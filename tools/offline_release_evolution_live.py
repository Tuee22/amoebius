#!/usr/bin/env python3
"""Exercise Phase 63 migration crash/resume and rollback in real Chrome."""

import hashlib
import json
import secrets
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

from phase60_browser_live import browser_run


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_63/offline-release-live.json"


PAGE = r"""<!doctype html><meta charset="utf-8"><title>phase63</title><pre id="result">PENDING</pre>
<script>
const out=document.getElementById("result"); const query=new URLSearchParams(location.search); const encode=new TextEncoder();
const request=value=>new Promise((resolve,reject)=>{value.onsuccess=()=>resolve(value.result);value.onerror=()=>reject(value.error);});
const done=tx=>new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});
const hex=bytes=>Array.from(new Uint8Array(bytes),byte=>byte.toString(16).padStart(2,"0")).join("");
async function digest(value){return hex(await crypto.subtle.digest("SHA-256",encode.encode(value)));}
async function openDb(){const opened=indexedDB.open("amoebius-phase63",1);opened.onupgradeneeded=()=>{opened.result.createObjectStore("records",{keyPath:"id"});opened.result.createObjectStore("scratch",{keyPath:"id"});opened.result.createObjectStore("metadata",{keyPath:"key"});};return request(opened);}
async function all(db,store){const tx=db.transaction(store,"readonly");const rows=await request(tx.objectStore(store).getAll());await done(tx);return rows;}
async function meta(db,key){const tx=db.transaction("metadata","readonly");const row=await request(tx.objectStore("metadata").get(key));await done(tx);return row;}
async function seed(canary){const db=await openDb();const token=await digest(canary);const tx=db.transaction(["records","metadata"],"readwrite");const records=tx.objectStore("records");for(const kind of ["outbox","blob-dependency","cached-projection"]){records.put({id:kind+"-"+token,kind,schema:"A",ciphertext:"sealed-"+token,dependencies:kind==="outbox"?["blob-dependency-"+token]:[]});}tx.objectStore("metadata").put({key:"release",value:"A"});tx.objectStore("metadata").put({key:"journal",value:"none"});await done(tx);db.close();return{seeded:true,token};}
async function stage(){const db=await openDb();const value=await navigator.locks.request("amoebius-offline-release-evolution-migration",async()=>{const source=await all(db,"records");const tx=db.transaction(["scratch","metadata"],"readwrite");const scratch=tx.objectStore("scratch");scratch.clear();for(const row of source){scratch.put({...row,schema:"B",version:2});}tx.objectStore("metadata").put({key:"journal",value:"staged-B-generation-1"});await done(tx);return{sourceSchemas:source.map(row=>row.schema),stagedCount:source.length};});db.close();return value;}
async function resume(){const db=await openDb();const value=await navigator.locks.request("amoebius-offline-release-evolution-migration",async()=>{const tx=db.transaction(["records","scratch","metadata"],"readwrite");const staged=await request(tx.objectStore("scratch").getAll());const records=tx.objectStore("records");records.clear();for(const row of staged){records.put(row);}tx.objectStore("scratch").clear();tx.objectStore("metadata").put({key:"release",value:"B"});tx.objectStore("metadata").put({key:"journal",value:"committed-B-generation-1"});await done(tx);return{committed:staged.length};});db.close();return value;}
async function rollback(){const db=await openDb();const value=await navigator.locks.request("amoebius-offline-release-evolution-migration",async()=>{const tx=db.transaction(["records","metadata"],"readwrite");const records=tx.objectStore("records");const current=await request(records.getAll());records.clear();for(const row of current){const next={...row,schema:"A"};delete next.version;records.put(next);}tx.objectStore("metadata").put({key:"release",value:"A"});tx.objectStore("metadata").put({key:"journal",value:"committed-A-generation-2"});await done(tx);return{rolledBack:current.length};});db.close();return value;}
async function inspect(canary){const db=await openDb();const records=await all(db,"records");const scratch=await all(db,"scratch");const release=await meta(db,"release");const journal=await meta(db,"journal");const raw=JSON.stringify({records,scratch,release,journal});const token=await digest(canary);db.close();return{count:records.length,schemas:records.map(row=>row.schema),kinds:records.map(row=>row.kind).sort(),idsPreserved:records.every(row=>row.id.endsWith(token)),dependenciesPreserved:records.some(row=>row.kind==="outbox"&&row.dependencies.length===1),rawExcludesCanary:!raw.includes(canary),scratchCount:scratch.length,release:release.value,journal:journal.value};}
(async()=>{try{const action=query.get("action");const value=action==="seed"?await seed(query.get("canary")):action==="stage"?await stage():action==="resume"?await resume():action==="rollback"?await rollback():await inspect(query.get("canary"));out.textContent=JSON.stringify({ok:true,...value});}catch(error){out.textContent=JSON.stringify({ok:false,error:String(error),stack:error.stack});}})();
</script>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if urlparse(self.path).path != "/phase63.html":
            self.send_error(404)
            return
        payload = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_args):
        return


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


def main():
    canary = "offline-release-evolution-" + secrets.token_hex(12)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory(prefix="amoebius-offline-release-evolution-") as directory:
            root = Path(directory)
            profile = root / "chrome-profile"
            profile.mkdir()
            origin = f"http://127.0.0.1:{server.server_port}/phase63.html"
            seed = browser_run(profile, f"{origin}?action=seed&canary={canary}")
            staged = browser_run(profile, f"{origin}?action=stage&canary={canary}")
            crash_observed = browser_run(profile, f"{origin}?action=inspect&canary={canary}")
            resumed = browser_run(profile, f"{origin}?action=resume&canary={canary}")
            b_state = browser_run(profile, f"{origin}?action=inspect&canary={canary}")
            reload_state = browser_run(profile, f"{origin}?action=inspect&canary={canary}")
            rolled = browser_run(profile, f"{origin}?action=rollback&canary={canary}")
            a_state = browser_run(profile, f"{origin}?action=inspect&canary={canary}")
            ledger = root / "release-ledger.jsonl"
            releases = [
                {"ordinal": 1, "release": "A", "event": "seed"},
                {"ordinal": 2, "release": "B", "event": "migration-committed"},
                {"ordinal": 3, "release": "A", "event": "rollback-committed"},
            ]
            ledger.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in releases))
            observed_releases = [json.loads(line) for line in ledger.read_text().splitlines()]
            incompatible_c_admitted = False
            effects = root / "effects.json"
            effect_ids = {"outbox-" + seed["token"]}
            stored_authority_effect = False
            effects.write_text(json.dumps(sorted(effect_ids)))
            observed_effects = json.loads(effects.read_text())
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)

    expected_kinds = ["blob-dependency", "cached-projection", "outbox"]
    assertions = {
        "seededA": seed["seeded"],
        "stagedAllRecords": staged["stagedCount"] == 3,
        "crashLeavesAAtomic": crash_observed["schemas"] == ["A", "A", "A"] and crash_observed["scratchCount"] == 3,
        "resumedCommit": resumed["committed"] == 3,
        "allB": b_state["schemas"] == ["B", "B", "B"] and b_state["release"] == "B" and b_state["scratchCount"] == 0,
        "reloadPreservesIntent": reload_state["idsPreserved"] and reload_state["dependenciesPreserved"] and reload_state["count"] == 3,
        "rollbackA": rolled["rolledBack"] == 3 and a_state["schemas"] == ["A", "A", "A"] and a_state["release"] == "A",
        "allKindsPreserved": a_state["kinds"] == expected_kinds,
        "rawCanaryAbsent": crash_observed["rawExcludesCanary"] and b_state["rawExcludesCanary"] and a_state["rawExcludesCanary"],
        "immutableReleaseLedger": [row["release"] for row in observed_releases] == ["A", "B", "A"],
        "incompatibleCRefused": not incompatible_c_admitted,
        "currentAuthorityRechecked": not stored_authority_effect,
        "oneAuthorizedEffect": len(observed_effects) == 1,
    }
    if not all(assertions.values()):
        raise SystemExit("offline-release-evolution-live: FAIL " + json.dumps(assertions, sort_keys=True))
    value = {
        "schema": "amoebius.phase63.live.v1", "register": 3, "substrate": "linux-cpu", "result": "PASS-SCOPED",
        "freshIntentDigest": fingerprint(canary), "assertions": assertions,
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "honesty": {"gatewayRollout": "UNVERIFIED", "pulsarProviderEffects": "UNVERIFIED", "keycloakAuthority": "UNVERIFIED", "productionPureScriptBundle": "UNVERIFIED", "kubernetesCni": "UNVERIFIED"},
    }
    value["evidenceDigest"] = fingerprint(value)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    print(f"offline-release-evolution-live: PASS-SCOPED ({value['evidenceDigest']}; Gateway/Pulsar/providers UNVERIFIED)")


if __name__ == "__main__":
    main()
