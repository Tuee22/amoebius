#!/usr/bin/env python3
"""Live enforcing-firewall, negative-control, and in-cluster pull gate."""

from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import ipaddress
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
NODE = "amoebius-bootstrap-coordinator-control-plane"
KUBECONFIG = Path(os.environ.get(
    "AMOEBIUS_KUBECONFIG",
    str(ROOT / ".build/tmp/base-image-registry/unconfigured-kubeconfig"),
))
KUBECTL = os.environ.get("AMOEBIUS_KUBECTL", "/usr/bin/kubectl")
FIXTURE = ROOT / "test/fixture/base_image_registry/public_registry_endpoints.txt"
EXPECTED_FAILURE = ROOT / "test/fixture/base_image_registry/expected_pull_failure.txt"
NAMESPACE = "amoebius-base-image-registry-gate"
MUTANT_NAMESPACE = "amoebius-base-image-registry-mutant"
BUSYBOX = "docker.io/library/busybox:1.36.1"
IN_CLUSTER_REPOSITORY = "registry.amoebius.invalid:5000/amoebius/base"
FIREWALL_COMMENT = "amoebius-base-image-registry-public-registry-deny"
PCAP = Path(os.environ.get(
    "AMOEBIUS_RUN_TMP",
    str(ROOT / ".build/tmp/base-image-registry"),
)) / "private-pull.pcap"


class GateFailure(RuntimeError):
    pass


def load_standup() -> Any:
    path = ROOT / "tools/base_image_registry_standup.py"
    spec = importlib.util.spec_from_file_location("base_image_registry_standup_gate", path)
    if spec is None or spec.loader is None:
        raise GateFailure("standup-module-load")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


STANDUP = load_standup()


def run(
    arguments: Sequence[str],
    *,
    stdin: str | None = None,
    check: bool = True,
    timeout: int = 120,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
        text=True,
        input=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=timeout,
    )
    if check and result.returncode:
        raise GateFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def docker_exec(*arguments: str, check: bool = True, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return run(("/usr/bin/docker", "exec", NODE, *arguments), check=check, timeout=timeout)


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments),
        stdin=stdin,
        check=check,
        timeout=180,
    )


def namespace_absent(name: str) -> None:
    kubectl("delete", "namespace", name, "--ignore-not-found", "--wait=true", "--timeout=120s")
    for _ in range(120):
        if not kubectl("get", "namespace", name, check=False).returncode == 0:
            return
        time.sleep(1)
    raise GateFailure(f"namespace-delete-timeout:{name}")


def apply(objects: list[dict[str, Any]]) -> None:
    payload = { "apiVersion": "v1", "kind": "List", "items": objects }
    kubectl("apply", "--server-side", "--field-manager=amoebius-base-image-registry-gate", "-f", "-", stdin=json.dumps(payload))


def pod(name: str, image: str, command: list[str]) -> dict[str, Any]:
    return {
        "apiVersion": "v1",
        "kind": "Pod",
        "metadata": {
            "name": name,
            "namespace": NAMESPACE,
            "labels": {"amoebius.io/gate": "phase25"},
        },
        "spec": {
            "restartPolicy": "Never",
            "automountServiceAccountToken": False,
            "nodeName": NODE,
            "containers": [
                {
                    "name": "probe",
                    "image": image,
                    "imagePullPolicy": "Always",
                    "command": command,
                    "resources": {
                        "requests": {
                            "cpu": "10m",
                            "memory": "16Mi",
                            "ephemeral-storage": "16Mi",
                        },
                        "limits": {
                            "cpu": "100m",
                            "memory": "64Mi",
                            "ephemeral-storage": "64Mi",
                        },
                    },
                    "securityContext": {
                        "allowPrivilegeEscalation": False,
                        "capabilities": {"drop": ["ALL"]},
                    },
                }
            ],
        },
    }


def wait_phase(namespace: str, name: str, accepted: set[str], timeout: int) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    last: dict[str, Any] = {}
    while time.monotonic() < deadline:
        result = kubectl("-n", namespace, "get", "pod", name, "-o", "json", check=False)
        if result.returncode == 0:
            last = json.loads(result.stdout)
            phase = str(last.get("status", {}).get("phase", ""))
            if phase in accepted:
                return last
            statuses = last.get("status", {}).get("containerStatuses", [])
            waiting = [
                str(row.get("state", {}).get("waiting", {}).get("reason", ""))
                for row in statuses
            ]
            if any(reason in accepted for reason in waiting):
                return last
        time.sleep(2)
    raise GateFailure(f"pod-phase-timeout:{namespace}/{name}:{last.get('status', {})}")


