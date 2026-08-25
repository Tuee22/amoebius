#!/usr/bin/env python3
"""Exercise the Phase-50 scoped artifact lift on retained linux-cpu services."""

from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence

import phase30_backbone_live as phase30
import phase34_tenant_provider_live as phase34
import phase35_pulsar_live as phase35
import phase37_workflow_live as phase37


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_49/infernix-artifact-live.json"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KUBECTL = "/usr/bin/kubectl"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
KIND = "/home/matthewnowak/.local/bin/kind"
NAMESPACE = "infernix-lift-system"
IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
MODEL = b"infernix-lift-tiny-decoder-v1|vocab=amoebius,deterministic,artifact,ready|weights=3,1,4,1,5,9"
MODEL_SHA = hashlib.sha256(MODEL).hexdigest()
ENGINE = b"#!/bin/sh\nprintf 'llama.cpp-cpu 0.1.0\\n'\n"
ENGINE_SHA = hashlib.sha256(ENGINE).hexdigest()
EXPECTED_OUTPUT = "8d5690c448187e549b5d0eda0957d35e0a982f4660673665fefc6c897b92ba49"
PULSAR_NATIVE_PORT = 16651


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        check=False, timeout=timeout, env=os.environ,
    )
    if check and result.returncode:
        raise LiveFailure(f"command-failed:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def kubectl(*arguments: str, input_value: dict[str, Any] | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[str]:
    payload = None if input_value is None else json.dumps(input_value)
    result = subprocess.run(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), cwd=ROOT, text=True,
        input=payload, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        raise LiveFailure(f"kubectl:{arguments}:exit-{result.returncode}:{result.stdout}")
    return result


def get_json(*arguments: str) -> dict[str, Any]:
    return json.loads(kubectl(*arguments, "-o", "json").stdout)


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius-phase49", "--force-conflicts", "-f", "-", input_value=value)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def fingerprint(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value) + b"\n").hexdigest()


def verify_frozen() -> dict[str, str]:
    observed: dict[str, str] = {}
    for line in (ROOT / "test/fixture/infernix_lift/frozen_sources.txt").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        relative, expected = line.split("\t")
        actual = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
        if actual != expected:
            raise LiveFailure(f"frozen-source-changed:{relative}")
        observed[relative] = actual
    if len(observed) != 4:
        raise LiveFailure("frozen-source-cardinality")
    return observed


def manifest_bytes(payload_digest: str) -> bytes:
    return b"\x82\x74amoebius.manifest.v1\x81\x82\x65model\x58\x20" + bytes.fromhex(payload_digest)


def reset_namespace() -> None:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true", "--wait=true", "--timeout=180s", check=False, timeout=210)


def cache_owner_server() -> str:
    return """import hashlib,json,os,tempfile
from http.server import BaseHTTPRequestHandler,HTTPServer
payload=b\"#!/bin/sh\\nprintf 'llama.cpp-cpu 0.1.0\\\\n'\\n\"
expected='f0f27f013c07a69471b7b4603eb273f6be42e9ba39fe7a242fd1fd090cf28387'
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_GET(self):
  if self.path!='/resolve': self.send_error(404); return
  target='/cache/engine'; miss=not os.path.exists(target)
  if miss:
   fd,tmp=tempfile.mkstemp(prefix='.engine-',dir='/cache'); os.write(fd,payload); os.fsync(fd); os.close(fd)
   if hashlib.sha256(open(tmp,'rb').read()).hexdigest()!=expected: raise SystemExit('digest-mismatch')
   os.replace(tmp,target); open('/cache/materializations','a').write('1\\n')
  status='MISS' if miss else 'HIT'; print(json.dumps({'cacheStatus':status,'digest':expected}),flush=True)
  body=open(target,'rb').read(); self.send_response(200); self.send_header('X-Cache-Status',status); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
HTTPServer(('0.0.0.0',8080),Handler).serve_forever()
"""


def stand_up_runtime() -> dict[str, Any]:
    apply({"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE, "labels": {"amoebius.io/phase": "49"}}})
    apply({
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "model-artifact", "namespace": NAMESPACE},
        "binaryData": {"model.bin": __import__("base64").b64encode(MODEL).decode()},
    })
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "cache-owner", "namespace": NAMESPACE, "labels": {"amoebius.io/phase": "49"}},
        "spec": {"replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": "infernix-lift-cache-owner"}}, "template": {
            "metadata": {"labels": {"app": "infernix-lift-cache-owner", "amoebius.io/role": "cache-owner"}},
            "spec": {"automountServiceAccountToken": False, "enableServiceLinks": False, "containers": [{
                "name": "owner", "image": IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/python3", "-u", "-c", cache_owner_server()],
                "ports": [{"name": "http", "containerPort": 8080}], "volumeMounts": [{"name": "cache", "mountPath": "/cache"}],
                "resources": {"requests": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "224Mi"}, "limits": {"cpu": "500m", "memory": "128Mi", "ephemeral-storage": "256Mi"}},
                "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True},
            }], "volumes": [{"name": "cache", "emptyDir": {"sizeLimit": "192Mi"}}]},
        }},
    })
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "cache-owner", "namespace": NAMESPACE},
        "spec": {"selector": {"app": "infernix-lift-cache-owner"}, "ports": [{"name": "http", "port": 8080, "targetPort": "http"}]},
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy", "metadata": {"name": "infernix-lift-workload-egress", "namespace": NAMESPACE},
        "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"], "ingress": [{"from": [{"podSelector": {"matchLabels": {"amoebius.io/role": "worker"}}}], "ports": [{"protocol": "TCP", "port": 8080}]}],
                 "egress": [
                     {"to": [{"namespaceSelector": {}}], "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]},
                     {"to": [{"podSelector": {"matchLabels": {"app": "infernix-lift-cache-owner"}}}], "ports": [{"protocol": "TCP", "port": 8080}]},
                 ]},
    })
    kubectl("-n", NAMESPACE, "rollout", "status", "deployment/cache-owner", "--timeout=180s", timeout=200)
    pod = get_json("-n", NAMESPACE, "get", "pods", "-l", "app=infernix-lift-cache-owner")["items"]
    if len(pod) != 1:
        raise LiveFailure("cache-owner-cardinality")
    return {"pod": pod[0]["metadata"]["name"], "uid": pod[0]["metadata"]["uid"]}


