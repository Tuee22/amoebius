"""Template executed inside the Phase-30 registry mutation-proxy container."""

import base64
import hashlib
import http.client
import json
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


CAPABILITY = __CAPABILITY__
PUBLICATION_PROOF = __PUBLICATION_PROOF__
PUBLICATION_TAG = __PUBLICATION_TAG__
INDEX_DIGEST = __INDEX_DIGEST__
ADMITTED = json.loads(__ADMITTED__)
BACKEND_HOST = "distribution-read.amoebius-bootstrap.svc"
BACKEND_PORT = 5003
MAX_CONCURRENCY = 2
ACTIVE = 0
ACTIVE_LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        print(format % args, flush=True)

    def send_body(self, status, body, headers=None):
        self.send_response(status)
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def credential(self):
        authorization = self.headers.get("Authorization", "")
        token = ""
        if authorization.startswith("Bearer "):
            token = authorization[7:]
        elif authorization.startswith("Basic "):
            try:
                decoded = base64.b64decode(authorization[6:], validate=True).decode("utf-8")
                token = decoded.partition(":")[2]
            except (ValueError, UnicodeDecodeError):
                token = ""
        supplied_capability, separator, supplied_proof = token.partition("|")
        return (
            supplied_capability == CAPABILITY,
            separator == "|" and supplied_proof == PUBLICATION_PROOF,
        )

    def require_read_capability(self):
        admitted, _active = self.credential()
        if admitted:
            return True
        self.send_body(
            401,
            b"publisher-capability-required\n",
            {"WWW-Authenticate": 'Basic realm="amoebius-registry"'},
        )
        return False

    def do_GET(self):
        if self.path == "/healthz":
            self.send_body(200, b"ready\n")
        elif self.require_read_capability():
            self.forward()

    def do_HEAD(self):
        if self.require_read_capability():
            self.forward()

    def do_POST(self):
        self.mutate()

    def do_PUT(self):
        self.mutate()

    def do_PATCH(self):
        self.mutate()

    def do_DELETE(self):
        self.mutate()

    def mutate(self):
        admitted, activated = self.credential()
        if not admitted:
            self.send_body(403, b"publisher-capability-required\n")
            return
        if not activated:
            self.send_body(409, b"atomic-publication-not-enabled-until-sprint-25.3\n")
            return
        global ACTIVE
        with ACTIVE_LOCK:
            if ACTIVE >= MAX_CONCURRENCY:
                self.send_body(429, b"publication-concurrency-exceeded\n")
                return
            ACTIVE += 1
        try:
            validation = self.validate_mutation()
            if validation is None:
                return
            body, fault = validation
            self.forward(body=body, fault=fault)
        finally:
            with ACTIVE_LOCK:
                ACTIVE -= 1

    def validate_mutation(self):
        parsed = urllib.parse.urlsplit(self.path)
        if not parsed.path.startswith("/v2/amoebius/base/"):
            self.send_body(403, b"unprovisioned-repository\n")
            return None
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_body(411, b"finite-content-length-required\n")
            return None
        if self.command == "POST" and parsed.path.endswith("/blobs/uploads/") and length == 0:
            return b"", False
        if self.command == "PUT" and "/blobs/uploads/" in parsed.path:
            digest = urllib.parse.parse_qs(parsed.query).get("digest", [""])[0]
            if digest not in ADMITTED:
                self.send_body(403, b"unprovisioned-digest\n")
                return None
            if ADMITTED[digest] != length:
                self.send_body(422, b"provisioned-size-mismatch\n")
                return None
            return False, self.headers.get("X-Amoebius-Fault") == "mid-upload"
        if self.command == "PUT" and "/manifests/" in parsed.path:
            if length > 1048576:
                self.send_body(413, b"manifest-too-large\n")
                return None
            body = self.rfile.read(length)
            digest = "sha256:" + hashlib.sha256(body).hexdigest()
            if digest not in ADMITTED or ADMITTED[digest] != length:
                self.send_body(403, b"unprovisioned-manifest\n")
                return None
            reference = parsed.path.rsplit("/", 1)[-1]
            if reference.startswith("sha256:") and reference != digest:
                self.send_body(422, b"manifest-digest-mismatch\n")
                return None
            if not reference.startswith("sha256:") and (
                reference != PUBLICATION_TAG or digest != INDEX_DIGEST
            ):
                self.send_body(403, b"unprovisioned-tag\n")
                return None
            return body, False
        self.send_body(405, b"mutation-shape-not-admitted\n")
        return None

    def forward(self, body=None, fault=False):
        connection = http.client.HTTPConnection(BACKEND_HOST, BACKEND_PORT, timeout=120)
        parsed = urllib.parse.urlsplit(self.path)
        path = urllib.parse.urlunsplit(("", "", parsed.path, parsed.query, ""))
        try:
            connection.putrequest(self.command, path, skip_host=True, skip_accept_encoding=True)
            for name, value in self.headers.items():
                if name.lower() not in {
                    "authorization",
                    "connection",
                    "host",
                    "proxy-connection",
                    "x-amoebius-fault",
                }:
                    connection.putheader(name, value)
            connection.putheader("Host", f"{BACKEND_HOST}:{BACKEND_PORT}")
            connection.endheaders()
            if body is False:
                remaining = int(self.headers.get("Content-Length", "0"))
                forwarded = 0
                while remaining:
                    chunk = self.rfile.read(min(1048576, remaining))
                    if not chunk:
                        raise ConnectionError("short publisher body")
                    connection.send(chunk)
                    remaining -= len(chunk)
                    forwarded += len(chunk)
                    if fault and forwarded >= 1048576:
                        connection.close()
                        self.close_connection = True
                        self.send_body(502, b"fault-injected-mid-upload\n")
                        return
            elif body:
                connection.send(body)
            response = connection.getresponse()
            response_body = response.read()
            headers = {}
            for name, value in response.getheaders():
                lower = name.lower()
                if lower in {"connection", "content-length", "transfer-encoding"}:
                    continue
                if lower == "location":
                    location = urllib.parse.urlsplit(value)
                    value = urllib.parse.urlunsplit(("", "", location.path, location.query, ""))
                headers[name] = value
            self.send_body(response.status, response_body, headers)
        finally:
            connection.close()


ThreadingHTTPServer(("0.0.0.0", 5001), Handler).serve_forever()
