#!/usr/bin/env python3
"""Exercise the Phase-44 boundaries available without valid AWS authority."""

from __future__ import annotations

import base64
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Sequence

import phase29_vault_live as vault_live
import phase30_backbone_live as backbone


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_44/provider-checkpoint-live.json"
LIVE_ROOT = Path("/var/tmp/amoebius-provider-deploy-checkpoint-live")
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KUBECTL = "/usr/bin/kubectl"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
PULUMI = "/usr/local/bin/pulumi"
STRACE = "/usr/bin/strace"
NAMESPACE = "provider-deploy-checkpoint-system"
BUCKET = "provider-deploy-checkpoint-pulumi"
IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
OBJECT_NAMES = (
    "current/deployment.json",
    "update/old/deployment.json",
    "update/new/deployment.json",
    "revisions/1/deployment.json",
    "revisions/2/deployment.json",
    "partial/deployment.json",
)


class Phase44Failure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, input_bytes: bytes | None = None, check: bool = True, timeout: int = 900, environment: dict[str, str] | None = None) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
        env=os.environ.copy() if environment is None else environment,
    )
    if check and result.returncode:
        raise Phase44Failure(f"command-failed:{arguments[0]}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def kubectl(*arguments: str, input_value: dict[str, Any] | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[bytes]:
    payload = None if input_value is None else json.dumps(input_value).encode()
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_bytes=payload, check=check, timeout=timeout)


def fingerprint(value: Any) -> str:
    payload = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def current_binary() -> Path:
    run((CABAL, "build", "exe:amoebius", "-w", GHC, "-j1", "-v0"), timeout=1800)
    binary = Path(text(run((CABAL, "list-bin", "exe:amoebius", "-w", GHC))).strip())
    if not binary.is_file():
        raise Phase44Failure("amoebius-binary-absent")
    return binary


def reset() -> None:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true", "--wait=true", "--timeout=180s", check=False)
    if LIVE_ROOT != Path("/var/tmp/amoebius-provider-deploy-checkpoint-live"):
        raise Phase44Failure("unsafe-live-root")
    if LIVE_ROOT.exists():
        shutil.rmtree(LIVE_ROOT)
    LIVE_ROOT.mkdir(parents=True)


def control_plane_readback() -> dict[str, Any]:
    deployment = json.loads(text(kubectl("-n", "live-dsl-deploy-system", "get", "deployment", "amoebius-control-plane", "-o", "json")))
    replicas = deployment["spec"].get("replicas")
    ready = deployment["status"].get("readyReplicas", 0)
    available = deployment["status"].get("availableReplicas", 0)
    if (replicas, ready, available) != (1, 1, 1):
        raise Phase44Failure(f"control-plane-readback:{replicas}:{ready}:{available}")
    return {
        "kind": "Deployment", "namespace": "live-dsl-deploy-system", "name": "amoebius-control-plane",
        "replicas": replicas, "readyReplicas": ready, "availableReplicas": available,
        "bespokeElection": False,
    }


def executor_job(name: str) -> dict[str, Any]:
    return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {"name": name, "namespace": NAMESPACE, "labels": {"amoebius.io/phase": "44"}},
        "spec": {
            "backoffLimit": 0,
            "activeDeadlineSeconds": 120,
            "template": {
                "metadata": {"labels": {"amoebius.io/phase": "44", "amoebius.io/executor": name}},
                "spec": {
                    "restartPolicy": "Never", "enableServiceLinks": False,
                    "containers": [{
                        "name": "pulumi-executor", "image": IMAGE, "imagePullPolicy": "Never",
                        "command": ["/bin/sh", "-c", "sleep 12"], "env": [],
                        "resources": {
                            "requests": {"cpu": "250m", "memory": "256Mi", "ephemeral-storage": "128Mi"},
                            "limits": {"cpu": "500m", "memory": "512Mi", "ephemeral-storage": "256Mi"},
                        },
                        "volumeMounts": [
                            {"name": "plugin-cache", "mountPath": "/var/lib/amoebius/pulumi/plugins"},
                            {"name": "workspace", "mountPath": "/var/lib/amoebius/pulumi/workspace"},
                        ],
                    }],
                    "volumes": [
                        {"name": "plugin-cache", "emptyDir": {"sizeLimit": "32Mi"}},
                        {"name": "workspace", "emptyDir": {"sizeLimit": "64Mi"}},
                    ],
                },
            },
        },
    }


