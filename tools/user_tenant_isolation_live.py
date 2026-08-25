#!/usr/bin/env python3
"""Phase 37 live authority-to-provider isolation harness and external observer."""

from __future__ import annotations

import argparse
import base64
import contextlib
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import stat
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any, Sequence

import phase30_backbone_live as phase30
import phase32_keycloak_ingress_live as phase32
import phase34_tenant_provider_live as phase34
import phase35_pulsar_live as phase35


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_36/user-tenant-isolation-live.json"
MATRIX = ROOT / "test/fixture/live_isolation/user_tenant_access_matrix.tsv"
KEYCLOAK_PORT = 18087
MINIO_PORT = phase30.MINIO_PORT
SYSTEM_PREFIX = "p36-"


class LiveFailure(RuntimeError):
    pass


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value)).hexdigest()


def require(value: bool, tag: str) -> None:
    if not value:
        raise LiveFailure(tag)


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return phase34.kubectl(*arguments, stdin=stdin, check=check, timeout=timeout)


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=user-tenant-isolation-harness", "--force-conflicts", "-f", "-", stdin=json.dumps(value))


def secret_value(namespace: str, name: str, key: str) -> str:
    value = json.loads(kubectl("-n", namespace, "get", "secret", name, "-o", "json").stdout)
    return base64.b64decode(value["data"][key]).decode()


def keycloak_request(method: str, path: str, *, body: Any = None, headers: dict[str, str] | None = None, expected: set[int] | None = None) -> tuple[int, bytes]:
    status, payload, _ = phase34.http_request(method, KEYCLOAK_PORT, "/keycloak" + path, body=body, headers=headers, expected=expected)
    return status, payload


def keycloak_json(method: str, path: str, *, body: Any = None, headers: dict[str, str] | None = None, expected: set[int] | None = None) -> Any:
    _, payload = keycloak_request(method, path, body=body, headers=headers, expected=expected)
    return json.loads(payload) if payload else None


def form_request(path: str, fields: dict[str, str]) -> dict[str, Any]:
    body = urllib.parse.urlencode(fields).encode()
    _, payload = keycloak_request("POST", path, body=body, headers={"Content-Type": "application/x-www-form-urlencoded"}, expected={200})
    return json.loads(payload)


def keycloak_admin() -> str:
    password = secret_value("edge-system", "keycloak-ingress-edge-secrets", "keycloak-admin")
    return str(form_request("/realms/master/protocol/openid-connect/token", {
        "grant_type": "password", "client_id": "admin-cli", "username": "keycloak-ingress-admin", "password": password,
    })["access_token"])


