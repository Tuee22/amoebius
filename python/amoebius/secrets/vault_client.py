"""
amoebius/secrets/vault_client.py

An asynchronous Vault client (`AsyncVaultClient`) that supports:
 - KV v2 operations (read, write, delete, list, history)
 - Transit encryption (create/update transit keys, encrypt/decrypt)
 - Token management via either:
   - Direct token usage, or
   - Kubernetes authentication (vault_role_name + JWT-based login)
 - Automatic token renewal and re-login when required
 - Checking Vault seal status (is_vault_sealed)

Usage:
    async with AsyncVaultClient(settings) as client:
        if await client.is_vault_sealed():
            raise RuntimeError("Vault is sealed/unavailable!")
        token = await client.get_active_token()
        secret_data = await client.read_secret("some/path")
        ...
"""

from __future__ import annotations

import time
import aiohttp
import aiofiles
import asyncio
import base64
import json
from typing import Any, Dict, Optional, Type, List, cast

from amoebius.models.validator import validate_type
from amoebius.models.vault import VaultSettings


class AsyncVaultClient:
    """
    An asynchronous Vault client that manages:
      - KV v2 (read, write, delete, list, history)
      - Transit encryption/decryption (create/update transit keys)
      - Token acquisition & renewal (via K8s auth or direct token)
      - Checking Vault's seal status

    This client uses an internal aiohttp session. Use like:

        async with AsyncVaultClient(settings) as client:
            if await client.is_vault_sealed():
                raise RuntimeError("Vault is sealed or unavailable.")
            secret_data = await client.read_secret("some/path")
    """

    _session: Optional[aiohttp.ClientSession]
    _client_token: Optional[str]
    _last_token_check: float

    def __init__(self, settings: VaultSettings) -> None:
        """
        Initializes the AsyncVaultClient.

        Args:
            settings (VaultSettings):
                Configuration for connecting/authenticating to Vault:
                  - vault_addr (str)
                  - vault_role_name (Optional[str])
                  - token_path (str)
                  - verify_ssl (bool)
                  - renew_threshold_seconds (float)
                  - check_interval_seconds (float)
                  - direct_vault_token (Optional[str])
        """
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
        """
        Enter the async context manager, creating a new aiohttp session.

        Returns:
            AsyncVaultClient: This client instance, ready for use.
        """
        self._session = aiohttp.ClientSession()
        return self

    async def __aexit__(
        self,
        exc_type: Optional[Type[BaseException]],
        exc_val: Optional[BaseException],
        exc_tb: Optional[Any],
    ) -> None:
        """
        Exit the async context manager, closing the aiohttp session.

        Args:
            exc_type: Exception type if an exception occurred.
            exc_val: Exception value if an exception occurred.
            exc_tb: Traceback if an exception occurred.
        """
        if self._session:
            await self._session.close()
        self._session = None

    async def is_vault_sealed(self) -> bool:
        """
        Checks whether Vault is sealed or unreachable by calling /v1/sys/seal-status.

        Returns:
            bool: True if sealed/unavailable, False if unsealed.

        Raises:
            RuntimeError: If the seal-status request fails or returns a non-200 status.
        """
        session = await self._ensure_session()
        url = f"{self._vault_addr}/v1/sys/seal-status"

        async with session.get(url, ssl=self._verify_ssl) as resp:
            data = await resp.json()
            if resp.status != 200:
                # If non-200 => treat as sealed/unavailable
                raise RuntimeError(
                    f"Vault seal-status check failed: {resp.status}, {data}"
                )

            # 'sealed' is a bool, but to avoid returning Any, we explicitly handle it.
            # If data.get("sealed") is not bool, default to True => safe side
            sealed_raw = data.get("sealed", True)
            if not isinstance(sealed_raw, bool):
                # If it's not a boolean, assume sealed => True
                return True
            return sealed_raw

    async def get_active_token(self) -> str:
        """
        Ensure a valid Vault token is available, returning it for external usage.

        Returns:
            str: The current Vault token, guaranteed valid.

        Raises:
            RuntimeError: If a token could not be obtained.
        """
        await self._ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Unable to obtain a Vault token.")
        return self._client_token

    # --------------------------------------------------------------------------
    # KV V2 Methods
    # --------------------------------------------------------------------------
    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Read a secret from the KV v2 engine at the specified path.

        Args:
            path: Path under `secret/data/` where the secret resides.

        Returns:
            Dict[str, Any]: The secret data.

        Raises:
            RuntimeError: If the read fails or Vault returns a non-200.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/data/{path}"
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error reading secret: {resp.status}, {resp_json}")

        data_field = resp_json.get("data", {})
        sub_data = data_field.get("data")
        if isinstance(sub_data, dict):
            return sub_data
        return resp_json

    async def write_secret(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Write a secret to the KV v2 engine at the specified path.

        Args:
            path: Path under `secret/data/`.
            data: A dictionary of data to store.

        Returns:
            Dict[str, Any]: The Vault response JSON if 200, or empty if 204.

        Raises:
            RuntimeError: If the write fails or status is unexpected.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/data/{path}"
        payload: Dict[str, Any] = {"data": data}

        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            try:
                raw_json = await resp.json()
            except aiohttp.ContentTypeError:
                raw_json = {}

            if resp.status not in (200, 204):
                err_json = validate_type(raw_json, Dict[str, Any])
                raise RuntimeError(f"Error writing secret: {resp.status}, {err_json}")

            if resp.status == 200:
                resp_json = validate_type(raw_json, Dict[str, Any])
                return resp_json
        return {}

    async def write_secret_idempotent(
        self, path: str, data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Write a secret if the existing data differs; else do nothing.

        Args:
            path: Path under `secret/data/`.
            data: Data to store if changed/new.

        Returns:
            Vault response if a write is performed, else {}.

        Raises:
            RuntimeError: If read/write fail (other than 404 on read).
        """
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
        """
        Delete a secret at a given path. By default, soft delete. If hard=True => remove all versions.

        Args:
            path: The path under `secret/`.
            hard: If True => `secret/metadata/` => remove all versions permanently.

        Raises:
            RuntimeError: If deletion fails with a status not in (200, 204, 404).
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        if hard:
            url = f"{self._vault_addr}/v1/secret/metadata/{path}"
            method_label = "Hard"
        else:
            url = f"{self._vault_addr}/v1/secret/data/{path}"
            method_label = "Soft"

        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204, 404):
                raw_json = await resp.json()
                raise RuntimeError(
                    f"{method_label} delete failed: {resp.status}, {raw_json}"
                )

    async def list_secrets(self, path: str) -> List[str]:
        """
        List keys at a path (folder) in KV v2. Returns empty if 404.

        Args:
            path: The folder path under `secret/metadata/`.

        Returns:
            A list of keys, or empty if not found.

        Raises:
            RuntimeError: If request fails with status not in (200, 404).
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        if not path.endswith("/"):
            path += "/"

        url = f"{self._vault_addr}/v1/secret/metadata/{path}?list=true"
        headers = {"X-Vault-Token": self._client_token}
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
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
        """
        Retrieve metadata about versions of a secret in KV v2.

        Args:
            path: The path under `secret/metadata/`.

        Returns:
            A dictionary with version info, or {} if 404.

        Raises:
            RuntimeError: If request fails with status != 200 or 404.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/metadata/{path}"

        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_json = await resp.json()
            if resp.status == 404:
                return {}
            if resp.status != 200:
                raise RuntimeError(f"Error reading metadata: {resp.status}, {raw_json}")

        return validate_type(raw_json, Dict[str, Any])

    async def revoke_self_token(self) -> None:
        """
        Revoke the current Vault token. Clears the client token.

        Raises:
            RuntimeError: If revoke operation fails with status not in (200, 204).
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            return

        headers = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/auth/token/revoke-self"

        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204):
                detail = await resp.json()
                raise RuntimeError(f"Failed to revoke token: {resp.status}, {detail}")

        self._client_token = None

    # --------------------------------------------------------------------------
    # Transit Methods
    # --------------------------------------------------------------------------
    async def write_transit_key(
        self,
        key_name: str,
        idempotent: bool = False,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Create or update a transit key in Vault's Transit Secrets Engine.

        Args:
            key_name: The name of the transit key.
            idempotent: If True, create only if it doesn't already exist.
            params: Additional parameters for key creation.

        Returns:
            A dict with creation/updates, or {} if idempotent & key exists.

        Raises:
            RuntimeError: If creation fails or an unexpected status is returned.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers = {"X-Vault-Token": self._client_token}

        if idempotent:
            check_url = f"{self._vault_addr}/v1/transit/keys/{key_name}"
            async with session.get(
                check_url, headers=headers, ssl=self._verify_ssl
            ) as resp:
                if resp.status == 200:
                    return {}
                elif resp.status not in (404, 200):
                    check_json = await resp.json()
                    raise RuntimeError(
                        f"Error checking transit key existence: {resp.status}, {check_json}"
                    )

        url = f"{self._vault_addr}/v1/transit/keys/{key_name}"
        payload = params if params else {}

        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            try:
                resp_json = await resp.json()
            except aiohttp.ContentTypeError:
                resp_json = {}

            if resp.status not in (200, 204):
                raise RuntimeError(
                    f"Error creating/updating transit key: {resp.status}, {resp_json}"
                )
            if resp.status == 200:
                return validate_type(resp_json, Dict[str, Any])
        return {}

    async def encrypt_transit_data(self, key_name: str, plaintext: bytes) -> str:
        """
        Encrypt data using the specified transit key.

        Args:
            key_name: The transit key name.
            plaintext: Raw bytes to encrypt.

        Returns:
            A Vault-format ciphertext (e.g. "vault:v1:...").

        Raises:
            RuntimeError: If encryption fails or response status != 200.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        b64_plaintext = base64.b64encode(plaintext).decode("utf-8")

        url = f"{self._vault_addr}/v1/transit/encrypt/{key_name}"
        payload = {"plaintext": b64_plaintext}
        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error encrypting data: {resp.status}, {resp_json}")

        ciphertext = resp_json["data"].get("ciphertext")
        if not isinstance(ciphertext, str):
            raise RuntimeError("Vault response did not include valid ciphertext.")
        return ciphertext

    async def decrypt_transit_data(self, key_name: str, ciphertext: str) -> bytes:
        """
        Decrypt a Vault-format ciphertext using the named transit key.

        Args:
            key_name: The transit key name.
            ciphertext: The Vault-format ciphertext string.

        Returns:
            Raw decrypted bytes.

        Raises:
            RuntimeError: If decryption fails or status != 200.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()
        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/transit/decrypt/{key_name}"
        payload = {"ciphertext": ciphertext}

        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error decrypting data: {resp.status}, {resp_json}")

        b64_plaintext = resp_json["data"].get("plaintext")
        if not isinstance(b64_plaintext, str):
            raise RuntimeError("Vault response did not include valid plaintext.")
        return base64.b64decode(b64_plaintext)

    async def encrypt_transit_dict(
        self, key_name: str, data_dict: Dict[str, Any]
    ) -> str:
        """
        Serialize a dict to JSON, then encrypt using the named transit key.

        Args:
            key_name: The transit key name.
            data_dict: The dictionary to be serialized and encrypted.

        Returns:
            Vault-format ciphertext.

        Raises:
            RuntimeError: If encryption fails or response invalid.
            json.JSONDecodeError: If data_dict can't be JSON-encoded.
        """
        json_str = json.dumps(data_dict)
        json_bytes = json_str.encode("utf-8")
        return await self.encrypt_transit_data(key_name, json_bytes)

    async def decrypt_transit_dict(
        self, key_name: str, ciphertext: str
    ) -> Dict[str, Any]:
        """
        Decrypt a Vault-format ciphertext, parse as JSON => dict.

        Args:
            key_name: Transit key name.
            ciphertext: The vault ciphertext string.

        Returns:
            The Python dict that was previously encrypted.

        Raises:
            RuntimeError: If decryption fails or response invalid.
            json.JSONDecodeError: If decrypted data is not valid JSON.
        """
        plaintext_bytes = await self.decrypt_transit_data(key_name, ciphertext)
        json_str = plaintext_bytes.decode("utf-8")
        return validate_type(json.loads(json_str), Dict[str, Any])

    # --------------------------------------------------------------------------
    # Private Token Management
    # --------------------------------------------------------------------------
    async def _ensure_session(self) -> aiohttp.ClientSession:
        """
        Internal helper to ensure an aiohttp session is open.

        Returns:
            The current or newly created aiohttp.ClientSession.
        """
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def _ensure_valid_token(self) -> None:
        """
        Internal helper ensuring we have a valid token.
        If direct_token is set, we use it.
        Otherwise, do K8s login or token renewal as needed.

        Raises:
            RuntimeError: If token acquisition/renewal fails.
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
        except RuntimeError as e:
            if "403" in str(e):
                # Possibly expired/invalid
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
        """
        Internal method: Kubernetes login with local JWT, setting self._client_token.
        If direct_token is set, it is used instead.
        """
        if self._direct_token is not None:
            self._client_token = self._direct_token
            return

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
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Vault login failed: {resp.status}, {resp_json}")

            auth_data = resp_json.get("auth")
            if not isinstance(auth_data, dict) or "client_token" not in auth_data:
                raise RuntimeError("Vault did not return a valid client_token.")

        self._client_token = auth_data["client_token"]
        self._last_token_check = 0.0

    async def _renew_token(self) -> None:
        """
        Internal method: attempt to renew the current Vault token, else re-login.
        """
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
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status == 200:
                auth_data = resp_json.get("auth")
                if isinstance(auth_data, dict) and "client_token" in auth_data:
                    self._client_token = auth_data["client_token"]
                    return

        # If renewal fails, re-login
        await self._login()

    async def _get_token_info(self) -> Dict[str, Any]:
        """
        Internal method: get details about the current token (vault token lookup-self).

        Returns:
            A dict containing TTL, etc.

        Raises:
            RuntimeError: If token is not set or request fails.
        """
        if self._client_token is None:
            raise RuntimeError("Vault token is not set.")

        session = await self._ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/lookup-self"
        headers = {"X-Vault-Token": self._client_token}
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Token lookup failed: {resp.status}, {resp_json}")

        data_obj = resp_json.get("data")
        if not isinstance(data_obj, dict):
            raise RuntimeError("Token lookup did not return valid 'data'.")
        return data_obj
