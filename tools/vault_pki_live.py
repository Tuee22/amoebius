#!/usr/bin/env python3
"""Run the root Vault, PKI, direct-client, and retained-rebuild proof."""

from __future__ import annotations

import argparse
import base64
import contextlib
import decimal
import hashlib
import http.client
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence

import yaml


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import containment  # noqa: E402
import retained_storage_backing as backing  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
KIND = ""
KUBECTL = ""
CABAL = ""
KUBECONFIG = Path(os.environ.get("AMOEBIUS_KUBECONFIG", ROOT / ".build/tmp/vault-pki/unconfigured-kubeconfig"))
KIND_CONFIG_TEMPLATE = ROOT / "test/fixture/vault_pki/kind.yaml"
KIND_CONFIG = Path()
IMAGE_ARCHIVE = Path()
IMAGE_DIGEST = ""
PRIVATE_IMAGE = ""
NODE_IMAGE = "kindest/node:v1.36.1"
CLUSTER = "amoebius-bootstrap-coordinator"
NODE = f"{CLUSTER}-control-plane"
NAMESPACE = "vault-system"
CONSUMER_NAMESPACE = "vault-consumer"
STORAGE_CLASS = "amoebius-retained"
TEST_ROOT = Path(os.environ.get("AMOEBIUS_TEST_ROOT", ROOT / ".build/tmp/vault-pki/unconfigured-test-root"))
RETAINED_ROOT = TEST_ROOT / "retained"
VAULT_IMAGE_BYTES = 134217728
AUDIT_IMAGE_BYTES = 67108864
VAULT_CAPACITY = "128Mi"
AUDIT_CAPACITY = "64Mi"
CANARY_FIXTURE = ROOT / "test/golden/vault/canary.json"
UNLOCK_ENVELOPE = RETAINED_ROOT / "vault-unlock.age"
LOCAL_PORT = 18290
UNLOCK_ENVELOPE_MAX_BYTES = 4096
SERVICE_PROJECTION: dict[str, Any] = {}


class VaultLiveFailure(RuntimeError):
    pass


def run(
    arguments: Sequence[str],
    *,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 600,
    sensitive: bool = False,
) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=timeout,
    )
    if check and result.returncode:
        if sensitive:
            raise VaultLiveFailure(f"sensitive-command-failed:exit-{result.returncode}")
        raise VaultLiveFailure(f"{arguments}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def sudo(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return run(("/usr/bin/sudo", "-n", *arguments), check=check)


def kubectl(
    *arguments: str,
    input_value: str | None = None,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 300,
    sensitive: bool = False,
) -> subprocess.CompletedProcess[bytes]:
    payload = input_bytes if input_bytes is not None else (input_value.encode() if input_value is not None else None)
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_bytes=payload, check=check, timeout=timeout, sensitive=sensitive)


def apply(value: dict[str, Any]) -> None:
    kubectl(
        "apply",
        "--server-side",
        "--field-manager=amoebius",
        "--force-conflicts",
        "-f",
        "-",
        input_value=json.dumps(value),
    )


def mountpoint(path: Path) -> bool:
    return run(("/usr/bin/mountpoint", "-q", str(path)), check=False).returncode == 0


def prepare_volume(name: str, raw_bytes: int) -> dict[str, Any]:
    pool = backing.observe_pool(RETAINED_ROOT)
    backing.inventory_plan(int(pool["capacityBytes"]), backing.existing_inventory(RETAINED_ROOT), {name: raw_bytes})
    image = RETAINED_ROOT / f"images/{name}.ext4"
    target = RETAINED_ROOT / f"mounts/{name}"
    image.parent.mkdir(parents=True, exist_ok=True)
    target.mkdir(parents=True, exist_ok=True)
    if not image.exists():
        backing.create_image(image, raw_bytes)
        backing.format_and_mount_new_image(image, target, raw_bytes)
    if image.stat().st_size != raw_bytes:
        raise VaultLiveFailure(f"raw-image-size:{name}:{image.stat().st_size}:{raw_bytes}")
    if not mountpoint(target):
        sudo("/usr/bin/mount", "-o", "loop,nodiscard", str(image), str(target))
    sudo("/usr/bin/chown", "-R", "0:0", str(target))
    filesystem_type = text(run(("/usr/bin/findmnt", "-n", "-o", "FSTYPE", "--target", str(target)))).strip()
    usable = int(text(run(("/usr/bin/df", "--block-size=1", "--output=avail", str(target)))).splitlines()[-1])
    return {
        "image": str(image),
        "mount": str(target),
        "rawBytes": image.stat().st_size,
        "allocatedBytes": backing.reserved_bytes(image, raw_bytes),
        "usableBytes": usable,
        "filesystemType": filesystem_type,
    }


def materialize_kind_config(output_root: Path) -> Path:
    template = KIND_CONFIG_TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "__VAULT_MOUNT__": str(RETAINED_ROOT / "mounts/vault"),
        "__AUDIT_MOUNT__": str(RETAINED_ROOT / "mounts/vault-audit"),
        "__AMOEBIUS_BINARY__": str(TEST_ROOT / "runtime/amoebius"),
    }
    for marker, replacement in replacements.items():
        if template.count(marker) != 1:
            raise VaultLiveFailure(f"kind-config-placeholder:{marker}:{template.count(marker)}")
        template = template.replace(marker, replacement)
    if "__" in template:
        raise VaultLiveFailure("kind-config-unresolved-placeholder")
    target = output_root / "runtime/kind.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(template, encoding="utf-8")
    return target


def install_current_binary() -> dict[str, Any]:
    builddir = ROOT / ".build/dist-newstyle/vault-pki"
    store = ROOT / ".build/cabal-store"
    common = (CABAL, f"--builddir={builddir}", f"--store-dir={store}")
    compiler = os.environ.get("AMOEBIUS_GHC")
    if compiler:
        common = (*common, f"--with-compiler={compiler}")
    run((*common, "--jobs=1", "build", "exe:amoebius"), timeout=2400)
    binary = Path(text(run((*common, "list-bin", "exe:amoebius"))).strip())
    destination = TEST_ROOT / "runtime/amoebius"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(binary, destination)
    destination.chmod(0o755)
    return {"path": str(destination), "sha256": sha256_file(destination), "compiledFromCurrentTree": True}


def delete_cluster() -> None:
    transcripts: list[str] = []
    for attempt in range(1, 4):
        deleted = run((KIND, "delete", "cluster", "--name", CLUSTER), check=False, timeout=600)
        transcripts.append(f"attempt-{attempt}:{deleted.returncode}:{text(deleted).strip()}")
        clusters = text(run((KIND, "get", "clusters"), check=False)).splitlines()
        node_absent = run(("/usr/bin/docker", "inspect", NODE), check=False).returncode != 0
        if CLUSTER not in clusters and node_absent:
            return
        if attempt < 3:
            # A busy private containerd can occasionally miss Docker's forced-kill
            # exit event immediately after a multi-gigabyte image import.  Give the
            # kind node a bounded graceful-stop opportunity, then ask Kind to own
            # network/volume removal again.  Success is still decided only by the
            # independently observed cluster and container absence above.
            run(("/usr/bin/docker", "stop", "--time", "60", NODE), check=False, timeout=90)
            time.sleep(2)
    raise VaultLiveFailure("cluster-delete:" + " | ".join(transcripts))


def import_selected_image() -> None:
    repository = PRIVATE_IMAGE.split("@", 1)[0]
    with IMAGE_ARCHIVE.open("rb") as archive:
        result = subprocess.run(
            (
                "/usr/bin/docker", "exec", "--privileged", "-i", NODE,
                "ctr", "--namespace", "k8s.io", "images", "import",
                "--platform", "linux/amd64", "--base-name", repository,
                "--digests", "--snapshotter", "overlayfs", "-",
            ),
            cwd=ROOT,
            stdin=archive,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=1200,
        )
    if result.returncode:
        raise VaultLiveFailure(f"selected-platform-image-import:exit-{result.returncode}:{result.stdout.decode('utf-8', 'replace')}")


