"""
amoebius/secrets/vault_client.py

An asynchronous Vault client supporting KV v2 operations, with optional
Kubernetes Auth or direct token usage.

Modified to include `get_active_token()` for Terraform usage.
"""

from __future__ import annotations

import time
import aiohttp
import aiofiles
import asyncio
from typing import Any, Dict, Optional, Type, List

from amoebius.models.validator import validate_type
from amoebius.models.vault import VaultSettings


class AsyncVaultClient:
    """
    An asynchronous Vault client that handles:
      - KV v2 read/write/delete/list
      - Automatic token management (login, renew) if using Kubernetes auth
      - Direct token usage if VaultSettings.direct_vault_token is set
    """

    _session: Optional[aiohttp.ClientSession]
    _client_token: Optional[str]
    _last_token_check: float

    def __init__(self, settings: VaultSettings) -> None:
        self._vault_addr: str = settings.vault_addr
        self._vault_role_name: Optional[str] = settings.vault_role_name
        self._token_path: str = settings.token_path
        self._verify_ssl: bool = settings.verify_ssl
        self._renew_threshold_seconds: float = settings.renew_threshold_seconds
        self._check_interval_seconds: float = settings.check_interval_seconds
        self._direct_token: Optional[str] = settings.direct_vault_token

        self._session = None
        self._client_token = None
        self._last_token_check = 0.0

    async def __aenter__(self) -> AsyncVaultClient:
        self._session = aiohttp.ClientSession()
        return self

    async def __aexit__(
        self,
        exc_type: Optional[Type[BaseException]],
        exc_val: Optional[BaseException],
        exc_tb: Optional[Any],
    ) -> None:
        if self._session:
            await self._session.close()
        self._session = None

    # --------------------------------------------------------------------------
    # NEW: Provide a way to get the currently active Vault token for Terraform, etc.
    # --------------------------------------------------------------------------
    async def get_active_token(self) -> str:
        """
        Ensures we have a valid token, then returns it.
        If token cannot be retrieved, raises RuntimeError.
        """
        await self._ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Unable to obtain a Vault token.")
        return self._client_token

    # ------------------
    # KV V2 Methods
    # ------------------
    async def read_secret(self, path: str) -> Dict[str, Any]:
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        url = f"{self._vault_addr}/v1/secret/data/{path}"
        headers = {"X-Vault-Token": self._client_token}
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            resp_json = validate_type(raw_resp, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error reading secret: {resp.status}, {resp_json}")

        data_field = resp_json.get("data", {})
        sub_data = data_field.get("data")
        if isinstance(sub_data, dict):
            return sub_data
        return resp_json

    async def write_secret(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        url = f"{self._vault_addr}/v1/secret/data/{path}"
        headers = {"X-Vault-Token": self._client_token}
        payload: Dict[str, Any] = {"data": data}

        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            raw_resp: Dict[str, Any] = {}
            try:
                raw_resp = await resp.json()
            except aiohttp.ContentTypeError:
                pass  # 204 No Content possible

            if resp.status not in (200, 204):
                err_json = validate_type(raw_resp, Dict[str, Any])
                raise RuntimeError(f"Error writing secret: {resp.status}, {err_json}")

            if resp.status == 200:
                resp_json = validate_type(raw_resp, Dict[str, Any])
                return resp_json
        return {}

    async def write_secret_idempotent(
        self, path: str, data: Dict[str, Any]
    ) -> Dict[str, Any]:
        existing_data: Optional[Dict[str, Any]] = None
        try:
            existing_data = await self.read_secret(path)
        except RuntimeError as ex:
            if "404" in str(ex):
                existing_data = None
            else:
                raise

        if existing_data == data:
            return {}
        return await self.write_secret(path, data)

    async def delete_secret(self, path: str, hard: bool = False) -> None:
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        if hard:
            url = f"{self._vault_addr}/v1/secret/metadata/{path}"
            method_label = "Hard"
        else:
            url = f"{self._vault_addr}/v1/secret/data/{path}"
            method_label = "Soft"

        headers = {"X-Vault-Token": self._client_token}
        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204, 404):
                raw_resp = await resp.json()
                raise RuntimeError(
                    f"{method_label} delete failed: {resp.status}, {raw_resp}"
                )

    async def list_secrets(self, path: str) -> List[str]:
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        if not path.endswith("/"):
            path += "/"

        url = f"{self._vault_addr}/v1/secret/metadata/{path}?list=true"
        headers = {"X-Vault-Token": self._client_token}

        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            resp_json = validate_type(raw_resp, Dict[str, Any])

            if resp.status == 404:
                return []
            if resp.status != 200:
                raise RuntimeError(f"Error listing secrets: {resp.status}, {resp_json}")

        data_field = resp_json.get("data", {})
        keys = data_field.get("keys", [])
        if not isinstance(keys, list):
            return []
        return keys

    async def secret_history(self, path: str) -> Dict[str, Any]:
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        url = f"{self._vault_addr}/v1/secret/metadata/{path}"
        headers = {"X-Vault-Token": self._client_token}

        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            if resp.status == 404:
                return {}
            if resp.status != 200:
                raise RuntimeError(f"Error reading metadata: {resp.status}, {raw_resp}")

        return validate_type(raw_resp, Dict[str, Any])

    async def revoke_self_token(self) -> None:
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            return

        url = f"{self._vault_addr}/v1/auth/token/revoke-self"
        headers = {"X-Vault-Token": self._client_token}

        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204):
                detail = await resp.json()
                raise RuntimeError(f"Failed to revoke token: {resp.status}, {detail}")

        self._client_token = None

    # ------------
    # Private Token Management
    # ------------
    async def _ensure_session(self) -> aiohttp.ClientSession:
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def _ensure_valid_token(self) -> None:
        """
        Ensure we have a valid token:
          - If direct_vault_token is set, we use that and skip any renew logic.
          - Else, do K8s-based login + renewal as needed.
        """
        # If direct token is provided, just use it
        if self._direct_token is not None:
            if self._client_token is None:
                self._client_token = self._direct_token
            return

        # Otherwise, K8s login + renewal
        now = time.time()
        if (
            self._last_token_check > 0
            and (now - self._last_token_check) < self._check_interval_seconds
        ):
            return

        self._last_token_check = now

        if self._client_token is None:
            await self._login()
            return

        # Check token TTL
        try:
            token_info = await self._get_token_info()
        except RuntimeError as e:
            if "403" in str(e):
                # Possibly token expired or invalid
                await self._login()
                return
            raise

        ttl = token_info.get("ttl")
        if not isinstance(ttl, int):
            await self._login()
            return

        if ttl < self._renew_threshold_seconds:
            await self._renew_token()

    async def _login(self) -> None:
        # If we had a direct token, we'd just set it. (Already handled above)
        if not self._vault_role_name:
            raise RuntimeError(
                "Cannot login via K8s auth because vault_role_name is not set."
            )

        session = await self._ensure_session()
        async with aiofiles.open(self._token_path, "r") as f:
            jwt = await f.read()

        url = f"{self._vault_addr}/v1/auth/kubernetes/login"
        payload = {"jwt": jwt, "role": self._vault_role_name}
        async with session.post(url, json=payload, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            resp_json = validate_type(raw_resp, Dict[str, Any])

            if resp.status != 200:
                raise RuntimeError(f"Vault login failed: {resp.status}, {resp_json}")

            auth_data = resp_json.get("auth")
            if not isinstance(auth_data, dict) or "client_token" not in auth_data:
                raise RuntimeError("Vault did not return a valid client_token.")

        self._client_token = auth_data["client_token"]
        self._last_token_check = 0.0

    async def _renew_token(self) -> None:
        if self._direct_token is not None:
            self._client_token = self._direct_token
            return

        if self._client_token is None:
            await self._login()
            return

        session = await self._ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/renew-self"
        headers = {"X-Vault-Token": self._client_token}

        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            resp_json = validate_type(raw_resp, Dict[str, Any])
            if resp.status == 200:
                auth_data = resp_json.get("auth")
                if isinstance(auth_data, dict) and "client_token" in auth_data:
                    self._client_token = auth_data["client_token"]
                    return

        # Renewal failed, re-login
        await self._login()

    async def _get_token_info(self) -> Dict[str, Any]:
        if self._client_token is None:
            raise RuntimeError("Vault token is not set.")

        session = await self._ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/lookup-self"
        headers = {"X-Vault-Token": self._client_token}
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            resp_json = validate_type(raw_resp, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Token lookup failed: {resp.status}, {resp_json}")

        data_obj = resp_json.get("data")
        if not isinstance(data_obj, dict):
            raise RuntimeError("Token lookup did not return valid 'data'.")
        return data_obj
