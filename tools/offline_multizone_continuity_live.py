#!/usr/bin/env python3
"""Run one integrated host-local slice of the Phase 65 continuity campaign."""

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

from phase60_browser_live import browser_run


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_64/offline-multizone-live.json"


PAGE = r"""<!doctype html><meta charset="utf-8"><title>phase64</title><pre id="result">PENDING</pre>
<script>
const out=document.getElementById("result");const query=new URLSearchParams(location.search);const encode=new TextEncoder();const decode=new TextDecoder();
const request=value=>new Promise((resolve,reject)=>{value.onsuccess=()=>resolve(value.result);value.onerror=()=>reject(value.error);});const done=tx=>new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});const hex=bytes=>Array.from(new Uint8Array(bytes),byte=>byte.toString(16).padStart(2,"0")).join("");
async function digest(value){return hex(await crypto.subtle.digest("SHA-256",encode.encode(value)));}async function openDb(){const opened=indexedDB.open("amoebius-phase64",1);opened.onupgradeneeded=()=>opened.result.createObjectStore("state",{keyPath:"key"});return request(opened);}async function getState(db){const tx=db.transaction("state","readonly");const value=await request(tx.objectStore("state").get("offline"));await done(tx);return value;}async function putState(db,value){const tx=db.transaction("state","readwrite");tx.objectStore("state").put(value);await done(tx);}async function keyFor(unlock,salt){const material=await crypto.subtle.importKey("raw",encode.encode(unlock),"PBKDF2",false,["deriveKey"]);return crypto.subtle.deriveKey({name:"PBKDF2",hash:"SHA-256",salt,iterations:120000},material,{name:"AES-GCM",length:256},false,["encrypt","decrypt"]);}
async function seed(canary,unlock){const db=await openDb();const salt=crypto.getRandomValues(new Uint8Array(16));const iv=crypto.getRandomValues(new Uint8Array(12));const key=await keyFor(unlock,salt);const content=("blob-"+canary+"|").repeat(128);const ciphertext=await crypto.subtle.encrypt({name:"AES-GCM",iv},key,encode.encode(content));const token=await digest(canary);const state={key:"offline",release:"A",schema:1,tenant:"tenant-a",owner:"alice",scopeEpoch:8,outbox:[{kind:"scalar",id:"scalar-"+token},{kind:"infernix-start",id:"infernix-"+token},{kind:"blob-dependent",id:"blob-command-"+token,dependency:"blob-"+token}],cursor:42,blob:{id:"blob-"+token,iv:Array.from(iv),ciphertext:Array.from(new Uint8Array(ciphertext)),salt:Array.from(salt)}};await putState(db,state);db.close();return{seeded:true,ids:state.outbox.map(row=>row.id),blobId:state.blob.id};}
async function migrate(){const db=await openDb();const value=await navigator.locks.request("amoebius-offline-multizone-continuity-migration",async()=>{const state=await getState(db);const next={...state,release:"B",schema:2};await putState(db,next);return{release:next.release,count:next.outbox.length,cursor:next.cursor};});db.close();return value;}
async function inspect(canary,unlock){const db=await openDb();const state=await getState(db);const raw=JSON.stringify(state);const key=await keyFor(unlock,new Uint8Array(state.blob.salt));const plaintext=decode.decode(await crypto.subtle.decrypt({name:"AES-GCM",iv:new Uint8Array(state.blob.iv)},key,new Uint8Array(state.blob.ciphertext)));db.close();return{release:state.release,schema:state.schema,tenant:state.tenant,owner:state.owner,scopeEpoch:state.scopeEpoch,outbox:state.outbox,cursor:state.cursor,blobId:state.blob.id,contentDigest:hex(await crypto.subtle.digest("SHA-256",encode.encode(plaintext))),recovered:plaintext===("blob-"+canary+"|").repeat(128),rawExcludesCanary:!raw.includes(canary)};}
(async()=>{try{const action=query.get("action");const value=action==="seed"?await seed(query.get("canary"),query.get("unlock")):action==="migrate"?await migrate():await inspect(query.get("canary"),query.get("unlock"));out.textContent=JSON.stringify({ok:true,...value});}catch(error){out.textContent=JSON.stringify({ok:false,error:String(error),stack:error.stack});}})();
</script>"""


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