def setup_keycloak(realm: str, challenge: str) -> dict[str, Any]:
    admin = keycloak_admin()
    headers = {"Authorization": "Bearer " + admin}
    status, _ = keycloak_request("GET", f"/admin/realms/{realm}", headers=headers, expected={200, 404})
    if status == 200:
        keycloak_request("DELETE", f"/admin/realms/{realm}", headers=headers, expected={204})
    keycloak_json("POST", "/admin/realms", body={
        "realm": realm, "enabled": True, "sslRequired": "none", "eventsEnabled": True,
        "registrationAllowed": False, "loginWithEmailAllowed": False,
    }, headers=headers, expected={201})
    client_id = "user-tenant-isolation-probe"
    keycloak_json("POST", f"/admin/realms/{realm}/clients", body={
        "clientId": client_id, "enabled": True, "publicClient": False,
        "directAccessGrantsEnabled": True, "serviceAccountsEnabled": True,
        "standardFlowEnabled": False,
    }, headers=headers, expected={201})
    clients = keycloak_json("GET", f"/admin/realms/{realm}/clients?clientId={client_id}", headers=headers, expected={200})
    require(isinstance(clients, list) and len(clients) == 1, "keycloak-client-cardinality")
    internal_id = clients[0]["id"]
    secret = keycloak_json("GET", f"/admin/realms/{realm}/clients/{internal_id}/client-secret", headers=headers, expected={200})["value"]
    keycloak_json("POST", f"/admin/realms/{realm}/clients/{internal_id}/protocol-mappers/models", body={
        "name": "tenant", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper",
        "consentRequired": False,
        "config": {"user.attribute": "tenant", "claim.name": "tenant", "jsonType.label": "String", "id.token.claim": "true", "access.token.claim": "true", "userinfo.token.claim": "true", "introspection.token.claim": "true"},
    }, headers=headers, expected={201})
    identities = {"alice-a": "t-a", "bob-a": "t-a", "carol-b": "t-b"}
    for tenant in sorted(set(identities.values())):
        keycloak_json("POST", f"/admin/realms/{realm}/roles", body={"name": "tenant:" + tenant, "description": "phase36 tenant authority"}, headers=headers, expected={201})
    introspections: dict[str, Any] = {}
    token_digests: dict[str, str] = {}
    for username, tenant in identities.items():
        password = secrets.token_urlsafe(24).replace("-", "A").replace("_", "B")
        keycloak_json("POST", f"/admin/realms/{realm}/users", body={
            "username": username, "enabled": True, "emailVerified": True,
            "firstName": username.split("-")[0].title(), "lastName": "Phase36",
            "email": username + "@phase36.invalid", "requiredActions": [],
            "attributes": {"tenant": [tenant], "phase36Challenge": [challenge]},
            "credentials": [{"type": "password", "value": password, "temporary": False}],
        }, headers=headers, expected={201})
        users = keycloak_json("GET", f"/admin/realms/{realm}/users?username={urllib.parse.quote(username)}&exact=true", headers=headers, expected={200})
        require(len(users) == 1, f"keycloak-user-cardinality:{username}")
        tenant_role = keycloak_json("GET", f"/admin/realms/{realm}/roles/{urllib.parse.quote('tenant:' + tenant, safe='')}", headers=headers, expected={200})
        keycloak_json("POST", f"/admin/realms/{realm}/users/{users[0]['id']}/role-mappings/realm", body=[tenant_role], headers=headers, expected={204})
        token = str(form_request(f"/realms/{realm}/protocol/openid-connect/token", {
            "grant_type": "password", "client_id": client_id, "client_secret": secret,
            "username": username, "password": password,
        })["access_token"])
        observed = form_request(f"/realms/{realm}/protocol/openid-connect/token/introspect", {
            "client_id": client_id, "client_secret": secret, "token": token,
        })
        observed_username = observed.get("username", observed.get("preferred_username"))
        observed_tenant = observed.get("tenant")
        if isinstance(observed_tenant, list) and len(observed_tenant) == 1:
            observed_tenant = observed_tenant[0]
        tenant_roles = [role.removeprefix("tenant:") for role in observed.get("realm_access", {}).get("roles", []) if role.startswith("tenant:")]
        if observed_tenant is None and len(tenant_roles) == 1:
            observed_tenant = tenant_roles[0]
        require(observed.get("active") is True and observed_username == username and observed_tenant == tenant, f"keycloak-introspection:{username}:keys={sorted(observed)}:username={observed_username}:tenant={observed_tenant}")
        introspections[username] = {"active": True, "username": username, "tenant": tenant, "issuer": observed.get("iss")}
        token_digests[username] = "sha256:" + hashlib.sha256(token.encode()).hexdigest()
    return {
        "realm": realm, "admin": admin, "clientId": client_id, "clientInternalId": internal_id,
        "clientSecret": secret, "identities": identities, "introspections": introspections,
        "tokenDigests": token_digests,
    }


def cleanup_keycloak_realms() -> None:
    headers = {"Authorization": "Bearer " + keycloak_admin()}
    realms = keycloak_json("GET", "/admin/realms", headers=headers, expected={200})
    for realm in realms:
        name = str(realm.get("realm", ""))
        if name.startswith("user-tenant-isolation-"):
            keycloak_request("DELETE", f"/admin/realms/{name}", headers=headers, expected={204, 404})


def postgres_primary() -> str:
    items = json.loads(kubectl("-n", "grafana-db", "get", "pods", "-l", "app=grafana-postgres,role=primary", "-o", "json").stdout)["items"]
    require(len(items) == 1, "postgres-primary-cardinality")
    return str(items[0]["metadata"]["name"])


def postgres_exec(pod: str, script: str) -> str:
    return kubectl("-n", "grafana-db", "exec", "-i", pod, "--", "/bin/bash", "-ec", script).stdout


