#!/usr/bin/env python3
"""Effect helper for the in-cluster Haskell Phase-33 singleton.

All authority comes from the projected ServiceAccount token or from unlock
material supplied on stdin.  No password, root token, or MinIO credential is
accepted through argv or the environment.
"""

from __future__ import annotations

import base64
import datetime as dt
import hashlib
import hmac
import http.client
import json
import re
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


NAMESPACE = "phase33-system"
LEASE_NAME = "amoebius-reconciler"
SERVICE_ACCOUNT = "amoebius-control-plane"
TOKEN_PATH = Path("/var/run/secrets/kubernetes.io/serviceaccount/token")
CA_PATH = Path("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
UNLOCK_PATH = Path("/var/lib/amoebius/phase29-unlock.age")
AMOEBIUS = "/phase33-artifacts/amoebius"
VAULT_HOST = "root-vault.vault-system.svc.cluster.local"
MINIO_HOST = "minio.platform-system.svc.cluster.local"
MINIO_BUCKET = "amoebius-control-plane"
MINIO_KEY = "state/in-force-spec.json"
PRIVATE_IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
FIELD_MANAGER = "amoebius-phase33-singleton"
ENACT_ORDER = [
    "ConfigMap/edge-system/phase32-envoy",
    "Deployment/edge-system/envoy",
    "Deployment/observability/prometheus-query-proxy",
    "Deployment/edge-system/phase33-trivial",
    "HTTPRoute/edge-system/phase33-trivial",
    "Service/observability/prometheus-query-proxy",
    "Service/edge-system/phase33-trivial",
]


class HelperError(RuntimeError):
    pass


def stdin_json() -> dict[str, Any]:
    try:
        value = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError) as problem:
        raise HelperError("admin-json-invalid") from problem
    if not isinstance(value, dict):
        raise HelperError("admin-json-not-object")
    return value


def kubernetes_request(method: str, path: str, payload: Any | None = None, *, content_type: str = "application/json") -> tuple[int, Any]:
    token = TOKEN_PATH.read_text(encoding="utf-8").strip()
    data = None if payload is None else json.dumps(payload, separators=(",", ":")).encode()
    request = urllib.request.Request(
        "https://kubernetes.default.svc" + path,
        data=data,
        method=method,
        headers={"Authorization": "Bearer " + token, "Accept": "application/json", "Content-Type": content_type},
    )
    context = ssl.create_default_context(cafile=str(CA_PATH))
    try:
        with urllib.request.urlopen(request, context=context, timeout=30) as response:
            body = response.read()
            return response.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as problem:
        body = problem.read()
        parsed = json.loads(body) if body else {}
        return problem.code, parsed


def require_kubernetes(method: str, path: str, payload: Any | None = None, *, content_type: str = "application/json", expected: set[int] = {200, 201}) -> Any:
    status, body = kubernetes_request(method, path, payload, content_type=content_type)
    if status not in expected:
        raise HelperError(f"kubernetes-{method.lower()}-{status}:{body}")
    return body


def lease_path() -> str:
    return f"/apis/coordination.k8s.io/v1/namespaces/{NAMESPACE}/leases/{LEASE_NAME}"


def lease_acquire(pod_uid: str) -> dict[str, Any]:
    observed = require_kubernetes("GET", lease_path())
    holder = observed.get("spec", {}).get("holderIdentity")
    release_observed = observed.get("metadata", {}).get("annotations", {}).get("amoebius.io/release-observed") == "true"
    if holder is None and not release_observed:
        raise HelperError("lease-release-not-yet-observed")
    if holder not in (None, pod_uid):
        renew_raw = observed.get("spec", {}).get("renewTime")
        duration = int(observed.get("spec", {}).get("leaseDurationSeconds", 10))
        try:
            renewed = dt.datetime.fromisoformat(str(renew_raw).replace("Z", "+00:00"))
        except ValueError as problem:
            raise HelperError("lease-held-by-other") from problem
        if dt.datetime.now(dt.timezone.utc) <= renewed + dt.timedelta(seconds=duration):
            raise HelperError("lease-held-by-other")
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    patch = {
        "metadata": {"resourceVersion": observed["metadata"]["resourceVersion"]},
        "spec": {
            "holderIdentity": pod_uid,
            "leaseDurationSeconds": 10,
            "acquireTime": observed.get("spec", {}).get("acquireTime", now),
            "renewTime": now,
            "leaseTransitions": int(observed.get("spec", {}).get("leaseTransitions", 0)) + (0 if holder == pod_uid else 1),
        },
    }
    successor = require_kubernetes("PATCH", lease_path(), patch, content_type="application/merge-patch+json")
    if successor.get("spec", {}).get("holderIdentity") != pod_uid:
        raise HelperError("lease-acquire-readback-mismatch")
    return {
        "holder": pod_uid,
        "uid": successor["metadata"]["uid"],
        "resourceVersion": successor["metadata"]["resourceVersion"],
    }


