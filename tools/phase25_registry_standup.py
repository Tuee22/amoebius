#!/usr/bin/env python3
"""Enact and externally verify the fixed six-object Phase-25.2 registry domain."""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import functools
import hashlib
import http.client
import json
import os
import shlex
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterator, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
NODE = "amoebius-phase24-control-plane"
NAMESPACE = "amoebius-bootstrap"
IMAGE_REPOSITORY = "amoebius.invalid/amoebius-base"
ORACLE = ROOT / "test/fixtures/phase25/bootstrap_registry_domain.dhall"
PUBLIC_HOSTS = ("docker.io", "quay.io", "ghcr.io")
PCAP = Path("/var/tmp/amoebius-phase25-standup.pcap")
FIREWALL_COMMENT = "amoebius-phase25-registry-private"


class StandupFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, stdin: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, input=stdin,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if check and result.returncode:
        raise StandupFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(("/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), *arguments), stdin=stdin, check=check)


@functools.cache
def dhall_to_json() -> str:
    """Resolve the dhall-to-json companion per run from the authored requirements.

    A bare `dhall-to-json` is a PATH lookup, which need not be the sibling of the dhall
    the authored range admits; the companion is taken from beside the resolved executable.
    """
    return str(Path(toolchain.resolve(["dhall"])["dhall"]["path"]).with_name("dhall-to-json"))


def oracle() -> dict[str, Any]:
    result = run((dhall_to_json(), "--file", str(ORACLE)))
    decoded = json.loads(result.stdout)
    if not isinstance(decoded, dict):
        raise StandupFailure("oracle-object")
    return decoded


def proxy_source(
    capability: str,
    admitted_objects: dict[str, int],
    publication_proof: str,
    publication_tag: str,
    index_digest: str,
) -> str:
    source = (ROOT / "tools/phase25_registry_proxy_runtime.py").read_text(encoding="utf-8")
    source = source.removeprefix(
        '"""Template executed inside the Phase-25 registry mutation-proxy container."""\n\n'
    )
    return (
        source.replace("__CAPABILITY__", repr(capability))
        .replace("__PUBLICATION_PROOF__", repr(publication_proof))
        .replace("__PUBLICATION_TAG__", repr(publication_tag))
        .replace("__INDEX_DIGEST__", repr(index_digest))
        .replace("__ADMITTED__", repr(json.dumps(admitted_objects, sort_keys=True)))
    )


def read_proxy_source() -> str:
    return '''import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(format % args, flush=True)

    def forward(self):
        connection = http.client.HTTPConnection("127.0.0.1", 5000, timeout=10)
        try:
            connection.request(self.command, self.path, headers={"Accept": self.headers.get("Accept", "*/*")})
            response = connection.getresponse()
            body = response.read()
            upstream_content_length = response.getheader("Content-Length")
            self.send_response(response.status)
            for name, value in response.getheaders():
                if name.lower() not in {"connection", "transfer-encoding", "content-length"}:
                    self.send_header(name, value)
            self.send_header(
                "Content-Length",
                upstream_content_length if self.command == "HEAD" and upstream_content_length else str(len(body)),
            )
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
        finally:
            connection.close()

    do_GET = forward
    do_HEAD = forward

    def deny(self):
        self.send_response(405)
        self.send_header("Allow", "GET, HEAD")
        self.end_headers()

    do_POST = deny
    do_PUT = deny
    do_PATCH = deny
    do_DELETE = deny

ThreadingHTTPServer(("0.0.0.0", 5002), Handler).serve_forever()
'''


def manifest(
    preflight: dict[str, Any],
    domain_oracle: dict[str, Any],
    evidence: Path,
    index_digest: str,
) -> dict[str, Any]:
    image = f"{IMAGE_REPOSITORY}@{index_digest}"
    digest = str(domain_oracle["handoffDigest"])
    capability = "sha256:" + hashlib.sha256((str(preflight["fingerprint"]) + digest).encode()).hexdigest()
    publication_tag = f"source-{digest[7:19]}-content-{index_digest[7:19]}"
    publication_proof = "sha256:" + hashlib.sha256(
        (capability + "|" + publication_tag + "|" + index_digest).encode()
    ).hexdigest()
    artifact = json.loads((evidence / "image-artifact.json").read_text(encoding="utf-8"))
    admitted_objects = {
        str(row["digest"]): int(row["storedBytes"])
        for row in artifact["registryObjects"]
    }
    registry_peak = int(preflight["registry"]["peakBytes"])
    registry_request = registry_peak + 512 * 1024**2
    registry_limit = registry_peak + 1024**3
    labels = {"app.kubernetes.io/managed-by": "amoebius", "amoebius.io/bootstrap": "registry"}
    annotations = {"amoebius.io/source-digest": digest}

    def metadata(name: str, *, namespace: bool = True, app: str | None = None) -> dict[str, Any]:
        result: dict[str, Any] = {"name": name, "labels": dict(labels), "annotations": dict(annotations)}
        if namespace:
            result["namespace"] = NAMESPACE
        if app is not None:
            result["labels"]["app.kubernetes.io/name"] = app
        return result

    registry_config = '''version: 0.1
log:
  level: info
  formatter: json
storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: false
http:
  addr: 0.0.0.0:5000
  headers:
    X-Content-Type-Options: [nosniff]
'''
    objects: list[dict[str, Any]] = [
        {"apiVersion": "v1", "kind": "Namespace", "metadata": metadata(NAMESPACE, namespace=False)},
        {
            "apiVersion": "v1", "kind": "ConfigMap", "metadata": metadata("registry-config"),
            "data": {
                "config.yml": registry_config,
                "proxy.py": proxy_source(
                    capability, admitted_objects, publication_proof, publication_tag, index_digest
                ),
                "read-proxy.py": read_proxy_source(),
            },
        },
        {
            "apiVersion": "apps/v1", "kind": "Deployment", "metadata": metadata("distribution", app="distribution"),
            "spec": {
                "replicas": 1, "strategy": {"type": "Recreate"},
                "selector": {"matchLabels": {"app.kubernetes.io/name": "distribution"}},
                "template": {
                    "metadata": {"labels": {**labels, "app.kubernetes.io/name": "distribution"}, "annotations": annotations},
                    "spec": {
                        "automountServiceAccountToken": False,
                        "schedulerName": "default-scheduler",
                        "nodeSelector": {"kubernetes.io/hostname": NODE},
                        "securityContext": {"runAsUser": 65532, "runAsGroup": 65532, "fsGroup": 65532, "seccompProfile": {"type": "RuntimeDefault"}},
                        "containers": [{
                            "name": "distribution", "image": image, "imagePullPolicy": "Never",
                            "command": ["/usr/bin/registry", "serve", "/etc/distribution/config.yml"],
                            "resources": {
                                "requests": {"cpu": "200m", "memory": "192Mi", "ephemeral-storage": str(registry_request - 64 * 1024**2)},
                                "limits": {"cpu": "400m", "memory": "384Mi", "ephemeral-storage": str(registry_limit - 128 * 1024**2)},
                            },
                            "securityContext": {"allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"]}},
                            "volumeMounts": [
                                {"name": "config", "mountPath": "/etc/distribution", "readOnly": True},
                                {"name": "blobs", "mountPath": "/var/lib/registry"},
                            ],
                        }, {
                            "name": "registry-read-proxy", "image": image, "imagePullPolicy": "Never",
                            "command": ["/usr/bin/python3", "/etc/distribution/read-proxy.py"],
                            "ports": [{"name": "read", "containerPort": 5002}],
                            "resources": {
                                "requests": {"cpu": "50m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                                "limits": {"cpu": "100m", "memory": "128Mi", "ephemeral-storage": "128Mi"},
                            },
                            "readinessProbe": {"httpGet": {"path": "/v2/", "port": "read"}, "periodSeconds": 2, "failureThreshold": 30},
                            "securityContext": {"readOnlyRootFilesystem": True, "allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"]}},
                            "volumeMounts": [{"name": "config", "mountPath": "/etc/distribution", "readOnly": True}, {"name": "tmp", "mountPath": "/tmp"}],
                        }],
                        "volumes": [
                            {"name": "config", "configMap": {"name": "registry-config", "items": [{"key": "config.yml", "path": "config.yml"}, {"key": "read-proxy.py", "path": "read-proxy.py"}]}},
                            {"name": "blobs", "emptyDir": {"sizeLimit": str(registry_peak)}},
                            {"name": "tmp", "emptyDir": {"sizeLimit": "16Mi"}},
                        ],
                    },
                },
            },
        },
        {
            "apiVersion": "v1", "kind": "Service", "metadata": metadata("distribution-read", app="distribution"),
            "spec": {
                "selector": {"app.kubernetes.io/name": "distribution"},
                "ports": [
                    {"name": "registry", "port": 5000, "targetPort": "read"},
                    {"name": "backend-private", "port": 5003, "targetPort": 5000},
                ],
            },
        },
        {
            "apiVersion": "apps/v1", "kind": "Deployment", "metadata": metadata("registry-mutation-proxy", app="registry-mutation-proxy"),
            "spec": {
                "replicas": 1, "strategy": {"type": "Recreate"},
                "selector": {"matchLabels": {"app.kubernetes.io/name": "registry-mutation-proxy"}},
                "template": {
                    "metadata": {"labels": {**labels, "app.kubernetes.io/name": "registry-mutation-proxy"}, "annotations": annotations},
                    "spec": {
                        "automountServiceAccountToken": False,
                        "schedulerName": "default-scheduler",
                        "nodeSelector": {"kubernetes.io/hostname": NODE},
                        "securityContext": {"runAsUser": 65532, "runAsGroup": 65532, "seccompProfile": {"type": "RuntimeDefault"}},
                        "containers": [{
                            "name": "registry-mutation-proxy", "image": image, "imagePullPolicy": "Never",
                            "command": ["/usr/bin/python3", "/etc/distribution/proxy.py"],
                            "ports": [{"name": "proxy", "containerPort": 5001}],
                            "resources": {
                                "requests": {"cpu": "100m", "memory": "128Mi", "ephemeral-storage": "64Mi"},
                                "limits": {"cpu": "250m", "memory": "256Mi", "ephemeral-storage": "128Mi"},
                            },
                            "readinessProbe": {"httpGet": {"path": "/healthz", "port": "proxy"}, "periodSeconds": 2, "failureThreshold": 30},
                            "securityContext": {"readOnlyRootFilesystem": True, "allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"]}},
                            "volumeMounts": [{"name": "config", "mountPath": "/etc/distribution", "readOnly": True}, {"name": "tmp", "mountPath": "/tmp"}],
                        }],
                        "volumes": [
                            {"name": "config", "configMap": {"name": "registry-config", "items": [{"key": "proxy.py", "path": "proxy.py"}]}},
                            {"name": "tmp", "emptyDir": {"sizeLimit": "16Mi"}},
                        ],
                    },
                },
            },
        },
        {
            "apiVersion": "v1", "kind": "Service", "metadata": metadata("registry-mutation-proxy", app="registry-mutation-proxy"),
            "spec": {"selector": {"app.kubernetes.io/name": "registry-mutation-proxy"}, "ports": [{"name": "proxy", "port": 5001, "targetPort": "proxy"}]},
        },
    ]
    return {
        "apiVersion": "v1",
        "kind": "List",
        "items": objects,
        "capability": capability,
        "publicationProof": publication_proof,
        "publicationTag": publication_tag,
    }


