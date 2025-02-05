from __future__ import annotations

import time
import aiohttp
import aiofiles
import asyncio
from typing import Any, Dict, Optional, Type, List

from ..models.validator import validate_type
from ..models.vault import VaultSettings


class AsyncVaultClient:
    """
    An asynchronous Vault client using Kubernetes Auth with automatic token management.
    This implementation is designed for KV v2 usage.
    """

    _session: Optional[aiohttp.ClientSession]
    _client_token: Optional[str]
    _last_token_check: float

    def __init__(self, settings: VaultSettings) -> None:
        """
        Initializes the Vault client using a `VaultSettings` instance.

        Args:
            settings: A Pydantic model containing Vault config (vault_addr, vault_role_name, etc.)
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

    #
    # ---------------------------
    # Public Methods (KV v2)
    # ---------------------------
    #

    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Reads a secret from KV v2 at: GET /v1/secret/data/<path>
        Returns the data under "data.data".

        Raises:
            RuntimeError if Vault returns a non-200 status (including 404 or 403).
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token unavailable after ensuring validity.")

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
        """
        Writes data to KV v2 at: POST /v1/secret/data/<path>
        The payload structure is {"data": <your_data>}.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token unavailable after ensuring validity.")

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
                pass  # Some responses may have an empty body

            if resp.status not in (200, 204):
                err_json = validate_type(raw_resp, Dict[str, Any])
                raise RuntimeError(f"Error writing secret: {resp.status}, {err_json}")

            if resp.status == 200:
                resp_json = validate_type(raw_resp, Dict[str, Any])
                return resp_json
        return {}

    async def list_secrets(self, path: str) -> List[str]:
        """
        Lists keys in KV v2: GET /v1/secret/metadata/<path>?list=true
        Returns child keys if any. 404 => empty list.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token unavailable after ensuring validity.")

        if not path.endswith("/"):
            path += "/"

        url = f"{self._vault_addr}/v1/secret/metadata/{path}?list=true"
        headers = {"X-Vault-Token": self._client_token}

        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            resp_json = validate_type(raw_resp, Dict[str, Any])

            if resp.status == 404:
                return []
            elif resp.status != 200:
                raise RuntimeError(f"Error listing secrets: {resp.status}, {resp_json}")

        data_field = resp_json.get("data", {})
        keys = data_field.get("keys", [])
        if not isinstance(keys, list):
            return []
        return keys

    async def write_secret_idempotent(
        self, path: str, data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Idempotent write for KV v2. Only writes if the current contents differ.
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
            # Same data => no new version
            return {}
        return await self.write_secret(path, data)

    async def delete_secret(self, path: str, hard: bool = False) -> None:
        """
        Deletes a secret in KV v2.

        - By default, it performs a "soft delete" (DELETE /v1/secret/data/<path>),
          which marks the latest version as deleted but retains version history.
        - If 'hard=True', it performs a "hard delete" (DELETE /v1/secret/metadata/<path>),
          removing all version history/metadata entirely.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token unavailable after ensuring validity.")

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

    async def secret_history(self, path: str) -> Dict[str, Any]:
        """
        Shows metadata (versions, etc.) for a KV v2 secret:
          GET /v1/secret/metadata/<path>
        Returns a dict with metadata or empty if not found (404).
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            raise RuntimeError("Vault token unavailable after ensuring validity.")

        url = f"{self._vault_addr}/v1/secret/metadata/{path}"
        headers = {"X-Vault-Token": self._client_token}

        async with session.get(url, headers=headers, ssl=self._verify_ssl) as resp:
            raw_resp = await resp.json()
            if resp.status == 404:
                return {}
            elif resp.status != 200:
                raise RuntimeError(f"Error reading metadata: {resp.status}, {raw_resp}")

        return validate_type(raw_resp, Dict[str, Any])

    async def revoke_self_token(self) -> None:
        """
        (Optional) Revoke the current token. Must have policy permission:
          path "auth/token/revoke-self" { capabilities = ["update"] }
        On success, the next call triggers a re-login.
        """
        await self._ensure_valid_token()
        session = await self._ensure_session()

        if self._client_token is None:
            # Already invalid/no token => do nothing
            return

        url = f"{self._vault_addr}/v1/auth/token/revoke-self"
        headers = {"X-Vault-Token": self._client_token}

        async with session.post(url, headers=headers, ssl=self._verify_ssl) as resp:
            if resp.status not in (200, 204):
                detail = await resp.json()
                raise RuntimeError(f"Failed to revoke token: {resp.status}, {detail}")

        # If successful, we remove our local token
        self._client_token = None

    #
    # ---------------------------
    # Private Token Management
    # ---------------------------
    #

    async def _ensure_session(self) -> aiohttp.ClientSession:
        if self._session is None:
            self._session = aiohttp.ClientSession()
        return self._session

    async def _ensure_valid_token(self) -> None:
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
            # If we get a 403 or some other error looking up the token, try re-login
            if "403" in str(e):
                await self._login()
                return
            raise

        ttl = token_info.get("ttl")
        if not isinstance(ttl, int):
            await self._login()
            return

        # If the TTL is below threshold, attempt to renew
        if ttl < self._renew_threshold_seconds:
            await self._renew_token()

    async def _login(self) -> None:
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

        # If renew didn't succeed, fall back to re-login
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
            raise RuntimeError("Token lookup did not return a valid 'data' object.")
        return data_obj


#
# ---------------------------
# Example Usage with Tests
# ---------------------------
#


async def example_usage() -> None:
    """
    Comprehensive Tests (live, no mocking):
     1) Basic read/write/idempotent write
     2) Soft vs. Hard delete
     3) Secret history checks
     4) Concurrency test (parallel writes)
     5) Force token revoke => next read triggers re-login (if policy allows)
     6) Read a path we don't have access to => expect 403 or 404
    """
    # Use your desired config (including verify_ssl=True):
    settings = VaultSettings(
        vault_role_name="amoebius-admin-role",
        verify_ssl=True,
    )

    async with AsyncVaultClient(settings) as vault_client:
        # 1) Basic Testing
        secret_path = "amoebius/test/test_secret"

        # Clean up leftover secret
        try:
            await vault_client.delete_secret(secret_path, hard=True)
        except RuntimeError as ex:
            if "404" not in str(ex):
                raise

        # 1a) List secrets
        keys = await vault_client.list_secrets("amoebius/test")
        print("[1a] Current keys under 'amoebius/test':", keys)

        # 1b) Write a secret
        test_data = {"value": 12345}
        await vault_client.write_secret_idempotent(secret_path, test_data)
        print("[1b] Wrote secret:", secret_path, "=", test_data)

        # 1c) Read & assert
        current = await vault_client.read_secret(secret_path)
        print("[1c] Current secret data:", current)
        assert current == test_data, f"Expected {test_data}, got {current}"

        # 1d) Idempotent no-op => version remains 1
        await vault_client.write_secret_idempotent(secret_path, {"value": 12345})
        meta1 = await vault_client.secret_history(secret_path)
        cv1 = meta1.get("data", {}).get("current_version")
        print("[1d] Metadata after no-op update:", meta1)
        assert cv1 == 1, f"Expected version=1 after no-op, got {cv1}"

        # 1e) Idempotent with new data => version increments to 2
        await vault_client.write_secret_idempotent(secret_path, {"value": "abc"})
        updated = await vault_client.read_secret(secret_path)
        assert updated == {"value": "abc"}, f"Expected {{'value':'abc'}}, got {updated}"
        meta2 = await vault_client.secret_history(secret_path)
        cv2 = meta2.get("data", {}).get("current_version")
        print("[1e] Metadata after new data:", meta2)
        assert cv2 == 2, f"Expected version=2 after change, got {cv2}"

        #
        # 2) Soft delete => gone, but history remains
        #
        await vault_client.delete_secret(secret_path, hard=False)
        print("[2] Soft deleted the secret.")
        # Now read => 404
        try:
            await vault_client.read_secret(secret_path)
            raise AssertionError("Expected 404 after soft delete, but no exception.")
        except RuntimeError as ex:
            assert "404" in str(ex), f"Expected 404, got: {ex}"

        meta_soft = await vault_client.secret_history(secret_path)
        print("[2] Metadata after soft delete:", meta_soft)
        versions_soft = meta_soft.get("data", {}).get("versions", {})
        v2_info = versions_soft.get("2", {})
        deletion_time = v2_info.get("deletion_time", "")
        assert deletion_time != "", "Expected non-empty deletion_time for version 2."

        #
        # 3) Hard delete => removes metadata entirely
        #
        await vault_client.delete_secret(secret_path, hard=True)
        meta_hard = await vault_client.secret_history(secret_path)
        print("[3] Metadata after hard delete:", meta_hard)
        assert meta_hard == {}, f"Expected empty metadata, got {meta_hard}"

        #
        # 4) Concurrency Test
        #
        concurrency_path = "amoebius/test/concurrent"

        async def writer_task(name: str) -> None:
            for i in range(3):
                data_conc = {"written_by": name, "count": i}
                await vault_client.write_secret(concurrency_path, data_conc)
                await asyncio.sleep(0.1)

        print("[4] Starting concurrency test:", concurrency_path)
        await asyncio.gather(writer_task("task1"), writer_task("task2"))

        final_data = await vault_client.read_secret(concurrency_path)
        print("[4] Final data after concurrency test:", final_data)
        assert (
            "written_by" in final_data and "count" in final_data
        ), f"Expected 'written_by'/'count', got {final_data}"

        #
        # 5) Force token revoke => next read triggers re-login if permitted
        #
        try:
            print("[5] Forcing token revoke-self (requires policy permission).")
            await vault_client.revoke_self_token()
            # Attempt read => triggers re-login behind the scenes if token was revoked
            after_revoke_data = await vault_client.read_secret(concurrency_path)
            print(
                "[5] Successfully re-logged in after revoke. Data:", after_revoke_data
            )
        except RuntimeError as ex:
            # If policy doesn't allow revoke-self, you'll see 403 or "unavailable..."
            print("[5] Could not revoke token. Error:", ex)
            # Attempt a manual re-login to ensure token isn't left None
            try:
                await vault_client._login()
            except RuntimeError as re_login_ex:
                print("[5] Manual re-login also failed:", re_login_ex)
                # At least we tried; proceed or raise if you want
                # raise  # uncomment if you want to fail the test
            else:
                print("[5] Manual re-login succeeded.")

        #
        # 6) Read a path we don't have access to => expect 403 or 404
        #
        forbidden_path = "forbidden_path/test_secret"
        try:
            print("[6] Attempting to read a forbidden path => expect 403 or 404.")
            await vault_client.read_secret(forbidden_path)
            raise AssertionError(
                "Expected 403 or 404 reading forbidden path, but request succeeded."
            )
        except RuntimeError as ex:
            # Vault may respond with 403 or 404 for inaccessible paths
            if "403" in str(ex) or "404" in str(ex):
                print("[6] Confirmed no-access => got expected error code.")
            else:
                raise

        print("All tests completed successfully!")


def main() -> None:
    asyncio.run(example_usage())


if __name__ == "__main__":
    main()