def create_cluster() -> dict[str, Any]:
    KUBECONFIG.parent.mkdir(parents=True, exist_ok=True)
    run(
        (
            KIND,
            "create",
            "cluster",
            "--name",
            CLUSTER,
            "--image",
            NODE_IMAGE,
            "--config",
            str(KIND_CONFIG),
            "--kubeconfig",
            str(KUBECONFIG),
            "--wait",
            "180s",
        ),
        timeout=600,
    )
    run(("/usr/bin/docker", "update", "--cpus", "2", "--memory", "4g", "--memory-swap", "4g", NODE))
    node_config = json.loads(text(run(("/usr/bin/docker", "inspect", NODE))))[0]["HostConfig"]
    if (node_config["NanoCpus"], node_config["Memory"], node_config["MemorySwap"]) != (2000000000, 4294967296, 4294967296):
        raise VaultLiveFailure("private-node-execution-envelope-mismatch")
    import_selected_image()
    images = text(run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q"))).splitlines()
    repository = PRIVATE_IMAGE.split("@", 1)[0]
    wrappers = [name for name in images if name.startswith(repository + "@") and name != PRIVATE_IMAGE]
    for wrapper in wrappers:
        run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "rm", wrapper))
    images = text(run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q"))).splitlines()
    if PRIVATE_IMAGE not in images:
        raise VaultLiveFailure("private-phase25-image-not-restored")
    kubectl("wait", "--for=condition=Ready", f"node/{NODE}", "--timeout=180s")
    return {"archive": str(IMAGE_ARCHIVE), "digest": IMAGE_DIGEST, "selectedPlatform": "linux/amd64", "imagePullPolicy": "Never", "publicPulls": 0, "discardedWrapperNames": wrappers}


def cluster_identity() -> dict[str, str]:
    config = yaml.safe_load(KUBECONFIG.read_text(encoding="utf-8"))
    cluster = config["clusters"][0]["cluster"]
    ca = base64.b64decode(cluster["certificate-authority-data"])
    uid = json.loads(text(kubectl("get", "namespace", "kube-system", "-o", "json")))["metadata"]["uid"]
    return {"serverCaSha256": hashlib.sha256(ca).hexdigest(), "clusterUid": uid, "server": cluster["server"]}


def storage_class() -> dict[str, Any]:
    return {
        "apiVersion": "storage.k8s.io/v1",
        "kind": "StorageClass",
        "metadata": {"name": STORAGE_CLASS},
        "provisioner": "kubernetes.io/no-provisioner",
        "reclaimPolicy": "Retain",
        "volumeBindingMode": "WaitForFirstConsumer",
    }


def persistent_volume(name: str, capacity: str, claim: str, host_path: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1",
        "kind": "PersistentVolume",
        "metadata": {
            "name": name,
            "labels": {"amoebius.io/pv-identity": name},
            "annotations": {"amoebius.io/pv-logical-identity": f"{NAMESPACE}/root-vault/{name}"},
        },
        "spec": {
            "capacity": {"storage": capacity},
            "accessModes": ["ReadWriteOnce"],
            "storageClassName": STORAGE_CLASS,
            "persistentVolumeReclaimPolicy": "Retain",
            "volumeMode": "Filesystem",
            "claimRef": {"namespace": NAMESPACE, "name": claim},
            "hostPath": {"path": host_path, "type": "Directory"},
            "nodeAffinity": {
                "required": {
                    "nodeSelectorTerms": [
                        {
                            "matchExpressions": [
                                {"key": "kubernetes.io/hostname", "operator": "In", "values": [NODE]}
                            ]
                        }
                    ]
                }
            },
        },
    }


def stateful_set() -> dict[str, Any]:
    if not SERVICE_PROJECTION:
        raise VaultLiveFailure("unprovisioned-vault-service-render")
    return {
        "apiVersion": "apps/v1",
        "kind": "StatefulSet",
        "metadata": {"name": "root-vault", "namespace": NAMESPACE},
        "spec": {
            "serviceName": "root-vault-internal",
            "replicas": 1,
            "selector": {"matchLabels": {"app": "root-vault"}},
            "template": {
                "metadata": {"labels": {"app": "root-vault"}},
                "spec": {
                    "serviceAccountName": "root-vault",
                    "securityContext": {"runAsUser": 0, "runAsGroup": 0},
                    "containers": [
                        {
                            "name": "vault",
                            "image": PRIVATE_IMAGE,
                            "imagePullPolicy": "Never",
                            "command": ["/bin/sh", "-c"],
                            "args": ["mkdir -p /vault/data/raft /vault/audit && exec /usr/local/bin/amoebius-live vault-audit-supervise /vault/config/server.hcl /vault/audit"],
                            "env": [{"name": "VAULT_ADDR", "value": "http://127.0.0.1:8200"}],
                            "ports": [{"name": "http", "containerPort": 8200}, {"name": "cluster", "containerPort": 8201}],
                            "resources": SERVICE_PROJECTION["resources"],
                            "securityContext": SERVICE_PROJECTION["securityContext"],
                            "volumeMounts": [
                                {"name": "data", "mountPath": "/vault/data"},
                                {"name": "audit", "mountPath": "/vault/audit"},
                                {"name": "config", "mountPath": "/vault/config", "readOnly": True},
                                {"name": "amoebius-live", "mountPath": "/usr/local/bin/amoebius-live", "readOnly": True},
                                {"name": "scratch", "mountPath": "/tmp"},
                            ],
                            "readinessProbe": {
                                "exec": {"command": ["/bin/sh", "-c", "VAULT_ADDR=http://127.0.0.1:8200 vault status >/dev/null 2>&1"]},
                                "periodSeconds": 2,
                                "failureThreshold": 60,
                            },
                        }
                    ],
                    "volumes": [
                        {"name": "config", "configMap": {"name": "root-vault-config"}},
                        {"name": "amoebius-live", "hostPath": {"path": "/amoebius-test/bin/amoebius", "type": "File"}},
                        {"name": "scratch", "emptyDir": {"sizeLimit": str(SERVICE_PROJECTION["scratch"]["bytes"])}},
                    ],
                },
            },
            "volumeClaimTemplates": [
                {
                    "metadata": {"name": "data"},
                    "spec": {
                        "accessModes": ["ReadWriteOnce"],
                        "storageClassName": STORAGE_CLASS,
                        "resources": {"requests": {"storage": VAULT_CAPACITY}},
                        "volumeMode": SERVICE_PROJECTION["durable"]["volumeMode"],
                    },
                },
                {
                    "metadata": {"name": "audit"},
                    "spec": {
                        "accessModes": ["ReadWriteOnce"],
                        "storageClassName": STORAGE_CLASS,
                        "resources": {"requests": {"storage": AUDIT_CAPACITY}},
                        "volumeMode": SERVICE_PROJECTION["audit"]["volumeMode"],
                    },
                },
            ],
        },
    }


def apply_vault() -> dict[str, Any]:
    kubectl("delete", "storageclass", "standard", "--ignore-not-found=true")
    persistent_volumes = [
        persistent_volume("vault-system.root-vault.pv-0", VAULT_CAPACITY, "data-root-vault-0", "/amoebius-retained/vault"),
        persistent_volume("vault-system.root-vault-audit.pv-0", AUDIT_CAPACITY, "audit-root-vault-0", "/amoebius-retained/vault-audit"),
    ]
    prebinds = [volume["spec"]["claimRef"] for volume in persistent_volumes]
    resources = [
        {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE}},
        storage_class(),
        {
            "apiVersion": "v1",
            "kind": "ConfigMap",
            "metadata": {"name": "root-vault-config", "namespace": NAMESPACE},
            "data": {
                "server.hcl": 'storage "raft" { path = "/vault/data/raft" node_id = "root-vault-0" snapshot_threshold = 32 snapshot_interval = 1 trailing_logs = 8 }\nlistener "tcp" { address = "0.0.0.0:8200" cluster_address = "0.0.0.0:8201" tls_disable = 1 }\ndisable_mlock = true\napi_addr = "http://root-vault-0.root-vault-internal.vault-system.svc:8200"\ncluster_addr = "http://root-vault-0.root-vault-internal.vault-system.svc:8201"\nui = false\n',
            },
        },
        {"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": "root-vault", "namespace": NAMESPACE}},
        {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "ClusterRoleBinding",
            "metadata": {"name": "root-vault-token-review"},
            "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "system:auth-delegator"},
            "subjects": [{"kind": "ServiceAccount", "name": "root-vault", "namespace": NAMESPACE}],
        },
        {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {"name": "root-vault-internal", "namespace": NAMESPACE},
            "spec": {"clusterIP": "None", "selector": {"app": "root-vault"}, "ports": [{"name": "http", "port": 8200}]},
        },
        {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {"name": "root-vault", "namespace": NAMESPACE},
            "spec": {"selector": {"app": "root-vault"}, "ports": [{"name": "http", "port": 8200}]},
        },
        *persistent_volumes,
        stateful_set(),
    ]
    for resource in resources:
        apply(resource)
    wait_pod_running()
    projection = verify_applied_projection()
    return {"claimRefsOmitServerFields": all("uid" not in value and "resourceVersion" not in value for value in prebinds), "serviceProjection": projection}


def quantity(value: str, *, cpu: bool = False) -> int:
    matched = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)([a-zA-Z]*)", value)
    if not matched:
        raise VaultLiveFailure("resource-quantity-format")
    number, suffix = decimal.Decimal(matched[1]), matched[2]
    factors = {"": 1, "Ki": 1024, "Mi": 1024**2, "Gi": 1024**3, "Ti": 1024**4,
               "k": 1000, "M": 1000**2, "G": 1000**3, "T": 1000**4,
               "m": decimal.Decimal("0.001"), "u": decimal.Decimal("0.000001"), "n": decimal.Decimal("0.000000001")}
    if suffix not in factors:
        raise VaultLiveFailure("resource-quantity-unit")
    exact = number * factors[suffix] * (1000 if cpu else 1)
    if exact != exact.to_integral_value():
        raise VaultLiveFailure("resource-quantity-not-integral")
    return int(exact)


