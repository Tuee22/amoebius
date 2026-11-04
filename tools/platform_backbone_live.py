#!/usr/bin/env python3
"""Exercise the platform backbone in one project-contained private cluster fixture."""

from __future__ import annotations

import argparse
import contextlib
import copy
import concurrent.futures
import datetime
import base64
import hashlib
import hmac
import http.client
import ipaddress
import json
import os
import re
import queue
import threading
import secrets
import shutil
import socket
import struct
import subprocess
import sys
import tarfile
import time
import urllib.parse
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Any, Callable, Iterator, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import containment  # noqa: E402
import toolchain  # noqa: E402
import vault_pki_live as vault  # noqa: E402
import project_cluster_fixture  # noqa: E402
import retained_storage_backing as backing  # noqa: E402
import platform_backbone_hot_observer as hot_observer  # noqa: E402
import platform_backbone_service_census as service_census  # noqa: E402
import platform_backbone_zookeeper_observer as zookeeper_wire  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
KIND = ""
KUBECTL = ""
CABAL = ""
KUBECONFIG = Path(os.environ.get("AMOEBIUS_KUBECONFIG", ROOT / ".build/tmp/platform-backbone/unconfigured-kubeconfig"))
NODE = "amoebius-bootstrap-coordinator-control-plane"
IMAGE_ARCHIVE = Path()
IMAGE_DIGEST = ""
PRIVATE_IMAGE = ""
TEST_ROOT = Path(os.environ.get("AMOEBIUS_TEST_ROOT", ROOT / ".build/tmp/platform-backbone/unconfigured-test-root"))
RETAINED_ROOT = TEST_ROOT / "retained"
EVIDENCE = ROOT / ".build/tmp/platform-backbone/unconfigured-evidence.json"
KIND_CONFIG_TEMPLATE = ROOT / "test/fixture/platform_backbone/kind.yaml"
KIND_CONFIG = Path()
PLATFORM_NAMESPACE = "platform-system"
METALLB_NAMESPACE = "metallb-system"
PULSAR_NAMESPACE = "pulsar-system"
MINIO_ACCESS = ""
MINIO_SECRET = ""
REGISTRY_ACCESS = ""
REGISTRY_SECRET = ""
OFFLOAD_ACCESS = ""
OFFLOAD_SECRET = ""
MEMBERLIST_SECRET = ""
LOAD_BALANCER_ADDRESS = ""
LOAD_BALANCER_POOL = ""
MINIO_PORT = 19000
GATEWAY_S3_PORT = 19001
REGISTRY_PORT = 15030
MIB = 1024 * 1024
HOT_TIER_CAP = int((ROOT / "test/fixture/platform_backbone/hot-tier-cap.golden").read_text(encoding="utf-8").strip())
DEV_OFFLOADERS = False
PUBLIC_REGISTRY_TOKENS = ("docker.io/", "quay.io/", "ghcr.io/", "registry.k8s.io/")
APPLIED_OBJECTS: dict[tuple[str, str, str], dict[str, Any]] = {}
STORAGE_PLAN: dict[str, Any] = {}
PREPARED_VOLUMES: dict[str, dict[str, Any]] = {}
SERVICE_PLAN: dict[str, Any] = {}
EXECUTION_ADMISSION: dict[str, Any] = {}
NATIVE_BINARY: Path | None = None
NATIVE_STAGES: list[str] = []


class BackboneLiveFailure(RuntimeError):
    pass


def run(
    arguments: Sequence[str],
    *,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 600,
) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        message = f"{arguments}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}"
        for sensitive in (MINIO_ACCESS, MINIO_SECRET, REGISTRY_ACCESS, REGISTRY_SECRET, OFFLOAD_ACCESS, OFFLOAD_SECRET, MEMBERLIST_SECRET):
            if sensitive:
                message = message.replace(sensitive, "<redacted>")
        raise BackboneLiveFailure(message)
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def cabal_command(*arguments: str) -> tuple[str, ...]:
    command = (
        CABAL,
        f"--builddir={ROOT / '.build/dist-newstyle/platform-backbone'}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
    )
    compiler = os.environ.get("AMOEBIUS_GHC")
    if compiler:
        command = (*command, f"--with-compiler={compiler}")
    return (*command, "--jobs=1", *arguments)


def materialize_kind_config(output_root: Path) -> Path:
    template = KIND_CONFIG_TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "__RETAINED_MOUNTS__": str(RETAINED_ROOT / "mounts"),
        "__AMOEBIUS_BINARY__": str(TEST_ROOT / "runtime/amoebius"),
    }
    for marker, replacement in replacements.items():
        if template.count(marker) != 1:
            raise BackboneLiveFailure(f"kind-config-placeholder:{marker}:{template.count(marker)}")
        template = template.replace(marker, replacement)
    if "__" in template:
        raise BackboneLiveFailure("kind-config-unresolved-placeholder")
    target = output_root / "runtime/kind.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(template, encoding="utf-8")
    return target