def image_rows() -> list[str]:
    return docker_exec(
        "/usr/local/bin/ctr",
        "--namespace",
        "k8s.io",
        "images",
        "list",
        "--quiet",
    ).stdout.splitlines()


def run_networkpolicy_mutant() -> dict[str, Any]:
    before = [row for row in image_rows() if "busybox" in row]
    if before:
        raise GateFailure(f"busybox-preexisting:{before}")
    namespace_absent(MUTANT_NAMESPACE)
    objects = [
        {
            "apiVersion": "v1",
            "kind": "Namespace",
            "metadata": {"name": MUTANT_NAMESPACE},
        },
        {
            "apiVersion": "networking.k8s.io/v1",
            "kind": "NetworkPolicy",
            "metadata": {"name": "deny-all-egress", "namespace": MUTANT_NAMESPACE},
            "spec": {
                "podSelector": {},
                "policyTypes": ["Egress"],
                "egress": [],
            },
        },
        {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {"name": "public-pull-mutant", "namespace": MUTANT_NAMESPACE},
            "spec": {
                "restartPolicy": "Never",
                "nodeName": NODE,
                "containers": [
                    {
                        "name": "probe",
                        "image": BUSYBOX,
                        "imagePullPolicy": "Always",
                        "command": ["/bin/sh", "-c", "echo public-pull-mutant-succeeded"],
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "8Mi", "ephemeral-storage": "8Mi"},
                            "limits": {"cpu": "100m", "memory": "32Mi", "ephemeral-storage": "32Mi"},
                        },
                    }
                ],
            },
        },
    ]
    apply(objects)
    observed = wait_phase(MUTANT_NAMESPACE, "public-pull-mutant", {"Succeeded", "Failed"}, 300)
    phase = str(observed["status"]["phase"])
    if phase != "Succeeded":
        raise GateFailure(f"noop-policy-mutant-did-not-survive:{observed['status']}")
    image_id = str(observed["status"]["containerStatuses"][0].get("imageID", ""))
    namespace_absent(MUTANT_NAMESPACE)
    task_rows = [row for row in image_rows() if "busybox" in row]
    for row in task_rows:
        docker_exec(
            "/usr/local/bin/ctr",
            "--namespace",
            "k8s.io",
            "images",
            "remove",
            row,
        )
    if any("busybox" in row for row in image_rows()):
        raise GateFailure("task-busybox-image-reference-not-removed")
    return {
        "mechanism": "kindnet-NetworkPolicy",
        "podPhase": phase,
        "imageId": image_id,
        "expectedOracle": "PublicPullCanaryUnexpectedlySucceeded",
        "result": "RED",
        "removedTaskImageReferences": task_rows,
    }