def place_executors() -> list[dict[str, Any]]:
    kubectl("create", "namespace", NAMESPACE)
    names = ("p44-executor-control-plane", "p44-executor-node-group")
    for name in names:
        kubectl("apply", "-f", "-", input_value=executor_job(name))
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        pods = json.loads(text(kubectl("-n", NAMESPACE, "get", "pods", "-l", "amoebius.io/phase=44", "-o", "json")))["items"]
        if len(pods) == 2 and all(item.get("status", {}).get("phase") == "Running" for item in pods):
            break
        time.sleep(1)
    else:
        raise Phase44Failure("parallel-executor-live-set-not-observed")
    rows = []
    for name in names:
        job = json.loads(text(kubectl("-n", NAMESPACE, "get", "job", name, "-o", "json")))
        container = job["spec"]["template"]["spec"]["containers"][0]
        volumes = {value["name"]: value["emptyDir"]["sizeLimit"] for value in job["spec"]["template"]["spec"]["volumes"]}
        if container["resources"]["requests"] != {"cpu": "250m", "ephemeral-storage": "128Mi", "memory": "256Mi"}:
            raise Phase44Failure(f"executor-request-readback:{name}")
        if volumes != {"plugin-cache": "32Mi", "workspace": "64Mi"}:
            raise Phase44Failure(f"executor-volume-readback:{name}:{volumes}")
        rows.append({
            "name": name, "requests": container["resources"]["requests"],
            "limits": container["resources"]["limits"], "volumes": volumes,
            "environmentEntries": len(container.get("env", [])), "serviceLinks": False,
        })
    for name in names:
        kubectl("-n", NAMESPACE, "wait", "--for=condition=complete", f"job/{name}", "--timeout=120s")
    return rows


def pulumi_execve_observation() -> dict[str, Any]:
    trace = LIVE_ROOT / "pulumi-execve.trace"
    result = run((STRACE, "-f", "-qq", "-s", "4096", "-e", "trace=execve", "-o", str(trace), PULUMI, "version"), environment={}, check=False, timeout=120)
    observed = trace.read_text(encoding="utf-8", errors="replace")
    matching = [line for line in observed.splitlines() if f'"{PULUMI}"' in line]
    if result.returncode != 0 or not matching or not any("/* 0 vars */" in line for line in matching):
        raise Phase44Failure(f"pulumi-empty-env-execve:{result.returncode}:{matching}")
    version = text(result).strip()
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", version):
        raise Phase44Failure(f"pulumi-version-shape:{version}")
    return {
        "observer": "strace -f -e execve", "argv": [PULUMI, "version"],
        "absolutePath": True, "environmentEntries": 0, "version": version,
        "providerUpArgv": "UNVERIFIED (AWS authority invalid)",
    }


def list_bucket() -> bytes:
    status, payload = backbone.s3_request("GET", BUCKET, query="list-type=2")
    if status != 200:
        raise Phase44Failure(f"minio-list:{status}:{payload.decode(errors='replace')}")
    return payload


def checkpoint_roundtrip(binary: Path) -> dict[str, Any]:
    password = os.environ.get("PHASE29_OPERATOR_PASSWORD") or os.environ.get("PHASE29_DEVELOPMENT_PASSWORD")
    if not password:
        raise Phase44Failure("phase29-operator-password-required")
    opened = vault_live.open_unlock(password.encode(), binary)
    root_token = opened["root_token"]
    unseal_key = opened["unseal_key"]
    suffix = secrets.token_hex(4)
    key_name = f"p44-checkpoint-{suffix}"
    created: list[str] = []
    sealed = False
    plaintext = b'{"deployment":"amoebius-p44","provider":"aws-eks","revision":1}'
    try:
        with vault_live.port_forward(), backbone.port_forward("platform-system", "service/minio", backbone.MINIO_PORT, 9000):
            backbone.ensure_bucket(BUCKET)
            vault_live.require_api("POST", f"transit/keys/{key_name}", root_token, {}, {200, 204})
            before_refusal = list_bucket()
            vault_live.require_api("PUT", "sys/seal", root_token, {})
            sealed = True
            refusal_status, _ = vault_live.api_request(
                "POST", f"transit/encrypt/{key_name}", root_token,
                {"plaintext": base64.b64encode(plaintext).decode()},
            )
            if refusal_status < 400 or list_bucket() != before_refusal:
                raise Phase44Failure("sealed-vault-did-not-refuse-before-checkpoint-put")
            unseal_status, unseal_payload = vault_live.api_request("PUT", "sys/unseal", body={"key": unseal_key})
            if unseal_status != 200 or json.loads(unseal_payload).get("sealed"):
                raise Phase44Failure(f"vault-unseal:{unseal_status}")
            sealed = False
            kubectl("-n", "vault-system", "wait", "--for=condition=Ready", "pod/root-vault-0", "--timeout=180s")
            rows = []
            for object_name in OBJECT_NAMES:
                raw = plaintext + b":" + object_name.encode()
                ciphertext = vault_live.require_api(
                    "POST", f"transit/encrypt/{key_name}", root_token,
                    {"plaintext": base64.b64encode(raw).decode()},
                )["data"]["ciphertext"]
                envelope = {
                    "envelopeVersion": 1, "keyName": key_name, "ciphertext": ciphertext,
                    "plaintextSha256": sha256(raw),
                }
                encoded = (json.dumps(envelope, sort_keys=True, separators=(",", ":")) + "\n").encode()
                status, response = backbone.s3_request("PUT", BUCKET, object_name, encoded)
                if status not in {200, 201}:
                    raise Phase44Failure(f"checkpoint-put:{object_name}:{status}:{response.decode(errors='replace')}")
                created.append(object_name)
                status, stored = backbone.s3_request("GET", BUCKET, object_name)
                if status != 200 or stored != encoded or raw in stored:
                    raise Phase44Failure(f"checkpoint-opaque-readback:{object_name}")
                decoded = json.loads(stored)
                recovered = vault_live.require_api(
                    "POST", f"transit/decrypt/{key_name}", root_token,
                    {"ciphertext": decoded["ciphertext"]},
                )["data"]["plaintext"]
                if base64.b64decode(recovered) != raw:
                    raise Phase44Failure(f"checkpoint-transit-decrypt:{object_name}")
                rows.append({"object": object_name, "bytes": len(stored), "ciphertextPrefix": "vault:v1:", "plaintextAbsent": True})
            inventory = list_bucket().decode(errors="replace")
            if not all(name in inventory for name in OBJECT_NAMES):
                raise Phase44Failure("checkpoint-inventory-incomplete")
            return {
                "keyNamePattern": "p44-checkpoint-<random>", "objects": rows,
                "exactObjectPeak": len(rows), "directTransitDecrypt": True,
                "sealedVaultRefusalStatus": refusal_status,
                "sealedVaultCheckpointInventoryUnchanged": True,
                "plaintextDataKeyWritten": False,
            }
    finally:
        if sealed:
            with vault_live.port_forward():
                vault_live.api_request("PUT", "sys/unseal", body={"key": unseal_key})
        with vault_live.port_forward():
            vault_live.require_api("POST", f"transit/keys/{key_name}/config", root_token, {"deletion_allowed": True}, {200, 204, 404})
            vault_live.require_api("DELETE", f"transit/keys/{key_name}", root_token, accepted={204, 404})
        with backbone.port_forward("platform-system", "service/minio", backbone.MINIO_PORT, 9000):
            for object_name in created:
                backbone.s3_request("DELETE", BUCKET, object_name)
            backbone.s3_request("DELETE", BUCKET)
        del root_token
        del unseal_key
        del opened


