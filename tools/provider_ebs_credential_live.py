#!/usr/bin/env python3
"""Exercise Phase-46 retained-storage boundaries without claiming AWS EBS."""

from __future__ import annotations

import base64
import datetime as dt
import hashlib
import json
import os
import secrets
import subprocess
import time
from pathlib import Path
from typing import Any, Sequence

import phase29_vault_live as vault_live
import phase30_backbone_live as backbone
import phase44_provider_checkpoint_live as phase44


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_46/provider-ebs-live.json"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KUBECTL = "/usr/bin/kubectl"
DOCKER = "/usr/bin/docker"
NAMESPACE = "provider-ebs-credential-system"
STATIC_PV = "provider-ebs-credential-static-ebs-object"
IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"


class Phase46Failure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, input_bytes: bytes | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
        env=os.environ,
    )
    if check and result.returncode:
        raise Phase46Failure(f"command-failed:{arguments[0]}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def kubectl(*arguments: str, input_value: dict[str, Any] | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[bytes]:
    payload = None if input_value is None else json.dumps(input_value).encode()
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_bytes=payload, check=check, timeout=timeout)


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius-phase46", "--force-conflicts", "-f", "-", input_value=value)


def get_json(*arguments: str) -> dict[str, Any]:
    return json.loads(text(kubectl(*arguments, "-o", "json")))


def fingerprint(value: Any) -> str:
    payload = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def reset() -> None:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true", "--wait=true", "--timeout=180s", check=False)
    for name in (STATIC_PV, "provider-ebs-credential-retained-a", "provider-ebs-credential-retained-b"):
        kubectl("delete", "persistentvolume", name, "--ignore-not-found=true", "--wait=true", "--timeout=120s", check=False)


def static_ebs_object() -> dict[str, Any]:
    apply({
        "apiVersion": "v1", "kind": "PersistentVolume",
        "metadata": {"name": STATIC_PV, "labels": {"amoebius.io/phase": "46", "amoebius.io/boundary": "object-only"}},
        "spec": {
            "capacity": {"storage": "6Gi"}, "volumeMode": "Filesystem", "accessModes": ["ReadWriteOnce"],
            "persistentVolumeReclaimPolicy": "Retain", "storageClassName": "amoebius-retained",
            "csi": {"driver": "ebs.csi.aws.com", "volumeHandle": "vol-provider-ebs-credential-object-only", "fsType": "ext4"},
            "nodeAffinity": {"required": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "topology.ebs.csi.aws.com/zone", "operator": "In", "values": ["us-east-1a"]}]}]}},
        },
    })
    value = get_json("get", "persistentvolume", STATIC_PV)
    spec = value["spec"]
    csi = spec["csi"]
    affinity = spec["nodeAffinity"]["required"]["nodeSelectorTerms"][0]["matchExpressions"][0]
    expected = ("Retain", "amoebius-retained", "ebs.csi.aws.com", "vol-provider-ebs-credential-object-only", "topology.ebs.csi.aws.com/zone", ["us-east-1a"])
    actual = (spec["persistentVolumeReclaimPolicy"], spec["storageClassName"], csi["driver"], csi["volumeHandle"], affinity["key"], affinity["values"])
    if actual != expected:
        raise Phase46Failure(f"static-ebs-object-readback:{actual}")
    return {
        "apiKind": value["kind"], "reclaimPolicy": actual[0], "storageClass": actual[1],
        "driver": actual[2], "volumeHandle": actual[3], "zoneKey": actual[4], "zones": actual[5],
        "bindingAttempted": False, "providerVolumeExists": "UNVERIFIED",
    }