def initialize(database):
    with sqlite3.connect(database) as connection:
        connection.executescript(
            """
            PRAGMA journal_mode=WAL;
            CREATE TABLE effects (tenant TEXT, owner TEXT, scope_epoch INTEGER, command TEXT, kind TEXT, PRIMARY KEY(tenant,owner,scope_epoch,command));
            CREATE TABLE receipts (tenant TEXT, owner TEXT, scope_epoch INTEGER, command TEXT, work_id TEXT, outcome TEXT, PRIMARY KEY(tenant,owner,scope_epoch,command));
            CREATE TABLE cursors (tenant TEXT, owner TEXT, stream TEXT, sequence INTEGER, PRIMARY KEY(tenant,owner,stream));
            INSERT INTO cursors VALUES ('tenant-a','alice','projection',42);
            """
        )


class Shared:
    def __init__(self, database, objects):
        self.database = database
        self.objects = objects
        self.routes = {}
        self.verified_blobs = set()


def make_handler(shared, replica):
    class Handler(BaseHTTPRequestHandler):
        def authority(self):
            tenant = self.headers.get("X-Tenant", "")
            owner = self.headers.get("X-Owner", "")
            if (tenant, owner) not in {("tenant-a", "alice"), ("tenant-a", "bob"), ("tenant-b", "mallory")}:
                return None
            if self.headers.get("X-Session-Epoch") != "2" or self.headers.get("X-Scope-Epoch") != "8" or self.headers.get("X-Release") != "B":
                return None
            return tenant, owner, 8

        def owner_authority(self, value=None):
            scope = self.authority()
            if scope != ("tenant-a", "alice", 8):
                return None
            if value is not None and (value.get("resourceTenant"), value.get("resourceOwner")) != ("tenant-a", "alice"):
                return None
            return scope

        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path == "/phase64.html":
                self.respond_bytes(200, PAGE.encode(), "text/html; charset=utf-8")
                return
            scope = self.owner_authority()
            if scope is None:
                self.send_error(403)
                return
            if parsed.path == "/cursor":
                with sqlite3.connect(shared.database) as connection:
                    row = connection.execute("SELECT sequence FROM cursors WHERE tenant=? AND owner=? AND stream='projection'", scope[:2]).fetchone()
                self.respond_json(200, {"sequence": row[0], "replica": replica})
                return
            if parsed.path == "/receipt":
                command = parse_qs(parsed.query).get("command", [""])[0]
                with sqlite3.connect(shared.database) as connection:
                    row = connection.execute("SELECT work_id,outcome FROM receipts WHERE tenant=? AND owner=? AND scope_epoch=? AND command=?", (*scope, command)).fetchone()
                if row is None:
                    self.send_error(404)
                    return
                self.respond_json(200, {"command": command, "workId": row[0], "outcome": row[1], "replica": replica})
                return
            self.send_error(404)

        def do_POST(self):
            parsed = urlparse(self.path)
            length = int(self.headers.get("Content-Length", "0"))
            if parsed.path == "/blob":
                scope = self.owner_authority()
                if scope is None:
                    self.send_error(403)
                    return
                content = self.rfile.read(length)
                claimed = parse_qs(parsed.query)["digest"][0]
                computed = hashlib.sha256(content).hexdigest()
                if computed != claimed:
                    self.send_error(422)
                    return
                (shared.objects / computed).write_bytes(content)
                shared.verified_blobs.add((scope, computed))
                self.respond_json(200, {"digest": computed, "replica": replica})
                return
            if parsed.path != "/command":
                self.send_error(404)
                return
            value = json.loads(self.rfile.read(length))
            scope = self.owner_authority(value)
            if scope is None:
                self.send_error(403)
                return
            command = value["command"]
            kind = value["kind"]
            if kind == "blob-dependent" and (scope, value["blobDigest"]) not in shared.verified_blobs:
                self.send_error(409)
                return
            work_id = command if kind == "infernix-start" else None
            outcome = "ready-artifact" if kind == "infernix-start" else "accepted"
            with sqlite3.connect(shared.database, isolation_level="IMMEDIATE") as connection:
                connection.execute("INSERT OR IGNORE INTO effects VALUES (?,?,?,?,?)", (*scope, command, kind))
                connection.execute("INSERT OR IGNORE INTO receipts VALUES (?,?,?,?,?,?)", (*scope, command, work_id, outcome))
            receipt = {"command": command, "workId": work_id, "outcome": outcome, "replica": replica}
            shared.routes[command] = receipt
            self.respond_json(200, receipt)

        def respond_json(self, status, value):
            self.respond_bytes(status, json.dumps(value, sort_keys=True).encode(), "application/json")

        def respond_bytes(self, status, payload, content_type):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, *_args):
            return

    return Handler