def bootstrap_vault_predecessor() -> dict[str, Any]:
    """Materialize Phase 29's real readiness floor inside this run's private fixture."""
    vault.KIND = KIND
    vault.KUBECTL = KUBECTL
    vault.CABAL = CABAL
    vault.KUBECONFIG = KUBECONFIG
    vault.TEST_ROOT = TEST_ROOT
    vault.RETAINED_ROOT = RETAINED_ROOT
    vault.UNLOCK_ENVELOPE = RETAINED_ROOT / "vault-unlock.age"
    vault.KIND_CONFIG = KIND_CONFIG
    vault.IMAGE_ARCHIVE = IMAGE_ARCHIVE
    vault.IMAGE_DIGEST = IMAGE_DIGEST
    vault.PRIVATE_IMAGE = PRIVATE_IMAGE
    observation = vault.execute(additional_volumes=STORAGE_PLAN["inventory"],
                                additional_usable_bytes={row["name"]: row["requiredUsableBytes"]
                                                         for row in STORAGE_PLAN["volumes"]},
                                pool_capacity_bytes=STORAGE_PLAN["poolCapacityBytes"],
                                after_ready=configure_backbone_vault)
    PREPARED_VOLUMES.update(observation["storage"]["additionalRetainedVolumes"])
    target = EVIDENCE.parent / "vault-readiness-floor.json"
    target.write_text(json.dumps(observation, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {
        "schema": observation.get("schema"),
        "vaultClusterId": observation.get("initOnce", {}).get("vaultClusterIdStable"),
        "pkiRootStable": observation.get("pki", {}).get("sameRootAfterRecreate"),
        "observation": str(target),
    }


def configure_backbone_vault(token: str) -> None:
    vault.require_api("POST", "secret/data/phase30/minio", token,
                      {"data": {"access-key": MINIO_ACCESS, "secret-key": MINIO_SECRET}})
    for suffix, access, secret in (("registry", REGISTRY_ACCESS, REGISTRY_SECRET),
                                   ("pulsar-offload", OFFLOAD_ACCESS, OFFLOAD_SECRET)):
        vault.require_api("POST", "secret/data/phase30/writers/" + suffix, token,
                          {"data": {"access-key": access, "secret-key": secret}})
    roles = [
        ("amoebius-minio-server", "minio-server", PLATFORM_NAMESPACE, ["phase30/minio"]),
        ("amoebius-platform-backbone", "platform-backbone", PLATFORM_NAMESPACE,
         ["phase30/minio", "phase30/writers/registry", "phase30/writers/pulsar-offload"]),
        ("amoebius-registry-writer", "registry-writer", PLATFORM_NAMESPACE, ["phase30/writers/registry"]),
        ("amoebius-pulsar-offload-writer", "pulsar-offload-writer", PULSAR_NAMESPACE, ["phase30/writers/pulsar-offload"]),
    ]
    for role, account, namespace, paths in roles:
        policy = "\n".join('path "secret/data/' + path + '" { capabilities = ["read"] }' for path in paths)
        vault.require_api("PUT", "sys/policies/acl/" + role, token, {"policy": policy})
        vault.require_api("POST", "auth/kubernetes/role/" + role, token, {
            "bound_service_account_names": [account], "bound_service_account_namespaces": [namespace],
            "token_policies": [role], "token_no_default_policy": True,
            "token_ttl": "10m", "token_max_ttl": "10m",
        })

    vault.require_api("PUT", "sys/policies/acl/amoebius-phase30-object-writer", token,
                      {"policy": 'path "auth/token/lookup-self" { capabilities = ["read"] }'})
    vault.require_api("POST", "auth/kubernetes/role/amoebius-phase30-object-writer", token, {
        "bound_service_account_names": ["phase30-object-writer"],
        "bound_service_account_namespaces": [PLATFORM_NAMESPACE],
        "token_policies": ["amoebius-phase30-object-writer"], "token_no_default_policy": True,
        "token_ttl": "5m", "token_max_ttl": "5m",
    })


def native_binary() -> str:
    global NATIVE_BINARY
    if NATIVE_BINARY is None:
        resolved = Path(text(run(cabal_command("list-bin", "platform-backbone-spec"))).strip())
        destination = EVIDENCE.parent / "runtime/platform-backbone-spec"
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(resolved, destination)
        digest = "sha256:" + hashlib.sha256(destination.read_bytes()).hexdigest()
        (EVIDENCE.parent / "native-executable.json").write_bytes(canonical_bytes(
            {"path": str(destination), "sha256": digest, "freshExecutionPerProjection": True}) + b"\n")
        NATIVE_BINARY = destination
    return str(NATIVE_BINARY)


def provision_storage_plan() -> dict[str, Any]:
    handoff = project_cluster_fixture.verified_image_handoff()
    if handoff.artifact != IMAGE_ARCHIVE or handoff.index_digest != IMAGE_DIGEST:
        raise BackboneLiveFailure("storage-plan-image-handoff-mismatch")
    capability = handoff.run_dir / "capability"
    public_input = {
        "artifact": json.loads((capability / "image-artifact.json").read_text()),
        "preflight": json.loads((capability / "standup-preflight.json").read_text()),
        "publication": json.loads((capability / "publication.json").read_text()),
        "backingCapacityBytes": shutil.disk_usage(TEST_ROOT).free,
    }
    binary = native_binary()
    plan = json.loads(text(run((binary, "--storage-plan"), input_bytes=canonical_bytes(public_input))))
    (EVIDENCE.parent / "storage-plan-input.json").write_bytes(canonical_bytes(public_input) + b"\n")
    (EVIDENCE.parent / "storage-plan.json").write_bytes(canonical_bytes(plan) + b"\n")
    observe_storage_provision(physical=False)
    return plan


def observe_storage_provision(*, physical: bool) -> dict[str, Any]:
    target = EVIDENCE.parent / ("storage-physical-observation.json" if physical else "storage-reference.json")
    command = (sys.executable, str(ROOT / "tools/platform_backbone_storage_observer.py"),
               "--input", str(EVIDENCE.parent / "storage-plan-input.json"),
               "--plan", str(EVIDENCE.parent / "storage-plan.json"), "--output", str(target))
    if physical:
        command = (*command, "--test-root", str(TEST_ROOT))
    run(command)
    return json.loads(target.read_text())


def sudo(*arguments: str, check: bool = True, timeout: float = 600) -> subprocess.CompletedProcess[bytes]:
    return run(("/usr/bin/sudo", "-n", *arguments), check=check, timeout=timeout)


def kubectl(
    *arguments: str,
    input_value: str | None = None,
    check: bool = True,
    timeout: int = 300,
) -> subprocess.CompletedProcess[bytes]:
    return run(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments),
        input_bytes=input_value.encode() if input_value is not None else None,
        check=check,
        timeout=timeout,
    )


def wait_on_delete_controller(namespace_name: str, kind: str, name: str, timeout: int) -> None:
    desired = APPLIED_OBJECTS[(kind, namespace_name, name)]
    expected = 1 if kind == "DaemonSet" else desired["spec"]["replicas"]
    resource = kind.lower() + "/" + name
    current = json.loads(text(kubectl("-n", namespace_name, "get", resource, "-o", "json")))
    generation = current["metadata"]["generation"]
    if current.get("status", {}).get("observedGeneration", 0) < generation:
        kubectl("-n", namespace_name, "wait", f"--for=jsonpath={{.status.observedGeneration}}={generation}",
                resource, f"--timeout={timeout}s", timeout=timeout + 20)
    field = "numberReady" if kind == "DaemonSet" else "readyReplicas"
    kubectl("-n", namespace_name, "wait", f"--for=jsonpath={{.status.{field}}}={expected}",
            resource, f"--timeout={timeout}s", timeout=timeout + 20)
    observed = json.loads(text(kubectl("-n", namespace_name, "get", resource, "-o", "json")))
    status = observed.get("status", {})
    if status.get("observedGeneration", 0) < generation or status.get(field) != expected:
        raise BackboneLiveFailure(f"on-delete-controller-not-observed-ready:{kind}/{name}")
    if kind == "DaemonSet" and status.get("desiredNumberScheduled") != expected:
        raise BackboneLiveFailure("daemonset-slots-differ-from-private-single-node-plan")


def object_key(value: dict[str, Any]) -> tuple[str, str, str]:
    metadata = value["metadata"]
    return value["kind"], metadata.get("namespace", ""), metadata["name"]


def merge_object(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(left)
    for key, value in right.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = merge_object(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def provision_backbone_services() -> dict[str, Any]:
    # The Vault floor retains its tested 2-CPU/4-GiB profile. Its successor
    # explicitly raises the enforced parent ceiling before admitting this set.
    if (os.cpu_count() or 0) < 8:
        raise BackboneLiveFailure("backbone-host-requires-eight-logical-cpus")
    run(("/usr/bin/docker", "update", "--cpus", "8", "--memory", "8g", "--memory-swap", "8g", NODE))
    host = json.loads(text(run(("/usr/bin/docker", "inspect", NODE))))[0]["HostConfig"]
    if (host["NanoCpus"], host["Memory"], host["MemorySwap"]) != (8000000000, 8589934592, 8589934592):
        raise BackboneLiveFailure("backbone-parent-supply-not-enforced")
    kubectl("-n", vault.CONSUMER_NAMESPACE, "delete", "pod", "vault-reader", "--ignore-not-found=true", "--wait=true")
    node = json.loads(text(kubectl("get", "node", NODE, "-o", "json")))
    allocatable = node["status"]["allocatable"]
    supply = [min(quantity(allocatable["cpu"], cpu=True), 8000),
              min(quantity(allocatable["memory"]), 8589934592),
              min(quantity(allocatable["ephemeral-storage"]), shutil.disk_usage(TEST_ROOT).free),
              int(allocatable["pods"])]
    pods = json.loads(text(kubectl("get", "pods", "-A", "-o", "json")))["items"]
    reserved = [0, 0, 0, 0]
    for pod in pods:
        if pod.get("status", {}).get("phase") in {"Succeeded", "Failed"}:
            continue
        spec = pod["spec"]
        # The retained floor contains only ordinary init containers. Fail
        # closed rather than miscount an unexpected restartable sidecar.
        if any(item.get("restartPolicy") == "Always" for item in spec.get("initContainers", [])):
            raise BackboneLiveFailure("unexpected-floor-restartable-init")
        app, initial = [0, 0, 0], [0, 0, 0]
        for key, units in (("containers", app), ("initContainers", initial)):
            for container in spec.get(key, []):
                resources = container.get("resources", {})
                for axis, name in enumerate(("cpu", "memory", "ephemeral-storage")):
                    value = max(quantity(resources.get("requests", {}).get(name, "0"), cpu=axis == 0),
                                quantity(resources.get("limits", {}).get(name, "0"), cpu=axis == 0))
                    units[axis] = units[axis] + value if key == "containers" else max(units[axis], value)
        for axis, name in enumerate(("cpu", "memory", "ephemeral-storage")):
            reserved[axis] += max(app[axis], initial[axis]) + quantity(spec.get("overhead", {}).get(name, "0"), cpu=axis == 0)
        reserved[3] += 1
    available = [capacity - used for capacity, used in zip(supply, reserved)]
    if min(available) < 0:
        raise BackboneLiveFailure("backbone-floor-exceeds-parent-supply")
    binary = native_binary()
    result = run((binary, "--service-plan", *(str(value) for value in available)))
    plan = json.loads(text(result))
    peak = plan["peak"]
    exact = [peak[key] for key in ("cpuMillis", "memoryBytes", "ephemeralBytes", "podSlots")]
    run((binary, "--service-plan", *(str(value) for value in exact)))
    reasons = []
    for axis, reason in enumerate(("CpuAxis", "MemoryAxis", "EphemeralStorageAxis", "PodSlotsAxis")):
        short = list(exact)
        short[axis] -= 1
        rejected = run((binary, "--service-plan", *(str(value) for value in short)), check=False)
        if rejected.returncode == 0 or reason not in text(rejected):
            raise BackboneLiveFailure(f"backbone-execution-negative-wrong-reason:{reason}")
        reasons.append(reason)
    os.environ["AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY"] = " ".join(str(value) for value in available)
    plan["zookeeperMembers"] = json.loads(text(run((binary, "--metadata-member-plan"),
        input_bytes=(EVIDENCE.parent / "storage-plan-input.json").read_bytes())))
    member_negatives = []
    for member in plan["zookeeperMembers"]["bindings"]:
        ordinal = member["ordinal"]
        for axis in ("cpu", "memory", "ephemeral", "pods", "usable", "incoming", "raw", "backing"):
            rejected = run((binary, "--metadata-member-negative", axis, str(ordinal)), check=False,
                           input_bytes=(EVIDENCE.parent / "storage-plan-input.json").read_bytes())
            locus = ("StorageOverBacking" if axis == "backing" else
                     "zookeeper-member-member-" + str(ordinal) + "-" +
                     ({"usable": "claim-usable", "incoming": "claim-usable", "raw": "claim-raw"}.get(axis, axis)))
            if rejected.returncode == 0 or locus not in text(rejected):
                raise BackboneLiveFailure("metadata-member-short-wrong-rejection:" + axis + ":" + str(ordinal))
            proof = {"ordinal": ordinal, "axis": axis, "locus": locus}
            if axis == "backing":
                expected_backing = "phase30-zookeeper-" + str(ordinal)
                if expected_backing not in text(rejected):
                    raise BackboneLiveFailure("metadata-member-backing-wrong-rejection:" + str(ordinal))
                proof["backing"] = expected_backing
            member_negatives.append(proof)
    parent_short = run((binary, "--metadata-member-negative", "parent", "0"), check=False,
                       input_bytes=(EVIDENCE.parent / "storage-plan-input.json").read_bytes())
    if (parent_short.returncode == 0 or "StorageOverBacking" not in text(parent_short)
            or "retained-parent" not in text(parent_short)):
        raise BackboneLiveFailure("metadata-parent-short-wrong-rejection")
    if APPLIED_OBJECTS:
        raise BackboneLiveFailure("metadata-admission-after-backbone-api-effects")
    globals()["EXECUTION_ADMISSION"] = {"nodeUid": node["metadata"]["uid"], "enforcedSupply": supply,
        "existingReservations": reserved, "available": available, "exactBoundary": exact,
        "oneUnitShortReasons": reasons, "backboneApiWritesDuringAdmission": 0,
        "metadataMemberNegatives": member_negatives, "metadataParentShortRejected": True,
        "metadataParentShortLocus": "StorageOverBacking:retained-parent",
        "metadataApiWritesDuringAdmission": 0}
    (EVIDENCE.parent / "service-plan.json").write_bytes(canonical_bytes(plan) + b"\n")
    return plan




def fresh_backbone_manifests(stage: str) -> list[dict[str, Any]]:
    os.environ["AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_NODE"] = NODE
    os.environ["AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_POOL"] = LOAD_BALANCER_POOL
    binary = native_binary()
    values = json.loads(text(run((binary, "--backbone-objects", stage),
        input_bytes=(EVIDENCE.parent / "storage-plan-input.json").read_bytes())))
    if not values or len({object_key(value) for value in values}) != len(values):
        raise BackboneLiveFailure("native-backbone-render-empty-or-duplicate")
    return values


def apply_native_stage(stage: str) -> None:
    priority = {"Namespace": 0, "CustomResourceDefinition": 1, "ServiceAccount": 2,
                "ClusterRole": 2, "ClusterRoleBinding": 3, "ConfigMap": 3,
                "StorageClass": 3, "PersistentVolume": 4, "Service": 5,
                "Deployment": 6, "DaemonSet": 6, "StatefulSet": 6, "Job": 6}
    for desired in sorted(fresh_backbone_manifests(stage),
                          key=lambda value: (priority.get(value["kind"], 7), object_key(value))):
        apply(desired)
        if desired["kind"] == "CustomResourceDefinition":
            kubectl("wait", "--for=condition=Established", "crd/" + desired["metadata"]["name"], "--timeout=60s")
    NATIVE_STAGES.append(stage)


def apply(value: dict[str, Any]) -> None:
    desired = copy.deepcopy(value)
    labels = desired.setdefault("metadata", {}).setdefault("labels", {})
    labels["app.kubernetes.io/managed-by"] = "amoebius"
    if desired.get("kind") == "Secret" and "stringData" in desired:
        desired["data"] = {
            key: base64.b64encode(raw.encode()).decode()
            for key, raw in desired.pop("stringData").items()
        }
    kubectl(
        "apply", "--server-side", "--field-manager=amoebius", "--force-conflicts",
        "-f", "-", input_value=json.dumps(desired),
    )
    key = object_key(desired)
    APPLIED_OBJECTS[key] = merge_object(APPLIED_OBJECTS.get(key, {}), desired)


def mountpoint(path: Path) -> bool:
    return run(("/usr/bin/mountpoint", "-q", str(path)), check=False).returncode == 0


def prepare_volume(name: str, raw_bytes: int) -> dict[str, Any]:
    # Allocation belongs to the predecessor composition, before either node's
    # bind mount is created. This path only consumes the sealed inventory.
    volume = PREPARED_VOLUMES.get(name)
    if volume is None or raw_bytes != STORAGE_PLAN["inventory"].get(name) or volume["rawBytes"] != raw_bytes:
        raise BackboneLiveFailure(f"retained-volume-not-preallocated:{name}")
    image, target = Path(volume["image"]), Path(volume["mount"])
    backing.reserved_bytes(image, raw_bytes)
    required = next(row["requiredUsableBytes"] for row in STORAGE_PLAN["volumes"] if row["name"] == name)
    if not mountpoint(target) or volume["usableBytes"] < required:
        raise BackboneLiveFailure(f"retained-volume-usable-capacity:{name}")
    sudo("/usr/bin/chmod", "0777", str(target))
    return volume


def ensure_cluster_image() -> None:
    if run(("/usr/bin/docker", "inspect", NODE), check=False).returncode:
        raise BackboneLiveFailure("phase24-kind-node-absent")
    images = text(run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q"))).splitlines()
    if PRIVATE_IMAGE not in images:
        imported = next((value for value in images if value.startswith("import-") and value.endswith("@" + IMAGE_DIGEST)), None)
        if imported is None:
            raise BackboneLiveFailure("phase25-image-absent")
        run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "tag", imported, PRIVATE_IMAGE))


def derive_load_balancer_pool() -> tuple[str, str]:
    """Select a host-routable pool from this private daemon's actual Kind network."""
    inspected = json.loads(text(run(("/usr/bin/docker", "network", "inspect", "kind"))))
    try:
        candidates = [
            ipaddress.ip_network(row["Subnet"])
            for row in inspected[0]["IPAM"]["Config"]
            if row.get("Subnet")
        ]
        network = next(candidate for candidate in candidates if candidate.version == 4)
    except (IndexError, KeyError, StopIteration, TypeError, ValueError) as problem:
        raise BackboneLiveFailure("kind-network-subnet-unreadable") from problem
    if network.num_addresses < 64:
        raise BackboneLiveFailure(f"kind-network-subnet-unsupported:{network}")
    first = network.broadcast_address - 20
    last = network.broadcast_address - 10
    if first not in network or last not in network:
        raise BackboneLiveFailure(f"kind-network-pool-outside-subnet:{network}:{first}:{last}")
    return str(first), f"{first}-{last}"


def reset_generated_phase30_state() -> None:
    for namespace_name in (PULSAR_NAMESPACE, PLATFORM_NAMESPACE, METALLB_NAMESPACE):
        kubectl("delete", "namespace", namespace_name, "--ignore-not-found=true", "--wait=true", "--timeout=300s", timeout=320)
    persistent_volumes = [f"platform-system.minio-data{index}.pv-0" for index in range(4)]
    persistent_volumes += [f"pulsar-system.zookeeper-data.pv-{index}" for index in range(3)]
    persistent_volumes += [f"pulsar-system.bookkeeper-data.pv-{index}" for index in range(3)]
    persistent_volumes += ["platform-system.object-gateway-state.pv-0",
        "platform-system.minio-replacement-replacement.pv-0", "pulsar-system.bookkeeper-replacement-replacement.pv-0"]
    kubectl("delete", "persistentvolume", *persistent_volumes, "--ignore-not-found=true", "--wait=true", "--timeout=120s", timeout=140)
    targets = [RETAINED_ROOT / f"mounts/phase30-minio-{index}" for index in range(4)]
    targets += [RETAINED_ROOT / f"mounts/phase30-zookeeper-{index}" for index in range(3)]
    targets += [RETAINED_ROOT / f"mounts/phase30-bookkeeper-{index}" for index in range(3)]
    targets += [RETAINED_ROOT / "mounts/phase30-registry-source", RETAINED_ROOT / "mounts/phase30-gateway-state", RETAINED_ROOT / "mounts/phase30-minio-replacement-0",
                RETAINED_ROOT / "mounts/phase30-bookkeeper-replacement-0"]
    expected_parent = (RETAINED_ROOT / "mounts").resolve()
    for target in targets:
        resolved = target.resolve()
        if resolved.parent != expected_parent or not resolved.name.startswith("phase30-"):
            raise BackboneLiveFailure(f"phase30-reset-target-refused:{resolved}")
        resolved.mkdir(parents=True, exist_ok=True)
        sudo("/usr/bin/find", str(resolved), "-mindepth", "1", "-delete")








def apply_metallb() -> dict[str, Any]:
    apply_native_stage("metallb")
    kubectl("-n", METALLB_NAMESPACE, "rollout", "status", "deployment/controller", "--timeout=180s")
    wait_on_delete_controller(METALLB_NAMESPACE, "DaemonSet", "speaker", 180)
    return {"controller": "Ready", "speaker": "Ready", "crdCount": 8}


def wait_for_load_balancer() -> dict[str, Any]:
    deadline = time.monotonic() + 180
    stable_observations = 0
    last_state = ""
    while time.monotonic() < deadline:
        service = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "service", "minio", "-o", "json")))
        controller = json.loads(text(kubectl("-n", METALLB_NAMESPACE, "get", "deployment", "controller", "-o", "json")))
        speaker = json.loads(text(kubectl("-n", METALLB_NAMESPACE, "get", "daemonset", "speaker", "-o", "json")))
        ingress = service.get("status", {}).get("loadBalancer", {}).get("ingress", [])
        controller_ready = controller.get("status", {}).get("readyReplicas", 0) == 1
        speaker_ready = speaker.get("status", {}).get("numberReady", 0) == speaker.get("status", {}).get("desiredNumberScheduled", -1) == 1
        ingress_reachable = False
        if ingress:
            connection = http.client.HTTPConnection(ingress[0]["ip"], 9000, timeout=1)
            try:
                connection.request("GET", "/minio/health/ready")
                response = connection.getresponse()
                response.read()
                ingress_reachable = response.status == 200
            except OSError:
                pass
            finally:
                connection.close()
        last_state = f"ingress={ingress},controller={controller_ready},speaker={speaker_ready},reachable={ingress_reachable}"
        stable_observations = stable_observations + 1 if ingress and controller_ready and speaker_ready and ingress_reachable else 0
        if stable_observations >= 5:
            return {"type": service["spec"]["type"], "ingress": ingress, "externallyReachable": True, "stableReadyObservations": stable_observations}
        time.sleep(1)
    raise BackboneLiveFailure(f"load-balancer-not-ready:{last_state}")






def apply_minio(volumes: list[dict[str, Any]]) -> dict[str, Any]:
    kubectl("delete", "storageclass", "standard", "--ignore-not-found=true")
    apply_native_stage("minio")
    wait_on_delete_controller(PLATFORM_NAMESPACE, "StatefulSet", "minio", 240)
    kubectl("-n", PLATFORM_NAMESPACE, "wait", "--for=jsonpath={.status.phase}=Bound",
            "pvc/replacement-minio-replacement-0", "--timeout=60s")
    stateful = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "statefulset", "minio", "-o", "json")))
    claims = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "pvc", "-o", "json")))
    return {
        "topology": "distributed-erasure-four-drive",
        "replicas": stateful["spec"]["replicas"],
        "claimTemplates": [item["metadata"]["name"] for item in stateful["spec"]["volumeClaimTemplates"]],
        "boundClaims": sorted(item["metadata"]["name"] for item in claims["items"] if item["metadata"]["name"].startswith(("data0-minio-", "data1-minio-", "data2-minio-", "data3-minio-"))),
        "volumes": volumes, "replacementClaimBound": True,
    }


@contextlib.contextmanager
def port_forward(namespace_name: str, resource: str, local_port: int, remote_port: int) -> Iterator[None]:
    process = subprocess.Popen(
        [KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", namespace_name, "port-forward", resource, f"{local_port}:{remote_port}"],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            connection = http.client.HTTPConnection("127.0.0.1", local_port, timeout=1)
            try:
                connection.request("GET", "/")
                connection.getresponse().read()
                break
            except OSError:
                time.sleep(0.2)
            finally:
                connection.close()
        else:
            raise BackboneLiveFailure(f"port-forward-not-ready:{namespace_name}:{resource}")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


@contextlib.contextmanager
def tcp_port_forward(namespace_name: str, resource: str, local_port: int, remote_port: int) -> Iterator[None]:
    process = subprocess.Popen(
        [KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", namespace_name, "port-forward", resource, f"{local_port}:{remote_port}"],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", local_port), timeout=1):
                    break
            except OSError:
                time.sleep(0.2)
        else:
            raise BackboneLiveFailure(f"tcp-port-forward-not-ready:{namespace_name}:{resource}")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def s3_request(method: str, bucket: str, key: str = "", body: bytes = b"", query: str = "", *,
               access: str | None = None, secret: str | None = None, port: int = MINIO_PORT,
               declared_bytes: int | None = None, extra_headers: dict[str, str] | None = None,
               payload_hash_override: str | None = None) -> tuple[int, bytes]:
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    access = MINIO_ACCESS if access is None else access
    secret = MINIO_SECRET if secret is None else secret
    encoded_key = urllib.parse.quote(key, safe="/-_.~")
    path = "/" + urllib.parse.quote(bucket, safe="-_.~") + ("/" + encoded_key if key else "")
    payload_hash = hashlib.sha256(body).hexdigest() if payload_hash_override is None else payload_hash_override
    canonical_query = query
    signed_values = {"host": f"127.0.0.1:{port}", "x-amz-content-sha256": payload_hash, "x-amz-date": amz_date,
                     **{name.lower(): value for name, value in (extra_headers or {}).items()}}
    canonical_headers = "".join(name + ":" + " ".join(value.split()) + "\n" for name, value in sorted(signed_values.items()))
    signed_headers = ";".join(sorted(signed_values))
    canonical_request = "\n".join([method, path, canonical_query, canonical_headers, signed_headers, payload_hash])
    scope = f"{date_stamp}/us-east-1/s3/aws4_request"
    string_to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical_request.encode()).hexdigest()])
    date_key = hmac.new(("AWS4" + secret).encode(), date_stamp.encode(), hashlib.sha256).digest()
    region_key = hmac.new(date_key, b"us-east-1", hashlib.sha256).digest()
    service_key = hmac.new(region_key, b"s3", hashlib.sha256).digest()
    signing_key = hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
    authorization = f"AWS4-HMAC-SHA256 Credential={access}/{scope}, SignedHeaders={signed_headers}, Signature={signature}"
    headers = {"x-amz-date": amz_date, "x-amz-content-sha256": payload_hash, "Authorization": authorization, "Content-Length": str(len(body) if declared_bytes is None else declared_bytes), **(extra_headers or {})}
    target = path + ("?" + query if query else "")
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
    try:
        connection.request(method, target, body=body, headers=headers)
        response = connection.getresponse()
        return response.status, response.read()
    finally:
        connection.close()