def open_material(password: str) -> dict[str, str]:
    if not password:
        raise HelperError("operator-password-required")
    process = subprocess.run(
        [AMOEBIUS, "vault-open-unlock"],
        input=password.encode() + b"\n" + UNLOCK_PATH.read_bytes(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=120,
    )
    if process.returncode:
        raise HelperError("operator-password-invalid")
    try:
        material = json.loads(process.stdout)
    except json.JSONDecodeError as problem:
        raise HelperError("unlock-material-invalid") from problem
    if set(material) != {"unseal_key", "root_token"}:
        raise HelperError("unlock-material-shape")
    return material


def vault_request(method: str, path: str, token: str | None = None, payload: Any | None = None, *, expected: set[int] = {200, 204}) -> Any:
    body = None if payload is None else json.dumps(payload, separators=(",", ":")).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["X-Vault-Token"] = token
    connection = http.client.HTTPConnection(VAULT_HOST, 8200, timeout=30)
    connection.request(method, "/v1/" + path.lstrip("/"), body=body, headers=headers)
    response = connection.getresponse()
    raw = response.read()
    connection.close()
    parsed = json.loads(raw) if raw else {}
    if response.status not in expected:
        raise HelperError(f"vault-{method.lower()}-{response.status}:{path}")
    return parsed


def vault_init(request: dict[str, Any]) -> dict[str, Any]:
    open_material(str(request.get("password", "")))
    status = vault_request("GET", "sys/init", expected={200})
    if status.get("initialized") is not True:
        raise HelperError("vault-uninitialized-requires-first-init-ceremony")
    return {"result": "already-initialized", "vaultContacts": 1}


def vault_unseal(request: dict[str, Any]) -> dict[str, Any]:
    material = open_material(str(request.get("password", "")))
    status = vault_request("GET", "sys/seal-status", expected={200})
    contacts = 1
    if status.get("sealed"):
        status = vault_request("PUT", "sys/unseal", payload={"key": material["unseal_key"]}, expected={200})
        contacts += 1
    if status.get("sealed"):
        raise HelperError("vault-remained-sealed")
    return {"result": "unsealed", "alreadyUnsealed": contacts == 1, "vaultContacts": contacts}


def kv_operation(request: dict[str, Any]) -> dict[str, Any]:
    token = open_material(str(request.get("password", "")))["root_token"]
    verb = str(request.get("verb", ""))
    name = str(request.get("name", ""))
    if verb not in {"put", "get", "list", "delete"}:
        raise HelperError("kv-verb-invalid")
    if verb != "list" and not re.fullmatch(r"[A-Za-z0-9_.-]+", name):
        raise HelperError("kv-name-invalid")
    path = "secret/data/amoebius/admin/" + urllib.parse.quote(name, safe="")
    if verb == "put":
        vault_request("POST", path, token, {"data": {"value": str(request.get("value", ""))}})
        return {"result": "stored", "name": name}
    if verb == "get":
        result = vault_request("GET", path, token, expected={200})
        return {"result": "read", "name": name, "value": result["data"]["data"]["value"]}
    if verb == "delete":
        vault_request("DELETE", path, token, expected={204})
        return {"result": "deleted", "name": name}
    listed = vault_request("LIST", "secret/metadata/amoebius/admin", token, expected={200, 404})
    return {"result": "listed", "names": listed.get("data", {}).get("keys", [])}


def transit_encrypt(token: str, plaintext: bytes) -> str:
    result = vault_request(
        "POST", "transit/encrypt/phase33-control-plane", token,
        {"plaintext": base64.b64encode(plaintext).decode()}, expected={200},
    )
    return str(result["data"]["ciphertext"])


def transit_decrypt(token: str, ciphertext: str) -> bytes:
    result = vault_request(
        "POST", "transit/decrypt/phase33-control-plane", token,
        {"ciphertext": ciphertext}, expected={200},
    )
    return base64.b64decode(result["data"]["plaintext"])


def vault_kubernetes_token() -> str:
    jwt = TOKEN_PATH.read_text(encoding="utf-8").strip()
    result = vault_request(
        "POST", "auth/kubernetes/login", payload={"role": "phase33-singleton", "jwt": jwt}, expected={200},
    )
    return str(result["auth"]["client_token"])


def minio_credentials(token: str) -> tuple[str, str]:
    result = vault_request("GET", "secret/data/amoebius/phase33/minio", token, expected={200})
    data = result["data"]["data"]
    return str(data["accessKey"]), str(data["secretKey"])


def sign_v4(method: str, bucket: str, key: str, body: bytes, access: str, secret: str, now: dt.datetime) -> dict[str, str]:
    encoded_key = "/".join(urllib.parse.quote(part, safe="-_.~") for part in key.split("/"))
    canonical_uri = f"/{bucket}" + (f"/{encoded_key}" if key else "")
    payload_hash = hashlib.sha256(body).hexdigest()
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    canonical_headers = f"host:{MINIO_HOST}:9000\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n"
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = "\n".join([method, canonical_uri, "", canonical_headers, signed_headers, payload_hash])
    scope = f"{date_stamp}/us-east-1/s3/aws4_request"
    string_to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical_request.encode()).hexdigest()])
    date_key = hmac.new(("AWS4" + secret).encode(), date_stamp.encode(), hashlib.sha256).digest()
    region_key = hmac.new(date_key, b"us-east-1", hashlib.sha256).digest()
    service_key = hmac.new(region_key, b"s3", hashlib.sha256).digest()
    signing_key = hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
    return {
        "Host": f"{MINIO_HOST}:9000", "x-amz-content-sha256": payload_hash, "x-amz-date": amz_date,
        "Authorization": f"AWS4-HMAC-SHA256 Credential={access}/{scope}, SignedHeaders={signed_headers}, Signature={signature}",
    }


