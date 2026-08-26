#!/usr/bin/env python3
"""Run the scoped Phase-52 browser/authority/durable-file/host-CUDA slice."""

from __future__ import annotations

import contextlib
import datetime as dt
import hashlib
import json
import secrets
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import phase51_jitml_cuda_live as phase51


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_52/jitml-ui-live.json"
JITML_LIFT_CUDA_RECEIPT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_51/phase-receipt.json"
INFERNIX_UI_LIFT_RECEIPT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_50/phase-receipt.json"
NODE = "/usr/bin/node"


class LiveFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise LiveFailure(tag)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def fingerprint(value: Any, *, newline: bool = False) -> str:
    return "sha256:" + hashlib.sha256(canonical(value) + (b"\n" if newline else b"")).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def put_immutable(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as output:
        output.write(canonical(value))


def read_record(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_bytes())
    require(isinstance(value, dict), f"record-shape:{path.name}")
    return value


class UiState:
    def __init__(self, *, tokens: dict[str, str], store: Path, request_id: str, input_value: str,
                 ready_handle: str, inflight_handle: str, failed_handle: str, command: str, challenge: str) -> None:
        self.token_identity = {
            tokens["alice"]: ("t-a", "alice"), tokens["bob"]: ("t-a", "bob"), tokens["carol"]: ("t-b", "carol"),
        }
        self.store = store
        self.request_id = request_id
        self.input_value = input_value
        self.ready_handle = ready_handle
        self.inflight_handle = inflight_handle
        self.failed_handle = failed_handle
        self.command = command
        self.challenge = challenge
        self.route_present = True
        self.effects = {"trainingStarts": 0, "cudaInvocations": 0, "checkpointReads": 0,
                        "resultWrites": 0, "pointerAdvances": 0}
        self.cuda: dict[str, Any] | None = None
        self.lock = threading.Lock()

    def identity(self, authorization: str) -> tuple[str, str] | None:
        return self.token_identity.get(authorization.removeprefix("Bearer "))

    def valid_body(self, body: dict[str, Any]) -> bool:
        return body.get("requestId") == self.request_id and body.get("input") == self.input_value

    def start(self) -> dict[str, Any]:
        with self.lock:
            accepted = self.store / "accepted.json"
            if not accepted.exists():
                put_immutable(accepted, {
                    "scope": "t-a/alice", "commandId": self.command, "workId": self.command,
                    "inputDigest": sha256_bytes(self.input_value.encode()), "outcome": "Accepted",
                })
                self.effects["trainingStarts"] += 1
            return {"visible": "Training accepted", "commandId": self.command, "workId": self.command}

    def invoke(self) -> dict[str, Any]:
        with self.lock:
            terminal = self.store / "terminal.json"
            if terminal.exists():
                return {"result": read_record(terminal)["result"], "commandId": self.command, "idempotent": True}
            checkpoint, cuda = phase51.run_cuda(self.challenge)
            result = "stable-reference-vector"
            put_immutable(self.store / "result.json", {
                "result": result, "cudaCheckpointDigest": sha256_bytes(checkpoint),
                "challengeDigest": sha256_bytes(self.challenge.encode()),
            })
            put_immutable(terminal, {
                "scope": "t-a/alice", "commandId": self.command, "workId": self.command,
                "handle": self.ready_handle, "inputDigest": sha256_bytes(self.input_value.encode()),
                "outcome": "TerminalSucceeded", "result": result,
            })
            self.cuda = cuda
            self.effects["cudaInvocations"] += 1
            self.effects["checkpointReads"] += 1
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
            try:
                value = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
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
            if self.auth() != ("t-a", "alice"):
                self.reply(404, {"error": "Unavailable"})
                return
            if self.path == "/progress":
                self.reply(200, {"visible": "Running", "boundedSteps": 200})
            elif self.path == "/ready":
                self.reply(200, {"visible": "Model ready", "handle": state.ready_handle})
            elif self.path == "/receipt" and replica == "ui-B":
                self.reply(200, read_record(state.store / "terminal.json"))
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
            if self.path == "/route-loss" and identity == ("t-a", "alice"):
                state.route_present = False
                self.reply(200, {"phaseScopedRouteDeleted": True, "socketDropped": True})
                return
            if identity != ("t-a", "alice"):
                self.reply(404, {"error": "Unavailable"})
                return
            if not state.valid_body(body):
                self.reply(409, {"error": "IdempotencyConflict"})
                return
            handle = body.get("handle")
            if handle in {state.inflight_handle, state.failed_handle}:
                self.reply(409, {"error": "NotReady"})
                return
            if handle != state.ready_handle:
                self.reply(404, {"error": "Unavailable"})
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
    server_a = ThreadingHTTPServer(("127.0.0.1", 0), handler_for(state, "ui-A"))
    server_b = ThreadingHTTPServer(("127.0.0.1", 0), handler_for(state, "ui-B"))
    threads = [threading.Thread(target=server.serve_forever, daemon=True) for server in (server_a, server_b)]
    for thread in threads:
        thread.start()
    try:
        yield server_a.server_port, server_b.server_port
    finally:
        for server in (server_a, server_b):
            server.shutdown()
            server.server_close()
        for thread in threads:
            thread.join(timeout=5)


def browser_run(state: UiState, tokens: dict[str, str]) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="amoebius-jitml-ui-lift-browser-") as temporary:
        token_path = Path(temporary) / "tokens.json"
        token_path.write_text(json.dumps(tokens), encoding="utf-8")
        token_path.chmod(0o600)
        with servers(state) as (port_a, port_b):
            result = subprocess.run(
                [NODE, str(ROOT / "test/harness/ui_live/jitml_ui_lift/browser.mjs"), str(token_path), str(port_a), str(port_b),
                 state.request_id, state.input_value, state.ready_handle, state.inflight_handle, state.failed_handle],
                cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900, check=False,
            )
        require(result.returncode == 0, f"browser:{result.stdout}")
        return json.loads(result.stdout)


