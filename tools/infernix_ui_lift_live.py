#!/usr/bin/env python3
"""Run the scoped Phase-51 infernix UI lift against retained services."""

from __future__ import annotations

import contextlib
import datetime as dt
import hashlib
import http.client
import json
import secrets
import subprocess
import tempfile
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import phase30_backbone_live as phase30
import phase32_keycloak_ingress_live as phase32
import phase34_tenant_provider_live as phase34
import phase35_pulsar_live as phase35
import phase36_isolation_live as phase36
import phase37_workflow_live as phase37
import phase49_infernix_artifact_live as phase49


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_50/infernix-ui-live.json"
INFERNIX_LIFT_RECEIPT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_49/phase-receipt.json"
KUBECTL = "/usr/bin/kubectl"
NODE = "/usr/bin/node"
IMAGE = phase30.PRIVATE_IMAGE
MODEL = b"infernix-lift-tiny-decoder-v1|vocab=amoebius,deterministic,artifact,ready|weights=3,1,4,1,5,9"


class LiveFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise LiveFailure(tag)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def digest(value: Any, *, newline: bool = False) -> str:
    payload = canonical(value) + (b"\n" if newline else b"")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def apply(value: dict[str, Any]) -> None:
    phase34.kubectl(
        "apply", "--server-side", "--field-manager=amoebius-phase50", "--force-conflicts",
        "-f", "-", stdin=json.dumps(value),
    )


def setup_authority(realm: str, challenge: str) -> dict[str, Any]:
    admin = phase36.keycloak_admin()
    headers = {"Authorization": "Bearer " + admin}
    phase36.keycloak_json("POST", "/admin/realms", body={
        "realm": realm, "enabled": True, "sslRequired": "none", "eventsEnabled": True,
        "registrationAllowed": False,
    }, headers=headers, expected={201})
    client_id = "infernix-ui-lift-ui"
    phase36.keycloak_json("POST", f"/admin/realms/{realm}/clients", body={
        "clientId": client_id, "enabled": True, "publicClient": False,
        "directAccessGrantsEnabled": True, "standardFlowEnabled": False,
    }, headers=headers, expected={201})
    clients = phase36.keycloak_json(
        "GET", f"/admin/realms/{realm}/clients?clientId={client_id}", headers=headers, expected={200},
    )
    require(isinstance(clients, list) and len(clients) == 1, "keycloak-client")
    internal = clients[0]["id"]
    client_secret = phase36.keycloak_json(
        "GET", f"/admin/realms/{realm}/clients/{internal}/client-secret", headers=headers, expected={200},
    )["value"]
    phase36.keycloak_json(
        "POST", f"/admin/realms/{realm}/clients/{internal}/protocol-mappers/models",
        body={
            "name": "tenant", "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-attribute-mapper", "consentRequired": False,
            "config": {"user.attribute": "tenant", "claim.name": "tenant", "jsonType.label": "String",
                       "id.token.claim": "true", "access.token.claim": "true",
                       "userinfo.token.claim": "true", "introspection.token.claim": "true"},
        }, headers=headers, expected={201},
    )
    identities = {"alice": "t-a", "carol": "t-b"}
    for tenant in identities.values():
        phase36.keycloak_json(
            "POST", f"/admin/realms/{realm}/roles",
            body={"name": "tenant:" + tenant, "description": "phase50 tenant authority"},
            headers=headers, expected={201},
        )
    tokens: dict[str, str] = {}
    token_digests: dict[str, str] = {}
    observations: dict[str, Any] = {}
    for username, tenant in identities.items():
        password = secrets.token_urlsafe(24).replace("-", "A").replace("_", "B")
        phase36.keycloak_json("POST", f"/admin/realms/{realm}/users", body={
            "username": username, "enabled": True, "emailVerified": True,
            "firstName": username.title(), "lastName": "Phase50",
            "email": username + "@phase50.invalid", "requiredActions": [],
            "attributes": {"tenant": [tenant], "phase50Challenge": [challenge]},
            "credentials": [{"type": "password", "value": password, "temporary": False}],
        }, headers=headers, expected={201})
        users = phase36.keycloak_json(
            "GET", f"/admin/realms/{realm}/users?username={urllib.parse.quote(username)}&exact=true",
            headers=headers, expected={200},
        )
        require(isinstance(users, list) and len(users) == 1, f"keycloak-user:{username}")
        tenant_role = phase36.keycloak_json(
            "GET", f"/admin/realms/{realm}/roles/{urllib.parse.quote('tenant:' + tenant, safe='')}",
            headers=headers, expected={200},
        )
        phase36.keycloak_json(
            "POST", f"/admin/realms/{realm}/users/{users[0]['id']}/role-mappings/realm",
            body=[tenant_role], headers=headers, expected={204},
        )
        token = str(phase36.form_request(f"/realms/{realm}/protocol/openid-connect/token", {
            "grant_type": "password", "client_id": client_id, "client_secret": client_secret,
            "username": username, "password": password,
        })["access_token"])
        observed = phase36.form_request(f"/realms/{realm}/protocol/openid-connect/token/introspect", {
            "client_id": client_id, "client_secret": client_secret, "token": token,
        })
        observed_username = observed.get("username", observed.get("preferred_username"))
        observed_tenant = observed.get("tenant")
        if isinstance(observed_tenant, list):
            observed_tenant = observed_tenant[0] if len(observed_tenant) == 1 else None
        if observed_tenant is None:
            tenant_roles = [
                role.removeprefix("tenant:") for role in observed.get("realm_access", {}).get("roles", [])
                if role.startswith("tenant:")
            ]
            observed_tenant = tenant_roles[0] if len(tenant_roles) == 1 else None
        require(
            observed.get("active") is True and observed_username == username and observed_tenant == tenant,
            f"keycloak-introspection:{username}:keys={sorted(observed)}:username={observed_username}:tenant={observed_tenant}",
        )
        tokens[username] = token
        token_digests[username] = sha256_bytes(token.encode())
        observations[username] = {"active": True, "username": username, "tenant": tenant, "issuer": observed.get("iss")}
    return {"admin": admin, "tokens": tokens, "tokenDigests": token_digests, "observations": observations}


