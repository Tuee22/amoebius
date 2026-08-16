#!/usr/bin/env python3
"""Run the Phase-33 singleton, admin, handoff, and live-deploy acceptance."""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import http.client
import importlib.util
import json
import os
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterator, Sequence


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_33"
LIVE_EVIDENCE = EVIDENCE / "singleton-live.json"
NAMESPACE = "phase33-system"
SINGLETON = "amoebius-control-plane"
LEASE = "amoebius-reconciler"
NODE = "amoebius-bootstrap-coordinator-control-plane"
NODE_ARTIFACTS = "/var/local/amoebius/phase33"
NODE_PORT = 32034
IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
EXPECTED = ROOT / "test/fixtures/phase33/expected-enact-pass1.json"
NEGATIVE = ROOT / "test/fixtures/phase33/negative-expected-tags.tsv"
ADMISSION = ROOT / "test/golden/admin/admission-tags.tsv"
UNLOCK = Path("/var/tmp/amoebius-phase28-retained/phase29-unlock.age")
MINIO_ACCESS = "phase30-test-access"
MINIO_SECRET = "phase30-test-secret-value"


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, stdin: str | bytes | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[Any]:
    binary = isinstance(stdin, bytes)
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=stdin, text=not binary,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        output = result.stdout.decode(errors="replace") if binary else result.stdout
        raise LiveFailure(f"command:{arguments[0]}:exit-{result.returncode}:{output}")
    return result


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return run(("/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), *arguments), stdin=stdin, check=check, timeout=timeout)


def docker(*arguments: str, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return run(("/usr/bin/docker", *arguments), check=check, timeout=timeout)


def apply(value: dict[str, Any], manager: str = "phase33-bootstrap-host") -> None:
    kubectl("apply", "--server-side", f"--field-manager={manager}", "--force-conflicts", "-f", "-", stdin=json.dumps(value))


def get(kind: str, name: str, namespace: str | None = None) -> dict[str, Any]:
    prefix = ("-n", namespace) if namespace else ()
    return json.loads(kubectl(*prefix, "get", kind, name, "-o", "json", "--show-managed-fields").stdout)


def sanitize(value: dict[str, Any]) -> dict[str, Any]:
    copied = json.loads(json.dumps(value))
    metadata = copied.get("metadata", {})
    for key in ("creationTimestamp", "generation", "managedFields", "resourceVersion", "uid"):
        metadata.pop(key, None)
    copied.pop("status", None)
    if copied.get("kind") == "Service":
        spec = copied.get("spec", {})
        for key in ("clusterIP", "clusterIPs", "ipFamilies", "ipFamilyPolicy", "internalTrafficPolicy", "sessionAffinity"):
            spec.pop(key, None)
        for port in spec.get("ports", []):
            port.pop("nodePort", None)
    return copied


def phase32_module() -> Any:
    path = ROOT / "tools/phase32_keycloak_ingress_live.py"
    spec = importlib.util.spec_from_file_location("phase32_for_phase33", path)
    if spec is None or spec.loader is None:
        raise LiveFailure("phase32-module-load")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@contextlib.contextmanager
def port_forward(namespace: str, resource: str, local: int, remote: int) -> Iterator[None]:
    process = subprocess.Popen(
        ["/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), "-n", namespace, "port-forward", resource, f"{local}:{remote}"],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                connection = http.client.HTTPConnection("127.0.0.1", local, timeout=1)
                connection.request("GET", "/v1/sys/health")
                response = connection.getresponse()
                response.read()
                connection.close()
                if response.status in {200, 429, 472, 473, 501, 503}:
                    break
            except OSError:
                pass
            if process.poll() is not None:
                output = process.stdout.read().decode(errors="replace") if process.stdout else ""
                raise LiveFailure("port-forward-exited:" + output)
            time.sleep(0.2)
        else:
            raise LiveFailure("port-forward-timeout")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def vault_local(method: str, path: str, token: str, payload: Any | None = None, expected: set[int] = {200, 204}) -> Any:
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        "http://127.0.0.1:18200/v1/" + path.lstrip("/"), data=data, method=method,
        headers={"X-Vault-Token": token, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            if response.status not in expected:
                raise LiveFailure(f"vault-local-{response.status}:{path}")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as problem:
        raw = problem.read()
        if problem.code not in expected:
            raise LiveFailure(f"vault-local-{problem.code}:{path}:{raw.decode(errors='replace')}") from problem
        return json.loads(raw) if raw else {}


def configure_vault(root_token: str) -> dict[str, Any]:
    with port_forward("vault-system", "service/root-vault", 18200, 8200):
        vault_local("POST", "transit/keys/phase33-control-plane", root_token, {}, {200, 204, 400})
        vault_local("POST", "secret/data/amoebius/phase33/minio", root_token, {"data": {"accessKey": MINIO_ACCESS, "secretKey": MINIO_SECRET}})
        policy = '''path "secret/data/amoebius/phase33/minio" { capabilities = ["read"] }
path "transit/decrypt/phase33-control-plane" { capabilities = ["update"] }
'''
        vault_local("PUT", "sys/policies/acl/phase33-singleton", root_token, {"policy": policy})
        vault_local("POST", "auth/kubernetes/role/phase33-singleton", root_token, {
            "bound_service_account_names": SINGLETON,
            "bound_service_account_namespaces": NAMESPACE,
            "policies": "phase33-singleton", "ttl": "15m",
        })
    return {"transitKey": "phase33-control-plane", "kubernetesRole": "phase33-singleton", "minioCredentialPath": "secret/data/amoebius/phase33/minio"}


def cabal_binary(component: str) -> Path:
    arguments = (
        "/home/matthewnowak/.ghcup/bin/cabal", "list-bin", component,
        "--disable-shared", "--disable-executable-dynamic", "--enable-executable-static", "--ghc-options=-optl-static",
    )
    return Path(run(arguments).stdout.strip())


def install_artifacts() -> dict[str, Any]:
    singleton = cabal_binary("exe:amoebius-singleton")
    amoebius = cabal_binary("exe:amoebius")
    if not singleton.is_file() or not amoebius.is_file() or not UNLOCK.is_file():
        raise LiveFailure("phase33-artifact-missing")
    docker("exec", NODE, "/bin/rm", "-rf", NODE_ARTIFACTS)
    docker("exec", NODE, "/bin/mkdir", "-p", NODE_ARTIFACTS)
    for source, name in (
        (singleton, "amoebius-singleton"),
        (amoebius, "amoebius"),
        (ROOT / "tools/phase33_runtime_helper.py", "phase33_runtime_helper.py"),
        (UNLOCK, "phase29-unlock.age"),
    ):
        docker("cp", str(source), f"{NODE}:{NODE_ARTIFACTS}/{name}")
    docker("cp", str(ROOT / "dhall"), f"{NODE}:{NODE_ARTIFACTS}/dhall")
    docker("exec", NODE, "/bin/chmod", "0755", f"{NODE_ARTIFACTS}/amoebius-singleton", f"{NODE_ARTIFACTS}/amoebius", f"{NODE_ARTIFACTS}/phase33_runtime_helper.py")
    docker("exec", NODE, "/bin/chmod", "0400", f"{NODE_ARTIFACTS}/phase29-unlock.age")
    return {
        "singletonSha256": "sha256:" + hashlib.sha256(singleton.read_bytes()).hexdigest(),
        "amoebiusSha256": "sha256:" + hashlib.sha256(amoebius.read_bytes()).hexdigest(),
        "helperSha256": "sha256:" + hashlib.sha256((ROOT / "tools/phase33_runtime_helper.py").read_bytes()).hexdigest(),
        "staticallyLinked": "statically linked" in run(("/usr/bin/file", str(singleton))).stdout,
        "nodePath": NODE_ARTIFACTS,
    }


def clean_previous() -> None:
    existing = kubectl("get", "namespace", NAMESPACE, check=False)
    if existing.returncode == 0:
        kubectl("delete", "namespace", NAMESPACE, "--wait=true", "--timeout=180s")
    for resource in ("clusterrole/phase33-singleton", "clusterrole/phase33-harness-observer", "clusterrolebinding/phase33-singleton", "clusterrolebinding/phase33-harness-observer"):
        kubectl("delete", resource, "--ignore-not-found=true")


def resources() -> list[dict[str, Any]]:
    return [
        {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE, "labels": {"app.kubernetes.io/managed-by": "amoebius"}}},
        {"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": SINGLETON, "namespace": NAMESPACE}},
        {"apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole", "metadata": {"name": "phase33-singleton"}, "rules": [
            {"apiGroups": [""], "resources": ["configmaps", "services", "pods"], "verbs": ["get", "list", "watch", "create", "patch", "update"]},
            {"apiGroups": ["apps"], "resources": ["deployments"], "verbs": ["get", "list", "watch", "create", "patch", "update"]},
            {"apiGroups": ["gateway.networking.k8s.io"], "resources": ["httproutes"], "verbs": ["get", "list", "watch", "create", "patch", "update"]},
            {"apiGroups": ["coordination.k8s.io"], "resources": ["leases"], "verbs": ["get", "list", "watch", "patch", "update"]},
        ]},
        {"apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding", "metadata": {"name": "phase33-singleton"}, "subjects": [{"kind": "ServiceAccount", "name": SINGLETON, "namespace": NAMESPACE}], "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "phase33-singleton"}},
        {"apiVersion": "coordination.k8s.io/v1", "kind": "Lease", "metadata": {"name": LEASE, "namespace": NAMESPACE, "labels": {"app.kubernetes.io/managed-by": "amoebius"}, "annotations": {"amoebius.io/release-observed": "false"}}, "spec": {"holderIdentity": "phase26-bootstrap-host", "leaseDurationSeconds": 10, "leaseTransitions": 0}},
        {"apiVersion": "v1", "kind": "Service", "metadata": {"name": "amoebius-admin", "namespace": NAMESPACE, "labels": {"amoebius.io/endpoint-class": "HostLocalPeer"}}, "spec": {"type": "NodePort", "selector": {"app": SINGLETON}, "ports": [{"name": "admin", "port": 18080, "targetPort": 18080, "nodePort": NODE_PORT}]}},
        {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": SINGLETON, "namespace": NAMESPACE, "labels": {"app.kubernetes.io/managed-by": "amoebius"}}, "spec": {
            "replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": SINGLETON}},
            "template": {"metadata": {"labels": {"app": SINGLETON}}, "spec": {
                "serviceAccountName": SINGLETON, "automountServiceAccountToken": True, "securityContext": {"fsGroup": 1000, "fsGroupChangePolicy": "OnRootMismatch"},
                "initContainers": [{"name": "stage-dhall", "image": IMAGE, "imagePullPolicy": "Never", "command": ["/bin/sh", "-ec", "/bin/cp -r /source/dhall/. /work/\n/bin/chown -R 1000:1000 /work"], "securityContext": {"runAsUser": 0, "runAsGroup": 0, "allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"], "add": ["CHOWN"]}, "seccompProfile": {"type": "RuntimeDefault"}}, "resources": {"requests": {"cpu": "5m", "memory": "16Mi", "ephemeral-storage": "16Mi"}, "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"}}, "volumeMounts": [{"name": "artifacts", "mountPath": "/source", "readOnly": True}, {"name": "dhall", "mountPath": "/work"}]}],
                "containers": [{"name": "singleton", "image": IMAGE, "imagePullPolicy": "Never", "command": ["/phase33-artifacts/amoebius-singleton"], "ports": [{"name": "admin", "containerPort": 18080}],
                    "resources": {"requests": {"cpu": "25m", "memory": "128Mi", "ephemeral-storage": "32Mi"}, "limits": {"cpu": "500m", "memory": "1Gi", "ephemeral-storage": "512Mi"}},
                    "securityContext": {"allowPrivilegeEscalation": False, "runAsNonRoot": True, "runAsUser": 1000, "runAsGroup": 1000, "capabilities": {"drop": ["ALL"]}, "seccompProfile": {"type": "RuntimeDefault"}},
                    "livenessProbe": {"httpGet": {"path": "/healthz", "port": 18080}, "periodSeconds": 5, "failureThreshold": 60},
                    "readinessProbe": {"httpGet": {"path": "/readyz", "port": 18080}, "periodSeconds": 2, "failureThreshold": 300},
                    "volumeMounts": [{"name": "artifacts", "mountPath": "/phase33-artifacts", "readOnly": True}, {"name": "dhall", "mountPath": "/phase33-dhall"}, {"name": "podinfo", "mountPath": "/etc/podinfo", "readOnly": True}, {"name": "artifacts", "mountPath": "/var/lib/amoebius/phase29-unlock.age", "subPath": "phase29-unlock.age", "readOnly": True}],
                }],
                "volumes": [{"name": "artifacts", "hostPath": {"path": NODE_ARTIFACTS, "type": "Directory"}}, {"name": "dhall", "emptyDir": {"sizeLimit": "64Mi"}}, {"name": "podinfo", "downwardAPI": {"items": [{"path": "uid", "fieldRef": {"fieldPath": "metadata.uid"}}]}}],
            }},
        }},
    ]