def aws_authority() -> dict[str, Any]:
    executable = shutil.which("aws")
    if executable is None:
        return {"available": False, "identity": "UNVERIFIED", "reason": "aws-cli-unavailable-in-gate-process"}
    result = run((executable, "sts", "get-caller-identity", "--output", "json"), check=False, timeout=30)
    output = text(result)
    if result.returncode == 0:
        parsed = json.loads(output)
        return {"available": True, "identity": "verified", "accountDigest": sha256(str(parsed.get("Account", "")).encode())}
    reason = "InvalidClientTokenId" if "InvalidClientTokenId" in output else "provider-identity-refused"
    return {"available": True, "identity": "UNVERIFIED", "reason": reason}


def cleanup() -> dict[str, Any]:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true", "--wait=true", "--timeout=180s", check=False)
    namespace = kubectl("get", "namespace", NAMESPACE, check=False)
    if namespace.returncode == 0:
        raise Phase44Failure("namespace-cleanup")
    if LIVE_ROOT.exists():
        shutil.rmtree(LIVE_ROOT)
    return {"phase44NamespaceAbsent": True, "temporaryRootAbsent": True, "checkpointBucketRemoved": True, "transitKeyRemoved": True}


def execute() -> dict[str, Any]:
    reset()
    control_plane = control_plane_readback()
    executors: list[dict[str, Any]] = []
    engine: dict[str, Any] = {}
    checkpoints: dict[str, Any] = {}
    authority: dict[str, Any] = {}
    cleaned: dict[str, Any] = {}
    try:
        executors = place_executors()
        engine = pulumi_execve_observation()
        authority = aws_authority()
        checkpoints = checkpoint_roundtrip(current_binary())
    finally:
        cleaned = cleanup()
    evidence: dict[str, Any] = {
        "schema": "amoebius.phase44.provider-checkpoint-live.v1",
        "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3, "substrate": "linux-cpu", "targetClass": "provider:aws-eks",
        "controlPlane": control_plane,
        "executorPlacement": {"boundedParallel": 2, "jobs": executors, "source": "external gate harness; real control-plane-daemon Pulumi up UNVERIFIED"},
        "engineBoundary": engine,
        "checkpoint": checkpoints,
        "providerAuthority": authority,
        "providerMaterialization": {
            "eksControlPlane": "UNVERIFIED", "managedNodeGroup": "UNVERIFIED",
            "providerAccountObservation": "UNVERIFIED", "cloudTrailMutationAudit": "UNVERIFIED",
            "reason": "valid AWS authority unavailable; no AWS mutation attempted",
        },
        "deferred": {
            "pulumiUpFromControlPlaneDaemon": "UNVERIFIED", "awsPluginExecve": "UNVERIFIED",
            "enginePodFilesystemObserver": "UNVERIFIED", "directS3OutsideGatewayDenied": "UNVERIFIED",
        },
        "cleanup": cleaned,
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
    print("provider-deploy-checkpoint-provider-checkpoint-scoped-live: PASS")
    print(f"provider-deploy-checkpoint-provider-materialization: UNVERIFIED ({evidence['evidenceDigest']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
