"""
amoebius/secrets/vault_client.py

An asynchronous Vault client (AsyncVaultClient) that supports:
 - KV v2 (read, write, delete, list, history)
 - Transit encryption/decryption
 - Token management (K8s or direct token usage)
 - Checking Vault seal status
 - Creating/deleting Vault ACL policies
"""

from __future__ import annotations

import time
import aiohttp
import aiofiles
import base64
import json
from typing import Any, Dict, List, Optional, Type

from amoebius.models.validator import validate_type
from amoebius.models.vault import VaultSettings

__all__ = ["AsyncVaultClient"]  # EXPLICIT EXPORT for mypy


class AsyncVaultClient:
    """
    An asynchronous Vault client that manages:
      - KV v2 read/write/delete/list
      - Transit encryption/decryption
      - Token acquisition & renewal
      - Checking Vault seal status
      - Creating/deleting Vault ACL policies
    """

    _session: Optional[aiohttp.ClientSession]
    _client_token: Optional[str]
    _last_token_check: float

    def __init__(self, settings: VaultSettings) -> None:
        """
        Initialize the AsyncVaultClient.

        Args:
            settings: A VaultSettings object containing:
                vault_addr, vault_role_name, token_path, verify_ssl,
                renew_threshold_seconds, check_interval_seconds, direct_vault_token
        """
        self._vault_addr = settings.vault_addr
        self._vault_role_name = settings.vault_role_name
        self._token_path = settings.token_path
        self._verify_ssl = settings.verify_ssl
        self._renew_threshold_seconds = settings.renew_threshold_seconds
        self._check_interval_seconds = settings.check_interval_seconds
        self._direct_token = settings.direct_vault_token

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

    async def ensure_session(self) -> aiohttp.ClientSession:
        """
        Ensure an aiohttp session is available.
        """
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def ensure_valid_token(self) -> None:
        """
        Ensure we have a valid token, either direct or from K8s-based login or renewal.

        Raises:
            RuntimeError if token acquisition or renewal fails.
        """
        if self._direct_token is not None:
            if self._client_token is None:
                self._client_token = self._direct_token
            return

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
        except RuntimeError as ex:
            if "403" in str(ex):
                await self._login()
                return
            raise

        ttl = token_info.get("ttl")
        if not isinstance(ttl, int):
            await self._login()
            return

        if ttl < self._renew_threshold_seconds:
            await self._renew_token()

    async def is_vault_sealed(self) -> bool:
        """
        Check if Vault is sealed/unavailable by calling /v1/sys/seal-status.

        Returns:
            bool: True if sealed/unavailable, False if unsealed.
        """
        session = await self.ensure_session()
        url = f"{self._vault_addr}/v1/sys/seal-status"
        async with session.get(url, ssl=self._verify_ssl) as resp:
            data = await resp.json()
            if resp.status != 200:
                raise RuntimeError(f"seal-status check failed: {resp.status}, {data}")
            return bool(data.get("sealed", True))

    async def get_active_token(self) -> str:
        """
        Obtain a valid token, returning it if successful.

        Raises:
            RuntimeError: If no valid token can be acquired.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Unable to acquire a Vault token.")
        return self._client_token

    async def _login(self) -> None:
        """
        Internal method for K8s-based login or direct token usage.

        Raises:
            RuntimeError on login failure or invalid token response.
        """
        if self._direct_token is not None:
            self._client_token = self._direct_token
            return
        if not self._vault_role_name:
            raise RuntimeError("Cannot login via K8s: vault_role_name not set.")

        session = await self.ensure_session()
        async with aiofiles.open(self._token_path, "r") as f:
            jwt = await f.read()

        url = f"{self._vault_addr}/v1/auth/kubernetes/login"
        payload = {"jwt": jwt, "role": self._vault_role_name}
        async with session.post(url, json=payload, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Vault login failed: {resp.status}, {js}")

            auth_data = js.get("auth")
            if not isinstance(auth_data, dict) or "client_token" not in auth_data:
                raise RuntimeError("Vault did not return a valid client_token.")

        self._client_token = auth_data["client_token"]
        self._last_token_check = 0.0

    async def _renew_token(self) -> None:
        """
        Internal method to attempt token renewal, else re-login.
        """
        if self._direct_token is not None:
            self._client_token = self._direct_token
            return
        if not self._client_token:
            await self._login()
            return

        session = await self.ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/renew-self"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status == 200:
                ad = js.get("auth")
                if isinstance(ad, dict) and "client_token" in ad:
                    self._client_token = ad["client_token"]
                    return
        await self._login()

    async def _get_token_info(self) -> Dict[str, Any]:
        """
        Internal method: retrieve token info from /v1/auth/token/lookup-self.
        """
        if not self._client_token:
            raise RuntimeError("Vault token is not set.")

        session = await self.ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/lookup-self"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Token lookup failed: {resp.status}, {js}")
        data_obj = js.get("data")
        if not isinstance(data_obj, dict):
            raise RuntimeError("lookup-self did not return 'data'")
        return data_obj

    # KV V2
    async def read_secret(self, path: str) -> Dict[str, Any]:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/data/{path}"
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error reading secret: {resp.status}, {js}")
        data_field = js.get("data", {})
        sub_data = data_field.get("data")
        if isinstance(sub_data, dict):
            return sub_data
        return js

    async def write_secret(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/data/{path}"
        payload = {"data": data}
        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            try:
                raw_js = await resp.json()
            except aiohttp.ContentTypeError:
                raw_js = {}
            if resp.status not in (200, 204):
                ejs = validate_type(raw_js, Dict[str, Any])
                raise RuntimeError(f"Error writing secret: {resp.status}, {ejs}")
            if resp.status == 200:
                return validate_type(raw_js, Dict[str, Any])
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
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        if hard:
            url = f"{self._vault_addr}/v1/secret/metadata/{path}"
            label = "Hard"
        else:
            url = f"{self._vault_addr}/v1/secret/data/{path}"
            label = "Soft"
        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204, 404):
                raw_js = await resp.json()
                raise RuntimeError(f"{label} delete failed: {resp.status}, {raw_js}")

    async def list_secrets(self, path: str) -> List[str]:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not path.endswith("/"):
            path += "/"
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/metadata/{path}?list=true"
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status == 404:
                return []
            if resp.status != 200:
                raise RuntimeError(f"Error listing secrets: {resp.status}, {js}")
        data_field = js.get("data", {})
        keys = data_field.get("keys", [])
        if not isinstance(keys, list):
            return []
        return keys

    async def secret_history(self, path: str) -> Dict[str, Any]:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/metadata/{path}"
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            if resp.status == 404:
                return {}
            if resp.status != 200:
                raise RuntimeError(f"Error reading metadata: {resp.status}, {raw_js}")
        return validate_type(raw_js, Dict[str, Any])

    async def revoke_self_token(self) -> None:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            return
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/auth/token/revoke-self"
        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204):
                detail = await resp.json()
                raise RuntimeError(f"Failed to revoke token: {resp.status}, {detail}")
        self._client_token = None

    # Transit
    async def write_transit_key(
        self,
        key_name: str,
        idempotent: bool = False,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        if idempotent:
            check_url = f"{self._vault_addr}/v1/transit/keys/{key_name}"
            async with session.get(
                check_url, headers=headers, ssl=self._verify_ssl
            ) as r:
                if r.status == 200:
                    return {}
                elif r.status not in (404, 200):
                    c_js = await r.json()
                    raise RuntimeError(
                        f"Error checking key existence: {r.status}, {c_js}"
                    )
        url = f"{self._vault_addr}/v1/transit/keys/{key_name}"
        payload = params or {}
        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            try:
                resp_js = await resp.json()
            except aiohttp.ContentTypeError:
                resp_js = {}
            if resp.status not in (200, 204):
                raise RuntimeError(
                    f"Error creating/updating transit key: {resp.status}, {resp_js}"
                )
            if resp.status == 200:
                return validate_type(resp_js, Dict[str, Any])
        return {}

    async def encrypt_transit_data(self, key_name: str, plaintext: bytes) -> str:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        b64_plaintext = base64.b64encode(plaintext).decode("utf-8")

        url = f"{self._vault_addr}/v1/transit/encrypt/{key_name}"
        payload = {"plaintext": b64_plaintext}
        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error encrypting data: {resp.status}, {js}")
        ct = js["data"].get("ciphertext")
        if not isinstance(ct, str):
            raise RuntimeError("Vault response missing ciphertext.")
        return ct

    async def decrypt_transit_data(self, key_name: str, ciphertext: str) -> bytes:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        url = f"{self._vault_addr}/v1/transit/decrypt/{key_name}"
        payload = {"ciphertext": ciphertext}
        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error decrypting data: {resp.status}, {js}")
        b64_plain = js["data"].get("plaintext")
        if not isinstance(b64_plain, str):
            raise RuntimeError("Vault response missing plaintext.")
        return base64.b64decode(b64_plain)

    async def encrypt_transit_dict(
        self, key_name: str, data_dict: Dict[str, Any]
    ) -> str:
        import json

        raw = json.dumps(data_dict).encode("utf-8")
        return await self.encrypt_transit_data(key_name, raw)

    async def decrypt_transit_dict(
        self, key_name: str, ciphertext: str
    ) -> Dict[str, Any]:
        import json

        raw_bytes = await self.decrypt_transit_data(key_name, ciphertext)
        return validate_type(json.loads(raw_bytes.decode()), Dict[str, Any])

    async def put_policy(self, policy_name: str, policy_text: str) -> None:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        url = f"{self._vault_addr}/v1/sys/policies/acl/{policy_name}"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        payload: Dict[str, Any] = {"policy": policy_text}
        async with session.put(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            try:
                resp_json = await resp.json()
            except aiohttp.ContentTypeError:
                resp_json = {}
            if resp.status not in (200, 204):
                raise RuntimeError(
                    f"Error creating/updating policy {policy_name}: "
                    f"{resp.status}, {resp_json}"
                )

    async def delete_policy(self, policy_name: str) -> None:
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        url = f"{self._vault_addr}/v1/sys/policies/acl/{policy_name}"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            try:
                resp_json = await resp.json()
            except aiohttp.ContentTypeError:
                resp_json = {}
            if resp.status not in (200, 204, 404):
                raise RuntimeError(
                    f"Error deleting policy {policy_name}: {resp.status}, {resp_json}"
                )