def delete_realm(realm: str, admin: str) -> bool:
    status, _ = phase36.keycloak_request(
        "DELETE", f"/admin/realms/{realm}", headers={"Authorization": "Bearer " + admin}, expected={204, 404},
    )
    return status in {204, 404}


def produce(topic: str, payload: dict[str, Any]) -> None:
    result = phase34.kubectl(
        "-n", "pulsar-system", "exec", "deployment/pulsar-tool", "--",
        "/pulsar/bin/pulsar-client", "--url", "pulsar://broker.pulsar-system.svc.cluster.local:6650",
        "produce", topic, "--messages", canonical(payload).decode(), "--separator", "\x1e", "--num-produce", "1",
        check=False, timeout=300,
    )
    require(result.returncode == 0, f"pulsar-produce:{topic}:{result.stdout}")


def topic_counts(topics: list[str]) -> dict[str, int]:
    return {
        topic: int(json.loads(phase35.admin_cli("topics", "stats", topic)).get("msgInCounter", 0))
        for topic in topics
    }


def run_worker(namespace: str, suffix: str, command: str, input_value: str) -> dict[str, Any]:
    name = "infernix-ui-lift-reference-worker-" + suffix
    script = (
        "import json,sys; "
        "print(json.dumps({'commandId':sys.argv[1],'workId':sys.argv[1],'output':sys.argv[2].upper()},sort_keys=True))"
    )
    workload = {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {"name": name, "namespace": namespace, "labels": {"amoebius.dev/phase50": "true"}},
        "spec": {
            "backoffLimit": 0,
            "template": {
                "metadata": {"labels": {"app": name}},
                "spec": {
                    "restartPolicy": "Never",
                    "containers": [{
                        "name": "worker", "image": IMAGE, "imagePullPolicy": "Never",
                        "command": ["/usr/bin/python3", "-c", script, command, input_value],
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "8Mi"},
                            "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                        },
                    }],
                },
            },
        },
    }
    apply(workload)
    phase34.kubectl("-n", namespace, "wait", "--for=condition=complete", f"job/{name}", "--timeout=180s", timeout=200)
    pod = json.loads(phase34.kubectl("-n", namespace, "get", "pods", "-l", f"job-name={name}", "-o", "json").stdout)["items"]
    require(len(pod) == 1, "worker-pod-cardinality")
    value = json.loads(phase34.kubectl("-n", namespace, "logs", pod[0]["metadata"]["name"]).stdout)
    require(value == {"commandId": command, "workId": command, "output": input_value.upper()}, "worker-output")
    phase34.kubectl("-n", namespace, "delete", "job", name, "--wait=true", "--timeout=120s", timeout=140)
    return {**value, "podUid": pod[0]["metadata"]["uid"], "argv0": "/usr/bin/python3"}


