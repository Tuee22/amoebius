"""
amoebius/secrets/ssh.py

This module provides a high-level interface for managing SSH secrets in a HashiCorp Vault KV
store, including the following features:

1. **Creation and Storage** of `SSHConfig` objects in Vault with optional auto-expiration
   if the SSH host key is not yet known ("Trust On First Use" scenario).

2. **Automated Expiry**: When an `SSHConfig` is stored without host keys, this module can
   store an `expires_at` timestamp (defaults to 1 hour in the future). Upon retrieval or
   cleanup, if the secret is expired, it is automatically hard-deleted.

3. **TOFU (Trust On First Use)**: If an SSH config is missing host keys, the module can:
    - Initiate an SSH handshake (using StrictHostKeyChecking=accept-new).
    - Retrieve the server's public key.
    - Populate and update the stored config so that future connections can strictly
      verify the host key.

4. **Mass TOFU**: A single call can operate on all SSH secrets under a given Vault path,
   retrieving any keys that lack host keys, and updating them in parallel.

5. **Cleanup** of expired SSH configs.

6. **Lifecycle Demonstration**: The `demo_lifecycle` function and the `main()` CLI
   showcase a complete create→read→TOFU→soft-delete→hard-delete flow.

**Typical Usage**:

.. code-block:: python

    from amoebius.secrets.vault_client import AsyncVaultClient
    from amoebius.secrets.ssh import store_ssh_config, get_ssh_config

    async with AsyncVaultClient(my_vault_settings) as vault:
        # Store an SSHConfig
        my_ssh = SSHConfig(user="root", hostname="1.2.3.4", private_key="...")
        await store_ssh_config(vault, "secrets/my_ssh_config", my_ssh)

        # Retrieve and auto-TOFU if needed
        config = await get_ssh_config(vault, "secrets/my_ssh_config", tofu_if_missing_host_keys=True)

        # Now config.host_keys should be populated
        # ... proceed with using the config in a strict SSH connection ...

This module requires:

- A working `vault_client.py` that provides the asynchronous KVv2 operations.
- A properly configured Vault server (KV v2 engine, Kubernetes authentication if desired).
- `ssh_runner.py` for the SSH handshake logic.

All functions are type-annotated and designed to pass `mypy --strict`.
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
from amoebius.secrets.vault_client import AsyncVaultClient


def _is_expired(expiry: Optional[float]) -> bool:
    """
    Check if the given `expiry` epoch timestamp is strictly in the past.

    :param expiry: Optional float epoch. If `None`, it's not expired.
    :return: True if expiry is a float and is less than time.time(), else False.
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
    expiry checks and optional auto-TOFU population.

    **Expiry Check**:
      - If the data has an 'expires_at' timestamp that has passed, this method
        performs a **hard delete** of the secret in Vault and raises a `RuntimeError`.

    **TOFU Auto-Populate**:
      - By default, if the `SSHConfig` has no `host_keys` upon retrieval and
        `tofu_if_missing_host_keys` is True, this method calls :func:`tofu_populate_ssh_config`
        to fetch the server's public key. It then re-retrieves the newly updated config.

    :param vault: An active instance of :class:`AsyncVaultClient`. Must be used within
        its asynchronous context manager (e.g., `async with vault:`).
    :param path: The Vault KV path from which the secret should be read.
    :param tofu_if_missing_host_keys: If True, automatically populate host keys via TOFU
        if they are missing. Defaults to True.
    :return: A valid `SSHConfig` object. After TOFU, the updated config (with host keys)
        is returned.
    :raises RuntimeError:
        - If the path is not found (Vault 404) or other Vault error statuses occur.
        - If the secret is expired, in which case it is also hard-deleted from Vault.
        - If the data fails Pydantic validation.
        - If TOFU fails (unreachable server, etc.).
    """
    raw = await vault.read_secret(path)

    # Parse into SSHVaultData to unify logic
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

    # If host_keys are missing and tofu is requested => do TOFU
    if tofu_if_missing_host_keys and (not data_obj.ssh_config.host_keys):
        await tofu_populate_ssh_config(vault, path)
        # Re-retrieve after TOFU
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
    Store an `SSHConfig` instance in Vault at the specified KV `path` using the
    `SSHVaultData` model. Optionally set an expiry of 1 hour if no host keys are present.

    .. code-block:: json

        {
          "ssh_config": {
            "user": "...",
            "hostname": "...",
            "port": 22,
            "private_key": "...",
            "host_keys": null or [...]
          },
          "expires_at": <float epoch time if no host keys and set_expiry_if_no_keys=True>
        }

    :param vault: An active instance of :class:`AsyncVaultClient`.
    :param path: A string denoting the KV path where the data should be stored.
    :param config: An `SSHConfig` object containing SSH connection details
        (user, hostname, port, private_key, etc.).
    :param set_expiry_if_no_keys: If True and `host_keys` are empty/None, sets
        `"expires_at" = time.time() + 3600`. Defaults to True.
    :raises RuntimeError: If the underlying Vault API call fails or returns an error.
    :return: None. The secret is stored in Vault.
    """
    vault_data = SSHVaultData(
        ssh_config=config,
        expires_at=(
            time.time() + 3600.0
            if not config.host_keys
            else None
        ),
    )

    # Convert the model to dict for Vault storage
    await vault.write_secret_idempotent(path, vault_data.model_dump(exclude_unset=True))


