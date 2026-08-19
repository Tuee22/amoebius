"""The admin client: what it refuses before it ever reaches the network."""

from __future__ import annotations

import io
import json
import urllib.error
import urllib.request

import pytest
from pb.admin import AdminClient, AdminEndpoint, AdminError


class _Opener:
    """A stand-in for `urllib`'s opener that records the request it was given."""

    def __init__(
        self, payload: object = None, failure: Exception | None = None
    ) -> None:
        self.payload = payload
        self.failure = failure
        self.requests: list[urllib.request.Request] = []

    def open(self, request: urllib.request.Request, timeout: float) -> io.BytesIO:
        self.requests.append(request)
        if self.failure is not None:
            raise self.failure
        return io.BytesIO(json.dumps(self.payload).encode())


def _client(payload: object = None, failure: Exception | None = None):
    opener = _Opener(payload, failure)
    endpoint = AdminEndpoint.parse("http://127.0.0.1:32034", "NodeLocal")
    return AdminClient(endpoint, opener=opener), opener


@pytest.mark.parametrize(
    ("url", "reach", "expected"),
    [
        ("http://127.0.0.1:1", "Anything", "reach-untrusted"),
        ("https://127.0.0.1:1", "NodeLocal", "endpoint-invalid"),
        ("http://user:pw@127.0.0.1:1", "NodeLocal", "endpoint-invalid"),
        ("http://127.0.0.1:1/path", "NodeLocal", "must-be-origin"),
        ("http://127.0.0.1:1?q=1", "NodeLocal", "must-be-origin"),
        ("http://example.com:1", "NodeLocal", "node-local-endpoint-required"),
    ],
)
def test_endpoint_parse_refuses(url: str, reach: str, expected: str) -> None:
    with pytest.raises(AdminError, match=expected):
        AdminEndpoint.parse(url, reach)


@pytest.mark.parametrize("host", ["127.0.0.1", "localhost", "[::1]"])
def test_endpoint_accepts_every_loopback_spelling(host: str) -> None:
    assert (
        AdminEndpoint.parse(f"http://{host}:32034/", "NodeLocal").reach == "NodeLocal"
    )


def test_authenticated_fabric_admits_a_non_loopback_host() -> None:
    assert AdminEndpoint.parse(
        "http://example.com:8080", "AuthenticatedFabric"
    ).base_url.endswith("8080")


def test_vault_calls_carry_the_reach_header() -> None:
    client, opener = _client({"ok": True})
    assert client.vault_init("secret") == {"ok": True}
    assert client.vault_unseal("secret") == {"ok": True}
    assert opener.requests[0].get_header("X-amoebius-reach") == "NodeLocal"


def test_an_empty_password_is_refused_before_the_request() -> None:
    client, opener = _client({})
    with pytest.raises(AdminError, match="operator-password-required"):
        client.vault_init("")
    assert opener.requests == []


def test_dhall_update_refuses_empty_source_and_sends_probes() -> None:
    client, opener = _client({"applied": 1})
    with pytest.raises(AdminError, match="dhall-source-empty"):
        client.dhall_update("pw", "   ", [])
    assert client.dhall_update("pw", "let x = 1 in x", [{"name": "p"}]) == {
        "applied": 1
    }
    body = json.loads(opener.requests[0].data or b"{}")
    assert body["probes"] == [{"name": "p"}]


@pytest.mark.parametrize(
    ("verb", "name", "value", "expected"),
    [
        ("wipe", "k", None, "kv-verb-invalid"),
        ("get", None, None, "kv-name-required"),
        ("put", "k", None, "kv-value-required"),
    ],
)
def test_kv_refuses_each_malformed_call(
    verb: str, name: str | None, value: str | None, expected: str
) -> None:
    client, _ = _client({})
    with pytest.raises(AdminError, match=expected):
        client.kv("pw", verb, name=name, value=value)


def test_kv_round_trips_each_admitted_verb() -> None:
    client, opener = _client({"ok": True})
    assert client.kv("pw", "list") == {"ok": True}
    assert client.kv("pw", "put", name="k", value="v") == {"ok": True}
    assert client.kv("pw", "delete", name="k") == {"ok": True}
    assert len(opener.requests) == 3


def test_an_http_error_becomes_its_tag() -> None:
    failure = urllib.error.HTTPError(
        "http://127.0.0.1", 403, "no", {}, io.BytesIO(b'{"tag":"denied"}')
    )
    client, _ = _client(failure=failure)
    with pytest.raises(AdminError, match="admin-http-403:denied"):
        client.kv("pw", "list")


def test_an_unreadable_error_body_is_still_a_tag() -> None:
    failure = urllib.error.HTTPError(
        "http://127.0.0.1", 500, "no", {}, io.BytesIO(b"not json")
    )
    client, _ = _client(failure=failure)
    with pytest.raises(AdminError, match="admin-response-invalid"):
        client.kv("pw", "list")


def test_a_transport_failure_is_named() -> None:
    client, _ = _client(failure=urllib.error.URLError("refused"))
    with pytest.raises(AdminError, match="admin-transport-failed"):
        client.kv("pw", "list")


def test_a_non_object_response_is_refused() -> None:
    client, _ = _client(payload=[1, 2])
    with pytest.raises(AdminError, match="admin-response-invalid"):
        client.kv("pw", "list")