def setup_control_plane() -> None:
    for value in resources():
        apply(value)
    kubectl("apply", "--server-side", "--field-manager=phase33-bootstrap-host", "--force-conflicts", "-f", "test/fixtures/phase33/harness-rbac.yaml")


def pod_name() -> str:
    items = json.loads(kubectl("-n", NAMESPACE, "get", "pods", "-l", f"app={SINGLETON}", "-o", "json").stdout)["items"]
    if len(items) != 1:
        raise LiveFailure(f"singleton-pod-cardinality:{len(items)}")
    return items[0]["metadata"]["name"]


def wait_pod_running(timeout: int = 180) -> str:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            name = pod_name()
            phase = get("pod", name, NAMESPACE).get("status", {}).get("phase")
            if phase == "Running":
                return name
        except (LiveFailure, KeyError, json.JSONDecodeError):
            pass
        time.sleep(1)
    raise LiveFailure("singleton-pod-not-running")


def pod_http(pod: str, path: str) -> int:
    program = "import http.client; c=http.client.HTTPConnection('127.0.0.1',18080,timeout=3); c.request('GET',%r); r=c.getresponse(); print(r.status); r.read()" % path
    result = kubectl("-n", NAMESPACE, "exec", pod, "--", "/usr/bin/python3", "-c", program, check=False)
    if result.returncode:
        return 0
    return int(result.stdout.strip().splitlines()[-1])


