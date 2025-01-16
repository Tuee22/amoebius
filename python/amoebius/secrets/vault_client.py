#!/usr/bin/env python3
# vault_async.py

"""
An asynchronous Vault client for Kubernetes authentication.

This module provides:
- A single class, `AsyncVaultClient`, which:
  1. Logs in to Vault using a Kubernetes service account token (Bound SA token).
  2. Automatically renews or re-authenticates the Vault token when near expiration.
  3. Exposes `read_secret` and `write_secret` methods for KV-based secret storage.

Default behaviors:
- Reads the Kubernetes token from /var/run/secrets/kubernetes.io/serviceaccount/token
- Uses the environment variable `VAULT_ADDR` if set, otherwise falls back to
  http://vault.vault.svc.cluster.local:8200
- Uses the environment variable `VAULT_ROLE_NAME` if set, otherwise "default"

Production considerations:
- Consider adding logging, retries, and error handling as needed.
- If `aiofiles` has incomplete stubs for mypy, you may need:
  `# type: ignore` or to install `types-aiofiles`.
"""

from __future__ import annotations

import os
import time
import json
import asyncio
import aiohttp
import aiofiles  # type: ignore[import]
from typing import Any, Dict, Optional

class AsyncVaultClient:
    """
    An asynchronous Vault client that uses Kubernetes Auth and automatically
    renews or re-authenticates its token.

    Typical usage:

        async with AsyncVaultClient() as vault_client:
            await vault_client.login()  # Get an initial token
            secret_data = await vault_client.read_secret("secret/data/my-path")
            ...

    Attributes:
        vault_addr:
            The Vault address (e.g., "http://vault.vault.svc.cluster.local:8200").
            Defaults to the VAULT_ADDR environment variable if set, otherwise the hardcoded URL.
        role_name:
            The Vault Kubernetes authentication role name.
            Defaults to the VAULT_ROLE_NAME environment variable if set, otherwise "default".
        token_path:
            Path to the bound service account token file, typically
            /var/run/secrets/kubernetes.io/serviceaccount/token.
        verify_ssl:
            Whether to verify Vault's TLS certificate.
        renew_threshold_seconds:
            If the Vault token's remaining TTL is below this threshold (in seconds),
            attempt to renew it. If renewal fails, re-authenticate.
        check_interval_seconds:
            How often (in seconds) to check the token's TTL (to avoid calling
            Vault too frequently).
    """

    def __init__(
        self,
        vault_addr: Optional[str] = None,
        role_name: Optional[str] = None,
        token_path: Optional[str] = None,
        verify_ssl: bool = True,
        renew_threshold_seconds: float = 60.0,
        check_interval_seconds: float = 60.0
    ) -> None:
        """
        Initializes an AsyncVaultClient instance with optional overrides.

        :param vault_addr:
            Vault address (e.g. "http://vault.vault.svc.cluster.local:8200").
            Defaults to the VAULT_ADDR environment variable or
            "http://vault.vault.svc.cluster.local:8200".
        :param role_name:
            The Vault Kubernetes authentication role name.
            Defaults to the VAULT_ROLE_NAME environment variable or "default".
        :param token_path:
            The file path to the Kubernetes service account token.
            Defaults to "/var/run/secrets/kubernetes.io/serviceaccount/token".
        :param verify_ssl:
            Whether or not to verify SSL certificates when contacting Vault.
        :param renew_threshold_seconds:
            Remaining TTL (in seconds) below which the token should be renewed.
        :param check_interval_seconds:
            How often (in seconds) to check the token TTL, to avoid calling Vault too frequently.
        """
        self.vault_addr: str = (
            vault_addr or os.getenv("VAULT_ADDR", "http://vault.vault.svc.cluster.local:8200")
        )
        self.role_name: str = role_name or os.getenv("VAULT_ROLE_NAME", "default")
        self.token_path: str = token_path or "/var/run/secrets/kubernetes.io/serviceaccount/token"
        self.verify_ssl: bool = verify_ssl

        self._client_token: Optional[str] = None
        self._session: Optional[aiohttp.ClientSession] = None

        # Auto-renew settings
        self._renew_threshold_seconds: float = renew_threshold_seconds
        self._check_interval_seconds: float = check_interval_seconds
        self._last_token_check: float = 0.0

    async def __aenter__(self) -> AsyncVaultClient:
        """
        Allows usage as an async context manager. Automatically creates a ClientSession.
        """
        self._session = aiohttp.ClientSession()
        return self

    async def __aexit__(
        self,
        exc_type: Optional[type[BaseException]],
        exc_val: Optional[BaseException],
        exc_tb: Optional[Any]
    ) -> None:
        """
        Closes the aiohttp ClientSession when exiting the async context manager.
        """
        if self._session is not None:
            await self._session.close()
        self._session = None

    async def login(self) -> None:
        """
        Authenticates to Vault using the Kubernetes Auth method. Reads the
        (potentially rotated) service account token from the file system
        and exchanges it for a Vault client token.

        :raises RuntimeError: if the login request fails.
        """
        await self._ensure_session()

        # Read the service account JWT from the token file
        async with aiofiles.open(self.token_path, "r") as f:
            jwt = await f.read()

        # Prepare the Kubernetes Auth request
        url: str = f"{self.vault_addr}/v1/auth/kubernetes/login"
        payload: Dict[str, str] = {"jwt": jwt, "role": self.role_name}

        async with self._session.post(url, json=payload, ssl=self.verify_ssl) as resp:
            resp_json = await resp.json()
            if resp.status != 200:
                raise RuntimeError(f"Error logging into Vault: {resp.status}, {resp_json}")

            auth_data = resp_json.get("auth")
            if not auth_data or "client_token" not in auth_data:
                raise RuntimeError("Vault did not return a client_token during login.")

        self._client_token = auth_data["client_token"]
        # Force a TTL check on the next request
        self._last_token_check = 0.0

    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Reads a secret from Vault using the stored token. Automatically
        ensures the token is still valid (renewing or re-authenticating if needed).

        :param path: The Vault path to read (e.g., "secret/data/my-secret").
        :return: A dict containing the secret data.
        :raises RuntimeError: if Vault returns a non-200 status or the token is unavailable.
        """
        await self._ensure_session()
        await self._ensure_valid_token()

        if not self._client_token:
            raise RuntimeError("No client token available after ensuring token validity.")

        url: str = f"{self.vault_addr}/v1/{path}"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        async with self._session.get(url, ssl=self.verify_ssl, headers=headers) as resp:
            resp_json = await resp.json()
            if resp.status != 200:
                raise RuntimeError(f"Error reading secret from Vault: {resp.status}, {resp_json}")

        # For Vault KV v2: secret data typically resides under resp_json["data"]["data"]
        if "data" in resp_json and "data" in resp_json["data"]:
            return resp_json["data"]["data"]
        return resp_json

    async def write_secret(self, path: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Writes a secret to Vault using the stored token. Automatically
        ensures the token is still valid (renewing or re-authenticating if needed).

        :param path: The Vault path to write (e.g., "secret/data/my-secret").
        :param data: A dict of the data to store in the secret.
        :return: A dict containing the response from Vault (may be empty for 204 responses).
        :raises RuntimeError: if Vault returns a non-(200|204) status or the token is unavailable.
        """
        await self._ensure_session()
        await self._ensure_valid_token()

        if not self._client_token:
            raise RuntimeError("No client token available after ensuring token validity.")

        url: str = f"{self.vault_addr}/v1/{path}"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}
        payload: Dict[str, Any] = {"data": data}

        async with self._session.post(url, json=payload, ssl=self.verify_ssl, headers=headers) as resp:
            if resp.status not in (200, 204):
                resp_json = await resp.json()
                raise RuntimeError(f"Error writing secret to Vault: {resp.status}, {resp_json}")

            try:
                return await resp.json()
            except aiohttp.ContentTypeError:
                # e.g., 204 No Content
                return {}

    async def _ensure_session(self) -> None:
        """
        Ensures that an aiohttp ClientSession is available. Creates one if not present.
        """
        if self._session is None:
            self._session = aiohttp.ClientSession()

    async def _ensure_valid_token(self) -> None:
        """
        Checks the token's TTL (via token lookup). If it's near expiration,
        attempts to renew it. If renewal fails or the token is invalid,
        it re-authenticates with Vault.
        """
        # Only check if we've gone past check_interval_seconds
        now: float = time.time()
        if now - self._last_token_check < self._check_interval_seconds:
            return

        self._last_token_check = now

        # If we have no token yet, just login
        if not self._client_token:
            await self.login()
            return

        # 1) Lookup the token
        try:
            token_info = await self._get_token_info()
        except RuntimeError as e:
            # If token lookup fails (e.g., 403), try a fresh login
            if "403" in str(e):
                await self.login()
                return
            raise

        ttl = token_info.get("ttl")
        if ttl is None:
            # If token data doesn't have a TTL, we can't renew; re-login
            await self.login()
            return

        # 2) Renew if TTL is below threshold
        if ttl < self._renew_threshold_seconds:
            await self._renew_token()

    async def _renew_token(self) -> None:
        """
        Attempts to renew the current Vault token (if renewable).
        If the token is invalid or not renewable, re-authenticates instead.
        """
        if not self._client_token:
            await self.login()
            return

        await self._ensure_session()

        url: str = f"{self.vault_addr}/v1/auth/token/renew-self"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        async with self._session.post(url, ssl=self.verify_ssl, headers=headers) as resp:
            resp_json = await resp.json()
            # 200 -> successful renewal, anything else -> re-auth
            if resp.status == 200:
                auth_data = resp_json.get("auth")
                if auth_data and "client_token" in auth_data:
                    self._client_token = auth_data["client_token"]
                    return
            # If renew fails, re-auth
            await self.login()

    async def _get_token_info(self) -> Dict[str, Any]:
        """
        Calls Vault's token lookup-self endpoint to retrieve metadata about the token.

        :return: Token info as a dict (typically includes "ttl", etc.).
        :raises RuntimeError: if Vault returns a non-200 response.
        """
        if not self._client_token:
            raise RuntimeError("No client token available.")

        await self._ensure_session()

        url: str = f"{self.vault_addr}/v1/auth/token/lookup-self"
        headers: Dict[str, str] = {"X-Vault-Token": self._client_token}

        async with self._session.get(url, ssl=self.verify_ssl, headers=headers) as resp:
            resp_json = await resp.json()
            if resp.status != 200:
                raise RuntimeError(f"Token lookup failed: {resp.status}, {resp_json}")
            data = resp_json.get("data", {})
            return data


async def _example_usage() -> None:
    """
    Example usage of AsyncVaultClient in an async function. In real code,
    remove or modify this to suit your application's needs.
    """
    async with AsyncVaultClient() as vault_client:
        # Login initially
        await vault_client.login()

        # Read a secret
        secret_path = "secret/data/my-app"
        secret_data = await vault_client.read_secret(secret_path)
        print("Secret data:", secret_data)

        # Write a secret
        write_data = {"api_key": "my-secret-key-value"}
        response = await vault_client.write_secret(secret_path, write_data)
        print("Write response:", response)


def main() -> None:
    """
    Demonstrates how to run the example usage in a synchronous entrypoint.
    """
    asyncio.run(_example_usage())


if __name__ == "__main__":
    main()