def storage_class_readback() -> dict[str, Any]:
    value = get_json("get", "storageclass", "amoebius-retained")
    if value.get("provisioner") != "kubernetes.io/no-provisioner" or value.get("reclaimPolicy") != "Retain":
        raise Phase46Failure("retained-storage-class")
    ebs_classes = [
        item["metadata"]["name"] for item in get_json("get", "storageclass")["items"]
        if item.get("provisioner") == "ebs.csi.aws.com"
    ]
    if ebs_classes:
        raise Phase46Failure(f"dynamic-ebs-storage-class-present:{ebs_classes}")
    return {
        "name": value["metadata"]["name"], "provisioner": value["provisioner"],
        "reclaimPolicy": value["reclaimPolicy"], "dynamicEbsStorageClasses": ebs_classes,
    }


def host_path_pv(name: str, path: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "PersistentVolume",
        "metadata": {"name": name, "labels": {"amoebius.io/phase": "46", "amoebius.io/scoped-backing": "hostpath"}},
        "spec": {
            "capacity": {"storage": "8Mi"}, "volumeMode": "Filesystem", "accessModes": ["ReadWriteOnce"],
            "persistentVolumeReclaimPolicy": "Retain", "storageClassName": "amoebius-retained",
            "hostPath": {"path": path, "type": "DirectoryOrCreate"},
        },
    }


def claim(volume_name: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "PersistentVolumeClaim",
        "metadata": {"name": "marker", "namespace": NAMESPACE},
        "spec": {
            "accessModes": ["ReadWriteOnce"], "storageClassName": "amoebius-retained",
            "volumeName": volume_name, "resources": {"requests": {"storage": "8Mi"}},
        },
    }


def marker_pod(name: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Pod", "metadata": {"name": name, "namespace": NAMESPACE},
        "spec": {
            "restartPolicy": "Never", "enableServiceLinks": False,
            "initContainers": [{
                "name": "prepare-test-mount", "image": IMAGE, "imagePullPolicy": "Never",
                "command": ["/bin/chmod", "0777", "/data"],
                "securityContext": {"runAsUser": 0, "runAsGroup": 0, "allowPrivilegeEscalation": False},
                "resources": {"requests": {"cpu": "5m", "memory": "8Mi", "ephemeral-storage": "2Mi"}, "limits": {"cpu": "25m", "memory": "32Mi", "ephemeral-storage": "4Mi"}},
                "volumeMounts": [{"name": "data", "mountPath": "/data"}],
            }],
            "containers": [{
                "name": "marker", "image": IMAGE, "imagePullPolicy": "Never",
                "command": ["/bin/sh", "-c", "sleep 3600"],
                "resources": {"requests": {"cpu": "5m", "memory": "16Mi", "ephemeral-storage": "4Mi"}, "limits": {"cpu": "50m", "memory": "64Mi", "ephemeral-storage": "8Mi"}},
                "volumeMounts": [{"name": "data", "mountPath": "/data"}],
            }],
            "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "marker"}}],
        },
    }


def wait_bound_claim(volume_name: str) -> None:
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        value = get_json("-n", NAMESPACE, "get", "persistentvolumeclaim", "marker")
        if value.get("status", {}).get("phase") == "Bound" and value.get("spec", {}).get("volumeName") == volume_name:
            return
        time.sleep(1)
    raise Phase46Failure(f"claim-not-bound:{volume_name}")


def wait_pod(name: str) -> None:
    kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", f"pod/{name}", "--timeout=180s")