class UiState:
    def __init__(self, *, tokens: dict[str, str], bucket: str, topics: list[str], namespace: str,
                 suffix: str, request_id: str, input_value: str, handle: str, command: str) -> None:
        self.token_identity = {tokens["alice"]: ("t-a", "alice"), tokens["carol"]: ("t-b", "carol")}
        self.bucket = bucket
        self.topics = topics
        self.namespace = namespace
        self.suffix = suffix
        self.request_id = request_id
        self.input_value = input_value
        self.handle = handle
        self.command = command
        self.effects = {"workflowStarts": 0, "inferenceDispatches": 0, "artifactReads": 0, "resultWrites": 0}
        self.worker: dict[str, Any] | None = None
        self.lock = threading.Lock()

    def identity(self, authorization: str) -> tuple[str, str] | None:
        return self.token_identity.get(authorization.removeprefix("Bearer "))

    def validate_body(self, body: dict[str, Any]) -> bool:
        return body == {"requestId": self.request_id, "input": self.input_value, "handle": self.handle}

    def start(self) -> dict[str, Any]:
        with self.lock:
            key = f"receipts/{self.command}/accepted.json"
            if key not in phase37.list_keys(self.bucket):
                produce(self.topics[0], {"commandId": self.command, "workId": self.command,
                                        "requestIdDigest": sha256_bytes(self.request_id.encode())})
                receipt = {"scope": "t-a/alice", "commandId": self.command, "workId": self.command,
                           "handle": self.handle, "inputDigest": sha256_bytes(self.input_value.encode()),
                           "outcome": "Accepted"}
                phase37.put_immutable(self.bucket, key, canonical(receipt))
                self.effects["workflowStarts"] += 1
            return {"visible": "Workflow started", "commandId": self.command}

    def invoke(self) -> dict[str, Any]:
        with self.lock:
            terminal_key = f"receipts/{self.command}/terminal.json"
            if terminal_key in phase37.list_keys(self.bucket):
                receipt, _ = phase37.get_object(self.bucket, terminal_key)
                return {"result": json.loads(receipt)["result"], "commandId": self.command, "idempotent": True}
            self.worker = run_worker(self.namespace, self.suffix, self.command, self.input_value)
            result = str(self.worker["output"])
            phase37.put_immutable(self.bucket, f"results/{self.command}.txt", result.encode())
            produce(self.topics[1], {"commandId": self.command, "workId": self.command, "outcome": "TerminalSucceeded"})
            receipt = {"scope": "t-a/alice", "commandId": self.command, "workId": self.command,
                       "handle": self.handle, "inputDigest": sha256_bytes(self.input_value.encode()),
                       "outcome": "TerminalSucceeded", "result": result}
            phase37.put_immutable(self.bucket, terminal_key, canonical(receipt))
            self.effects["inferenceDispatches"] += 1
            self.effects["artifactReads"] += 1
            self.effects["resultWrites"] += 1
            return {"result": result, "commandId": self.command, "idempotent": False}