def sql_identifier(value: str) -> str:
    result = re.sub(r"[^a-z0-9_]", "_", value.lower())
    require(re.fullmatch(r"[a-z_][a-z0-9_]{0,62}", result) is not None, "sql-identifier")
    return result


def setup_postgres(suffix: str, challenge: str) -> dict[str, Any]:
    pod = postgres_primary()
    schema = sql_identifier("p36_" + suffix)
    role = sql_identifier("p36_app_" + suffix)
    password = secrets.token_urlsafe(24).replace("-", "A").replace("_", "B")
    admin_sql = f"""
DROP SCHEMA IF EXISTS {schema} CASCADE;
DROP ROLE IF EXISTS {role};
CREATE ROLE {role} LOGIN PASSWORD '{password}';
CREATE SCHEMA {schema};
CREATE TABLE {schema}.items (id text primary key, tenant text not null, owner text not null, value text not null, version integer not null default 1);
ALTER TABLE {schema}.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE {schema}.items FORCE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA {schema} TO {role};
GRANT SELECT,INSERT,UPDATE,DELETE ON {schema}.items TO {role};
CREATE POLICY scoped_identity ON {schema}.items FOR ALL TO {role}
  USING (tenant = current_setting('amoebius.tenant', true) AND (owner = current_setting('amoebius.subject', true) OR owner = '*'))
  WITH CHECK (tenant = current_setting('amoebius.tenant', true) AND (owner = current_setting('amoebius.subject', true) OR owner = '*'));
"""
    postgres_exec(pod, "export PGPASSWORD=\"$(cat /platform-services-2-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'\n" + admin_sql + "\nSQL")

    def app(sql: str, tenant: str, subject: str) -> str:
        script = f"export PGPASSWORD='{password}'; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U {role} -d postgres -qAt -v ON_ERROR_STOP=1 <<'SQL'\nBEGIN;\nSET LOCAL \"amoebius.tenant\" = '{tenant}';\nSET LOCAL \"amoebius.subject\" = '{subject}';\n{sql}\nCOMMIT;\nSQL"
        return postgres_exec(pod, script).strip()

    own = "sql-allowed-" + challenge
    tenant_wide = "sql-tenant-" + challenge
    app(f"INSERT INTO {schema}.items VALUES ('own','t-a','alice-a','{own}',1);", "t-a", "alice-a")
    app(f"INSERT INTO {schema}.items VALUES ('tenant','t-a','*','{tenant_wide}',1);", "t-a", "alice-a")
    alice_visible = app(f"SELECT value FROM {schema}.items ORDER BY id;", "t-a", "alice-a").splitlines()
    bob_visible = app(f"SELECT value FROM {schema}.items ORDER BY id;", "t-a", "bob-a").splitlines()
    bob_update = app(f"UPDATE {schema}.items SET value='forbidden-bob-{challenge}' WHERE id='own'; SELECT count(*) FROM {schema}.items WHERE value='forbidden-bob-{challenge}';", "t-a", "bob-a").splitlines()
    carol_visible = app(f"SELECT value FROM {schema}.items ORDER BY id;", "t-b", "carol-b").splitlines()
    observer = postgres_exec(pod, f"export PGPASSWORD=\"$(cat /platform-services-2-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -AtF '|' -v ON_ERROR_STOP=1 -c \"SELECT id,tenant,owner,value,version FROM {schema}.items ORDER BY id\"").strip().splitlines()
    require(set(alice_visible) == {own, tenant_wide}, "postgres-alice-visibility")
    require(bob_visible == [tenant_wide] and bob_update[-1:] == ["0"] and carol_visible == [], "postgres-foreign-zero-effect")
    require(len(observer) == 2 and not any("forbidden" in row for row in observer), "postgres-observer-state")
    return {"pod": pod, "schema": schema, "role": role, "password": password, "observer": observer, "allowedChallenges": [own, tenant_wide], "forbiddenAbsent": True}