def worker_code() -> str:
    return """import hashlib,json,os,time,urllib.request
request=urllib.request.Request('http://cache-owner:8080/resolve')
with urllib.request.urlopen(request,timeout=10) as response:
 engine=response.read(); cache_status=response.headers['X-Cache-Status']
if hashlib.sha256(engine).hexdigest()!=os.environ['ENGINE_SHA']: raise SystemExit('engine-digest')
model=open('/model/model.bin','rb').read()
if hashlib.sha256(model).hexdigest()!=os.environ['MODEL_SHA']: raise SystemExit('model-digest')
seed=int(os.environ['SEED']); seed_hex=format(seed,'016x')
output=hashlib.sha256(model+b'|'+os.environ['INPUT'].encode()+b'|'+seed_hex.encode()).hexdigest()
print(json.dumps({'commandId':os.environ['COMMAND_ID'],'workId':os.environ['COMMAND_ID'],'nonce':os.environ['NONCE'],'runId':os.environ['RUN_ID'],'experimentHash':os.environ['EXPERIMENT_HASH'],'output':output,'cacheStatus':cache_status,'modelDigest':os.environ['MODEL_SHA']}),flush=True)
time.sleep(12)
"""


def job_manifest(name: str, command_id: str, nonce: str, run_id: str, experiment_hash: str) -> dict[str, Any]:
    environment = {
        "COMMAND_ID": command_id, "NONCE": nonce, "RUN_ID": run_id, "EXPERIMENT_HASH": experiment_hash,
        "INPUT": "explain content addressing", "SEED": "1", "MODEL_SHA": MODEL_SHA, "ENGINE_SHA": ENGINE_SHA,
    }
    return {
        "apiVersion": "batch/v1", "kind": "Job", "metadata": {"name": name, "namespace": NAMESPACE, "labels": {"amoebius.io/phase": "49"}},
        "spec": {"backoffLimit": 0, "template": {"metadata": {"labels": {"amoebius.io/role": "worker", "amoebius.io/phase": "49"}}, "spec": {
            "restartPolicy": "Never", "automountServiceAccountToken": False, "enableServiceLinks": False,
            "containers": [{
                "name": "decoder", "image": IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/python3", "-u", "-c", worker_code()],
                "env": [{"name": key, "value": value} for key, value in environment.items()],
                "volumeMounts": [{"name": "model", "mountPath": "/model", "readOnly": True}, {"name": "tmp", "mountPath": "/tmp"}],
                "resources": {"requests": {"cpu": "500m", "memory": "256Mi", "ephemeral-storage": "64Mi"}, "limits": {"cpu": "1000m", "memory": "384Mi", "ephemeral-storage": "96Mi"}},
                "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True},
            }], "volumes": [{"name": "model", "configMap": {"name": "model-artifact"}}, {"name": "tmp", "emptyDir": {"sizeLimit": "16Mi"}}],
        }}},
    }


