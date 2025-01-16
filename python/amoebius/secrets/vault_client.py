# amoebius/secrets/vault_client.py

from __future__ import annotations

import time
import aiohttp
import aiofiles
import asyncio
from typing import Any, Dict, Optional, Type

from ..models.validator import validate_type
from ..models.vault_settings import VaultSettings


class AsyncVaultClient:
    """
    An asynchronous Vault client using Kubernetes Auth with automatic token management.
    Configuration is provided via a Pydantic `VaultSettings` object.
    """

    # We declare the attributes so Mypy recognizes them as instance variables
    _session: Optional[aiohttp.ClientSession]
    _client_token: Optional[str]
    _last_token_check: float

    def __init__(self, settings: VaultSettings) -> None:
        """
        Initializes the Vault client using a `VaultSettings` instance.

        Args:
            settings: A Pydantic model containing Vault config (addr, role_name, etc.)
        """
        self._vault_addr: str = settings.vault_addr
        self._vault_role_name: str = settings.vault_role_name
        self._token_path: str = settings.token_path
        self._verify_ssl: bool = settings.verify_ssl
        self._renew_threshold_seconds: float = settings.renew_threshold_seconds
        self._check_interval_seconds: float = settings.check_interval_seconds

        self._session = None
        self._client_token = None
        self._last_token_check = 0.0

    async def __aenter__(self) -> AsyncVaultClient:
        """
        Allows usage as an async context manager. When entering,
        an aiohttp session is created.
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
        Closes the aiohttp session on context exit.
        """
        if self._session:
            await self._session.close()
        self._session = None

    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Reads a secret from Vault, automatically ensuring the token is
        valid or renewed beforehand.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token unavailable after ensuring validity.")

        url = f"{self._vault_addr}/v1/{path}"
        headers = {"X-Vault-Token": self._client_token}

        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            resp_json = validate_type(
                raw_resp, Dict[str, Any]
            )  # Raises ValueError if invalid

            if resp.status != 200:
                raise RuntimeError(f"Error reading secret: {resp.status}, {resp_json}")

        # For KV v2, often the actual data is under resp_json["data"]["data"]
        data_field = resp_json.get("data")
        if isinstance(data_field, dict):
            sub_data = data_field.get("data")
            if isinstance(sub_data, dict):
                return sub_data

        return resp_json

    async def write_secret(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Writes data to a Vault secret path, ensuring the token is
        valid or renewed beforehand.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token unavailable after ensuring validity.")

        url = f"{self._vault_addr}/v1/{path}"
        headers = {"X-Vault-Token": self._client_token}
        payload: Dict[str, Any] = {"data": data}

        async with session.post(
            url, json=payload, headers=headers, ssl=self._verify_ssl
        ) as resp:
            if resp.status not in (200, 204):
                raw_error = await resp.json()
                err_json = validate_type(raw_error, Dict[str, Any])
                raise RuntimeError(f"Error writing secret: {resp.status}, {err_json}")

            if resp.status == 200:
                raw_resp = await resp.json()
                resp_json = validate_type(raw_resp, Dict[str, Any])
                return resp_json

        return {}

    # --------------------------------
    #       Private methods
    # --------------------------------
    async def _ensure_session(self) -> aiohttp.ClientSession:
        """
        Ensures an aiohttp ClientSession exists and returns it.
        """
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def _ensure_valid_token(self) -> None:
        """
        Checks the token TTL. If it does not exist or is near expiration,
        attempts to renew or re-authenticate using Kubernetes Auth.
        """
        now = time.time()
        if (
            self._last_token_check
            and (now - self._last_token_check) < self._check_interval_seconds
        ):
            return

        self._last_token_check = now

        if self._client_token is None:
            await self._login()
            return

        try:
            token_info = await self._get_token_info()
        except RuntimeError as e:
            if "403" in str(e):
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
        Authenticates to Vault using Kubernetes service account token
        and updates the stored Vault token upon success.
        """
        session = await self._ensure_session()

        # Read the service account token file
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
        """
        Attempts to renew the current Vault token. If renewal fails,
        re-authenticates via Kubernetes Auth.
        """
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

        # If renewal fails, do a full login again
        await self._login()

    async def _get_token_info(self) -> Dict[str, Any]:
        """
        Retrieves metadata about the current Vault token (including TTL).
        """
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
            raise RuntimeError("Token lookup did not return a valid 'data' object.")

        return data_obj


async def example_usage() -> None:
    """
    Demonstrates usage of the AsyncVaultClient with Pydantic settings.
    """
    # This will read environment variables: VAULT_ROLE_NAME, VAULT_ADDR, etc.
    # For example, VAULT_ROLE_NAME="my-k8s-role".
    settings = VaultSettings()

    async with AsyncVaultClient(settings) as vault_client:
        secret_data = await vault_client.read_secret("secret/data/my-app")
        print("Read secret:", secret_data)

        resp = await vault_client.write_secret("secret/data/my-app", {"some": "value"})
        print("Wrote secret:", resp)


def main() -> None:
    asyncio.run(example_usage())


if __name__ == "__main__":
    main()
