"""
amoebius/secrets/vault_client.py

An asynchronous Vault client that supports:
 - KV v2 (read, write, delete, list, history)
 - Transit encryption/decryption
 - Token management (Kubernetes or direct token usage)
 - Checking Vault seal status
 - Creating/deleting Vault ACL policies
 - Creating/deleting Vault K8s roles

Usage example:
    from amoebius.secrets.vault_client import AsyncVaultClient
    from amoebius.models.vault import VaultSettings

    settings = VaultSettings(vault_addr="http://vault:8200", vault_role_name="myRole")
    async with AsyncVaultClient(settings) as client:
        # e.g. client.read_secret("some/path")
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

__all__ = ["AsyncVaultClient"]


class AsyncVaultClient:
    """
    An asynchronous Vault client that manages:
      - KV v2 (read/write/delete/list/history)
      - Transit encrypt/decrypt
      - Token acquisition & renewal (Kubernetes or direct token)
      - Checking Vault seal status
      - Creating/deleting Vault ACL policies
      - Creating/deleting Kubernetes roles for user-based policies

    Typical usage:
        settings = VaultSettings(...)
        async with AsyncVaultClient(settings) as client:
            secret = await client.read_secret("some/path")
    """

    _session: Optional[aiohttp.ClientSession]
    _client_token: Optional[str]
    _last_token_check: float

    def __init__(self, settings: VaultSettings) -> None:
        """
        Initialize the AsyncVaultClient.

        Args:
            settings (VaultSettings):
                Contains vault_addr, vault_role_name, verify_ssl, etc.
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
        """
        Async context manager entry: creates an aiohttp session.
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
        Async context manager exit: closes the aiohttp session if open.
        """
        if self._session:
            await self._session.close()
        self._session = None

    async def ensure_session(self) -> aiohttp.ClientSession:
        """
        Ensure an aiohttp session is available, creating one if missing.

        Returns:
            The active aiohttp.ClientSession.
        """
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def ensure_valid_token(self) -> None:
        """
        Ensure we have a valid Vault token, performing login/renewal as needed.

        Raises:
            RuntimeError: If token acquisition/renewal fails.
        """
        if self._direct_token is not None:
            # If we have a direct token, just set it once
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
        Check if Vault is sealed or unavailable by calling /v1/sys/seal-status.

        Returns:
            True if sealed/unavailable, False if unsealed.

        Raises:
            RuntimeError: if request fails or status!=200
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
        Return a valid Vault token, ensuring it's renewed or acquired first.

        Raises:
            RuntimeError if no token can be acquired.

        Returns:
            The active Vault token string.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Unable to acquire a Vault token.")
        return self._client_token

    async def _login(self) -> None:
        """
        Internal method for K8s-based login or direct token usage.

        Raises:
            RuntimeError: if login fails or the token is invalid.
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
        Attempt token renewal, or re-login if renewal fails.
        """
        if self._direct_token is not None:
            self._client_token = self._direct_token
            return
        if not self._client_token:
            await self._login()
            return

        session = await self.ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/renew-self"
        headers = {"X-Vault-Token": self._client_token}
        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status == 200:
                ad = js.get("auth")
                if isinstance(ad, dict) and "client_token" in ad:
                    self._client_token = ad["client_token"]
                    return
        # If renewal unsuccessful, re-login
        await self._login()

    async def _get_token_info(self) -> Dict[str, Any]:
        """
        Retrieve token info from /v1/auth/token/lookup-self.

        Returns:
            A dict with token details (ttl, etc.).
        """
        if not self._client_token:
            raise RuntimeError("Vault token is not set.")

        session = await self.ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/lookup-self"
        headers = {"X-Vault-Token": self._client_token}
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            js = validate_type(raw_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Token lookup failed: {resp.status}, {js}")
        data_obj = js.get("data")
        if not isinstance(data_obj, dict):
            raise RuntimeError("lookup-self did not return 'data'")
        return data_obj

    # ------------------------------
    # KV V2 Methods
    # ------------------------------

    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Read a KV v2 secret at path='secret/data/{path}'.

        Args:
            path: e.g. "myapp/config"

        Returns:
            The secret data dict.

        Raises:
            RuntimeError if read fails or status != 200
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/data/{path}"
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            data_js = validate_type(raw_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error reading secret: {resp.status}, {data_js}")

        data_field = data_js.get("data", {})
        sub_data = data_field.get("data")
        if isinstance(sub_data, dict):
            return sub_data
        return data_js

    async def write_secret(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Write a secret to path='secret/data/{path}' (KV v2).

        Args:
            path: e.g. "myapp/config"
            data: dict of fields

        Returns:
            The Vault response JSON if 200, else {} if 204.

        Raises:
            RuntimeError if write fails or status not in (200, 204).
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        headers = {"X-Vault-Token": self._client_token}
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
        """
        Write a secret if existing data differs or doesn't exist.

        Args:
            path: e.g. "myapp/config"
            data: The data to store

        Returns:
            Vault response if a write is performed, else {}.

        Raises:
            RuntimeError if read/write fails
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
        Delete a KV v2 secret from path='secret/data/{path}' (soft) or metadata (hard).

        Args:
            path: e.g. "myapp/config"
            hard: if True => delete metadata => all versions. Otherwise just the data.

        Raises:
            RuntimeError if deletion fails with unexpected status
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        if hard:
            url = f"{self._vault_addr}/v1/secret/metadata/{path}"
        else:
            url = f"{self._vault_addr}/v1/secret/data/{path}"
        headers = {"X-Vault-Token": self._client_token}
        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204, 404):
                detail = await resp.json()
                label = "Hard" if hard else "Soft"
                raise RuntimeError(f"{label} delete failed: {resp.status}, {detail}")

    async def list_secrets(self, path: str) -> List[str]:
        """
        List secrets under path='secret/metadata/{path}?list=true'.

        Args:
            path: e.g. "myapp/" or "myapp"

        Returns:
            The list of child keys if path found, else [].

        Raises:
            RuntimeError if listing fails or not in [200, 404].
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not path.endswith("/"):
            path += "/"
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/metadata/{path}?list=true"
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            data_js = validate_type(raw_js, Dict[str, Any])
            if resp.status == 404:
                return []
            if resp.status != 200:
                raise RuntimeError(f"Error listing secrets: {resp.status}, {data_js}")
        data_field = data_js.get("data", {})
        keys = data_field.get("keys", [])
        if not isinstance(keys, list):
            return []
        return keys

    async def secret_history(self, path: str) -> Dict[str, Any]:
        """
        Retrieve metadata about all versions for path='secret/metadata/{path}'.

        Args:
            path: e.g. "myapp/config"

        Returns:
            The metadata dict if found, else {} if 404.
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/secret/metadata/{path}"
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            if resp.status == 404:
                return {}
            if resp.status != 200:
                raise RuntimeError(f"Error reading metadata: {resp.status}, {raw_js}")
        return validate_type(raw_js, Dict[str, Any])

    async def revoke_self_token(self) -> None:
        """
        Revoke the current client token (token/self-revoke).
        After this, the client token is cleared.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            return

        session = await self.ensure_session()
        url = f"{self._vault_addr}/v1/auth/token/revoke-self"
        headers = {"X-Vault-Token": self._client_token}
        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204):
                detail = await resp.json()
                raise RuntimeError(f"Failed to revoke token: {resp.status}, {detail}")
        self._client_token = None

    # ------------------------------
    # Transit Methods
    # ------------------------------

    async def write_transit_key(
        self,
        key_name: str,
        idempotent: bool = False,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Create/Update a Vault transit key at 'transit/keys/{key_name}'.

        Args:
            key_name: The name of the transit key
            idempotent: If True => skip creation if it already exists
            params: Additional JSON for key creation

        Returns:
            The Vault response if newly created/updated, else {} if skip.

        Raises:
            RuntimeError if request fails or status unexpected.
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        headers = {"X-Vault-Token": self._client_token}

        if idempotent:
            check_url = f"{self._vault_addr}/v1/transit/keys/{key_name}"
            async with session.get(
                check_url, headers=headers, ssl=self._verify_ssl
            ) as r:
                if r.status == 200:
                    return {}
                elif r.status not in (200, 404):
                    c_js = await r.json()
                    raise RuntimeError(
                        f"Checking transit key existence failed: {r.status}, {c_js}"
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
        """
        Encrypt data using Vault's transit engine at 'transit/encrypt/{key_name}'.

        Args:
            key_name: The transit key name
            plaintext: The raw bytes to encrypt

        Returns:
            The vault-format ciphertext

        Raises:
            RuntimeError if encryption fails
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        headers = {"X-Vault-Token": self._client_token}

        b64_plaintext = base64.b64encode(plaintext).decode("utf-8")
        url = f"{self._vault_addr}/v1/transit/encrypt/{key_name}"
        payload = {"plaintext": b64_plaintext}
        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            data_js = await resp.json()
            dval = validate_type(data_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error encrypting data: {resp.status}, {dval}")
        ct = dval["data"].get("ciphertext")
        if not isinstance(ct, str):
            raise RuntimeError("Vault response missing ciphertext.")
        return ct

    async def decrypt_transit_data(self, key_name: str, ciphertext: str) -> bytes:
        """
        Decrypt data using Vault's transit engine at 'transit/decrypt/{key_name}'.

        Args:
            key_name: The transit key name
            ciphertext: The vault-format ciphertext

        Returns:
            The raw decrypted bytes

        Raises:
            RuntimeError if decryption fails
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        headers = {"X-Vault-Token": self._client_token}
        url = f"{self._vault_addr}/v1/transit/decrypt/{key_name}"
        payload = {"ciphertext": ciphertext}
        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            data_js = await resp.json()
            dval = validate_type(data_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error decrypting data: {resp.status}, {dval}")
        b64_plain = dval["data"].get("plaintext")
        if not isinstance(b64_plain, str):
            raise RuntimeError("Vault response missing plaintext.")
        return base64.b64decode(b64_plain)

    async def encrypt_transit_dict(
        self, key_name: str, data_dict: Dict[str, Any]
    ) -> str:
        """
        Serialize a dict to JSON, then encrypt it with the named transit key.

        Args:
            key_name: The transit key name
            data_dict: The dictionary to encrypt

        Returns:
            The vault-format ciphertext
        """
        import json

        raw = json.dumps(data_dict).encode("utf-8")
        return await self.encrypt_transit_data(key_name, raw)

    async def decrypt_transit_dict(
        self, key_name: str, ciphertext: str
    ) -> Dict[str, Any]:
        """
        Decrypt a vault-format ciphertext, parse as JSON, return the dict.

        Args:
            key_name: The transit key name
            ciphertext: The vault-format ciphertext

        Returns:
            The decrypted dictionary
        """
        import json

        raw_bytes = await self.decrypt_transit_data(key_name, ciphertext)
        return validate_type(json.loads(raw_bytes.decode()), Dict[str, Any])

    # ------------------------------
    # ACL Policy Methods
    # ------------------------------

    async def put_policy(self, policy_name: str, policy_text: str) -> None:
        """
        Create or update a Vault ACL policy at path=sys/policies/acl/{policy_name}.

        Args:
            policy_name: The name of the ACL policy.
            policy_text: The HCL policy text to store.

        Raises:
            RuntimeError: If creation/updating fails or status not in [200, 204].
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        url = f"{self._vault_addr}/v1/sys/policies/acl/{policy_name}"
        headers = {"X-Vault-Token": self._client_token}
        payload = {"policy": policy_text}
        async with session.put(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            try:
                resp_js = await resp.json()
            except aiohttp.ContentTypeError:
                resp_js = {}
            if resp.status not in (200, 204):
                raise RuntimeError(
                    f"Error creating/updating policy {policy_name}: {resp.status}, {resp_js}"
                )

    async def delete_policy(self, policy_name: str) -> None:
        """
        Delete a Vault ACL policy by name.

        If it doesn't exist => 404 => skip, else must be [200,204,404].
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        url = f"{self._vault_addr}/v1/sys/policies/acl/{policy_name}"
        headers = {"X-Vault-Token": self._client_token}
        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204, 404):
                detail = await resp.json()
                raise RuntimeError(
                    f"Deleting policy {policy_name} failed: {resp.status}, {detail}"
                )

    async def create_user_secret_policy(
        self, policy_name: str, secret_path: str
    ) -> None:
        """
        Create or update a Vault policy that grants read-only access to 'secret_path'.
        'secret_path' is relative to 'secret/data/'.

        This is used for user-specific secrets, e.g. "amoebius/services/minio/id/<user>"

        Args:
            policy_name: The name of the policy in Vault
            secret_path: The path under KV, e.g. "amoebius/services/minio/id/namespace:name"
        """
        # read-only policy for that path
        policy_hcl = f"""
        path "secret/data/{secret_path}" {{
          capabilities = ["read"]
        }}

        path "secret/metadata/{secret_path}" {{
          capabilities = ["read", "list"]
        }}
        """
        await self.put_policy(policy_name, policy_hcl)

    # ------------------------------
    # Kubernetes Role Methods
    # ------------------------------

    async def create_k8s_role(
        self,
        role_name: str,
        bound_sa_names: List[str],
        bound_sa_namespaces: List[str],
        policies: List[str],
        ttl: str = "1h",
    ) -> None:
        """
        Create or update a Vault Kubernetes role that binds certain policies to K8s SAs.

        Args:
            role_name: The name of the role in Vault.
            bound_sa_names: e.g. ["amoebius"]
            bound_sa_namespaces: e.g. ["amoebius-admin"]
            policies: e.g. ["minio-user-amoebius"]
            ttl: Default "1h"
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        headers = {"X-Vault-Token": self._client_token}

        sa_name_csv = ",".join(bound_sa_names)
        sa_ns_csv = ",".join(bound_sa_namespaces)
        policy_csv = ",".join(policies)

        url = f"{self._vault_addr}/v1/auth/kubernetes/role/{role_name}"
        data = {
            "bound_service_account_names": sa_name_csv,
            "bound_service_account_namespaces": sa_ns_csv,
            "policies": policy_csv,
            "ttl": ttl,
        }
        async with session.post(
            url, json=data, headers=headers, ssl=self._verify_ssl
        ) as resp:
            try:
                resp_js = await resp.json()
            except aiohttp.ContentTypeError:
                resp_js = {}
            if resp.status not in (200, 204):
                raise RuntimeError(
                    f"Error creating/updating k8s role {role_name}: {resp.status}, {resp_js}"
                )

    async def delete_k8s_role(self, role_name: str) -> None:
        """
        Delete a Vault Kubernetes role by name. 404 => skip.
        """
        await self.ensure_valid_token()
        session = await self.ensure_session()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")

        url = f"{self._vault_addr}/v1/auth/kubernetes/role/{role_name}"
        headers = {"X-Vault-Token": self._client_token}
        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204, 404):
                detail = await resp.json()
                raise RuntimeError(
                    f"Deleting k8s role {role_name} failed: {resp.status}, {detail}"
                )