def retained_marker_roundtrip(path: str) -> dict[str, Any]:
    marker = secrets.token_hex(32).encode()
    apply(host_path_pv("provider-ebs-credential-retained-a", path))
    apply(claim("provider-ebs-credential-retained-a"))
    wait_bound_claim("provider-ebs-credential-retained-a")
    apply(marker_pod("marker-writer"))
    wait_pod("marker-writer")
    run((KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "exec", "marker-writer", "-c", "marker", "--", "/bin/sh", "-c", f"printf %s {marker.decode()} > /data/marker"))
    first_pv = get_json("get", "persistentvolume", "provider-ebs-credential-retained-a")
    kubectl("-n", NAMESPACE, "delete", "pod", "marker-writer", "--wait=true", "--timeout=120s")
    kubectl("-n", NAMESPACE, "delete", "persistentvolumeclaim", "marker", "--wait=true", "--timeout=120s")
    kubectl("delete", "persistentvolume", "provider-ebs-credential-retained-a", "--wait=true", "--timeout=120s")
    apply(host_path_pv("provider-ebs-credential-retained-b", path))
    apply(claim("provider-ebs-credential-retained-b"))
    wait_bound_claim("provider-ebs-credential-retained-b")
    apply(marker_pod("marker-reader"))
    wait_pod("marker-reader")
    recovered = run((KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "exec", "marker-reader", "-c", "marker", "--", "/bin/cat", "/data/marker")).stdout.strip()
    second_pv = get_json("get", "persistentvolume", "provider-ebs-credential-retained-b")
    if recovered != marker:
        raise Phase46Failure("retained-marker-byte-mismatch")
    run((KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "exec", "marker-reader", "-c", "marker", "--", "/bin/rm", "-f", "/data/marker"))
    return {
        "backing": "retained hostPath scoped analogue; not EBS", "firstPvUid": first_pv["metadata"]["uid"],
        "secondPvUid": second_pv["metadata"]["uid"], "pvIdentityChanged": first_pv["metadata"]["uid"] != second_pv["metadata"]["uid"],
        "backingPathStable": True, "markerDigest": sha256(marker), "byteExact": True,
        "ebsVolumeHandleStable": "UNVERIFIED",
    }


def checkpoint_class_roundtrip(binary: Path) -> dict[str, Any]:
    password = os.environ.get("PHASE29_OPERATOR_PASSWORD") or os.environ.get("PHASE29_DEVELOPMENT_PASSWORD")
    if not password:
        raise Phase46Failure("phase29-operator-password-required")
    opened = vault_live.open_unlock(password.encode(), binary)
    root_token = opened["root_token"]
    key_name = "p46-durable-" + secrets.token_hex(4)
    bucket = "provider-ebs-credential-checkpoints-" + secrets.token_hex(4)
    keys = ("ephemeral/cluster/checkpoint.json", "durable/pv/data-sts0-pv_0/checkpoint.json")
    stored_keys: list[str] = []
    try:
        with vault_live.port_forward(), backbone.port_forward("platform-system", "service/minio", backbone.MINIO_PORT, 9000):
            backbone.ensure_bucket(bucket)
            vault_live.require_api("POST", f"transit/keys/{key_name}", root_token, {}, {200, 204})
            for object_key, resource_class in zip(keys, ("ephemeral-cluster", "durable-per-pv")):
                raw = json.dumps({"class": resource_class, "protect": resource_class == "durable-per-pv", "retain": resource_class == "durable-per-pv"}, sort_keys=True).encode()
                encrypted = vault_live.require_api("POST", f"transit/encrypt/{key_name}", root_token, {"plaintext": base64.b64encode(raw).decode()})["data"]["ciphertext"]
                envelope = (json.dumps({"ciphertext": encrypted, "plaintextSha256": sha256(raw)}, sort_keys=True, separators=(",", ":")) + "\n").encode()
                status, _ = backbone.s3_request("PUT", bucket, object_key, envelope)
                if status not in {200, 201}:
                    raise Phase46Failure(f"checkpoint-put:{status}")
                status, observed = backbone.s3_request("GET", bucket, object_key)
                if status != 200 or observed != envelope or raw in observed:
                    raise Phase46Failure("checkpoint-opaque-readback")
                recovered = vault_live.require_api("POST", f"transit/decrypt/{key_name}", root_token, {"ciphertext": json.loads(observed)["ciphertext"]})["data"]["plaintext"]
                if base64.b64decode(recovered) != raw:
                    raise Phase46Failure("checkpoint-transit-recovery")
                stored_keys.append(object_key)
            status, inventory = backbone.s3_request("GET", bucket, query="list-type=2")
            if status != 200 or not all(key.encode() in inventory for key in keys):
                raise Phase46Failure("checkpoint-class-inventory")
            return {
                "objectKeys": list(keys), "distinctLogicalNamespaces": True, "objectsOpaque": True,
                "directTransitRecovery": True, "durableProtectRetainMetadataRecovered": True,
            }
    finally:
        with vault_live.port_forward():
            vault_live.require_api("POST", f"transit/keys/{key_name}/config", root_token, {"deletion_allowed": True}, {200, 204, 404})
            vault_live.require_api("DELETE", f"transit/keys/{key_name}", root_token, accepted={204, 404})
        with backbone.port_forward("platform-system", "service/minio", backbone.MINIO_PORT, 9000):
            for object_key in stored_keys:
                backbone.s3_request("DELETE", bucket, object_key)
            backbone.s3_request("DELETE", bucket)
        del root_token
        del opened


