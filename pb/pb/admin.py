"""Typed client for the singleton's privileged admin REST surface."""

from __future__ import annotations

import dataclasses
import ipaddress
import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, BinaryIO, Protocol


class AdminError(RuntimeError):
    """A fail-closed admin client refusal."""


class Opener(Protocol):
    def open(self, request: urllib.request.Request, timeout: float) -> BinaryIO: ...


@dataclasses.dataclass(frozen=True)
class AdminEndpoint:
    base_url: str
    reach: str

    @classmethod
    def parse(cls, base_url: str, reach: str) -> "AdminEndpoint":
        if reach not in {"NodeLocal", "AuthenticatedFabric"}:
            raise AdminError("admin-client-reach-untrusted")
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme != "http" or not parsed.hostname or parsed.username or parsed.password:
            raise AdminError("admin-client-endpoint-invalid")
        if parsed.path.rstrip("/") or parsed.query or parsed.fragment:
            raise AdminError("admin-client-endpoint-must-be-origin")
        if reach == "NodeLocal" and not _loopback(parsed.hostname):
            raise AdminError("admin-client-node-local-endpoint-required")
        return cls(base_url.rstrip("/"), reach)


def _loopback(hostname: str) -> bool:
    if hostname.lower() == "localhost":
        return True
    try:
        return ipaddress.ip_address(hostname).is_loopback
    except ValueError:
        return False


class AdminClient:
    """One control path: CLI request to the singleton, with no credential persistence."""

    def __init__(
        self,
        endpoint: AdminEndpoint,
        *,
        opener: Opener | None = None,
        timeout: float = 120.0,
    ) -> None:
        self._endpoint = endpoint
        self._opener = opener or urllib.request.build_opener()
        self._timeout = timeout

    def vault_init(self, password: str) -> dict[str, Any]:
        return self._post("/v1/vault/init", {"password": _password(password)})

    def vault_unseal(self, password: str) -> dict[str, Any]:
        return self._post("/v1/vault/unseal", {"password": _password(password)})

    def dhall_update(
        self,
        password: str,
        source: str,
        probes: list[dict[str, Any]],
    ) -> dict[str, Any]:
        if not source.strip():
            raise AdminError("admin-client-dhall-source-empty")
        return self._post(
            "/v1/dhall/update",
            {"password": _password(password), "dhall": source, "probes": probes},
        )

    def kv(
        self,
        password: str,
        verb: str,
        *,
        name: str | None = None,
        value: str | None = None,
    ) -> dict[str, Any]:
        if verb not in {"put", "get", "list", "delete"}:
            raise AdminError("admin-client-kv-verb-invalid")
        if verb != "list" and not name:
            raise AdminError("admin-client-kv-name-required")
        if verb == "put" and value is None:
            raise AdminError("admin-client-kv-value-required")
        payload: dict[str, Any] = {"password": _password(password), "verb": verb}
        if name is not None:
            payload["name"] = name
        if value is not None:
            payload["value"] = value
        return self._post("/v1/kv", payload)

    def _post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        body = json.dumps(payload, separators=(",", ":")).encode()
        request = urllib.request.Request(
            self._endpoint.base_url + path,
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "X-Amoebius-Reach": self._endpoint.reach,
            },
        )
        try:
            with self._opener.open(request, timeout=self._timeout) as response:
                return _decode_response(response.read())
        except urllib.error.HTTPError as problem:
            try:
                decoded = _decode_response(problem.read())
                tag = decoded.get("tag", "admin-operation-refused")
            except AdminError:
                tag = "admin-response-invalid"
            raise AdminError(f"admin-http-{problem.code}:{tag}") from None
        except urllib.error.URLError as problem:
            raise AdminError(f"admin-transport-failed:{problem.reason}") from None


def _password(value: str) -> str:
    if not value:
        raise AdminError("operator-password-required")
    return value


def _decode_response(body: bytes) -> dict[str, Any]:
    try:
        decoded = json.loads(body)
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise AdminError("admin-response-invalid") from None
    if not isinstance(decoded, dict):
        raise AdminError("admin-response-invalid")
    return decoded