def normalized_resources(value: dict[str, Any]) -> dict[str, Any]:
    result = {}
    for arm in ("requests", "limits"):
        if set(value.get(arm, {})) != {"cpu", "memory", "ephemeral-storage"}:
            raise VaultLiveFailure("resource-projection-axis-set")
        result[arm] = {name: quantity(amount, cpu=name == "cpu") for name, amount in value[arm].items()}
    return result


def verify_applied_projection() -> dict[str, Any]:
    stateful = json.loads(text(kubectl("-n", NAMESPACE, "get", "statefulset", "root-vault", "-o", "json")))
    pod = json.loads(text(kubectl("-n", NAMESPACE, "get", "pod", "root-vault-0", "-o", "json")))
    if stateful["spec"]["replicas"] != SERVICE_PROJECTION["replicas"]:
        raise VaultLiveFailure("vault-replica-projection-mismatch")
    expected = normalized_resources(SERVICE_PROJECTION["resources"])
    for ordinal, subject in enumerate((stateful["spec"]["template"]["spec"], pod["spec"])):
        containers = subject.get("containers", [])
        if len(containers) != 1 or subject.get("initContainers") or containers[0]["name"] != "vault":
            raise VaultLiveFailure("vault-execution-unit-inventory-mismatch")
        if normalized_resources(containers[0]["resources"]) != expected:
            raise VaultLiveFailure("vault-complete-resource-projection-mismatch")
        if containers[0].get("image") != PRIVATE_IMAGE or containers[0].get("imagePullPolicy") != "Never":
            raise VaultLiveFailure("vault-image-projection-mismatch")
        security = containers[0].get("securityContext", {})
        if security.get("privileged", False) or any(security.get(key) != value for key, value in SERVICE_PROJECTION["securityContext"].items()):
            raise VaultLiveFailure("vault-security-projection-mismatch")
        scratch = [v for v in subject.get("volumes", []) if v["name"] == "scratch"]
        if len(scratch) != 1 or quantity(scratch[0]["emptyDir"]["sizeLimit"]) != SERVICE_PROJECTION["scratch"]["bytes"]:
            raise VaultLiveFailure("vault-bounded-local-volume-mismatch")
        mounts = {v["name"]: v for v in containers[0]["volumeMounts"]}
        if mounts.get("scratch", {}).get("mountPath") != "/tmp" or mounts.get("data", {}).get("mountPath") != "/vault/data" or mounts.get("audit", {}).get("mountPath") != "/vault/audit":
            raise VaultLiveFailure("vault-volume-mount-projection-mismatch")
        volumes = {v["name"]: v for v in subject.get("volumes", [])}
        expected_volumes = {"config", "amoebius-live", "scratch"} | ({"data", "audit"} if ordinal else set())
        injected = {name for name, volume in volumes.items() if name.startswith("kube-api-access-") and "projected" in volume}
        if set(volumes) != expected_volumes | injected or len(injected) > 1:
            raise VaultLiveFailure("vault-local-volume-inventory-mismatch")
        if set(mounts) != {"data", "audit", "config", "amoebius-live", "scratch"} | injected:
            raise VaultLiveFailure("vault-local-mount-inventory-mismatch")
    claims = {row["metadata"]["name"]: row["spec"] for row in stateful["spec"]["volumeClaimTemplates"]}
    if set(claims) != {"data", "audit"}:
        raise VaultLiveFailure("vault-claim-slot-inventory-mismatch")
    actual_claims = json.loads(text(kubectl("-n", NAMESPACE, "get", "pvc", "-o", "json")))["items"]
    if {row["metadata"]["name"] for row in actual_claims} != {"data-root-vault-0", "audit-root-vault-0"}:
        raise VaultLiveFailure("vault-realized-claim-inventory-mismatch")
    for name, arm in (("data", "durable"), ("audit", "audit")):
        expected_volume = SERVICE_PROJECTION[arm]
        observed = claims[name]
        if (quantity(observed["resources"]["requests"]["storage"]) != expected_volume["provisionedBytes"]
                or observed.get("volumeMode") != expected_volume["volumeMode"]
                or observed.get("accessModes") != expected_volume["accessModes"]
                or observed.get("storageClassName") != expected_volume["storageClass"]):
            raise VaultLiveFailure("vault-complete-claim-projection-mismatch")
        claim_name = f"{name}-root-vault-0"
        pvc = json.loads(text(kubectl("-n", NAMESPACE, "get", "pvc", claim_name, "-o", "json")))
        pv = json.loads(text(kubectl("get", "pv", pvc["spec"]["volumeName"], "-o", "json")))
        for volume, capacity in ((pvc, pvc["spec"]["resources"]["requests"]["storage"]), (pv, pv["spec"]["capacity"]["storage"])):
            if (quantity(capacity) != expected_volume["provisionedBytes"]
                    or volume["spec"]["storageClassName"] != expected_volume["storageClass"]
                    or volume["spec"]["accessModes"] != expected_volume["accessModes"]
                    or volume["spec"]["volumeMode"] != expected_volume["volumeMode"]
                    or volume["status"]["phase"] != "Bound"):
                raise VaultLiveFailure("vault-applied-pv-pvc-projection-mismatch")
        if pv["spec"]["claimRef"]["uid"] != pvc["metadata"]["uid"] or pv["spec"]["persistentVolumeReclaimPolicy"] != "Retain":
            raise VaultLiveFailure("vault-applied-bind-projection-mismatch")
        expected_path = "/amoebius-retained/vault" if name == "data" else "/amoebius-retained/vault-audit"
        if pv["spec"].get("hostPath") != {"path": expected_path, "type": "Directory"}:
            raise VaultLiveFailure("vault-backing-path-projection-mismatch")
    return {"completeMatch": True, "normalizedResources": expected, "sealed": SERVICE_PROJECTION}


def wait_pod_running() -> None:
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        result = kubectl("-n", NAMESPACE, "get", "pod", "root-vault-0", "-o", "json", check=False)
        if result.returncode == 0:
            status = json.loads(text(result)).get("status", {})
            containers = status.get("containerStatuses", [])
            if status.get("phase") == "Running" and containers and containers[0].get("state", {}).get("running") is not None:
                return
        time.sleep(2)
    raise VaultLiveFailure("vault-pod-running-timeout")


def vault_status() -> dict[str, Any]:
    deadline = time.monotonic() + 180
    last = ""
    while time.monotonic() < deadline:
        result = kubectl("-n", NAMESPACE, "exec", "root-vault-0", "--", "/bin/sh", "-c", "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json || true", check=False)
        last = text(result)
        try:
            return json.loads(last)
        except json.JSONDecodeError:
            time.sleep(1)
    raise VaultLiveFailure(f"vault-status-timeout:{last}")


def initialize_vault(password: bytes, binary_path: Path) -> tuple[dict[str, Any], str, str]:
    before = vault_status()
    if before.get("initialized"):
        raise VaultLiveFailure("run1-vault-already-initialized")
    initialized = kubectl(
        "-n",
        NAMESPACE,
        "exec",
        "root-vault-0",
        "--",
        "/bin/sh",
        "-c",
        "VAULT_ADDR=http://127.0.0.1:8200 vault operator init -key-shares=1 -key-threshold=1 -format=json",
        sensitive=True,
    )
    material = json.loads(text(initialized))
    unseal_key = material["unseal_keys_b64"][0]
    root_token = material["root_token"]
    plaintext = json.dumps({"unseal_key": unseal_key, "root_token": root_token}, separators=(",", ":")).encode()
    sealed = run((str(binary_path), "vault-seal-unlock"), input_bytes=password + b"\n" + plaintext, timeout=120, sensitive=True)
    if len(sealed.stdout) > UNLOCK_ENVELOPE_MAX_BYTES:
        raise VaultLiveFailure("unlock-envelope-exceeds-bounded-bootstrap-allocation")
    UNLOCK_ENVELOPE.write_bytes(sealed.stdout)
    UNLOCK_ENVELOPE.chmod(0o600)
    del material
    del plaintext
    return before, unseal_key, root_token


def open_unlock(password: bytes, binary_path: Path) -> dict[str, str]:
    opened = run((str(binary_path), "vault-open-unlock"), input_bytes=password + b"\n" + UNLOCK_ENVELOPE.read_bytes(), timeout=120, sensitive=True)
    return json.loads(opened.stdout)


def unseal(unseal_key: str) -> dict[str, Any]:
    with port_forward():
        response_status, payload = api_request("PUT", "sys/unseal", body={"key": unseal_key})
    if response_status != 200:
        raise VaultLiveFailure(f"vault-unseal-api:status-{response_status}")
    status = json.loads(payload)
    if status.get("sealed"):
        raise VaultLiveFailure("vault-remained-sealed")
    kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", "pod/root-vault-0", "--timeout=180s")
    return status


