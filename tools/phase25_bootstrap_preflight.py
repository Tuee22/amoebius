#!/usr/bin/env python3
"""Read-only admission for the Phase-25.2 selected-image/registry transition."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import socket
import subprocess
from pathlib import Path
from typing import Any, Iterable, Sequence


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = Path("/var/tmp/amoebius-phase25-scratch/oci/amoebius-phase25.oci.tar")
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
NODE = "amoebius-phase24-control-plane"
IMAGE = "amoebius.invalid/amoebius-base:phase25"
PUBLIC_HOSTS = ("docker.io", "quay.io", "ghcr.io")


class PreflightFailure(RuntimeError):
    pass


def run(arguments: Sequence[str]) -> str:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False,
    )
    if result.returncode:
        raise PreflightFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result.stdout


def docker_exec(*arguments: str) -> str:
    return run(("/usr/bin/docker", "exec", NODE, *arguments))


def kubectl_json(*arguments: str) -> dict[str, Any]:
    decoded = json.loads(run(("/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), *arguments, "-o", "json")))
    if not isinstance(decoded, dict):
        raise PreflightFailure("kubectl-json-object")
    return decoded


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def quantity(value: str, axis: str) -> int:
    match = re.fullmatch(r"([0-9]+)([A-Za-z]+|m)?", value)
    if match is None:
        raise PreflightFailure(f"quantity:{axis}:{value}")
    number = int(match.group(1))
    suffix = match.group(2) or ""
    if axis == "cpu":
        if suffix == "m":
            return number
        if suffix == "":
            return number * 1000
        raise PreflightFailure(f"cpu-quantity:{value}")
    multipliers = {
        "": 1, "Ki": 1024, "Mi": 1024**2, "Gi": 1024**3,
        "K": 1000, "M": 1000**2, "G": 1000**3,
    }
    if suffix not in multipliers:
        raise PreflightFailure(f"byte-quantity:{value}")
    return number * multipliers[suffix]


def vector(resources: dict[str, Any]) -> dict[str, int]:
    return {
        "cpuMillis": quantity(str(resources.get("cpu", "0")), "cpu"),
        "memoryBytes": quantity(str(resources.get("memory", "0")), "bytes"),
        "ephemeralBytes": quantity(str(resources.get("ephemeral-storage", "0")), "bytes"),
    }


def plus(left: dict[str, int], right: dict[str, int]) -> dict[str, int]:
    return {key: left[key] + right[key] for key in left}


def maximum(left: dict[str, int], right: dict[str, int]) -> dict[str, int]:
    return {key: max(left[key], right[key]) for key in left}


def pod_resources(pod: dict[str, Any], locus: str) -> tuple[dict[str, int], dict[str, int]]:
    zero = {"cpuMillis": 0, "memoryBytes": 0, "ephemeralBytes": 0}
    spec = pod.get("spec", {})
    regular_requests = dict(zero)
    regular_limits = dict(zero)
    for container in spec.get("containers", []):
        resources = container.get("resources", {})
        regular_requests = plus(regular_requests, vector(resources.get("requests", {})))
        regular_limits = plus(regular_limits, vector(resources.get("limits", {})))
    init_requests = dict(zero)
    init_limits = dict(zero)
    for container in spec.get("initContainers", []):
        resources = container.get("resources", {})
        init_requests = maximum(init_requests, vector(resources.get("requests", {})))
        init_limits = maximum(init_limits, vector(resources.get("limits", {})))
    overhead = vector(spec.get("overhead", {}))
    effective_requests = plus(maximum(regular_requests, init_requests), overhead)
    effective_limits = plus(maximum(regular_limits, init_limits), overhead)
    if any(value < 0 for value in [*effective_requests.values(), *effective_limits.values()]):
        raise PreflightFailure(f"negative-resource:{locus}")
    return effective_requests, effective_limits


def current_allocations(pods: Iterable[dict[str, Any]]) -> tuple[dict[str, int], dict[str, int], int]:
    requests = {"cpuMillis": 0, "memoryBytes": 0, "ephemeralBytes": 0}
    limits = dict(requests)
    slots = 0
    for pod in pods:
        if pod.get("spec", {}).get("nodeName") != NODE:
            continue
        if pod.get("status", {}).get("phase") in {"Succeeded", "Failed"}:
            continue
        pod_request, pod_limit = pod_resources(pod, str(pod.get("metadata", {}).get("uid", "unknown")))
        requests = plus(requests, pod_request)
        limits = plus(limits, pod_limit)
        slots += 1
    return requests, limits, slots


def filesystem_observation() -> dict[str, Any]:
    host = run(("/usr/bin/findmnt", "-bno", "SOURCE,FSTYPE,SIZE,AVAIL,TARGET", "-T", "/var/lib/amoebius/phase24/unified")).strip().split()
    if len(host) != 5:
        raise PreflightFailure("host-filesystem-observation")
    node_rows = []
    for path in ("/var/lib/kubelet", "/var/lib/containerd"):
        fields = docker_exec("findmnt", "-bno", "SOURCE,FSTYPE,SIZE,AVAIL,TARGET", "-T", path).strip().split()
        if len(fields) != 5:
            raise PreflightFailure(f"node-filesystem-observation:{path}")
        node_rows.append({
            "path": path, "source": fields[0], "backingSource": fields[0].split("[", 1)[0],
            "type": fields[1], "sizeBytes": int(fields[2]), "availableBytes": int(fields[3]),
        })
    identities = {(row["backingSource"], row["type"], row["sizeBytes"], row["availableBytes"]) for row in node_rows}
    if len(identities) != 1:
        raise PreflightFailure("layout-alias-mismatch")
    return {
        "hostSource": host[0], "hostType": host[1], "sizeBytes": int(host[2]),
        "availableBytes": min(int(host[3]), *(row["availableBytes"] for row in node_rows)),
        "layout": "Unified", "nodeRoots": node_rows,
    }


def artifact_demand(evidence: Path) -> dict[str, Any]:
    artifact = json.loads((evidence / "image-artifact.json").read_text(encoding="utf-8"))
    platforms = [row for row in artifact["platforms"] if row["os"] == "linux" and row["architecture"] == "amd64"]
    if len(platforms) != 1:
        raise PreflightFailure("selected-platform-domain")
    platform = platforms[0]
    layer_bytes: dict[str, int] = {}
    snapshot_bytes: dict[str, int] = {}
    for layer in platform["layers"]:
        digest = str(layer["digest"])
        compressed = int(layer["compressedBytes"])
        if digest in layer_bytes and layer_bytes[digest] != compressed:
            raise PreflightFailure(f"selected-content-conflict:{digest}")
        layer_bytes[digest] = compressed
        chain = str(layer["chainId"])
        unpacked = int(layer["unpackedTarBytes"])
        if chain in snapshot_bytes and snapshot_bytes[chain] != unpacked:
            raise PreflightFailure(f"selected-snapshot-conflict:{chain}")
        snapshot_bytes[chain] = unpacked
    content = (
        int(artifact["imageIndexBytes"]) + int(platform["childManifestBytes"])
        + int(platform["configBytes"]) + sum(layer_bytes.values())
    )
    snapshots = sum(snapshot_bytes.values())
    workspace = int(platform["derivedPeakImportWorkspaceBytes"])
    return {
        "imageIndexDigest": artifact["imageIndexDigest"], "childDigest": platform["childDigest"],
        "contentBytes": content, "snapshotBytes": snapshots, "workspaceBytes": workspace,
        "peakBytes": content + snapshots + workspace, "layerCount": len(layer_bytes),
    }


def registry_demand(evidence: Path) -> dict[str, Any]:
    artifact = json.loads((evidence / "image-artifact.json").read_text(encoding="utf-8"))
    objects: dict[str, int] = {}
    for row in artifact["registryObjects"]:
        digest, size = str(row["digest"]), int(row["storedBytes"])
        if digest in objects and objects[digest] != size:
            raise PreflightFailure(f"registry-object-conflict:{digest}")
        objects[digest] = size
    stored = sum(objects.values())
    largest = max(objects.values())
    workspace = 2 * largest
    failed = 3 * min(largest, 1024**3)
    return {
        "objectCount": len(objects), "storedBytes": stored, "uploadConcurrency": 2,
        "workspaceModel": "largest-compressed-object-per-upload-v1", "workspaceBytes": workspace,
        "failedUploadModel": "three-one-gib-capped-partials-v1", "failedUploadBytes": failed,
        "gcHorizonSeconds": 3600, "peakBytes": stored + workspace + failed,
    }


def resolve_public_hosts() -> dict[str, list[str]]:
    return {host: sorted({row[4][0] for row in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)}) for host in PUBLIC_HOSTS}


def observe(evidence: Path, expected_archive_sha256: str) -> dict[str, Any]:
    if not ARTIFACT.is_file():
        raise PreflightFailure("artifact-absent")
    archive_sha = sha256_file(ARTIFACT)
    if archive_sha != expected_archive_sha256:
        raise PreflightFailure(f"artifact-sha256:{archive_sha}")
    node = kubectl_json("get", "node", NODE)
    pods = kubectl_json("get", "pods", "--all-namespaces")
    current_requests, current_limits, current_slots = current_allocations(pods.get("items", []))
    allocatable = node.get("status", {}).get("allocatable", {})
    node_supply = vector(allocatable)
    pod_supply = int(allocatable.get("pods", "0"))
    image = artifact_demand(evidence)
    registry = registry_demand(evidence)
    filesystem = filesystem_observation()
    registry_private = 512 * 1024**2
    proxy_ephemeral = 64 * 1024**2
    planned_requests = {
        "cpuMillis": 350,
        "memoryBytes": 384 * 1024**2,
        "ephemeralBytes": registry["peakBytes"] + registry_private + proxy_ephemeral,
    }
    planned_limits = {
        "cpuMillis": 750,
        "memoryBytes": 768 * 1024**2,
        "ephemeralBytes": registry["peakBytes"] + 1024**3 + 128 * 1024**2,
    }
    request_residual = {key: node_supply[key] - current_requests[key] for key in node_supply}
    # Kubernetes permits CPU/memory limit overcommit.  Phase 25 deliberately
    # uses the finite node-cgroup ceiling and current request debit instead.
    docker_limit = run(("/usr/bin/docker", "inspect", NODE, "--format", "{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}}")).strip().split()
    if len(docker_limit) != 2:
        raise PreflightFailure("node-cgroup-observation")
    cgroup_supply = {"cpuMillis": int(docker_limit[0]) // 1_000_000, "memoryBytes": int(docker_limit[1])}
    cgroup_residual = {
        "cpuMillis": max(0, cgroup_supply["cpuMillis"] - current_requests["cpuMillis"]),
        "memoryBytes": max(0, cgroup_supply["memoryBytes"] - current_requests["memoryBytes"]),
    }
    for key, required in planned_requests.items():
        if required > request_residual[key]:
            raise PreflightFailure(f"request-overdraw:{key}:{required}:{request_residual[key]}")
    if planned_limits["cpuMillis"] > cgroup_residual["cpuMillis"]:
        raise PreflightFailure(f"limit-overdraw:cpu:{planned_limits['cpuMillis']}:{cgroup_residual['cpuMillis']}")
    if planned_limits["memoryBytes"] > cgroup_residual["memoryBytes"]:
        raise PreflightFailure(f"limit-overdraw:memory:{planned_limits['memoryBytes']}:{cgroup_residual['memoryBytes']}")
    if current_slots + 2 > pod_supply:
        raise PreflightFailure(f"pod-slot-overdraw:{current_slots + 2}:{pod_supply}")
    transition = image["peakBytes"] + registry["peakBytes"]
    if transition > filesystem["availableBytes"]:
        raise PreflightFailure(f"filesystem-overdraw:{transition}:{filesystem['availableBytes']}")
    image_rows = docker_exec("/usr/local/bin/ctr", "--namespace", "k8s.io", "images", "list", "--quiet").splitlines()
    if IMAGE in image_rows:
        raise PreflightFailure("selected-image-already-resident")
    content = docker_exec("/usr/local/bin/ctr", "--namespace", "k8s.io", "content", "list", "--quiet").splitlines()
    snapshots = docker_exec("/usr/local/bin/ctr", "--namespace", "k8s.io", "snapshots", "list").splitlines()[1:]
    domain = run(("/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), "get", "namespace", "amoebius-bootstrap", "--ignore-not-found", "-o", "name")).strip()
    if domain:
        raise PreflightFailure("bootstrap-domain-already-present")
    result: dict[str, Any] = {
        "schema": "amoebius.phase25.bootstrap-preflight.v1",
        "archiveSha256": archive_sha,
        "artifact": image,
        "registry": registry,
        "filesystem": filesystem,
        "observedContentCount": len(content),
        "observedSnapshotCount": len(snapshots),
        "nodeSupply": node_supply,
        "currentRequests": current_requests,
        "currentLimits": current_limits,
        "requestResidual": request_residual,
        "nodeCgroupSupply": cgroup_supply,
        "nodeCgroupResidual": cgroup_residual,
        "plannedRequests": planned_requests,
        "plannedLimits": planned_limits,
        "podSlots": {"current": current_slots, "planned": 2, "supply": pod_supply},
        "pullPolicy": "Never",
        "publicEndpoints": resolve_public_hosts(),
    }
    fingerprint_source = json.dumps(result, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    result["fingerprint"] = "sha256:" + hashlib.sha256(fingerprint_source.encode()).hexdigest()
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    # The bundle this run reads its artifact observation from is supplied by the caller.
    # There is deliberately no default: a default names a location, and whatever a previous
    # run left there would decide this admission instead of the run in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    # The archive checksum is the one this run built, never a constant pinning a build that
    # no longer exists.
    parser.add_argument(
        "--expected-archive-sha256", required=True, help="the OCI archive checksum this run produced"
    )
    arguments = parser.parse_args()
    result = observe(arguments.evidence, arguments.expected_archive_sha256)
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if arguments.output is not None:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")


if __name__ == "__main__":
    main()