def ensure_bucket(bucket: str) -> None:
    status, payload = s3_request("PUT", bucket)
    if status not in {200, 409}:
        raise BackboneLiveFailure(f"s3-create-bucket:{bucket}:{status}:{payload.decode(errors='replace')}")


def minio_roundtrip() -> dict[str, Any]:
    bucket, key = "phase30-canary", "admitted-canary"
    value = secrets.token_bytes(4096)
    ensure_bucket(bucket)
    apply_native_stage("application-gateway")
    wait_on_delete_controller(PLATFORM_NAMESPACE, "StatefulSet", "object-gateway", 180)
    jwt = text(kubectl("-n", PLATFORM_NAMESPACE, "create", "token", "phase30-object-writer", "--duration=10m")).strip()
    with port_forward("vault-system", "service/root-vault", vault.LOCAL_PORT, 8200):
        login_status, login_body = vault.api_request("POST", "auth/kubernetes/login",
            body={"role": "amoebius-phase30-object-writer", "jwt": jwt})
        if login_status != 200:
            raise BackboneLiveFailure("object-writer-authority-login-failed")
        writer_token = json.loads(login_body)["auth"]["client_token"]
        secret_status, _ = vault.api_request("GET", "secret/data/phase30/minio", writer_token)
        if secret_status != 403:
            raise BackboneLiveFailure("object-writer-can-read-backend-credential")
        del writer_token, login_body
    def request(method: str, path: str, body: bytes = b"", *, port: int = 19010) -> tuple[int, bytes]:
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
        try:
            connection.request(method, path, body=body, headers={"Authorization": "Bearer " + jwt})
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()
    with port_forward(PLATFORM_NAMESPACE, "service/object-gateway", 19010, 8081):
        status, result = request("PUT", "/" + bucket + "/" + key, value)
        if (status, result) != (200, b"stored"):
            raise BackboneLiveFailure("object-gateway-own-scope-failed")
        status, fetched = request("GET", "/" + bucket + "/" + key)
        if status != 200 or fetched != value:
            raise BackboneLiveFailure("object-gateway-roundtrip-drift")
        foreign_status, foreign = request("PUT", "/registry/" + key, value)
        if (foreign_status, foreign) != (403, b"writer-scope-denied"):
            raise BackboneLiveFailure("object-gateway-foreign-scope-wrong-denial")
        oversize_status, oversize = request("PUT", "/" + bucket + "/" + key, value + b"x")
        if (oversize_status, oversize) != (413, b"writer-extent-denied"):
            raise BackboneLiveFailure("object-gateway-over-budget-wrong-denial")
    direct_status, direct_body = request("PUT", "/" + bucket + "/" + key, secrets.token_bytes(4096), port=MINIO_PORT)
    try: direct_code = ElementTree.fromstring(direct_body).findtext("Code")
    except ElementTree.ParseError: direct_code = None
    if (direct_status, direct_code) not in {(403, "AccessDenied"), (400, "InvalidRequest")}:
        raise BackboneLiveFailure("direct-minio-writer-wrong-denial:" + str((direct_status, direct_code)))
    status, observed = s3_request("GET", bucket, key)
    foreign_observed, _ = s3_request("GET", "registry", key)
    if status != 200 or observed != value or foreign_observed != 404:
        raise BackboneLiveFailure("object-gateway-forbidden-effects-observed")
    return {"bucket": bucket, "key": key, "sha256": hashlib.sha256(value).hexdigest(), "byteIdentical": True,
            "writerAdmission": {"ownScopeSuccess": True, "foreignScopeDenied": True,
                "directMinioDenied": True, "zeroForbiddenEffects": True, "oversizeDenied": True,
                "backendCredentialReadDenied": True,
                "directMinioStatus": direct_status, "directMinioReason": direct_code,
                "applicationProducerGatewayBound": True, "allPresentProducersGatewayBound": False}}





def writer_boundary_checks() -> list[dict[str, Any]]:
    """Use actual scoped Vault credentials, with independent backend effects."""
    proof = []
    nonce = secrets.token_hex(16)
    scopes = [
        ("registry", PLATFORM_NAMESPACE, "registry-writer", "amoebius-registry-writer", "registry",
         "docker/registry/v2/repositories/amoebius/phase30-new/_uploads/" + nonce + "/boundary", 4096,
         "pulsar-offload", nonce[:8] + "-" + nonce[8:12] + "-" + nonce[12:16] + "-" + nonce[16:20] + "-" + nonce[20:] + "-ledger-999999"),
        ("pulsar-offload", PULSAR_NAMESPACE, "pulsar-offload-writer", "amoebius-pulsar-offload-writer", "pulsar-offload",
         nonce[:8] + "-" + nonce[8:12] + "-" + nonce[12:16] + "-" + nonce[16:20] + "-" + nonce[20:] + "-ledger-999998", MIB,
         "registry", "docker/registry/v2/repositories/amoebius/phase30-new/_uploads/" + nonce + "/foreign"),
    ]
    with port_forward("vault-system", "service/root-vault", vault.LOCAL_PORT, 8200), \
         port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000), \
         port_forward(PLATFORM_NAMESPACE, "service/minio", GATEWAY_S3_PORT, 9000):
        for producer, namespace, account, role, bucket, key, maximum, foreign_bucket, foreign_key in scopes:
            jwt = text(kubectl("-n", namespace, "create", "token", account, "--duration=10m")).strip()
            login_status, login = vault.api_request("POST", "auth/kubernetes/login", body={"role": role, "jwt": jwt})
            if login_status != 200:
                raise BackboneLiveFailure("writer-authority-login-denied:" + producer)
            writer_token = json.loads(login)["auth"]["client_token"]
            status, credential_body = vault.api_request("GET", "secret/data/phase30/writers/" + producer, writer_token)
            if status != 200:
                raise BackboneLiveFailure("writer-own-credential-read-denied:" + producer)
            credentials = json.loads(credential_body)["data"]["data"]
            root_status, _ = vault.api_request("GET", "secret/data/phase30/minio", writer_token)
            other = "pulsar-offload" if producer == "registry" else "registry"
            other_status, _ = vault.api_request("GET", "secret/data/phase30/writers/" + other, writer_token)
            if (root_status, other_status) != (403, 403):
                raise BackboneLiveFailure("writer-authority-escapes-scope:" + producer)
            del jwt, writer_token, login, credential_body
            signed = {"access": credentials["access-key"], "secret": credentials["secret-key"]}
            payload = secrets.token_bytes(4096)
            status, _ = s3_request("PUT", bucket, key, payload, port=GATEWAY_S3_PORT, **signed)
            if status != 200:
                raise BackboneLiveFailure("writer-own-scope-failed:" + producer + ":" + str(status))
            status, observed = s3_request("GET", bucket, key)
            if status != 200 or observed != payload:
                raise BackboneLiveFailure("writer-fresh-backend-challenge-mismatch:" + producer)
            foreign_status, foreign_body = s3_request("PUT", foreign_bucket, foreign_key, payload, port=GATEWAY_S3_PORT, **signed)
            oversize_status, oversize_body = s3_request("PUT", bucket, key, port=GATEWAY_S3_PORT,
                                                       declared_bytes=maximum + 1, **signed)
            direct_status, direct_body = s3_request("PUT", bucket, key, secrets.token_bytes(4096), **signed)
            def code(body):
                try: return ElementTree.fromstring(body).findtext("Code")
                except ElementTree.ParseError: return None
            if (foreign_status, code(foreign_body)) != (403, "AccessDenied"):
                raise BackboneLiveFailure("writer-foreign-scope-wrong-denial:" + producer)
            if (oversize_status, code(oversize_body)) != (403, "gateway-object-extent-denied"):
                raise BackboneLiveFailure("writer-extent-wrong-denial:" + producer)
            if direct_status != 403 or code(direct_body) not in {"InvalidAccessKeyId", "AccessDenied"}:
                raise BackboneLiveFailure("writer-direct-backend-wrong-denial:" + producer)
            # Quiet-first is a real ordering emitted by the packaged AWS SDK.
            # Validate every requested key before forwarding any deletion: the
            # first key exists and belongs to this writer, the second does not.
            outside_key = "outside-owned-scope/" + nonce
            delete_body = ('<Delete xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
                           '<Quiet>false</Quiet><Object><Key>' + key + '</Key></Object>'
                           '<Object><Key>' + outside_key + '</Key></Object></Delete>').encode("ascii")
            bulk_status, bulk_body = s3_request("POST", bucket, body=delete_body, query="delete=",
                                               port=GATEWAY_S3_PORT, **signed)
            bulk_own_status, bulk_own = s3_request("GET", bucket, key)
            bulk_foreign_status, _ = s3_request("GET", bucket, outside_key)
            if ((bulk_status, code(bulk_body)) != (403, "gateway-writer-scope-denied")
                    or bulk_own_status != 200 or bulk_own != payload or bulk_foreign_status != 404):
                raise BackboneLiveFailure("writer-mixed-bulk-delete-scope-not-foreclosed:" + producer)
            if producer == "pulsar-offload":
                copy_key = key.removesuffix("999998") + "999997"
                source_key = scopes[0][5]
                copied_status, copied_body = s3_request("PUT", bucket, copy_key, port=GATEWAY_S3_PORT,
                    extra_headers={"x-amz-copy-source": "registry/" + source_key}, **signed)
                copy_absent, _ = s3_request("GET", bucket, copy_key)
                if (copied_status, code(copied_body), copy_absent) != (403, "gateway-copy-source-scope-denied", 404):
                    raise BackboneLiveFailure("writer-copy-source-foreign-scope-not-foreclosed")
            own_status, unchanged = s3_request("GET", bucket, key)
            absent_status, _ = s3_request("GET", foreign_bucket, foreign_key)
            if own_status != 200 or unchanged != payload or absent_status != 404:
                raise BackboneLiveFailure("writer-forbidden-backend-effect:" + producer)
            proof.append({"producer": producer, "authority": "vault-kubernetes-scoped-kv", "ownScopeSuccess": True,
                "payloadSha256": "sha256:" + hashlib.sha256(payload).hexdigest(), "bytes": len(payload),
                "foreignScopeDenied": True, "directMinioDenied": True, "oversizeDenied": True,
                "backendCredentialReadDenied": True, "foreignCredentialReadDenied": True, "zeroForbiddenEffects": True,
                "mixedBulkScopeDenied": True, "mixedBulkOwnObjectUnchanged": True, "mixedBulkForeignObjectAbsent": True,
                "observer": "independent-backend-s3-get", "oversizeReason": code(oversize_body), "directReason": code(direct_body),
                "foreignCopySourceDenied": producer == "pulsar-offload"})
            del credentials, signed
    return proof


def gateway_restart_debt_check() -> dict[str, Any]:
    """A real backend hash rejection must retain capacity debt across restart."""
    with port_forward("vault-system", "service/root-vault", vault.LOCAL_PORT, 8200):
        jwt = text(kubectl("-n", PLATFORM_NAMESPACE, "create", "token", "registry-writer", "--duration=10m")).strip()
        status, login = vault.api_request("POST", "auth/kubernetes/login",
                                         body={"role": "amoebius-registry-writer", "jwt": jwt})
        if status != 200:
            raise BackboneLiveFailure("gateway-restart-writer-login-denied")
        token = json.loads(login)["auth"]["client_token"]
        status, encoded = vault.api_request("GET", "secret/data/phase30/writers/registry", token)
        if status != 200:
            raise BackboneLiveFailure("gateway-restart-writer-credential-denied")
        credentials = json.loads(encoded)["data"]["data"]
        signed = {"access": credentials["access-key"], "secret": credentials["secret-key"]}
        del jwt, login, token, encoded, credentials
    key = "docker/registry/v2/repositories/amoebius/phase30-new/_uploads/" + secrets.token_hex(16) + "/restart"
    payload = secrets.token_bytes(4096)
    def reject_bad_digest() -> None:
        status, body = s3_request("PUT", "registry", key, payload, port=GATEWAY_S3_PORT,
                                  payload_hash_override="0" * 64, **signed)
        try: code = ElementTree.fromstring(body).findtext("Code")
        except ElementTree.ParseError: code = None
        if status not in {400, 403} or code not in {"XAmzContentSHA256Mismatch", "BadDigest"}:
            raise BackboneLiveFailure("gateway-restart-backend-failure-wrong-reason:" + str((status, code)))
    old = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "pod/object-gateway-0", "-o", "json")))["metadata"]["uid"]
    with port_forward(PLATFORM_NAMESPACE, "service/minio", GATEWAY_S3_PORT, 9000):
        reject_bad_digest()
    kubectl("-n", PLATFORM_NAMESPACE, "delete", "pod/object-gateway-0", "--wait=true", "--timeout=90s", timeout=100)
    wait_on_delete_controller(PLATFORM_NAMESPACE, "StatefulSet", "object-gateway", 240)
    new = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "pod/object-gateway-0", "-o", "json")))["metadata"]["uid"]
    if old == new:
        raise BackboneLiveFailure("gateway-restart-pod-identity-unchanged")
    with port_forward(PLATFORM_NAMESPACE, "service/minio", GATEWAY_S3_PORT, 9000):
        reject_bad_digest()
        reject_bad_digest()
        status, body = s3_request("PUT", "registry", key, payload, port=GATEWAY_S3_PORT, **signed)
        try: code = ElementTree.fromstring(body).findtext("Code")
        except ElementTree.ParseError: code = None
        if (status, code) != (403, "gateway-failed-history-full"):
            raise BackboneLiveFailure("gateway-restart-forgot-failed-debt:" + str((status, code)))
    del signed
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000):
        absent, _ = s3_request("GET", "registry", key)
    if absent != 404:
        raise BackboneLiveFailure("gateway-failed-write-left-unexpected-committed-object")
    return {"oldPodUid": old, "newPodUid": new, "observedBackendHashRejections": 3,
            "failureDebtRetainedAcrossRestart": True, "furtherWriteDenied": True,
            "forbiddenObjectAbsent": True, "failureReason": "gateway-failed-history-full"}


def apply_registry(filesystem: bool, source_dir: Path) -> None:
    stage = "registry-source" if filesystem else "registry-target"
    name = "registry-source" if filesystem else "registry"
    objects = fresh_backbone_manifests(stage)
    # The candidate must be Ready before the single stable Service switches.
    for desired in objects:
        if desired["kind"] != "Service":
            apply(desired)
    kubectl("-n", PLATFORM_NAMESPACE, "rollout", "status", f"deployment/{name}", "--timeout=180s")
    for desired in objects:
        if desired["kind"] == "Service":
            apply(desired)
    NATIVE_STAGES.append(stage)