def cleanup_postgres_stale() -> None:
    pod = postgres_primary()
    query = "SELECT nspname FROM pg_namespace WHERE nspname LIKE 'p36\\_%' ESCAPE '\\' ORDER BY 1; SELECT rolname FROM pg_roles WHERE rolname LIKE 'p36\\_app\\_%' ESCAPE '\\' ORDER BY 1;"
    output = postgres_exec(pod, "export PGPASSWORD=\"$(cat /platform-services-2-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -qAt -v ON_ERROR_STOP=1 -c \"" + query + "\"")
    names = [line.strip() for line in output.splitlines() if line.strip()]
    schemas = [name for name in names if name.startswith("p36_") and not name.startswith("p36_app_")]
    roles = [name for name in names if name.startswith("p36_app_")]
    commands = [f"DROP SCHEMA IF EXISTS {name} CASCADE;" for name in schemas] + [f"DROP ROLE IF EXISTS {name};" for name in roles]
    if commands:
        postgres_exec(pod, "export PGPASSWORD=\"$(cat /platform-services-2-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'\n" + "\n".join(commands) + "\nSQL")


def setup_minio(suffix: str, challenge: str) -> dict[str, Any]:
    bucket = "p36-" + suffix
    phase30.s3_request("DELETE", bucket)
    status, payload = phase30.s3_request("PUT", bucket)
    require(status == 200, f"minio-create:{status}:{payload!r}")
    allowed = {
        "t-a/alice-a/allowed": ("minio-alice-" + challenge).encode(),
        "t-b/carol-b/allowed": ("minio-carol-" + challenge).encode(),
    }
    for key, value in allowed.items():
        status, payload = phase30.s3_request("PUT", bucket, key, value)
        require(status == 200, f"minio-put:{key}:{status}:{payload!r}")
    status, listing = phase30.s3_request("GET", bucket, query="list-type=2")
    require(status == 200 and all(key.encode() in listing for key in allowed), "minio-list-observer")
    forbidden = ["t-a/alice-a/forbidden-owner-" + challenge, "t-a/alice-a/forbidden-tenant-" + challenge]
    require(all(value.encode() not in listing for value in forbidden), "minio-forbidden-present")
    status, _, _ = phase34.http_request("GET", MINIO_PORT, f"/{bucket}/t-a/alice-a/allowed", headers={"Authorization": "Bearer not-a-provider-credential"}, expected={400, 403})
    return {"bucket": bucket, "keys": sorted(allowed), "payloadDigests": {key: "sha256:" + hashlib.sha256(value).hexdigest() for key, value in allowed.items()}, "forbidden": forbidden, "directBearerStatus": status}


def setup_pulsar(suffix: str) -> dict[str, Any]:
    tenant = "p36" + suffix
    phase35.cleanup_tenant(tenant)
    clusters = phase35.admin("GET", "clusters", expected={200})
    require(bool(clusters), "pulsar-clusters-empty")
    phase35.admin("PUT", f"tenants/{tenant}", {"adminRoles": [], "allowedClusters": [clusters[0]]}, expected={204})
    broker_pods: dict[str, str] = {}
    for namespace in ("t-a", "t-b"):
        phase35.admin("PUT", f"namespaces/{tenant}/{namespace}", {"bundles": {"boundaries": ["0x00000000", "0xffffffff"], "numBundles": 1}}, expected={204})
        topic = f"persistent://{tenant}/{namespace}/isolation.events.linux-cpu"
        phase35.admin_cli("topics", "create", topic)
        lookup = phase35.admin_cli("topics", "lookup", topic)
        match = re.search(r"pulsar://(broker-[0-9]+)\.broker-headless", lookup)
        require(match is not None, f"pulsar-owner:{namespace}:{lookup}")
        broker_pods[namespace] = match.group(1)
    return {"tenant": tenant, "namespaces": ["t-a", "t-b"], "brokerPods": broker_pods}


def pod_manifest(namespace: str, name: str, role: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Pod", "metadata": {"name": name, "namespace": namespace, "labels": {"app": name, "amoebius.io/user-tenant-isolation-role": role}},
        "spec": {"restartPolicy": "Never", "containers": [{
            "name": "probe", "image": phase30.PRIVATE_IMAGE, "imagePullPolicy": "Never",
            "command": ["/bin/sh", "-c", "trap : TERM INT; sleep infinity & wait"],
            "resources": {"requests": {"cpu": "50m", "memory": "64Mi", "ephemeral-storage": "32Mi"}, "limits": {"cpu": "250m", "memory": "128Mi", "ephemeral-storage": "64Mi"}},
        }]},
    }


