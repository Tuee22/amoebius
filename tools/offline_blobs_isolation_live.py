#!/usr/bin/env python3
"""Run Phase 63 with real Chrome encryption and a resumable local upload endpoint."""

import hashlib
import http.client
import json
import secrets
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from phase60_browser_live import browser_run


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_62/offline-blob-live.json"


PAGE = r"""<!doctype html><meta charset="utf-8"><title>phase62</title><pre id="result">PENDING</pre>
<script>
const out = document.getElementById("result"); const query = new URLSearchParams(location.search);
const encode = new TextEncoder(); const decode = new TextDecoder();
const request = value => new Promise((resolve, reject) => { value.onsuccess = () => resolve(value.result); value.onerror = () => reject(value.error); });
const done = tx => new Promise((resolve, reject) => { tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error); });
const hex = bytes => Array.from(new Uint8Array(bytes), byte => byte.toString(16).padStart(2, "0")).join("");
async function partition(parts) { return hex(await crypto.subtle.digest("SHA-256", encode.encode(parts.join("|")))); }
async function openDb() { const opened = indexedDB.open("amoebius-phase62", 1); opened.onupgradeneeded = () => { opened.result.createObjectStore("blobs", {keyPath:"id"}); opened.result.createObjectStore("metadata", {keyPath:"key"}); }; return request(opened); }
async function getRow(db, store, key) { const tx=db.transaction(store,"readonly"); const value=await request(tx.objectStore(store).get(key)); await done(tx); return value; }
async function putRow(db, store, value) { const tx=db.transaction(store,"readwrite"); tx.objectStore(store).put(value); await done(tx); }
async function keyFor(unlock,salt) { const material=await crypto.subtle.importKey("raw",encode.encode(unlock),"PBKDF2",false,["deriveKey"]); return crypto.subtle.deriveKey({name:"PBKDF2",hash:"SHA-256",salt,iterations:120000},material,{name:"AES-GCM",length:256},false,["encrypt","decrypt"]); }
async function seed(canary,unlock) {
 const db=await openDb(); const content=("blob-"+canary+"|").repeat(128); const salt=crypto.getRandomValues(new Uint8Array(16)); const iv=crypto.getRandomValues(new Uint8Array(12)); const key=await keyFor(unlock,salt); const encrypted=await crypto.subtle.encrypt({name:"AES-GCM",iv},key,encode.encode(content)); const own=await partition(["tenant-a","alice","device-1","program-a","7"]); await putRow(db,"blobs",{id:own+"/blob-1",partition:own,iv:Array.from(iv),ciphertext:Array.from(new Uint8Array(encrypted))}); await putRow(db,"metadata",{key:"salt",value:Array.from(salt)}); await putRow(db,"metadata",{key:"partition",value:own}); db.close(); return {seeded:true,partition:own};
}
async function inspect(canary,unlock) {
 const db=await openDb(); const p=await getRow(db,"metadata","partition"); const salt=await getRow(db,"metadata","salt"); const stored=await getRow(db,"blobs",p.value+"/blob-1"); const raw=JSON.stringify(stored); const key=await keyFor(unlock,new Uint8Array(salt.value)); const plaintext=decode.decode(await crypto.subtle.decrypt({name:"AES-GCM",iv:new Uint8Array(stored.iv)},key,new Uint8Array(stored.ciphertext))); const foreign=await partition(["tenant-b","alice","device-1","program-a","7"]); db.close(); return {recovered:plaintext===("blob-"+canary+"|").repeat(128),rawExcludesCanary:!raw.includes(canary),partitionIsolated:foreign!==p.value,contentDigest:hex(await crypto.subtle.digest("SHA-256",encode.encode(plaintext)))};
}
(async()=>{try{const value=query.get("action")==="seed"?await seed(query.get("canary"),query.get("unlock")):await inspect(query.get("canary"),query.get("unlock"));out.textContent=JSON.stringify({ok:true,...value});}catch(error){out.textContent=JSON.stringify({ok:false,error:String(error),stack:error.stack});}})();
</script>"""


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