def s3_request(method: str, bucket: str, key: str, body: bytes, access: str, secret: str, expected: set[int]) -> bytes:
    now = dt.datetime.now(dt.timezone.utc)
    headers = sign_v4(method, bucket, key, body, access, secret, now)
    connection = http.client.HTTPConnection(MINIO_HOST, 9000, timeout=60)
    path = f"/{bucket}" + ("/" + "/".join(urllib.parse.quote(part, safe="-_.~") for part in key.split("/")) if key else "")
    connection.request(method, path, body=body, headers=headers)
    response = connection.getresponse()
    payload = response.read()
    connection.close()
    if response.status not in expected:
        raise HelperError(f"minio-{method.lower()}-{response.status}")
    return payload


def persist_state(request: dict[str, Any]) -> dict[str, Any]:
    source = str(request.get("dhall", "")).encode()
    if not source:
        raise HelperError("dhall-source-absent")
    root_token = open_material(str(request.get("password", "")))["root_token"]
    access, secret = minio_credentials(root_token)
    ciphertext = transit_encrypt(root_token, source)
    record = json.dumps(
        {"schema": "amoebius.phase33.control-plane-state.v1", "ciphertext": ciphertext, "sha256": hashlib.sha256(source).hexdigest()},
        sort_keys=True, separators=(",", ":"),
    ).encode()
    s3_request("PUT", MINIO_BUCKET, "", b"", access, secret, {200, 409})
    s3_request("PUT", MINIO_BUCKET, MINIO_KEY, record, access, secret, {200})
    return {"sha256": "sha256:" + hashlib.sha256(source).hexdigest(), "bytes": len(source)}