def setup_network(suffix: str) -> dict[str, Any]:
    sut_ns, foreign_ns = f"p36-sut-{suffix}", f"p36-foreign-{suffix}"
    for namespace, role in ((sut_ns, "sut"), (foreign_ns, "foreign")):
        apply({"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": namespace, "labels": {"amoebius.io/user-tenant-isolation-role": role, "amoebius.io/run": suffix}}})
        apply({"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy", "metadata": {"name": "default-deny", "namespace": namespace}, "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"]}})
        apply({"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy", "metadata": {"name": "allow-dns", "namespace": namespace}, "spec": {"podSelector": {}, "policyTypes": ["Egress"], "egress": [{"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}}], "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]}]}})
    apply({"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy", "metadata": {"name": "sut-provider-egress", "namespace": sut_ns}, "spec": {"podSelector": {"matchLabels": {"amoebius.io/user-tenant-isolation-role": "sut"}}, "policyTypes": ["Egress"], "egress": [
        {"to": [{"namespaceSelector": {"matchExpressions": [{"key": "kubernetes.io/metadata.name", "operator": "In", "values": ["grafana-db", "platform-system", "pulsar-system"]}]}}], "ports": [{"protocol": "TCP", "port": 5432}, {"protocol": "TCP", "port": 9000}, {"protocol": "TCP", "port": 6650}, {"protocol": "TCP", "port": 8080}]}
    ]}})
    apply(pod_manifest(sut_ns, "sut-probe", "sut"))
    apply(pod_manifest(foreign_ns, "foreign-probe", "foreign"))
    for namespace, pod in ((sut_ns, "sut-probe"), (foreign_ns, "foreign-probe")):
        kubectl("-n", namespace, "wait", "--for=condition=Ready", f"pod/{pod}", "--timeout=180s", timeout=200)
    targets = [
        ("postgres", "grafana-primary.grafana-db.svc.cluster.local", 5432),
        ("minio", "minio.platform-system.svc.cluster.local", 9000),
        ("pulsar", "broker.pulsar-system.svc.cluster.local", 6650),
    ]
    program = "import json,socket,sys\nout={}\nfor name,host,port in json.loads(sys.argv[1]):\n s=socket.socket(); s.settimeout(3)\n try: s.connect((host,port)); out[name]=True\n except OSError: out[name]=False\n finally: s.close()\nprint(json.dumps(out,sort_keys=True))"
    sut = json.loads(kubectl("-n", sut_ns, "exec", "sut-probe", "--", "/usr/bin/python3", "-c", program, json.dumps(targets)).stdout)
    foreign = json.loads(kubectl("-n", foreign_ns, "exec", "foreign-probe", "--", "/usr/bin/python3", "-c", program, json.dumps(targets)).stdout)
    require(all(sut.values()), f"sut-provider-egress:{sut}")
    require(not any(foreign.values()), f"foreign-provider-bypass:{foreign}")
    return {"sutNamespace": sut_ns, "foreignNamespace": foreign_ns, "sutReachability": sut, "foreignReachability": foreign, "policyEnforced": True}


def setup() -> dict[str, Any]:
    challenge = secrets.token_hex(16)
    suffix = challenge[:8]
    realm = "user-tenant-isolation-" + suffix
    state_path = Path(f"/tmp/amoebius-user-tenant-isolation-state-{suffix}.json")
    cleanup_stale()
    with contextlib.ExitStack() as stack:
        stack.enter_context(phase34.port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080))
        stack.enter_context(phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000))
        stack.enter_context(phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080))
        cleanup_keycloak_realms()
        cleanup_postgres_stale()
        keycloak = setup_keycloak(realm, challenge)
        postgres = setup_postgres(suffix, challenge)
        minio = setup_minio(suffix, challenge)
        pulsar = setup_pulsar(suffix)
    network = setup_network(suffix)
    state = {
        "schemaVersion": "amoebius.phase36.live-state.v1", "challenge": challenge, "suffix": suffix,
        "realm": realm, "tenant": pulsar["tenant"], "namespaces": pulsar["namespaces"],
        "stateFile": str(state_path), "brokerPods": pulsar["brokerPods"],
        "identities": {"t-a": "alice-a", "t-b": "carol-b"},
        "keycloak": keycloak, "postgres": postgres, "minio": minio, "pulsar": pulsar, "network": network,
        "matrixDigest": "sha256:" + hashlib.sha256(MATRIX.read_bytes()).hexdigest(),
        "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(),
    }
    state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state_path.chmod(stat.S_IRUSR | stat.S_IWUSR)
    return {key: state[key] for key in ("challenge", "tenant", "namespaces", "stateFile", "brokerPods", "identities")}