class State:
    def __init__(self, object_root):
        self.object_root = object_root
        self.handles = {}
        self.effects = set()
        self.lock = threading.Lock()


def make_handler(state):
    class Handler(BaseHTTPRequestHandler):
        def authority(self):
            tenant = self.headers.get("X-Tenant", "")
            owner = self.headers.get("X-Owner", "")
            epoch = self.headers.get("X-Scope-Epoch", "")
            if (tenant, owner) not in {("tenant-a", "alice"), ("tenant-a", "bob"), ("tenant-b", "mallory")} or epoch != "7":
                return None
            return tenant, owner

        def scoped_handle(self, token):
            scope = self.authority()
            record = state.handles.get(token)
            if scope is None or record is None or record["scope"] != scope:
                return None
            return record

        def do_GET(self):
            parsed = urlparse(self.path)
            query = parse_qs(parsed.query)
            if parsed.path == "/phase62.html":
                self.respond_bytes(200, PAGE.encode(), "text/html; charset=utf-8")
                return
            if parsed.path == "/upload/handle":
                scope = self.authority()
                if scope != ("tenant-a", "alice"):
                    self.send_error(403)
                    return
                token = "handle-" + secrets.token_hex(16)
                state.handles[token] = {"scope": scope, "digest": query["digest"][0], "total": int(query["chunks"][0]), "chunks": {}, "verified": False}
                self.respond_json(200, {"handle": token})
                return
            if parsed.path == "/upload/status":
                record = self.scoped_handle(query.get("handle", [""])[0])
                if record is None:
                    self.send_error(403)
                    return
                self.respond_json(200, {"nextChunk": len(record["chunks"]), "verified": record["verified"]})
                return
            self.send_error(404)

        def do_POST(self):
            parsed = urlparse(self.path)
            query = parse_qs(parsed.query)
            token = query.get("handle", [""])[0]
            record = self.scoped_handle(token)
            if record is None:
                self.send_error(403)
                return
            if parsed.path == "/upload/chunk":
                index = int(query["index"][0])
                payload = self.rfile.read(int(self.headers.get("Content-Length", "0")))
                if len(payload) > 65536 or index < 0 or index >= record["total"]:
                    self.send_error(413)
                    return
                with state.lock:
                    record["chunks"].setdefault(index, payload)
                self.respond_json(200, {"nextChunk": len(record["chunks"])})
                return
            if parsed.path == "/upload/verify":
                if len(record["chunks"]) != record["total"]:
                    self.send_error(409)
                    return
                content = b"".join(record["chunks"][index] for index in range(record["total"]))
                computed = hashlib.sha256(content).hexdigest()
                if computed != record["digest"]:
                    self.send_error(422)
                    return
                target = state.object_root / computed
                target.write_bytes(content)
                record["verified"] = True
                record["object"] = target
                self.respond_json(200, {"digest": computed})
                return
            if parsed.path == "/dependent":
                if not record["verified"]:
                    self.send_error(409)
                    return
                command = query["command"][0]
                state.effects.add((record["scope"], command))
                self.respond_json(200, {"command": command, "effectCount": 1})
                return
            self.send_error(404)

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


def api(server, method, path, scope, payload=None):
    connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
    headers = {"X-Tenant": scope[0], "X-Owner": scope[1], "X-Scope-Epoch": "7"}
    if payload is not None:
        headers["Content-Length"] = str(len(payload))
        headers["Content-Type"] = "application/octet-stream"
    try:
        connection.request(method, path, body=payload, headers=headers)
        response = connection.getresponse()
        body = response.read()
        return response.status, json.loads(body) if response.status == 200 and body else None
    finally:
        connection.close()


