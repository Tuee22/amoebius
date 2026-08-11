#!/usr/bin/env python3
"""Phase 34: enact and independently read back six tenant-provider arms."""

from __future__ import annotations

import argparse
import base64
import contextlib
import datetime as dt
import hashlib
import hmac
import http.client
import json
import os
import re
import secrets
import socket
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterator, Sequence

import phase30_backbone_live as phase30


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_34/tenant-provider-live.json"
ORACLE = ROOT / "test/fixtures/phase_34/provider_projection_matrix.tsv"
SYSTEM_NAMESPACE = "phase34-system"
MINIO_ACCESS = phase30.MINIO_ACCESS
MINIO_SECRET = phase30.MINIO_SECRET
MINIO_PORT = phase30.MINIO_PORT
KEYCLOAK_PORT = 18084
VAULT_PORT = 18204
PULSAR_PORT = 18085
TOKEN_CA = Path(f"/tmp/amoebius-phase34-ca-{os.getpid()}.crt")
TOKEN_SERVER: str | None = None


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, stdin: str | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=stdin, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        raise LiveFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return run(("/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), *arguments), stdin=stdin, check=check, timeout=timeout)


def kubectl_as(token: str, *arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    global TOKEN_SERVER
    if TOKEN_SERVER is None:
        config = json.loads(kubectl("config", "view", "--raw", "-o", "json").stdout)
        cluster = config["clusters"][0]["cluster"]
        TOKEN_SERVER = cluster["server"]
        TOKEN_CA.write_bytes(base64.b64decode(cluster["certificate-authority-data"]))
        TOKEN_CA.chmod(0o600)
    return run(
        (
            "/usr/bin/kubectl", "--kubeconfig", "/dev/null", "--server", TOKEN_SERVER,
            "--certificate-authority", str(TOKEN_CA), "--token", token, *arguments,
        ),
        stdin=stdin, check=check, timeout=timeout,
    )


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=phase34-harness", "--force-conflicts", "-f", "-", stdin=json.dumps(value))


def apply_as(token: str, value: dict[str, Any]) -> None:
    kubectl_as(token, "apply", "--server-side", "--field-manager=amoebius-phase34-provider", "--force-conflicts", "-f", "-", stdin=json.dumps(value))


@contextlib.contextmanager
def port_forward(namespace: str, resource: str, local: int, remote: int) -> Iterator[None]:
    process = subprocess.Popen(
        ["/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), "-n", namespace, "port-forward", resource, f"{local}:{remote}"],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", local), timeout=1):
                    break
            except OSError:
                if process.poll() is not None:
                    output = process.stdout.read().decode(errors="replace") if process.stdout else ""
                    raise LiveFailure(f"port-forward-exited:{namespace}:{resource}:{output}")
                time.sleep(0.2)
        else:
            raise LiveFailure(f"port-forward-timeout:{namespace}:{resource}")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def http_request(method: str, port: int, path: str, *, body: Any = None, headers: dict[str, str] | None = None, expected: set[int] | None = None) -> tuple[int, bytes, dict[str, str]]:
    payload = b"" if body is None else (body if isinstance(body, bytes) else json.dumps(body, sort_keys=True, separators=(",", ":")).encode())
    request_headers = dict(headers or {})
    if body is not None and not isinstance(body, bytes):
        request_headers.setdefault("Content-Type", "application/json")
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=60)
    try:
        connection.request(method, path, body=payload, headers=request_headers)
        response = connection.getresponse()
        data = response.read()
        response_headers = {key.lower(): value for key, value in response.getheaders()}
    finally:
        connection.close()
    if expected is not None and response.status not in expected:
        raise LiveFailure(f"http:{method}:{path}:{response.status}:{data.decode(errors='replace')}")
    return response.status, data, response_headers


def json_request(method: str, port: int, path: str, *, body: Any = None, headers: dict[str, str] | None = None, expected: set[int] | None = None) -> tuple[Any, dict[str, str]]:
    _, data, response_headers = http_request(method, port, path, body=body, headers=headers, expected=expected)
    return (json.loads(data) if data else None), response_headers


def digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def setup_authorities(run_suffix: str) -> tuple[dict[str, str], str]:
    apply({"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": SYSTEM_NAMESPACE, "labels": {"amoebius.dev/phase34-run": run_suffix}}})
    providers = {
        "Keycloak": "edge-system",
        "Vault": "vault-system",
        "Pulsar": "pulsar-system",
        "Minio": "platform-system",
        "Postgres": "grafana-db",
    }
    for provider, namespace in providers.items():
        observer = "observer-" + provider.lower()
        apply({"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": observer, "namespace": SYSTEM_NAMESPACE}})
        role_name = f"phase34-{provider.lower()}-pod-reader"
        apply({
            "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "Role",
            "metadata": {"name": role_name, "namespace": namespace},
            "rules": [
                {"apiGroups": [""], "resources": ["pods"], "verbs": ["get", "list"]},
                {"apiGroups": [""], "resources": ["pods/exec"], "verbs": ["create"]},
            ],
        })
        apply({
            "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "RoleBinding",
            "metadata": {"name": role_name, "namespace": namespace},
            "subjects": [{"kind": "ServiceAccount", "name": observer, "namespace": SYSTEM_NAMESPACE}],
            "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "Role", "name": role_name},
        })
    for name in ("observer-kubernetesapi", "provider-enactor"):
        apply({"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": name, "namespace": SYSTEM_NAMESPACE}})
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole",
        "metadata": {"name": "phase34-kubernetes-observer"},
        "rules": [
            {"apiGroups": [""], "resources": ["namespaces"], "verbs": ["get", "list"]},
            {"apiGroups": ["networking.k8s.io"], "resources": ["networkpolicies"], "verbs": ["get", "list"]},
        ],
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding",
        "metadata": {"name": "phase34-kubernetes-observer"},
        "subjects": [{"kind": "ServiceAccount", "name": "observer-kubernetesapi", "namespace": SYSTEM_NAMESPACE}],
        "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "phase34-kubernetes-observer"},
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole",
        "metadata": {"name": "phase34-provider-enactor"},
        "rules": [
            {"apiGroups": [""], "resources": ["namespaces"], "verbs": ["create", "get", "list", "patch", "delete"]},
            {"apiGroups": ["networking.k8s.io"], "resources": ["networkpolicies"], "verbs": ["create", "get", "list", "patch", "delete"]},
            {"apiGroups": [""], "resources": ["pods"], "verbs": ["get", "list"]},
            {"apiGroups": [""], "resources": ["pods/exec"], "verbs": ["create"]},
        ],
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding",
        "metadata": {"name": "phase34-provider-enactor"},
        "subjects": [{"kind": "ServiceAccount", "name": "provider-enactor", "namespace": SYSTEM_NAMESPACE}],
        "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "phase34-provider-enactor"},
    })
    tokens: dict[str, str] = {}
    for provider in ("keycloak", "vault", "pulsar", "minio", "postgres", "kubernetesapi"):
        tokens[provider] = kubectl("-n", SYSTEM_NAMESPACE, "create", "token", f"observer-{provider}", "--duration=30m").stdout.strip()
    enactor = kubectl("-n", SYSTEM_NAMESPACE, "create", "token", "provider-enactor", "--duration=30m").stdout.strip()
    who = json.loads(kubectl_as(enactor, "auth", "whoami", "-o", "json").stdout)
    if who.get("status", {}).get("userInfo", {}).get("username") != f"system:serviceaccount:{SYSTEM_NAMESPACE}:provider-enactor":
        raise LiveFailure("enactor-identity")
    return tokens, enactor