def recover_state() -> dict[str, Any]:
    token = vault_kubernetes_token()
    access, secret = minio_credentials(token)
    try:
        raw = s3_request("GET", MINIO_BUCKET, MINIO_KEY, b"", access, secret, {200})
    except HelperError as problem:
        if "minio-get-404" in str(problem):
            return {"result": "absent"}
        raise
    record = json.loads(raw)
    plaintext = transit_decrypt(token, str(record["ciphertext"]))
    digest = hashlib.sha256(plaintext).hexdigest()
    if digest != record.get("sha256"):
        raise HelperError("durable-state-digest-mismatch")
    return {"result": "recovered", "sha256": "sha256:" + digest, "bytes": len(plaintext)}


def object_path(value: dict[str, Any]) -> str:
    kind = value["kind"]
    namespace = value["metadata"].get("namespace")
    name = value["metadata"]["name"]
    table = {
        "ConfigMap": ("/api/v1", "configmaps"),
        "Service": ("/api/v1", "services"),
        "Deployment": ("/apis/apps/v1", "deployments"),
        "HTTPRoute": ("/apis/gateway.networking.k8s.io/v1", "httproutes"),
    }
    prefix, plural = table[kind]
    return f"{prefix}/namespaces/{namespace}/{plural}/{name}"


def identity(value: dict[str, Any]) -> str:
    metadata = value["metadata"]
    return f"{value['kind']}/{metadata.get('namespace', '')}/{metadata['name']}"


def desired_hash(value: dict[str, Any]) -> str:
    candidate = json.loads(json.dumps(value))
    candidate.setdefault("metadata", {}).setdefault("annotations", {}).pop("amoebius.io/phase33-desired-hash", None)
    return hashlib.sha256(json.dumps(candidate, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def apply_if_changed(value: dict[str, Any], run_id: str) -> bool:
    digest = desired_hash(value)
    metadata = value.setdefault("metadata", {})
    metadata.setdefault("annotations", {})["amoebius.io/phase33-desired-hash"] = digest
    metadata.setdefault("labels", {})["app.kubernetes.io/managed-by"] = "amoebius"
    if identity(value).split("/", 1)[0] in {"Deployment", "Service", "HTTPRoute"} and metadata["name"] == "phase33-trivial":
        metadata["labels"]["amoebius.dev/phase33-run"] = run_id
    path = object_path(value)
    status, observed = kubernetes_request("GET", path)
    if (
        status == 200
        and observed.get("metadata", {}).get("annotations", {}).get("amoebius.io/phase33-desired-hash") == digest
        and contains_desired(observed, value)
    ):
        return False
    query = urllib.parse.urlencode({"fieldManager": FIELD_MANAGER, "force": "true"})
    require_kubernetes("PATCH", path + "?" + query, value, content_type="application/apply-patch+yaml", expected={200, 201})
    return True


def contains_desired(observed: Any, desired: Any) -> bool:
    """Compare the SSA-owned projection; never trust a possibly stale hash alone."""
    if isinstance(desired, dict):
        return isinstance(observed, dict) and all(
            key in observed and contains_desired(observed[key], nested)
            for key, nested in desired.items()
        )
    if isinstance(desired, list):
        return isinstance(observed, list) and len(observed) == len(desired) and all(
            contains_desired(actual, expected)
            for actual, expected in zip(observed, desired, strict=True)
        )
    return observed == desired


def query_proxy_objects() -> list[dict[str, Any]]:
    service = {
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "prometheus-query-proxy", "namespace": "observability"},
        "spec": {"type": "ClusterIP", "selector": {"app": "prometheus-query-proxy"}, "ports": [{"name": "http", "port": 8080, "targetPort": 8080}]},
    }
    deployment = {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "prometheus-query-proxy", "namespace": "observability"},
        "spec": {
            "replicas": 1, "selector": {"matchLabels": {"app": "prometheus-query-proxy"}},
            "template": {"metadata": {"labels": {"app": "prometheus-query-proxy"}}, "spec": {
                "automountServiceAccountToken": False,
                "containers": [{
                    "name": "prometheus-query-proxy", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": ["/usr/bin/python3"], "args": ["/phase31-query-proxy/query_proxy.py", "--max-concurrent=4", "--max-series=64", "--max-samples=4096", "--max-range-seconds=3600", "--timeout-seconds=30"],
                    "ports": [{"name": "http", "containerPort": 8080}],
                    "readinessProbe": {"httpGet": {"path": "/healthz", "port": 8080}, "periodSeconds": 2, "failureThreshold": 60},
                    "resources": {"requests": {"cpu": "25m", "memory": "32Mi", "ephemeral-storage": "16Mi"}, "limits": {"cpu": "250m", "memory": "128Mi", "ephemeral-storage": "64Mi"}},
                    "securityContext": {"allowPrivilegeEscalation": False, "runAsNonRoot": True, "runAsUser": 1000, "runAsGroup": 1000, "capabilities": {"drop": ["ALL"]}, "seccompProfile": {"type": "RuntimeDefault"}},
                    "volumeMounts": [{"name": "query-proxy", "mountPath": "/phase31-query-proxy", "readOnly": True}],
                }],
                "volumes": [{"name": "query-proxy", "configMap": {"name": "prometheus-query-proxy", "defaultMode": 365}}],
            }},
        },
    }
    return [deployment, service]