def registry_request(method: str, path: str, body: bytes = b"", headers: dict[str, str] | None = None) -> tuple[int, dict[str, str], bytes]:
    connection = http.client.HTTPConnection("127.0.0.1", REGISTRY_PORT, timeout=30)
    try:
        request_headers = {"Content-Length": str(len(body)), **(headers or {})}
        connection.request(method, path, body=body, headers=request_headers)
        response = connection.getresponse()
        return response.status, {key.lower(): value for key, value in response.getheaders()}, response.read()
    finally:
        connection.close()


def registry_upload_blob(repository: str, value: bytes) -> str:
    digest = "sha256:" + hashlib.sha256(value).hexdigest()
    status, headers, payload = registry_request("POST", f"/v2/{repository}/blobs/uploads/")
    if status != 202:
        raise BackboneLiveFailure(f"registry-upload-start:{status}:{payload.decode(errors='replace')}")
    location = headers.get("location")
    if not location:
        raise BackboneLiveFailure("registry-upload-location-absent")
    separator = "&" if "?" in location else "?"
    status, _, payload = registry_request("PUT", location + separator + urllib.parse.urlencode({"digest": digest}), value, {"Content-Type": "application/octet-stream"})
    if status != 201:
        raise BackboneLiveFailure(f"registry-upload-finish:{status}:{payload.decode(errors='replace')}")
    return digest


def hash_file(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(65536), b""):
            digest.update(chunk)
            size += len(chunk)
    return "sha256:" + digest.hexdigest(), size


def materialize_registry_source(source_dir: Path) -> dict[str, Any]:
    registry = STORAGE_PLAN["registry"]
    objects = registry["objectSet"]
    observed: set[str] = set()
    with tarfile.open(IMAGE_ARCHIVE, "r|") as archive:
        for member in archive:
            identity = "sha256:" + member.name.removeprefix("blobs/sha256/")
            if identity not in objects:
                continue
            if not member.isfile() or member.size != objects[identity] or identity in observed:
                raise BackboneLiveFailure("registry-source-archive-object-invalid")
            raw = identity.split(":", 1)[1]
            target = source_dir / f"docker/registry/v2/blobs/sha256/{raw[:2]}/{raw}/data"
            target.parent.mkdir(parents=True, exist_ok=True)
            source = archive.extractfile(member)
            if source is None:
                raise BackboneLiveFailure("registry-source-archive-object-absent")
            with source, target.open("xb") as output:
                shutil.copyfileobj(source, output, length=65536)
            observed.add(identity)
    if observed != set(objects):
        raise BackboneLiveFailure("registry-source-archive-object-set-mismatch")
    for item in registry["driverObjects"]:
        if item["key"].endswith("/data"):
            continue
        identity = registry["indexDigest"] if "/current/link" in item["key"] else "sha256:" + item["key"].split("/")[-2]
        target = source_dir / item["key"]
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as output:
            output.write(identity.encode())
    actual = {str(path.relative_to(source_dir)): hash_file(path) for path in source_dir.rglob("*") if path.is_file()}
    expected = {row["key"]: (row["sha256"], row["bytes"]) for row in registry["driverObjects"]}
    if actual != expected:
        raise BackboneLiveFailure("registry-source-driver-map-mismatch")
    return {"repository": registry["repository"], "tag": registry["tag"],
            "indexDigest": registry["indexDigest"], "objectCount": len(objects),
            "storedBytes": sum(objects.values()), "driverObjectCount": len(actual)}


def hash_directory(path: Path) -> str:
    digest = hashlib.sha256()
    for item in sorted(value for value in path.rglob("*") if value.is_file()):
        digest.update(str(item.relative_to(path)).encode() + b"\0")
        with item.open("rb") as source:
            for chunk in iter(lambda: source.read(65536), b""):
                digest.update(chunk)
    return digest.hexdigest()


def pull_registry_inventory() -> dict[str, Any]:
    registry = STORAGE_PLAN["registry"]
    repository = registry["repository"]
    manifest_digests = {"sha256:" + row["key"].split("/")[-2]
                        for row in registry["driverObjects"] if "/_manifests/revisions/" in row["key"]}
    results = []
    accept = ", ".join(("application/vnd.oci.image.index.v1+json", "application/vnd.oci.image.manifest.v1+json",
                        "application/vnd.docker.distribution.manifest.list.v2+json", "application/vnd.docker.distribution.manifest.v2+json"))
    for identity, expected_bytes in registry["objectSet"].items():
        kind = "manifests" if identity in manifest_digests else "blobs"
        connection = http.client.HTTPConnection("127.0.0.1", REGISTRY_PORT, timeout=120)
        try:
            connection.request("GET", f"/v2/{repository}/{kind}/{identity}", headers={"Accept": accept})
            response = connection.getresponse()
            if response.status == 307:
                location = urllib.parse.urlsplit(response.getheader("Location", ""))
                raw = identity.removeprefix("sha256:")
                expected_path = f"/registry/docker/registry/v2/blobs/sha256/{raw[:2]}/{raw}/data"
                if (kind != "blobs" or location.scheme != "http" or location.hostname != "minio.platform-system.svc"
                    or location.port != 9000 or location.path != expected_path or location.username is not None):
                    raise BackboneLiveFailure("registry-blob-redirect-outside-verified-minio-object")
                connection.close()
                # Keep the signed Host/path/query intact while reaching the
                # private backing endpoint through the operator's local tunnel.
                connection = http.client.HTTPConnection("127.0.0.1", GATEWAY_S3_PORT, timeout=120)
                connection.request("GET", location.path + "?" + location.query, headers={"Host": location.netloc})
                response = connection.getresponse()
            if response.status != 200:
                raise BackboneLiveFailure(f"registry-inventory-pull-status:{response.status}:{identity}")
            digest = hashlib.sha256()
            size = 0
            while chunk := response.read(65536):
                digest.update(chunk)
                size += len(chunk)
                if size > expected_bytes:
                    raise BackboneLiveFailure("registry-inventory-pull-exceeded-extent")
            if "sha256:" + digest.hexdigest() != identity or size != expected_bytes:
                raise BackboneLiveFailure("registry-inventory-pull-digest-or-size-mismatch")
            results.append({"digest": identity, "bytes": size})
        finally:
            connection.close()
    status, _, body = registry_request("GET", f"/v2/{repository}/manifests/{registry['tag']}", headers={"Accept": accept})
    if status != 200 or "sha256:" + hashlib.sha256(body).hexdigest() != registry["indexDigest"]:
        raise BackboneLiveFailure("registry-immutable-tag-mismatch")
    return {"objects": results, "indexDigest": registry["indexDigest"], "immutableTag": registry["tag"]}


def fresh_registry_migration_manifests(*, verify_only: bool) -> list[dict[str, Any]]:
    binary = native_binary()
    mode = "verify-corrupt-link" if verify_only else "copy"
    public_input = (EVIDENCE.parent / "storage-plan-input.json").read_bytes()
    return json.loads(text(run((binary, "--migration-objects", mode), input_bytes=public_input)))


def wait_job_terminal(name: str, timeout: int) -> str:
    processes = {}
    try:
        for condition in ("complete", "failed"):
            processes[condition] = subprocess.Popen(
                [KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", PLATFORM_NAMESPACE,
                 "wait", f"--for=condition={condition}", f"job/{name}", f"--timeout={timeout}s"],
                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {pool.submit(process.wait): condition for condition, process in processes.items()}
            try:
                done, _ = concurrent.futures.wait(futures, timeout=timeout + 20,
                                                  return_when=concurrent.futures.FIRST_COMPLETED)
                if not done:
                    raise BackboneLiveFailure("registry-job-terminal-observer-timeout")
                first = next(iter(done))
                condition = futures[first]
                if first.result() != 0:
                    raise BackboneLiveFailure("registry-job-terminal-observer-failed")
                return condition
            finally:
                # Stop the opposite watch so a failed Job cannot leave a
                # success-only waiter alive until the full deadline.
                for process in processes.values():
                    if process.poll() is None:
                        process.terminate()
                for process in processes.values():
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            if process.stdout is not None:
                process.stdout.close()


def transfer_registry_job(name: str, objects: list[dict[str, Any]], *, verify_only: bool = False, expect_failure: bool = False) -> dict[str, Any]:
    manifests = fresh_registry_migration_manifests(verify_only=verify_only)
    jobs = [value for value in manifests if value["kind"] == "Job"]
    configs = [value for value in manifests if value["kind"] == "ConfigMap"]
    if len(jobs) != 1 or len(configs) != 1 or jobs[0]["metadata"]["name"] != name:
        raise BackboneLiveFailure("registry-native-job-identity-mismatch")
    configuration = json.loads(configs[0]["data"]["migration.json"])
    if configuration["objects"] != objects or configuration["verifyOnly"] != verify_only:
        raise BackboneLiveFailure("registry-native-job-object-map-mismatch")
    # renderAll supplies deterministic identity order; the reconciler's
    # dependency order creates the identity and configuration before the Job.
    priority = {"ServiceAccount": 0, "ConfigMap": 1, "Job": 2}
    for value in sorted(manifests, key=lambda value: priority[value["kind"]]):
        apply(value)
    condition = wait_job_terminal(name, 1200)
    output = text(kubectl("-n", PLATFORM_NAMESPACE, "logs", f"job/{name}"))
    if condition != ("failed" if expect_failure else "complete"):
        raise BackboneLiveFailure(f"registry-job-unexpected-terminal:{condition}:{output[:2000]}")
    fresh = fresh_registry_migration_manifests(verify_only=verify_only)
    if fresh != manifests:
        raise BackboneLiveFailure("registry-native-job-render-not-deterministic")
    for desired in fresh:
        metadata = desired["metadata"]
        observed = live_object(desired["kind"], metadata["namespace"], metadata["name"])
        if canonical_bytes(projected_like(observed, desired)) != canonical_bytes(desired):
            raise BackboneLiveFailure("registry-native-job-applied-projection-drift")

    if expect_failure:
        if "transfer-target-digest-mismatch" not in output:
            raise BackboneLiveFailure("registry-verify-negative-wrong-reason")
        proof = {"reason": "transfer-target-digest-mismatch", "job": name, "fullNativeRenderMatch": True}
        (EVIDENCE.parent / f"{name}-observation.json").write_bytes(canonical_bytes(proof) + b"\n")
        return proof
    result = json.loads(output)
    if result.get("objects") != objects or not result.get("verified") or result.get("streamBufferBytes") != 65536:
        raise BackboneLiveFailure("registry-transfer-job-result-mismatch")
    proof = {**result, "job": name, "fullNativeRenderMatch": True}
    (EVIDENCE.parent / f"{name}-observation.json").write_bytes(canonical_bytes(proof) + b"\n")
    return proof


def registry_rehome(source_dir: Path) -> dict[str, Any]:
    fixture = materialize_registry_source(source_dir)
    source_before = hash_directory(source_dir)
    apply_registry(True, source_dir)
    with port_forward(PLATFORM_NAMESPACE, "service/registry", REGISTRY_PORT, 5000):
        source_pull = pull_registry_inventory()
    selector_before = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "service", "registry", "-o", "json")))["spec"]["selector"]
    # Leave one corrupt partial target present and prove a real GET verifier
    # refuses it while the public service and complete source stay readable.
    small = next(row for row in STORAGE_PLAN["registry"]["driverObjects"] if row["bytes"] == 71)
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000):
        ensure_bucket("registry")
        status, _ = s3_request("PUT", "registry", small["key"], b"x" * 71)
        if status != 200:
            raise BackboneLiveFailure("registry-verify-negative-setup-failed")
    rejected = transfer_registry_job("registry-transfer-mismatch", [small], verify_only=True, expect_failure=True)
    selector_failed = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "service", "registry", "-o", "json")))["spec"]["selector"]
    if selector_failed != selector_before or hash_directory(source_dir) != source_before:
        raise BackboneLiveFailure("registry-failure-changed-source-or-route")
    with port_forward(PLATFORM_NAMESPACE, "service/registry", REGISTRY_PORT, 5000):
        status, _, _ = registry_request("GET", "/v2/")
        if status != 200:
            raise BackboneLiveFailure("registry-source-route-not-readable-after-rejection")
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000):
        status, retained_partial = s3_request("GET", "registry", small["key"])
        if status != 200 or retained_partial != b"x" * 71:
            raise BackboneLiveFailure("registry-failure-reclaimed-partial-target")
    migration = transfer_registry_job("registry-transfer", STORAGE_PLAN["registry"]["driverObjects"])
    apply_registry(False, source_dir)
    post_cutover_canary = secrets.token_bytes(4096)
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000), \
         port_forward(PLATFORM_NAMESPACE, "service/minio", GATEWAY_S3_PORT, 9000):
        with port_forward(PLATFORM_NAMESPACE, "service/registry", REGISTRY_PORT, 5000):
            target_pull = pull_registry_inventory()
            new_digest = registry_upload_blob("amoebius/phase30-new", post_cutover_canary)
    if source_pull != target_pull or source_before != hash_directory(source_dir):
        raise BackboneLiveFailure("registry-source-or-inventory-changed-after-cutover")
    selector_after = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "service", "registry", "-o", "json")))["spec"]["selector"]
    apply_native_stage("registry-retired")
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000):
        keys = list_bucket_keys("registry")
        raw_digest = new_digest.split(":", 1)[1]
        data_key = f"docker/registry/v2/blobs/sha256/{raw_digest[:2]}/{raw_digest}/data"
        status, actual_canary = s3_request("GET", "registry", data_key)
        if data_key not in keys or status != 200 or actual_canary != post_cutover_canary:
            raise BackboneLiveFailure("post-cutover-blob-not-byte-identical-in-minio")
    return {"fixture": fixture, "migration": migration, "sourceHashStable": True,
            "sourcePull": source_pull, "targetPull": target_pull,
            "verifyFailure": {**rejected, "sourceRoutePreserved": selector_failed == selector_before,
                              "sourceBytesRetained": fixture["storedBytes"], "partialTargetBytesRetained": 71},
            "route": {"before": selector_before, "after": selector_after, "atomicServiceSelectorUpdate": True},
            "postCutoverDigest": new_digest, "postCutoverByteIdentical": True,
            "postCutoverBytes": len(post_cutover_canary), "minioObjectCount": len(keys), "backend": "s3"}


def assert_vault_unsealed() -> dict[str, Any]:
    def status_value() -> dict[str, Any]:
        result = kubectl(
            "-n", "vault-system", "exec", "root-vault-0", "--", "env", "VAULT_ADDR=http://127.0.0.1:8200",
            "/usr/bin/vault", "status", "-format=json", check=False,
        )
        try:
            status, _ = json.JSONDecoder().raw_decode(text(result).lstrip())
            return status
        except json.JSONDecodeError as problem:
            raise BackboneLiveFailure(f"vault-status-unreadable:{result.returncode}") from problem

    status = status_value()
    if status.get("sealed") or not status.get("initialized"):
        raise BackboneLiveFailure(f"vault-not-ready:{status}")
    kubectl("-n", "vault-system", "wait", "--for=condition=Ready", "pod/root-vault-0", "--timeout=180s")
    return {
        "initialized": True,
        "sealed": False,
        "clusterId": status.get("cluster_id", ""),
        "observedBeforePulsar": True,
        "unsealedDuringPlatformBackbone": False,
    }






def apply_zookeeper(volumes: list[dict[str, Any]]) -> dict[str, Any]:
    for ordinal in range(3):
        directory = RETAINED_ROOT / "mounts" / ("phase30-zookeeper-" + str(ordinal))
        existing = sudo("/usr/bin/find", str(directory), "-mindepth", "1", "-maxdepth", "1",
                        "!", "-name", "lost+found", "-print", "-quit").stdout
        if existing.strip():
            raise BackboneLiveFailure("zookeeper-initial-backing-not-empty:" + str(ordinal))
    apply_native_stage("zookeeper")
    wait_on_delete_controller(PULSAR_NAMESPACE, "StatefulSet", "zookeeper", 360)
    pods = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pods", "-l", "app=pulsar-zookeeper", "-o", "json")))
    genesis = capture_zookeeper_genesis(volumes)
    return {"replicas": 3, "readyPods": len([pod for pod in pods["items"] if all(condition.get("status") == "True" for condition in pod["status"].get("conditions", []) if condition["type"] == "Ready")]), "volumes": volumes,
            "initialGenesis": genesis}