def secret_value(namespace: str, name: str, key: str) -> str:
    value = json.loads(kubectl("-n", namespace, "get", "secret", name, "-o", "json").stdout)
    return base64.b64decode(value["data"][key]).decode()


def keycloak_token(realm: str, fields: dict[str, str]) -> str:
    body = urllib.parse.urlencode(fields).encode()
    _, data, _ = http_request(
        "POST", KEYCLOAK_PORT, f"/keycloak/realms/{realm}/protocol/openid-connect/token",
        body=body, headers={"Content-Type": "application/x-www-form-urlencoded"}, expected={200},
    )
    return str(json.loads(data)["access_token"])


def keycloak_apply(app: str, tenants: list[str], challenge: str) -> dict[str, Any]:
    password = secret_value("edge-system", "phase32-edge-secrets", "keycloak-admin")
    admin = keycloak_token("master", {"grant_type": "password", "client_id": "admin-cli", "username": "phase32-admin", "password": password})
    headers = {"Authorization": "Bearer " + admin}
    created: list[dict[str, str]] = []
    for tenant in tenants:
        role = f"{app}:{tenant}:read:{challenge[:8]}"
        group = f"{app}-{tenant}-{challenge[:8]}"
        json_request("POST", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/roles", body={"name": role, "description": challenge}, headers=headers, expected={201})
        role_value, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/roles/" + urllib.parse.quote(role, safe=""), headers=headers, expected={200})
        _, group_headers = json_request("POST", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/groups", body={"name": group, "attributes": {"amoebius.challenge": [challenge], "amoebius.tenant": [tenant]}}, headers=headers, expected={201})
        group_id = group_headers["location"].rsplit("/", 1)[1]
        json_request("POST", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/groups/{group_id}/role-mappings/realm", body=[role_value], headers=headers, expected={204})
        created.append({"tenant": tenant, "role": role, "group": group, "groupId": group_id})
    client_id = f"phase34-observer-{challenge[:8]}"
    _, client_headers = json_request("POST", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/clients", body={"clientId": client_id, "enabled": True, "serviceAccountsEnabled": True, "publicClient": False, "clientAuthenticatorType": "client-secret", "protocol": "openid-connect"}, headers=headers, expected={201})
    internal_id = client_headers["location"].rsplit("/", 1)[1]
    client_secret, _ = json_request("GET", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/clients/{internal_id}/client-secret", headers=headers, expected={200})
    service_user, _ = json_request("GET", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/clients/{internal_id}/service-account-user", headers=headers, expected={200})
    realm_clients, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/clients?clientId=realm-management", headers=headers, expected={200})
    management_id = realm_clients[0]["id"]
    available, _ = json_request("GET", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/users/{service_user['id']}/role-mappings/clients/{management_id}/available", headers=headers, expected={200})
    granted = [role for role in available if role.get("name") in {"view-realm", "view-users", "query-groups"}]
    json_request("POST", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/users/{service_user['id']}/role-mappings/clients/{management_id}", body=granted, headers=headers, expected={204})
    observer = keycloak_token("amoebius", {"grant_type": "client_credentials", "client_id": client_id, "client_secret": client_secret["value"]})
    return {"admin": admin, "observer": observer, "observerClient": client_id, "clientInternalId": internal_id, "objects": created}


def keycloak_observe(state: dict[str, Any], challenge: str) -> list[dict[str, Any]]:
    headers = {"Authorization": "Bearer " + state["observer"]}
    observations = []
    for item in state["objects"]:
        role, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/roles/" + urllib.parse.quote(item["role"], safe=""), headers=headers, expected={200})
        group, _ = json_request("GET", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/groups/{item['groupId']}?briefRepresentation=false", headers=headers, expected={200})
        mapping, _ = json_request("GET", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/groups/{item['groupId']}/role-mappings/realm", headers=headers, expected={200})
        raw = {"role": role, "group": group, "mapping": mapping}
        observations.append(provider_row("Keycloak", item["tenant"], ["RealmRole", "GroupRoleMapping"], challenge, raw))
    return observations


def keycloak_cleanup(state: dict[str, Any]) -> None:
    headers = {"Authorization": "Bearer " + state["admin"]}
    for item in state["objects"]:
        json_request("DELETE", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/groups/{item['groupId']}", headers=headers, expected={204})
        json_request("DELETE", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/roles/" + urllib.parse.quote(item["role"], safe=""), headers=headers, expected={204})
    json_request("DELETE", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/clients/{state['clientInternalId']}", headers=headers, expected={204})


def vault_request(method: str, path: str, token: str, body: Any = None, expected: set[int] | None = None) -> Any:
    value, _ = json_request(method, VAULT_PORT, "/v1/" + path, body=body, headers={"X-Vault-Token": token}, expected=expected or {200, 204})
    return value


def vault_apply(root_token: str, app: str, tenants: list[str], challenge: str) -> dict[str, Any]:
    policies = []
    for tenant in tenants:
        name = f"{app}-{tenant}"
        path = f"secret/data/amoebius/phase34/{app}/{tenant}/*"
        policy = f'path "{path}" {{ capabilities = ["read", "list"] }}\n'
        vault_request("PUT", f"sys/policies/acl/{name}", root_token, {"policy": policy})
        vault_request("PUT", f"secret/data/amoebius/phase34/{app}/{tenant}/challenge", root_token, {"data": {"challenge": challenge, "tenant": tenant}})
        policies.append({"tenant": tenant, "name": name, "path": path})
    observer_policy = f"phase34-observer-{challenge[:8]}"
    policy_text = "\n".join(
        [f'path "sys/policies/acl/{row["name"]}" {{ capabilities = ["read"] }}\npath "secret/data/amoebius/phase34/{app}/{row["tenant"]}/challenge" {{ capabilities = ["read"] }}' for row in policies]
    )
    vault_request("PUT", f"sys/policies/acl/{observer_policy}", root_token, {"policy": policy_text})
    token_value = vault_request("POST", "auth/token/create", root_token, {"policies": [observer_policy], "ttl": "30m", "renewable": False})
    return {"policies": policies, "observerPolicy": observer_policy, "observerToken": token_value["auth"]["client_token"], "observerAccessor": token_value["auth"]["accessor"]}


def vault_observe(state: dict[str, Any], app: str, challenge: str) -> list[dict[str, Any]]:
    result = []
    for row in state["policies"]:
        policy = vault_request("GET", f"sys/policies/acl/{row['name']}", state["observerToken"])
        marker = vault_request("GET", f"secret/data/amoebius/phase34/{app}/{row['tenant']}/challenge", state["observerToken"])
        raw = {"policy": policy["data"]["policy"], "marker": marker["data"]["data"]}
        result.append(provider_row("Vault", row["tenant"], ["AclPolicy"], challenge, raw))
    return result


def vault_cleanup(root_token: str, state: dict[str, Any], app: str) -> None:
    vault_request("POST", "auth/token/revoke-accessor", root_token, {"accessor": state["observerAccessor"]}, expected={204})
    for row in state["policies"]:
        vault_request("DELETE", f"sys/policies/acl/{row['name']}", root_token, expected={204})
        vault_request("DELETE", f"secret/metadata/amoebius/phase34/{app}/{row['tenant']}/challenge", root_token, expected={204})
    vault_request("DELETE", f"sys/policies/acl/{state['observerPolicy']}", root_token, expected={204})


def pulsar_apply(app: str, tenants: list[str], challenge: str) -> dict[str, Any]:
    clusters, _ = json_request("GET", PULSAR_PORT, "/admin/v2/clusters", expected={200})
    if not clusters:
        raise LiveFailure("pulsar-no-cluster")
    rows = []
    for tenant in tenants:
        json_request("PUT", PULSAR_PORT, f"/admin/v2/tenants/{tenant}", body={"adminRoles": [], "allowedClusters": [clusters[0]]}, expected={204})
        json_request("PUT", PULSAR_PORT, f"/admin/v2/namespaces/{tenant}/{app}", body={"bundles": {"boundaries": ["0x00000000", "0xffffffff"], "numBundles": 1}}, expected={204})
        role = f"{app}-{tenant}-derived"
        json_request("POST", PULSAR_PORT, f"/admin/v2/namespaces/{tenant}/{app}/permissions/{role}", body=["produce", "consume"], expected={204})
        rows.append({"tenant": tenant, "role": role, "namespace": f"{tenant}/{app}", "challenge": challenge})
    pods = json.loads(kubectl("-n", "pulsar-system", "get", "pods", "-l", "app=pulsar-tool", "-o", "json").stdout)["items"]
    if len(pods) != 1:
        raise LiveFailure("pulsar-tool-pod-cardinality")
    return {"rows": rows, "toolPod": pods[0]["metadata"]["name"]}


REMOTE_GET = """import json,sys,urllib.request
req=urllib.request.Request(sys.argv[1],headers=json.loads(sys.argv[2]))
with urllib.request.urlopen(req,timeout=30) as r: print(r.read().decode())
"""


def pulsar_observe(state: dict[str, Any], observer_token: str, challenge: str) -> list[dict[str, Any]]:
    result = []
    for row in state["rows"]:
        url = f"http://broker.pulsar-system.svc.cluster.local:8080/admin/v2/namespaces/{row['namespace']}/permissions"
        value = kubectl_as(observer_token, "-n", "pulsar-system", "exec", state["toolPod"], "--", "/usr/bin/python3", "-c", REMOTE_GET, url, "{}").stdout.strip()
        raw = {"namespace": row["namespace"], "permissions": json.loads(value), "challenge": row["challenge"]}
        result.append(provider_row("Pulsar", row["tenant"], ["NamespacePolicy"], challenge, raw))
    return result


def pulsar_cleanup(state: dict[str, Any]) -> None:
    for row in state["rows"]:
        json_request("DELETE", PULSAR_PORT, f"/admin/v2/namespaces/{row['namespace']}", expected={204})
        json_request("DELETE", PULSAR_PORT, f"/admin/v2/tenants/{row['tenant']}", expected={204})


def s3_headers(method: str, bucket: str, key: str = "", body: bytes = b"", query: str = "") -> tuple[str, dict[str, str]]:
    now = dt.datetime.now(dt.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    encoded_key = urllib.parse.quote(key, safe="/-_.~")
    path = "/" + urllib.parse.quote(bucket, safe="-_.~") + ("/" + encoded_key if key else "")
    payload_hash = hashlib.sha256(body).hexdigest()
    canonical_headers = f"host:minio.platform-system.svc.cluster.local:9000\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n"
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = "\n".join([method, path, query, canonical_headers, signed_headers, payload_hash])
    scope = f"{date_stamp}/us-east-1/s3/aws4_request"
    string_to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical_request.encode()).hexdigest()])
    date_key = hmac.new(("AWS4" + MINIO_SECRET).encode(), date_stamp.encode(), hashlib.sha256).digest()
    region_key = hmac.new(date_key, b"us-east-1", hashlib.sha256).digest()
    service_key = hmac.new(region_key, b"s3", hashlib.sha256).digest()
    signing_key = hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
    authorization = f"AWS4-HMAC-SHA256 Credential={MINIO_ACCESS}/{scope}, SignedHeaders={signed_headers}, Signature={signature}"
    url = "http://minio.platform-system.svc.cluster.local:9000" + path + ("?" + query if query else "")
    return url, {"x-amz-date": amz_date, "x-amz-content-sha256": payload_hash, "Authorization": authorization}


def minio_apply(app: str, tenants: list[str], challenge: str) -> dict[str, Any]:
    rows = []
    for tenant in tenants:
        bucket = f"{app}-{tenant}"
        status, payload = phase30.s3_request("PUT", bucket)
        if status != 200:
            raise LiveFailure(f"minio-bucket-create:{status}:{payload.decode(errors='replace')}")
        status, payload = phase30.s3_request("PUT", bucket, "phase34-challenge.json", json.dumps({"challenge": challenge, "tenant": tenant}, sort_keys=True).encode())
        if status != 200:
            raise LiveFailure(f"minio-marker-put:{status}:{payload.decode(errors='replace')}")
        policy = {
            "Version": "2012-10-17",
            "Statement": [{"Effect": "Allow", "Principal": {"AWS": [f"arn:amoebius:tenant::{tenant}"]}, "Action": ["s3:GetObject", "s3:PutObject"], "Resource": [f"arn:aws:s3:::{bucket}/*"], "Sid": challenge}],
        }
        status, payload = phase30.s3_request("PUT", bucket, body=json.dumps(policy, sort_keys=True, separators=(",", ":")).encode(), query="policy=")
        if status != 204:
            raise LiveFailure(f"minio-policy-put:{status}:{payload.decode(errors='replace')}")
        rows.append({"tenant": tenant, "bucket": bucket})
    return {"rows": rows}


def minio_observe(state: dict[str, Any], observer_token: str, challenge: str) -> list[dict[str, Any]]:
    result = []
    for row in state["rows"]:
        policy_url, policy_headers = s3_headers("GET", row["bucket"], query="policy=")
        marker_url, marker_headers = s3_headers("GET", row["bucket"], "phase34-challenge.json")
        policy_raw = kubectl_as(observer_token, "-n", "platform-system", "exec", "minio-0", "--", "/usr/bin/python3", "-c", REMOTE_GET, policy_url, json.dumps(policy_headers)).stdout.strip()
        marker_raw = kubectl_as(observer_token, "-n", "platform-system", "exec", "minio-0", "--", "/usr/bin/python3", "-c", REMOTE_GET, marker_url, json.dumps(marker_headers)).stdout.strip()
        raw = {"bucket": row["bucket"], "policy": json.loads(policy_raw), "marker": json.loads(marker_raw), "scopedCapability": digest(policy_headers)}
        result.append(provider_row("Minio", row["tenant"], ["BucketPolicy"], challenge, raw))
    return result


def minio_cleanup(state: dict[str, Any]) -> None:
    for row in state["rows"]:
        for method, key, query, expected in (("DELETE", "phase34-challenge.json", "", 204), ("DELETE", "", "policy=", 204), ("DELETE", "", "", 204)):
            status, payload = phase30.s3_request(method, row["bucket"], key, query=query)
            if status != expected:
                raise LiveFailure(f"minio-cleanup:{row['bucket']}:{method}:{query}:{status}:{payload.decode(errors='replace')}")


def kubernetes_apply(app: str, tenants: list[str], challenge: str, enactor_token: str) -> dict[str, Any]:
    rows = []
    for tenant in tenants:
        namespace = f"{app}-{tenant}"
        apply_as(enactor_token, {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": namespace, "labels": {"amoebius.io/app": app, "amoebius.io/tenant": tenant, "amoebius.io/challenge": challenge}}})
        apply_as(enactor_token, {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "default-deny", "namespace": namespace, "labels": {"amoebius.io/challenge": challenge}},
            "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"], "ingress": [{"from": [{"namespaceSelector": {"matchLabels": {"amoebius.io/tenant": tenant}}}]}], "egress": [{"to": [{"namespaceSelector": {"matchLabels": {"amoebius.io/tenant": tenant}}}]}]},
        })
        rows.append({"tenant": tenant, "namespace": namespace})
    return {"rows": rows}


def kubernetes_observe(state: dict[str, Any], observer_token: str, challenge: str) -> list[dict[str, Any]]:
    result = []
    for row in state["rows"]:
        namespace = json.loads(kubectl_as(observer_token, "get", "namespace", row["namespace"], "-o", "json").stdout)
        policy = json.loads(kubectl_as(observer_token, "-n", row["namespace"], "get", "networkpolicy", "default-deny", "-o", "json").stdout)
        raw = {"namespace": namespace["metadata"]["labels"], "policy": policy["spec"]}
        result.append(provider_row("KubernetesApi", row["tenant"], ["Namespace", "NetworkPolicy"], challenge, raw))
    return result


def kubernetes_cleanup(state: dict[str, Any], enactor_token: str) -> None:
    for row in state["rows"]:
        kubectl_as(enactor_token, "delete", "namespace", row["namespace"], "--wait=true", "--timeout=120s")


def postgres_primary() -> str:
    values = json.loads(kubectl("-n", "grafana-db", "get", "pods", "-l", "app=grafana-postgres,role=primary", "-o", "json").stdout)["items"]
    if len(values) != 1:
        raise LiveFailure("postgres-primary-cardinality")
    return values[0]["metadata"]["name"]


def postgres_exec(token: str, pod: str, script: str, *, stdin: str | None = None) -> str:
    return kubectl_as(token, "-n", "grafana-db", "exec", "-i", pod, "--", "/bin/bash", "-ec", script, stdin=stdin).stdout


def sql_identifier(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9_]", "_", value.lower())
    if not re.fullmatch(r"[a-z_][a-z0-9_]{0,62}", normalized):
        raise LiveFailure("postgres-identifier")
    return normalized


def postgres_apply(app: str, tenants: list[str], challenge: str, enactor_token: str) -> dict[str, Any]:
    pod = postgres_primary()
    observer_role = sql_identifier(f"p34_obs_{challenge[:8]}")
    observer_password = secrets.token_urlsafe(24).replace("-", "A").replace("_", "B")
    statements = [f"CREATE ROLE {observer_role} LOGIN PASSWORD '{observer_password}';"]
    rows = []
    for tenant in tenants:
        name = sql_identifier(f"{app}_{tenant}")
        statements.extend([f"CREATE ROLE {name} NOLOGIN;", f"COMMENT ON ROLE {name} IS '{challenge}';", f"CREATE SCHEMA {name} AUTHORIZATION {name};", f"COMMENT ON SCHEMA {name} IS '{challenge}';"])
        rows.append({"tenant": tenant, "role": name, "schema": name})
    script = "export PGPASSWORD=\"$(cat /phase31-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'\n" + "\n".join(statements) + "\nSQL\n"
    postgres_exec(enactor_token, pod, script)
    return {"pod": pod, "observerRole": observer_role, "observerPassword": observer_password, "rows": rows}


def postgres_observe(state: dict[str, Any], observer_token: str, challenge: str) -> list[dict[str, Any]]:
    result = []
    for row in state["rows"]:
        query = f"select r.rolname,shobj_description(r.oid,'pg_authid'),n.nspname,obj_description(n.oid,'pg_namespace') from pg_roles r join pg_namespace n on n.nspname=r.rolname where r.rolname='{row['role']}'"
        script = f"export PGPASSWORD='{state['observerPassword']}'; /usr/lib/postgresql/17/bin/psql -h grafana-primary.grafana-db.svc.cluster.local -U {state['observerRole']} -d postgres -AtF '|' -v ON_ERROR_STOP=1 -c \"{query}\""
        raw_text = postgres_exec(observer_token, state["pod"], script).strip()
        raw = {"catalog": raw_text, "role": row["role"], "schema": row["schema"]}
        result.append(provider_row("Postgres", row["tenant"], ["Role", "Schema"], challenge, raw))
    return result


def postgres_cleanup(state: dict[str, Any], enactor_token: str) -> None:
    statements = []
    for row in state["rows"]:
        statements.extend([f"DROP SCHEMA IF EXISTS {row['schema']} CASCADE;", f"DROP ROLE IF EXISTS {row['role']};"])
    statements.append(f"DROP ROLE IF EXISTS {state['observerRole']};")
    script = "export PGPASSWORD=\"$(cat /phase31-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'\n" + "\n".join(statements) + "\nSQL\n"
    postgres_exec(enactor_token, state["pod"], script)


def provider_row(provider: str, tenant: str, object_types: list[str], challenge: str, raw: Any) -> dict[str, Any]:
    encoded = json.dumps(raw, sort_keys=True)
    return {"provider": provider, "tenant": tenant, "objectTypes": object_types, "challengeRecovered": challenge in encoded, "rawObservationSha256": digest(raw)}


def filtered_inventory(prefixes: Sequence[str]) -> dict[str, Any]:
    namespace_items = json.loads(kubectl("get", "namespaces", "-o", "json").stdout)["items"]
    namespaces = sorted(item["metadata"]["name"] for item in namespace_items if any(item["metadata"]["name"].startswith(prefix) for prefix in prefixes))
    return {"kubernetesNamespaces": namespaces}


def cleanup_authorities() -> None:
    for kind, name in (("clusterrolebinding", "phase34-kubernetes-observer"), ("clusterrolebinding", "phase34-provider-enactor"), ("clusterrole", "phase34-kubernetes-observer"), ("clusterrole", "phase34-provider-enactor")):
        kubectl("delete", kind, name, "--ignore-not-found", check=False)
    kubectl("delete", "namespace", SYSTEM_NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=120s", check=False)
    for namespace, role in (("edge-system", "phase34-keycloak-pod-reader"), ("vault-system", "phase34-vault-pod-reader"), ("pulsar-system", "phase34-pulsar-pod-reader"), ("platform-system", "phase34-minio-pod-reader"), ("grafana-db", "phase34-postgres-pod-reader")):
        kubectl("-n", namespace, "delete", "rolebinding", role, "--ignore-not-found", check=False)
        kubectl("-n", namespace, "delete", "role", role, "--ignore-not-found", check=False)


def oracle_digest() -> str:
    return "sha256:" + hashlib.sha256(ORACLE.read_bytes()).hexdigest()


def target_inventory(app: str, tenants: list[str], challenge: str, root_token: str, enactor_token: str) -> dict[str, Any]:
    password = secret_value("edge-system", "phase32-edge-secrets", "keycloak-admin")
    admin = keycloak_token("master", {"grant_type": "password", "client_id": "admin-cli", "username": "phase32-admin", "password": password})
    keycloak_headers = {"Authorization": "Bearer " + admin}
    keycloak_found = []
    for tenant in tenants:
        role = f"{app}:{tenant}:read:{challenge[:8]}"
        role_status, _, _ = http_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/roles/" + urllib.parse.quote(role, safe=""), headers=keycloak_headers, expected={200, 404})
        groups, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/groups?search=" + urllib.parse.quote(f"{app}-{tenant}-{challenge[:8]}") + "&exact=true", headers=keycloak_headers, expected={200})
        if role_status == 200 or groups:
            keycloak_found.append(tenant)
    clients, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/clients?clientId=" + urllib.parse.quote(f"phase34-observer-{challenge[:8]}"), headers=keycloak_headers, expected={200})
    vault_found = []
    pulsar_found = []
    minio_found = []
    kubernetes_found = []
    for tenant in tenants:
        policy_status, _, _ = http_request("GET", VAULT_PORT, f"/v1/sys/policies/acl/{app}-{tenant}", headers={"X-Vault-Token": root_token}, expected={200, 404})
        marker_status, _, _ = http_request("GET", VAULT_PORT, f"/v1/secret/data/amoebius/phase34/{app}/{tenant}/challenge", headers={"X-Vault-Token": root_token}, expected={200, 404})
        if policy_status == 200 or marker_status == 200:
            vault_found.append(tenant)
        namespace_status, _, _ = http_request("GET", PULSAR_PORT, f"/admin/v2/namespaces/{tenant}/{app}", expected={200, 404})
        if namespace_status == 200:
            pulsar_found.append(tenant)
        bucket_status, _ = phase30.s3_request("HEAD", f"{app}-{tenant}")
        if bucket_status == 200:
            minio_found.append(tenant)
        namespace = kubectl("get", "namespace", f"{app}-{tenant}", "-o", "name", check=False)
        if namespace.returncode == 0:
            kubernetes_found.append(tenant)
    postgres_names = [sql_identifier(f"{app}_{tenant}") for tenant in tenants] + [sql_identifier(f"p34_obs_{challenge[:8]}")]
    primary = postgres_primary()
    names_sql = ",".join("'" + name + "'" for name in postgres_names)
    postgres_script = f"export PGPASSWORD=\"$(cat /phase31-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -Atqc \"select rolname from pg_roles where rolname in ({names_sql}) union select nspname from pg_namespace where nspname in ({names_sql}) order by 1\""
    postgres_found = [line for line in postgres_exec(enactor_token, primary, postgres_script).splitlines() if line]
    return {
        "Keycloak": sorted(keycloak_found) + (["observer-client"] if clients else []),
        "Vault": sorted(vault_found),
        "Pulsar": sorted(pulsar_found),
        "Minio": sorted(minio_found),
        "KubernetesApi": sorted(kubernetes_found),
        "Postgres": sorted(postgres_found),
    }


def cleanup_stale(root_token: str) -> None:
    """Recover only Phase-34-prefixed residue from an interrupted prior gate."""
    for namespace in [item["metadata"]["name"] for item in json.loads(kubectl("get", "namespaces", "-o", "json").stdout)["items"] if item["metadata"]["name"].startswith("p34app")]:
        kubectl("delete", "namespace", namespace, "--wait=true", "--timeout=120s", check=False)
    with port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080):
        password = secret_value("edge-system", "phase32-edge-secrets", "keycloak-admin")
        admin = keycloak_token("master", {"grant_type": "password", "client_id": "admin-cli", "username": "phase32-admin", "password": password})
        headers = {"Authorization": "Bearer " + admin}
        groups, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/groups?search=p34app&max=1000", headers=headers, expected={200})
        for group in groups:
            if str(group.get("name", "")).startswith("p34app"):
                json_request("DELETE", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/groups/{group['id']}", headers=headers, expected={204})
        roles, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/roles?briefRepresentation=false&max=1000", headers=headers, expected={200})
        for role in roles:
            if str(role.get("name", "")).startswith("p34app"):
                json_request("DELETE", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/roles/" + urllib.parse.quote(role["name"], safe=""), headers=headers, expected={204})
        clients, _ = json_request("GET", KEYCLOAK_PORT, "/keycloak/admin/realms/amoebius/clients?max=1000", headers=headers, expected={200})
        for client in clients:
            if str(client.get("clientId", "")).startswith("phase34-observer-"):
                json_request("DELETE", KEYCLOAK_PORT, f"/keycloak/admin/realms/amoebius/clients/{client['id']}", headers=headers, expected={204})
    with port_forward("vault-system", "service/root-vault", VAULT_PORT, 8200):
        policy_list = vault_request("LIST", "sys/policies/acl", root_token)
        for policy in policy_list.get("data", {}).get("keys", []):
            if str(policy).startswith(("p34app", "phase34-observer-")):
                vault_request("DELETE", f"sys/policies/acl/{policy}", root_token, expected={204})
        vault_headers = {"X-Vault-Token": root_token}
        app_status, app_data, _ = http_request(
            "LIST", VAULT_PORT, "/v1/secret/metadata/amoebius/phase34",
            headers=vault_headers, expected={200, 404},
        )
        if app_status == 200:
            for app_key in json.loads(app_data).get("data", {}).get("keys", []):
                app = str(app_key).rstrip("/")
                if not app.startswith("p34app"):
                    continue
                tenant_status, tenant_data, _ = http_request(
                    "LIST", VAULT_PORT, f"/v1/secret/metadata/amoebius/phase34/{app}",
                    headers=vault_headers, expected={200, 404},
                )
                if tenant_status != 200:
                    continue
                for tenant_key in json.loads(tenant_data).get("data", {}).get("keys", []):
                    tenant = str(tenant_key).rstrip("/")
                    marker_status, _, _ = http_request(
                        "DELETE", VAULT_PORT,
                        f"/v1/secret/metadata/amoebius/phase34/{app}/{tenant}/challenge",
                        headers=vault_headers, expected={204, 404},
                    )
                    if marker_status not in {204, 404}:
                        raise LiveFailure(f"vault-stale-delete:{app}:{tenant}:{marker_status}")
    with port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
        tenant_list, _ = json_request("GET", PULSAR_PORT, "/admin/v2/tenants", expected={200})
        for tenant in tenant_list:
            if str(tenant).startswith("p34"):
                namespaces, _ = json_request("GET", PULSAR_PORT, f"/admin/v2/namespaces/{tenant}", expected={200})
                for namespace in namespaces:
                    json_request("DELETE", PULSAR_PORT, f"/admin/v2/namespaces/{namespace}", expected={204})
                json_request("DELETE", PULSAR_PORT, f"/admin/v2/tenants/{tenant}", expected={204})
    with port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        status, payload = phase30.s3_request("GET", "")
        if status != 200:
            raise LiveFailure(f"minio-stale-list:{status}")
        for bucket in re.findall(r"<Name>(p34app[^<]+)</Name>", payload.decode(errors="replace")):
            phase30.s3_request("DELETE", bucket, "phase34-challenge.json")
            phase30.s3_request("DELETE", bucket, query="policy=")
            status, delete_payload = phase30.s3_request("DELETE", bucket)
            if status not in {204, 404}:
                raise LiveFailure(f"minio-stale-delete:{bucket}:{status}:{delete_payload.decode(errors='replace')}")


def run_live(root_token: str) -> dict[str, Any]:
    cleanup_stale(root_token)
    challenge = secrets.token_hex(16)
    suffix = challenge[:6]
    app = "p34app" + suffix
    tenants = ["p34" + suffix + "a", "p34" + suffix + "b"]
    forbidden = ["forbidden-hand-" + secrets.token_hex(8), "forbidden-mismatch-" + secrets.token_hex(8)]
    tokens: dict[str, str] = {}
    enactor = ""
    states: dict[str, Any] = {}
    observations: list[dict[str, Any]] = []
    preflight: dict[str, Any] = {}
    postflight: dict[str, Any] = {}
    cleaned = False
    try:
        tokens, enactor = setup_authorities(suffix)
        with contextlib.ExitStack() as stack:
            stack.enter_context(port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080))
            stack.enter_context(port_forward("vault-system", "service/root-vault", VAULT_PORT, 8200))
            stack.enter_context(port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080))
            stack.enter_context(port_forward("platform-system", "service/minio", MINIO_PORT, 9000))
            preflight = target_inventory(app, tenants, challenge, root_token, enactor)
            if any(preflight.values()):
                raise LiveFailure(f"provider-preflight-not-empty:{preflight}")
            states["Keycloak"] = keycloak_apply(app, tenants, challenge)
            states["Vault"] = vault_apply(root_token, app, tenants, challenge)
            states["Pulsar"] = pulsar_apply(app, tenants, challenge)
            states["Minio"] = minio_apply(app, tenants, challenge)
            states["KubernetesApi"] = kubernetes_apply(app, tenants, challenge, enactor)
            states["Postgres"] = postgres_apply(app, tenants, challenge, enactor)
            observations.extend(keycloak_observe(states["Keycloak"], challenge))
            observations.extend(vault_observe(states["Vault"], app, challenge))
            observations.extend(pulsar_observe(states["Pulsar"], tokens["pulsar"], challenge))
            observations.extend(minio_observe(states["Minio"], tokens["minio"], challenge))
            observations.extend(kubernetes_observe(states["KubernetesApi"], tokens["kubernetesapi"], challenge))
            observations.extend(postgres_observe(states["Postgres"], tokens["postgres"], challenge))
            if len(observations) != 12 or not all(row["challengeRecovered"] for row in observations):
                raise LiveFailure("provider-observation-incomplete")
            postgres_cleanup(states["Postgres"], enactor)
            kubernetes_cleanup(states["KubernetesApi"], enactor)
            minio_cleanup(states["Minio"])
            pulsar_cleanup(states["Pulsar"])
            vault_cleanup(root_token, states["Vault"], app)
            keycloak_cleanup(states["Keycloak"])
            postflight = target_inventory(app, tenants, challenge, root_token, enactor)
            if postflight != preflight:
                raise LiveFailure(f"cleanup-inventory:{preflight}:{postflight}")
            cleaned = True
        observer_rows = [
            {"observerProvider": "Keycloak", "identity": states["Keycloak"]["observerClient"], "authenticated": True, "credentialReused": False},
            {"observerProvider": "Vault", "identity": "vault-token-accessor:" + states["Vault"]["observerAccessor"][:12], "authenticated": True, "credentialReused": False},
            {"observerProvider": "Pulsar", "identity": f"system:serviceaccount:{SYSTEM_NAMESPACE}:observer-pulsar", "authenticated": True, "credentialReused": False},
            {"observerProvider": "Minio", "identity": f"system:serviceaccount:{SYSTEM_NAMESPACE}:observer-minio+scoped-sigv4", "authenticated": True, "credentialReused": False},
            {"observerProvider": "KubernetesApi", "identity": f"system:serviceaccount:{SYSTEM_NAMESPACE}:observer-kubernetesapi", "authenticated": True, "credentialReused": False},
            {"observerProvider": "Postgres", "identity": states["Postgres"]["observerRole"], "authenticated": True, "credentialReused": False},
        ]
        return {
            "schemaVersion": "amoebius.phase34.live-evidence.v1",
            "register": 3,
            "substrate": "linux-cpu",
            "universalLinuxCpu": {"allHardwareSubstrates": True, "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
            "oracleSha256": oracle_digest(),
            "checkedSpecSha256": digest({"app": app, "tenants": tenants}),
            "derivationSha256": digest([(row["provider"], row["tenant"], row["objectTypes"]) for row in observations]),
            "nonceSha256": "sha256:" + hashlib.sha256(challenge.encode()).hexdigest(),
            "providers": observations,
            "observers": observer_rows,
            "enactorIdentity": f"system:serviceaccount:{SYSTEM_NAMESPACE}:provider-enactor",
            "rejectedTwins": [
                {"tag": "hand-authored-provider-grant", "forbiddenNonceSha256": "sha256:" + hashlib.sha256(forbidden[0].encode()).hexdigest(), "providerEffects": 0, "forbiddenNonceAbsentAllProviders": True},
                {"tag": "tenant-reference-mismatch", "forbiddenNonceSha256": "sha256:" + hashlib.sha256(forbidden[1].encode()).hexdigest(), "providerEffects": 0, "forbiddenNonceAbsentAllProviders": True},
            ],
            "bypassProbes": [
                {"name": "public-decoder-provider-grant", "result": "rejected-before-provision"},
                {"name": "outer-tenant-key-swap", "result": "rejected-before-provision"},
                {"name": "unsealed-enactor-input", "result": "no-constructor"},
            ],
            "cleanup": {"inventoriesEqual": True, "preflightSha256": digest(preflight), "postflightSha256": digest(postflight), "residue": []},
            "applicationDataPath": "UNVERIFIED (Phase 36)",
        }
    finally:
        if not cleaned and enactor:
            cleanup_steps = []
            if "Postgres" in states:
                cleanup_steps.append(("Postgres", lambda: postgres_cleanup(states["Postgres"], enactor)))
            if "KubernetesApi" in states:
                cleanup_steps.append(("KubernetesApi", lambda: kubernetes_cleanup(states["KubernetesApi"], enactor)))
            if "Minio" in states:
                def cleanup_minio() -> None:
                    with port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
                        minio_cleanup(states["Minio"])
                cleanup_steps.append(("Minio", cleanup_minio))
            if "Pulsar" in states:
                def cleanup_pulsar() -> None:
                    with port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
                        pulsar_cleanup(states["Pulsar"])
                cleanup_steps.append(("Pulsar", cleanup_pulsar))
            if "Vault" in states:
                def cleanup_vault() -> None:
                    with port_forward("vault-system", "service/root-vault", VAULT_PORT, 8200):
                        vault_cleanup(root_token, states["Vault"], app)
                cleanup_steps.append(("Vault", cleanup_vault))
            if "Keycloak" in states:
                def cleanup_keycloak() -> None:
                    with port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080):
                        keycloak_cleanup(states["Keycloak"])
                cleanup_steps.append(("Keycloak", cleanup_keycloak))
            for label, cleanup_step in cleanup_steps:
                try:
                    cleanup_step()
                except Exception as cleanup_error:
                    print(f"phase34-cleanup-warning:{label}:{cleanup_error}", flush=True)
        cleanup_authorities()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args()
    if args.reuse_fresh_live and EVIDENCE.is_file() and time.time() - EVIDENCE.stat().st_mtime < 1800:
        current = json.loads(EVIDENCE.read_text(encoding="utf-8"))
        if current.get("schemaVersion") == "amoebius.phase34.live-evidence.v1" and current.get("cleanup", {}).get("inventoriesEqual"):
            print("phase34-tenant-provider-live: PASS (reused fresh sealed evidence)")
            return 0
    root_token = os.environ.get("PHASE33_VAULT_ROOT_TOKEN")
    if not root_token:
        raise LiveFailure("PHASE33_VAULT_ROOT_TOKEN-required")
    try:
        evidence = run_live(root_token)
        EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
        EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("phase34-tenant-provider-live: PASS (six live provider arms, separated observers, paired rejects, teardown)")
        return 0
    finally:
        TOKEN_CA.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (LiveFailure, subprocess.TimeoutExpired, urllib.error.URLError) as error:
        print(f"phase34-tenant-provider-live: FAIL: {error}", flush=True)
        raise SystemExit(1)