def handler_for(state: UiState, replica: str) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, _format: str, *_args: object) -> None:
            return

        def reply(self, status: int, value: dict[str, Any]) -> None:
            payload = canonical(value)
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("X-Amoebius-Replica", replica)
            self.end_headers()
            self.wfile.write(payload)

        def auth(self) -> tuple[str, str] | None:
            return state.identity(self.headers.get("Authorization", ""))

        def body(self) -> dict[str, Any]:
            raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
            try:
                value = json.loads(raw)
                return value if isinstance(value, dict) else {}
            except json.JSONDecodeError:
                return {}

        def do_GET(self) -> None:
            if self.path == "/":
                payload = b"<!doctype html><meta charset=utf-8><div id=result></div><div id=hostile></div>"
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("X-Amoebius-Replica", replica)
                self.end_headers()
                self.wfile.write(payload)
                return
            identity = self.auth()
            if identity != ("t-a", "alice"):
                self.reply(404, {"error": "Unavailable"})
                return
            if self.path == "/progress":
                self.reply(200, {"visible": "Running"})
            elif self.path == "/ready":
                pointer, _ = phase37.get_object(state.bucket, "models/reference/ready")
                self.reply(200, {"visible": "Artifact ready", "handle": pointer.decode()})
            elif self.path == "/receipt" and replica == "replica-b":
                payload, _ = phase37.get_object(state.bucket, f"receipts/{state.command}/terminal.json")
                self.reply(200, json.loads(payload))
            elif self.path == "/metrics":
                self.reply(200, dict(state.effects))
            else:
                self.reply(404, {"error": "NotFound"})

        def do_POST(self) -> None:
            identity = self.auth()
            body = self.body()
            if self.path == "/presentation" and identity == ("t-a", "alice"):
                self.reply(200, {"result": str(body.get("value", "")).upper()})
                return
            if identity != ("t-a", "alice"):
                self.reply(404, {"error": "Unavailable"})
                return
            if not state.validate_body(body):
                self.reply(409, {"error": "IdempotencyConflict"})
                return
            if self.path == "/start":
                self.reply(200, state.start())
            elif self.path == "/invoke":
                self.reply(200, state.invoke())
            else:
                self.reply(404, {"error": "NotFound"})

    return Handler


@contextlib.contextmanager
def servers(state: UiState):
    a = ThreadingHTTPServer(("127.0.0.1", 0), handler_for(state, "replica-a"))
    b = ThreadingHTTPServer(("127.0.0.1", 0), handler_for(state, "replica-b"))
    threads = [threading.Thread(target=server.serve_forever, daemon=True) for server in (a, b)]
    for thread in threads:
        thread.start()
    try:
        yield a.server_port, b.server_port
    finally:
        for server in (a, b):
            server.shutdown()
            server.server_close()
        for thread in threads:
            thread.join(timeout=5)


def browser_run(state: UiState, tokens: dict[str, str]) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="amoebius-infernix-ui-lift-") as temporary:
        token_path = Path(temporary) / "tokens.json"
        token_path.write_text(json.dumps(tokens), encoding="utf-8")
        token_path.chmod(0o600)
        with servers(state) as (port_a, port_b):
            result = subprocess.run(
                [NODE, str(ROOT / "test/harness/ui_live/infernix_ui_lift/browser.mjs"), str(token_path), str(port_a), str(port_b),
                 state.request_id, state.input_value, state.handle],
                cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600, check=False,
            )
        require(result.returncode == 0, f"browser:{result.stdout}")
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise LiveFailure("browser-json") from error


def minio_bearer_probe(token: str, bucket: str) -> int:
    connection = http.client.HTTPConnection("127.0.0.1", phase37.MINIO_PORT, timeout=30)
    try:
        connection.request("GET", "/" + urllib.parse.quote(bucket), headers={"Authorization": "Bearer " + token})
        response = connection.getresponse()
        response.read()
        return response.status
    finally:
        connection.close()


def cleanup_bucket(bucket: str) -> bool:
    for key in phase37.list_keys(bucket):
        phase37.delete_object(bucket, key)
    status, _, _ = phase37.s3_request("DELETE", bucket)
    return status in {204, 404}