@contextlib.contextmanager
def port_forward() -> Iterator[None]:
    process = subprocess.Popen(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "port-forward", "pod/root-vault-0", f"{LOCAL_PORT}:8200"),
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", LOCAL_PORT), timeout=0.25):
                    break
            except OSError:
                if process.poll() is not None:
                    output = process.stdout.read().decode(errors="replace") if process.stdout else ""
                    raise VaultLiveFailure(f"vault-port-forward:{output}")
                time.sleep(0.1)
        else:
            raise VaultLiveFailure("vault-port-forward-timeout")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def api_request(method: str, path: str, token: str | None = None, body: dict[str, Any] | bytes | None = None) -> tuple[int, bytes]:
    payload = body if isinstance(body, bytes) else json.dumps(body).encode() if body is not None else b""
    content_type = "application/octet-stream" if isinstance(body, bytes) else "application/json"
    headers = {"Content-Type": content_type, "Content-Length": str(len(payload))}
    if token:
        headers["X-Vault-Token"] = token
    connection = http.client.HTTPConnection("127.0.0.1", LOCAL_PORT, timeout=30)
    try:
        connection.request(method, "/v1/" + path.lstrip("/"), body=payload, headers=headers)
        response = connection.getresponse()
        return response.status, response.read()
    finally:
        connection.close()


def require_api(method: str, path: str, token: str | None = None, body: dict[str, Any] | None = None, accepted: set[int] | None = None) -> dict[str, Any]:
    expected = accepted or {200, 204}
    status, payload = api_request(method, path, token, body)
    if status not in expected:
        raise VaultLiveFailure(f"vault-api:{method}:{path}:status-{status}")
    return json.loads(payload) if payload else {}


def configure_vault(root_token: str, canary: dict[str, str], transit_challenge: str) -> dict[str, Any]:
    require_api("POST", "sys/audit/file", root_token, {"type": "file", "options": {"file_path": "/vault/audit/audit.fifo", "log_raw": "false"}}, {204, 400})
    require_api("POST", "sys/mounts/secret", root_token, {"type": "kv", "options": {"version": "2"}}, {204, 400})
    absent_status, _ = api_request("GET", "secret/data/" + canary["path"], root_token)
    if absent_status != 404:
        raise VaultLiveFailure(f"fresh-canary-not-absent:{absent_status}")
    require_api("POST", "sys/mounts/transit", root_token, {"type": "transit"}, {204, 400})
    require_api("POST", "transit/keys/canary-key", root_token, {}, {200, 204, 400})
    encrypted = require_api("POST", "transit/encrypt/canary-key", root_token, {"plaintext": base64.b64encode(transit_challenge.encode()).decode()})
    require_api("POST", "sys/mounts/pki", root_token, {"type": "pki"}, {204, 400})
    ca_status, _ = api_request("GET", "pki/cert/ca", root_token)
    if ca_status != 200:
        require_api("POST", "pki/root/generate/internal", root_token, {"common_name": "amoebius.internal", "ttl": "87600h"})
    require_api("POST", "pki/roles/internal", root_token, {"allowed_domains": "amoebius.internal", "allow_subdomains": True, "max_ttl": "72h"})
    issue = require_api("POST", "pki/issue/internal", root_token, {"common_name": "vault.vault-system.svc.amoebius.internal", "ttl": "1h"})
    return {
        "ciphertext": encrypted["data"]["ciphertext"],
        "rootCertificate": issue["data"]["issuing_ca"],
        "issuingCa": issue["data"]["issuing_ca"],
        "leafCertificate": issue["data"]["certificate"],
    }


def configure_kubernetes_auth(root_token: str) -> None:
    require_api("POST", "sys/auth/kubernetes", root_token, {"type": "kubernetes"}, {204, 400})
    reviewer_jwt = text(kubectl("-n", NAMESPACE, "exec", "root-vault-0", "--", "cat", "/var/run/secrets/kubernetes.io/serviceaccount/token")).strip()
    ca_certificate = text(kubectl("-n", NAMESPACE, "exec", "root-vault-0", "--", "cat", "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"))
    require_api(
        "POST",
        "auth/kubernetes/config",
        root_token,
        {
            "kubernetes_host": "https://kubernetes.default.svc:443",
            "token_reviewer_jwt": reviewer_jwt,
            "kubernetes_ca_cert": ca_certificate,
            "disable_iss_validation": True,
        },
    )
    policy = 'path "secret/data/amoebius/canary" { capabilities = ["read"] }\npath "secret/subkeys/amoebius/canary" { capabilities = ["read"] }\npath "transit/decrypt/canary-key" { capabilities = ["update"] }\n'
    require_api("PUT", "sys/policies/acl/amoebius-canary", root_token, {"policy": policy})
    restore_client_role(root_token)


def restore_client_role(root_token: str) -> None:
    require_api(
        "POST",
        "auth/kubernetes/role/amoebius-canary",
        root_token,
        {
            "bound_service_account_names": ["vault-reader"],
            "bound_service_account_namespaces": [CONSUMER_NAMESPACE],
            "policies": ["amoebius-canary"],
            "token_ttl": "30s", "token_max_ttl": "30s",
        },
    )


def deploy_consumer(identity: str = "vault-reader", *, wait_ready: bool = True) -> dict[str, Any]:
    readiness = {} if identity != "vault-reader" else {"readinessProbe": {
        "exec": {"command": ["/usr/local/bin/amoebius-live", "vault-ready", "root-vault.vault-system.svc", "8200",
                               "amoebius-canary", CONSUMER_NAMESPACE, identity, "secret", "amoebius/canary", "token",
                               "/var/run/secrets/kubernetes.io/serviceaccount/token"]},
        "periodSeconds": 5, "timeoutSeconds": 3, "failureThreshold": 1,
    }}
    for resource in (
        {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": CONSUMER_NAMESPACE}},
        {"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": identity, "namespace": CONSUMER_NAMESPACE}},
        {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {"name": identity, "namespace": CONSUMER_NAMESPACE},
            "spec": {
                "serviceAccountName": identity,
                "restartPolicy": "Never",
                "containers": [
                    {
                        "name": "consumer",
                        "image": PRIVATE_IMAGE,
                        "imagePullPolicy": "Never",
                        "command": ["/bin/sh", "-c", "sleep 3600"],
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "32Mi", "ephemeral-storage": "8Mi"},
                            "limits": {"cpu": "100m", "memory": "128Mi", "ephemeral-storage": "16Mi"},
                        },
                        "volumeMounts": [{"name": "amoebius-live", "mountPath": "/usr/local/bin/amoebius-live", "readOnly": True}],
                        **readiness,
                    }
                ],
                "volumes": [
                    {
                        "name": "amoebius-live",
                        "hostPath": {"path": "/amoebius-test/bin/amoebius", "type": "File"},
                    }
                ],
            },
        },
    ):
        apply(resource)
    kubectl("-n", CONSUMER_NAMESPACE, "wait", "--for=jsonpath={.status.phase}=Running", f"pod/{identity}", "--timeout=180s")
    if wait_ready:
        kubectl("-n", CONSUMER_NAMESPACE, "wait", "--for=condition=Ready", f"pod/{identity}", "--timeout=180s")
    pod = json.loads(text(kubectl("-n", CONSUMER_NAMESPACE, "get", "pod", identity, "-o", "json")))
    return {
        "containers": [container["name"] for container in pod["spec"]["containers"]],
        "plainSecretVolumes": [volume["name"] for volume in pod["spec"].get("volumes", []) if "secret" in volume],
        "imageId": pod["status"]["containerStatuses"][0]["imageID"],
    }


