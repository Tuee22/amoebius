from __future__ import annotations

import io
import json
import sys
import unittest
import urllib.error
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pb"))

from pb.admin import AdminClient, AdminEndpoint, AdminError  # noqa: E402
from pb.cli import parser  # noqa: E402


class Response(io.BytesIO):
    def __enter__(self) -> "Response":
        return self

    def __exit__(self, *unused: object) -> None:
        self.close()


class RecordingOpener:
    def __init__(self, response: dict[str, object] | None = None) -> None:
        self.response = response or {"result": "ok"}
        self.requests: list[object] = []

    def open(self, request: object, timeout: float) -> Response:
        self.requests.append((request, timeout))
        return Response(json.dumps(self.response).encode())


class AdminClientSpec(unittest.TestCase):
    def client(self, reach: str = "NodeLocal") -> tuple[AdminClient, RecordingOpener]:
        opener = RecordingOpener()
        endpoint = AdminEndpoint.parse("http://127.0.0.1:32034", reach)
        return AdminClient(endpoint, opener=opener), opener

    def test_node_local_endpoint_is_structural(self) -> None:
        AdminEndpoint.parse("http://[::1]:32034", "NodeLocal")
        with self.assertRaisesRegex(AdminError, "node-local-endpoint-required"):
            AdminEndpoint.parse("http://10.0.0.8:32034", "NodeLocal")
        with self.assertRaisesRegex(AdminError, "reach-untrusted"):
            AdminEndpoint.parse("http://127.0.0.1:32034", "WildIngress")

    def test_password_is_body_only_and_reach_is_typed_header(self) -> None:
        client, opener = self.client()
        client.vault_unseal("transport-only")
        request, timeout = opener.requests[0]
        self.assertEqual(request.full_url, "http://127.0.0.1:32034/v1/vault/unseal")
        self.assertNotIn("transport-only", request.full_url)
        self.assertEqual(request.get_header("X-amoebius-reach"), "NodeLocal")
        self.assertEqual(json.loads(request.data), {"password": "transport-only"})
        self.assertEqual(timeout, 120.0)

    def test_exact_endpoint_payloads(self) -> None:
        client, opener = self.client()
        probe = {"name": "root", "secretExists": True}
        client.vault_init("pw")
        client.dhall_update("pw", "let x = 1 in x", [probe])
        client.kv("pw", "put", name="ssh/node-a", value="value")
        client.kv("pw", "get", name="ssh/node-a")
        client.kv("pw", "list")
        client.kv("pw", "delete", name="ssh/node-a")
        paths = [request.full_url.rsplit("/v1", 1)[1] for request, _ in opener.requests]
        self.assertEqual(paths, ["/vault/init", "/dhall/update", "/kv", "/kv", "/kv", "/kv"])
        verbs = [json.loads(request.data).get("verb") for request, _ in opener.requests[2:]]
        self.assertEqual(verbs, ["put", "get", "list", "delete"])

    def test_http_refusal_preserves_specific_tag_without_password(self) -> None:
        error = urllib.error.HTTPError(
            "http://127.0.0.1:32034/v1/vault/init", 403, "Forbidden", {},
            Response(b'{"tag":"admin-reach-seal-critical-node-local-required"}'),
        )
        opener = mock.Mock()
        opener.open.side_effect = error
        client = AdminClient(AdminEndpoint.parse("http://127.0.0.1:32034", "NodeLocal"), opener=opener)
        with self.assertRaisesRegex(AdminError, "admin-reach-seal-critical-node-local-required") as observed:
            client.vault_init("never-report-me")
        self.assertNotIn("never-report-me", str(observed.exception))

    def test_cli_is_two_mode_with_nested_admin_verbs(self) -> None:
        cases = [
            (["admin", "vault", "init"], ("vault", "init")),
            (["admin", "vault", "unseal"], ("vault", "unseal")),
            (["admin", "dhall", "update", "spec.dhall", "--probes", "probes.json"], ("dhall", "update")),
            (["admin", "kv", "put", "secret", "--value-stdin"], ("kv", "put")),
            (["admin", "kv", "get", "secret"], ("kv", "get")),
            (["admin", "kv", "list"], ("kv", "list")),
            (["admin", "kv", "delete", "secret"], ("kv", "delete")),
        ]
        for arguments, expected in cases:
            with self.subTest(arguments=arguments):
                parsed = parser().parse_args(arguments)
                command = getattr(parsed, "vault_command", getattr(parsed, "dhall_command", getattr(parsed, "kv_command", None)))
                self.assertEqual((parsed.admin_command, command), expected)


if __name__ == "__main__":
    unittest.main()