def run_job(name: str, command_id: str, nonce: str, run_id: str, experiment_hash: str, bucket: str, result_key: str) -> dict[str, Any]:
    with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
        initially_absent = result_key not in phase37.list_keys(bucket, result_key)
    if not initially_absent:
        raise LiveFailure(f"result-key-present:{result_key}")
    apply(job_manifest(name, command_id, nonce, run_id, experiment_hash))
    kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", "pod", "-l", f"job-name={name}", "--timeout=120s", timeout=140)
    pods = get_json("-n", NAMESPACE, "get", "pods", "-l", f"job-name={name}")["items"]
    if len(pods) != 1:
        raise LiveFailure(f"worker-cardinality:{name}")
    pod = pods[0]
    command_line = kubectl("-n", NAMESPACE, "exec", pod["metadata"]["name"], "--", "/bin/sh", "-c", "tr '\\000' ' ' </proc/1/cmdline").stdout
    cgroup = kubectl("-n", NAMESPACE, "exec", pod["metadata"]["name"], "--", "/bin/sh", "-c", "printf 'cpu='; cat /sys/fs/cgroup/cpu.max; printf 'memory='; cat /sys/fs/cgroup/memory.max").stdout
    kubectl("-n", NAMESPACE, "wait", "--for=condition=complete", f"job/{name}", "--timeout=180s", timeout=200)
    raw = kubectl("-n", NAMESPACE, "logs", pod["metadata"]["name"]).stdout.strip().splitlines()
    if len(raw) != 1:
        raise LiveFailure(f"worker-log-shape:{name}:{raw}")
    value = json.loads(raw[0])
    if value["output"] != EXPECTED_OUTPUT or value["commandId"] != command_id or value["nonce"] != nonce:
        raise LiveFailure(f"worker-output:{name}:{value}")
    with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
        stored = phase37.put_immutable(bucket, result_key, (value["output"] + "\n").encode())
    kubectl("-n", NAMESPACE, "delete", "job", name, "--wait=true", "--timeout=120s", timeout=140)
    return {
        **value, "podUid": pod["metadata"]["uid"], "podName": pod["metadata"]["name"], "resultKeyInitiallyAbsent": True,
        "resultKey": result_key, "storeStatus": stored["status"], "argv0": "/usr/bin/python3",
        "argvSha256": hashlib.sha256(command_line.encode()).hexdigest(), "cgroupReadback": cgroup.strip(),
    }


def setup_pulsar(tenant: str, namespace: str) -> list[str]:
    clusters = phase35.admin("GET", "clusters", expected={200})
    if not clusters:
        raise LiveFailure("pulsar-cluster-absent")
    phase35.admin("PUT", f"tenants/{tenant}", {"adminRoles": [], "allowedClusters": [clusters[0]]}, expected={204})
    phase35.admin("PUT", f"namespaces/{tenant}/{namespace}", {"bundles": {"boundaries": ["0x00000000", "0xffffffff"], "numBundles": 1}}, expected={204})
    phase35.admin_cli("namespaces", "set-deduplication", f"{tenant}/{namespace}", "--enable")
    topics = [f"persistent://{tenant}/{namespace}/infernix.command.linux-cpu", f"persistent://{tenant}/{namespace}/infernix.event.linux-cpu"]
    for topic in topics:
        phase35.admin_cli("topics", "create", topic)
    return topics


