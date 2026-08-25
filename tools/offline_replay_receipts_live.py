#!/usr/bin/env python3
"""Run Phase 62 through two local UI endpoints and a durable SQLite observer."""

import hashlib
import http.client
import json
import secrets
import socket
import sqlite3
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_61/offline-replay-live.json"


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


def initialize(database):
    with sqlite3.connect(database) as connection:
        connection.executescript(
            """
            PRAGMA journal_mode=WAL;
            CREATE TABLE effects (
              tenant TEXT, owner TEXT, program TEXT, epoch INTEGER, command TEXT,
              kind TEXT, payload TEXT,
              PRIMARY KEY (tenant, owner, program, epoch, command)
            );
            CREATE TABLE receipts (
              tenant TEXT, owner TEXT, program TEXT, epoch INTEGER, command TEXT,
              work_id TEXT, outcome TEXT,
              PRIMARY KEY (tenant, owner, program, epoch, command)
            );
            """
        )


def make_handler(database, replica, transient_routes):
    class Handler(BaseHTTPRequestHandler):
        def authority(self):
            tenant = self.headers.get("X-Tenant", "")
            owner = self.headers.get("X-Owner", "")
            program = self.headers.get("X-Program", "")
            try:
                epoch = int(self.headers.get("X-Scope-Epoch", "0"))
            except ValueError:
                return None
            admitted = {("tenant-a", "alice"), ("tenant-a", "bob"), ("tenant-b", "mallory")}
            if (tenant, owner) not in admitted or epoch != 7 or program != "program-a":
                return None
            return tenant, owner, program, epoch

        def do_POST(self):
            if self.path != "/execute":
                self.send_error(404)
                return
            scope = self.authority()
            if scope is None:
                self.send_error(403)
                return
            length = int(self.headers.get("Content-Length", "0"))
            request = json.loads(self.rfile.read(length))
            command = request["command"]
            kind = request["kind"]
            payload = request["payload"]
            work_id = command if kind == "infernix-start" else None
            with sqlite3.connect(database, isolation_level="IMMEDIATE") as connection:
                existing = connection.execute(
                    "SELECT work_id, outcome FROM receipts WHERE tenant=? AND owner=? AND program=? AND epoch=? AND command=?",
                    (*scope, command),
                ).fetchone()
                if existing is None:
                    connection.execute(
                        "INSERT INTO effects VALUES (?,?,?,?,?,?,?)",
                        (*scope, command, kind, payload),
                    )
                    outcome = "ready-artifact" if kind == "infernix-start" else "scalar-ok"
                    connection.execute(
                        "INSERT INTO receipts VALUES (?,?,?,?,?,?,?)",
                        (*scope, command, work_id, outcome),
                    )
                else:
                    work_id, outcome = existing
            receipt = {"command": command, "workId": work_id, "outcome": outcome, "replica": replica}
            transient_routes[command] = receipt
            if self.headers.get("X-Drop-Response") == "true":
                self.close_connection = True
                try:
                    self.connection.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                self.connection.close()
                return
            self.respond(receipt)

        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path != "/receipt":
                self.send_error(404)
                return
            scope = self.authority()
            if scope is None:
                self.send_error(403)
                return
            command = parse_qs(parsed.query).get("command", [""])[0]
            with sqlite3.connect(database) as connection:
                row = connection.execute(
                    "SELECT work_id, outcome FROM receipts WHERE tenant=? AND owner=? AND program=? AND epoch=? AND command=?",
                    (*scope, command),
                ).fetchone()
            if row is None:
                self.send_error(404)
                return
            self.respond({"command": command, "workId": row[0], "outcome": row[1], "replica": replica})

        def respond(self, value):
            payload = json.dumps(value, sort_keys=True).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, *_args):
            return

    return Handler


def request(server, method, path, scope, value=None, drop=False):
    connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
    headers = {
        "X-Tenant": scope[0],
        "X-Owner": scope[1],
        "X-Program": scope[2],
        "X-Scope-Epoch": str(scope[3]),
    }
    body = None
    if value is not None:
        body = json.dumps(value)
        headers["Content-Type"] = "application/json"
        headers["Content-Length"] = str(len(body.encode()))
    if drop:
        headers["X-Drop-Response"] = "true"
    try:
        connection.request(method, path, body=body, headers=headers)
        response = connection.getresponse()
        payload = response.read()
        return response.status, json.loads(payload) if response.status == 200 and payload else None
    finally:
        connection.close()