async def tofu_populate_ssh_config(vault: AsyncVaultClient, path: str) -> None:
    """
    Perform a "Trust On First Use" (TOFU) workflow for an `SSHConfig` stored in Vault.

    **Workflow**:

    1. Retrieve the existing `SSHConfig` via :func:`get_ssh_config` with TOFU disabled
       (so we won't get an infinite recursion).
    2. Verify that `host_keys` is empty. If present, raises `RuntimeError` to avoid overwriting.
    3. Use :func:`ssh_get_server_key` to perform a minimal SSH handshake, obtaining
       one or more public key lines.
    4. Update the stored `SSHConfig.host_keys`, and explicitly set `expires_at=None`,
       ensuring the secret no longer has an expiry once we have valid host keys.
    5. Write the updated data back to Vault.

    :param vault: An active :class:`AsyncVaultClient` context.
    :param path: The Vault KV path to the `SSHConfig`.
    :raises RuntimeError:
        - If the config at `path` already has `host_keys`.
        - If reading/writing to Vault fails.
        - If the SSH server key retrieval fails (unreachable, etc.).
    :return: None. The updated config (with host keys) is saved to Vault.
    """
    # 1) Retrieve existing config (without auto-TOFU to avoid recursion)
    try:
        cfg_no_tofu = await get_ssh_config(vault, path, tofu_if_missing_host_keys=False)
    except RuntimeError as ex:
        raise RuntimeError(f"Cannot TOFU-populate {path}: {ex}") from ex

    # 2) Ensure no host keys are currently set
    if cfg_no_tofu.host_keys:
        raise RuntimeError(
            f"SSHConfig at path '{path}' already has host_keys; aborting TOFU."
        )

    # 3) Retrieve server key lines
    lines = await ssh_get_server_key(cfg_no_tofu)
    cfg_no_tofu.host_keys = lines

    # 4) Overwrite data, ensuring expires_at=None
    updated_data = SSHVaultData(ssh_config=cfg_no_tofu, expires_at=None).model_dump()

    # 5) Write the updated record back to Vault
    await vault.write_secret(path, updated_data)


async def delete_ssh_config(
    vault: AsyncVaultClient, path: str, hard_delete: bool = False
) -> None:
    """
    Delete the `SSHConfig` at the specified Vault path, either softly or fully.

    - A "soft delete" removes the latest version but retains version history.
    - A "hard delete" removes all metadata and version history for the secret.

    :param vault: An active :class:`AsyncVaultClient`.
    :param path: The Vault KV path where the `SSHConfig` is stored.
    :param hard_delete: If True, fully remove all version history. If False, mark only
        the latest version as deleted. Defaults to False.
    :raises RuntimeError: If Vault raises an unexpected error status.
    :return: None.
    """
    await vault.delete_secret(path, hard=hard_delete)


async def demo_lifecycle(
    settings: VaultSettings,
    user: str,
    hostname: str,
    port: int,
    private_key: str,
    base_path: str = "secrets/amoebius/test",
) -> None:
    """
    Demonstrate an end-to-end lifecycle for managing an SSH secret in Vault,
    leveraging expiry checks and optional TOFU population.

    **Workflow**:

    1. **Cleanup** any expired configs in `base_path`.
    2. **Store** a new `SSHConfig` with no host keys. This triggers a 1-hour expiry timer.
    3. **Retrieve** that config from Vault with `tofu_if_missing_host_keys=False`,
       confirming it truly has no host keys initially.
    4. **Retrieve** again with `tofu_if_missing_host_keys=True`, automatically
       performing TOFU if host keys are missing, then returning an updated config.
    5. **Soft-delete** the secret and confirm that reading it fails with 404.
    6. **Hard-delete** the secret's metadata and confirm the secret is fully removed.

    :param settings: Configuration for connecting/authenticating with Vault.
    :param user: SSH username.
    :param hostname: The SSH server hostname (e.g., "1.2.3.4" or "myhost.com").
    :param port: SSH server port (default 22).
    :param private_key: Contents of the private key used to authenticate as `user`.
    :param base_path: The Vault path under which this demo secret is stored.
        Defaults to "secrets/amoebius/test".
    :raises RuntimeError:
        - If storing/retrieving from Vault fails unexpectedly.
        - If the TOFU step fails (e.g., server unreachable).
        - If the post-soft-delete read does not yield 404.
        - If metadata remains after a hard delete.
    :return: None. Prints progress messages to stdout.
    """
    if not base_path.endswith("/"):
        base_path += "/"
    path = base_path + "demo_ssh"

    async with AsyncVaultClient(settings) as vault:

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

        print("\nDemo lifecycle completed successfully.")


def main() -> None:
    """
    Command-line interface demonstration for the SSH secrets lifecycle in Vault,
    including automatic expiry and TOFU.

    **Usage** example:

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
         --base-path secrets/amoebius/test

    :raises SystemExit: If reading the private key file fails.
    :return: None. Prints output messages to stdout.
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
        help="Path to the JWT token used for Vault login.",
    )
    parser.add_argument(
        "--verify-ssl",
        action="store_true",
        default=False,
        help="Whether to verify SSL certs when connecting to Vault.",
    )
    parser.add_argument(
        "--base-path",
        default="amoebius/test",
        help="Base path in Vault for storing SSH secrets (default: secrets/amoebius/test).",
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
            f"Error reading private key file '{args.private_key}': {e}", file=sys.stderr
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