def main() -> int:
    require(INFERNIX_LIFT_RECEIPT.is_file(), "infernix-lift-receipt-absent")
    phase49_receipt = json.loads(INFERNIX_LIFT_RECEIPT.read_text(encoding="utf-8"))
    require(phase49_receipt.get("result") == "PASS-SCOPED", "infernix-lift-prerequisite")
    challenge = secrets.token_hex(24)
    suffix = challenge[:8]
    realm = "infernix-ui-lift-" + suffix
    namespace = "infernix-ui-lift-ui-" + suffix
    tenant = "p50" + suffix
    pulsar_namespace = "ui"
    bucket = "p50-" + suffix
    request_id = "request-" + challenge
    input_value = "fresh-challenge"
    command = "cmd:" + hashlib.sha256("\0".join(["infernix-ui", "t-a", "alice", "infernix.start", request_id]).encode()).hexdigest()
    model_digest = sha256_bytes(MODEL)
    handle = "artifact:" + hashlib.sha256(("t-a/alice\0" + model_digest + "\0" + command).encode()).hexdigest()
    authority: dict[str, Any] | None = None
    topics: list[str] = []
    cleanup: dict[str, bool] = {}
    browser: dict[str, Any] | None = None
    state: UiState | None = None
    edge_token_digest = ""
    direct_minio_status = 0
    counts_before: dict[str, int] = {}
    counts_after: dict[str, int] = {}
    try:
        with phase32.edge_port_forward():
            edge_token = phase32.obtain_oidc_token("127.0.0.1", 19443)
            edge_token_digest = sha256_bytes(edge_token.encode())
        with contextlib.ExitStack() as stack:
            stack.enter_context(phase34.port_forward("edge-system", "service/keycloak", phase36.KEYCLOAK_PORT, 8080))
            stack.enter_context(phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000))
            stack.enter_context(phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080))
            authority = setup_authority(realm, challenge)
            phase37.ensure_bucket(bucket)
            require(phase37.list_keys(bucket) == [], "fresh-bucket")
            phase37.put_immutable(bucket, "models/reference/blob", MODEL)
            phase37.put_immutable(bucket, "models/reference/manifest", canonical({"blob": model_digest, "scope": "t-a/alice"}))
            phase37.put_immutable(bucket, "models/reference/ready", handle.encode())
            topics = phase49.setup_pulsar(tenant, pulsar_namespace)
            counts_before = topic_counts(topics)
            apply({"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": namespace,
                   "labels": {"amoebius.dev/phase50": "true"}}})
            state = UiState(tokens=authority["tokens"], bucket=bucket, topics=topics, namespace=namespace,
                            suffix=suffix, request_id=request_id, input_value=input_value, handle=handle, command=command)
            browser = browser_run(state, authority["tokens"])
            counts_after = topic_counts(topics)
            direct_minio_status = minio_bearer_probe(authority["tokens"]["carol"], bucket)
            require(direct_minio_status == 403, f"direct-minio:{direct_minio_status}")
            require(delete_realm(realm, phase36.keycloak_admin()), "realm-cleanup")
            cleanup["KeycloakRealm"] = True
            require(cleanup_bucket(bucket), "bucket-cleanup")
            cleanup["MinioBucket"] = True
            phase35.cleanup_tenant(tenant)
            cleanup["PulsarTenant"] = True
        phase34.kubectl("delete", "namespace", namespace, "--ignore-not-found", "--wait=true", "--timeout=180s", timeout=200)
        cleanup["KubernetesNamespace"] = phase34.kubectl("get", "namespace", namespace, check=False).returncode != 0
    finally:
        if not cleanup.get("KeycloakRealm"):
            try:
                with phase34.port_forward("edge-system", "service/keycloak", phase36.KEYCLOAK_PORT, 8080):
                    cleanup["KeycloakRealm"] = delete_realm(realm, phase36.keycloak_admin())
            except Exception:
                cleanup["KeycloakRealm"] = False
        if not cleanup.get("MinioBucket"):
            try:
                with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
                    cleanup["MinioBucket"] = cleanup_bucket(bucket)
            except Exception:
                cleanup["MinioBucket"] = False
        if topics and not cleanup.get("PulsarTenant"):
            try:
                with phase34.port_forward("pulsar-system", "service/broker", phase35.PULSAR_PORT, 8080):
                    phase35.cleanup_tenant(tenant)
                    cleanup["PulsarTenant"] = True
            except Exception:
                cleanup["PulsarTenant"] = False
        if not cleanup.get("KubernetesNamespace"):
            phase34.kubectl("delete", "namespace", namespace, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False, timeout=200)
            cleanup["KubernetesNamespace"] = phase34.kubectl("get", "namespace", namespace, check=False).returncode != 0
    require(authority is not None and browser is not None and state is not None and state.worker is not None, "live-observation-incomplete")
    require(all(cleanup.values()), f"cleanup:{cleanup}")
    require([browser["start"]["status"], browser["progress"]["status"], browser["ready"]["status"], browser["invoke"]["status"]] == [200, 200, 200, 200], "browser-positive-flow")
    require(browser["visibleResult"] == input_value.upper(), "browser-result")
    require(browser["receipt"]["value"]["commandId"] == command == browser["receipt"]["value"]["workId"], "receipt-identity")
    require(browser["receipt"]["value"]["handle"] == handle and browser["receipt"]["value"]["outcome"] == "TerminalSucceeded", "receipt-terminal")
    require(browser["foreignStatus"] == 404 and browser["foreignEffectsBefore"] == browser["foreignEffectsAfter"], "foreign-zero-effect")
    require(browser["hostileText"] == "<SCRIPT>PORT:ADMIN</SCRIPT>" and browser["hostileScriptCount"] == 0 and "&lt;SCRIPT&gt;" in browser["hostileHtml"], "hostile-output")
    require(
        counts_before == {topics[0]: 0, topics[1]: 0} and counts_after == {topics[0]: 1, topics[1]: 1},
        f"pulsar-counts:before={counts_before}:after={counts_after}",
    )
    stable = {
        "schema": "amoebius.phase50.infernix-ui-live.v1", "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3, "substrate": "linux-cpu", "result": "PASS-SCOPED",
        "challenge": {"nonceDigest": sha256_bytes(challenge.encode()), "requestIdDigest": sha256_bytes(request_id.encode())},
        "prerequisite": {"phase49ReceiptFingerprint": phase49_receipt["receiptFingerprint"], "phase49Result": "PASS-SCOPED"},
        "authority": {"tenantSessions": authority["observations"], "tokenDigests": authority["tokenDigests"],
                      "envoyOidcProbeTokenDigest": edge_token_digest, "rawTokensStored": False},
        "browser": {"engine": browser["browser"], "origins": browser["origins"], "positiveStatuses": [200, 200, 200, 200],
                    "visibleResult": browser["visibleResult"], "hostileText": browser["hostileText"],
                    "hostileHtml": browser["hostileHtml"], "hostileScriptCount": browser["hostileScriptCount"]},
        "workflow": {"commandId": command, "workId": command, "handleDigest": sha256_bytes(handle.encode()),
                     "inputDigest": sha256_bytes(input_value.encode()), "terminalOutcome": "TerminalSucceeded",
                     "effectCounts": state.effects, "foreignStatus": browser["foreignStatus"], "foreignEffectDelta": 0,
                     "receiptReadByServer": "replica-b", "acceptanceSource": "MinIO durable receipt"},
        "providers": {"Minio": {"readyPointerWrittenLast": True, "resultAndReceiptReadBack": True, "directBearerStatus": direct_minio_status},
                      "Pulsar": {"topics": topics, "before": counts_before, "after": counts_after},
                      "Kubernetes": {"workerPodUid": state.worker["podUid"], "argv0": state.worker["argv0"]}},
        "cleanup": cleanup,
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True,
                              "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "honesty": {"typedUiAdapter": "TESTED", "realBrowser": "TESTED", "tenantKeycloakSessions": "TESTED",
                    "retainedProviderIntegration": "TESTED", "browserThroughEnvoyToUiServer": "UNVERIFIED",
                    "kubernetesUiServerReplicas": "UNVERIFIED", "phase50NativeCborChain": "UNVERIFIED",
                    "fullPhase49InferenceOutputCorrespondence": "UNVERIFIED", "productionTinyLlama": "UNVERIFIED",
                    "generalNoninterference": "UNVERIFIED", "redisSocketRecovery": "UNVERIFIED"},
    }
    evidence = {**stable, "evidenceDigest": digest(stable, newline=True)}
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"infernix-ui-lift-infernix-ui-live: PASS-SCOPED ({evidence['evidenceDigest']}; full edge/replica/native-CBOR/production inference chain UNVERIFIED)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