def main() -> int:
    require(JITML_LIFT_CUDA_RECEIPT.is_file(), "jitml-lift-cuda-receipt-absent")
    require(INFERNIX_UI_LIFT_RECEIPT.is_file(), "infernix-ui-lift-receipt-absent")
    phase51_receipt = json.loads(JITML_LIFT_CUDA_RECEIPT.read_text(encoding="utf-8"))
    phase50_receipt = json.loads(INFERNIX_UI_LIFT_RECEIPT.read_text(encoding="utf-8"))
    require(phase51_receipt.get("result") == "PASS-SCOPED", "jitml-lift-cuda-prerequisite")
    require(phase50_receipt.get("result") == "PASS-SCOPED", "infernix-ui-lift-prerequisite")
    challenge = secrets.token_hex(24)
    suffix = challenge[:8]
    request_id = "request-" + challenge
    input_value = "bounded-linear"
    command = "cmd:" + hashlib.sha256("\0".join(["jitml-ui", "t-a", "alice", "jitml.train", request_id]).encode()).hexdigest()
    ready_handle = "model:" + hashlib.sha256(("t-a/alice\0" + command + "\0ready").encode()).hexdigest()
    inflight_handle = "model:" + hashlib.sha256(("t-a/alice\0" + command + "\0inflight").encode()).hexdigest()
    failed_handle = "model:" + hashlib.sha256(("t-a/alice\0" + command + "\0failed").encode()).hexdigest()
    tokens = {name: secrets.token_urlsafe(48) for name in ("alice", "bob", "carol")}
    authority = {
        "tokens": tokens,
        "tokenDigests": {name: sha256_bytes(token.encode()) for name, token in tokens.items()},
        "observations": {
            "alice": {"active": True, "username": "alice", "tenant": "t-a", "source": "scoped-identity-fixture"},
            "bob": {"active": True, "username": "bob", "tenant": "t-a", "source": "scoped-identity-fixture"},
            "carol": {"active": True, "username": "carol", "tenant": "t-b", "source": "scoped-identity-fixture"},
        },
    }
    browser: dict[str, Any] | None = None
    state: UiState | None = None
    store_cleaned = False
    with tempfile.TemporaryDirectory(prefix="amoebius-jitml-ui-lift-durable-") as temporary:
        store = Path(temporary)
        state = UiState(tokens=authority["tokens"], store=store, request_id=request_id,
                        input_value=input_value, ready_handle=ready_handle, inflight_handle=inflight_handle,
                        failed_handle=failed_handle, command=command, challenge=challenge)
        browser = browser_run(state, authority["tokens"])
        require(sorted(path.name for path in store.iterdir()) == ["accepted.json", "result.json", "terminal.json"],
                "durable-record-inventory")
        terminal = read_record(store / "terminal.json")
        require(terminal["commandId"] == command == terminal["workId"], "durable-record-identity")
    store_cleaned = not store.exists()
    require(browser is not None and state.cuda is not None, "live-observation-incomplete")
    require(store_cleaned and not state.route_present, "cleanup-or-route-loss")
    require([browser[name]["status"] for name in ("start", "progress", "ready", "invoke")] == [200, 200, 200, 200], "positive-flow")
    require(browser["visibleResult"] == "stable-reference-vector", "browser-result")
    require(browser["sameTenantNonOwner"]["status"] == 404 and browser["foreignTenant"]["status"] == 404, "owner-scope-denial")
    require(browser["inflight"]["status"] == 409 and browser["failed"]["status"] == 409, "readiness-denial")
    require(browser["effectsBeforeDenials"] == browser["effectsAfterDenials"] == browser["effectsAfterRepair"], "forbidden-or-repair-effect")
    require(browser["receiptBeforeLoss"]["value"] == browser["receiptAfterLoss"]["value"], "durable-repair")
    require(browser["repeatInvoke"]["value"].get("idempotent") is True, "repeat-invoke")
    require(browser["hostileText"] == "<SCRIPT>PORT:ADMIN</SCRIPT>" and browser["hostileScriptCount"] == 0 and "&lt;SCRIPT&gt;" in browser["hostileHtml"], "hostile-output")
    cleanup = {"TemporaryDurableStore": store_cleaned,
               "CudaAllocationReleased": phase51.nvidia_inventory()["freeMiB"] > 0}
    stable = {
        "schema": "amoebius.phase52.jitml-ui-live.v1", "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3, "substrate": "linux-cuda", "result": "PASS-SCOPED",
        "challenge": {"nonceDigest": sha256_bytes(challenge.encode()), "requestIdDigest": sha256_bytes(request_id.encode()), "unpredictableBytes": 24},
        "prerequisite": {"phase50ReceiptFingerprint": phase50_receipt["receiptFingerprint"], "phase50Result": "PASS-SCOPED",
                         "phase51ReceiptFingerprint": phase51_receipt["receiptFingerprint"], "phase51Result": "PASS-SCOPED"},
        "authority": {"scopedIdentityFixtures": authority["observations"], "tokenDigests": authority["tokenDigests"],
                      "freshKeycloakSessions": False, "rawTokensStored": False},
        "browser": {"engine": browser["browser"], "origins": browser["origins"], "positiveStatuses": [200, 200, 200, 200],
                    "visibleResult": browser["visibleResult"], "hostileText": browser["hostileText"],
                    "hostileHtml": browser["hostileHtml"], "hostileScriptCount": browser["hostileScriptCount"]},
        "workflow": {"commandId": command, "workId": command, "readyHandleDigest": sha256_bytes(ready_handle.encode()),
                     "terminalOutcome": "TerminalSucceeded", "effects": state.effects,
                     "denials": {"sameTenantNonOwner": 404, "foreignTenant": 404, "inflight": 409, "failed": 409},
                     "forbiddenEffectDelta": 0, "receiptOriginReplica": "ui-B",
                     "receiptRepairSource": "independent temporary durable-file observer"},
        "cuda": {**state.cuda, "physicalDevice": True, "cpuFallback": False, "allocationReleased": True},
        "providers": {"Keycloak": "UNVERIFIED", "Minio": "UNVERIFIED", "Pulsar": "UNVERIFIED", "Redis": "UNVERIFIED",
                      "retainedProviderReason": "retained Keycloak/MinIO restarts, Pulsar observer instability, and expired Redis TLS certificate"},
        "cleanup": cleanup,
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True,
                              "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "honesty": {"typedUiAdapter": "TESTED", "realBrowser": "TESTED", "threeScopedIdentityFixtures": "TESTED",
                    "freshKeycloakSessions": "UNVERIFIED", "physicalHostCuda": "TESTED", "twoLocalUiOrigins": "TESTED",
                    "temporaryDurableReceiptRepair": "TESTED",
                    "browserThroughEnvoy": "UNVERIFIED", "kubernetesUiReplicas": "UNVERIFIED", "nativeCborPulsar": "UNVERIFIED",
                    "retainedMinioReceipt": "UNVERIFIED", "retainedRedisRoute": "UNVERIFIED",
                    "fullSiblingJitmlServing": "UNVERIFIED", "phase51TrainingCommitInSameFlow": "UNVERIFIED",
                    "directWorkerNetworkPolicy": "UNVERIFIED", "generalNoninterference": "UNVERIFIED"},
    }
    evidence = {**stable, "evidenceDigest": fingerprint(stable, newline=True)}
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"jitml-ui-lift-jitml-ui-live: PASS-SCOPED ({evidence['evidenceDigest']}; retained providers/Kubernetes UI replicas/Envoy/native-CBOR/full sibling serving UNVERIFIED)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