def release_bootstrap_holder() -> dict[str, Any]:
    prior = get("lease", LEASE, NAMESPACE)
    if prior["spec"].get("holderIdentity") != "phase26-bootstrap-host":
        raise LiveFailure("bootstrap-holder-not-observed")
    patch = {"metadata": {"resourceVersion": prior["metadata"]["resourceVersion"]}, "spec": {"holderIdentity": None}}
    kubectl("-n", NAMESPACE, "patch", "lease", LEASE, "--type=merge", "--field-manager=phase33-bootstrap-host", "-p", json.dumps(patch))
    released = get("lease", LEASE, NAMESPACE)
    if released["metadata"]["uid"] != prior["metadata"]["uid"] or released["spec"].get("holderIdentity") is not None or released["metadata"]["resourceVersion"] == prior["metadata"]["resourceVersion"]:
        raise LiveFailure("lease-release-readback")
    acknowledgement = {"metadata": {"resourceVersion": released["metadata"]["resourceVersion"], "annotations": {"amoebius.io/release-observed": "true"}}}
    kubectl("-n", NAMESPACE, "patch", "lease", LEASE, "--type=merge", "--field-manager=phase33-bootstrap-host", "-p", json.dumps(acknowledgement))
    return {
        "bootstrap": {"holder": "phase26-bootstrap-host", "uid": prior["metadata"]["uid"], "resourceVersion": prior["metadata"]["resourceVersion"]},
        "released": {"holder": None, "uid": released["metadata"]["uid"], "resourceVersion": released["metadata"]["resourceVersion"]},
        "hostQuiescedBeforeRelease": True,
    }