def trivial_objects(run_id: str) -> list[dict[str, Any]]:
    labels = {"app": "phase32-route-probe", "amoebius.io/phase33-app": "trivial"}
    script = "from http.server import BaseHTTPRequestHandler,HTTPServer\nclass H(BaseHTTPRequestHandler):\n def do_GET(s):\n  b=('phase33-trivial:'+s.path).encode();s.send_response(200);s.send_header('Content-Length',str(len(b)));s.end_headers();s.wfile.write(b)\n def log_message(s,*a): pass\nHTTPServer(('0.0.0.0',8080),H).serve_forever()"
    deployment = {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "phase33-trivial", "namespace": "edge-system"},
        "spec": {"replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"amoebius.io/phase33-app": "trivial"}},
            "template": {"metadata": {"labels": labels}, "spec": {"automountServiceAccountToken": False, "containers": [{
                "name": "app", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/python3", "-c", script],
                "ports": [{"name": "http", "containerPort": 8080}],
                "readinessProbe": {"httpGet": {"path": "/healthz", "port": 8080}, "periodSeconds": 1, "failureThreshold": 60},
                "resources": {"requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "16Mi"}, "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"}},
                "securityContext": {"allowPrivilegeEscalation": False, "runAsNonRoot": True, "runAsUser": 1000, "runAsGroup": 1000, "capabilities": {"drop": ["ALL"]}, "seccompProfile": {"type": "RuntimeDefault"}},
            }]}}},
    }
    service = {
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "phase33-trivial", "namespace": "edge-system"},
        "spec": {"type": "ClusterIP", "selector": {"amoebius.io/phase33-app": "trivial"}, "ports": [{"name": "http", "port": 8080, "targetPort": 8080}]},
    }
    route = {
        "apiVersion": "gateway.networking.k8s.io/v1", "kind": "HTTPRoute", "metadata": {"name": "phase33-trivial", "namespace": "edge-system", "annotations": {"amoebius.io/auth-owner": "Keycloak", "amoebius.io/data-plane-projection": "static-envoy-v1"}},
        "spec": {"parentRefs": [{"name": "keycloak-edge"}], "hostnames": ["phase32.amoebius.internal"], "rules": [{"matches": [{"path": {"type": "PathPrefix", "value": "/phase33/"}}], "backendRefs": [{"name": "phase33-trivial", "port": 8080}]}]},
    }
    return [deployment, route, service]


