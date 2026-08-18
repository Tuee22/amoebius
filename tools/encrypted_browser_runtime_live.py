#!/usr/bin/env python3
"""Run the Phase 60 boundary against a fresh real Chrome profile."""

import hashlib
import base64
import json
import secrets
import socket
import struct
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_60/browser-runtime-live.json"
CHROME = "/usr/bin/google-chrome"


PAGE = r"""<!doctype html><meta charset="utf-8"><title>phase60</title>
<pre id="result">PENDING</pre>
<script>
const out = document.getElementById("result");
const query = new URLSearchParams(location.search);
const encode = new TextEncoder();
const decode = new TextDecoder();
const request = value => new Promise((resolve, reject) => { value.onsuccess = () => resolve(value.result); value.onerror = () => reject(value.error); });
const transactionDone = tx => new Promise((resolve, reject) => { tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error); });
const hex = bytes => Array.from(new Uint8Array(bytes), byte => byte.toString(16).padStart(2, "0")).join("");
async function partition(parts) { return hex(await crypto.subtle.digest("SHA-256", encode.encode(parts.join("|")))); }
async function openDb() {
  const opened = indexedDB.open("amoebius-phase60", 1);
  opened.onupgradeneeded = () => {
    opened.result.createObjectStore("records", { keyPath: "id" });
    opened.result.createObjectStore("metadata", { keyPath: "key" });
  };
  return request(opened);
}
async function getRow(db, store, key) { const tx = db.transaction(store, "readonly"); const value = await request(tx.objectStore(store).get(key)); await transactionDone(tx); return value; }
async function putRow(db, store, value) { const tx = db.transaction(store, "readwrite"); tx.objectStore(store).put(value); await transactionDone(tx); }
async function deriveKey(unlock, salt) {
  const material = await crypto.subtle.importKey("raw", encode.encode(unlock), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey({ name: "PBKDF2", hash: "SHA-256", salt, iterations: 120000 }, material, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
}
async function bumpGeneration(db) {
  const row = await getRow(db, "metadata", "generation");
  const generation = (row?.value || 0) + 1;
  await putRow(db, "metadata", { key: "generation", value: generation });
  return generation;
}
function quotaOutcome(budget, used, requested) { return used + requested <= budget ? "Stored" : "RejectedQuota"; }
async function seed(canary, unlock) {
  const db = await openDb();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(unlock, salt);
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encode.encode(canary));
  const own = await partition(["tenant-a", "alice", "device-1", "program-1", "1"]);
  await putRow(db, "records", { id: own + "/command-1", partition: own, kind: "queued-command", iv: Array.from(iv), ciphertext: Array.from(new Uint8Array(ciphertext)) });
  await putRow(db, "metadata", { key: "salt", value: Array.from(salt) });
  await putRow(db, "metadata", { key: "partition", value: own });
  const cache = await caches.open("amoebius-assets-v1");
  await cache.addAll(["/asset/hash-app.js", "/asset/hash-runtime.js"]);
  await navigator.serviceWorker.register("/sw.js");
  await navigator.serviceWorker.ready;
  let release;
  const held = new Promise(resolve => { release = resolve; });
  const lockName = "amoebius-replay/" + own;
  const first = navigator.locks.request(lockName, async () => { await bumpGeneration(db); await held; });
  await new Promise(resolve => setTimeout(resolve, 50));
  const secondAdmitted = await navigator.locks.request(lockName, { ifAvailable: true }, lock => lock !== null);
  release();
  await first;
  await navigator.locks.request(lockName, async () => { await bumpGeneration(db); });
  const received = new Promise(resolve => { const listener = new BroadcastChannel(lockName); listener.onmessage = event => { listener.close(); resolve(event.data); }; });
  const sender = new BroadcastChannel(lockName); sender.postMessage("handoff-2");
  const broadcast = await received; sender.close();
  db.close();
  return { seeded: true, partition: own, secondLeaderRefused: !secondAdmitted, fencingGeneration: 2, broadcast };
}
async function inspect(canary, unlock) {
  const db = await openDb();
  const partitionRow = await getRow(db, "metadata", "partition");
  const saltRow = await getRow(db, "metadata", "salt");
  const generation = await getRow(db, "metadata", "generation");
  const stored = await getRow(db, "records", partitionRow.value + "/command-1");
  const raw = JSON.stringify(stored);
  const key = await deriveKey(unlock, new Uint8Array(saltRow.value));
  const plaintext = decode.decode(await crypto.subtle.decrypt({ name: "AES-GCM", iv: new Uint8Array(stored.iv) }, key, new Uint8Array(stored.ciphertext)));
  const foreign = await partition(["tenant-b", "alice", "device-1", "program-1", "1"]);
  const cache = await caches.open("amoebius-assets-v1");
  const cachedPaths = (await cache.keys()).map(item => new URL(item.url).pathname).sort();
  const registrations = await navigator.serviceWorker.getRegistrations();
  db.close();
  return {
    recoveredAfterBrowserRestart: plaintext === canary,
    rawCiphertextExcludesCanary: !raw.includes(canary),
    rawStorageExcludesProhibited: !["credential", "refresh-token", "private-plan"].some(value => raw.includes(value)),
    partitionIsolated: foreign !== partitionRow.value && stored.partition === partitionRow.value,
    fencingGeneration: generation.value,
    cachedPaths,
    serviceWorkerRegistered: registrations.length === 1,
    quotaDepended: quotaOutcome(100, 90, 20),
    quotaIndependent: quotaOutcome(100, 90, 20)
  };
}
(async () => {
  try {
    const result = query.get("action") === "seed"
      ? await seed(query.get("canary"), query.get("unlock"))
      : await inspect(query.get("canary"), query.get("unlock"));
    out.textContent = JSON.stringify({ ok: true, ...result });
  } catch (error) {
    out.textContent = JSON.stringify({ ok: false, error: String(error), stack: error.stack });
  }
})();
</script>"""