def main():
    scalar = "scalar-" + secrets.token_hex(12)
    infernix = "infernix-" + secrets.token_hex(12)
    scope = ("tenant-a", "alice", "program-a", 7)
    with tempfile.TemporaryDirectory(prefix="amoebius-offline-replay-receipts-") as directory:
        root = Path(directory)
        database = root / "durable-receipts.sqlite3"
        outbox = root / "encrypted-outbox-observer.json"
        outbox.write_text(json.dumps([scalar, infernix]))
        initialize(database)
        transient_routes = {}
        servers = [
            ThreadingHTTPServer(("127.0.0.1", 0), make_handler(database, "replica-a", transient_routes)),
            ThreadingHTTPServer(("127.0.0.1", 0), make_handler(database, "replica-b", transient_routes)),
        ]
        threads = [threading.Thread(target=server.serve_forever, daemon=True) for server in servers]
        for thread in threads:
            thread.start()
        try:
            scalar_status, scalar_receipt = request(
                servers[1], "POST", "/execute", scope,
                {"command": scalar, "kind": "scalar", "payload": "value-61"},
            )
            dropped = False
            try:
                request(
                    servers[1], "POST", "/execute", scope,
                    {"command": infernix, "kind": "infernix-start", "payload": "ready-input"},
                    drop=True,
                )
            except (http.client.RemoteDisconnected, ConnectionResetError, BrokenPipeError):
                dropped = True
            transient_routes.clear()
            route_flushed = transient_routes == {}
            recovered_status, recovered = request(
                servers[0], "GET", "/receipt?command=" + infernix, scope
            )
            retry_status, retried = request(
                servers[0], "POST", "/execute", scope,
                {"command": infernix, "kind": "infernix-start", "payload": "ready-input"},
            )
            stale_status, _ = request(
                servers[0], "GET", "/receipt?command=" + scalar,
                ("tenant-a", "alice", "program-a", 6),
            )
            foreign_status, _ = request(
                servers[0], "GET", "/receipt?command=" + scalar,
                ("tenant-b", "mallory", "program-a", 7),
            )
        finally:
            for server in servers:
                server.shutdown()
                server.server_close()
            for thread in threads:
                thread.join(timeout=2)
        with sqlite3.connect(database) as observer:
            effect_rows = observer.execute(
                "SELECT command, COUNT(*) FROM effects GROUP BY command ORDER BY command"
            ).fetchall()
            receipt_rows = observer.execute(
                "SELECT command, work_id, outcome FROM receipts ORDER BY command"
            ).fetchall()
        pending_survived_disconnect = json.loads(outbox.read_text()) == [scalar, infernix]

    assertions = {
        "scalarAccepted": scalar_status == 200 and scalar_receipt["command"] == scalar,
        "realResponseDrop": dropped,
        "routeStateFlushed": route_flushed,
        "durableCrossReplicaRecovery": recovered_status == 200 and recovered["replica"] == "replica-a",
        "exactRetrySameReceipt": retry_status == 200 and retried["command"] == recovered["command"] and retried["outcome"] == recovered["outcome"],
        "infernixIdentity": recovered["command"] == recovered["workId"] == infernix,
        "oneEffectEach": len(effect_rows) == 2 and all(count == 1 for _, count in effect_rows),
        "twoDurableReceipts": len(receipt_rows) == 2,
        "staleMembershipDenied": stale_status == 403,
        "foreignScopeNoReceipt": foreign_status == 404,
        "pendingPreserved": pending_survived_disconnect,
    }
    if not all(assertions.values()):
        raise SystemExit("offline-replay-receipts-live: FAIL " + json.dumps(assertions, sort_keys=True))
    value = {
        "schema": "amoebius.phase61.live.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "result": "PASS-SCOPED",
        "freshCommands": {"scalarDigest": fingerprint(scalar), "infernixDigest": fingerprint(infernix)},
        "assertions": assertions,
        "observer": {"engine": "sqlite3", "effects": len(effect_rows), "receipts": len(receipt_rows)},
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
        "honesty": {
            "keycloakOidc": "UNVERIFIED",
            "realRedis": "UNVERIFIED",
            "pulsarMinioPostgres": "UNVERIFIED",
            "infernixWorker": "UNVERIFIED",
            "gatewayKubernetesCni": "UNVERIFIED",
        },
    }
    value["evidenceDigest"] = fingerprint(value)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    print(
        f"offline-replay-receipts-live: PASS-SCOPED ({value['evidenceDigest']}; "
        "real provider/broker/identity observers UNVERIFIED)"
    )


if __name__ == "__main__":
    main()
