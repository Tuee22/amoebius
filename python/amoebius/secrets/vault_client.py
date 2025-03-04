"""
amoebius/secrets/vault_client.py

This module provides an asynchronous Vault client (`AsyncVaultClient`) that supports:
 - KV v2 operations (read, write, delete, list, history)
 - Transit encryption (create/update transit keys, encrypt/decrypt, file-based encrypt/decrypt)
 - Token management via either:
   - Direct token usage (settings.direct_vault_token), or
   - Kubernetes authentication (settings.vault_role_name + JWT-based login)
 - Automatic token renewal and re-login when required

Usage:
    async with AsyncVaultClient(settings) as client:
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
from typing import Any, Dict, Optional, Type, List

from amoebius.models.validator import validate_type
from amoebius.models.vault import VaultSettings


class AsyncVaultClient:
    """
    An asynchronous Vault client that manages:
      - KV v2 read/write/delete/list
      - Transit encrypt/decrypt/key creation (including dicts and files)
      - Automatic token acquisition & renewal (via Kubernetes auth or direct token)

    The client uses an internal aiohttp session and should be used as an async
    context manager, for example:

        async with AsyncVaultClient(settings) as client:
            secret_data = await client.read_secret("some/path")
            ...
    """

    _session: Optional[aiohttp.ClientSession]
    _client_token: Optional[str]
    _last_token_check: float

    def __init__(self, settings: VaultSettings) -> None:
        """
        Initializes the AsyncVaultClient.

        Args:
            settings (VaultSettings):
                A dataclass-like object containing configuration for Vault access:
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
            AsyncVaultClient: The client instance itself, ready for use.
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
            exc_type (Optional[Type[BaseException]]): Exception type if an exception occurred.
            exc_val (Optional[BaseException]): Exception value if an exception occurred.
            exc_tb (Optional[Any]): Traceback if an exception occurred.
        """
        if self._session:
            await self._session.close()
        self._session = None

    async def get_active_token(self) -> str:
        """
        Ensure a valid Vault token is available, returning it for external use.

        Returns:
            str: The active Vault token.

        Raises:
            RuntimeError: If a token could not be obtained.
        """
        await self._ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Unable to obtain a Vault token.")
        return self._client_token

    # ------------------
    # KV V2 Methods
    # ------------------
    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Read a secret from the KV v2 engine at the specified path.

        Args:
            path (str): The path under `secret/data/` where your secret resides.

        Returns:
            Dict[str, Any]: A dictionary of secret data.

        Raises:
            RuntimeError: If the read fails or if the Vault returns an error status.
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
        Overwrites existing data (unless using KV v2 versioning logic outside this method).

        Args:
            path (str): The path under `secret/data/`.
            data (Dict[str, Any]): A dictionary of data to store.

        Returns:
            Dict[str, Any]: The Vault response JSON if successful; may be empty if 204 is returned.

        Raises:
            RuntimeError: If the write operation fails or Vault returns an error status.
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
                # 204 No Content possible
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
        Write a secret only if the existing data differs from `data` or it doesn't exist.
        If the data matches exactly, no action is taken.

        Args:
            path (str): The path under `secret/data/`.
            data (Dict[str, Any]): The data to store if new or changed.

        Returns:
            Dict[str, Any]: The Vault response if a write is performed, or an empty dict if not.

        Raises:
            RuntimeError: If a read or write operation fails (other than a 404 on read).
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
        Delete a secret at a given path. By default, performs a "soft" delete in KV v2
        (which can be undone by versioning). If `hard=True`, the metadata is deleted,
        removing all versions permanently.

        Args:
            path (str): The path under `secret/`.
            hard (bool, optional): If True, use the `secret/metadata/` endpoint,
                removing all versions. Defaults to False.

        Raises:
            RuntimeError: If deletion fails with a status not in (200, 204, 404).
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

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
        List all secret keys at a given path (folder) in KV v2.

        Args:
            path (str): The path (folder) under `secret/metadata/`.

        Returns:
            List[str]: A list of keys (sub-paths) under the given folder.
                       Returns an empty list if 404 (folder does not exist).

        Raises:
            RuntimeError: If the list operation fails with a status != 200 or 404.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        if not path.endswith("/"):
            path += "/"

        url = f"{self._vault_addr}/v1/secret/metadata/{path}?list=true"
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
        Retrieve metadata about all versions of a secret (its "history") in KV v2.

        Args:
            path (str): The secret path under `secret/metadata/`.

        Returns:
            Dict[str, Any]: Metadata dictionary containing version info, etc.
                            Returns an empty dict if 404.

        Raises:
            RuntimeError: If the request fails with any status != 200 or 404.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
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
        Revoke the current Vault token (token/self-revoke).
        After calling this, the client token is cleared.

        Raises:
            RuntimeError: If the revoke operation fails with status != 200, 204.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            return

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/auth/token/revoke-self"

        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204):
                detail = await resp.json()
                raise RuntimeError(f"Failed to revoke token: {resp.status}, {detail}")

        self._client_token = None

    # ------------------
    # Transit Methods
    # ------------------
    async def write_transit_key(
        self,
        key_name: str,
        idempotent: bool = False,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Create or update a transit key in Vault's Transit Secrets Engine.

        Args:
            key_name (str): The name of the transit key.
            idempotent (bool, optional): If True, only create/update the key if it
                does not already exist. Defaults to False.
            params (Optional[Dict[str, Any]]): Additional parameters for key creation,
                such as:
                  - 'type': "aes256-gcm96", "rsa-2048", etc.
                  - 'derived': bool
                  - 'convergent_encryption': bool
                  - 'exportable': bool
                  - 'allow_plaintext_backup': bool
                (See Vault's API docs for full details.)

        Returns:
            Dict[str, Any]: The Vault response if a new key was created or updated.
                            An empty dict if idempotent is True and the key already existed.

        Raises:
            RuntimeError: If creation/updating fails or returns an unexpected status.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        if idempotent:
            # Check if key already exists
            check_url = f"{self._vault_addr}/v1/transit/keys/{key_name}"
            async with session.get(
                check_url, headers=headers, ssl=self._verify_ssl
            ) as resp:
                if resp.status == 200:
                    # Key already exists; skip creation
                    return {}
                elif resp.status not in (404, 200):
                    check_json = await resp.json()
                    raise RuntimeError(
                        f"Error checking transit key existence: {resp.status}, {check_json}"
                    )

        # Create or update the key
        url = f"{self._vault_addr}/v1/transit/keys/{key_name}"
        payload: Dict[str, Any] = params if params else {}

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
                # Validate only if it's a JSON response
                return validate_type(resp_json, Dict[str, Any])

        return {}

    async def encrypt_transit_data(self, key_name: str, plaintext: bytes) -> str:
        """
        Encrypt data using a named transit key.

        Args:
            key_name (str): The name of the transit key.
            plaintext (bytes): Raw bytes to encrypt (could be UTF-8, binary, JSON, etc.).

        Returns:
            str: The Vault-format ciphertext (e.g., "vault:v1:abc123...").

        Raises:
            RuntimeError: If encryption fails or Vault returns an unexpected response.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
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
        Decrypt data using a named transit key.

        Args:
            key_name (str): The name of the transit key.
            ciphertext (str): The Vault-format ciphertext to decrypt.

        Returns:
            bytes: The raw decrypted bytes from Vault.

        Raises:
            RuntimeError: If decryption fails or the response is invalid.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token is unavailable.")

        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
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
        Serialize a Python dictionary to JSON, then encrypt it using a named transit key.

        Args:
            key_name (str): The name of the transit key.
            data_dict (Dict[str, Any]): The dictionary to be serialized and encrypted.

        Returns:
            str: A Vault-format ciphertext (e.g., "vault:v1:abc123...").

        Raises:
            RuntimeError: If encryption fails or if Vault returns an invalid response.
            json.JSONDecodeError: If an error occurs while encoding the dictionary to JSON.
        """
        # 1. Serialize dict -> JSON string
        json_str = json.dumps(data_dict)
        # 2. Encode to bytes
        json_bytes = json_str.encode("utf-8")
        # 3. Encrypt the bytes
        ciphertext = await self.encrypt_transit_data(key_name, json_bytes)
        return ciphertext

    async def decrypt_transit_dict(
        self, key_name: str, ciphertext: str
    ) -> Dict[str, Any]:
        """
        Decrypt a Vault-format ciphertext (presumed to be JSON), then parse it into a Python dictionary.

        Args:
            key_name (str): The name of the transit key.
            ciphertext (str): The Vault-format ciphertext string.

        Returns:
            Dict[str, Any]: The dictionary that was previously encrypted.

        Raises:
            RuntimeError: If decryption fails or the response is invalid.
            json.JSONDecodeError: If the decrypted data is not valid JSON.
        """
        # 1. Decrypt to raw bytes
        plaintext_bytes = await self.decrypt_transit_data(key_name, ciphertext)
        # 2. Convert bytes -> UTF-8 string
        json_str = plaintext_bytes.decode("utf-8")
        # 3. Parse JSON into dict, validating the type
        data_dict = validate_type(json.loads(json_str), Dict[str, Any])
        return data_dict

    # async def encrypt_transit_file(self, key_name: str, file_path: str) -> str:
    #     """
    #     Reads a file from disk asynchronously, encrypts its contents using
    #     the specified transit key, and returns a Vault-format ciphertext string.

    #     Args:
    #         key_name (str): The name of the transit key in Vault.
    #         file_path (str): Path to the file on disk to be read and encrypted.

    #     Returns:
    #         str: A Vault-format ciphertext (e.g., "vault:v1:abc123...").

    #     Raises:
    #         RuntimeError: If encryption fails or if Vault returns an invalid response.
    #         OSError: If there's an error reading the file from disk.
    #     """
    #     # 1. Read the file content asynchronously
    #     async with aiofiles.open(file_path, "rb") as f:
    #         file_bytes = await f.read()

    #     # 2. Encrypt using existing transit method
    #     ciphertext = await self.encrypt_transit_data(key_name, file_bytes)
    #     return ciphertext

    # async def decrypt_transit_file(
    #     self, key_name: str, ciphertext: str, dest_path: str
    # ) -> None:
    #     """
    #     Decrypts the given Vault-format ciphertext using the specified transit key,
    #     then writes the resulting bytes asynchronously to a file on disk.

    #     Args:
    #         key_name (str): The name of the transit key in Vault.
    #         ciphertext (str): The Vault-format ciphertext (e.g., "vault:v1:abc123...").
    #         dest_path (str): The destination file path where decrypted bytes will be saved.

    #     Raises:
    #         RuntimeError: If decryption fails or if Vault returns an invalid response.
    #         OSError: If there's an error writing the file to disk.
    #     """
    #     # 1. Decrypt to raw bytes
    #     decrypted_bytes = await self.decrypt_transit_data(key_name, ciphertext)

    #     # 2. Write those bytes to the file asynchronously
    #     async with aiofiles.open(dest_path, "wb") as f:
    #         await f.write(decrypted_bytes)

    # ------------------
    # Private Token Management
    # ------------------
    async def _ensure_session(self) -> aiohttp.ClientSession:
        """
        Internal helper to ensure the aiohttp session is initialized.

        Returns:
            aiohttp.ClientSession: The session to be used for requests.
        """
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def _ensure_valid_token(self) -> None:
        """
        Internal helper to ensure the client has a valid token.
        If a direct token is provided, uses it.
        Otherwise, performs K8s-based login if necessary, and renews the token
        if the TTL is below the configured threshold.

        Raises:
            RuntimeError: If login or renewal attempts fail and no valid token is obtained.
        """
        # If direct token is provided, just use it
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
        """
        Internal method to perform Kubernetes-based login to Vault,
        retrieving a client token using the JWT from the local file system.

        Raises:
            RuntimeError: If the login fails or the response is missing expected fields.
        """
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
        Internal method to renew the current Vault token if possible.
        If renewal fails, a fresh login is attempted.
        """
        if self._direct_token is not None:
            self._client_token = self._direct_token
            return

        if self._client_token is None:
            await self._login()
            return

        session = await self._ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/renew-self"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status == 200:
                auth_data = resp_json.get("auth")
                if isinstance(auth_data, dict) and "client_token" in auth_data:
                    self._client_token = auth_data["client_token"]
                    return

        # Renewal failed, re-login
        await self._login()

    async def _get_token_info(self) -> Dict[str, Any]:
        """
        Internal method to retrieve information about the current token (lookup-self).

        Returns:
            Dict[str, Any]: A dictionary containing details such as TTL, creation time, etc.

        Raises:
            RuntimeError: If the token lookup fails or if the token is not set.
        """
        if self._client_token is None:
            raise RuntimeError("Vault token is not set.")

        session = await self._ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/lookup-self"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_json = await resp.json()
            resp_json = validate_type(raw_json, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Token lookup failed: {resp.status}, {resp_json}")

        data_obj = resp_json.get("data")
        if not isinstance(data_obj, dict):
            raise RuntimeError("Token lookup did not return valid 'data'.")
        return data_obj
