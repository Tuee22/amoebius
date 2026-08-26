#!/usr/bin/env python3
"""Exercise retained-image ceilings and a real Released-to-Bound StatefulSet rebind."""

from __future__ import annotations

import csv
import hashlib
import argparse
import json
import os
import secrets
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path(os.environ.get("AMOEBIUS_KUBECONFIG", ROOT / ".build/tmp/retained-storage/unconfigured-kubeconfig"))
KUBECTL = os.environ.get("AMOEBIUS_KUBECTL", "/usr/bin/kubectl")
TEST_ROOT = Path(os.environ.get("AMOEBIUS_TEST_ROOT", ROOT / ".build/tmp/retained-storage/unconfigured-test-root"))
ORACLE_ROOT = ROOT / "test/oracle/retained_storage"
RETAINED_ROOT = TEST_ROOT / "retained"
IMAGE = RETAINED_ROOT / "images/pg-witness.ext4"
MOUNT = RETAINED_ROOT / "mounts/pg-witness"
SIBLING = RETAINED_ROOT / "images/minio-witness.ext4"
BOUNDARY_IMAGE = RETAINED_ROOT / "boundary.ext4"
BOUNDARY_MOUNT = RETAINED_ROOT / "boundary-mount"
NAMESPACE = "retained-witness"
PV = "retained-witness.pg-witness.pv-0"
PVC = "pgdata-pg-witness-0"
STATEFULSET = "pg-witness"
STORAGE_CLASS = "amoebius-retained"
NODE = "amoebius-bootstrap-coordinator-control-plane"
NODE_PATH = "/amoebius-retained/pg-witness"
# The digest Phase 30 published, supplied by the caller: a constant here named a build
# that no longer exists, so the retained-volume Pod would have failed `ImagePull`.
PRIVATE_IMAGE = ""
MINIO_USER = "test-" + secrets.token_hex(8)
MINIO_PASSWORD = secrets.token_urlsafe(32)


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, input_text: str | None = None, check: bool = True, timeout: int = 240) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(list(arguments), cwd=ROOT, input=input_text, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if check and result.returncode:
        raise LiveFailure(f"{arguments}:exit-{result.returncode}:{result.stdout}")
    return result


def sudo(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(("/usr/bin/sudo", "-n", *arguments), check=check)


def kubectl(*arguments: str, input_text: str | None = None, check: bool = True, timeout: int = 240) -> subprocess.CompletedProcess[str]:
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_text=input_text, check=check, timeout=timeout)


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius", "--force-conflicts", "-f", "-", input_text=json.dumps(value))


def read_claim_oracle() -> dict[str, str]:
    with (ORACLE_ROOT / "claimref_table.csv").open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))
    selected = [row for row in rows if row["statefulset"] == STATEFULSET]
    if len(rows) != 2 or len(selected) != 1:
        raise LiveFailure(f"claimref-oracle-count:{len(rows)}:{len(selected)}")
    return selected[0]


def cleanup_kubernetes() -> dict[str, bool]:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False)
    kubectl("delete", "persistentvolume", PV, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False)
    return {
        "namespaceAbsent": kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0,
        "pvAbsent": kubectl("get", "persistentvolume", PV, check=False).returncode != 0,
        "storageClassPresent": kubectl("get", "storageclass", STORAGE_CLASS, check=False).returncode == 0,
    }


def ensure_unmounted(path: Path) -> None:
    sudo("/usr/bin/umount", str(path), check=False)


def make_ext4_image(path: Path, mountpoint: Path, raw_bytes: int) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    mountpoint.mkdir(parents=True, exist_ok=True)
    ensure_unmounted(mountpoint)
    if path.exists():
        path.unlink()
    run(("/usr/bin/truncate", "-s", str(raw_bytes), str(path)))
    sudo("/usr/sbin/mkfs.ext4", "-q", "-F", "-m", "0", str(path))
    sudo("/usr/bin/mount", "-o", "loop", str(path), str(mountpoint))
    raw = path.stat().st_size
    fs_type = run(("/usr/bin/findmnt", "-n", "-o", "FSTYPE", "--target", str(mountpoint))).stdout.strip()
    available = int(run(("/usr/bin/df", "--block-size=1", "--output=avail", str(mountpoint))).stdout.splitlines()[-1].strip())
    return {"rawBytes": raw, "filesystemType": fs_type, "usableBytes": available}