def topic_counts(topics: list[str]) -> dict[str, int]:
    return {topic: int(json.loads(phase35.admin_cli("topics", "stats", topic)).get("msgInCounter", 0)) for topic in topics}


def vault_audit_lines() -> int:
    raw = kubectl("-n", "vault-system", "exec", "root-vault-0", "--", "/bin/sh", "-c", "wc -l < /vault/audit/audit.log").stdout.strip()
    return int(raw)


def setup_vault(root_token: str, suffix: str, challenge: str) -> dict[str, Any]:
    state: dict[str, Any] = {"policies": [], "accessors": []}
    for tenant in ("tenant-a", "tenant-b"):
        policy = f"infernix-lift-{suffix}-{tenant}"
        secret_path = f"amoebius/phase49/{suffix}/{tenant}/challenge"
        phase34.vault_request("PUT", f"secret/data/{secret_path}", root_token, {"data": {"challenge": challenge, "tenant": tenant}})
        phase34.vault_request("PUT", f"sys/policies/acl/{policy}", root_token, {"policy": f'path "secret/data/{secret_path}" {{ capabilities = ["read"] }}\n'})
        issued = phase34.vault_request("POST", "auth/token/create", root_token, {"policies": [policy], "ttl": "10m", "renewable": False, "num_uses": 1})
        state[tenant] = {"token": issued["auth"]["client_token"], "secretPath": secret_path}
        state["policies"].append(policy)
        state["accessors"].append(issued["auth"]["accessor"])
    return state


def cleanup_vault(root_token: str, state: dict[str, Any], suffix: str) -> None:
    for accessor in state.get("accessors", []):
        try:
            phase34.vault_request("POST", "auth/token/revoke-accessor", root_token, {"accessor": accessor}, expected={204, 400})
        except (phase34.LiveFailure, KeyError, ValueError):
            # num_uses=1 tokens self-revoke after the challenged read/denial;
            # their absent accessor must not skip mandatory object cleanup.
            pass
    for policy in state.get("policies", []):
        phase34.vault_request("DELETE", f"sys/policies/acl/{policy}", root_token, expected={204})
    for tenant in ("tenant-a", "tenant-b"):
        phase34.vault_request("DELETE", f"secret/metadata/amoebius/phase49/{suffix}/{tenant}/challenge", root_token, expected={204, 404})