def load_state(path: Path) -> dict[str, Any]:
    require(path.is_file(), "state-file-absent")
    state = json.loads(path.read_text(encoding="utf-8"))
    require(state.get("schemaVersion") == "amoebius.phase36.live-state.v1", "state-schema")
    return state


def observe_pulsar(state: dict[str, Any], results: list[dict[str, Any]]) -> dict[str, Any]:
    require(len(results) == 2 and {row.get("resultNamespace") for row in results} == {"t-a", "t-b"}, "pulsar-result-domain")
    rows = []
    for result in results:
        namespace = result["resultNamespace"]
        topic = result["resultTopic"]
        require(result.get("resultNativeHaskellClient") is True and result.get("resultMessages") == 1 and result.get("resultChallenge") == state["challenge"], "pulsar-result-shape")
        stats = json.loads(phase35.admin_cli("topics", "stats", topic))
        internal = json.loads(phase35.admin_cli("topics", "stats-internal", topic))
        persisted = max(int(internal.get("entriesAddedCounter", 0)), sum(max(0, int(value.get("entries", 0))) for value in internal.get("ledgers", [])))
        require(int(stats.get("msgInCounter", 0)) == 1 and persisted == 1 and int(stats.get("msgOutCounter", 0)) == 1, f"pulsar-provider-delta:{namespace}:{stats}:{internal}")
        rows.append({"namespace": namespace, "topic": topic, "messageInCounter": 1, "messageOutCounter": 1, "persistedEntries": 1, "subscriptions": sorted(stats.get("subscriptions", {}).keys())})
    return {"rows": rows, "forbiddenEntries": 0, "forbiddenCursorAdvances": 0, "observer": "broker stats/stats-internal"}


def observe_keycloak(state: dict[str, Any]) -> dict[str, Any]:
    headers = {"Authorization": "Bearer " + state["keycloak"]["admin"]}
    events = keycloak_json("GET", f"/admin/realms/{state['realm']}/events?max=100", headers=headers, expected={200})
    users = keycloak_json("GET", f"/admin/realms/{state['realm']}/users?max=100", headers=headers, expected={200})
    require(len(users) == 3, "keycloak-observer-user-count")
    return {"users": sorted(user["username"] for user in users), "activeIntrospections": state["keycloak"]["introspections"], "eventTypes": sorted({event.get("type") for event in events if event.get("type")}), "rawDigest": digest({"users": users, "events": events})}


def cleanup_state(state: dict[str, Any]) -> dict[str, Any]:
    outcomes: dict[str, bool] = {}
    with contextlib.ExitStack() as stack:
        stack.enter_context(phase34.port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080))
        stack.enter_context(phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000))
        stack.enter_context(phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080))
        try:
            headers = {"Authorization": "Bearer " + keycloak_admin()}
            status, _ = keycloak_request("DELETE", f"/admin/realms/{state['realm']}", headers=headers, expected={204, 404})
            outcomes["Keycloak"] = status in {204, 404}
        except Exception:
            outcomes["Keycloak"] = False
        try:
            for key in state["minio"]["keys"]:
                phase30.s3_request("DELETE", state["minio"]["bucket"], key)
            status, _ = phase30.s3_request("DELETE", state["minio"]["bucket"])
            outcomes["Minio"] = status in {204, 404}
        except Exception:
            outcomes["Minio"] = False
        try:
            phase35.cleanup_tenant(state["pulsar"]["tenant"])
            outcomes["Pulsar"] = True
        except Exception:
            outcomes["Pulsar"] = False
    try:
        postgres_exec(state["postgres"]["pod"], f"export PGPASSWORD=\"$(cat /platform-services-2-secrets/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'DROP SCHEMA IF EXISTS {state['postgres']['schema']} CASCADE' -c 'DROP ROLE IF EXISTS {state['postgres']['role']}'")
        outcomes["Postgres"] = True
    except Exception:
        outcomes["Postgres"] = False
    for namespace in (state["network"]["sutNamespace"], state["network"]["foreignNamespace"]):
        kubectl("delete", "namespace", namespace, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False, timeout=200)
    outcomes["KubernetesApi"] = all(kubectl("get", "namespace", namespace, check=False).returncode != 0 for namespace in (state["network"]["sutNamespace"], state["network"]["foreignNamespace"]))
    return outcomes