def wait_initial_zookeeper_snapshot(stat_source: Callable[[float], dict[str, int] | None],
                                    read_source: Callable[[float], bytes], *, device: int,
                                    deadline: float) -> tuple[bytes, dict[str, int]]:
    """TCP readiness can precede the first snapshot's completed file write."""
    def remaining() -> float:
        seconds = deadline - time.monotonic()
        if seconds <= 0:
            raise BackboneLiveFailure("zookeeper-genesis-file-not-ready-before-deadline")
        return seconds

    def provenance(observed: dict[str, int] | None) -> None:
        if observed is not None and (observed["device"] != device or observed["sizeBytes"] > 742):
            raise BackboneLiveFailure("zookeeper-genesis-file-provenance")

    while time.monotonic() < deadline:
        before = stat_source(remaining())
        provenance(before)
        if before is not None:
            if before["sizeBytes"] == 742:
                data = read_source(remaining())
                after = stat_source(remaining())
                provenance(after)
                if before == after and len(data) == 742:
                    remaining()
                    return data, before
        time.sleep(min(0.1,remaining()))
    raise BackboneLiveFailure("zookeeper-genesis-file-not-ready-before-deadline")


def capture_zookeeper_genesis(volumes: list[dict[str, Any]]) -> dict[str, Any]:
    """Keep the fresh pre-client bootstrap separately from current-state proof."""
    forbidden = {("Job", PULSAR_NAMESPACE, "pulsar-metadata"), ("StatefulSet", PULSAR_NAMESPACE, "bookkeeper"),
                 ("StatefulSet", PULSAR_NAMESPACE, "broker"), ("Deployment", PULSAR_NAMESPACE, "pulsar-tool")}
    if forbidden & APPLIED_OBJECTS.keys():
        raise BackboneLiveFailure("zookeeper-genesis-after-metadata-writers")
    directory = EVIDENCE.parent / "zookeeper-genesis"
    directory.mkdir()
    rows = []
    stat_reader = ("import os,sys,json,stat\ntry: s=os.stat(sys.argv[1],follow_symlinks=False)\n"
                   "except FileNotFoundError: print('null'); sys.exit(0)\n"
                   "assert stat.S_ISREG(s.st_mode); print(json.dumps({'device':s.st_dev,'inode':s.st_ino,"
                   "'sizeBytes':s.st_size,'allocatedBytes':s.st_blocks*512,'modifiedNs':s.st_mtime_ns}))")
    deadline = time.monotonic() + 180
    for ordinal in range(3):
        name = "phase30-zookeeper-" + str(ordinal)
        source = RETAINED_ROOT / "mounts" / name / "version-2/snapshot.0"
        volume = volumes[ordinal]
        mount = RETAINED_ROOT / "mounts" / name
        if Path(volume["mount"]) != mount:
            raise BackboneLiveFailure("zookeeper-genesis-file-provenance:" + name)
        data, before = wait_initial_zookeeper_snapshot(
            lambda seconds: json.loads(text(sudo("/usr/bin/python3", "-c", stat_reader, str(source), timeout=seconds))),
            lambda seconds: sudo("/usr/bin/cat", str(source), timeout=seconds).stdout,
            device=mount.stat().st_dev, deadline=deadline)
        snapshot = zookeeper_wire.parse_snapshot(data)
        zookeeper_wire.validate_native_genesis(snapshot, file_name="snapshot.0", snapshot_file_zxid=0)
        saved = directory / ("member-" + str(ordinal) + "-snapshot.0")
        saved.write_bytes(data)
        rows.append({"ordinal": ordinal, "backing": name, "file": saved.name, "source": before,
                     "sha256": "sha256:" + hashlib.sha256(data).hexdigest(), "bootstrap": snapshot.projection()})
    if len({row["source"]["device"] for row in rows}) != 3:
        raise BackboneLiveFailure("zookeeper-genesis-backing-alias")
    proof = {"capturedBeforeMetadataWriters": True, "sourceBackingsEmptyBeforeStart": True,
             "currentStateProof": False, "members": rows}
    (directory / "provenance.json").write_bytes(canonical_bytes(proof) + b"\n")
    return proof


def apply_pulsar_metadata() -> dict[str, Any]:
    apply_native_stage("pulsar-metadata")
    kubectl("-n", PULSAR_NAMESPACE, "wait", "--for=condition=complete", "job/pulsar-metadata", "--timeout=300s", timeout=320)
    job = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "job", "pulsar-metadata", "-o", "json")))
    return {"completed": job.get("status", {}).get("succeeded", 0) == 1, "observedAfterZooKeeperReady": True}


def apply_bookkeeper(volumes: list[dict[str, Any]]) -> dict[str, Any]:
    apply_native_stage("bookkeeper")
    wait_on_delete_controller(PULSAR_NAMESPACE, "StatefulSet", "bookkeeper", 480)
    kubectl("-n", PULSAR_NAMESPACE, "wait", "--for=jsonpath={.status.phase}=Bound",
            "pvc/replacement-bookkeeper-replacement-0", "--timeout=60s")
    pods = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pods", "-l", "app=pulsar-bookie", "-o", "json")))
    return {"replicas": 3, "readyPods": len([pod for pod in pods["items"] if pod.get("status", {}).get("phase") == "Running"]), "volumes": volumes, "ensemble": 3, "writeQuorum": 2, "ackQuorum": 2, "replacementClaimBound": True}


def apply_brokers() -> dict[str, Any]:
    apply_native_stage("pulsar-brokers")
    wait_on_delete_controller(PULSAR_NAMESPACE, "StatefulSet", "broker", 600)
    baked_offloaders = [
        line for line in text(kubectl(
            "-n", PULSAR_NAMESPACE, "exec", "broker-0", "--",
            "/usr/bin/find", "/pulsar/offloaders", "-type", "f",
        )).splitlines() if line.strip()
    ]
    if not baked_offloaders:
        raise BackboneLiveFailure("baked-pulsar-offloader-files-absent")
    kubectl("-n", PULSAR_NAMESPACE, "rollout", "status", "deployment/pulsar-tool", "--timeout=180s")
    pods = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pods", "-l", "app=pulsar-broker", "-o", "json")))
    return {
        "replicas": 2,
        "readyPods": len([pod for pod in pods["items"] if pod.get("status", {}).get("phase") == "Running"]),
        "nativePort": 6650,
        "webSocketUsed": False,
        "developmentOffloaderMount": DEV_OFFLOADERS,
        "bakedOffloaderFileCount": len(baked_offloaders),
        "bakedOffloaderFilesSha256": "sha256:" + hashlib.sha256("\n".join(sorted(baked_offloaders)).encode()).hexdigest(),
        "externalToolPod": True,
    }


def pulsar_admin(*arguments: str, allow_exists: bool = False) -> str:
    result = kubectl(
        "-n", PULSAR_NAMESPACE, "exec", "deployment/pulsar-tool", "--", "/pulsar/bin/pulsar-admin", "--admin-url", "http://broker.pulsar-system.svc.cluster.local:8080",
        *arguments, check=False, timeout=300,
    )
    output = text(result)
    if result.returncode and not (allow_exists and ("already exist" in output.lower() or "conflict" in output.lower())):
        raise BackboneLiveFailure(f"pulsar-admin:{arguments}:{result.returncode}:{output}")
    return output


def list_bucket_keys(bucket: str) -> list[str]:
    status, listing = s3_request("GET", bucket, query="list-type=2")
    if status != 200:
        raise BackboneLiveFailure(f"bucket-list:{bucket}:{status}:{listing.decode(errors='replace')}")
    return [node.text or "" for node in ElementTree.fromstring(listing).findall("{*}Contents/{*}Key")]


def encode_varint(value: int) -> bytes:
    encoded = bytearray()
    while value >= 0x80:
        encoded.append((value & 0x7f) | 0x80)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def proto_varint(field: int, value: int) -> bytes:
    return encode_varint(field << 3) + encode_varint(value)


def proto_bytes(field: int, value: bytes) -> bytes:
    return encode_varint((field << 3) | 2) + encode_varint(len(value)) + value


def proto_text(field: int, value: str) -> bytes:
    return proto_bytes(field, value.encode())


def base_command(command_type: int, command_field: int, payload: bytes) -> bytes:
    return proto_varint(1, command_type) + proto_bytes(command_field, payload)


def simple_pulsar_frame(command: bytes) -> bytes:
    body = struct.pack(">I", len(command)) + command
    return struct.pack(">I", len(body)) + body


def payload_pulsar_frame(command: bytes, metadata: bytes, payload: bytes) -> bytes:
    body = struct.pack(">I", len(command)) + command + struct.pack(">I", len(metadata)) + metadata + payload
    return struct.pack(">I", len(body)) + body


def decode_varint(value: bytes, offset: int) -> tuple[int, int]:
    result = 0
    shift = 0
    while offset < len(value) and shift < 70:
        byte = value[offset]
        offset += 1
        result |= (byte & 0x7f) << shift
        if not byte & 0x80:
            return result, offset
        shift += 7
    raise BackboneLiveFailure("pulsar-protobuf-varint-malformed")


def proto_fields(value: bytes) -> dict[int, list[int | bytes]]:
    fields: dict[int, list[int | bytes]] = {}
    offset = 0
    while offset < len(value):
        tag, offset = decode_varint(value, offset)
        field = tag >> 3
        wire_type = tag & 7
        if wire_type == 0:
            decoded, offset = decode_varint(value, offset)
        elif wire_type == 2:
            size, offset = decode_varint(value, offset)
            decoded = value[offset:offset + size]
            if len(decoded) != size:
                raise BackboneLiveFailure("pulsar-protobuf-bytes-truncated")
            offset += size
        elif wire_type == 5:
            decoded = value[offset:offset + 4]
            offset += 4
        elif wire_type == 1:
            decoded = value[offset:offset + 8]
            offset += 8
        else:
            raise BackboneLiveFailure(f"pulsar-protobuf-wire-type:{wire_type}")
        fields.setdefault(field, []).append(decoded)
    return fields