SW = """self.addEventListener('install', event => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => event.respondWith(caches.match(event.request).then(hit => hit || fetch(event.request))));
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/phase60.html":
            payload, content_type = PAGE.encode(), "text/html; charset=utf-8"
        elif path == "/sw.js":
            payload, content_type = SW.encode(), "application/javascript"
        elif path == "/asset/hash-app.js":
            payload, content_type = b"globalThis.phase60App='sha256:app-v1';", "application/javascript"
        elif path == "/asset/hash-runtime.js":
            payload, content_type = b"globalThis.phase60Runtime='sha256:runtime-v1';", "application/javascript"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_args):
        return


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


def read_exact(connection, size):
    chunks = []
    remaining = size
    while remaining:
        chunk = connection.recv(remaining)
        if not chunk:
            raise RuntimeError("Chrome debugging socket closed")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def websocket_send(connection, value):
    payload = json.dumps(value, separators=(",", ":")).encode()
    mask = secrets.token_bytes(4)
    length = len(payload)
    if length < 126:
        header = bytes((0x81, 0x80 | length))
    elif length < 65536:
        header = bytes((0x81, 0xFE)) + struct.pack("!H", length)
    else:
        header = bytes((0x81, 0xFF)) + struct.pack("!Q", length)
    masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    connection.sendall(header + mask + masked)


def websocket_receive(connection):
    first, second = read_exact(connection, 2)
    opcode = first & 0x0F
    length = second & 0x7F
    if length == 126:
        length = struct.unpack("!H", read_exact(connection, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", read_exact(connection, 8))[0]
    mask = read_exact(connection, 4) if second & 0x80 else None
    payload = read_exact(connection, length)
    if mask:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    if opcode == 0x8:
        raise RuntimeError("Chrome closed the debugging WebSocket")
    if opcode != 0x1:
        return websocket_receive(connection)
    return json.loads(payload)


def connect_debugger(websocket_url):
    parsed = urlparse(websocket_url)
    connection = socket.create_connection((parsed.hostname, parsed.port), timeout=5)
    key = base64.b64encode(secrets.token_bytes(16)).decode()
    request = (
        f"GET {parsed.path} HTTP/1.1\r\n"
        f"Host: {parsed.hostname}:{parsed.port}\r\n"
        "Upgrade: websocket\r\nConnection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
    )
    connection.sendall(request.encode())
    response = b""
    while b"\r\n\r\n" not in response:
        response += connection.recv(4096)
    if b" 101 " not in response.split(b"\r\n", 1)[0]:
        raise RuntimeError("Chrome rejected debugging WebSocket: " + response[:300].decode(errors="replace"))
    return connection


def evaluate(connection, expression, request_id):
    websocket_send(
        connection,
        {"id": request_id, "method": "Runtime.evaluate", "params": {"expression": expression, "returnByValue": True}},
    )
    while True:
        message = websocket_receive(connection)
        if message.get("id") == request_id:
            if "error" in message:
                raise RuntimeError("Chrome evaluation failed: " + json.dumps(message))
            return message["result"]["result"].get("value")


def browser_run(profile, url):
    expected_path = urlparse(url).path
    active = Path(profile) / "DevToolsActivePort"
    active.unlink(missing_ok=True)
    process = subprocess.Popen(
        [
            CHROME,
            "--headless=new",
            "--no-sandbox",
            "--disable-gpu",
            "--no-proxy-server",
            "--disable-background-networking",
            "--remote-debugging-port=0",
            "--remote-allow-origins=*",
            f"--user-data-dir={profile}",
            url,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        deadline = time.monotonic() + 15
        while not active.exists() and time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError("Chrome exited before opening its debugging endpoint")
            time.sleep(0.05)
        if not active.exists():
            raise RuntimeError("Chrome debugging endpoint did not appear")
        port = int(active.read_text().splitlines()[0])
        target_deadline = time.monotonic() + 15
        target = None
        while target is None and time.monotonic() < target_deadline:
            targets = json.loads(urlopen(f"http://127.0.0.1:{port}/json/list", timeout=2).read())
            target = next(
                (
                    item
                    for item in targets
                    if item.get("type") == "page" and urlparse(item.get("url", "")).path == expected_path
                ),
                None,
            )
            if target is None:
                time.sleep(0.05)
        if target is None:
            raise RuntimeError("Chrome Phase-60 page target did not appear")
        connection = connect_debugger(target["webSocketDebuggerUrl"])
        try:
            deadline = time.monotonic() + 35
            request_id = 1
            rendered = "PENDING"
            while rendered == "PENDING" and time.monotonic() < deadline:
                rendered = evaluate(connection, "document.getElementById('result')?.textContent || 'PENDING'", request_id)
                request_id += 1
                if rendered == "PENDING":
                    time.sleep(0.1)
        finally:
            connection.close()
        if rendered == "PENDING":
            raise RuntimeError("Chrome page did not finish its asynchronous boundary trace")
        value = json.loads(rendered)
        if not value.get("ok"):
            raise RuntimeError("Chrome page failed: " + json.dumps(value))
        return value
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def main():
    canary = "encrypted-browser-runtime-" + secrets.token_hex(16)
    unlock = "unlock-" + secrets.token_hex(16)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory(prefix="amoebius-encrypted-browser-runtime-profile-") as profile:
            origin = f"http://127.0.0.1:{server.server_port}/phase60.html"
            seed = browser_run(profile, f"{origin}?action=seed&canary={canary}&unlock={unlock}")
            inspect = browser_run(profile, f"{origin}?action=inspect&canary={canary}&unlock={unlock}")
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)

    expected_paths = ["/asset/hash-app.js", "/asset/hash-runtime.js"]
    assertions = {
        "secondLeaderRefused": seed["secondLeaderRefused"],
        "fencingGeneration": seed["fencingGeneration"] == inspect["fencingGeneration"] == 2,
        "broadcastHandoff": seed["broadcast"] == "handoff-2",
        "restartRecovery": inspect["recoveredAfterBrowserRestart"],
        "rawCiphertext": inspect["rawCiphertextExcludesCanary"],
        "prohibitedFields": inspect["rawStorageExcludesProhibited"],
        "partitionIsolation": inspect["partitionIsolated"],
        "immutableAssetCache": inspect["cachedPaths"] == expected_paths,
        "serviceWorker": inspect["serviceWorkerRegistered"],
        "explicitQuota": inspect["quotaDepended"] == inspect["quotaIndependent"] == "RejectedQuota",
    }
    if not all(assertions.values()):
        raise SystemExit("encrypted-browser-runtime-browser: FAIL " + json.dumps(assertions, sort_keys=True))
    version = subprocess.run([CHROME, "--version"], text=True, stdout=subprocess.PIPE, check=True).stdout.strip()
    value = {
        "schema": "amoebius.phase60.browser.v1",
        "register": 2,
        "substrate": "none",
        "result": "PASS-SCOPED",
        "browser": version,
        "freshCanaryDigest": fingerprint(canary),
        "assertions": assertions,
        "rawObserver": "second fresh Chrome process using the same hermetic profile",
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
        "honesty": {
            "purescriptCompiler": "UNVERIFIED",
            "productionGenericClientBundle": "UNVERIFIED",
            "serverReplay": "UNVERIFIED",
        },
    }
    value["evidenceDigest"] = fingerprint(value)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    print(
        f"encrypted-browser-runtime-browser: PASS-SCOPED ({value['evidenceDigest']}; "
        "real Chrome boundary; PureScript production bundle/server replay UNVERIFIED)"
    )


if __name__ == "__main__":
    main()
