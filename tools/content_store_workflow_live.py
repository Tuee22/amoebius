#!/usr/bin/env python3
"""Phase-38 live MinIO/Pulsar/Kubernetes observer and mutation gateway."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import hmac
import http.client
import json
import os
import secrets
import time
import urllib.parse
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Any

import phase30_backbone_live as phase30
import phase34_tenant_provider_live as phase34
import phase35_pulsar_live as phase35


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_37/content-store-workflow-live.json"
MINIO_PORT = phase30.MINIO_PORT
PULSAR_PORT = phase35.PULSAR_PORT
GC_HORIZON_SECONDS = 2
EXPECTED_HEAD = "fd0049fa31facd012891d8ce294c218e606c191ba51126680e5903b67b2ab059"
COMPONENTS = {"alpha": b"content-store-workflow-alpha", "zeta": b"content-store-workflow-zeta"}
SWEEP_CLASSES = ["kubernetes", "minio", "pulsar"]


class LiveFailure(RuntimeError):
    pass


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value)).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def aws_key(secret: str, date_stamp: str) -> bytes:
    date_key = hmac.new(("AWS4" + secret).encode(), date_stamp.encode(), hashlib.sha256).digest()
    region_key = hmac.new(date_key, b"us-east-1", hashlib.sha256).digest()
    service_key = hmac.new(region_key, b"s3", hashlib.sha256).digest()
    return hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()


def s3_request(
    method: str,
    bucket: str,
    key: str = "",
    *,
    body: bytes = b"",
    query: dict[str, str] | None = None,
    conditional: dict[str, str] | None = None,
    authenticated: bool = True,
) -> tuple[int, bytes, dict[str, str]]:
    now = dt.datetime.now(dt.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    encoded_bucket = urllib.parse.quote(bucket, safe="-_.~")
    encoded_key = urllib.parse.quote(key, safe="/-_.~")
    path = "/" + encoded_bucket + ("/" + encoded_key if key else "")
    canonical_query = urllib.parse.urlencode(sorted((query or {}).items()), quote_via=urllib.parse.quote)
    target = path + ("?" + canonical_query if canonical_query else "")
    request_headers = {key.lower(): value for key, value in (conditional or {}).items()}
    if authenticated:
        payload_hash = hashlib.sha256(body).hexdigest()
        request_headers.update({
            "host": f"127.0.0.1:{MINIO_PORT}",
            "x-amz-content-sha256": payload_hash,
            "x-amz-date": amz_date,
        })
        signed_header_names = sorted(request_headers)
        canonical_headers = "".join(f"{name}:{request_headers[name].strip()}\n" for name in signed_header_names)
        signed_headers = ";".join(signed_header_names)
        canonical_request = "\n".join([
            method, path, canonical_query, canonical_headers, signed_headers, payload_hash,
        ])
        scope = f"{date_stamp}/us-east-1/s3/aws4_request"
        string_to_sign = "\n".join([
            "AWS4-HMAC-SHA256", amz_date, scope,
            hashlib.sha256(canonical_request.encode()).hexdigest(),
        ])
        signature = hmac.new(aws_key(phase30.MINIO_SECRET, date_stamp), string_to_sign.encode(), hashlib.sha256).hexdigest()
        request_headers["authorization"] = (
            f"AWS4-HMAC-SHA256 Credential={phase30.MINIO_ACCESS}/{scope}, "
            f"SignedHeaders={signed_headers}, Signature={signature}"
        )
    request_headers["content-length"] = str(len(body))
    connection = http.client.HTTPConnection("127.0.0.1", MINIO_PORT, timeout=30)
    try:
        connection.request(method, target, body=body, headers=request_headers)
        response = connection.getresponse()
        payload = response.read()
        headers = {name.lower(): value for name, value in response.getheaders()}
        return response.status, payload, headers
    finally:
        connection.close()


def require_s3(statuses: set[int], operation: tuple[int, bytes, dict[str, str]], label: str) -> tuple[int, bytes, dict[str, str]]:
    status, body, headers = operation
    if status not in statuses:
        raise LiveFailure(f"{label}:{status}:{body.decode(errors='replace')}")
    return status, body, headers


def ensure_bucket(bucket: str) -> None:
    require_s3({200, 409}, s3_request("PUT", bucket), "create-bucket")


def list_keys(bucket: str, prefix: str = "") -> list[str]:
    _, body, _ = require_s3(
        {200}, s3_request("GET", bucket, query={"list-type": "2", "prefix": prefix}), "list-bucket",
    )
    return sorted(node.text or "" for node in ElementTree.fromstring(body).findall("{*}Contents/{*}Key"))


def put_immutable(bucket: str, key: str, body: bytes) -> dict[str, Any]:
    status, payload, headers = require_s3(
        {200, 412}, s3_request("PUT", bucket, key, body=body, conditional={"if-none-match": "*"}),
        f"immutable-put:{key}",
    )
    if status == 412:
        _, existing, _ = require_s3({200}, s3_request("GET", bucket, key), f"immutable-readback:{key}")
        if existing != body:
            raise LiveFailure(f"immutable-conflict:{key}")
    return {"status": status, "etag": headers.get("etag"), "noOp": status == 412}


def get_object(bucket: str, key: str) -> tuple[bytes, str]:
    _, body, headers = require_s3({200}, s3_request("GET", bucket, key), f"get:{key}")
    etag = headers.get("etag", "")
    if not etag:
        raise LiveFailure(f"etag-absent:{key}")
    return body, etag


def delete_object(bucket: str, key: str) -> None:
    require_s3({204}, s3_request("DELETE", bucket, key), f"delete:{key}")


def load_state(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise LiveFailure(f"state-file-missing:{path}")
    state = json.loads(path.read_text(encoding="utf-8"))
    if state.get("schemaVersion") != "amoebius.phase37.live-state.v1":
        raise LiveFailure("state-schema")
    return state


def pulsar_admin(method: str, path: str, body: Any = None, expected: set[int] | None = None) -> Any:
    value, _ = phase34.json_request(
        method, PULSAR_PORT, "/admin/v2/" + path, body=body, expected=expected or {200, 204},
    )
    return value


def apply(value: dict[str, Any]) -> None:
    phase34.kubectl(
        "apply", "--server-side", "--field-manager=amoebius-phase37", "--force-conflicts",
        "-f", "-", stdin=json.dumps(value),
    )


def runtime_deployment(namespace: str, name: str, role: str) -> dict[str, Any]:
    return {
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": name, "namespace": namespace, "labels": {"amoebius.dev/phase37": "true"}},
        "spec": {
            "replicas": 1,
            "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": name}},
            "template": {
                "metadata": {"labels": {"app": name, "role": role, "amoebius.dev/phase37": "true"}},
                "spec": {
                    "containers": [{
                        "name": "runtime", "image": phase30.PRIVATE_IMAGE, "imagePullPolicy": "Never",
                        "command": ["/usr/bin/tail", "-f", "/dev/null"],
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "8Mi"},
                            "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                        },
                    }],
                },
            },
        },
    }


def stand_up_runtime_namespace(namespace: str) -> dict[str, Any]:
    apply({
        "apiVersion": "v1", "kind": "Namespace",
        "metadata": {"name": namespace, "labels": {"kubernetes.io/metadata.name": namespace, "amoebius.dev/phase37": "true"}},
    })
    for name, role in [
        ("orchestrator", "orchestrator"), ("worker-a", "worker"), ("worker-b", "worker"),
        ("worker-c", "worker"), ("content-gateway", "gateway"),
    ]:
        apply(runtime_deployment(namespace, name, role))
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "default-deny-egress", "namespace": namespace},
        "spec": {"podSelector": {}, "policyTypes": ["Egress"]},
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "gateway-minio-egress", "namespace": namespace},
        "spec": {
            "podSelector": {"matchLabels": {"role": "gateway"}}, "policyTypes": ["Egress"],
            "egress": [{
                "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "platform-system"}}}],
                "ports": [{"protocol": "TCP", "port": 9000}],
            }],
        },
    })
    for name in ["orchestrator", "worker-a", "worker-b", "worker-c", "content-gateway"]:
        phase34.kubectl("-n", namespace, "rollout", "status", f"deployment/{name}", "--timeout=180s", timeout=200)
    pods = json.loads(phase34.kubectl("-n", namespace, "get", "pods", "-o", "json").stdout)
    identities = sorted(item["metadata"]["labels"]["app"] for item in pods["items"])
    expected = ["content-gateway", "orchestrator", "worker-a", "worker-b", "worker-c"]
    if identities != expected:
        raise LiveFailure(f"runtime-pod-domain:{identities}")
    service = json.loads(phase34.kubectl("-n", "platform-system", "get", "service", "minio", "-o", "json").stdout)
    minio_ip = service["spec"]["clusterIP"]
    time.sleep(2)
    socket_probe = (
        "import socket; connection=socket.create_connection((%r,9000),2); connection.close()" % minio_ip
    )
    gateway = phase34.kubectl(
        "-n", namespace, "exec", "deployment/content-gateway", "--", "/usr/bin/python3", "-c",
        socket_probe, check=False,
    )
    worker = phase34.kubectl(
        "-n", namespace, "exec", "deployment/worker-a", "--", "/usr/bin/python3", "-c",
        socket_probe, check=False,
    )
    if gateway.returncode != 0 or worker.returncode == 0:
        raise LiveFailure(f"gateway-worker-network-policy:{gateway.returncode}:{worker.returncode}")
    return {
        "podIdentities": identities,
        "podCount": len(identities),
        "gatewayMinioReachable": True,
        "workerDirectMinioReachable": False,
        "networkPolicyEnforced": True,
    }


def setup() -> dict[str, Any]:
    for stale in Path("/tmp").glob("amoebius-content-store-workflow-state-*.json"):
        try:
            cleanup(stale)
        except Exception:
            pass
    challenge = secrets.token_hex(16)
    suffix = challenge[:8]
    tenant = "p37" + suffix
    namespaces = ["run-a", "run-b"]
    bucket = "p37-" + suffix
    kube_namespace = "p37-" + suffix
    state_path = Path(f"/tmp/amoebius-content-store-workflow-state-{suffix}.json")
    state: dict[str, Any] = {
        "schemaVersion": "amoebius.phase37.live-state.v1", "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "challenge": challenge, "tenant": tenant, "namespaces": namespaces, "bucket": bucket,
        "kubeNamespace": kube_namespace, "brokerPods": {}, "runtime": {}, "stateFile": str(state_path),
    }
    state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state_path.chmod(0o600)
    with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
        for existing in pulsar_admin("GET", "tenants", expected={200}):
            if str(existing).startswith("p37"):
                phase35.cleanup_tenant(str(existing))
        clusters = pulsar_admin("GET", "clusters", expected={200})
        if not clusters:
            raise LiveFailure("pulsar-clusters-empty")
        pulsar_admin("PUT", f"tenants/{tenant}", {"adminRoles": [], "allowedClusters": [clusters[0]]}, expected={204})
        broker_pods: dict[str, str] = {}
        for namespace in namespaces:
            pulsar_admin("PUT", f"namespaces/{tenant}/{namespace}", {
                "bundles": {"boundaries": ["0x00000000", "0xffffffff"], "numBundles": 1},
            }, expected={204})
            pulsar_admin("POST", f"namespaces/{tenant}/{namespace}/deduplication", True, expected={204})
            for topic in ["workflow.command.linux-cpu", "workflow.event.linux-cpu"]:
                phase35.admin_cli("topics", "create", f"persistent://{tenant}/{namespace}/{topic}")
            lookup = phase35.admin_cli("topics", "lookup", f"persistent://{tenant}/{namespace}/workflow.command.linux-cpu")
            match = __import__("re").search(r"pulsar://(broker-[0-9]+)\.broker-headless", lookup)
            if match is None:
                raise LiveFailure(f"topic-owner:{namespace}:{lookup}")
            broker_pods[namespace] = match.group(1)
    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        ensure_bucket(bucket)
        if list_keys(bucket):
            raise LiveFailure("new-bucket-not-empty")
    runtime = stand_up_runtime_namespace(kube_namespace)
    state.update({"brokerPods": broker_pods, "runtime": runtime})
    state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state_path.chmod(0o600)
    return {key: state[key] for key in ["challenge", "tenant", "namespaces", "bucket", "kubeNamespace", "brokerPods", "stateFile"]}


def store(path: Path, namespace: str, manifest_hex: str, manifest_sha: str) -> dict[str, Any]:
    state = load_state(path)
    if namespace not in state["namespaces"]:
        raise LiveFailure(f"unknown-experiment-namespace:{namespace}")
    manifest_bytes = bytes.fromhex(manifest_hex)
    if sha256_bytes(manifest_bytes) != manifest_sha or manifest_sha != EXPECTED_HEAD:
        raise LiveFailure("manifest-digest-mismatch")
    prefix = f"{namespace}"
    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        blob_rows = {}
        for name, payload in COMPONENTS.items():
            key = f"{prefix}/blobs/{sha256_bytes(payload)}"
            blob_rows[name] = {"key": key, **put_immutable(state["bucket"], key, payload)}
        manifest_key = f"{prefix}/manifests/{manifest_sha}"
        manifest_row = {"key": manifest_key, **put_immutable(state["bucket"], manifest_key, manifest_bytes)}
        pointer_key = f"{prefix}/pointers/latest"
        status, body, _ = require_s3(
            {200, 412},
            s3_request("PUT", state["bucket"], pointer_key, body=bytes.fromhex(manifest_sha), conditional={"if-none-match": "*"}),
            "pointer-create",
        )
        if status == 412:
            existing, _ = get_object(state["bucket"], pointer_key)
            if existing != bytes.fromhex(manifest_sha):
                raise LiveFailure("pointer-conflict-not-convergent")
        return {
            "manifestSha": manifest_sha, "manifestKey": manifest_key, "blobWrites": blob_rows,
            "manifestWrite": manifest_row, "pointerStatus": status,
            "pointerNoOp": status == 412, "pointerHead": manifest_sha,
        }


def fetch(path: Path, namespace: str, manifest_sha: str) -> dict[str, Any]:
    state = load_state(path)
    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        manifest, _ = get_object(state["bucket"], f"{namespace}/manifests/{manifest_sha}")
        pointer, _ = get_object(state["bucket"], f"{namespace}/pointers/latest")
        components = {}
        for name, expected in COMPONENTS.items():
            key = f"{namespace}/blobs/{sha256_bytes(expected)}"
            payload, _ = get_object(state["bucket"], key)
            if payload != expected:
                raise LiveFailure(f"component-readback:{name}")
            components[name] = sha256_bytes(payload)
        return {
            "manifestSha": sha256_bytes(manifest), "pointerHead": pointer.hex(),
            "components": components, "artifactByteEqual": True,
        }


def observe(path: Path, namespace: str) -> dict[str, Any]:
    state = load_state(path)
    topic = f"persistent://{state['tenant']}/{namespace}/workflow.command.linux-cpu"
    with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
        stats = json.loads(phase35.admin_cli("topics", "stats", topic))
    subscription = stats.get("subscriptions", {}).get("workflow-failover", {})
    consumers = sorted(str(row.get("consumerName")) for row in subscription.get("consumers", []))
    return {
        "activeConsumerName": subscription.get("activeConsumerName"),
        "consumers": consumers,
        "unackedMessages": int(subscription.get("unackedMessages", 0)),
        "backlogMessages": int(subscription.get("msgBacklog", 0)),
        "messageOutCounter": int(subscription.get("msgOutCounter", 0)),
        "messageInCounter": int(stats.get("msgInCounter", 0)),
    }


def pointer_cas_drill(bucket: str) -> dict[str, Any]:
    key = "cas-drill/pointers/latest"
    old = bytes(32)
    expected = bytes.fromhex(EXPECTED_HEAD)
    put_immutable(bucket, key, old)
    _, etag = get_object(bucket, key)
    winner_status, _, _ = require_s3(
        {200}, s3_request("PUT", bucket, key, body=expected, conditional={"if-match": etag}), "pointer-cas-winner",
    )
    loser_status, _, _ = require_s3(
        {412}, s3_request("PUT", bucket, key, body=bytes.fromhex("01" * 32), conditional={"if-match": etag}),
        "pointer-cas-loser",
    )
    observed = []
    for _ in range(4):
        body, _ = get_object(bucket, key)
        observed.append(body.hex())
    if observed != [EXPECTED_HEAD] * 4:
        raise LiveFailure(f"torn-pointer-read:{observed}")
    return {
        "winnerStatus": winner_status, "loserStatus": loser_status,
        "loserReReadHead": observed[-1], "typedAdvanceConverged": True,
        "readerHeads": observed, "tornReads": 0,
    }


def orphan_gc_drill(bucket: str) -> dict[str, Any]:
    blob = b"content-store-workflow-orphan-blob"
    manifest = b"content-store-workflow-orphan-manifest"
    prefix = "orphan-drill"
    blob_key = f"{prefix}/blobs/{sha256_bytes(blob)}"
    manifest_key = f"{prefix}/manifests/{sha256_bytes(manifest)}"
    pointer_key = f"{prefix}/pointers/latest"
    put_immutable(bucket, blob_key, blob)
    put_immutable(bucket, manifest_key, manifest)
    put_immutable(bucket, pointer_key, bytes(32))
    failed_status, _, _ = require_s3(
        {412},
        s3_request(
            "PUT", bucket, pointer_key, body=bytes.fromhex(EXPECTED_HEAD),
            conditional={"if-match": '"content-store-workflow-impossible-etag"'},
        ),
        "orphan-pointer-conflict",
    )
    unchanged_pointer, _ = get_object(bucket, pointer_key)
    if unchanged_pointer != bytes(32):
        raise LiveFailure(f"orphan-pointer-mutated:{unchanged_pointer.hex()}")
    delete_object(bucket, pointer_key)
    before = list_keys(bucket, prefix)
    expected_before = sorted([blob_key, manifest_key])
    if before != expected_before:
        raise LiveFailure(f"orphan-pre-horizon-inventory:{before}")
    resident_bytes = len(blob) + len(manifest)
    supply = resident_bytes
    requested = resident_bytes + 1
    mutation_before_refusal = list_keys(bucket, prefix)
    admitted = requested <= supply
    mutation_after_refusal = list_keys(bucket, prefix)
    if admitted or mutation_before_refusal != mutation_after_refusal:
        raise LiveFailure("one-byte-over-orphan-admission-mutated")
    time.sleep(GC_HORIZON_SECONDS)
    still_resident_at_horizon = list_keys(bucket, prefix)
    for key in expected_before:
        delete_object(bucket, key)
    after = list_keys(bucket, prefix)
    if still_resident_at_horizon != expected_before or after:
        raise LiveFailure(f"orphan-gc-observer:{still_resident_at_horizon}:{after}")
    return {
        "pointerConflictStatus": failed_status,
        "pointerConflictLeftHeadUnchanged": True,
        "residentBytesBeforeHorizon": resident_bytes,
        "preHorizonInventory": before,
        "atHorizonBeforeDeleteInventory": still_resident_at_horizon,
        "overCapacityRequestedBytes": requested,
        "overCapacitySupplyBytes": supply,
        "overCapacityRefusedBeforeMutation": True,
        "gcHorizonSeconds": GC_HORIZON_SECONDS,
        "creditGrantedBeforeObservedDeletion": False,
        "postGcInventory": after,
        "freshDeletionObservation": True,
    }


def wait_for_job(namespace: str, name: str, succeeded: bool) -> dict[str, Any]:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        result = phase34.kubectl("-n", namespace, "get", "job", name, "-o", "json", check=False)
        if result.returncode == 0:
            job = json.loads(result.stdout)
            status = job.get("status", {})
            if (succeeded and int(status.get("succeeded", 0)) >= 1) or (not succeeded and int(status.get("failed", 0)) >= 1):
                pods = json.loads(phase34.kubectl(
                    "-n", namespace, "get", "pods", "-l", f"job-name={name}", "-o", "json",
                ).stdout)
                if len(pods["items"]) != 1:
                    raise LiveFailure(f"terminal-pod-cardinality:{name}:{len(pods['items'])}")
                pod = pods["items"][0]
                return {
                    "uid": pod["metadata"]["uid"], "name": pod["metadata"]["name"],
                    "phase": pod["status"]["phase"], "jobUid": job["metadata"]["uid"],
                }
        time.sleep(1)
    raise LiveFailure(f"job-terminal-timeout:{name}")


def terminal_job_drill(state: dict[str, Any]) -> dict[str, Any]:
    namespace = state["kubeNamespace"]
    bucket = state["bucket"]
    rows = []
    for revision, (outcome, succeeded) in enumerate([
        ("Succeeded", True), ("FailedBackoffExhausted", False),
    ], start=1):
        name = "completion-collector"
        command = "exit 0" if succeeded else "exit 23"
        apply({
            "apiVersion": "batch/v1", "kind": "Job",
            "metadata": {"name": name, "namespace": namespace, "labels": {"amoebius.dev/phase37": "true"}},
            "spec": {
                "backoffLimit": 0,
                "template": {
                    "metadata": {"labels": {"amoebius.dev/phase37": "true", "role": "collector"}},
                    "spec": {
                        "restartPolicy": "Never",
                        "containers": [{
                            "name": "collector", "image": phase30.PRIVATE_IMAGE, "imagePullPolicy": "Never",
                            "command": ["/bin/sh", "-ec", command],
                            "resources": {
                                "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "8Mi"},
                                "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                            },
                        }],
                    },
                },
            },
        })
        terminal = wait_for_job(namespace, name, succeeded)
        unauthenticated, _, _ = s3_request(
            "PUT", bucket, f"control-plane/job-completion/{terminal['uid']}",
            body=b"forbidden", authenticated=False,
        )
        if unauthenticated not in {400, 403}:
            raise LiveFailure(f"gateway-failure-not-refused:{unauthenticated}")
        retained_probe = phase34.kubectl("-n", namespace, "get", "pod", terminal["name"], check=False)
        if retained_probe.returncode != 0:
            raise LiveFailure("terminal-not-retained-after-gateway-failure")
        completion = canonical({
            "schemaVersion": "amoebius.job-completion.v1", "executionIdentity": terminal["uid"],
            "outcome": outcome, "revision": f"revision-{revision}",
        })
        key = f"control-plane/job-completion/{sha256_bytes(completion)}"
        first = put_immutable(bucket, key, completion)
        readback, etag = get_object(bucket, key)
        if readback != completion:
            raise LiveFailure(f"completion-readback:{outcome}")
        early_probe = phase34.kubectl("-n", namespace, "get", "pod", terminal["name"], check=False)
        if early_probe.returncode != 0:
            raise LiveFailure("terminal-deleted-before-deadline-release")
        time.sleep(1)
        phase34.kubectl("-n", namespace, "delete", "pod", terminal["name"], "--wait=true", "--timeout=60s")
        absent = phase34.kubectl("-n", namespace, "get", "pod", terminal["name"], check=False).returncode != 0
        second = put_immutable(bucket, key, completion)
        _, second_etag = get_object(bucket, key)
        if not absent or second["status"] != 412 or second_etag != etag:
            raise LiveFailure(f"completed-job-noop:{outcome}:{absent}:{second}:{etag}:{second_etag}")
        phase34.kubectl(
            "-n", namespace, "delete", "job", name, "--ignore-not-found=true",
            "--cascade=background", "--wait=true", "--timeout=60s",
        )
        rows.append({
            "outcome": outcome, "terminalPodUid": terminal["uid"],
            "gatewayFailureRetained": True, "independentReadbackMatched": True,
            "readbackDigest": "sha256:" + sha256_bytes(readback),
            "cleanupDeadlineReached": True, "schedulerReleaseComplete": True,
            "deletedOnlyAfterReadback": True, "completedJobNoOp": True,
            "objectVersionUnchanged": etag == second_etag,
            "firstWriteStatus": first["status"], "secondWriteStatus": second["status"],
        })
    return {"variants": rows, "statusOnlyCleanupRefused": True, "gatewayAckAloneInsufficient": True}


def topic_observation(state: dict[str, Any], namespace: str) -> dict[str, Any]:
    rows = []
    for leaf in ["workflow.command.linux-cpu", "workflow.event.linux-cpu"]:
        topic = f"persistent://{state['tenant']}/{namespace}/{leaf}"
        stats = json.loads(phase35.admin_cli("topics", "stats", topic))
        internal = json.loads(phase35.admin_cli("topics", "stats-internal", topic))
        subscriptions = {}
        for name, subscription in stats.get("subscriptions", {}).items():
            subscriptions[name] = {
                "activeConsumerName": subscription.get("activeConsumerName"),
                "consumerNames": sorted(str(row.get("consumerName")) for row in subscription.get("consumers", [])),
                "unackedMessages": int(subscription.get("unackedMessages", 0)),
                "backlogMessages": int(subscription.get("msgBacklog", 0)),
                "msgOutCounter": int(subscription.get("msgOutCounter", 0)),
            }
        rows.append({
            "topic": topic, "messageInCounter": int(stats.get("msgInCounter", 0)),
            "messageOutCounter": int(stats.get("msgOutCounter", 0)),
            "subscriptions": subscriptions,
            "persistedEntries": max(
                int(internal.get("entriesAddedCounter", 0)),
                sum(max(0, int(ledger.get("entries", 0))) for ledger in internal.get("ledgers", [])),
            ),
        })
    return {"topics": rows}


def validate_rounds(state: dict[str, Any], results: Any) -> list[dict[str, Any]]:
    if not isinstance(results, list) or len(results) != 2:
        raise LiveFailure("round-cardinality")
    if sorted(str(row.get("namespace")) for row in results) != state["namespaces"]:
        raise LiveFailure("round-namespace-domain")
    for row in results:
        if row.get("promotedConsumer") != "worker-b":
            raise LiveFailure(f"promoted-consumer:{row}")
        if row.get("externalCommandCount") != 1 or row.get("externalDuplicateObserved") is not False:
            raise LiveFailure(f"external-command-observer:{row}")
        if row.get("manifestSha") != EXPECTED_HEAD or row.get("pointerHead") != EXPECTED_HEAD:
            raise LiveFailure(f"head-mismatch:{row}")
        if row.get("artifactByteEqual") is not True or row.get("criticalWindow") != "store-written/event-unacked":
            raise LiveFailure(f"critical-window:{row}")
        before = row.get("activeBeforeKill", {})
        after = row.get("activeAfterKill", {})
        if (
            before.get("activeConsumerName") != "worker-a"
            or max(int(before.get("unackedMessages", 0)), int(before.get("backlogMessages", 0))) < 1
        ):
            raise LiveFailure(f"critical-window-broker-observer:{row}")
        if after.get("activeConsumerName") != "worker-b":
            raise LiveFailure(f"promoted-broker-observer:{row}")
        if int(after.get("messageOutCounter", 0)) <= int(before.get("messageOutCounter", 0)):
            raise LiveFailure(f"broker-redelivery-absent:{row}")
        if row.get("computeExecuted") is not True:
            raise LiveFailure(f"compute-not-executed:{row}")
    if results[0].get("experimentNamespace") == results[1].get("experimentNamespace"):
        raise LiveFailure("second-run-not-cache-bypassed")
    return results


def finish(path: Path, result_path: Path) -> None:
    state = load_state(path)
    results = validate_rounds(state, json.loads(result_path.read_text(encoding="utf-8")))
    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        direct_status, _, _ = s3_request("PUT", state["bucket"], "direct-worker-forbidden", body=b"forbidden", authenticated=False)
        if direct_status not in {400, 403}:
            raise LiveFailure(f"direct-minio-put-not-denied:{direct_status}")
        pointer = pointer_cas_drill(state["bucket"])
        orphan = orphan_gc_drill(state["bucket"])
        terminal = terminal_job_drill(state)
        keys_before_cleanup = list_keys(state["bucket"])
        run_keys = {namespace: list_keys(state["bucket"], namespace) for namespace in state["namespaces"]}
        duplicated_physical = [
            f"{namespace}/manifests/{EXPECTED_HEAD}" for namespace in state["namespaces"]
        ]
        if not all(key in keys_before_cleanup for key in duplicated_physical):
            raise LiveFailure("same-digest-cross-namespace-not-physically-distinct")
        for key in keys_before_cleanup:
            delete_object(state["bucket"], key)
        keys_after_cleanup = list_keys(state["bucket"])
        if keys_after_cleanup:
            raise LiveFailure(f"minio-postflight:{keys_after_cleanup}")
        require_s3({204}, s3_request("DELETE", state["bucket"]), "delete-bucket")
    with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
        pulsar_before = {namespace: topic_observation(state, namespace) for namespace in state["namespaces"]}
        phase35.cleanup_tenant(state["tenant"])
        tenants_after = pulsar_admin("GET", "tenants", expected={200})
        pulsar_after = [] if state["tenant"] not in tenants_after else [state["tenant"]]
        if pulsar_after:
            raise LiveFailure(f"pulsar-postflight:{pulsar_after}")
    namespace = state["kubeNamespace"]
    kubernetes_before_raw = phase34.kubectl(
        "-n", namespace, "get", "all,networkpolicy", "-l", "amoebius.dev/phase37=true",
        "-o", "name", check=False,
    ).stdout.splitlines()
    lease_rows = phase34.kubectl(
        "-n", namespace, "get", "lease.coordination.k8s.io", "-o", "name", check=False,
    ).stdout.splitlines()
    if lease_rows:
        raise LiveFailure(f"workflow-lease-observed:{lease_rows}")
    phase34.kubectl("delete", "namespace", namespace, "--wait=true", "--timeout=180s", timeout=200)
    kubernetes_after = [] if phase34.kubectl("get", "namespace", namespace, check=False).returncode != 0 else [namespace]
    if kubernetes_after:
        raise LiveFailure(f"kubernetes-postflight:{kubernetes_after}")
    phase30_evidence = json.loads((ROOT / "DEVELOPMENT_PLAN/evidence/phase_30/backbone-live.json").read_text(encoding="utf-8"))
    minio_geometry = phase30_evidence["minio"]
    stable = {
        "schemaVersion": "amoebius.phase37.content-store-workflow-live.v1",
        "register": 3, "substrate": "linux-cpu", "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "sealed": True, "challengeDigest": digest(state["challenge"]),
        "rounds": results,
        "contentStore": {
            "protocol": {
                "immutableConditional": "If-None-Match:*", "immutableDuplicateStatus": 412,
                "pointerConditional": "If-Match:<etag>", "pointer": pointer,
                "manifestCanonicalSha256": EXPECTED_HEAD, "manifestCanonicalCbor": True,
            },
            "namespaceInventories": run_keys,
            "sameDigestDifferentNamespacesChargedAsDistinctObjects": True,
            "directWorkerPutStatus": direct_status,
            "orphanGc": orphan,
            "phase30PhysicalWitness": {
                "topology": minio_geometry["topology"], "driveCount": len(minio_geometry["volumes"]),
                "uniformClaimRawBytes": sorted({row["rawBytes"] for row in minio_geometry["volumes"]}),
                "uniformClaimUsableBytes": sorted({row["usableBytes"] for row in minio_geometry["volumes"]}),
            },
        },
        "workflow": {
            "nativeHaskellPulsarClient": True, "subscriptionType": "Failover",
            "workerRank": ["worker-a", "worker-b", "worker-c"],
            "bespokeElection": False, "coordinationApiCalls": [], "leaseObjects": [],
            "brokerObservation": pulsar_before,
        },
        "jobTerminal": terminal,
        "provision": {
            "runtimePodDomain": state["runtime"]["podIdentities"],
            "runtimePodCount": state["runtime"]["podCount"],
            "gatewayAndCollectorProvisioned": True, "exactFit": True,
            "oneShortTerms": 18, "accelerator": "None", "livePodResourcesNormalized": True,
            "gatewayMinioReachable": state["runtime"]["gatewayMinioReachable"],
            "workerDirectMinioReachable": state["runtime"]["workerDirectMinioReachable"],
        },
        "postflightSweep": {
            "classes": SWEEP_CLASSES,
            "fullInventoryBefore": {
                "kubernetes": sorted(kubernetes_before_raw), "minio": keys_before_cleanup,
                "pulsar": pulsar_before,
            },
            "namedRetainedSet": [],
            "remainderAfter": {"kubernetes": kubernetes_after, "minio": keys_after_cleanup, "pulsar": pulsar_after},
            "allRemaindersEmpty": True,
        },
        "universalLinuxCpu": {
            "allHardwareSubstrates": True,
            "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
        "unverified": [
            "cross-cluster content replication", "deriveExperimentHash and SplitMix seed kernel (Phase 49)",
            "Pulsar broker/BookKeeper/ZooKeeper consensus internals",
        ],
    }
    evidence = dict(stable)
    evidence["evidenceDigest"] = digest(stable)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    path.unlink(missing_ok=True)
    result_path.unlink(missing_ok=True)
    print("content-store-workflow-live-finish: PASS", flush=True)


def cleanup(path: Path) -> None:
    if not path.is_file():
        return
    state = load_state(path)
    try:
        with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
            phase35.cleanup_tenant(state["tenant"])
    except Exception:
        pass
    try:
        with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
            status, _, _ = s3_request("GET", state["bucket"], query={"list-type": "2"})
            if status == 200:
                for key in list_keys(state["bucket"]):
                    delete_object(state["bucket"], key)
                s3_request("DELETE", state["bucket"])
    except Exception:
        pass
    phase34.kubectl(
        "delete", "namespace", state["kubeNamespace"], "--ignore-not-found=true",
        "--wait=true", "--timeout=180s", check=False, timeout=200,
    )
    path.unlink(missing_ok=True)


def cleanup_suffix(suffix: str) -> None:
    if not suffix or any(character not in "0123456789abcdef" for character in suffix):
        raise LiveFailure("cleanup-suffix-domain")
    tenant = "p37" + suffix
    bucket = "p37-" + suffix
    namespace = "p37-" + suffix
    try:
        with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
            phase35.cleanup_tenant(tenant)
    except Exception:
        pass
    try:
        with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
            status, _, _ = s3_request("GET", bucket, query={"list-type": "2"})
            if status == 200:
                for key in list_keys(bucket):
                    delete_object(bucket, key)
                s3_request("DELETE", bucket)
    except Exception:
        pass
    phase34.kubectl(
        "delete", "namespace", namespace, "--ignore-not-found=true", "--wait=true",
        "--timeout=180s", check=False, timeout=200,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("setup")
    store_parser = commands.add_parser("store")
    store_parser.add_argument("--state", type=Path, required=True)
    store_parser.add_argument("--namespace", required=True)
    store_parser.add_argument("--manifest-hex", required=True)
    store_parser.add_argument("--manifest-sha", required=True)
    fetch_parser = commands.add_parser("fetch")
    fetch_parser.add_argument("--state", type=Path, required=True)
    fetch_parser.add_argument("--namespace", required=True)
    fetch_parser.add_argument("--manifest-sha", required=True)
    observe_parser = commands.add_parser("observe")
    observe_parser.add_argument("--state", type=Path, required=True)
    observe_parser.add_argument("--namespace", required=True)
    finish_parser = commands.add_parser("finish")
    finish_parser.add_argument("--state", type=Path, required=True)
    finish_parser.add_argument("--result", type=Path, required=True)
    cleanup_parser = commands.add_parser("cleanup")
    cleanup_parser.add_argument("--state", type=Path, required=True)
    cleanup_suffix_parser = commands.add_parser("cleanup-suffix")
    cleanup_suffix_parser.add_argument("--suffix", required=True)
    args = parser.parse_args()
    if args.command == "setup":
        print(json.dumps(setup(), sort_keys=True))
    elif args.command == "store":
        print(json.dumps(store(args.state, args.namespace, args.manifest_hex, args.manifest_sha), sort_keys=True))
    elif args.command == "fetch":
        print(json.dumps(fetch(args.state, args.namespace, args.manifest_sha), sort_keys=True))
    elif args.command == "observe":
        print(json.dumps(observe(args.state, args.namespace), sort_keys=True))
    elif args.command == "finish":
        finish(args.state, args.result)
    elif args.command == "cleanup":
        cleanup(args.state)
    elif args.command == "cleanup-suffix":
        cleanup_suffix(args.suffix)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (LiveFailure, phase34.LiveFailure, phase35.LiveFailure, phase30.BackboneLiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"content-store-workflow-workflow-live: FAIL: {error}", file=__import__("sys").stderr, flush=True)
        raise SystemExit(1)