def receive_exact(connection: socket.socket, size: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < size:
        value = connection.recv(size - len(chunks))
        if not value:
            raise BackboneLiveFailure("pulsar-native-connection-closed")
        chunks.extend(value)
    return bytes(chunks)


def receive_pulsar_frame(connection: socket.socket) -> tuple[int, dict[int, list[int | bytes]], bytes | None]:
    total_size = struct.unpack(">I", receive_exact(connection, 4))[0]
    body = receive_exact(connection, total_size)
    if len(body) < 4:
        raise BackboneLiveFailure("pulsar-native-frame-short")
    command_size = struct.unpack(">I", body[:4])[0]
    command = body[4:4 + command_size]
    if len(command) != command_size:
        raise BackboneLiveFailure("pulsar-native-command-short")
    base = proto_fields(command)
    command_type = int(base[1][0])
    nested_raw = base.get(command_type, [b""])[0]
    if not isinstance(nested_raw, bytes):
        raise BackboneLiveFailure(f"pulsar-native-command-payload:{command_type}")
    payload_block = body[4 + command_size:]
    payload: bytes | None = None
    if payload_block:
        if payload_block.startswith(b"\x0e\x01"):
            payload_block = payload_block[6:]
        if len(payload_block) < 4:
            raise BackboneLiveFailure("pulsar-native-payload-metadata-short")
        metadata_size = struct.unpack(">I", payload_block[:4])[0]
        if len(payload_block) < 4 + metadata_size:
            raise BackboneLiveFailure("pulsar-native-payload-short")
        payload = payload_block[4 + metadata_size:]
    return command_type, proto_fields(nested_raw), payload


def wait_for_pulsar_command(connection: socket.socket, accepted: set[int]) -> tuple[int, dict[int, list[int | bytes]], bytes | None]:
    while True:
        command_type, fields, payload = receive_pulsar_frame(connection)
        if command_type == 18:
            connection.sendall(simple_pulsar_frame(base_command(19, 19, b"")))
            continue
        if command_type in {8, 14}:
            raise BackboneLiveFailure(f"pulsar-native-broker-error:{command_type}:{fields}")
        if command_type in accepted:
            return command_type, fields, payload


def native_dedup_probe(topic: str) -> str:
    lookup = pulsar_admin("topics", "lookup", topic)
    match = re.search(r"pulsar://(broker-[0-9]+)\.", lookup)
    if match is None:
        raise BackboneLiveFailure(f"pulsar-topic-owner-unresolved:{lookup}")
    broker_pod = match.group(1)
    nonce = secrets.token_bytes(32)
    cbor_one = b"\xa2\x63msg\x63one\x65nonce\x58\x20" + nonce
    cbor_duplicate = b"\xa2\x63msg\x64drop\x65nonce\x58\x20" + nonce
    cbor_two = b"\xa2\x63msg\x63two\x65nonce\x58\x20" + nonce
    producer_name = "phase30-sequenced-producer"
    subscription = f"phase30-dedup-observer-{time.time_ns()}"
    with tcp_port_forward(PULSAR_NAMESPACE, f"pod/{broker_pod}", 16650, 6650):
        with socket.create_connection(("127.0.0.1", 16650), timeout=30) as connection:
            connection.settimeout(30)
            connect = proto_text(1, "amoebius-phase30-native-probe") + proto_varint(4, 21)
            connection.sendall(simple_pulsar_frame(base_command(2, 2, connect)))
            wait_for_pulsar_command(connection, {3})
            subscribe = b"".join([
                proto_text(1, topic), proto_text(2, subscription), proto_varint(3, 0),
                proto_varint(4, 1), proto_varint(5, 1), proto_text(6, "phase30-observer"),
                proto_varint(8, 1), proto_varint(13, 1), proto_varint(15, 0),
            ])
            connection.sendall(simple_pulsar_frame(base_command(4, 4, subscribe)))
            wait_for_pulsar_command(connection, {13})
            producer = b"".join([
                proto_text(1, topic), proto_varint(2, 1), proto_varint(3, 2),
                proto_text(4, producer_name), proto_varint(9, 1),
            ])
            connection.sendall(simple_pulsar_frame(base_command(5, 5, producer)))
            wait_for_pulsar_command(connection, {17})
            for sequence_id, value in ((7, cbor_one), (7, cbor_duplicate), (8, cbor_two)):
                send = proto_varint(1, 1) + proto_varint(2, sequence_id) + proto_varint(3, 1)
                metadata = b"".join([
                    proto_text(1, producer_name), proto_varint(2, sequence_id),
                    proto_varint(3, int(time.time() * 1000)), proto_varint(11, 1),
                ])
                connection.sendall(payload_pulsar_frame(base_command(6, 6, send), metadata, value))
                _, receipt, _ = wait_for_pulsar_command(connection, {7})
                if int(receipt[2][0]) != sequence_id:
                    raise BackboneLiveFailure(f"pulsar-native-receipt-sequence:{receipt}")
            flow = proto_varint(1, 1) + proto_varint(2, 3)
            connection.sendall(simple_pulsar_frame(base_command(11, 11, flow)))
            received: list[bytes] = []
            while len(received) < 2:
                _, _, payload = wait_for_pulsar_command(connection, {9})
                if payload is None:
                    raise BackboneLiveFailure("pulsar-native-message-payload-absent")
                received.append(payload)
            connection.settimeout(3)
            deadline = time.monotonic() + 3
            try:
                while time.monotonic() < deadline:
                    command_type, _, _ = receive_pulsar_frame(connection)
                    if command_type == 9:
                        raise BackboneLiveFailure("pulsar-native-duplicate-delivered")
            except socket.timeout:
                pass
    if set(received) != {cbor_one, cbor_two} or cbor_duplicate in received:
        raise BackboneLiveFailure(f"pulsar-native-cbor-drift:{received}")
    return "platform-backbone-dedup-probe: PASS native=true sequenceIds=7,7,8 delivered=2 cborByteIdentical=true"


def native_offloaded_read_probe(topic: str, message: bytes, observation: dict[str, Any]) -> dict[str, Any]:
    """A fresh earliest subscription must read actual reclaimed ledgers via S3."""
    deleted = {row["ledgerId"] for row in observation["ledgers"]
               if row.get("offloaded") and row.get("deletionCredited")
               and not row.get("bookkeeperMetadataExists")}
    if not deleted:
        raise BackboneLiveFailure("offloaded-read-has-no-observed-reclaimed-ledger")
    # Closing the managed ledger removes its entry cache. A fresh consumer
    # against the still-open producer ledger could otherwise read cached data.
    pulsar_admin("topics", "unload", topic)
    lookup = pulsar_admin("topics", "lookup", topic)
    match = re.search(r"pulsar://(broker-[0-9]+)\.", lookup)
    if match is None:
        raise BackboneLiveFailure("offloaded-read-topic-owner-unresolved")
    subscription = "phase30-offloaded-read-" + secrets.token_hex(16)
    delivered, offloaded_ids = 0, set()
    with tcp_port_forward(PULSAR_NAMESPACE, "pod/" + match.group(1), 16650, 6650):
        with socket.create_connection(("127.0.0.1", 16650), timeout=30) as connection:
            connection.settimeout(60)
            connect = proto_text(1, "amoebius-phase30-offloaded-read") + proto_varint(4, 21)
            connection.sendall(simple_pulsar_frame(base_command(2, 2, connect)))
            wait_for_pulsar_command(connection, {3})
            subscribe = b"".join([
                proto_text(1, topic), proto_text(2, subscription), proto_varint(3, 0),
                proto_varint(4, 1), proto_varint(5, 1), proto_text(6, "phase30-cold-observer"),
                proto_varint(8, 1), proto_varint(13, 1), proto_varint(15, 0),
            ])
            connection.sendall(simple_pulsar_frame(base_command(4, 4, subscribe)))
            wait_for_pulsar_command(connection, {13})
            connection.sendall(simple_pulsar_frame(base_command(11, 11, proto_varint(1, 1) + proto_varint(2, 100))))
            while delivered < 100:
                _, fields, payload = wait_for_pulsar_command(connection, {9})
                if payload != message:
                    raise BackboneLiveFailure("offloaded-read-fresh-payload-mismatch")
                raw_id = fields.get(2, [None])[0]
                if not isinstance(raw_id, bytes):
                    raise BackboneLiveFailure("offloaded-read-message-id-absent")
                ledger = int(proto_fields(raw_id)[1][0])
                if ledger in deleted:
                    offloaded_ids.add(ledger)
                delivered += 1
    if not offloaded_ids:
        raise BackboneLiveFailure("offloaded-read-never-used-reclaimed-ledger")
    return {"freshEarliestSubscription": True, "deliveredMessages": delivered,
            "payloadSha256": "sha256:" + hashlib.sha256(message).hexdigest(),
            "readReclaimedLedgerIds": sorted(offloaded_ids), "bookkeeperAbsenceObservedBeforeRead": True,
            "managedLedgerUnloadedBeforeRead": True}


def topic_owner_identity(topic: str) -> dict[str, Any]:
    status, encoded = pulsar_broker_http("GET", pulsar_topic_path(topic, lookup=True))
    if status != 200:
        raise BackboneLiveFailure("offload-protocol-owner-lookup-denied:" + str(status))
    lookup = json.loads(encoded).get("brokerUrl", "")
    match = re.fullmatch(r"pulsar://(broker-[01])\.broker-headless\.pulsar-system\.svc\.cluster\.local:6650", lookup)
    if match is None:
        raise BackboneLiveFailure("offload-protocol-owner-unresolved")
    pod = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pod", match.group(1), "-o", "json")))
    statuses = pod.get("status", {}).get("containerStatuses", [])
    if len(statuses) != 1 or not statuses[0].get("ready"):
        raise BackboneLiveFailure("offload-protocol-owner-not-ready")
    return {"pod": match.group(1), "uid": pod["metadata"]["uid"],
            "containerID": statuses[0]["containerID"], "restartCount": statuses[0]["restartCount"]}


def pulsar_topic_path(topic: str, *, lookup: bool = False) -> str:
    if not re.fullmatch(r"persistent://phase30/drill/[a-z0-9._-]{1,128}", topic):
        raise BackboneLiveFailure("pulsar-finite-topic-path-invalid")
    suffix = urllib.parse.quote(topic.removeprefix("persistent://"), safe="/-_.")
    return ("/lookup/v2/topic/persistent/" if lookup else "/admin/v2/persistent/") + suffix


def pulsar_broker_http(method: str, path: str, body: bytes | None = None) -> tuple[int, bytes]:
    """Preserve method/body through bounded redirects to admitted brokers."""
    target = "service/broker"
    original_path = urllib.parse.urlsplit(path).path
    for _attempt in range(3):
        with port_forward(PULSAR_NAMESPACE, target, 18080, 8080):
            connection = http.client.HTTPConnection("127.0.0.1", 18080, timeout=15)
            try:
                connection.request(method, path, body=body, headers={"Content-Type": "application/json"})
                response = connection.getresponse()
                payload = response.read(1048577)
                location = response.getheader("Location")
                status = response.status
            finally:
                connection.close()
        if len(payload) > 1048576:
            raise BackboneLiveFailure("pulsar-broker-http-response-bound")
        if status != 307:
            return status, payload
        redirect = urllib.parse.urlsplit(location or "")
        host = re.fullmatch(r"(broker-[01])\.broker-headless\.pulsar-system\.svc\.cluster\.local", redirect.hostname or "")
        query = urllib.parse.parse_qs(redirect.query, strict_parsing=True)
        if (redirect.scheme != "http" or host is None or redirect.port != 8080 or redirect.username is not None
                or redirect.password is not None or redirect.fragment or redirect.path != original_path
                or set(query) - {"authoritative"} or any(value not in [["true"], ["false"]] for value in query.values())):
            raise BackboneLiveFailure("pulsar-broker-http-redirect-outside-admission")
        target = "pod/" + host.group(1)
        path = redirect.path + ("?" + redirect.query if redirect.query else "")
    raise BackboneLiveFailure("pulsar-broker-http-redirect-limit")


def compile_pulsar_observer() -> dict[str, Any]:
    compilation = EVIDENCE.parent / "observer-compile"
    compilation.mkdir(exist_ok=True)
    classpath = compilation / "pulsar-lib"
    classes = compilation / "classes"
    classes.mkdir(exist_ok=True)
    pods = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pods", "-l", "app=pulsar-tool", "-o", "json")))["items"]
    if len(pods) != 1:
        raise BackboneLiveFailure("observer-compiler-pod-identity-ambiguous")
    pod = pods[0]
    if (pod["spec"]["containers"][0]["image"] != PRIVATE_IMAGE
        or IMAGE_DIGEST not in pod["status"]["containerStatuses"][0].get("imageID", "")
        or not pod["spec"]["containers"][0]["securityContext"]["readOnlyRootFilesystem"]):
        raise BackboneLiveFailure("observer-compiler-classpath-provenance")
    if not classpath.exists():
        kubectl("cp", "-n", PULSAR_NAMESPACE,
                pod["metadata"]["name"] + ":/pulsar/lib", str(classpath), timeout=300)
    jars = sorted(classpath.glob("*.jar"))
    if not jars:
        raise BackboneLiveFailure("observer-compiler-classpath-empty")
    capture_directory = compilation / ("history-capture-" + secrets.token_hex(8))
    run((sys.executable, str(ROOT / "tools/platform_backbone_jvm_capture.py"),
         "--classpath", str(classpath), "--output", str(capture_directory)), timeout=240)
    capture_proof = capture_directory / "provenance.json"
    compiler = toolchain.resolve(["javac"])["javac"]
    source = ROOT / "test/live/PlatformBackboneLedgerObserver.java"
    run((compiler["path"], "--release", "21", "-cp", str(classpath / "*"),
         "-d", str(classes), str(source)), timeout=120)
    compiled = classes / "PlatformBackboneLedgerObserver.class"
    if not compiled.is_file():
        raise BackboneLiveFailure("observer-compiler-class-absent")
    kubectl("cp", "-n", PULSAR_NAMESPACE, str(compiled),
            pod["metadata"]["name"] + ":/tmp/PlatformBackboneLedgerObserver.class")
    proof = {"compiler": compiler, "targetRelease": 21, "imageDigest": IMAGE_DIGEST,
             "sourceSha256": hash_file(source)[0], "classSha256": hash_file(compiled)[0],
             "classpath": [{"name": jar.name, "bytes": jar.stat().st_size, "sha256": hash_file(jar)[0]} for jar in jars],
             "recompiledThisInvocation": True,
             "captureProbePath": str(capture_proof.relative_to(EVIDENCE.parent)),
             "captureProbeSha256": hash_file(capture_proof)[0]}
    (compilation / "provenance.json").write_bytes(canonical_bytes(proof) + b"\n")
    return proof


@contextlib.contextmanager
def pulsar_ledger_observer() -> Iterator[Any]:
    compile_pulsar_observer()
    arguments = [KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", PULSAR_NAMESPACE,
                 "exec", "-i", "deployment/pulsar-tool", "--", "/usr/bin/java",
                 "-Xms16m", "-Xmx96m", "-XX:MaxDirectMemorySize=32m", "--class-path",
                 "/tmp:/pulsar/lib/*", "PlatformBackboneLedgerObserver"]
    process = subprocess.Popen(arguments, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)
    lines: queue.Queue[str | None] = queue.Queue(maxsize=4096)
    raw_path = EVIDENCE.parent / "bookkeeper-observer-process.log"
    def collect() -> None:
        with raw_path.open("w") as raw:
            total = 0
            for line in process.stdout:
                total += len(line)
                if total > 8 * MIB:
                    lines.put(None)
                    return
                raw.write(line)
                raw.flush()
                lines.put(line)
        lines.put(None)
    reader = threading.Thread(target=collect, daemon=True)
    reader.start()
    def receive(prefix: str, timeout: float) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                line = lines.get(timeout=max(0.01, deadline - time.monotonic()))
            except queue.Empty as problem:
                raise BackboneLiveFailure("bookkeeper-observer-timeout") from problem
            if line is None:
                raise BackboneLiveFailure("bookkeeper-observer-unavailable:" + str(process.poll()))
            if line.startswith(prefix):
                return line[len(prefix):].strip()
        raise BackboneLiveFailure("bookkeeper-observer-timeout")
    def observe(topic: str) -> dict[str, Any]:
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,128}", topic):
            raise BackboneLiveFailure("bookkeeper-observer-topic-invalid")
        process.stdin.write(topic + "\n")
        process.stdin.flush()
        result = json.loads(receive("PHASE30_OBSERVATION ", 20))
        if result.get("topic") != topic or not isinstance(result.get("hotTierBytes"), int):
            raise BackboneLiveFailure("bookkeeper-observer-challenge-mismatch")
        hot_observer.hot_bytes(result)
        return result
    try:
        receive("PHASE30_OBSERVER_READY", 60)
        yield observe
    finally:
        if process.stdin:
            process.stdin.close()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        reader.join(timeout=5)
        if process.stdout:
            process.stdout.close()


def observe_pulsar_ingest(topic: str, observe: Any, message: str, *, bounded: bool,
                          message_count: int = 100, topic_created_seconds: float | None = None) -> dict[str, Any]:
    # Both policies receive the same complete 100 x 4096-byte stream at 2/s.
    # The finite rate leaves rollover/offload headroom; it is not a ready wait.
    if len(message.encode()) != 4096:
        raise BackboneLiveFailure("pulsar-ingest-challenge-extent-invalid")
    if message_count not in {11, 100}:
        raise BackboneLiveFailure("pulsar-ingest-count-outside-finite-program")
    args = [KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", PULSAR_NAMESPACE,
            "exec", "deployment/pulsar-tool", "--", "/pulsar/bin/pulsar-client",
            "--url", "pulsar://broker.pulsar-system.svc.cluster.local:6650", "produce",
            "--disable-batching", "--num-produce", str(message_count), "--rate", "2",
            "--messages", message, "persistent://phase30/drill/" + topic]
    samples = []
    sample_path = EVIDENCE.parent / (topic + "-hot-tier.jsonl")
    log_path = EVIDENCE.parent / (topic + "-producer.log")
    started = time.monotonic()
    topic_age_at_start = None if topic_created_seconds is None else started - topic_created_seconds
    first_write_age_upper = None
    process = None
    succeeded = False
    producer_started = producer_finished = 0.0

    def measured():
        before = time.monotonic() - started
        result = observe(topic)
        result["observationStartedSeconds"] = before
        result["observationFinishedSeconds"] = time.monotonic() - started
        result["elapsedSeconds"] = result["observationFinishedSeconds"]
        return result

    def first_write_age(sample):
        nonlocal first_write_age_upper
        if topic_age_at_start is None or first_write_age_upper is not None:
            return
        upper = topic_age_at_start + sample["observationFinishedSeconds"]
        if not 0 <= upper < 60:
            raise BackboneLiveFailure("positive-topic-aged-before-first-write")
        if sample["hotTierBytes"] > 0:
            first_write_age_upper = upper

    try:
        with log_path.open("wb") as log, sample_path.open("w") as raw:
            # An actual zero/initial observation precedes the first publication.
            first = measured()
            raw.write(json.dumps(first, sort_keys=True) + "\n"); raw.flush()
            samples.append(first)
            first_write_age(first)
            producer_started = time.monotonic() - started
            process = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
            while True:
                result = measured()
                raw.write(json.dumps(result, sort_keys=True) + "\n"); raw.flush()
                samples.append(result)
                first_write_age(result)
                if bounded and result["hotTierBytes"] > HOT_TIER_CAP:
                    raise BackboneLiveFailure("continuous-hot-tier-cap-exceeded:" + str(result["hotTierBytes"]))
                if process.poll() is not None:
                    producer_finished = time.monotonic() - started
                    final = measured()
                    raw.write(json.dumps(final, sort_keys=True) + "\n"); raw.flush()
                    samples.append(final)
                    first_write_age(final)
                    if bounded and final["hotTierBytes"] > HOT_TIER_CAP:
                        raise BackboneLiveFailure("continuous-hot-tier-cap-exceeded:" + str(final["hotTierBytes"]))
                    break
                if time.monotonic() - started > 300:
                    raise BackboneLiveFailure("pulsar-ingest-timeout")
                time.sleep(0.25)
            if process.returncode != 0:
                raise BackboneLiveFailure("pulsar-producer-failed:" + str(process.returncode))
        if f"{message_count} messages successfully produced" not in log_path.read_text():
            raise BackboneLiveFailure("producer-success-marker-absent")
        coverage = hot_observer.verify_coverage(samples, producer_started, producer_finished)
        if topic_age_at_start is not None and first_write_age_upper is None:
            raise BackboneLiveFailure("positive-topic-first-write-unobserved")
        succeeded = True
    finally:
        if process is not None and not succeeded:
            # Stop the owning test container, then observe deletion. A local
            # exec-client signal cannot prove the remote producer has stopped.
            kubectl("-n", PULSAR_NAMESPACE, "scale", "deployment/pulsar-tool", "--replicas=0")
            kubectl("-n", PULSAR_NAMESPACE, "wait", "--for=delete", "pod",
                    "-l", "app=pulsar-tool", "--timeout=60s", timeout=80)
        if process is not None and process.poll() is None:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(timeout=5)
    return {"topic": topic, "coverage": coverage, "producerStartedSeconds": producer_started,
            "producerFinishedSeconds": producer_finished, "sampleCount": len(samples), "maximumObservedHotTierBytes": max(row["hotTierBytes"] for row in samples),
            "hotTierBytes": samples[-1]["hotTierBytes"], "samplesPath": sample_path.name,
            "sampleSha256": "sha256:" + hashlib.sha256(sample_path.read_bytes()).hexdigest(),
            "producerExited": True, "producedBytes": message_count * 4096, "messageCount": message_count, "messagesPerSecond": 2,
            "payloadSha256": "sha256:" + hashlib.sha256(message.encode()).hexdigest(),
            "topicAgeAtObservationStartSeconds": topic_age_at_start,
            "firstWriteAgeUpperSeconds": first_write_age_upper,
            "maximumTopicAgeBeforeFirstWriteSeconds": 60 if topic_age_at_start is not None else None,
            "creditsOnlyObservedBookkeeperDeletion": True,
            "closedLedgerMetadataObservations": len({ledger["ledgerId"] for sample in samples for ledger in sample["ledgers"]
                if ledger.get("bookkeeperMetadataExists") and ledger.get("bookkeeperClosed") and ledger.get("bookkeeperLengthBytes", 0) > 0}),
            "observer": "baked-bookkeeper-metadata-api-plus-broker-internal-stats",
            "lastObservation": samples[-1]}