def ensure_envoy_route(run_id: str) -> list[str]:
    config_path = "/api/v1/namespaces/edge-system/configmaps/phase32-envoy"
    observed = require_kubernetes("GET", config_path)
    config = str(observed["data"]["envoy.yaml"])
    mutations: list[str] = []
    if "cluster: phase33_trivial" not in config:
        route_anchor = '              - match: {prefix: "/platform/"}\n                route: {cluster: route_probe, timeout: 30s}\n'
        route = '              - match: {prefix: "/phase33/"}\n                route: {cluster: phase33_trivial, prefix_rewrite: "/", timeout: 30s}\n'
        if route_anchor not in config:
            raise HelperError("envoy-route-anchor-absent")
        config = config.replace(route_anchor, route_anchor + route, 1)
        cluster = '''  - name: phase33_trivial
    connect_timeout: 5s
    type: STRICT_DNS
    load_assignment:
      cluster_name: phase33_trivial
      endpoints: [{lb_endpoints: [{endpoint: {address: {socket_address: {address: phase33-trivial.edge-system.svc.cluster.local, port_value: 8080}}}}]}]
'''
        if "admin:\n" not in config:
            raise HelperError("envoy-admin-anchor-absent")
        config = config.replace("admin:\n", cluster + "admin:\n", 1)
        desired = {"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "phase32-envoy", "namespace": "edge-system"}, "data": {"envoy.yaml": config}}
        if apply_if_changed(desired, run_id):
            mutations.append("ConfigMap/edge-system/phase32-envoy")
        deployment_path = "/apis/apps/v1/namespaces/edge-system/deployments/envoy"
        live = require_kubernetes("GET", deployment_path)
        rollout_digest = hashlib.sha256((run_id + "\n" + config).encode()).hexdigest()
        patch = {"metadata": {"resourceVersion": live["metadata"]["resourceVersion"]}, "spec": {"template": {"metadata": {"annotations": {"amoebius.io/phase33-config-sha": rollout_digest}}}}}
        query = urllib.parse.urlencode({"fieldManager": FIELD_MANAGER})
        require_kubernetes("PATCH", deployment_path + "?" + query, patch, content_type="application/merge-patch+json")
        mutations.append("Deployment/edge-system/envoy")
    return mutations


def wait_deployment(namespace: str, name: str, timeout: int = 240) -> None:
    path = f"/apis/apps/v1/namespaces/{namespace}/deployments/{name}"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = require_kubernetes("GET", path)
        desired = int(value.get("spec", {}).get("replicas", 1))
        if int(value.get("status", {}).get("readyReplicas", 0)) == desired and int(value.get("status", {}).get("observedGeneration", 0)) >= int(value["metadata"].get("generation", 0)):
            return
        time.sleep(2)
    raise HelperError(f"deployment-not-ready:{namespace}/{name}")


def reconcile(request: dict[str, Any]) -> dict[str, Any]:
    run_id = str(request.get("runId", ""))
    if not re.fullmatch(r"phase33-[a-f0-9]{12}", run_id):
        raise HelperError("phase33-run-id-invalid")
    mutations: list[str] = []
    for value in query_proxy_objects() + trivial_objects(run_id):
        if apply_if_changed(value, run_id):
            mutations.append(identity(value))
    mutations.extend(ensure_envoy_route(run_id))
    wait_deployment("observability", "prometheus-query-proxy")
    wait_deployment("edge-system", "phase33-trivial")
    wait_deployment("edge-system", "envoy")
    mutation_set = set(mutations)
    ordered = [object_id for object_id in ENACT_ORDER if object_id in mutation_set]
    if len(ordered) != len(mutation_set):
        raise HelperError(f"unexpected-enact-object:{sorted(mutation_set - set(ENACT_ORDER))}")
    return {"fieldManager": FIELD_MANAGER, "objects": ordered}


def main() -> int:
    if len(sys.argv) < 2:
        raise HelperError("helper-operation-required")
    operation = sys.argv[1]
    if operation == "lease-acquire":
        if len(sys.argv) != 3:
            raise HelperError("pod-uid-required")
        result = lease_acquire(sys.argv[2])
    elif operation == "recover-state":
        result = recover_state()
    else:
        request = stdin_json()
        if operation == "vault-init":
            result = vault_init(request)
        elif operation == "vault-unseal":
            result = vault_unseal(request)
        elif operation == "kv":
            result = kv_operation(request)
        elif operation == "persist-state":
            result = persist_state(request)
        elif operation == "reconcile":
            result = reconcile(request)
        else:
            raise HelperError("unknown-helper-operation")
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (HelperError, OSError, ValueError, KeyError, subprocess.SubprocessError) as problem:
        print(str(problem), file=sys.stderr)
        raise SystemExit(1)