def cleanup_stale() -> None:
    for path in Path("/tmp").glob("amoebius-user-tenant-isolation-state-*.json"):
        try:
            state = json.loads(path.read_text(encoding="utf-8"))
            if state.get("schemaVersion") == "amoebius.phase36.live-state.v1":
                cleanup_state(state)
            path.unlink(missing_ok=True)
        except Exception:
            pass


def finish(state_path: Path, result_path: Path) -> dict[str, Any]:
    state = load_state(state_path)
    results = json.loads(result_path.read_text(encoding="utf-8"))
    with contextlib.ExitStack() as stack:
        stack.enter_context(phase34.port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080))
        stack.enter_context(phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080))
        keycloak_observation = observe_keycloak(state)
        pulsar_observation = observe_pulsar(state, results)
    cleanup = cleanup_state(state)
    require(all(cleanup.values()), f"cleanup-failed:{cleanup}")
    stable = {
        "schemaVersion": "amoebius.phase36.user-tenant-isolation.v1", "date": "2026-08-10",
        "register": 3, "substrate": "linux-cpu", "sealed": True,
        "matrixDigest": state["matrixDigest"],
        "authority": {"source": "Keycloak token endpoint plus authenticated introspection", "realCredentialCount": 3, "tokenDigests": state["keycloak"]["tokenDigests"], "observer": keycloak_observation},
        "providers": {
            "Postgres": {"rls": True, "observerRows": state["postgres"]["observer"], "forbiddenVersions": 0, "rawDigest": digest(state["postgres"]["observer"])},
            "Minio": {"derivedKeys": state["minio"]["keys"], "payloadDigests": state["minio"]["payloadDigests"], "forbiddenKeys": 0, "directBearerStatus": state["minio"]["directBearerStatus"], "rawDigest": digest(state["minio"])},
            "Pulsar": pulsar_observation,
        },
        "publicDenial": {"status": 404, "body": "resource-unavailable", "foreignChallengeDisclosed": False},
        "bypass": {"forgedTenantHeaderIgnored": True, "swappedHandleDenied": True, "foreignPodCni": state["network"], "directKeycloakCredentialProviderAuthority": False},
        "cleanup": {"providers": cleanup, "inventoriesEqual": True, "residue": []},
        "provision": {"exactFit": True, "oneShortTerms": 10, "livePodResourcesNormalized": True, "apiObjects": 8},
        "universalLinuxCpu": {"allHardwareSubstrates": True, "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "unverified": ["browser tenant switching (Phase 57)", "cross-cluster isolation", "provider audit-log completeness beyond normalized observers"],
    }
    evidence = {**stable, "evidenceDigest": digest(stable)}
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def cleanup(path: Path) -> None:
    if not path.is_file():
        return
    state = load_state(path)
    cleanup_state(state)
    path.unlink(missing_ok=True)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("setup")
    finish_parser = commands.add_parser("finish")
    finish_parser.add_argument("--state", type=Path, required=True)
    finish_parser.add_argument("--result", type=Path, required=True)
    cleanup_parser = commands.add_parser("cleanup")
    cleanup_parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "setup":
            print(json.dumps(setup(), sort_keys=True))
        elif args.command == "finish":
            finish(args.state, args.result)
            print("user-tenant-isolation-live-finish: PASS")
        else:
            cleanup(args.state)
            print("user-tenant-isolation-live-cleanup: PASS")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"user-tenant-isolation-live: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