def resolve_endpoints() -> dict[str, list[str]]:
    endpoints = [
        line.strip()
        for line in FIXTURE.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    result: dict[str, list[str]] = {}
    for endpoint in endpoints:
        resolved = docker_exec("/usr/bin/getent", "ahostsv4", endpoint, check=False)
        addresses = sorted(
            {
                line.split()[0]
                for line in resolved.stdout.splitlines()
                if line.split() and isinstance(ipaddress.ip_address(line.split()[0]), ipaddress.IPv4Address)
            }
        )
        if not addresses:
            raise GateFailure(f"endpoint-unresolved:{endpoint}:{resolved.stdout}")
        result[endpoint] = addresses
    return result


def remove_public_firewall() -> None:
    listed = docker_exec("/usr/sbin/iptables", "-S").stdout
    for line in listed.splitlines():
        if FIREWALL_COMMENT not in line:
            continue
        arguments = shlex.split(line)
        if not arguments or arguments[0] != "-A":
            raise GateFailure(f"public-firewall-rule-shape:{line}")
        arguments[0] = "-D"
        docker_exec("/usr/sbin/iptables", *arguments)


def install_public_firewall(endpoints: dict[str, list[str]]) -> int:
    remove_public_firewall()
    addresses = sorted({address for rows in endpoints.values() for address in rows})
    comment = ("-m", "comment", "--comment", FIREWALL_COMMENT)
    for address in reversed(addresses):
        for chain in ("OUTPUT", "FORWARD"):
            docker_exec(
                "/usr/sbin/iptables",
                "-I",
                chain,
                "1",
                "-d",
                address,
                "-p",
                "tcp",
                "-m",
                "multiport",
                "--dports",
                "80,443",
                *comment,
                "-j",
                "DROP",
            )
    return len(addresses) * 2


def firewall_counters() -> dict[str, int]:
    saved = docker_exec("/usr/sbin/iptables-save", "-c").stdout
    packets = 0
    bytes_count = 0
    rules = 0
    for line in saved.splitlines():
        if FIREWALL_COMMENT not in line:
            continue
        match = re.match(r"\[(\d+):(\d+)\]", line)
        if not match:
            raise GateFailure(f"firewall-counter-shape:{line}")
        packets += int(match.group(1))
        bytes_count += int(match.group(2))
        rules += 1
    return {"rules": rules, "packets": packets, "bytes": bytes_count}


def write_node_file(path: str, contents: str, *, append: bool = False) -> None:
    command = ("/usr/bin/docker", "exec", "-i", NODE, "/usr/bin/tee")
    if append:
        command += ("--append",)
    command += (path,)
    result = run(command, stdin=contents)
    if result.stdout != contents:
        raise GateFailure(f"node-file-write-readback:{path}")


def configure_in_cluster_registry() -> dict[str, Any]:
    service = json.loads(
        kubectl(
            "-n",
            "amoebius-bootstrap",
            "get",
            "service",
            "distribution-read",
            "-o",
            "json",
        ).stdout
    )
    cluster_ip = str(service["spec"]["clusterIP"])
    config = docker_exec("/usr/bin/sed", "-n", "1,220p", "/etc/containerd/config.toml").stdout
    registry_stanza = (
        '\n[plugins."io.containerd.grpc.v1.cri".registry]\n'
        '  config_path = "/etc/containerd/certs.d"\n'
    )
    if "config_path = \"/etc/containerd/certs.d\"" not in config:
        docker_exec(
            "/usr/bin/cp",
            "--preserve=mode,ownership,timestamps",
            "/etc/containerd/config.toml",
            "/etc/containerd/config.toml.amoebius-base-image-registry-before",
        )
        write_node_file("/etc/containerd/config.toml", registry_stanza, append=True)
    docker_exec("/usr/bin/mkdir", "-p", "/etc/containerd/certs.d/registry.amoebius.invalid:5000")
    hosts = (
        f'server = "http://{cluster_ip}:5000"\n\n'
        f'[host."http://{cluster_ip}:5000"]\n'
        '  capabilities = ["pull", "resolve"]\n'
        "  skip_verify = true\n"
    )
    write_node_file(
        "/etc/containerd/certs.d/registry.amoebius.invalid:5000/hosts.toml",
        hosts,
    )
    docker_exec("/usr/bin/systemctl", "restart", "containerd")
    for _ in range(60):
        if docker_exec("/usr/bin/systemctl", "is-active", "containerd", check=False).stdout.strip() == "active":
            break
        time.sleep(1)
    else:
        raise GateFailure("containerd-restart-timeout")
    for _ in range(90):
        ready = kubectl(
            "get",
            "node",
            NODE,
            "-o",
            "jsonpath={.status.conditions[?(@.type=='Ready')].status}",
            check=False,
        )
        if ready.stdout.strip() == "True":
            break
        time.sleep(1)
    else:
        raise GateFailure("node-not-ready-after-registry-wiring")
    dump = docker_exec("/usr/local/bin/containerd", "config", "dump").stdout
    if "config_path = '/etc/containerd/certs.d'" not in dump:
        raise GateFailure("containerd-registry-config-path-not-active")
    return {
        "registryHost": "registry.amoebius.invalid:5000",
        "serviceClusterIp": cluster_ip,
        "configPath": "/etc/containerd/certs.d",
        "hostsFile": "/etc/containerd/certs.d/registry.amoebius.invalid:5000/hosts.toml",
        "containerdActive": True,
        "nodeReady": True,
    }


def start_capture() -> subprocess.Popen[bytes]:
    PCAP.parent.mkdir(parents=True, exist_ok=True)
    if PCAP.exists():
        run(("/usr/bin/sudo", "-n", "/usr/bin/rm", "-f", "--", str(PCAP)))
    process = subprocess.Popen(
        (
            "/usr/bin/sudo",
            "-n",
            "/usr/bin/tcpdump",
            "-i",
            "any",
            "-nn",
            "-U",
            "-w",
            str(PCAP),
            "tcp",
        ),
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    time.sleep(1)
    if process.poll() is not None:
        error = process.stderr.read().decode("utf-8", "replace") if process.stderr else ""
        raise GateFailure(f"tcpdump-start:{process.returncode}:{error}")
    return process


def stop_capture(process: subprocess.Popen[bytes]) -> str:
    process.send_signal(signal.SIGINT)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)
    return run(("/usr/bin/tcpdump", "-nn", "-r", str(PCAP))).stdout


def registry_logs() -> str:
    return kubectl(
        "-n",
        "amoebius-bootstrap",
        "logs",
        "deployment/distribution",
        "-c",
        "distribution",
    ).stdout


def negative_observation(pod_value: dict[str, Any]) -> tuple[str, list[dict[str, str]]]:
    statuses = pod_value.get("status", {}).get("containerStatuses", [])
    waiting_reason = ""
    if statuses:
        waiting_reason = str(statuses[0].get("state", {}).get("waiting", {}).get("reason", ""))
    events = json.loads(
        kubectl(
            "-n",
            NAMESPACE,
            "get",
            "events",
            "--field-selector",
            "involvedObject.name=public-pull-canary",
            "-o",
            "json",
        ).stdout
    )
    rows = [
        {
            "reason": str(item.get("reason", "")),
            "message": str(item.get("message", "")),
        }
        for item in events["items"]
    ]
    if waiting_reason not in {"ErrImagePull", "ImagePullBackOff"}:
        raise GateFailure(f"public-canary-reason:{waiting_reason}:{rows}")
    messages = " | ".join(row["message"].lower() for row in rows)
    if not any(marker in messages for marker in ("timeout", "deadline exceeded", "i/o timeout")):
        raise GateFailure(f"public-canary-not-timeout:{rows}")
    return waiting_reason, rows


def established_public_connections(packet_text: str, addresses: set[str]) -> tuple[int, int]:
    attempts = 0
    established = 0
    for line in packet_text.splitlines():
        if not any(address in line for address in addresses):
            continue
        if "Flags [S]" in line:
            attempts += 1
        if "Flags [S.]" in line:
            established += 1
    return attempts, established


def run_enforced_gate(
    endpoints: dict[str, list[str]], firewall_rules: int, index_digest: str
) -> dict[str, Any]:
    namespace_absent(NAMESPACE)
    namespace = {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE}}
    in_cluster_image = f"{IN_CLUSTER_REPOSITORY}@{index_digest}"
    positive = pod(
        "in-cluster-pull-canary",
        in_cluster_image,
        ["/usr/bin/redis-cli", "--version"],
    )
    negative = pod(
        "public-pull-canary",
        BUSYBOX,
        ["/bin/sh", "-c", "echo public-pull-unexpectedly-succeeded"],
    )
    journal_since = dt.datetime.now(dt.timezone.utc).isoformat()
    logs_before = registry_logs()
    counters_before = firewall_counters()
    capture = start_capture()
    try:
        apply([namespace, positive, negative])
        positive_observed = wait_phase(NAMESPACE, "in-cluster-pull-canary", {"Succeeded", "Failed"}, 300)
        if positive_observed["status"]["phase"] != "Succeeded":
            raise GateFailure(f"in-cluster-pull-failed:{positive_observed['status']}")
        negative_observed = wait_phase(
            NAMESPACE,
            "public-pull-canary",
            {"ErrImagePull", "ImagePullBackOff", "Succeeded"},
            300,
        )
        if negative_observed.get("status", {}).get("phase") == "Succeeded":
            raise GateFailure("public-pull-canary-unexpectedly-succeeded")
        waiting_reason, events = negative_observation(negative_observed)
        time.sleep(2)
    finally:
        packet_text = stop_capture(capture)
    counters_after = firewall_counters()
    dropped = counters_after["packets"] - counters_before["packets"]
    if counters_after["rules"] != firewall_rules or dropped <= 0:
        raise GateFailure(f"firewall-unexercised:{counters_before}:{counters_after}:{firewall_rules}")
    addresses = {address for rows in endpoints.values() for address in rows}
    attempted, established = established_public_connections(packet_text, addresses)
    if established != 0:
        raise GateFailure(f"public-registry-connection-established:{established}")
    statuses = positive_observed["status"]["containerStatuses"]
    image_id = str(statuses[0].get("imageID", ""))
    if index_digest not in image_id:
        raise GateFailure(f"in-cluster-image-id:{image_id}")
    logs_after = registry_logs()
    registry_delta = logs_after[len(logs_before):] if logs_after.startswith(logs_before) else logs_after
    if index_digest not in registry_delta or "ns=registry.amoebius.invalid%3A5000" not in registry_delta:
        raise GateFailure("in-cluster-registry-read-not-observed")
    journal = docker_exec(
        "journalctl",
        "-u",
        "containerd",
        "--since",
        journal_since,
        "--no-pager",
    ).stdout
    if "busybox" not in journal or not any(
        marker in journal.lower() for marker in ("timeout", "deadline exceeded", "i/o timeout")
    ):
        raise GateFailure("containerd-negative-control-not-observed")
    result = {
        "positive": {
            "phase": positive_observed["status"]["phase"],
            "image": in_cluster_image,
            "imageId": image_id,
            "registryReadObserved": True,
        },
        "negative": {
            "waitingReason": waiting_reason,
            "image": BUSYBOX,
            "events": events,
            "containerdTimeoutObserved": True,
        },
        "firewall": {
            "mechanism": "node-iptables-ip-cidr-drop",
            "ruleCount": counters_after["rules"],
            "droppedPackets": dropped,
            "droppedBytes": counters_after["bytes"] - counters_before["bytes"],
        },
        "observer": {
            "capturedPackets": len(packet_text.splitlines()),
            "publicSynAttemptsCaptured": attempted,
            "publicEstablishedConnections": established,
        },
    }
    namespace_absent(NAMESPACE)
    return result