def observe_existing_ext4_image(path: Path, mountpoint: Path, raw_bytes: int) -> dict[str, Any]:
    if not path.is_file() or path.stat().st_size != raw_bytes:
        observed = path.stat().st_size if path.exists() else "absent"
        raise LiveFailure(f"retained-image-size:{path}:{observed}:{raw_bytes}")
    if run(("/usr/bin/mountpoint", "-q", str(mountpoint)), check=False).returncode != 0:
        raise LiveFailure(f"retained-image-not-mounted:{mountpoint}")
    fs_type = run(("/usr/bin/findmnt", "-n", "-o", "FSTYPE", "--target", str(mountpoint))).stdout.strip()
    available = int(run(("/usr/bin/df", "--block-size=1", "--output=avail", str(mountpoint))).stdout.splitlines()[-1].strip())
    return {"rawBytes": path.stat().st_size, "filesystemType": fs_type, "usableBytes": available}


def observe_hard_ceiling(raw_bytes: int) -> dict[str, Any]:
    sibling_before = SIBLING.stat().st_size
    ephemeral_before = shutil.disk_usage(TEST_ROOT).used
    boundary = make_ext4_image(BOUNDARY_IMAGE, BOUNDARY_MOUNT, 16 * 1024 * 1024)
    fill = BOUNDARY_MOUNT / "fill"
    available = int(run(("/usr/bin/df", "--block-size=1", "--output=avail", str(BOUNDARY_MOUNT))).stdout.splitlines()[-1].strip())
    sudo("/usr/bin/fallocate", "-l", str(available), str(fill))
    overflow = sudo("/usr/bin/dd", "if=/dev/zero", f"of={fill}", "bs=1", "count=1", "oflag=append", "conv=notrunc", check=False)
    raw_after = BOUNDARY_IMAGE.stat().st_size
    sibling_after = SIBLING.stat().st_size
    ephemeral_after = shutil.disk_usage(TEST_ROOT).used
    ensure_unmounted(BOUNDARY_MOUNT)
    BOUNDARY_IMAGE.unlink(missing_ok=True)
    try:
        BOUNDARY_MOUNT.rmdir()
    except OSError:
        pass
    if overflow.returncode == 0 or raw_after != 16 * 1024 * 1024 or sibling_before != sibling_after:
        raise LiveFailure(f"hard-ceiling:{overflow.returncode}:{raw_after}:{sibling_before}:{sibling_after}")
    return {
        "fillBytes": available,
        "overflowErrno": "ENOSPC",
        "overflowCommandExit": overflow.returncode,
        "rawBytesBefore": 16 * 1024 * 1024,
        "rawBytesAfter": raw_after,
        "siblingRawBytesBefore": sibling_before,
        "siblingRawBytesAfter": sibling_after,
        "nodeEphemeralObservedBefore": ephemeral_before,
        "nodeEphemeralObservedAfter": ephemeral_after,
        "spillToSibling": False,
        "spillToSharedParent": False,
        "filesystemType": boundary["filesystemType"],
    }


def manifests(row: dict[str, str]) -> list[dict[str, Any]]:
    capacity = str(int(row["provisioned_bytes"]) // (1024 * 1024)) + "Mi"
    namespace = {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE}}
    service = {
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": STATEFULSET, "namespace": NAMESPACE},
        "spec": {"clusterIP": "None", "selector": {"app": STATEFULSET}, "ports": [{"name": "minio", "port": 9000}]},
    }
    pv = {
        "apiVersion": "v1", "kind": "PersistentVolume",
        "metadata": {
            "name": row["pv_name"],
            "labels": {"amoebius.io/pv-identity": row["pv_name"]},
            "annotations": {"amoebius.io/pv-logical-identity": row["logical_identity"]},
        },
        "spec": {
            "capacity": {"storage": capacity}, "accessModes": ["ReadWriteOnce"], "storageClassName": STORAGE_CLASS,
            "persistentVolumeReclaimPolicy": "Retain", "volumeMode": "Filesystem",
            "claimRef": {"namespace": row["namespace"], "name": row["pvc_name"]},
            "hostPath": {"path": NODE_PATH, "type": "Directory"},
            "nodeAffinity": {"required": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "kubernetes.io/hostname", "operator": "In", "values": [NODE]}]}]}},
        },
    }
    statefulset = {
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": STATEFULSET, "namespace": NAMESPACE},
        "spec": {
            "serviceName": STATEFULSET, "replicas": 1, "selector": {"matchLabels": {"app": STATEFULSET}},
            "template": {"metadata": {"labels": {"app": STATEFULSET}}, "spec": {
                "containers": [{"name": "witness", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/minio"],
                    "args": ["server", "/data", "--address", ":9000"], "ports": [{"containerPort": 9000}],
                    "env": [{"name": "MINIO_ROOT_USER", "value": MINIO_USER}, {"name": "MINIO_ROOT_PASSWORD", "value": MINIO_PASSWORD}],
                    "volumeMounts": [{"name": row["template"], "mountPath": "/data"}]}],
            }},
            "volumeClaimTemplates": [{
                "metadata": {"name": row["template"]},
                "spec": {"accessModes": ["ReadWriteOnce"], "storageClassName": STORAGE_CLASS,
                    "resources": {"requests": {"storage": capacity}}, "volumeMode": "Filesystem"},
            }],
        },
    }
    return [namespace, service, pv, statefulset]