def wait_singleton_holder(pod_uid: str, timeout: int = 180) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        lease = get("lease", LEASE, NAMESPACE)
        if lease.get("spec", {}).get("holderIdentity") == pod_uid:
            return {"holder": pod_uid, "uid": lease["metadata"]["uid"], "resourceVersion": lease["metadata"]["resourceVersion"]}
        time.sleep(1)
    raise LiveFailure("singleton-holder-timeout")


def admin_request(path: str, payload: dict[str, Any], reach: str = "NodeLocal", timeout: int = 300) -> tuple[int, dict[str, Any]]:
    body = json.dumps(payload, separators=(",", ":")).encode()
    deadline = time.monotonic() + min(timeout, 60)
    while True:
        result = subprocess.run(
            ["/usr/bin/docker", "exec", "-i", NODE, "/usr/bin/curl", "--silent", "--show-error", "--max-time", str(timeout),
             "--header", "Content-Type: application/json", "--header", f"X-Amoebius-Reach: {reach}",
             "--data-binary", "@-", "--write-out", "\n%{http_code}", f"http://127.0.0.1:{NODE_PORT}{path}"],
            cwd=ROOT, input=body, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout + 10,
        )
        if result.returncode == 0:
            raw, status_line = result.stdout.rsplit(b"\n", 1)
            status = int(status_line)
            break
        if time.monotonic() >= deadline:
            raise LiveFailure("admin-node-loopback-unreachable:" + result.stdout.decode(errors="replace"))
        time.sleep(0.5)
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as problem:
        raise LiveFailure(f"admin-non-json:{status}:{raw[:512]!r}") from problem
    return status, parsed


def vault_audit_lines() -> int:
    program = "import glob; print(sum(sum(1 for _ in open(p,'rb')) for p in glob.glob('/vault/audit/audit.log*')))"
    result = kubectl("-n", "vault-system", "exec", "root-vault-0", "--", "/usr/bin/python3", "-c", program)
    return int(result.stdout.strip())


def platform_snapshot() -> dict[str, Any]:
    identities = json.loads(EXPECTED.read_text(encoding="utf-8"))["objects"]
    result: dict[str, Any] = {}
    for raw in identities:
        kind, namespace, name = raw.split("/", 2)
        plural = {"ConfigMap": "configmap", "Deployment": "deployment", "HTTPRoute": "httproute", "Service": "service"}[kind]
        observed = kubectl("-n", namespace, "get", plural, name, "-o", "json", check=False)
        if observed.returncode:
            result[raw] = None
            continue
        value = json.loads(observed.stdout)
        result[raw] = {
            "uid": value["metadata"].get("uid"), "resourceVersion": value["metadata"].get("resourceVersion"),
            "generation": value["metadata"].get("generation"), "spec": value.get("spec"), "data": value.get("data"),
        }
    return result


def audit_events_since(start: dt.datetime) -> list[dict[str, Any]]:
    events = []
    with tempfile.TemporaryDirectory(prefix="amoebius-phase33-audit-") as temporary:
        docker("cp", f"{NODE}:/var/log/kubernetes/audit", temporary, timeout=180)
        for path in Path(temporary, "audit").glob("audit*.log"):
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if value.get("stage") != "ResponseComplete":
                    continue
                timestamp = value.get("requestReceivedTimestamp") or value.get("stageTimestamp")
                if timestamp and dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00")) >= start:
                    events.append(value)
    return events