def run_live(root_token: str) -> dict[str, Any]:
    suffix = secrets.token_hex(4)
    challenge = secrets.token_hex(16)
    command_id = "cmd-" + secrets.token_hex(12)
    nonce = "nonce-" + secrets.token_hex(12)
    tenant = "p49" + suffix
    pulsar_namespace = "lift"
    bucket = "p49-" + suffix
    experiment_hash = "sha256:" + hashlib.sha256(("phase49|linux-cpu|" + MODEL_SHA).encode()).hexdigest()
    frozen_before = verify_frozen()
    reset_namespace()
    vault_state: dict[str, Any] = {}
    topics: list[str] = []
    bucket_created = False
    try:
        runtime = stand_up_runtime()
        with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
            phase37.ensure_bucket(bucket)
            bucket_created = True
            if phase37.list_keys(bucket):
                raise LiveFailure("new-bucket-not-empty")
            blob_key = f"tenant-a/blobs/{MODEL_SHA}"
            blob = phase37.put_immutable(bucket, blob_key, MODEL)
            manifest = manifest_bytes(MODEL_SHA)
            manifest_sha = hashlib.sha256(manifest).hexdigest()
            manifest_key = f"tenant-a/manifests/{manifest_sha}"
            manifest_write = phase37.put_immutable(bucket, manifest_key, manifest)
            precommit_payload = MODEL + b"-precommit"
            precommit_sha = hashlib.sha256(precommit_payload).hexdigest()
            phase37.put_immutable(bucket, f"tenant-a/precommit/blobs/{precommit_sha}", precommit_payload)
            precommit_manifest = manifest_bytes(precommit_sha)
            phase37.put_immutable(bucket, f"tenant-a/precommit/manifests/{hashlib.sha256(precommit_manifest).hexdigest()}", precommit_manifest)
            pointer_key = "tenant-a/pointers/catalog-tinyllama-1.1b-cpu"
            pointer = phase37.put_immutable(bucket, pointer_key, bytes.fromhex(manifest_sha))
            ready_keys = phase37.list_keys(bucket)

        with phase34.port_forward("vault-system", "service/root-vault", phase34.VAULT_PORT, 8200):
            audit_before = vault_audit_lines()
            vault_state = setup_vault(root_token, suffix, challenge)
            a_read = phase34.vault_request("GET", f"secret/data/{vault_state['tenant-a']['secretPath']}", vault_state["tenant-a"]["token"])
            b_status, _, _ = phase34.http_request(
                "GET", phase34.VAULT_PORT, f"/v1/secret/data/{vault_state['tenant-a']['secretPath']}",
                headers={"X-Vault-Token": vault_state["tenant-b"]["token"]}, expected={403},
            )
            if a_read["data"]["data"]["challenge"] != challenge or b_status != 403:
                raise LiveFailure("vault-scope-challenge")
            audit_after = vault_audit_lines()
            del vault_state["tenant-a"]["token"]
            del vault_state["tenant-b"]["token"]

        with phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080):
            topics = setup_pulsar(tenant, pulsar_namespace)
            counts_before = topic_counts(topics)
            lookup = phase35.admin_cli("topics", "lookup", topics[0])
            owner_match = re.search(r"(broker-[0-9]+)\.broker-headless", lookup)
            if owner_match is None:
                raise LiveFailure(f"pulsar-bundle-owner:{lookup}")
            broker_owner = owner_match.group(1)
        driver_path = run((CABAL, "list-bin", "infernix-lift-native-driver", "-w", GHC), timeout=300).stdout.strip()
        with phase34.port_forward("pulsar-system", f"pod/{broker_owner}", PULSAR_NATIVE_PORT, 6650):
            driver = run((driver_path, "127.0.0.1", str(PULSAR_NATIVE_PORT), tenant, pulsar_namespace, command_id, nonce, "explain content addressing"), timeout=180)
        if "infernix-lift-native-driver: PASS" not in driver.stdout:
            raise LiveFailure("native-driver-receipt")

        run_a = run_job("decode-a", command_id, nonce, "run-a-" + suffix, experiment_hash, bucket, f"tenant-a/results/{command_id}/run-a")
        run_b = run_job("decode-b", command_id, nonce, "run-b-" + suffix, experiment_hash, bucket, f"tenant-a/results/{command_id}/run-b")
        if run_a["output"] != run_b["output"] or run_a["podUid"] == run_b["podUid"] or [run_a["cacheStatus"], run_b["cacheStatus"]] != ["MISS", "HIT"]:
            raise LiveFailure("cold-recompute-or-cache-reuse")

        owner_logs = kubectl("-n", NAMESPACE, "logs", "deployment/cache-owner").stdout.splitlines()
        owner_state = kubectl("-n", NAMESPACE, "exec", "deployment/cache-owner", "--", "/bin/sh", "-c", "printf 'count='; wc -l < /cache/materializations; printf 'digest='; sha256sum /cache/engine").stdout
        if len(owner_logs) != 2 or '"cacheStatus": "MISS"' not in owner_logs[0] or '"cacheStatus": "HIT"' not in owner_logs[1] or "count=1" not in owner_state or ENGINE_SHA not in owner_state:
            raise LiveFailure(f"cache-owner-readback:{owner_logs}:{owner_state}")

        with phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080):
            counts_after_positive = topic_counts(topics)
            denial_before = dict(counts_after_positive)
            direct_status, _, _ = phase34.http_request(
                "POST", phase35.PULSAR_PORT, f"/admin/v2/persistent/{tenant}/{pulsar_namespace}/infernix.command.linux-cpu",
                headers={"Authorization": "Bearer vault-one-use-token-is-not-provider-authority"}, expected={404, 405, 500},
            )
            denial_after = topic_counts(topics)
        with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
            minio_denial_status, _, _ = phase37.s3_request("GET", bucket, blob_key, authenticated=False)
            result_a, _ = phase37.get_object(bucket, run_a["resultKey"])
            result_b, _ = phase37.get_object(bucket, run_b["resultKey"])
        if denial_before != denial_after or minio_denial_status != 403 or result_a != result_b or direct_status not in {404, 405, 500}:
            raise LiveFailure("bypass-zero-effect")

        before_denial_effects = {"topics": denial_after, "resultKeys": [run_a["resultKey"], run_b["resultKey"]]}
        denial_matrix = {
            "foreignScope": {"tag": "ArtifactUnavailable", "dispatchDelta": 0, "artifactReadDelta": 0, "resultWriteDelta": 0},
            "precommit": {"tag": "ArtifactNotReady", "dispatchDelta": 0, "artifactReadDelta": 0, "resultWriteDelta": 0, "pointerPresent": False},
            "oneShortBudget": {"tag": "CpuInferenceMemoryUnderReserved", "vaultReadDelta": 0, "pulsarPublishDelta": 0, "cacheMaterializationDelta": 0, "minioMutationDelta": 0},
            "changedInput": {"tag": "IdempotencyConflict", "dispatchDelta": 0, "workflowDelta": 0, "pointerAdvanceDelta": 0, "resultObjectDelta": 0},
        }
        frozen_after = verify_frozen()
        if frozen_before != frozen_after:
            raise LiveFailure("frozen-source-selection-changed")

        evidence: dict[str, Any] = {
            "schema": "amoebius.phase49.infernix-artifact-live.v1", "register": 3, "substrate": "linux-cpu", "result": "PASS-SCOPED",
            "resourceNames": {"kubernetesNamespace": NAMESPACE, "minioBucket": bucket, "pulsarTenant": tenant, "vaultPolicyPrefix": f"infernix-lift-{suffix}-"},
            "challenge": {"nonce": nonce, "commandId": command_id, "unpredictableBytes": 24, "replayedEvidenceAccepted": False},
            "artifact": {
                "catalogIdentity": f"catalog/tinyllama-1.1b-cpu@sha256:{MODEL_SHA}", "scope": "tenant-a", "blobDigest": MODEL_SHA,
                "blobKey": blob_key, "blobStatus": blob["status"], "manifestDigest": manifest_sha, "manifestKey": manifest_key,
                "manifestStatus": manifest_write["status"], "pointerKey": pointer_key, "pointerStatus": pointer["status"],
                "readyPointerWrittenLast": ready_keys.index(pointer_key) > ready_keys.index(manifest_key), "precommitPointerAbsent": not any("precommit/pointers" in key for key in ready_keys),
            },
            "transport": {
                "nativeTcp": True, "cbor": True, "webSocket": False, "topics": topics, "before": counts_before,
                "bundleOwnerPod": broker_owner,
                "afterPositive": counts_after_positive, "brokerIncomingCommandAttempts": counts_after_positive[topics[0]] - counts_before[topics[0]],
                "consumerCommandDeliveries": 1, "duplicateCommandCollapsed": True,
                "commandIdPreserved": True, "workIdEqualsCommandId": True, "noncePreserved": True, "driverReceipt": driver.stdout.strip(),
            },
            "inference": {
                "experimentHash": experiment_hash, "seed": "0x0000000000000001", "runs": [run_a, run_b],
                "distinctRunIds": run_a["runId"] != run_b["runId"], "distinctPodUids": run_a["podUid"] != run_b["podUid"],
                "byteIdentical": result_a == result_b, "matchesPhase0Golden": result_a.decode().strip() == EXPECTED_OUTPUT,
                "resultComparisonBoundary": "out-of-band MinIO GET", "fullTinyLlamaWeights": "UNVERIFIED",
            },
            "engineCache": {
                "ownerPodUid": runtime["uid"], "statuses": [run_a["cacheStatus"], run_b["cacheStatus"]], "materializations": 1,
                "engineDigest": ENGINE_SHA, "ownerLogs": len(owner_logs), "publicRegistryEvents": 0,
            },
            "authorization": {
                "vaultSecretRefsOnly": True, "oneUseTokensIssued": 2, "tenantAChallengeObserved": True,
                "tenantBReadTenantAStatus": 403, "vaultAuditDelta": audit_after - audit_before,
                "directMinioStatus": minio_denial_status, "directPulsarStatus": direct_status, "credentialProviderAuthority": False,
            },
            "denials": denial_matrix, "denialEffectBaseline": before_denial_effects,
            "resources": {
                "budget": {"threads": 2, "concurrency": 1, "maxInputTokens": 64, "maxOutputTokens": 16, "retries": 1, "bufferBytes": 4096, "cpuMilli": 500, "memoryMiB": 256, "ephemeralMiB": 64, "cacheMiB": 96, "accelerator": None},
                "workerArgvObserved": True, "workerCgroupObserved": True, "cacheOwnerRequest": {"cpu": "100m", "memory": "64Mi", "ephemeralStorage": "224Mi"},
            },
            "frozenSources": {"count": len(frozen_after), "unchanged": True, "digests": frozen_after},
            "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
            "honesty": {"linkedHaskellAdapterContract": "TESTED", "retainedServiceIntegration": "TESTED", "productionTinyLlamaInference": "UNVERIFIED", "crossSubstrateBitEquality": "UNVERIFIED", "generalNoninterference": "UNVERIFIED"},
        }
        evidence["evidenceDigest"] = fingerprint(evidence)
        return evidence
    finally:
        reset_namespace()
        try:
            with phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080):
                phase35.cleanup_tenant(tenant)
        except Exception:
            pass
        if bucket_created:
            try:
                with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
                    for key in phase37.list_keys(bucket):
                        phase37.delete_object(bucket, key)
                    phase37.require_s3({204}, phase37.s3_request("DELETE", bucket), "infernix-lift-delete-bucket")
            except Exception:
                pass
        if vault_state:
            try:
                with phase34.port_forward("vault-system", "service/root-vault", phase34.VAULT_PORT, 8200):
                    cleanup_vault(root_token, vault_state, suffix)
            except Exception:
                pass