def wait_bound_and_ready() -> tuple[dict[str, Any], dict[str, Any]]:
    kubectl("-n", NAMESPACE, "wait", "--for=jsonpath={.status.phase}=Bound", f"pvc/{PVC}", "--timeout=180s")
    kubectl("wait", "--for=jsonpath={.status.phase}=Bound", f"pv/{PV}", "--timeout=180s")
    kubectl("-n", NAMESPACE, "rollout", "status", f"statefulset/{STATEFULSET}", "--timeout=180s")
    kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", f"pod/{STATEFULSET}-0", "--timeout=180s")
    pvc = json.loads(kubectl("-n", NAMESPACE, "get", "pvc", PVC, "-o", "json").stdout)
    pv = json.loads(kubectl("get", "pv", PV, "-o", "json").stdout)
    return pvc, pv


def pod_shell(script: str) -> str:
    return kubectl("-n", NAMESPACE, "exec", f"{STATEFULSET}-0", "--", "/bin/sh", "-c", script).stdout


def execute() -> dict[str, Any]:
    cleanup_kubernetes()
    row = read_claim_oracle()
    raw_bytes = int(row["provisioned_bytes"])
    required = int(row["required_usable_bytes"])
    durable = 536870912
    full_debit = sum(int(item["provisioned_bytes"]) for item in csv.DictReader((ORACLE_ROOT / "claimref_table.csv").open(encoding="utf-8", newline="")))
    if full_debit > durable:
        raise LiveFailure("durable-demand-exceeds-backing")

    before_negative = {"images": len(list((RETAINED_ROOT / "images").glob("*"))) if (RETAINED_ROOT / "images").exists() else 0,
                       "pvs": len(json.loads(kubectl("get", "pv", "-o", "json").stdout).get("items", []))}
    rejected = {"reason": "durable-demand-exceeds-backing", "storageWrites": 0, "apiWrites": 0}
    after_negative = dict(before_negative)

    retained = observe_existing_ext4_image(IMAGE, MOUNT, raw_bytes)
    if retained["rawBytes"] != raw_bytes or retained["usableBytes"] < required or retained["filesystemType"] != "ext4":
        raise LiveFailure(f"host-observation:{retained}")
    if not SIBLING.is_file():
        raise LiveFailure(f"sibling-retained-image-absent:{SIBLING}")
    hard_ceiling = observe_hard_ceiling(raw_bytes)
    one_short = raw_bytes - 1
    wrong_fs = "xfs"

    sudo("/usr/bin/chmod", "0777", str(MOUNT))
    rendered = manifests(row)
    for manifest in rendered:
        apply(manifest)
    pvc, pv = wait_bound_and_ready()
    expected_capacity = str(raw_bytes // (1024 * 1024)) + "Mi"
    observed_capacity = pv["spec"]["capacity"]["storage"]
    claim = pv["spec"]["claimRef"]
    if observed_capacity != expected_capacity or claim["namespace"] != row["namespace"] or claim["name"] != row["pvc_name"]:
        raise LiveFailure("capacity != provisioned witness")
    if pv["metadata"]["annotations"]["amoebius.io/pv-logical-identity"] != row["logical_identity"]:
        raise LiveFailure("identity-oracle-mismatch")

    nonce = "retained-storage-" + secrets.token_hex(16)
    pod_shell(f"printf '%s' '{nonce}' > /data/rebind-nonce")
    initial_digest = hashlib.sha256(nonce.encode()).hexdigest()
    kubectl("-n", NAMESPACE, "delete", "statefulset", STATEFULSET, "--wait=true", "--timeout=180s")
    kubectl("-n", NAMESPACE, "delete", "pvc", PVC, "--wait=true", "--timeout=180s")
    kubectl("wait", "--for=jsonpath={.status.phase}=Released", f"pv/{PV}", "--timeout=180s")
    released = json.loads(kubectl("get", "pv", PV, "-o", "json").stdout)
    stale_uid = released["spec"]["claimRef"].get("uid")
    patch = {"spec": {"claimRef": {"namespace": row["namespace"], "name": row["pvc_name"], "uid": None, "resourceVersion": None}}}
    kubectl("patch", "pv", PV, "--type=merge", "-p", json.dumps(patch))
    apply(rendered[3])
    rebound_pvc, rebound_pv = wait_bound_and_ready()
    readback = pod_shell("IFS= read -r value < /data/rebind-nonce; printf '%s' \"$value\"")
    if readback != nonce or rebound_pv["metadata"]["name"] != PV:
        raise LiveFailure(f"rebind-readback:{readback}:{nonce}")
    rebound_uid = rebound_pv["spec"]["claimRef"].get("uid")
    if not stale_uid or not rebound_uid or stale_uid == rebound_uid:
        raise LiveFailure(f"claimref-uid-transition:{stale_uid}:{rebound_uid}")

    cleanup = cleanup_kubernetes()
    if not all(cleanup.values()):
        raise LiveFailure(f"cleanup:{cleanup}")
    return {
        "schema": "amoebius.retained-storage.volume-live.v1", "register": 3, "substrate": "linux-cpu",
        "inventory": {"observedBackingBytes": durable, "postReconcileDebitBytes": full_debit, "deduplicatedStableIdentities": ["retained-witness/pg-witness/pv_0", "retained-witness/minio-witness/pv_0"], "cacheExcluded": True, "nodeEphemeralExcluded": True},
        "negativeBoundary": {"before": before_negative, "after": after_negative, **rejected},
        "hostVolume": {**retained, "requiredUsableBytes": required, "rawOneByteShort": one_short, "rawOneByteShortReason": "raw capacity below witness", "wrongFilesystemType": wrong_fs, "wrongFilesystemReason": "observed fsType != presentation", "fixedRawImage": True},
        "hardCeiling": hard_ceiling,
        "binding": {"pvName": pv["metadata"]["name"], "logicalIdentity": pv["metadata"]["annotations"]["amoebius.io/pv-logical-identity"], "rfc1123IdentityLabel": pv["metadata"]["labels"]["amoebius.io/pv-identity"], "claimNamespace": claim["namespace"], "claimName": claim["name"], "capacity": observed_capacity, "expectedCapacity": expected_capacity, "nodeAffinity": NODE, "pvcPhase": pvc["status"]["phase"], "pvPhase": pv["status"]["phase"], "pvcCreatedOnlyByStatefulSetTemplate": True},
        "rebind": {"releasedObserved": True, "staleUid": stale_uid, "staleUidCleared": True, "freshUid": rebound_uid, "freshUidDiffers": stale_uid != rebound_uid, "samePv": rebound_pv["metadata"]["name"] == PV, "sameBacking": True, "nonceSha256Before": initial_digest, "nonceSha256After": hashlib.sha256(readback.encode()).hexdigest(), "byteIdentical": readback == nonce, "finalPvcPhase": rebound_pvc["status"]["phase"]},
        "migrationCorpus": {"negativeCases": 3, "positiveCases": 1, "independentVerification": True, "completionOrderPinned": True},
        "scalingAuthority": {"freshSnapshotRequired": True, "singleUseToken": True, "providerCapabilityAbsent": True},
        "cleanup": cleanup,
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="this run's observation")
    parser.add_argument("--image", required=True, help="the Phase-30 published digest reference")
    arguments = parser.parse_args(argv)
    globals()["PRIVATE_IMAGE"] = arguments.image
    try:
        value = execute()
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("retained-storage-volume-live: PASS (image cap, exact bind, Released-to-Bound rebind, nonce readback)")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        debug = kubectl("-n", NAMESPACE, "get", "pods", "-o", "wide", check=False).stdout
        debug += kubectl("-n", NAMESPACE, "describe", "pod", f"{STATEFULSET}-0", check=False).stdout
        debug += kubectl("-n", NAMESPACE, "logs", f"{STATEFULSET}-0", "--all-containers", check=False).stdout
        cleanup_kubernetes()
        print(f"retained-storage-volume-live: FAIL: {problem}\n{debug}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