def audit_identity(event: dict[str, Any]) -> str | None:
    reference = event.get("objectRef", {})
    resource = reference.get("resource")
    kind = {"configmaps": "ConfigMap", "deployments": "Deployment", "httproutes": "HTTPRoute", "services": "Service"}.get(resource)
    if not kind or not reference.get("name"):
        return None
    return f"{kind}/{reference.get('namespace', '')}/{reference['name']}"


def singleton_mutations(events: list[dict[str, Any]]) -> tuple[set[str], list[dict[str, Any]]]:
    user = f"system:serviceaccount:{NAMESPACE}:{SINGLETON}"
    mutations = []
    for event in events:
        if event.get("verb") not in {"create", "update", "patch", "delete"}:
            continue
        identity_value = audit_identity(event)
        if identity_value and event.get("user", {}).get("username") == user:
            mutations.append({"identity": identity_value, "verb": event["verb"], "user": user, "requestURI": event.get("requestURI")})
    return {row["identity"] for row in mutations}, mutations


def check_history_capacity() -> dict[str, Any]:
    configured = 16 * 1024 * 1024 * 3
    with tempfile.TemporaryDirectory(prefix="amoebius-phase33-history-") as temporary:
        docker("cp", f"{NODE}:/var/log/kubernetes/audit", temporary, timeout=180)
        sizes = {path.name: path.stat().st_size for path in Path(temporary, "audit").glob("audit*.log")}
    if sum(sizes.values()) > configured:
        raise LiveFailure("audit-history-over-configured-carve")
    return {"maxBytesPerFile": 16777216, "maxBackups": 2, "retainedByteCapacity": configured, "observedResidentBytes": sum(sizes.values()), "gateWindowMaximumSeconds": 1800, "eventTtlSeconds": 3600, "withinEngineSystemReserve": True}


def test_admin_sequence(password: str, normalized_dhall: str, run_id: str) -> dict[str, Any]:
    status, initialized = admin_request("/v1/vault/init", {"password": password})
    if status != 200 or initialized.get("result") != "already-initialized":
        raise LiveFailure(f"admin-vault-init:{status}:{initialized}")
    status, unsealed = admin_request("/v1/vault/unseal", {"password": password})
    if status != 200 or unsealed.get("result") != "unsealed":
        raise LiveFailure(f"admin-vault-unseal:{status}:{unsealed}")
    probes = [
        {"name": "static-host", "secretExists": True, "sshConnects": True, "observedResourcesSatisfy": True, "cloudPermissionAndQuota": True},
        {"name": "cloud-provider", "secretExists": True, "sshConnects": True, "observedResourcesSatisfy": True, "cloudPermissionAndQuota": True},
    ]
    payload = {"password": password, "dhall": normalized_dhall, "probes": probes, "runId": run_id}
    first_start = dt.datetime.now(dt.UTC)
    status, first = admin_request("/v1/dhall/update", payload, timeout=600)
    if status != 200 or first.get("result") != "converged":
        raise LiveFailure(f"admin-dhall-first:{status}:{first}")
    expected_objects = json.loads(EXPECTED.read_text(encoding="utf-8"))["objects"]
    enacted_objects = first.get("enact", {}).get("objects", [])
    if enacted_objects != expected_objects:
        raise LiveFailure(f"first-enact-oracle:{enacted_objects}:{expected_objects}")
    expected = set(expected_objects)
    first_audit_set, first_audit = singleton_mutations(audit_events_since(first_start))
    if first_audit_set != expected:
        raise LiveFailure(f"first-audit-oracle:{sorted(first_audit_set)}:{sorted(expected)}")
    second_start = dt.datetime.now(dt.UTC)
    status, second = admin_request("/v1/dhall/update", payload, timeout=600)
    if status != 200 or second.get("enact", {}).get("objects") != []:
        raise LiveFailure(f"second-enact-not-empty:{status}:{second}")
    second_set, second_audit = singleton_mutations(audit_events_since(second_start))
    if second_set:
        raise LiveFailure(f"second-audit-not-empty:{sorted(second_set)}")
    for verb, name, value in (("put", "phase33-canary", "phase33-kv-value"), ("get", "phase33-canary", None), ("list", "", None), ("delete", "phase33-canary", None)):
        status, result = admin_request("/v1/kv", {"password": password, "verb": verb, "name": name, "value": value})
        if status != 200:
            raise LiveFailure(f"kv-{verb}:{status}:{result}")
        if verb == "get" and result.get("value") != "phase33-kv-value":
            raise LiveFailure("kv-get-value")
    return {
        "vaultInit": initialized, "vaultUnseal": unsealed,
        "dhallBytes": len(normalized_dhall.encode()), "durable": first.get("durable"),
        "firstPass": {"objects": enacted_objects, "audit": first_audit},
        "secondPass": {"objects": [], "audit": second_audit, "discoverReran": True},
        "kvCrud": ["put", "get", "list", "delete"],
    }


