"""
amoebius/secrets/vault_client.py

An asynchronous Vault client with:
 - KV v2 (read/write/delete/list/history)
 - Transit encrypt/decrypt
 - Checking if Vault is sealed
 - Creating/deleting Vault ACL policies
 - Creating/deleting Kubernetes roles
 - Checking if Vault is fully configured (is_vault_configured)
 - 'secret_history(...)' for retrieving KV v2 metadata about all versions

No local imports, passes mypy --strict, no for loops for side effects.
"""

from __future__ import annotations

import time
import base64
import json
import aiohttp
import aiofiles
from typing import Any, Dict, List, Optional, Type

from amoebius.models.validator import validate_type
from amoebius.models.vault import VaultSettings
from amoebius.utils.k8s import get_k8s_secret_data
from amoebius.utils.async_retry import async_retry


class AsyncVaultClient:
    """
    An asynchronous Vault client that manages:
      - KV v2 usage (read, write, delete, list, history)
      - Transit encryption/decryption
      - Token acquisition/renewal (Kubernetes or direct token)
      - Checking Vault seal status
      - ACL policy management
      - K8s role management
      - Checking if Vault is configured (is_vault_configured)
    """

    def __init__(self, settings: VaultSettings) -> None:
        """
        Initialize the AsyncVaultClient.

        Args:
            settings: A VaultSettings object with vault_addr, role_name, verify_ssl, etc.
        """
        self._vault_addr = settings.vault_addr
        self._vault_role_name = settings.vault_role_name
        self._token_path = settings.token_path
        self._verify_ssl = settings.verify_ssl
        self._renew_threshold_seconds = settings.renew_threshold_seconds
        self._check_interval_seconds = settings.check_interval_seconds
        self._direct_token = settings.direct_vault_token

        self._session: Optional[aiohttp.ClientSession] = None
        self._client_token: Optional[str] = None
        self._last_token_check = 0.0

    async def __aenter__(self) -> AsyncVaultClient:
        """Async context manager entry, creates an aiohttp session."""
        self._session = aiohttp.ClientSession()
        return self

    async def __aexit__(
        self,
        exc_type: Optional[Type[BaseException]],
        exc_val: Optional[BaseException],
        exc_tb: Optional[Any],
    ) -> None:
        """Async context manager exit, closes the aiohttp session if open."""
        if self._session:
            await self._session.close()
        self._session = None

    async def ensure_session(self) -> aiohttp.ClientSession:
        """Ensure an aiohttp session is available, creating one if needed."""
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def ensure_valid_token(self) -> None:
        """
        Ensure we have a valid Vault token, performing login or renewal if needed.

        Raises:
            RuntimeError: If token acquisition/renewal fails.
        """
        if self._direct_token is not None:
            # If we have a direct token, just store it once
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
                # Possibly token is invalid => re-login
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
        Internal method for Kubernetes-based login or direct token usage.

        Raises:
            RuntimeError: If login fails or no vault_role_name is set.
        """
        if self._direct_token is not None:
            self._client_token = self._direct_token
            return

        if not self._vault_role_name:
            raise RuntimeError("No vault_role_name set for K8s auth method.")

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
        """Attempt token renewal; if unsuccessful, do a fresh login."""
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
        await self._login()

    async def _get_token_info(self) -> Dict[str, Any]:
        """Retrieve token info from /v1/auth/token/lookup-self."""
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

    async def is_vault_sealed(self) -> bool:
        """
        Check if Vault is sealed by calling /v1/sys/seal-status.

        Returns:
            True if sealed/unavailable, False if unsealed.
        """
        session = await self.ensure_session()
        url = f"{self._vault_addr}/v1/sys/seal-status"
        async with session.get(url, ssl=self._verify_ssl) as resp:
            data = await resp.json()
            if resp.status != 200:
                raise RuntimeError(f"seal-status check failed: {resp.status}, {data}")
            return bool(data.get("sealed", True))

    async def is_vault_configured(self) -> bool:
        """
        Check if Vault is fully configured by reading 'vault-config-status' in 'amoebius' NS,
        expecting {"configured":"true"} if done.
        """
        secret_data = await get_k8s_secret_data("vault-config-status", "amoebius")
        if not secret_data:
            return False
        return secret_data.get("configured") == "true"

    async def get_active_token(self) -> str:
        """Return a valid Vault token, ensuring renewal or login first."""
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Unable to acquire a Vault token.")
        return self._client_token

    async def revoke_self_token(self) -> None:
        """Revoke the current client token (token/self-revoke)."""
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
    # KV V2 Methods
    # ------------------------------
    async def read_secret(self, path: str) -> Dict[str, Any]:
        """Read a KV v2 secret from 'secret/data/{path}'."""
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

        url = f"{self._vault_addr}/v1/secret/data/{path}"
        headers = {"X-Vault-Token": self._client_token}
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
        """Write a KV v2 secret at 'secret/data/{path}'."""
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

        url = f"{self._vault_addr}/v1/secret/data/{path}"
        headers = {"X-Vault-Token": self._client_token}
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
        """Write a secret only if existing data differs or doesn't exist."""
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
        """Delete a KV v2 secret from 'secret/data/{path}' or 'secret/metadata/{path}' (hard)."""
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

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
        """List secrets under 'secret/metadata/{path}?list=true'."""
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

        if not path.endswith("/"):
            path += "/"
        url = f"{self._vault_addr}/v1/secret/metadata/{path}?list=true"
        headers = {"X-Vault-Token": self._client_token}
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
        Retrieve metadata about all versions for path='secret/metadata/{path}' in KV v2.

        Returns:
            The metadata dict if found, else {} if 404.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

        url = f"{self._vault_addr}/v1/secret/metadata/{path}"
        headers = {"X-Vault-Token": self._client_token}
        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_js = await resp.json()
            if resp.status == 404:
                return {}
            if resp.status != 200:
                raise RuntimeError(f"Error reading metadata: {resp.status}, {raw_js}")
        return validate_type(raw_js, Dict[str, Any])

    # ------------------------------
    # Transit Methods
    # ------------------------------
    @async_retry(retries=3)
    async def write_transit_key(
        self,
        key_name: str,
        idempotent: bool = False,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Create/update a Vault transit key at 'transit/keys/{key_name}'.
        If idempotent => check existence first.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

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
        Returns the vault-format ciphertext (e.g. "vault:v1:...").
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

        b64_plaintext = base64.b64encode(plaintext).decode("utf-8")
        url = f"{self._vault_addr}/v1/transit/encrypt/{key_name}"
        payload = {"plaintext": b64_plaintext}
        headers = {"X-Vault-Token": self._client_token}

        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            data_js = await resp.json()
            dval = validate_type(data_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error encrypting data: {resp.status}, {dval}")
        ct = dval["data"].get("ciphertext")
        if not isinstance(ct, str):
            raise RuntimeError("Vault response missing 'ciphertext'.")
        return ct

    async def decrypt_transit_data(self, key_name: str, ciphertext: str) -> bytes:
        """
        Decrypt data using Vault's transit engine at 'transit/decrypt/{key_name}'.
        Returns the raw decrypted bytes.

        Raises:
            RuntimeError: If decryption fails or missing fields.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

        url = f"{self._vault_addr}/v1/transit/decrypt/{key_name}"
        payload = {"ciphertext": ciphertext}
        headers = {"X-Vault-Token": self._client_token}

        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            data_js = await resp.json()
            dval = validate_type(data_js, Dict[str, Any])
            if resp.status != 200:
                raise RuntimeError(f"Error decrypting data: {resp.status}, {dval}")
        b64_plain = dval["data"].get("plaintext")
        if not isinstance(b64_plain, str):
            raise RuntimeError("Vault response missing 'plaintext'.")
        return base64.b64decode(b64_plain)

    # ------------------------------
    # ACL Policy Methods
    # ------------------------------
    async def put_policy(self, policy_name: str, policy_text: str) -> None:
        """Create or update a Vault ACL policy at sys/policies/acl/{policy_name}."""
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

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
        """Delete a Vault ACL policy by name, ignoring 404."""
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

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
        Create or update a read-only Vault policy for 'secret_path' under the KV engine.
        """
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
        Create or update a Vault Kubernetes role that binds certain policies to given K8s SAs.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

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
        Delete a Vault Kubernetes role by name, ignoring 404.
        """
        await self.ensure_valid_token()
        if not self._client_token:
            raise RuntimeError("Vault token unavailable.")
        session = await self.ensure_session()

        url = f"{self._vault_addr}/v1/auth/kubernetes/role/{role_name}"
        headers = {"X-Vault-Token": self._client_token}
        async with session.delete(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204, 404):
                detail = await resp.json()
                raise RuntimeError(
                    f"Deleting k8s role {role_name} failed: {resp.status}, {detail}"
                )