def gate(evidence: Path, index_digest: str) -> dict[str, Any]:
    STANDUP.observe_backend_firewall()
    publication = json.loads((evidence / "publication.json").read_text(encoding="utf-8"))
    standup = json.loads((evidence / "standup.json").read_text(encoding="utf-8"))
    if publication["rerunMutatingRequests"] != 0:
        raise GateFailure("publication-rerun-mutated")
    remove_public_firewall()
    mutant = run_networkpolicy_mutant()
    endpoints = resolve_endpoints()
    firewall_rules = install_public_firewall(endpoints)
    wiring = configure_in_cluster_registry()
    enforced = run_enforced_gate(endpoints, firewall_rules, index_digest)
    return {
        "schema": "amoebius.phase25.sprint25.4-no-public-pull.v1",
        "capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "substrate": "linux-cpu",
        "register": 3,
        "endpointFixture": str(FIXTURE.relative_to(ROOT)),
        "expectedFailureFixture": EXPECTED_FAILURE.read_text(encoding="utf-8").splitlines(),
        "resolvedEndpoints": endpoints,
        "mutant": mutant,
        "registryWiring": wiring,
        "enforced": enforced,
        "standupPublicRegistryTcpConnections": standup["publicRegistryTcpConnections"],
        "publicationPublicRegistryTcpConnections": publication["publicRegistryTcpConnections"],
        "publicationRerunMutatingRequests": publication["rerunMutatingRequests"],
        "indexDigest": index_digest,
    }