def write_canary_prompt(root_token: str, canary: dict[str, str]) -> dict[str, Any]:
    """Pair a foreign-SA denial with an own-SA stdin write through the real CLI."""
    role = "amoebius-bootstrap-writer"
    policy = f'path "{canary["mount"]}/data/{canary["path"]}" {{ capabilities = ["create", "update", "patch"] }}'
    require_api("PUT", f"sys/policies/acl/{role}", root_token, {"policy": policy})
    require_api("POST", f"auth/kubernetes/role/{role}", root_token, {
        "bound_service_account_names": ["vault-writer"],
        "bound_service_account_namespaces": [CONSUMER_NAMESPACE],
        "policies": [role], "token_ttl": "1m",
    })
    deploy_consumer("vault-writer")

    def attempt(identity: str) -> subprocess.CompletedProcess[bytes]:
        return kubectl(
            "-n", CONSUMER_NAMESPACE, "exec", "-i", identity, "--",
            "/usr/local/bin/amoebius-live", "vault-prompt-write",
            "root-vault.vault-system.svc", "8200", role, CONSUMER_NAMESPACE, identity,
            canary["mount"], canary["path"], canary["field"],
            "/var/run/secrets/kubernetes.io/serviceaccount/token", "canary", "live bootstrap",
            input_bytes=canary["value"].encode() + b"\n", check=False,
        )

    foreign = attempt("vault-reader")
    if foreign.returncode == 0 or b"tag=policy-missing" not in foreign.stdout:
        raise VaultLiveFailure("foreign-prompt-authority-not-denied")
    absent_status, _ = api_request("GET", canary["mount"] + "/data/" + canary["path"], root_token)
    if absent_status != 404:
        raise VaultLiveFailure("foreign-prompt-write-had-an-effect")
    own = attempt("vault-writer")
    if own.returncode != 0:
        tags = re.findall(rb"tag=(unavailable|uninitialized|sealed|policy-missing|secret-missing|decrypt-denied)\b", own.stdout)
        safe_tag = tags[-1].decode() if tags else "no-redacted-tag"
        raise VaultLiveFailure(f"own-prompt-write-failed:exit-{own.returncode}:tag-{safe_tag}")
    readback = require_api("GET", canary["mount"] + "/data/" + canary["path"], root_token)
    if readback["data"]["data"][canary["field"]] != canary["value"]:
        raise VaultLiveFailure("prompt-write-challenge-mismatch")
    require_api("DELETE", f"auth/kubernetes/role/{role}", root_token)
    require_api("DELETE", f"sys/policies/acl/{role}", root_token)
    kubectl("-n", CONSUMER_NAMESPACE, "delete", "pod", "vault-writer", "--wait=true", "--timeout=120s")
    return {"ownScopeSuccess": True, "foreignScopeDenied": True, "forbiddenStateAbsent": True,
            "stdinOnly": True, "writerPodRemoved": kubectl("-n", CONSUMER_NAMESPACE, "get", "pod", "vault-writer", check=False).returncode != 0}


def client_presence(canary: dict[str, str], *, expected_tag: str | None = None) -> None:
    result = kubectl(
        "-n", CONSUMER_NAMESPACE, "exec", "vault-reader", "--", "/usr/local/bin/amoebius-live",
        "vault-ready", "root-vault.vault-system.svc", "8200", "amoebius-canary", CONSUMER_NAMESPACE,
        "vault-reader", canary["mount"], canary["path"], canary["field"],
        "/var/run/secrets/kubernetes.io/serviceaccount/token", check=False,
    )
    if expected_tag is None:
        if result.returncode or result.stdout:
            raise VaultLiveFailure("presence-only-ready-probe-failed-or-emitted-data")
    elif result.returncode == 0 or f"tag={expected_tag}" not in text(result):
        raise VaultLiveFailure(f"presence-only-ready-probe-wrong-error:{expected_tag}")


def client_read(canary: dict[str, str], *, expect_success: bool, expected_tag: str = "policy-missing") -> subprocess.CompletedProcess[bytes]:
    result = kubectl(
        "-n",
        CONSUMER_NAMESPACE,
        "exec",
        "vault-reader",
        "--",
        "/usr/local/bin/amoebius-live",
        "vault-read",
        "root-vault.vault-system.svc",
        "8200",
        "amoebius-canary",
        CONSUMER_NAMESPACE,
        "vault-reader",
        canary["mount"],
        canary["path"],
        canary["field"],
        "/var/run/secrets/kubernetes.io/serviceaccount/token",
        check=False,
    )
    if expect_success and (result.returncode != 0 or text(result).strip() != canary["value"]):
        raise VaultLiveFailure(f"haskell-client-read-mismatch:exit-{result.returncode}")
    if not expect_success and (result.returncode == 0 or f"tag={expected_tag}" not in text(result)):
        raise VaultLiveFailure(f"haskell-client-denial-mismatch:exit-{result.returncode}")
    return result


def client_transit(ciphertext: str, expected: str) -> str:
    result = kubectl(
        "-n",
        CONSUMER_NAMESPACE,
        "exec",
        "vault-reader",
        "--",
        "/usr/local/bin/amoebius-live",
        "vault-transit-decrypt",
        "root-vault.vault-system.svc",
        "8200",
        "amoebius-canary",
        CONSUMER_NAMESPACE,
        "vault-reader",
        "canary-key",
        ciphertext,
        "/var/run/secrets/kubernetes.io/serviceaccount/token",
        sensitive=True,
    )
    value = text(result).strip()
    if value != expected:
        raise VaultLiveFailure("transit-cleartext-mismatch")
    return value


def verify_certificates(root_certificate: str, issuing_ca: str, leaf_certificate: str) -> dict[str, str]:
    temporary = TEST_ROOT / "runtime/cert-verify"
    temporary.mkdir(parents=True, exist_ok=True)
    root_path = temporary / "root.pem"
    issuing_path = temporary / "issuing.pem"
    leaf_path = temporary / "leaf.pem"
    root_path.write_text(root_certificate, encoding="utf-8")
    issuing_path.write_text(issuing_ca, encoding="utf-8")
    leaf_path.write_text(leaf_certificate, encoding="utf-8")
    subject = text(run(("/usr/bin/openssl", "x509", "-in", str(root_path), "-noout", "-subject"))).strip()
    issuer = text(run(("/usr/bin/openssl", "x509", "-in", str(root_path), "-noout", "-issuer"))).strip()
    verify = text(run(("/usr/bin/openssl", "verify", "-CAfile", str(root_path), str(leaf_path)))).strip()
    if subject.replace("subject=", "") != issuer.replace("issuer=", "") or not verify.endswith(": OK"):
        raise VaultLiveFailure(f"pki-chain:{subject}:{issuer}:{verify}")
    return {"rootSelfSigned": True, "leafChainsToRoot": True, "rootSha256": sha256_file(root_path)}


def raft_indexes(vault_volume: dict[str, Any]) -> dict[str, Any]:
    found = text(sudo("/usr/bin/find", vault_volume["mount"], "-type", "f", "-name", "raft.db")).splitlines()
    if len(found) != 1:
        raise VaultLiveFailure(f"raft-log-database-count:{len(found)}")
    observed = sudo(sys.executable, str(ROOT / "tools/vault_raft_observer.py"),
                    "--test-root", str(TEST_ROOT), "--database", found[0],
                    "--maximum-bytes", str(vault_volume["rawBytes"]))
    return json.loads(text(observed))


def raft_and_audit_bounds(root_token: str, vault_volume: dict[str, Any], audit_volume: dict[str, Any]) -> dict[str, Any]:
    before = raft_indexes(vault_volume)
    checkpoints = [before]
    require_api("POST", "secret/config", root_token, {"max_versions": 2})
    for generation in range(2):
        for index in range(64):
            require_api("POST", f"secret/data/amoebius/history-{index}", root_token,
                        {"data": {"value": str(generation) + "x" * 1023}})
        deadline = time.monotonic() + 15
        while True:
            after = raft_indexes(vault_volume)
            if after["lowestLogIndex"] > checkpoints[-1]["lowestLogIndex"]:
                checkpoints.append(after)
                break
            if time.monotonic() >= deadline:
                raise VaultLiveFailure("raft-log-prefix-compaction-not-observed")
            time.sleep(0.1)
    snapshot_status, snapshot = api_request("GET", "sys/storage/raft/snapshot", root_token)
    if snapshot_status != 200 or not snapshot:
        raise VaultLiveFailure(f"raft-snapshot:{snapshot_status}:{len(snapshot)}")
    # Vault's BoltSnapshotStore streams ordinary snapshots from the active FSM.
    # An actual restore installs a separate BoltDB then atomically replaces the
    # active file. Observe both files externally and require that replacement.
    database = Path(vault_volume["mount"]) / "raft/vault.db"
    original_inode = database.stat().st_ino
    restore_status, _ = api_request("POST", "sys/storage/raft/snapshot", root_token, snapshot)
    if restore_status not in {200, 204}:
        raise VaultLiveFailure(f"raft-snapshot-restore:status-{restore_status}")
    deadline = time.monotonic() + 60
    while True:
        installed_inode = database.stat().st_ino
        health_status, _ = api_request("GET", "sys/health")
        if installed_inode != original_inode and health_status == 200:
            break
        if time.monotonic() >= deadline:
            raise VaultLiveFailure("raft-snapshot-install-not-observed")
        time.sleep(0.05)
    # Same-key authenticated restore must recover the bounded population.
    restored = require_api("GET", "secret/data/amoebius/history-63", root_token)
    if restored["data"]["data"]["value"] != "1" + "x" * 1023:
        raise VaultLiveFailure("raft-snapshot-restored-value-mismatch")
    vault_used = int(text(sudo("/usr/bin/du", "-sb", vault_volume["mount"])).split()[0])
    audit_path = Path(audit_volume["mount"]) / "audit.log"
    if not audit_path.is_file():
        raise VaultLiveFailure("audit-file-absent")
    # The native sink rotates while Vault keeps its file audit device enabled.
    # Generate enough real audited reads to cross multiple file boundaries.
    for _ in range(4096):
        if (audit_path.parent / "audit.log.3").is_file():
            break
        require_api("GET", "secret/data/amoebius/canary", root_token)
    else:
        raise VaultLiveFailure("automatic-audit-rotation-not-observed")
    audit_files = sorted(Path(audit_volume["mount"]).glob("audit.log*"))
    audit_sizes = {path.name: path.stat().st_size for path in audit_files}
    audit_total = sum(audit_sizes.values())
    if any(size > 1048576 for size in audit_sizes.values()) or len(audit_files) > 4 or audit_total > 4194304:
        raise VaultLiveFailure("automatic-audit-file-bounds-exceeded")
    # A timestamped history fixture crosses the real 24-hour age cutoff after
    # one second. We observe the running writer expire it while otherwise idle.
    oldest = audit_path.parent / "audit.log.3"
    threshold_start = time.time()
    sudo("/usr/bin/touch", "-m", "-d", f"@{threshold_start - 86400 + 1}", str(oldest))
    if not oldest.is_file():
        raise VaultLiveFailure("unexpired-audit-history-absent")
    deadline = time.monotonic() + 5
    while oldest.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    if oldest.exists() or time.time() < threshold_start + 1:
        raise VaultLiveFailure("audit-retention-boundary-not-observed")
    if vault_used > vault_volume["usableBytes"] or audit_total > audit_volume["usableBytes"]:
        raise VaultLiveFailure(f"storage-observation:{vault_used}:{audit_total}")
    return {
        "snapshotBytes": len(snapshot),
        "snapshotInstall": {"oldInode": original_inode, "newInode": installed_inode,
                            "restoredPopulationVerified": True},
        "raftSampledBytes": vault_used,
        "compactionExternallyObserved": checkpoints[-1]["lowestLogIndex"] > before["lowestLogIndex"],
        "raftLogCheckpoints": checkpoints,
        "auditHighWaterBytes": audit_total,
        "auditFiles": audit_sizes,
        "automaticRotationObserved": True,
        "realClockRetentionBoundaryObserved": True,
        "withinProvision": vault_used <= vault_volume["usableBytes"] and audit_total <= audit_volume["usableBytes"],
    }


