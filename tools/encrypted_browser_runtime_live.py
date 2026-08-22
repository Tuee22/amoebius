#!/usr/bin/env python3
"""Drive the production offline PureScript bundle in two fresh Chrome processes."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
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
TEMP_ROOT = Path(os.environ.get("AMOEBIUS_TEST_TMP", ROOT / ".build/tmp/encrypted-browser-runtime"))

PAGE = b"""<!doctype html><meta charset="utf-8"><title>offline runtime</title>
<pre id="result">PENDING</pre><script type="module" src="/bundle.js"></script>"""
SW = b"""self.addEventListener('install', event => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => event.respondWith(caches.match(event.request).then(hit => hit || fetch(event.request))));
"""


class Handler(BaseHTTPRequestHandler):
    bundle = b""

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/offline-runtime.html":
            payload, content_type = PAGE, "text/html; charset=utf-8"
        elif path == "/bundle.js":
            payload, content_type = self.bundle, "application/javascript"
        elif path == "/sw.js":
            payload, content_type = SW, "application/javascript"
        elif path == "/asset/hash-app.js":
            payload, content_type = b"globalThis.amoebiusAppAsset=true;", "application/javascript"
        elif path == "/asset/hash-runtime.js":
            payload, content_type = b"globalThis.amoebiusRuntimeAsset=true;", "application/javascript"
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
    websocket_send(connection, {
        "id": request_id,
        "method": "Runtime.evaluate",
        "params": {"expression": expression, "returnByValue": True},
    })
    while True:
        message = websocket_receive(connection)
        if message.get("id") == request_id:
            if "error" in message:
                raise RuntimeError("Chrome evaluation failed: " + json.dumps(message))
            return message["result"]["result"].get("value")


def browser_run(browser, profile, url):
    expected_path = urlparse(url).path
    active = Path(profile) / "DevToolsActivePort"
    active.unlink(missing_ok=True)
    process = subprocess.Popen(
        [
            browser, "--headless=new", "--no-sandbox", "--disable-gpu", "--no-proxy-server",
            "--disable-background-networking", "--disable-component-update", "--disable-sync",
            "--remote-debugging-port=0", "--remote-allow-origins=*",
            f"--user-data-dir={profile}", url,
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        deadline = time.monotonic() + 20
        while not active.exists() and time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError("Chrome exited before opening its debugging endpoint")
            time.sleep(0.05)
        if not active.exists():
            raise RuntimeError("Chrome debugging endpoint did not appear")
        port = int(active.read_text().splitlines()[0])
        target_deadline = time.monotonic() + 20
        target = None
        while target is None and time.monotonic() < target_deadline:
            targets = json.loads(urlopen(f"http://127.0.0.1:{port}/json/list", timeout=2).read())
            target = next((item for item in targets if item.get("type") == "page"
                           and urlparse(item.get("url", "")).path == expected_path), None)
            if target is None:
                time.sleep(0.05)
        if target is None:
            raise RuntimeError("Chrome offline-runtime page target did not appear")
        connection = connect_debugger(target["webSocketDebuggerUrl"])
        try:
            deadline = time.monotonic() + 45
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", default=os.environ.get("AMOEBIUS_CHROMIUM"))
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if not args.browser or not Path(args.browser).is_file():
        raise SystemExit("resolved Chrome executable is absent")
    bundle = Path(args.bundle)
    if not bundle.is_file():
        raise SystemExit("production PureScript bundle is absent")
    Handler.bundle = bundle.read_bytes()

    canary = "encrypted-browser-runtime-" + secrets.token_hex(16)
    unlock = "unlock-" + secrets.token_hex(16)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="profile-", dir=TEMP_ROOT) as profile:
            origin = f"http://127.0.0.1:{server.server_port}/offline-runtime.html"
            seeded = browser_run(args.browser, profile, f"{origin}?action=seed&canary={canary}&unlock={unlock}")
            inspected = browser_run(args.browser, profile, f"{origin}?action=inspect&canary={canary}&unlock={unlock}")
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)

    trace = json.loads((ROOT / "test/golden/browser/encrypted_browser_runtime/action_trace.json").read_text())
    expected_paths = ["/asset/hash-app.js", "/asset/hash-runtime.js"]
    expected_capabilities = [
        "webcrypto-aes-gcm", "indexeddb-ciphertext", "opaque-scope-partition", "web-lock-fencing",
        "broadcast-handoff", "immutable-service-worker-assets", "explicit-quota-refusal",
    ]
    assertions = {
        "actionTrace": seeded["actions"] == trace["actions"],
        "productionCapabilities": seeded["capabilities"] == inspected["capabilities"] == expected_capabilities,
        "secondLeaderRefused": seeded["secondLeaderRefused"],
        "fencingGeneration": seeded["fencingGeneration"] == inspected["fencingGeneration"] == 2,
        "broadcastHandoff": seeded["broadcast"] == "handoff-2",
        "restartRecovery": inspected["recoveredAfterBrowserRestart"],
        "rawCiphertext": inspected["rawCiphertextExcludesCanary"],
        "prohibitedFields": inspected["rawStorageExcludesProhibited"],
        "partitionIsolation": inspected["partitionIsolated"],
        "immutableAssetCache": inspected["cachedPaths"] == expected_paths,
        "serviceWorker": inspected["serviceWorkerRegistered"],
        "explicitQuota": inspected["quotaDepended"] == inspected["quotaIndependent"] == "RejectedQuota",
    }
    if not all(assertions.values()):
        raise SystemExit("encrypted-browser-runtime-browser: FAIL " + json.dumps(assertions, sort_keys=True))
    version = subprocess.run([args.browser, "--version"], text=True, stdout=subprocess.PIPE, check=True).stdout.strip()
    value = {
        "schema": "amoebius.encrypted-browser-runtime.browser.v2",
        "register": 2,
        "substrate": "none",
        "result": "PASS",
        "browser": version,
        "freshCanaryDigest": fingerprint(canary),
        "bundleDigest": "sha256:" + hashlib.sha256(bundle.read_bytes()).hexdigest(),
        "assertions": assertions,
        "rawObserver": "second fresh Chrome process using the same repository-contained profile",
        "honesty": {"serverReplay": "UNVERIFIED", "liveMultiZone": "UNVERIFIED"},
    }
    value["evidenceDigest"] = fingerprint(value)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    print(f"encrypted-browser-runtime-browser: PASS ({value['evidenceDigest']}; production PureScript bundle; real Chrome)")


if __name__ == "__main__":
    main()