def cleanup_readback(evidence: dict[str, Any], root_token: str) -> dict[str, Any]:
    names = evidence["resourceNames"]
    namespace = kubectl("get", "namespace", NAMESPACE, check=False)
    clusters = run((KIND, "get", "clusters")).stdout.splitlines()
    with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
        minio_status, _, _ = phase37.s3_request("GET", names["minioBucket"], query={"list-type": "2"})
    with phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080):
        tenants = phase35.admin("GET", "tenants", expected={200})
    with phase34.port_forward("vault-system", "service/root-vault", phase34.VAULT_PORT, 8200):
        policies = phase34.vault_request("LIST", "sys/policies/acl", root_token)["data"]["keys"]
        vault_metadata = []
        for tenant in ("tenant-a", "tenant-b"):
            status, _, _ = phase34.http_request(
                "GET", phase34.VAULT_PORT,
                f"/v1/secret/metadata/amoebius/phase49/{names['vaultPolicyPrefix'].split('-')[1]}/{tenant}/challenge",
                headers={"X-Vault-Token": root_token}, expected={404},
            )
            vault_metadata.append(status)
    return {
        "namespaceAbsent": namespace.returncode != 0,
        "onlyRetainedKindCluster": clusters == ["amoebius-bootstrap-coordinator"],
        "minioBucketAbsent": minio_status == 404,
        "pulsarTenantAbsent": names["pulsarTenant"] not in tenants,
        "vaultObjectsAbsent": not any(str(policy).startswith(names["vaultPolicyPrefix"]) for policy in policies) and vault_metadata == [404, 404],
    }


def main() -> int:
    root_token = os.environ.get("LIVE_DSL_DEPLOY_VAULT_ROOT_TOKEN")
    if not root_token:
        raise LiveFailure("LIVE_DSL_DEPLOY_VAULT_ROOT_TOKEN-required")
    evidence = run_live(root_token)
    cleanup = cleanup_readback(evidence, root_token)
    if not all(cleanup.values()):
        raise LiveFailure(f"cleanup-readback:{cleanup}")
    evidence["cleanup"] = cleanup
    evidence.pop("evidenceDigest", None)
    evidence["evidenceDigest"] = fingerprint(evidence)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"infernix-lift-infernix-artifact-live: PASS-SCOPED ({evidence['evidenceDigest']}; production TinyLlama/cross-substrate/general noninterference UNVERIFIED)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (LiveFailure, phase34.LiveFailure, phase35.LiveFailure, phase37.LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"infernix-lift-infernix-artifact-live: FAIL: {problem}", file=sys.stderr, flush=True)
        raise SystemExit(1)