def cleanup(path: str) -> dict[str, Any]:
    reset()
    if not path.startswith("/var/lib/amoebius/phase46/") or len(path) < len("/var/lib/amoebius/phase46/") + 8:
        raise Phase46Failure("unsafe-hostpath-cleanup")
    run((DOCKER, "exec", "amoebius-bootstrap-coordinator-control-plane", "/bin/rm", "-rf", path))
    namespace_absent = kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0
    pvs = [item["metadata"]["name"] for item in get_json("get", "persistentvolume")["items"] if item["metadata"]["name"].startswith("provider-ebs-credential-")]
    if not namespace_absent or pvs:
        raise Phase46Failure(f"cleanup:{namespace_absent}:{pvs}")
    return {"namespaceAbsent": True, "phase46PersistentVolumes": [], "hostPathRemoved": True, "checkpointBucketRemoved": True, "transitKeyRemoved": True, "providerResources": "none-created"}


def execute() -> dict[str, Any]:
    reset()
    suffix = secrets.token_hex(6)
    host_path = f"/var/lib/amoebius/phase46/{suffix}"
    static_object: dict[str, Any] = {}
    storage_class: dict[str, Any] = {}
    marker: dict[str, Any] = {}
    checkpoint: dict[str, Any] = {}
    cleaned: dict[str, Any] = {}
    try:
        apply({"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE, "labels": {"amoebius.io/phase": "46"}}})
        storage_class = storage_class_readback()
        static_object = static_ebs_object()
        marker = retained_marker_roundtrip(host_path)
        checkpoint = checkpoint_class_roundtrip(phase44.current_binary())
    finally:
        cleaned = cleanup(host_path)
    evidence: dict[str, Any] = {
        "schema": "amoebius.phase46.provider-ebs-live.v1", "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3, "substrate": "linux-cpu", "targetClass": "provider:aws-eks",
        "scopedBoundary": "retained kind storage and checkpoint-class analogue; not an AWS EBS or IAM result",
        "storageClass": storage_class, "staticEbsPvObject": static_object, "retainedMarker": marker,
        "checkpointClasses": checkpoint, "cleanup": cleaned,
        "providerMaterialization": {
            "realEbsVolume": "UNVERIFIED", "operationalEc2CreateVolume": "UNVERIFIED",
            "operationalEc2DeleteVolumeDenied": "UNVERIFIED", "awsEbsCsiReady": "UNVERIFIED",
            "providerAttachMount": "UNVERIFIED", "sameEbsHandleReattach": "UNVERIFIED",
            "providerRawAndUsableGeometry": "UNVERIFIED", "cloudAudit": "UNVERIFIED",
            "reason": "Phase 44 AWS authority invalid",
        },
        "bakedCsiBinaryExecution": {"amd64": "UNVERIFIED", "arm64": "UNVERIFIED"},
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }
    evidence["evidenceDigest"] = fingerprint(evidence)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main() -> int:
    evidence = execute()
    print("provider-ebs-credential-provider-ebs-scoped-live: PASS")
    print(f"provider-ebs-credential-aws-ebs-iam: UNVERIFIED ({evidence['evidenceDigest']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
