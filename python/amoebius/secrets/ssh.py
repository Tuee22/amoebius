"""
amoebius/secrets/ssh.py

This module provides a high-level interface for managing SSH secrets in a HashiCorp Vault KV
store. It supports:

1. **Creation and Storage** of `SSHConfig` objects in Vault, including auto-expiration
   if the SSH host key is not yet known ("Trust On First Use" scenario).

2. **TOFU (Trust On First Use)**: If an SSH config is missing host keys, we can perform
   an SSH handshake (StrictHostKeyChecking=accept-new), retrieve the server's public key,
   and update the stored config with those keys for future strict validation.

3. **Automated Expiry**: If you store a config without host keys, an expiry (by default
   1 hour) is set. When retrieved, if it is expired, it is immediately hard-deleted from Vault.

4. **Mass TOFU**: (Not shown in detail here) can operate on all SSH secrets under a path.

5. **Cleanup of Expired** SSH configs.

6. **Lifecycle Demonstration**: `demo_lifecycle` demonstrates the create→read→TOFU→soft-delete→hard-delete flow,
   including a newly added scenario where a secret is created and immediately hard-deleted.

Typical usage:

.. code-block:: python

    from amoebius.secrets.vault_client import AsyncVaultClient
    from amoebius.secrets.ssh import store_ssh_config, get_ssh_config

    async with AsyncVaultClient(my_vault_settings) as vault:
        # Store an SSHConfig (possibly with no host keys)
        my_ssh = SSHConfig(user="root", hostname="1.2.3.4", private_key="...")
        await store_ssh_config(vault, "secrets/my_ssh_config", my_ssh)

        # Retrieve and auto-TOFU if missing host keys
        config = await get_ssh_config(vault, "secrets/my_ssh_config", tofu_if_missing_host_keys=True)
        # ...
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import time
from typing import Any, Dict, List, Optional

from pydantic import ValidationError

from amoebius.models.ssh import SSHConfig, SSHVaultData
from amoebius.models.vault import VaultSettings
from amoebius.utils.ssh_runner import ssh_get_server_key
from amoebius.utils.async_retry import async_retry
from amoebius.secrets.vault_client import AsyncVaultClient


def _is_expired(expiry: Optional[float]) -> bool:
    """
    Check if the given `expiry` epoch timestamp is strictly in the past.

    :param expiry: Optional float epoch. If `None`, it's not expired.
    :return: True if expiry is a float and is less than `time.time()`, else False.
    """
    if expiry is None:
        return False
    return expiry < time.time()


async def get_ssh_config(
    vault: AsyncVaultClient,
    path: str,
    tofu_if_missing_host_keys: bool = True,
) -> SSHConfig:
    """
    Retrieve an `SSHConfig` from the given Vault KV `path`, with built-in
    expiry checks and optional auto-TOFU.

    **Expiry Check**:
      - If `expires_at` is in the past, this method does a **hard delete** of
        the secret in Vault and raises RuntimeError.

    **TOFU Auto-Populate**:
      - If `ssh_config.host_keys` is empty and `tofu_if_missing_host_keys` is True,
        we call :func:`tofu_populate_ssh_config`. Afterward, we re-read the updated
        data to ensure it’s parsed correctly.

    :param vault: An active instance of :class:`AsyncVaultClient`.
    :param path: The Vault KV path from which to read the SSHConfig.
    :param tofu_if_missing_host_keys: If True, automatically populate missing host keys
        via TOFU if they are missing. Defaults to True.
    :return: A valid `SSHConfig` object (possibly updated by TOFU).
    :raises RuntimeError:
        - If the path is not found or other Vault error statuses occur.
        - If the secret is expired (in which case it is also hard-deleted).
        - If the data fails Pydantic validation.
        - If TOFU fails.
    """
    raw = await vault.read_secret(path)

    try:
        data_obj = SSHVaultData(**raw)
    except ValidationError as ve:
        raise RuntimeError(f"Invalid SSHVaultData at '{path}': {ve}") from ve

    # If expired => forcibly hard-delete from Vault, raise
    if _is_expired(data_obj.expires_at):
        await vault.delete_secret(path, hard=True)
        raise RuntimeError(
            f"SSHConfig at path '{path}' has expired; it has been removed from Vault."
        )

    # If host_keys missing and tofu requested => do TOFU
    if tofu_if_missing_host_keys and (not data_obj.ssh_config.host_keys):
        await tofu_populate_ssh_config(vault, path)
        updated_raw = await vault.read_secret(path)
        try:
            data_obj = SSHVaultData(**updated_raw)
        except ValidationError as e:
            raise RuntimeError(
                f"Failed to re-parse SSHVaultData after TOFU at path '{path}': {e}"
            ) from e

    return data_obj.ssh_config


async def store_ssh_config(
    vault: AsyncVaultClient,
    path: str,
    config: SSHConfig,
) -> None:
    """
    Store an `SSHConfig` instance in Vault at `path`. If `host_keys` is empty,
    this method sets `expires_at` to 1 hour from now by default.

    The data is stored according to the `SSHVaultData` model, e.g.:

    .. code-block:: json

        {
          "ssh_config": {
            "user": "...",
            "hostname": "...",
            "port": 22,
            "private_key": "...",
            "host_keys": null or [...]
          },
          "expires_at": <float epoch time if no host keys>
        }

    :param vault: An active :class:`AsyncVaultClient`.
    :param path: The KV path where the config should be stored.
    :param config: The SSHConfig object (must have user, hostname, private_key, etc.).
    :raises RuntimeError: If writing to Vault fails.
    :return: None
    """
    # Set an expiry of 1 hour if no host_keys
    expires = None
    if not config.host_keys:
        expires = time.time() + 3600.0

    vault_data = SSHVaultData(
        ssh_config=config,
        expires_at=expires,
    )
    await vault.write_secret_idempotent(path, vault_data.model_dump(exclude_unset=True))


async def store_ssh_config_with_tofu(
    vault: AsyncVaultClient,
    path: str,
    config: SSHConfig,
) -> None:
    """
    High-level convenience method to store an SSHConfig at `path`, then attempt
    TOFU population if host keys are missing. If TOFU fails, the secret is forcibly
    hard-deleted and a RuntimeError is raised.

    1) Calls `store_ssh_config`.
    2) If `config.host_keys` is empty, calls `tofu_populate_ssh_config`.
    3) If TOFU fails, does a hard-delete of the secret and raises RuntimeError.

    :param vault: An active :class:`AsyncVaultClient`.
    :param path: The KV path to store the SSH config.
    :param config: The SSHConfig to be stored.
    :raises RuntimeError:
      - If storing fails.
      - If TOFU fails for any reason (unreachable server, etc.).
    """
    # Step 1: Store the config
    await store_ssh_config(vault, path, config)

    # Step 2: If no host keys, attempt TOFU
    if not config.host_keys:
        try:
            await tofu_populate_ssh_config(vault, path)
        except Exception as exc:
            # If TOFU fails, forcibly remove the secret so it doesn't linger
            await delete_ssh_config(vault, path, hard_delete=True)
            raise RuntimeError(
                f"TOFU failed for path '{path}'; secret forcibly removed: {exc}"
            ) from exc


@async_retry(retries=30)
async def tofu_populate_ssh_config(vault: AsyncVaultClient, path: str) -> None:
    """
    Perform a Trust On First Use (TOFU) workflow on an `SSHConfig` stored in Vault.

    1. Retrieve the existing config (with tofu disabled to avoid recursion).
    2. Ensure `host_keys` is empty (raise RuntimeError if not).
    3. Perform a minimal SSH handshake (StrictHostKeyChecking=accept-new) to retrieve
       the server's public key(s).
    4. Update the config with those host keys, clear `expires_at`.
    5. Write the updated record back to Vault.

    :param vault: An active :class:`AsyncVaultClient`.
    :param path: The Vault KV path to the `SSHConfig`.
    :raises RuntimeError:
      - If the config already has `host_keys`.
      - If retrieving/writing to Vault fails.
      - If SSH handshake fails.
    :return: None
    """
    cfg_no_tofu = await get_ssh_config(vault, path, tofu_if_missing_host_keys=False)

    if cfg_no_tofu.host_keys:
        raise RuntimeError(
            f"SSHConfig at path '{path}' already has host_keys; aborting TOFU."
        )

    # Perform SSH handshake to retrieve host key lines
    lines = await ssh_get_server_key(cfg_no_tofu)
    cfg_no_tofu.host_keys = lines

    # Overwrite data, ensuring expires_at=None now that host keys exist
    updated_data = SSHVaultData(ssh_config=cfg_no_tofu, expires_at=None).model_dump()
    await vault.write_secret(path, updated_data)


async def delete_ssh_config(
    vault: AsyncVaultClient, path: str, hard_delete: bool = False
) -> None:
    """
    Delete the `SSHConfig` at the specified Vault path. If `hard_delete` is True,
    we remove the metadata (destroying all versions). If `hard_delete` is False,
    we soft-delete only the latest version (metadata remains).

    When soft-deleting, we first verify that the path indeed contains an SSH config
    (i.e., `SSHVaultData`). If that fails (404 or invalid format), we raise `RuntimeError`.

    For a hard delete, we tolerate a 404 if the secret data has already been removed;
    we still proceed to destroy the metadata record.

    :param vault: An active :class:`AsyncVaultClient`.
    :param path: The Vault KV path.
    :param hard_delete: If True, fully remove all version history; else soft-delete
        only the latest version. Defaults to False.
    :raises RuntimeError:
      - If no secret is found at `path` (for soft-delete).
      - If the data is not valid `SSHVaultData` (for soft-delete).
      - If other Vault errors occur.
    :return: None
    """
    if hard_delete:
        # Attempt to read+validate if it exists, but tolerate 404
        try:
            raw = await vault.read_secret(path)
            # If we can read it, verify it's a valid SSHVaultData
            SSHVaultData(**raw)
        except RuntimeError as ex:
            if "404" in str(ex):
                # Already gone (soft-deleted data), but we still want to remove metadata
                pass
            else:
                raise RuntimeError(
                    f"Could not retrieve secret at '{path}' prior to hard delete: {ex}"
                ) from ex
        except ValidationError as ve:
            # If there's some corrupted data, we can still remove it.
            raise RuntimeError(
                f"Data at path '{path}' is not a valid SSHVaultData. {ve}"
            ) from ve

        # Now remove the metadata
        await vault.delete_secret(path, hard=True)
        return

    # Otherwise, we're doing a "soft delete"
    # => must read+validate to confirm there's a valid SSHVaultData
    try:
        raw = await vault.read_secret(path)
    except RuntimeError as ex:
        if "404" in str(ex):
            raise RuntimeError(
                f"No SSH config found at path '{path}' to delete."
            ) from ex
        raise RuntimeError(
            f"Could not retrieve secret at '{path}' prior to delete: {ex}"
        ) from ex

    try:
        SSHVaultData(**raw)
    except ValidationError as ve:
        raise RuntimeError(
            f"Data at path '{path}' is not a valid SSHVaultData. Cannot delete as SSH config. {ve}"
        ) from ve

    # Perform the soft-delete
    await vault.delete_secret(path, hard=False)


async def demo_lifecycle(
    settings: VaultSettings,
    user: str,
    hostname: str,
    port: int,
    private_key: str,
    base_path: str,
) -> None:
    """
    Demonstrate an end-to-end lifecycle for managing an SSH secret in Vault,
    including expiry checks, TOFU, and deletion. This acts like an integration
    test to confirm the entire flow.

    Workflow:
      1) (Optional) Cleanup any expired configs in `base_path`.
      2) Store a new `SSHConfig` with no host keys -> triggers 1-hour expiry.
      3) Retrieve it without TOFU, confirm no host keys.
      4) Retrieve it with TOFU, confirm host keys get populated.
      5) Soft-delete the secret, confirm 404 on read.
      6) Hard-delete the secret, confirm no metadata remains.
      7) Create a brand-new secret and immediately hard-delete it to verify
         that a direct hard-delete works (metadata is removed even if the data
         wasn't soft-deleted first).

    Note: `delete_ssh_config` now tolerates a 404 when doing a hard delete.

    :param settings: Config for connecting to Vault.
    :param user: SSH username.
    :param hostname: The SSH server hostname/IP.
    :param port: SSH port (22 by default).
    :param private_key: Contents of the SSH private key.
    :param base_path: Vault path to store the test secret.
    """
    if not base_path.endswith("/"):
        base_path += "/"
    path = base_path + "demo_ssh"

    async with AsyncVaultClient(settings) as vault:
        print(
            "=== 1) Cleanup any expired configs first (if a cleanup utility exists) ==="
        )
        # e.g. await cleanup_expired_ssh_configs(vault, base_path=base_path, hard=True)
        # (Assuming you have a function that checks for and deletes expired secrets.)

        print("=== 2) Store SSHConfig with no host keys (one-hour expiry) ===")
        config_in = SSHConfig(
            user=user,
            hostname=hostname,
            port=port,
            private_key=private_key,
            host_keys=None,
        )
        await store_ssh_config(vault, path, config_in)

        print("=== 3) Retrieve => confirm no host keys ===")
        cfg = await get_ssh_config(vault, path, tofu_if_missing_host_keys=False)
        if cfg.host_keys:
            raise RuntimeError("Expected no host keys at this stage.")
        print(f"   Successfully retrieved {path} with NO host keys.")

        print("=== 4) Retrieve => auto-TOFU if host keys are missing ===")
        cfg = await get_ssh_config(vault, path, tofu_if_missing_host_keys=True)
        if not cfg.host_keys:
            raise RuntimeError(
                "TOFU was expected to populate host keys, but none found."
            )
        print(f"   Host keys now present after TOFU: {cfg.host_keys}")

        print("=== 5) Soft-delete => expect 404 on read ===")
        await delete_ssh_config(vault, path, hard_delete=False)
        try:
            await vault.read_secret(path)
            raise RuntimeError(
                "Expected a 404 after soft-delete, but secret still exists."
            )
        except RuntimeError as ex:
            if "404" not in str(ex):
                raise
            print("   Confirmed 404 => secret not found after soft-delete.")

        print("=== 6) Hard-delete => confirm metadata is gone ===")
        await delete_ssh_config(vault, path, hard_delete=True)
        meta = await vault.secret_history(path)
        if meta:
            raise RuntimeError(
                f"Expected empty metadata after hard-delete, got: {meta}"
            )
        print("   Confirmed metadata is empty after hard-delete.")

        print("=== 7) Create a new secret and immediately hard-delete it ===")
        direct_path = base_path + "demo_ssh_harddelete"
        new_config = SSHConfig(
            user="direct_harddel",
            hostname="127.0.0.1",
            port=22,
            private_key="dummy_key",
            host_keys=None,
        )
        # Store the new secret
        await store_ssh_config(vault, direct_path, new_config)
        print(f"   Created secret at: {direct_path}")

        # Now directly hard-delete it
        await delete_ssh_config(vault, direct_path, hard_delete=True)
        # Confirm no metadata remains
        direct_meta = await vault.secret_history(direct_path)
        if direct_meta:
            raise RuntimeError(
                f"Expected empty metadata after direct hard-delete, got: {direct_meta}"
            )
        print("   Confirmed direct hard-delete removed metadata as well.")

        print("\nDemo lifecycle completed successfully.")


def main() -> None:
    """
    Command-line demonstration of the SSH secrets lifecycle in Vault,
    including expiry and TOFU.

    Usage example:

    .. code-block:: console

       python -m amoebius.secrets.ssh \\
         --user root \\
         --hostname 1.2.3.4 \\
         --port 22 \\
         --private-key /path/to/id_rsa \\
         --vault-addr http://vault.vault.svc.cluster.local:8200 \\
         --vault-role-name amoebius-admin-role \\
         --vault-token-path /var/run/secrets/kubernetes.io/serviceaccount/token \\
         --verify-ssl \\
         --base-path amoebius/tests
    """
    parser = argparse.ArgumentParser(
        description="Demonstration of full SSH secret lifecycle in Vault (TOFU, expiry, etc.)."
    )
    parser.add_argument("--user", required=True, help="SSH user name.")
    parser.add_argument("--hostname", required=True, help="SSH server hostname/IP.")
    parser.add_argument(
        "--port", required=False, type=int, default=22, help="SSH port."
    )
    parser.add_argument(
        "--private-key", required=True, help="Path to private key file (PEM)."
    )
    parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    parser.add_argument(
        "--vault-role-name",
        default="amoebius-admin-role",
        help="Vault K8s auth role name (default: amoebius-admin-role).",
    )
    parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help="Path to the JWT token for Vault login.",
    )
    parser.add_argument(
        "--verify-ssl",
        action="store_true",
        default=False,
        help="Whether to verify SSL certs when connecting to Vault.",
    )
    parser.add_argument(
        "--base-path",
        default="amoebius/tests",
        help="Base path in Vault for storing SSH secrets (default: amoebius/tests).",
    )

    args = parser.parse_args()

    vault_settings = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        token_path=args.vault_token_path,
        verify_ssl=args.verify_ssl,
        renew_threshold_seconds=60,
        check_interval_seconds=30,
    )

    try:
        with open(args.private_key, "r", encoding="utf-8") as fpk:
            key_data = fpk.read()
    except OSError as e:
        print(
            f"Error reading private key file '{args.private_key}': {e}",
            file=sys.stderr,
        )
        sys.exit(1)

    asyncio.run(
        demo_lifecycle(
            settings=vault_settings,
            user=args.user,
            hostname=args.hostname,
            port=args.port,
            private_key=key_data,
            base_path=args.base_path,
        )
    )


if __name__ == "__main__":
    main()