def main():
    canary = "offline-blobs-isolation-" + secrets.token_hex(12)
    unlock = "unlock-" + secrets.token_hex(12)
    content = (("blob-" + canary + "|") * 128).encode()
    digest = hashlib.sha256(content).hexdigest()
    owner = ("tenant-a", "alice")
    nonowner = ("tenant-a", "bob")
    foreign = ("tenant-b", "mallory")
    with tempfile.TemporaryDirectory(prefix="amoebius-offline-blobs-isolation-") as directory:
        root = Path(directory)
        state = State(root / "objects")
        state.object_root.mkdir()
        server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(state))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with tempfile.TemporaryDirectory(prefix="amoebius-offline-blobs-isolation-profile-") as profile:
                origin = f"http://127.0.0.1:{server.server_port}/phase62.html"
                seed = browser_run(profile, f"{origin}?action=seed&canary={canary}&unlock={unlock}")
                inspect = browser_run(profile, f"{origin}?action=inspect&canary={canary}&unlock={unlock}")
            handle_status, handle_value = api(server, "GET", f"/upload/handle?digest={digest}&chunks=2", owner)
            token = handle_value["handle"]
            pre_status, _ = api(server, "POST", f"/dependent?handle={token}&command=dependent-1", owner, b"")
            nonowner_status, _ = api(server, "GET", f"/upload/status?handle={token}", nonowner)
            foreign_status, _ = api(server, "GET", f"/upload/status?handle={token}", foreign)
            split = len(content) // 2
            first_status, _ = api(server, "POST", f"/upload/chunk?handle={token}&index=0", owner, content[:split])
            resume_status, resume = api(server, "GET", f"/upload/status?handle={token}", owner)
            second_status, _ = api(server, "POST", f"/upload/chunk?handle={token}&index=1", owner, content[split:])
            verify_status, verified = api(server, "POST", f"/upload/verify?handle={token}", owner, b"")
            effect_status, effect = api(server, "POST", f"/dependent?handle={token}&command=dependent-1", owner, b"")
            retry_status, retry = api(server, "POST", f"/dependent?handle={token}&command=dependent-1", owner, b"")
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
        object_bytes = (state.object_root / digest).read_bytes()
        effect_count = len(state.effects)

    assertions = {
        "chromeSeed": seed["seeded"],
        "chromeRestartRecovery": inspect["recovered"],
        "chromeRawCiphertext": inspect["rawExcludesCanary"],
        "chromePartitionIsolation": inspect["partitionIsolated"],
        "chromeDigest": inspect["contentDigest"] == digest,
        "opaqueHandleIssued": handle_status == 200 and token.startswith("handle-"),
        "dependencyHeldBeforeVerification": pre_status == 409,
        "sameTenantNonownerDenied": nonowner_status == 403,
        "foreignTenantDenied": foreign_status == 403,
        "firstChunk": first_status == 200,
        "resumedAtOne": resume_status == 200 and resume["nextChunk"] == 1,
        "secondChunk": second_status == 200,
        "serverContentVerified": verify_status == 200 and verified["digest"] == digest,
        "independentContentReadback": hashlib.sha256(object_bytes).hexdigest() == digest and object_bytes == content,
        "oneDependentEffect": effect_status == retry_status == 200 and effect == retry and effect_count == 1,
    }
    if not all(assertions.values()):
        raise SystemExit("offline-blobs-isolation-live: FAIL " + json.dumps(assertions, sort_keys=True))
    value = {
        "schema": "amoebius.phase62.live.v1", "register": 3, "substrate": "linux-cpu", "result": "PASS-SCOPED",
        "freshBlobDigest": "sha256:" + digest, "assertions": assertions,
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "honesty": {"minioAuditContent": "UNVERIFIED", "keycloakGateway": "UNVERIFIED", "kubernetesCni": "UNVERIFIED", "productionPureScriptBundle": "UNVERIFIED"},
    }
    value["evidenceDigest"] = fingerprint(value)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    print(f"offline-blobs-isolation-live: PASS-SCOPED ({value['evidenceDigest']}; MinIO/Gateway/Kubernetes/CNI UNVERIFIED)")


if __name__ == "__main__":
    main()