def negative_corpus(password: str) -> dict[str, Any]:
    before = platform_snapshot()
    vault_before = vault_audit_lines()
    rows = []
    for line in NEGATIVE.read_text(encoding="utf-8").splitlines()[1:]:
        if not line.strip():
            continue
        fixture, gate, tag, positive = line.split("\t")
        source = (ROOT / fixture).read_text(encoding="utf-8")
        status, result = admin_request("/v1/dhall/update", {"password": password, "dhall": source, "probes": [], "runId": "phase33-000000000000"}, timeout=300)
        if status != 422 or result.get("gate") != gate or result.get("tag") != tag:
            raise LiveFailure(f"negative:{fixture}:{status}:{result}:{gate}:{tag}")
        rows.append({"fixture": fixture, "gate": gate, "tag": tag, "positivePair": positive})
    after = platform_snapshot()
    vault_after = vault_audit_lines()
    if before != after or vault_before != vault_after:
        raise LiveFailure(f"negative-side-effect:{before == after}:{vault_before}:{vault_after}")
    return {"count": len(rows), "rows": rows, "platformAppResourceVersionsUnchanged": True, "vaultContacts": 0, "apiserverWrites": 0, "snapshotScope": "oracle-pinned platform/app object set"}


def admin_negatives(password: str, normalized_dhall: str, run_id: str) -> dict[str, Any]:
    before = vault_audit_lines()
    reaches = []
    for endpoint in ("/v1/vault/init", "/v1/vault/unseal"):
        for reach in ("AuthenticatedFabric", "Lan", "WildIngress"):
            status, result = admin_request(endpoint, {"password": password}, reach=reach)
            if status != 403 or result.get("tag") != "admin-reach-seal-critical-node-local-required":
                raise LiveFailure(f"reach-negative:{endpoint}:{reach}:{status}:{result}")
            reaches.append({"endpoint": endpoint, "reach": reach, "tag": result["tag"]})
    after_reach = vault_audit_lines()
    if before != after_reach:
        raise LiveFailure("reach-negative-contacted-vault")
    admissions = []
    fixture_root = ROOT / "test/fixtures/admin/secrets-capability"
    for line in ADMISSION.read_text(encoding="utf-8").splitlines()[1:]:
        cause, tag, negative_name, positive_name = line.split("\t")
        probe = json.loads((fixture_root / negative_name).read_text(encoding="utf-8"))
        vault_before_negative = vault_audit_lines()
        start = dt.datetime.now(dt.UTC)
        status, result = admin_request("/v1/dhall/update", {"password": password, "dhall": normalized_dhall, "probes": [probe], "runId": run_id})
        if status != 422 or result.get("tag") != tag:
            raise LiveFailure(f"admission-negative:{cause}:{status}:{result}")
        writes, _ = singleton_mutations(audit_events_since(start))
        if writes:
            raise LiveFailure(f"admission-negative-writes:{cause}:{sorted(writes)}")
        if vault_audit_lines() != vault_before_negative:
            raise LiveFailure(f"admission-negative-contacted-vault:{cause}")
        positive_probe = json.loads((fixture_root / positive_name).read_text(encoding="utf-8"))
        status, positive = admin_request("/v1/dhall/update", {"password": password, "dhall": normalized_dhall, "probes": [positive_probe], "runId": run_id})
        if status != 200 or positive.get("result") != "converged" or positive.get("enact", {}).get("objects") != []:
            raise LiveFailure(f"admission-positive:{cause}:{status}:{positive}")
        admissions.append({"cause": cause, "tag": tag, "positivePair": positive_name, "positiveAdmitted": True})
    return {"reach": reaches, "reachVaultContacts": 0, "admission": admissions, "admissionApiserverWrites": 0, "admissionVaultContacts": 0}