def observe_pulsar_offload_policy(size: int, seconds: int) -> dict[str, Any]:
    with port_forward(PULSAR_NAMESPACE, "service/broker", 18080, 8080):
        connection = http.client.HTTPConnection("127.0.0.1", 18080, timeout=15)
        try:
            connection.request("GET", "/admin/v2/namespaces/phase30/drill/offloadPolicies")
            response = connection.getresponse()
            body = response.read(1048577)
            if response.status != 200 or len(body) > 1048576:
                raise BackboneLiveFailure("offload-policy-readback-unavailable")
            policy = json.loads(body)
        finally:
            connection.close()
    expected = {"managedLedgerOffloadThresholdInBytes": size,
                "managedLedgerOffloadThresholdInSeconds": seconds,
                "managedLedgerOffloadDeletionLagInMillis": 0}
    if any(policy.get(key) != value for key, value in expected.items()):
        raise BackboneLiveFailure("offload-policy-operands-drift")
    if any(value for key, value in policy.items() if "credential" in key.lower()):
        raise BackboneLiveFailure("offload-policy-contains-inline-credential")
    return {key: policy[key] for key in expected}


def configure_and_drill_pulsar() -> dict[str, Any]:
    pulsar_admin("tenants", "create", "phase30", "--allowed-clusters", "phase30", allow_exists=True)
    pulsar_admin("namespaces", "create", "phase30/drill", "--clusters", "phase30", allow_exists=True)
    pulsar_admin("namespaces", "set-retention", "phase30/drill", "--size", "1M", "--time", "1h")
    pulsar_admin("namespaces", "set-deduplication", "phase30/drill", "--enable")
    pulsar_admin(
        "namespaces", "set-offload-policies", "phase30/drill", "--driver", "aws-s3", "--region", "us-east-1",
        "--bucket", "pulsar-offload", "--endpoint", "http://minio.platform-system.svc.cluster.local:9000",
        "--maxBlockSize", "5M",
        "--offloadAfterThreshold", str(HOT_TIER_CAP // 2),
        "--offloadAfterThresholdInSeconds", "-1", "--offloadAfterElapsed", "0",
    )
    policy_operands = observe_pulsar_offload_policy(HOT_TIER_CAP // 2, -1)
    dedup_topic = "persistent://phase30/drill/dedup-" + secrets.token_hex(16)
    offload_topic = "persistent://phase30/drill/offload-" + secrets.token_hex(16)
    pulsar_admin("topics", "create", dedup_topic, allow_exists=True)
    probe_marker = native_dedup_probe(dedup_topic)

    local_name = offload_topic.rsplit("/", 1)[1]
    challenge_message = secrets.token_hex(2048)
    with pulsar_ledger_observer() as observe:
        # HTTP readiness does not initialize the lazy JClouds protocol path.
        # Observe this finite11-message workload against the unchanged cap
        # while its first automatic offload initializes. Up to eleven nonempty
        # data ledgers, empty successors and the dedup cursor remain
        # charged in the shared source/history.
        readiness_name = "ready-" + secrets.token_hex(16)
        pulsar_admin("topics", "create", "persistent://phase30/drill/" + readiness_name)
        readiness_owner_before = topic_owner_identity("persistent://phase30/drill/" + readiness_name)
        readiness = observe_pulsar_ingest(readiness_name, observe, secrets.token_hex(2048),
                                         bounded=True, message_count=11)
        readiness_started = time.monotonic()
        ready_samples = []
        readiness_trace = EVIDENCE.parent / (readiness_name + "-offload-ready.jsonl")
        with readiness_trace.open("w") as trace:
            while True:
                sample = observe(readiness_name)
                sample["elapsedAfterProducerSeconds"] = time.monotonic() - readiness_started
                trace.write(json.dumps(sample, sort_keys=True) + "\n"); trace.flush()
                ready_samples.append(sample)
                if sample["hotTierBytes"] > HOT_TIER_CAP:
                    raise BackboneLiveFailure("offload-readiness-hot-tier-cap-exceeded")
                if sample["elapsedAfterProducerSeconds"] > 120:
                    raise BackboneLiveFailure("offload-protocol-readiness-timeout")
                if any(row.get("offloaded") and row.get("deletionCredited")
                       and not row.get("bookkeeperMetadataExists") for row in sample["ledgers"]):
                    break
                time.sleep(0.25)
        readiness["automaticOffloadAndBookkeeperDeletionObserved"] = True
        readiness["maximumNonemptyDataLedgers"] = 11
        readiness["completionTrace"] = {"path": readiness_trace.name, "samples": len(ready_samples),
            "sha256": "sha256:" + hashlib.sha256(readiness_trace.read_bytes()).hexdigest()}
        ready_owner = topic_owner_identity("persistent://phase30/drill/" + readiness_name)
        if ready_owner != readiness_owner_before:
            raise BackboneLiveFailure("offload-protocol-readiness-owner-changed-during-warmup")
        readiness["ownerBeforeIngest"] = readiness_owner_before
        if observe_pulsar_offload_policy(HOT_TIER_CAP // 2, -1) != policy_operands:
            raise BackboneLiveFailure("offload-protocol-policy-changed-before-positive")
        # Empty ledgers still age toward the broker's one-minute rollover.
        # Materialize the positive only after protocol readiness completes.
        positive_created = time.monotonic()
        created, _ = pulsar_broker_http("PUT", pulsar_topic_path(offload_topic), b"{}")
        if created != 204:
            raise BackboneLiveFailure("positive-fresh-topic-create-denied:" + str(created))
        positive_owner = topic_owner_identity(offload_topic)
        if ready_owner != positive_owner:
            raise BackboneLiveFailure("offload-protocol-readiness-owner-or-policy-changed")
        readiness["owner"] = ready_owner
        positive = observe_pulsar_ingest(local_name, observe, challenge_message, bounded=True,
                                         topic_created_seconds=positive_created)
        positive["ingestOwner"] = positive_owner
        if topic_owner_identity(offload_topic) != positive_owner:
            raise BackboneLiveFailure("offload-protocol-owner-changed-during-positive-ingest")
        offloaded_read = native_offloaded_read_probe(offload_topic, challenge_message.encode(), positive["lastObservation"])
        # Disable only the size dimension; a one-hour time trigger cannot fire
        # during the same bounded stream. The physical plan reserves this probe.
        pulsar_admin("namespaces", "set-offload-policies", "phase30/drill", "--driver", "aws-s3",
                     "--region", "us-east-1", "--bucket", "pulsar-offload",
                     "--endpoint", "http://minio.platform-system.svc.cluster.local:9000",
                     "--maxBlockSize", "5M", "--offloadAfterThreshold", "-1",
                     "--offloadAfterThresholdInSeconds", "1h", "--offloadAfterElapsed", "0")
        time_policy_operands = observe_pulsar_offload_policy(-1, 3600)
        negative_name = "time-only-" + secrets.token_hex(16)
        pulsar_admin("topics", "create", "persistent://phase30/drill/" + negative_name)
        negative = observe_pulsar_ingest(negative_name, observe, challenge_message, bounded=False)
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000):
        keys = list_bucket_keys("pulsar-offload")
        observed_payload = None
        for key in keys:
            status, payload = s3_request("GET", "pulsar-offload", key)
            if status == 200 and challenge_message.encode() in payload:
                observed_payload = {"key": key, "bytes": len(payload), "sha256": "sha256:" + hashlib.sha256(payload).hexdigest()}
                break
    if observed_payload is None:
        raise BackboneLiveFailure("offload-fresh-payload-not-observed-in-s3")
    if not keys or negative["maximumObservedHotTierBytes"] <= HOT_TIER_CAP:
        raise BackboneLiveFailure("offload-or-time-only-paired-control-failed")
    # Restore the admitted policy before final observation and closure.
    pulsar_admin("namespaces", "set-offload-policies", "phase30/drill", "--driver", "aws-s3",
                 "--region", "us-east-1", "--bucket", "pulsar-offload",
                 "--endpoint", "http://minio.platform-system.svc.cluster.local:9000",
                 "--maxBlockSize", "5M", "--offloadAfterThreshold", str(HOT_TIER_CAP // 2),
                 "--offloadAfterThresholdInSeconds", "-1", "--offloadAfterElapsed", "0")
    return {
        "nativeRoundtrip": True, "deduplicationExercised": True, "sequenceIds": [7, 7, 8], "deliveredMessages": 2,
        "cborByteIdentical": True, "dedupProbeOutput": probe_marker,
        "offload": {
            "topic": offload_topic, "configuredSizeTriggerBytes": HOT_TIER_CAP // 2, "timeOnly": False,
            "producedBytes": 100 * 4096, "objectCount": len(keys), "objectKeys": keys[:20],
            "hotTierBytes": positive["hotTierBytes"], "hotTierCapBytes": HOT_TIER_CAP, "bounded": True,
            "observer": positive["observer"], "continuousObservation": positive,
            "freshPayloadObservedInS3": True, "freshPayloadObject": observed_payload, "policyOperands": policy_operands,
            "offloadedRead": offloaded_read,
            "protocolReadiness": readiness,
            "timeOnlyNegative": {"sameIngest": all(positive[key] == negative[key] for key in
                ("producedBytes", "messageCount", "messagesPerSecond", "payloadSha256")), "observedBreach": True,
                "hotTierBytes": negative["maximumObservedHotTierBytes"], "observation": negative,
                "policyOperands": time_policy_operands},
        },
        "producerOutputMarker": "100 messages successfully produced", "producerExited": True,
    }


def apply_pulsar() -> dict[str, Any]:
    vault = assert_vault_unsealed()
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000):
        ensure_bucket("pulsar-offload")
    zookeeper_volumes = [prepare_volume(f"phase30-zookeeper-{ordinal}", STORAGE_PLAN["inventory"][f"phase30-zookeeper-{ordinal}"]) for ordinal in range(3)]
    bookkeeper_volumes = [prepare_volume(f"phase30-bookkeeper-{ordinal}", STORAGE_PLAN["inventory"][f"phase30-bookkeeper-{ordinal}"]) for ordinal in range(3)]
    zookeeper = apply_zookeeper(zookeeper_volumes)
    metadata = apply_pulsar_metadata()
    bookkeeper = apply_bookkeeper(bookkeeper_volumes)
    broker = apply_brokers()
    drill = configure_and_drill_pulsar()
    return {"vaultReadyEdge": vault, "zookeeper": zookeeper, "metadata": metadata, "bookkeeper": bookkeeper, "broker": broker, "drill": drill}


def image_and_resource_evidence() -> dict[str, Any]:
    pods = json.loads(text(kubectl("get", "pods", "-A", "-o", "json")))
    selected = [item for item in pods["items"] if item["metadata"]["namespace"] in {METALLB_NAMESPACE, PLATFORM_NAMESPACE, "pulsar-system"}]
    images: list[str] = []
    image_ids: list[str] = []
    resources_exact = True
    public_refs: list[str] = []
    for pod in selected:
        statuses = {
            status.get("name"): status.get("imageID", "")
            for status in pod.get("status", {}).get("containerStatuses", [])
        }
        for container in pod["spec"].get("containers", []):
            image = container["image"]
            images.append(image)
            if image != PRIVATE_IMAGE:
                public_refs.append(image)
            limits = container.get("resources", {}).get("limits", {})
            requests = container.get("resources", {}).get("requests", {})
            resources_exact = resources_exact and all(key in limits and key in requests for key in ("cpu", "memory", "ephemeral-storage"))
            image_id = statuses.get(container["name"], "")
            image_ids.append(image_id)
            if IMAGE_DIGEST not in image_id:
                raise BackboneLiveFailure(f"runtime-image-id-drift:{pod['metadata']['namespace']}/{pod['metadata']['name']}:{container['name']}:{image_id}")
    if public_refs or not resources_exact or not image_ids:
        raise BackboneLiveFailure(f"image-resource-provenance:{public_refs}:{resources_exact}:{len(image_ids)}")
    return {
        "podCount": len(selected), "images": sorted(set(images)), "runtimeImageIds": sorted(set(image_ids)),
        "allRuntimeImageIdsMatchBaseDigest": True, "publicImageReferences": public_refs,
        "completeResourceFields": resources_exact,
    }


def live_object(kind: str, namespace_name: str, name: str) -> dict[str, Any]:
    arguments = (["-n", namespace_name] if namespace_name else []) + ["get", kind, name, "-o", "json", "--show-managed-fields"]
    return json.loads(text(kubectl(*arguments)))


def projected_like(observed: Any, desired: Any, path: str = "$") -> Any:
    if isinstance(desired, dict):
        if not isinstance(observed, dict):
            raise BackboneLiveFailure(f"ssa-projection-type:{path}")
        missing = sorted(set(desired) - set(observed))
        if missing:
            raise BackboneLiveFailure(f"ssa-projection-missing:{path}:{missing}")
        return {key: projected_like(observed[key], value, f"{path}.{key}") for key, value in desired.items()}
    if isinstance(desired, list):
        if not isinstance(observed, list) or len(observed) < len(desired):
            raise BackboneLiveFailure(f"ssa-projection-list:{path}:{len(desired)}")
        return [projected_like(observed[index], value, f"{path}[{index}]") for index, value in enumerate(desired)]
    return observed


def verify_ssa_projection() -> dict[str, Any]:
    rows: list[dict[str, str]] = []
    for (kind, namespace_name, name), desired in sorted(APPLIED_OBJECTS.items()):
        observed = live_object(kind, namespace_name, name)
        managers = {
            entry.get("manager", "")
            for entry in observed.get("metadata", {}).get("managedFields", [])
        }
        if "amoebius" not in managers:
            raise BackboneLiveFailure(f"ssa-field-manager-absent:{kind}/{namespace_name}/{name}:{sorted(managers)}")
        projection = projected_like(observed, desired)
        desired_bytes = canonical_bytes(desired)
        projection_bytes = canonical_bytes(projection)
        if not hmac.compare_digest(desired_bytes, projection_bytes):
            raise BackboneLiveFailure(f"ssa-byte-projection-drift:{kind}/{namespace_name}/{name}")
        rows.append({
            "identity": f"{kind}/{namespace_name}/{name}",
            "sha256": "sha256:" + hashlib.sha256(desired_bytes).hexdigest(),
        })
    if not rows:
        raise BackboneLiveFailure("ssa-projection-empty")
    return {
        "fieldManager": "amoebius",
        "objectCount": len(rows),
        "allOwnedFieldsByteIdentical": True,
        "objectHashes": rows,
        "aggregateSha256": "sha256:" + hashlib.sha256(canonical_bytes(rows)).hexdigest(),
    }


def verify_complete_haskell_render() -> dict[str, Any]:
    fresh: dict[tuple[str, str, str], dict[str, Any]] = {}
    for stage in NATIVE_STAGES:
        for desired in fresh_backbone_manifests(stage):
            key = object_key(desired)
            fresh[key] = merge_object(fresh.get(key, {}), desired)
    for verify_only in (True, False):
        for desired in fresh_registry_migration_manifests(verify_only=verify_only):
            key = object_key(desired)
            fresh[key] = merge_object(fresh.get(key, {}), desired)
    if set(fresh) != set(APPLIED_OBJECTS):
        raise BackboneLiveFailure("complete-native-render-object-set-drift")
    rows = []
    for key, desired in sorted(fresh.items()):
        if canonical_bytes(desired) != canonical_bytes(APPLIED_OBJECTS[key]):
            raise BackboneLiveFailure("complete-native-render-desired-field-drift:" + "/".join(key))
        observed = live_object(*key)
        if canonical_bytes(projected_like(observed, desired)) != canonical_bytes(desired):
            raise BackboneLiveFailure("complete-native-render-live-field-drift:" + "/".join(key))
        rows.append({"identity": "/".join(key), "sha256": "sha256:" + hashlib.sha256(canonical_bytes(desired)).hexdigest()})
    return {"renderer": "Amoebius.Manifest.renderAll", "freshGateProcessOutput": True,
            "allOwnedFieldsByteIdentical": True, "objectCount": len(rows), "objectHashes": rows,
            "renderSha256": "sha256:" + hashlib.sha256(canonical_bytes(rows)).hexdigest()}


def quantity(value: str, *, cpu: bool = False) -> int:
    if cpu:
        return int(value[:-1]) if value.endswith("m") else int(value) * 1000
    factors = {"Ki": 1024, "Mi": MIB, "Gi": 1024 * MIB}
    for suffix, factor in factors.items():
        if value.endswith(suffix):
            return int(value[:-len(suffix)]) * factor
    return int(value)


def resource_projection(container: dict[str, Any]) -> dict[str, int]:
    resources = container.get("resources", {})
    requests = resources.get("requests", {})
    limits = resources.get("limits", {})
    return {
        "requestCpuMillis": quantity(requests["cpu"], cpu=True),
        "limitCpuMillis": quantity(limits["cpu"], cpu=True),
        "requestMemoryBytes": quantity(requests["memory"]),
        "limitMemoryBytes": quantity(limits["memory"]),
        "requestEphemeralBytes": quantity(requests["ephemeral-storage"]),
        "limitEphemeralBytes": quantity(limits["ephemeral-storage"]),
    }


def fresh_haskell_render_plan() -> list[dict[str, Any]]:
    binary = native_binary()
    if not binary:
        raise BackboneLiveFailure("phase30-haskell-renderer-binary-absent")
    rendered = json.loads(text(run((binary, "--render-plan"))))
    if not isinstance(rendered, list) or not rendered:
        raise BackboneLiveFailure("phase30-haskell-render-plan-empty")
    return rendered


def verify_haskell_render_projection() -> dict[str, Any]:
    expected = fresh_haskell_render_plan()
    actual: list[dict[str, Any]] = []
    for plan_object in expected:
        kind = plan_object["objectKind"]
        namespace_name = plan_object["objectNamespace"]
        name = plan_object["objectName"]
        observed = live_object(kind, namespace_name, name)
        if kind == "Service":
            ingress = observed.get("status", {}).get("loadBalancer", {}).get("ingress", [])
            addresses = [entry.get("ip") or entry.get("hostname") for entry in ingress]
            projected = {
                **plan_object,
                "objectArguments": addresses,
            }
        else:
            pod_spec = observed["spec"]["template"]["spec"]
            container = pod_spec["containers"][0]
            resource_names = set(container.get("resources", {}).get("requests", {})) | set(container.get("resources", {}).get("limits", {}))
            accelerator = sorted(name for name in resource_names if "/" in name)
            cache_volumes = sorted(volume.get("name", "") for volume in pod_spec.get("volumes", []) if "cache" in volume.get("name", "").lower())
            projected = {
                "objectAccelerator": accelerator[0] if accelerator else None,
                "objectArguments": container.get("command", []) + container.get("args", []),
                "objectCache": 0 if cache_volumes else None,
                "objectImage": container["image"],
                "objectKind": kind,
                "objectName": name,
                "objectNamespace": namespace_name,
                "objectReplicas": 1 if kind in {"DaemonSet", "Job"} else observed["spec"].get("replicas", 1),
                "objectResources": resource_projection(container),
            }
        if canonical_bytes(projected) != canonical_bytes(plan_object):
            raise BackboneLiveFailure(
                f"haskell-render-projection-drift:{kind}/{namespace_name}/{name}:"
                f"expected={canonical_bytes(plan_object).decode()}:actual={canonical_bytes(projected).decode()}"
            )
        actual.append(projected)
    rendered_bytes = canonical_bytes(expected)
    return {
        "renderer": "Amoebius.Platform.Backbone.renderBackbone",
        "freshGateProcessOutput": True,
        "objectCount": len(expected),
        "allAppliedProjectionsByteIdentical": True,
        "renderSha256": "sha256:" + hashlib.sha256(rendered_bytes).hexdigest(),
    }


def node_pull_event_evidence(since: datetime.datetime) -> dict[str, Any]:
    since_text = since.astimezone(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
    journal_since = since.astimezone(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    output = text(run(("/usr/bin/docker", "exec", NODE, "/usr/bin/journalctl", "-u", "containerd",
                       "--since", journal_since, "--no-pager", "--output=cat")))
    lines = output.splitlines()
    if not lines or output.strip() == "-- No entries --" or "No journal files were found" in output:
        raise BackboneLiveFailure("containerd-journal-observer-unavailable")
    pull_lines = [line for line in lines if "pull" in line.lower() and "image" in line.lower()]
    public_lines = [line for line in pull_lines if any(token in line for token in PUBLIC_REGISTRY_TOKENS)]
    if public_lines:
        raise BackboneLiveFailure(f"public-registry-pull-events:{public_lines[:10]}")
    return {
        "observer": "kind-node-containerd-log-window", "since": since_text,
        "logSource": "systemd-containerd-journal", "windowMessageCount": len(lines),
        "pullEventCount": len(pull_lines), "publicPullEventCount": 0,
        "windowSha256": "sha256:" + hashlib.sha256(output.encode()).hexdigest(),
    }


@contextlib.contextmanager
def observe_service_filesystems() -> Iterator[Path]:
    directory = EVIDENCE.parent / "service-census"
    directory.mkdir()
    output, summary, stop = (directory / name for name in ("files.jsonl", "summary.json", "stop"))
    completed = False
    with (directory / "observer.log").open("wb") as log:
        process = subprocess.Popen(["/usr/bin/sudo", "-n", "/usr/bin/python3",
            str(ROOT / "tools/platform_backbone_service_census.py"), "--test-root", str(TEST_ROOT),
            "--output", str(output), "--summary", str(summary), "--stop", str(stop)],
            cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 30
            while not output.exists() or output.stat().st_size == 0:
                if process.poll() is not None or time.monotonic() > deadline:
                    raise BackboneLiveFailure("service-census-observer-unavailable")
                time.sleep(.1)
            yield summary
            completed = True
        finally:
            stop.touch()
            try: process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=5)
            if completed and (process.returncode != 0 or not summary.is_file()):
                raise BackboneLiveFailure("service-census-observer-failed")


def execute() -> dict[str, Any]:
    gate_started = datetime.datetime.now(datetime.timezone.utc)
    APPLIED_OBJECTS.clear()
    print("platform-backbone-live: admit complete execution inventory", flush=True)
    globals()["SERVICE_PLAN"] = provision_backbone_services()
    ensure_cluster_image()
    reset_generated_phase30_state()
    volumes = [prepare_volume(f"phase30-minio-{index}", STORAGE_PLAN["inventory"][f"phase30-minio-{index}"]) for index in range(4)]
    source_dir = RETAINED_ROOT / "mounts/phase30-registry-source"
    prepare_volume("phase30-registry-source", STORAGE_PLAN["inventory"]["phase30-registry-source"])
    print("platform-backbone-live: MetalLB and four-drive MinIO", flush=True)
    metallb = apply_metallb()
    minio = apply_minio(volumes)
    apply_native_stage("application-gateway")
    wait_on_delete_controller(PLATFORM_NAMESPACE, "StatefulSet", "object-gateway", 240)
    load_balancer = wait_for_load_balancer()
    with port_forward(PLATFORM_NAMESPACE, "service/minio-backend", MINIO_PORT, 9000):
        roundtrip = minio_roundtrip()
    print("platform-backbone-live: exact Phase-25 registry transfer and cutover", flush=True)
    registry = registry_rehome(source_dir)
    print("platform-backbone-live: Pulsar HA and size-triggered offload", flush=True)
    pulsar = apply_pulsar()
    writer_checks = writer_boundary_checks()
    restart_debt = gateway_restart_debt_check()
    roundtrip["writerAdmission"]["producerChecks"] = writer_checks
    roundtrip["writerAdmission"]["restartDebt"] = restart_debt
    roundtrip["writerAdmission"]["allPresentProducersGatewayBound"] = {row["producer"] for row in writer_checks} == {"registry", "pulsar-offload"}
    provenance = image_and_resource_evidence()
    provenance["ssaProjection"] = verify_ssa_projection()
    provenance["fullHaskellRenderProjection"] = verify_complete_haskell_render()
    provenance["haskellRenderProjection"] = verify_haskell_render_projection()
    pull_events = node_pull_event_evidence(gate_started)
    evidence = {
        "schema": "amoebius.phase30.backbone-live.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "artifactSource": {"digest": IMAGE_DIGEST, "imagePullPolicy": "Never", "publicPulls": 0, "pullEvents": pull_events},
        "metallb": metallb,
        "minio": minio,
        "minioRoundtrip": roundtrip,
        "storageProvision": STORAGE_PLAN,
        "physicalBacking": backing.observe_pool(RETAINED_ROOT),
        "executionProvision": SERVICE_PLAN,
        "executionAdmission": EXECUTION_ADMISSION,
        "storageIndependentObservation": observe_storage_provision(physical=True),
        "registryRehome": registry,
        "pulsar": pulsar,
        "loadBalancer": load_balancer,
        "provenance": provenance,
        "deferred": {"keycloak": "UNVERIFIED", "phase31Services": "UNVERIFIED", "singletonOwnedReconcile": "UNVERIFIED"},
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
    }
    genesis = pulsar["zookeeper"]["initialGenesis"]
    devices = {row["name"]: row["filesystemDevice"]
               for row in evidence["storageIndependentObservation"]["physicalObservation"]["volumes"]}
    genesis["verification"] = zookeeper_wire.verify_native_genesis_capture(EVIDENCE.parent / "zookeeper-genesis", genesis, devices)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--image-digest", required=True)
    arguments = parser.parse_args(argv)
    resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl"])
    globals()["CABAL"] = os.environ.get("AMOEBIUS_CABAL", resolved["cabal"]["path"])
    globals()["KIND"] = os.environ.get("AMOEBIUS_KIND", resolved["kind"]["path"])
    globals()["KUBECTL"] = os.environ.get("AMOEBIUS_KUBECTL", resolved["kubectl"]["path"])
    globals()["IMAGE_ARCHIVE"] = arguments.artifact
    globals()["IMAGE_DIGEST"] = arguments.image_digest
    globals()["PRIVATE_IMAGE"] = f"registry.amoebius.invalid:5000/amoebius/base@{arguments.image_digest}"
    globals()["EVIDENCE"] = arguments.output
    globals()["MINIO_ACCESS"] = "amoebius-" + secrets.token_hex(8)
    globals()["MINIO_SECRET"] = secrets.token_urlsafe(32)
    globals()["REGISTRY_ACCESS"] = "registry-" + secrets.token_hex(8)
    globals()["REGISTRY_SECRET"] = secrets.token_urlsafe(32)
    globals()["OFFLOAD_ACCESS"] = "offload-" + secrets.token_hex(8)
    globals()["OFFLOAD_SECRET"] = secrets.token_urlsafe(32)
    globals()["MEMBERLIST_SECRET"] = secrets.token_urlsafe(32)
    os.environ["AMOEBIUS_CABAL"] = CABAL
    os.environ["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
    globals()["KIND_CONFIG"] = materialize_kind_config(arguments.output.parent)
    try:
        containment.require_state_path(arguments.output, "build", actor="test")
        globals()["STORAGE_PLAN"] = provision_storage_plan()
        print(f"platform-backbone-live: preallocate {STORAGE_PLAN['physicalPoolRawBytes']} physical pool bytes before the Vault floor", flush=True)
        predecessor = bootstrap_vault_predecessor()
        address, pool = derive_load_balancer_pool()
        globals()["LOAD_BALANCER_ADDRESS"] = address
        globals()["LOAD_BALANCER_POOL"] = pool
        os.environ["AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_IMAGE"] = PRIVATE_IMAGE
        os.environ["AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_ADDRESS"] = LOAD_BALANCER_ADDRESS
        with observe_service_filesystems() as census_path:
            evidence = execute()
        census = json.loads(census_path.read_text())
        devices = {row["name"]: row["filesystemDevice"] for row in evidence["storageIndependentObservation"]["physicalObservation"]["volumes"]
                   if row["name"] in {"phase30-" + service + "-" + str(i) for service in ("bookkeeper", "zookeeper") for i in range(3)} | {"phase30-gateway-state"}}
        census["verification"] = service_census.verify_trace(census_path.parent, census, devices)
        evidence["serviceStorageCensus"] = census
        evidence["vaultPredecessor"] = predecessor
        arguments.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"platform-backbone-live: PASS (MetalLB, four-drive MinIO, registry {evidence['registryRehome']['backend']}, Pulsar HA/offload)")
        return 0
    except (
        BackboneLiveFailure,
        vault.VaultLiveFailure,
        project_cluster_fixture.FixtureFailure,
        backing.BackingError,
        toolchain.ResolutionError,
        containment.ContainmentError,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
        ElementTree.ParseError,
        zookeeper_wire.ZooKeeperObservationFailure,
    ) as problem:
        # Preserve bounded public diagnostics before the owning fixture cleans
        # up. Never dump Pod environments, Secrets or Vault's container logs.
        try:
            pods = json.loads(text(kubectl("get", "pods", "-A", "-o", "json")))
            selected = [pod for pod in pods["items"] if pod["metadata"]["namespace"] in
                        {METALLB_NAMESPACE, PLATFORM_NAMESPACE, PULSAR_NAMESPACE}]
            (EVIDENCE.parent / "failure-pod-status.json").write_text(json.dumps([
                {"metadata": {key: pod["metadata"][key] for key in ("name", "namespace")}, "status": pod.get("status", {})}
                for pod in selected], sort_keys=True, indent=2) + "\n")
            for pod in selected:
                for previous in (False, True):
                    meta = pod["metadata"]
                    result = kubectl("-n", meta["namespace"], "logs", meta["name"], "--limit-bytes=131072",
                                     *(["--previous"] if previous else []), check=False, timeout=15)
                    content = text(result)
                    for sensitive in (MINIO_ACCESS, MINIO_SECRET, REGISTRY_ACCESS, REGISTRY_SECRET, OFFLOAD_ACCESS, OFFLOAD_SECRET, MEMBERLIST_SECRET):
                        if sensitive:
                            content = content.replace(sensitive, "<redacted>")
                    (EVIDENCE.parent / ("failure-" + meta["name"] + ("-previous" if previous else "") + ".log")).write_text(content)
        except Exception:
            pass  # The original failure and owning cleanup remain authoritative.
        print(f"platform-backbone-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