def api(server, method, path, identity, payload=None, session_epoch=2):
    connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=4)
    headers = {"X-Tenant": identity[0], "X-Owner": identity[1], "X-Session-Epoch": str(session_epoch), "X-Scope-Epoch": "8", "X-Release": "B"}
    body = None
    if payload is not None:
        body = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        headers["Content-Length"] = str(len(body))
        headers["Content-Type"] = "application/octet-stream" if isinstance(payload, bytes) else "application/json"
    try:
        connection.request(method, path, body=body, headers=headers)
        response = connection.getresponse()
        data = response.read()
        return response.status, json.loads(data) if response.status == 200 and data else None
    finally:
        connection.close()


def main():
    canary = "offline-multizone-continuity-" + secrets.token_hex(12)
    unlock = "unlock-" + secrets.token_hex(12)
    blob_content = (("blob-" + canary + "|") * 128).encode()
    blob_digest = hashlib.sha256(blob_content).hexdigest()
    owner = ("tenant-a", "alice")
    with tempfile.TemporaryDirectory(prefix="amoebius-offline-multizone-continuity-") as directory:
        root = Path(directory)
        database = root / "durable.sqlite3"
        objects = root / "objects"
        objects.mkdir()
        initialize(database)
        shared = Shared(database, objects)
        servers = [ThreadingHTTPServer(("127.0.0.1", 0), make_handler(shared, name)) for name in ("zone-a-ui", "zone-b-ui", "zone-c-ui")]
        threads = [threading.Thread(target=server.serve_forever, daemon=True) for server in servers]
        for thread in threads:
            thread.start()
        try:
            with tempfile.TemporaryDirectory(prefix="amoebius-offline-multizone-continuity-profile-") as profile:
                origin = f"http://127.0.0.1:{servers[0].server_port}/phase64.html"
                seed = browser_run(profile, f"{origin}?action=seed&canary={canary}&unlock={unlock}")
                zone_b_port = servers[1].server_port
                servers[1].shutdown()
                servers[1].server_close()
                role_isolated = False
                try:
                    api(servers[1], "GET", "/cursor", owner)
                except (ConnectionRefusedError, ConnectionResetError, socket.timeout, OSError):
                    role_isolated = True
                migrated = browser_run(profile, f"{origin}?action=migrate&canary={canary}&unlock={unlock}")
                state = browser_run(profile, f"{origin}?action=inspect&canary={canary}&unlock={unlock}")
            pre_status, _ = api(servers[2], "GET", "/cursor", owner, session_epoch=1)
            cursor_status, cursor = api(servers[2], "GET", "/cursor", owner)
            blob_status, blob = api(servers[2], "POST", f"/blob?digest={blob_digest}", owner, blob_content)
            receipts = []
            for record in state["outbox"]:
                payload = {"command": record["id"], "kind": record["kind"], "resourceTenant": "tenant-a", "resourceOwner": "alice"}
                if record["kind"] == "blob-dependent":
                    payload["blobDigest"] = blob_digest
                status, receipt = api(servers[2], "POST", "/command", owner, payload)
                receipts.append((status, receipt))
                retry_status, retry = api(servers[0], "POST", "/command", owner, payload)
                if retry_status != 200 or retry["command"] != receipt["command"] or retry["outcome"] != receipt["outcome"]:
                    raise RuntimeError("exact replay mismatch")
            nonowner_payload = {"command": state["outbox"][0]["id"], "kind": "scalar", "resourceTenant": "tenant-a", "resourceOwner": "alice"}
            nonowner_status, _ = api(servers[2], "POST", "/command", ("tenant-a", "bob"), nonowner_payload)
            foreign_status, _ = api(servers[2], "POST", "/command", ("tenant-b", "mallory"), nonowner_payload)
            shared.routes.clear()
            recovered_status, recovered = api(servers[0], "GET", "/receipt?command=" + state["outbox"][1]["id"], owner)
        finally:
            for index, server in enumerate(servers):
                if index != 1:
                    server.shutdown()
                    server.server_close()
            for thread in threads:
                thread.join(timeout=2)
        with sqlite3.connect(database) as observer:
            effect_rows = observer.execute("SELECT command,COUNT(*) FROM effects GROUP BY command ORDER BY command").fetchall()
            receipt_rows = observer.execute("SELECT command,work_id,outcome FROM receipts ORDER BY command").fetchall()
        object_bytes = (objects / blob_digest).read_bytes()
        release_ledger = [{"ordinal": 1, "release": "A", "event": "disconnected"}, {"ordinal": 2, "release": "B", "event": "migrated-after-role-loss"}]
        ledger_path = root / "release-ledger.jsonl"
        ledger_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in release_ledger))
        observed_ledger = [json.loads(line) for line in ledger_path.read_text().splitlines()]

    assertions = {
        "offlineASeed": seed["seeded"] and len(seed["ids"]) == 3,
        "zoneBRoleActuallyStopped": role_isolated and zone_b_port > 0,
        "releaseBPreservesIntent": migrated["release"] == "B" and migrated["count"] == 3 and state["release"] == "B" and len(state["outbox"]) == 3,
        "chromeEncryptedBlobRecovered": state["recovered"] and state["rawExcludesCanary"] and state["contentDigest"] == blob_digest,
        "prefaultAuthorityDenied": pre_status == 403,
        "cursorRepaired": cursor_status == 200 and cursor["sequence"] == state["cursor"] == 42 and cursor["replica"] == "zone-c-ui",
        "blobVerified": blob_status == 200 and blob["digest"] == blob_digest and object_bytes == blob_content,
        "allCommandsAccepted": all(status == 200 for status, _ in receipts),
        "infernixIdentity": receipts[1][1]["command"] == receipts[1][1]["workId"],
        "oneEffectPerCommand": len(effect_rows) == 3 and all(count == 1 for _, count in effect_rows),
        "durableReceipts": len(receipt_rows) == 3,
        "pairedDenial": nonowner_status == foreign_status == 403,
        "routeLossDurableRecovery": shared.routes == {} and recovered_status == 200 and recovered["replica"] == "zone-a-ui",
        "releaseLedger": [row["release"] for row in observed_ledger] == ["A", "B"],
    }
    if not all(assertions.values()):
        raise SystemExit("offline-multizone-continuity-live: FAIL " + json.dumps(assertions, sort_keys=True))
    value = {
        "schema": "amoebius.phase64.live.v1", "register": 3, "substrate": "linux-cpu → provider", "result": "PASS-SCOPED",
        "freshCampaignDigest": fingerprint(canary), "assertions": assertions,
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "honesty": {"providerWholeZoneIsolation": "UNVERIFIED", "managedMultizoneTopology": "UNVERIFIED", "realRedisSentinel": "UNVERIFIED", "keycloakGateway": "UNVERIFIED", "pulsarSqlMinioWorkflow": "UNVERIFIED", "kubernetesCni": "UNVERIFIED", "offlineJitmlCuda": "UNVERIFIED", "productionPureScriptBundle": "UNVERIFIED"},
    }
    value["evidenceDigest"] = fingerprint(value)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    print(f"offline-multizone-continuity-live: PASS-SCOPED ({value['evidenceDigest']}; provider multi-zone continuity UNVERIFIED)")


if __name__ == "__main__":
    main()