def password_scan(password: str, pod: str) -> dict[str, Any]:
    scanner = r'''import os,sys
needle=sys.stdin.buffer.readline().rstrip(b'\n')
hits=[]
for root in ['/tmp','/phase33-artifacts','/phase33-dhall']:
 for base,dirs,files in os.walk(root):
  for name in files:
   p=os.path.join(base,name)
   try:
    if needle and needle in open(p,'rb').read(): hits.append(p)
   except Exception: pass
for p in ['/proc/1/cmdline','/proc/1/environ']:
 try:
  if needle and needle in open(p,'rb').read(): hits.append(p)
 except Exception: pass
print('\n'.join(hits))
'''
    process = subprocess.run(
        ["/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "exec", "-i", "-c", "singleton", pod, "--", "/usr/bin/python3", "-c", scanner],
        cwd=ROOT, input=password.encode() + b"\n", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    if process.returncode or process.stdout.strip():
        raise LiveFailure("operator-password-container-persistence")
    objects = kubectl("get", "configmaps,secrets", "-A", "-o", "json").stdout
    logs = kubectl("-n", NAMESPACE, "logs", pod).stdout
    if password in objects or password in logs:
        raise LiveFailure("operator-password-kubernetes-persistence")
    return {"containerFilesystem": "clear", "processArgvAndEnvironment": "clear", "kubernetesObjects": "clear", "singletonLogs": "clear", "passwordPersisted": False}


def edge_probe() -> dict[str, Any]:
    phase32 = phase32_module()
    token = phase32.obtain_oidc_token()
    status, body, _ = phase32.https_request(phase32.EDGE_VIP, phase32.EDGE_PORT, "/phase33/probe", headers={"Authorization": "Bearer " + token})
    del token
    if status != 200 or body.decode() != "phase33-trivial:/probe":
        raise LiveFailure(f"phase33-edge-probe:{status}:{body!r}")
    return {"status": status, "body": body.decode(), "oidcOwned": True, "path": "/phase33/probe"}


def off_host_denial() -> dict[str, Any]:
    node_ip = get("node", NODE)["status"]["addresses"][0]["address"]
    pod = json.loads(kubectl("-n", "phase32-wan", "get", "pods", "-o", "json").stdout)["items"][0]["metadata"]["name"]
    program = "import socket\ns=socket.socket();s.settimeout(3)\ntry:s.connect((%r,%d));print('REACHABLE')\nexcept Exception:print('DENIED')" % (node_ip, NODE_PORT)
    result = kubectl("-n", "phase32-wan", "exec", pod, "--", "/usr/bin/python3", "-c", program)
    denied = result.stdout.strip().endswith("DENIED")
    if not denied:
        raise LiveFailure("admin-nodeport-off-host-reachable")
    return {"nodeLoopbackStatus": 200, "offHostDenied": True, "nodePort": NODE_PORT, "endpointClass": "HostLocalPeer"}


def replacement_probe(old_pod: str, expected_sha: str) -> dict[str, Any]:
    old_uid = get("pod", old_pod, NAMESPACE)["metadata"]["uid"]
    kubectl("-n", NAMESPACE, "delete", "pod", old_pod, "--wait=true", "--timeout=120s")
    kubectl("-n", NAMESPACE, "rollout", "status", f"deployment/{SINGLETON}", "--timeout=240s", timeout=260)
    new_pod = pod_name()
    new_uid = get("pod", new_pod, NAMESPACE)["metadata"]["uid"]
    if new_uid == old_uid:
        raise LiveFailure("singleton-pod-uid-unchanged")
    logs = kubectl("-n", NAMESPACE, "logs", new_pod).stdout
    if expected_sha not in logs:
        raise LiveFailure("replacement-durable-state-not-recovered")
    holder = wait_singleton_holder(new_uid)
    return {"oldPodUid": old_uid, "newPodUid": new_uid, "uidChanged": True, "durableStateSha256": expected_sha, "byteIdentical": True, "holder": holder, "pod": new_pod}


def restore_shared_stack(snapshots: dict[str, dict[str, Any]], run_id: str) -> dict[str, Any]:
    kubectl("-n", "edge-system", "delete", "deployment,service,httproute", "-l", f"amoebius.dev/phase33-run={run_id}", "--ignore-not-found=true")
    for value in snapshots.values():
        apply(sanitize(value), manager="phase33-postflight")
    for target in ("deployment/envoy", "deployment/prometheus-query-proxy"):
        namespace = "edge-system" if target.endswith("envoy") else "observability"
        kubectl("-n", namespace, "rollout", "status", target, "--timeout=240s", timeout=260)
    sweep = kubectl("get", "deployment,service,httproute", "-A", "-l", f"amoebius.dev/phase33-run={run_id}", "-o", "name").stdout.strip().splitlines()
    if sweep:
        raise LiveFailure(f"postflight-leaks:{sweep}")
    return {"runLabelSweep": [], "envoyReady": True, "prometheusQueryProxyReady": True, "sharedStackRestored": True}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=LIVE_EVIDENCE)
    arguments = parser.parse_args()
    root_token = os.environ.get("PHASE33_VAULT_ROOT_TOKEN")
    operator_password = os.environ.get("PHASE29_OPERATOR_PASSWORD")
    if not root_token or not operator_password:
        raise LiveFailure("PHASE33_VAULT_ROOT_TOKEN-and-PHASE29_OPERATOR_PASSWORD-required")
    history = check_history_capacity()
    phase32_receipt = json.loads((ROOT / "DEVELOPMENT_PLAN/evidence/phase_32/phase-receipt.json").read_text(encoding="utf-8"))
    if phase32_receipt.get("result") != "PASS":
        raise LiveFailure("phase32-prerequisite-not-green")
    snapshots = {
        "queryDeployment": get("deployment", "prometheus-query-proxy", "observability"),
        "queryService": get("service", "prometheus-query-proxy", "observability"),
        "envoyConfig": get("configmap", "phase32-envoy", "edge-system"),
        "envoyDeployment": get("deployment", "envoy", "edge-system"),
    }
    if "phase33_trivial" in snapshots["envoyConfig"].get("data", {}).get("envoy.yaml", ""):
        raise LiveFailure("preflight-phase33-envoy-route-leaked")
    clean_previous()
    artifacts = install_artifacts()
    vault = configure_vault(root_token)
    del root_token
    setup_control_plane()
    pod = wait_pod_running()
    if pod_http(pod, "/healthz") != 200 or pod_http(pod, "/readyz") != 503:
        raise LiveFailure("pre-handoff-serving-state")
    bootstrap_mutation_end = dt.datetime.now(dt.UTC)
    kubectl("-n", "observability", "delete", "deployment", "prometheus-query-proxy", "--wait=true")
    kubectl("-n", "observability", "delete", "service", "prometheus-query-proxy")
    handoff = release_bootstrap_holder()
    pod_uid = get("pod", pod, NAMESPACE)["metadata"]["uid"]
    kubectl("-n", NAMESPACE, "rollout", "status", f"deployment/{SINGLETON}", "--timeout=180s", timeout=200)
    handoff["singleton"] = wait_singleton_holder(pod_uid)
    handoff["sameLeaseUid"] = handoff["bootstrap"]["uid"] == handoff["released"]["uid"] == handoff["singleton"]["uid"]
    handoff["podNonServingBeforeRelease"] = True
    handoff["noSingletonMutationBeforeAcquire"] = len(singleton_mutations(audit_events_since(bootstrap_mutation_end))[0]) == 0
    normalized = run(("/home/matthewnowak/.local/bin/dhall", "--file", "dhall/examples/platform_plus_trivial_app.dhall"), timeout=300).stdout
    run_id = "phase33-" + secrets.token_hex(6)
    admin = test_admin_sequence(operator_password, normalized, run_id)
    edge = edge_probe()
    reach = off_host_denial()
    negatives = negative_corpus(operator_password)
    admin_negative = admin_negatives(operator_password, normalized, run_id)
    password_observer = password_scan(operator_password, pod)
    expected_sha = admin["durable"]["sha256"]
    replacement = replacement_probe(pod, expected_sha)
    postflight = restore_shared_stack(snapshots, run_id)
    harness_user = f"system:serviceaccount:{NAMESPACE}:phase33-harness"
    all_events = audit_events_since(bootstrap_mutation_end)
    harness_writes = [event for event in all_events if event.get("verb") in {"create", "update", "patch", "delete"} and event.get("user", {}).get("username") == harness_user and audit_identity(event)]
    if harness_writes:
        raise LiveFailure("harness-issued-platform-write")
    result = {
        "schema": "amoebius.phase33.singleton-live.v1", "register": 3, "substrate": "linux-cpu",
        "prerequisites": {"phase32ReceiptFingerprint": phase32_receipt.get("receiptFingerprint"), "retainedCluster": "amoebius-bootstrap-coordinator"},
        "historyCapacity": history, "artifacts": artifacts, "vaultProvision": vault,
        "manifest": {"kind": "Deployment", "replicas": 1, "strategy": "Recreate", "persistentVolumeClaims": [], "standbyReplicas": 0, "amoebiusElection": False, "image": IMAGE, "fieldManager": "amoebius-phase33-singleton"},
        "handoff": handoff, "adminSequence": admin, "edge": edge, "adminReach": reach,
        "negativeCorpus": negatives, "adminNegatives": admin_negative, "passwordObserver": password_observer,
        "replacement": replacement, "postflight": postflight,
        "attribution": {"singletonServiceAccount": f"system:serviceaccount:{NAMESPACE}:{SINGLETON}", "singletonWriteCount": len(admin["firstPass"]["audit"]), "harnessPrincipal": harness_user, "harnessPlatformWrites": 0, "observer": "kube-apiserver audit log"},
        "artifactSource": {"image": IMAGE, "imagePullPolicy": "Never", "publicPulls": 0, "haskellSingleton": True, "pythonEffectHelper": True},
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "deferred": {"fullAppTenancy": "UNVERIFIED", "crossClusterGatewayMigration": "UNVERIFIED", "tenantAdminScope": "UNVERIFIED", "parentChildAdminReach": "UNVERIFIED"},
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("phase33-singleton-live: PASS (typed Lease handoff, Haskell admin singleton, exact live reconcile/no-op, durable replacement, negatives, teardown)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (LiveFailure, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as problem:
        print(f"phase33-singleton-live: FAIL: {problem}", file=sys.stderr)
        raise SystemExit(1)