def identities(objects: list[dict[str, Any]]) -> list[str]:
    result = []
    for item in objects:
        metadata = item["metadata"]
        namespace = metadata.get("namespace")
        name = metadata["name"]
        result.append(f"{item['kind']}/{namespace + '/' if namespace else ''}{name}")
    return result


@contextlib.contextmanager
def port_forward(service: str, local: int, remote: int) -> Iterator[None]:
    process = subprocess.Popen(
        ("/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "port-forward", f"service/{service}", f"{local}:{remote}"),
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    try:
        for _ in range(60):
            try:
                with socket.create_connection(("127.0.0.1", local), timeout=0.2):
                    break
            except OSError:
                if process.poll() is not None:
                    output = process.stdout.read() if process.stdout is not None else ""
                    raise StandupFailure(f"port-forward:{service}:{process.returncode}:{output}")
                time.sleep(0.25)
        else:
            raise StandupFailure(f"port-forward-timeout:{service}")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def request(port: int, method: str, path: str, headers: dict[str, str] | None = None) -> tuple[int, str]:
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
    try:
        connection.request(method, path, headers=headers or {})
        response = connection.getresponse()
        return response.status, response.read().decode("utf-8", "replace")
    finally:
        connection.close()


def remove_backend_firewall() -> None:
    listed = run(("/usr/bin/docker", "exec", NODE, "/usr/sbin/iptables", "-S")).stdout
    for line in listed.splitlines():
        if FIREWALL_COMMENT not in line:
            continue
        arguments = shlex.split(line)
        if not arguments or arguments[0] != "-A":
            raise StandupFailure(f"firewall-rule-shape:{line}")
        arguments[0] = "-D"
        run(("/usr/bin/docker", "exec", NODE, "/usr/sbin/iptables", *arguments))


def observe_backend_firewall() -> dict[str, Any]:
    listed = run(("/usr/bin/docker", "exec", NODE, "/usr/sbin/iptables", "-S")).stdout
    rules = [line for line in listed.splitlines() if FIREWALL_COMMENT in line]
    if len(rules) != 3:
        raise StandupFailure(f"backend-firewall-rule-count:{rules}")
    service = json.loads(kubectl("-n", NAMESPACE, "get", "service", "distribution-read", "-o", "json").stdout)
    cluster_ip = str(service["spec"]["clusterIP"])
    proxy_read = kubectl(
        "-n", NAMESPACE, "exec", "deployment/registry-mutation-proxy", "--",
        "/usr/bin/python3", "-c",
        "import urllib.request; print(urllib.request.urlopen('http://distribution-read:5003/v2/', timeout=3).status)",
    )
    if proxy_read.stdout.strip() != "200":
        raise StandupFailure(f"proxy-private-backend-unreachable:{proxy_read.stdout}")
    direct = run(
        (
            "/usr/bin/docker", "exec", NODE, "/usr/bin/curl", "--silent", "--show-error",
            "--connect-timeout", "2", "--max-time", "3", f"http://{cluster_ip}:5003/v2/",
        ),
        check=False,
    )
    if direct.returncode == 0:
        raise StandupFailure(f"node-direct-backend-route-open:{direct.stdout}")
    return {
        "comment": FIREWALL_COMMENT,
        "ruleCount": len(rules),
        "proxyPrivateReadStatus": 200,
        "nodeDirectReadExit": direct.returncode,
    }


def configure_backend_firewall() -> dict[str, Any]:
    remove_backend_firewall()
    distribution = json.loads(
        kubectl(
            "-n", NAMESPACE, "get", "pod", "-l", "app.kubernetes.io/name=distribution",
            "-o", "json",
        ).stdout
    )
    proxy = json.loads(
        kubectl(
            "-n", NAMESPACE, "get", "pod", "-l", "app.kubernetes.io/name=registry-mutation-proxy",
            "-o", "json",
        ).stdout
    )
    if len(distribution["items"]) != 1 or len(proxy["items"]) != 1:
        raise StandupFailure("backend-firewall-pod-domain")
    distribution_ip = str(distribution["items"][0]["status"]["podIP"])
    proxy_ip = str(proxy["items"][0]["status"]["podIP"])
    comment = ("-m", "comment", "--comment", FIREWALL_COMMENT)
    run(
        (
            "/usr/bin/docker", "exec", NODE, "/usr/sbin/iptables", "-I", "FORWARD", "1",
            "-s", proxy_ip, "-d", distribution_ip, "-p", "tcp", "--dport", "5000",
            *comment, "-j", "ACCEPT",
        )
    )
    run(
        (
            "/usr/bin/docker", "exec", NODE, "/usr/sbin/iptables", "-I", "FORWARD", "2",
            "-d", distribution_ip, "-p", "tcp", "--dport", "5000",
            *comment, "-j", "REJECT",
        )
    )
    run(
        (
            "/usr/bin/docker", "exec", NODE, "/usr/sbin/iptables", "-I", "OUTPUT", "1",
            "-d", distribution_ip, "-p", "tcp", "--dport", "5000",
            *comment, "-j", "REJECT",
        )
    )
    return observe_backend_firewall()


def start_capture() -> subprocess.Popen[bytes]:
    if PCAP.exists():
        run(("/usr/bin/sudo", "-n", "/usr/bin/rm", "-f", "--", str(PCAP)))
    process = subprocess.Popen(
        (
            "/usr/bin/sudo", "-n", "/usr/bin/tcpdump", "-i", "any", "-nn", "-U", "-w", str(PCAP),
            "tcp", "and", "(", "net", "10.244.0.0/16", "or", "host", "172.18.0.2", ")",
        ),
        cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
    )
    time.sleep(1)
    if process.poll() is not None:
        error = process.stderr.read().decode("utf-8", "replace") if process.stderr is not None else ""
        raise StandupFailure(f"tcpdump-start:{process.returncode}:{error}")
    return process


def stop_capture(process: subprocess.Popen[bytes]) -> str:
    process.send_signal(signal.SIGINT)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)
    if not PCAP.is_file():
        raise StandupFailure("pcap-absent")
    return run(("/usr/bin/tcpdump", "-nn", "-r", str(PCAP)), check=True).stdout


def validate_no_public_connections(packet_text: str, endpoints: dict[str, list[str]]) -> None:
    public_ipv4 = {address for values in endpoints.values() for address in values if ":" not in address}
    hits = sorted(address for address in public_ipv4 if address in packet_text)
    if hits:
        raise StandupFailure("public-registry-tcp:" + ",".join(hits))


def validate_live(
    domain_oracle: dict[str, Any],
    generated: dict[str, Any],
    packet_text: str,
    journal_since: str | None,
    evidence: Path,
    index_digest: str,
) -> dict[str, Any]:
    image = f"{IMAGE_REPOSITORY}@{index_digest}"
    resources = json.loads(kubectl("-n", NAMESPACE, "get", "namespace,configmap,deployment,service", "-l", "amoebius.io/bootstrap=registry", "-o", "json").stdout)
    observed_ids = sorted(identities(resources["items"]))
    expected_ids = sorted(str(value) for value in domain_oracle["identities"])
    if observed_ids != expected_ids:
        raise StandupFailure(f"live-domain:{observed_ids}:{expected_ids}")
    for item in resources["items"]:
        if item["metadata"].get("annotations", {}).get("amoebius.io/source-digest") != domain_oracle["handoffDigest"]:
            raise StandupFailure(f"source-digest:{item['kind']}/{item['metadata']['name']}")
    deployments = json.loads(kubectl("-n", NAMESPACE, "get", "deployments", "-o", "json").stdout)
    for deployment in deployments["items"]:
        containers = deployment["spec"]["template"]["spec"]["containers"]
        if any(container.get("imagePullPolicy") != "Never" or container.get("image") != image for container in containers):
            raise StandupFailure(f"pull-policy-or-image:{deployment['metadata']['name']}")
    pods = json.loads(kubectl("-n", NAMESPACE, "get", "pods", "-o", "json").stdout)
    image_ids = []
    for pod in pods["items"]:
        for status in pod.get("status", {}).get("containerStatuses", []):
            image_ids.append(status.get("imageID", ""))
    if len(image_ids) != 3 or any(index_digest not in value for value in image_ids):
        raise StandupFailure(f"image-byte-identity:{image_ids}")
    if journal_since is not None:
        journal = run(("/usr/bin/docker", "exec", NODE, "journalctl", "-u", "containerd", "--since", journal_since, "--no-pager")).stdout
        forbidden = [line for line in journal.splitlines() if any(host in line for host in PUBLIC_HOSTS)]
        if forbidden:
            raise StandupFailure("containerd-public-registry:" + " | ".join(forbidden))
    preflight = json.loads((evidence / "sprint-25.2-preflight.json").read_text(encoding="utf-8"))
    validate_no_public_connections(packet_text, preflight["publicEndpoints"])
    capability = str(generated["capability"])
    with port_forward("distribution-read", 15000, 5000):
        read_status, read_body = request(15000, "GET", "/v2/")
        direct_write_status, direct_write_body = request(15000, "POST", "/v2/amoebius/probe/blobs/uploads/")
    if read_status != 200:
        raise StandupFailure(f"registry-read:{read_status}:{read_body}")
    if direct_write_status < 400:
        raise StandupFailure(f"readonly-direct-write:{direct_write_status}:{direct_write_body}")
    with port_forward("registry-mutation-proxy", 15001, 5001):
        health_status, health_body = request(15001, "GET", "/healthz")
        denied_status, denied_body = request(15001, "POST", "/v2/amoebius/probe/blobs/uploads/")
        admitted_status, admitted_body = request(15001, "POST", "/v2/amoebius/probe/blobs/uploads/", {"Authorization": "Bearer " + capability})
    if health_status != 200 or denied_status != 403 or admitted_status != 409:
        raise StandupFailure(f"proxy-boundary:{health_status}:{denied_status}:{admitted_status}")
    filesystem = run(("/usr/bin/docker", "exec", NODE, "df", "-B1", "/var/lib/containerd")).stdout
    return {
        "domain": observed_ids,
        "handoffDigest": domain_oracle["handoffDigest"],
        "image": image,
        "imageIds": image_ids,
        "registryRead": {"status": read_status, "body": read_body},
        "directMutation": {"status": direct_write_status, "body": direct_write_body},
        "proxy": {
            "healthStatus": health_status, "healthBody": health_body,
            "deniedStatus": denied_status, "deniedBody": denied_body,
            "admittedButDeferredStatus": admitted_status, "admittedButDeferredBody": admitted_body,
        },
        "containerdPublicRegistryLines": 0,
        "publicRegistryTcpConnections": 0,
        "capturedTcpPackets": len(packet_text.splitlines()),
        "filesystemReadback": filesystem.strip(),
    }


def enact(evidence: Path, index_digest: str) -> dict[str, Any]:
    domain_oracle = oracle()
    preflight = json.loads((evidence / "sprint-25.2-preflight.json").read_text(encoding="utf-8"))
    image_rows = run(("/usr/bin/docker", "exec", NODE, "/usr/local/bin/ctr", "--namespace", "k8s.io", "images", "list", "--quiet")).stdout.splitlines()
    if f"{IMAGE_REPOSITORY}@{index_digest}" not in image_rows:
        raise StandupFailure("side-loaded-image-absent")
    if kubectl("get", "namespace", NAMESPACE, "--ignore-not-found", "-o", "name").stdout.strip():
        raise StandupFailure("bootstrap-domain-already-present")
    generated = manifest(preflight, domain_oracle, evidence, index_digest)
    if sorted(identities(generated["items"])) != sorted(str(value) for value in domain_oracle["identities"]):
        raise StandupFailure("generated-domain-mismatch")
    payload = dict(generated)
    payload.pop("capability")
    payload.pop("publicationProof")
    payload.pop("publicationTag")
    journal_since = dt.datetime.now(dt.timezone.utc).isoformat()
    capture = start_capture()
    backend_firewall: dict[str, Any] = {}
    try:
        kubectl("apply", "--server-side", "--field-manager=amoebius-bootstrap-registry", "-f", "-", stdin=json.dumps(payload))
        kubectl("-n", NAMESPACE, "rollout", "status", "deployment/distribution", "--timeout=300s")
        kubectl("-n", NAMESPACE, "rollout", "status", "deployment/registry-mutation-proxy", "--timeout=300s")
        backend_firewall = configure_backend_firewall()
        time.sleep(2)
    finally:
        packet_text = stop_capture(capture)
    result = validate_live(domain_oracle, generated, packet_text, journal_since, evidence, index_digest)
    result.update({
        "schema": "amoebius.phase25.sprint25.2-standup.v1",
        "preflightFingerprint": preflight["fingerprint"],
        "backendFirewall": backend_firewall,
        "capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
    })
    return result


def verify_current(evidence: Path, index_digest: str) -> dict[str, Any]:
    standup = evidence / "sprint-25.2-standup.json"
    if not standup.is_file() or not PCAP.is_file():
        raise StandupFailure("standup-evidence-or-pcap-absent")
    recorded = json.loads(standup.read_text(encoding="utf-8"))
    if (
        recorded.get("containerdPublicRegistryLines") != 0
        or recorded.get("publicRegistryTcpConnections") != 0
    ):
        raise StandupFailure("recorded-standup-public-registry-observation")
    domain_oracle = oracle()
    preflight = json.loads((evidence / "sprint-25.2-preflight.json").read_text(encoding="utf-8"))
    generated = manifest(preflight, domain_oracle, evidence, index_digest)
    packet_text = run(("/usr/bin/tcpdump", "-nn", "-r", str(PCAP))).stdout
    result = validate_live(
        domain_oracle,
        generated,
        packet_text,
        None,
        evidence,
        index_digest,
    )
    result.update(
        {
            "schema": "amoebius.phase25.sprint25.2-current-verification.v1",
            "preflightFingerprint": preflight["fingerprint"],
            "backendFirewall": observe_backend_firewall(),
            "verifiedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        }
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    # The bundle this run reads its preflight, artifact, and standup observations from is
    # supplied by the caller. There is deliberately no default: a default names a location,
    # and whatever a previous run left there would decide this standup instead of the run
    # in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    # Likewise the index digest: a constant here would pin a build that no longer exists.
    parser.add_argument("--index-digest", required=True, help="the index digest this run produced")
    arguments = parser.parse_args()
    result = (
        verify_current(arguments.evidence, arguments.index_digest)
        if arguments.verify_only
        else enact(arguments.evidence, arguments.index_digest)
    )
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if arguments.output is not None:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")


if __name__ == "__main__":
    main()