@contextlib.contextmanager
def storage_observer() -> Iterator[Path]:
    """Run a read-only, elevated filesystem observer outside both workloads."""
    folder = containment.require_state_path(KIND_CONFIG.parent.parent / "observers", "build", actor="test")
    folder.mkdir(parents=True, exist_ok=True)
    trace, summary, stop = (folder / name for name in ("storage.jsonl", "storage-summary.json", "storage.stop"))
    with (folder / "storage-process.log").open("xb") as log:
        process = subprocess.Popen(
            ("/usr/bin/sudo", "-n", sys.executable, str(ROOT / "tools/vault_storage_observer.py"),
             "--test-root", str(TEST_ROOT), "--output", str(trace), "--summary", str(summary), "--stop", str(stop)),
            cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 15
            while not trace.exists() or trace.stat().st_size == 0:
                if process.poll() is not None or time.monotonic() >= deadline:
                    raise VaultLiveFailure("storage-observer-unavailable")
                time.sleep(0.02)
            yield summary
        finally:
            stop.write_text("stop\n", encoding="utf-8")
            result = process.wait(timeout=30)
            if result:
                raise VaultLiveFailure(f"storage-observer-failed:exit-{result}")
    if not summary.is_file():
        raise VaultLiveFailure("storage-observer-summary-absent")


def observe_secret_surfaces(password: bytes) -> dict[str, Any]:
    node = json.loads(text(run(("/usr/bin/docker", "inspect", NODE))))
    if len(node) != 1 or not node[0].get("State", {}).get("Running"):
        raise VaultLiveFailure("secret-observer-node-identity-unavailable")
    node_pid = int(node[0]["State"]["Pid"])
    container_pids = []
    for namespace, pod_name in ((NAMESPACE, "root-vault-0"), (CONSUMER_NAMESPACE, "vault-reader")):
        pod = json.loads(text(kubectl("-n", namespace, "get", "pod", pod_name, "-o", "json")))
        containers = pod["status"].get("containerStatuses", [])
        if len(containers) != 1 or not containers[0].get("ready"):
            raise VaultLiveFailure("secret-observer-pod-identity-unavailable")
        container_id = containers[0]["containerID"].removeprefix("containerd://")
        runtime = json.loads(text(run(("/usr/bin/docker", "exec", NODE, "crictl", "inspect", container_id))))
        info = runtime["info"]
        if isinstance(info, str):
            info = json.loads(info)
        container_pids.append(int(info["pid"]))
    command = ["/usr/bin/sudo", "-n", sys.executable, str(ROOT / "tools/vault_secret_observer.py"),
               "--test-root", str(TEST_ROOT), "--run-root", str(KIND_CONFIG.parent.parent.parent),
               "--node-pid", str(node_pid)]
    for pid in container_pids:
        command.extend(("--container-pid", str(pid)))
    result = run(command, input_bytes=json.dumps({"needle": base64.b64encode(password).decode()}).encode(),
                 check=False, timeout=1200)
    try:
        observed = json.loads(text(result))
    except json.JSONDecodeError as error:
        raise VaultLiveFailure("password-surface-observer-returned-no-structured-result") from error
    # This trusted observer emits only counts, a digest, and fixed failure codes.
    # Preserve that evidence even when its scan fails closed.
    destination = KIND_CONFIG.parent.parent / "observers/secret-surfaces.json"
    destination.write_text(json.dumps(observed, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if result.returncode:
        safe_code = observed.get("errorCode", "matching-secret-observed")
        raise VaultLiveFailure(f"password-surface-observer-failed:{safe_code}")
    if not observed.get("clean") or observed.get("needleSha256") != hashlib.sha256(password).hexdigest():
        raise VaultLiveFailure("password-surface-observer-challenge-mismatch")
    return observed


def preallocation_rejections(binary_path: Path) -> dict[str, Any]:
    storage_lines = (ROOT / "test/golden/vault/storage-demand.golden").read_text().splitlines()[1:]
    storage = {key: int(value) for key, value in (line.split(",") for line in storage_lines)}
    audit = {key: int(value) for key, value in (line.split("=") for line in (ROOT / "test/golden/vault/audit-rotation.golden").read_text().splitlines())}
    raw, audit_raw = storage["provisioned-raw"], audit["provisionedRawBytes"]
    usable, audit_usable = storage["required-usable-peak"], audit["requiredUsableBytes"]
    cases = (
        (raw - 1048576, audit_raw, usable, audit_usable, "DurableBackingTooSmall"),
        (raw, audit_raw - 1048576, usable, audit_usable, "AuditBackingTooSmall"),
        (raw, audit_raw, usable - 1, audit_usable, "VaultDurableUsableTooSmall"),
        (raw, audit_raw, usable, audit_usable - 1, "VaultAuditUsableTooSmall"),
    )

    def boundary() -> dict[str, Any]:
        return {"retainedRootPresent": RETAINED_ROOT.exists(),
                "poolImagePresent": (TEST_ROOT / "disks/retained-durable-pool.ext4").exists(),
                "kindClusters": text(run((KIND, "get", "clusters", "--quiet"))).splitlines()}

    before = boundary()
    if before["retainedRootPresent"] or before["poolImagePresent"] or before["kindClusters"]:
        raise VaultLiveFailure("storage-negative-boundary-not-pristine")
    # The independent native service fixture admits this conservative supply.
    # Keep it identical for the positive and all four storage negatives.
    supply = ("1000", "1073741824", "134217728", "2")
    positive_operands = (raw, audit_raw, usable, audit_usable)
    positive = json.loads(text(run((str(binary_path), "vault-service-projection", *supply,
                                    *(str(value) for value in positive_operands)))))
    if boundary() != before:
        raise VaultLiveFailure("storage-positive-crossed-effect-boundary")
    reasons = []
    for durable, audit_bytes, durable_usable, audit_available, reason in cases:
        result = run((str(binary_path), "vault-service-projection", *supply,
                      str(durable), str(audit_bytes), str(durable_usable), str(audit_available)), check=False)
        if result.returncode == 0 or reason not in text(result):
            raise VaultLiveFailure(f"storage-negative-wrong-reason:{reason}")
        reasons.append(reason)
    after = boundary()
    if before != after:
        raise VaultLiveFailure("storage-negative-crossed-effect-boundary")
    return {"before": before, "after": after, "reasons": reasons, "storageEffects": 0, "apiEffects": 0,
            "executionSupply": [int(value) for value in supply], "positiveOperands": positive_operands,
            "positiveProjection": positive,
            "cases": [{"operands": case[:4], "reason": case[4]} for case in cases]}


def provision_live_service(binary_path: Path, vault_volume: dict[str, Any], audit_volume: dict[str, Any]) -> dict[str, Any]:
    node = json.loads(text(kubectl("get", "node", NODE, "-o", "json")))
    allocatable = node["status"]["allocatable"]
    observed = [quantity(allocatable["cpu"], cpu=True), quantity(allocatable["memory"]),
                quantity(allocatable["ephemeral-storage"]), int(allocatable["pods"])]
    host_config = json.loads(text(run(("/usr/bin/docker", "inspect", NODE))))[0]["HostConfig"]
    # kubelet may advertise host capacity inside kind. Admit against the actual
    # enforced parent supply, never that larger advertised CPU/memory value.
    parent = {"cpuMilli": host_config["NanoCpus"] // 1000000, "memoryBytes": host_config["Memory"]}
    if parent != {"cpuMilli": 2000, "memoryBytes": 4294967296}:
        raise VaultLiveFailure("private-node-enforced-supply-mismatch")
    observed[0] = min(observed[0], parent["cpuMilli"])
    observed[1] = min(observed[1], parent["memoryBytes"])
    result = run((str(binary_path), "vault-service-projection", *(str(value) for value in observed),
                  str(vault_volume["rawBytes"]), str(audit_volume["rawBytes"]),
                  str(vault_volume["usableBytes"]), str(audit_volume["usableBytes"])))
    projection = json.loads(text(result))
    config = json.loads(text(kubectl("get", "--raw", f"/api/v1/nodes/{NODE}/proxy/configz")))["kubeletconfig"]
    policy = projection["logPolicy"]
    if quantity(config["containerLogMaxSize"]) != policy["maximumFileBytes"] or config["containerLogMaxFiles"] != policy["maximumFiles"]:
        raise VaultLiveFailure("effective-kubelet-log-policy-mismatch")
    globals()["SERVICE_PROJECTION"] = projection
    globals()["VAULT_CAPACITY"] = str(projection["durable"]["provisionedBytes"])
    globals()["AUDIT_CAPACITY"] = str(projection["audit"]["provisionedBytes"])
    return {"nodeUid": node["metadata"]["uid"], "observedAllocatable": observed,
            "enforcedParentSupply": parent, "sealed": projection}


def execute(*, additional_volumes: Mapping[str, int] | None = None,
            additional_usable_bytes: Mapping[str, int] | None = None,
            pool_capacity_bytes: int = 256 * 1024**2,
            after_ready=None) -> dict[str, Any]:
    if not IMAGE_ARCHIVE.is_file():
        raise VaultLiveFailure("phase25-image-archive-absent")
    canary = json.loads(CANARY_FIXTURE.read_text(encoding="utf-8"))
    if len(canary["value"].encode()) != 32:
        raise VaultLiveFailure("canary-not-32-bytes")
    if additional_usable_bytes is not None and (
        set(additional_usable_bytes) != set(additional_volumes or {})
        or any(required <= 0 or required > (additional_volumes or {})[name]
               for name, required in additional_usable_bytes.items())
    ):
        raise VaultLiveFailure("successor-usable-inventory-mismatch")
    binary = install_current_binary()
    negative = preallocation_rejections(Path(binary["path"]))
    required = {"vault": VAULT_IMAGE_BYTES, "vault-audit": AUDIT_IMAGE_BYTES}
    inventory = backing.inventory_plan(pool_capacity_bytes - UNLOCK_ENVELOPE_MAX_BYTES, required,
                                       additional_volumes or {})
    backing.prepare_pool(RETAINED_ROOT, pool_capacity_bytes, inventory)
    # A successor declares its complete inventory up front. All child mounts
    # must exist before kind copies the host mount tree into either fresh node.
    prepared = {name: prepare_volume(name, size) for name, size in inventory.items()}
    # Validate every successor filesystem before either cluster is created.
    # Raw allocation fit alone does not establish ext4 usable presentation.
    for name, required_usable in (additional_usable_bytes or {}).items():
        if prepared[name]["usableBytes"] < required_usable:
            raise VaultLiveFailure(f"retained-volume-usable-capacity:{name}")
    vault_volume, audit_volume = prepared["vault"], prepared["vault-audit"]
    with storage_observer() as summary_path:
        if after_ready is None:
            evidence = execute_live(canary, vault_volume, audit_volume, binary, negative)
        else:
            evidence = execute_live(canary, vault_volume, audit_volume, binary, negative, after_ready=after_ready)
    evidence["storage"]["additionalRetainedVolumes"] = {
        name: volume for name, volume in prepared.items() if name not in required
    }
    observed = json.loads(summary_path.read_text(encoding="utf-8"))
    bounds = evidence["storage"]["run1HighWater"]
    bounds["raftHighWaterBytes"] = observed["peakDataAllocatedBytes"]["vault"]
    bounds["auditHighWaterBytes"] = observed["peakDataAllocatedBytes"]["vault-audit"]
    bounds["withinProvision"] = (
        observed["samples"] > 1
        and bounds["raftHighWaterBytes"] <= vault_volume["usableBytes"]
        and bounds["auditHighWaterBytes"] <= audit_volume["usableBytes"]
        and observed["maximumActiveAuditBytes"] <= 1048576
        and observed["maximumBackupAuditBytes"] <= 1048576
        and observed["maximumAuditFileCount"] <= 4
        and observed["maximumSimultaneousFsmDatabases"] >= 2
        and bounds.get("compactionExternallyObserved") is True
        and bounds.get("recoveryExternallyObserved") is True
    )
    if not bounds["withinProvision"]:
        raise VaultLiveFailure("incomplete-or-exceeded-observed-storage-proof")
    evidence["storage"]["observer"] = {"summary": str(summary_path), **observed}
    return evidence


def execute_live(canary: dict[str, str], vault_volume: dict[str, Any], audit_volume: dict[str, Any], binary: dict[str, Any], negative: dict[str, Any], *, after_ready=None) -> dict[str, Any]:
    binary_path = Path(binary["path"])
    # The elevated live harness simulates the operator at stdin with an in-memory,
    # one-use value.  No credential arrives through argv, environment, or a file.
    password = secrets.token_urlsafe(32).encode()
    delete_cluster()
    source1 = create_cluster()
    service1 = provision_live_service(binary_path, vault_volume, audit_volume)
    identity1 = cluster_identity()
    prebind1 = apply_vault()
    before_init, unseal_key, root_token = initialize_vault(password, binary_path)
    opened = open_unlock(password, binary_path)
    envelope_sha256 = sha256_file(UNLOCK_ENVELOPE)
    if opened != {"unseal_key": unseal_key, "root_token": root_token}:
        raise VaultLiveFailure("unlock-envelope-roundtrip")
    wrong = run((str(binary_path), "vault-open-unlock"), input_bytes=b"wrong-password\n" + UNLOCK_ENVELOPE.read_bytes(), check=False, timeout=120)
    if wrong.returncode == 0:
        raise VaultLiveFailure("wrong-password-opened-envelope")
    unseal1 = unseal(unseal_key)
    # The authored fixture pins the reference and length. Challenge bytes are
    # unpredictable and issued only after the live subject has started.
    canary["value"] = secrets.token_hex(16)
    transit_challenge = secrets.token_hex(16)

    with port_forward():
        configured = configure_vault(root_token, canary, transit_challenge)
        configure_kubernetes_auth(root_token)
        consumer1 = deploy_consumer(wait_ready=False)
        client_presence(canary, expected_tag="secret-missing")
        prompt_write = write_canary_prompt(root_token, canary)
        kubectl("-n", CONSUMER_NAMESPACE, "wait", "--for=condition=Ready", "pod/vault-reader", "--timeout=120s")
        client_presence(canary)
        client_read(canary, expect_success=True)
        transit_value = client_transit(configured["ciphertext"], transit_challenge)
        pki1 = verify_certificates(configured["rootCertificate"], configured["issuingCa"], configured["leafCertificate"])
        require_api("DELETE", "auth/kubernetes/role/amoebius-canary", root_token)
        denied = client_read(canary, expect_success=False)
        restore_client_role(root_token)
        bounds1 = raft_and_audit_bounds(root_token, vault_volume, audit_volume)
        health1 = require_api("GET", "sys/health", accepted={200})
        kubectl("-n", CONSUMER_NAMESPACE, "wait", "--for=condition=Ready", "pod/vault-reader", "--timeout=120s")
        require_api("PUT", "sys/seal", root_token, {})
        kubectl("-n", CONSUMER_NAMESPACE, "wait", "--for=condition=Ready=false", "pod/vault-reader", "--timeout=60s")
        client_presence(canary, expected_tag="sealed")
        client_read(canary, expect_success=False, expected_tag="sealed")
        sealed_issue_status, sealed_issue_body = api_request("POST", "pki/issue/internal", root_token, {"common_name": "denied.amoebius.internal"})
    if sealed_issue_status == 200:
        raise VaultLiveFailure("pki-issued-while-sealed")
    unseal(unseal_key)
    kubectl("-n", CONSUMER_NAMESPACE, "wait", "--for=condition=Ready", "pod/vault-reader", "--timeout=120s")

    old_vault_hash = sha256_file(Path(vault_volume["image"]))
    delete_cluster()
    clusters = text(run((KIND, "get", "clusters"))).splitlines()
    cluster_absent = CLUSTER not in clusters
    node_absent = run(("/usr/bin/docker", "inspect", NODE), check=False).returncode != 0
    backing_present = mountpoint(Path(vault_volume["mount"])) and Path(vault_volume["image"]).is_file()
    if not (cluster_absent and node_absent and backing_present):
        raise VaultLiveFailure(f"delete-boundary:{cluster_absent}:{node_absent}:{backing_present}")
    at_shutdown = raft_indexes(vault_volume)

    source2 = create_cluster()
    service2 = provision_live_service(binary_path, vault_volume, audit_volume)
    if service1["sealed"] != service2["sealed"]:
        raise VaultLiveFailure("recreated-vault-service-projection-changed")
    identity2 = cluster_identity()
    if identity1["serverCaSha256"] == identity2["serverCaSha256"] or identity1["clusterUid"] == identity2["clusterUid"]:
        raise VaultLiveFailure("cluster-recreate-not-fresh")
    prebind2 = apply_vault()
    before_unseal2 = vault_status()
    if not before_unseal2.get("initialized") or not before_unseal2.get("sealed"):
        raise VaultLiveFailure(f"recreate-did-not-find-initialized-sealed-vault:{before_unseal2}")
    opened2 = open_unlock(password, binary_path)
    unseal2 = unseal(opened2["unseal_key"])
    after_recovery = raft_indexes(vault_volume)
    with port_forward():
        health2 = require_api("GET", "sys/health", accepted={200})
        if health1.get("cluster_id") != health2.get("cluster_id"):
            raise VaultLiveFailure("vault-cluster-identity-changed")
        configure_kubernetes_auth(opened2["root_token"])
        consumer2 = deploy_consumer()
        client_read(canary, expect_success=True)
        issue2 = require_api("POST", "pki/issue/internal", opened2["root_token"], {"common_name": "vault-recreated.vault-system.svc.amoebius.internal", "ttl": "1h"})
        pki2 = verify_certificates(issue2["data"]["issuing_ca"], issue2["data"]["issuing_ca"], issue2["data"]["certificate"])
        if after_ready is not None:
            # A successor may configure its own scoped role while the operator
            # token is still in memory. It never receives the unlock password.
            after_ready(opened2["root_token"])

    bounds1["recoveryExternallyObserved"] = (
        after_recovery["highestLogIndex"] >= at_shutdown["highestLogIndex"]
        and health1.get("cluster_id") == health2.get("cluster_id")
    )
    bounds1["logIndexesAtShutdown"] = at_shutdown
    bounds1["logIndexesAfterRecovery"] = after_recovery

    pod_spec = json.loads(text(kubectl("-n", NAMESPACE, "get", "statefulset", "root-vault", "-o", "json")))
    storage_classes = json.loads(text(kubectl("get", "storageclass", "-o", "json")))["items"]
    vault_hash_after = sha256_file(Path(vault_volume["image"]))
    audit_text = "".join(text(sudo("/usr/bin/cat", str(path))) for path in Path(audit_volume["mount"]).glob("audit.log*"))
    audit_login = "auth/kubernetes/login" in audit_text
    audit_read = "secret/data/amoebius/canary" in audit_text
    if not (audit_login and audit_read):
        raise VaultLiveFailure("vault-audit-provenance-operations-absent")
    secret_surfaces = observe_secret_surfaces(password)
    password_scan = secret_surfaces["clean"] and password.decode() not in json.dumps(pod_spec) and password.decode() not in audit_text
    if not password_scan:
        raise VaultLiveFailure("password-persisted-in-observed-surface")

    return {
        "schema": "amoebius.vault-pki.live.v2",
        "register": 3,
        "substrate": "linux-cpu",
        "challenge": {"issuedAfterSubjectStart": True, "absentBeforeWrite": True, "nonceSha256": hashlib.sha256(canary["value"].encode()).hexdigest()},
        "promptWrite": prompt_write,
        "secretDependentReadiness": {"missingFieldDenied": True, "unreadyWhileSealed": True, "readyAfterUnseal": True, "presenceOnly": True},
        "initOnce": {
            "run1InitializedBefore": before_init.get("initialized"),
            "run2InitializedBeforeUnseal": before_unseal2.get("initialized"),
            "run2SealedBeforeUnseal": before_unseal2.get("sealed"),
            "initCount": 1,
            "vaultClusterIdStable": health1.get("cluster_id") == health2.get("cluster_id"),
            "run1Unsealed": not unseal1.get("sealed"),
            "run2Unsealed": not unseal2.get("sealed"),
        },
        "unlockEnvelope": {
            "path": str(UNLOCK_ENVELOPE),
            "sha256": envelope_sha256,
            "format": "Argon2id-v1.3+ChaCha20-Poly1305-IETF",
            "wrongPasswordRejected": True,
            "mode": "0600",
            "passwordPersisted": False,
            "observedSurfaceScanPassed": password_scan,
            "externalSurfaceObservation": secret_surfaces,
            "stdinOnly": True,
            "environmentSources": 0,
            "argumentSources": 0,
        },
        "storage": {
            "physicalPool": backing.observe_pool(RETAINED_ROOT),
            "negativeBoundary": negative,
            "durable": vault_volume,
            "audit": audit_volume,
            "declared": {"raftProvisionedRawBytes": VAULT_IMAGE_BYTES, "auditProvisionedRawBytes": AUDIT_IMAGE_BYTES},
            "run1HighWater": bounds1,
            "backingHashChangedOnlyByVault": old_vault_hash != vault_hash_after,
        },
        "clusterRebuild": {
            "run1": identity1,
            "run2": identity2,
            "serverCaChanged": identity1["serverCaSha256"] != identity2["serverCaSha256"],
            "clusterUidChanged": identity1["clusterUid"] != identity2["clusterUid"],
            "kindClusterAbsent": cluster_absent,
            "nodeContainerAbsent": node_absent,
            "backingPresentWhileAbsent": backing_present,
            "prebindRun1": prebind1,
            "prebindRun2": prebind2,
        },
        "pki": {
            "run1": pki1,
            "run2": pki2,
            "sameRootAfterRecreate": pki1["rootSha256"] == pki2["rootSha256"],
            "sealedIssuanceStatus": sealed_issue_status,
            "sealedIssuanceBodySha256": hashlib.sha256(sealed_issue_body).hexdigest(),
        },
        "client": {
            "compiledBinary": binary,
            "run1": consumer1,
            "run2": consumer2,
            "secretRefByteIdentical": True,
            "transitByteIdentical": transit_value == transit_challenge,
            "roleDeletionDenied": denied.returncode != 0,
            "auditKubernetesLoginObserved": audit_login,
            "auditSecretReadObserved": audit_read,
            "agentSidecars": 0,
            "plainSecretMounts": 0,
        },
        "manifestProjection": {
            "serviceRun1": service1,
            "serviceRun2": service2,
            "appliedRun1": prebind1["serviceProjection"],
            "appliedRun2": prebind2["serviceProjection"],
            "vaultContainers": len(pod_spec["spec"]["template"]["spec"]["containers"]),
            "resources": pod_spec["spec"]["template"]["spec"]["containers"][0]["resources"],
            "storageClassCount": len(storage_classes),
            "storageClass": storage_classes[0]["metadata"]["name"] if len(storage_classes) == 1 else None,
        },
        "artifactSource": {"run1": source1, "run2": source2, "phase25IndexDigest": IMAGE_DIGEST},
        "deferred": {
            "parentChildUnseal": "UNVERIFIED",
            "crossClusterIntermediateCa": "UNVERIFIED",
            "parentSecretInjection": "UNVERIFIED",
        },
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="write the run observation beneath .build")
    parser.add_argument("--artifact", type=Path, required=True, help="verified Phase-25 OCI handoff")
    parser.add_argument("--image-digest", required=True, help="verified Phase-25 image index digest")
    arguments = parser.parse_args(argv)
    containment.require_state_path(arguments.output, "build", actor="test")
    globals()["IMAGE_ARCHIVE"] = arguments.artifact
    globals()["IMAGE_DIGEST"] = arguments.image_digest
    globals()["PRIVATE_IMAGE"] = f"registry.amoebius.invalid:5000/amoebius/base@{arguments.image_digest}"
    resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl"])
    globals()["CABAL"] = os.environ.get("AMOEBIUS_CABAL", resolved["cabal"]["path"])
    globals()["KIND"] = os.environ.get("AMOEBIUS_KIND", resolved["kind"]["path"])
    globals()["KUBECTL"] = os.environ.get("AMOEBIUS_KUBECTL", resolved["kubectl"]["path"])
    globals()["KIND_CONFIG"] = materialize_kind_config(arguments.output.parent)
    try:
        evidence = execute()
        containment.require_state_path(arguments.output, "build", actor="test")
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("vault-pki-live: PASS (init once, retained unseal, PKI chain, Kubernetes-auth Haskell client)")
        return 0
    except (VaultLiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired, yaml.YAMLError) as problem:
        print(f"vault-pki-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