def verify_current(evidence: Path, index_digest: str) -> dict[str, Any]:
    recorded = json.loads((evidence / "private-pull.json").read_text(encoding="utf-8"))
    endpoints = resolve_endpoints()
    firewall_rules = install_public_firewall(endpoints)
    wiring = configure_in_cluster_registry()
    enforced = run_enforced_gate(endpoints, firewall_rules, index_digest)
    return {
        "schema": "amoebius.phase25.sprint25.4-current-verification.v1",
        "verifiedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "resolvedEndpoints": endpoints,
        "registryWiring": wiring,
        "enforced": enforced,
        "standupPublicRegistryTcpConnections": recorded["standupPublicRegistryTcpConnections"],
        "publicationPublicRegistryTcpConnections": recorded["publicationPublicRegistryTcpConnections"],
        "publicationRerunMutatingRequests": recorded["publicationRerunMutatingRequests"],
        "indexDigest": index_digest,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    # The bundle holding this run's prior-sprint observations is supplied by the caller.
    # There is deliberately no default: a default names a location, and whatever a previous
    # run left there would decide this gate instead of the run in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    # The digest is the caller's for the same reason: the canary must pull the index this
    # run built, never a constant pinning a build that no longer exists.
    parser.add_argument("--index-digest", required=True, help="the index digest this run produced")
    arguments = parser.parse_args(argv)
    try:
        result = (
            verify_current(arguments.evidence, arguments.index_digest)
            if arguments.verify_only
            else gate(arguments.evidence, arguments.index_digest)
        )
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.output is None:
            print(encoded, end="")
        else:
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(encoded, encoding="utf-8")
        label = "phase25-no-public-pull-verify" if arguments.verify_only else "phase25-no-public-pull-gate"
        print(
            f"{label}: PASS "
            f"({result['enforced']['firewall']['droppedPackets']} denied packets; {result['indexDigest']})"
        )
        return 0
    except (
        GateFailure,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-no-public-pull-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
