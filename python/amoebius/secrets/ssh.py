"""
amoebius/secrets/ssh.py

Vault-based SSH management:
 - store_ssh_config
 - store_ssh_config_with_tofu
 - delete_ssh_config
 - tofu_populate_ssh_config
 - get_ssh_config
 - demo_lifecycle

We rely on ephemeral usage from amoebius.utils.ssh for accept-new if host_keys are missing.
"""

from __future__ import annotations

import asyncio
import time
import sys
import argparse
from typing import Optional, Dict, Any
from pydantic import ValidationError

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.ssh import SSHConfig, SSHVaultData
from amoebius.utils.ssh import ssh_get_server_key
from amoebius.models.vault import VaultSettings
from amoebius.utils.async_retry import async_retry


def _is_expired(expiry: Optional[float]) -> bool:
    if expiry is None:
        return False
    return expiry < time.time()


@async_retry(retries=3)
async def get_ssh_config(
    vault_client: AsyncVaultClient, path: str, tofu_if_missing_host_keys: bool = True
) -> SSHConfig:
    """
    Retrieve an SSHConfig from Vault, verifying expiry. If missing host_keys and tofu is True,
    do ephemeral handshake via ssh_get_server_key, store them back.
    """
    raw = await vault_client.read_secret(path)
    data_obj = SSHVaultData(**raw)  # parse

    if _is_expired(data_obj.expires_at):
        await vault_client.delete_secret(path, hard=True)
        raise RuntimeError(f"SSHConfig at path '{path}' expired; removed from Vault.")

    if tofu_if_missing_host_keys and not data_obj.ssh_config.host_keys:
        await tofu_populate_ssh_config(vault_client, path)
        updated_raw = await vault_client.read_secret(path)
        data_obj = SSHVaultData(**updated_raw)

    return data_obj.ssh_config


async def store_ssh_config(
    vault_client: AsyncVaultClient, path: str, cfg: SSHConfig
) -> None:
    """
    Store an SSHConfig. If no host_keys => expires_at in 1 hr.
    """
    expires = None
    if not cfg.host_keys:
        expires = time.time() + 3600.0

    data = SSHVaultData(ssh_config=cfg, expires_at=expires)
    await vault_client.write_secret_idempotent(
        path, data.model_dump(exclude_unset=True)
    )


async def store_ssh_config_with_tofu(
    vault_client: AsyncVaultClient, path: str, cfg: SSHConfig
) -> None:
    """
    High-level storing an SSH config w/ immediate TOFU if no keys.
    If TOFU fails => forcibly hard-delete.
    """
    await store_ssh_config(vault_client, path, cfg)

    if not cfg.host_keys:
        try:
            await tofu_populate_ssh_config(vault_client, path)
        except Exception as ex:
            await delete_ssh_config(vault_client, path, hard_delete=True)
            raise RuntimeError(
                f"TOFU failed for path '{path}'; forcibly removed: {ex}"
            ) from ex


@async_retry(retries=30)
async def tofu_populate_ssh_config(vault_client: AsyncVaultClient, path: str) -> None:
    """
    If host_keys is empty => ephemeral handshake => store them, remove expiry.
    """
    existing = await get_ssh_config(vault_client, path, tofu_if_missing_host_keys=False)
    if existing.host_keys:
        raise RuntimeError(
            f"SSHConfig at '{path}' already has host_keys; aborting TOFU."
        )

    lines = await ssh_get_server_key(existing)
    existing.host_keys = lines
    updated = SSHVaultData(ssh_config=existing, expires_at=None)
    await vault_client.write_secret(path, updated.model_dump())


async def delete_ssh_config(
    vault_client: AsyncVaultClient, path: str, hard_delete: bool = False
) -> None:
    """
    Hard-delete => remove all version history
    Soft-delete => remove latest version only (metadata remains).
    """
    if hard_delete:
        # read+validate if possible, ignoring 404
        try:
            raw = await vault_client.read_secret(path)
            SSHVaultData(**raw)
        except RuntimeError as ex:
            if "404" not in str(ex):
                raise RuntimeError(
                    f"Could not retrieve secret '{path}' prior to hard delete: {ex}"
                ) from ex
        except ValidationError as ve:
            # if corrupted => still remove
            raise RuntimeError(
                f"Data at path '{path}' is not a valid SSHVaultData. {ve}"
            ) from ve

        await vault_client.delete_secret(path, hard=True)
        return

    # soft-delete => read+validate => delete
    try:
        raw = await vault_client.read_secret(path)
    except RuntimeError as ex:
        if "404" in str(ex):
            raise RuntimeError(
                f"No SSH config found at path '{path}' to delete."
            ) from ex
        raise

    try:
        SSHVaultData(**raw)
    except ValidationError as ve:
        raise RuntimeError(
            f"Data at '{path}' is not a valid SSHVaultData. {ve}"
        ) from ve

    await vault_client.delete_secret(path, hard=False)


async def demo_lifecycle(
    settings: VaultSettings,
    user: str,
    hostname: str,
    port: int,
    private_key: str,
    base_path: str,
) -> None:
    """
    Demonstrate an end-to-end lifecycle for an SSH secret in Vault:
     - store w/o host_keys => triggers 1-hour expiry
     - retrieve => confirm empty
     - retrieve => auto-TOFU => confirm
     - soft-delete => confirm
     - hard-delete => confirm
     - create new => immediate hard-delete => confirm
    """
    import time

    if not base_path.endswith("/"):
        base_path += "/"
    path = base_path + "demo_ssh"

    from amoebius.utils.ssh import run_ssh_command

    async with AsyncVaultClient(settings) as vault:
        print("=== (Optional) Cleanup expired, not shown. ===")

        print("=== 2) Store SSHConfig w/ no host keys => 1 hr expiry. ===")
        cfg_in = SSHConfig(
            user=user,
            hostname=hostname,
            port=port,
            private_key=private_key,
            host_keys=None,
        )
        await store_ssh_config(vault, path, cfg_in)

        print("=== 3) Retrieve => expect no host_keys ===")
        c1 = await get_ssh_config(vault, path, tofu_if_missing_host_keys=False)
        if c1.host_keys:
            raise RuntimeError("Expected no host keys here!")
        print(f"   got {path} w/o host_keys as expected.")

        print("=== 4) Retrieve => auto-TOFU => expect new host_keys ===")
        c2 = await get_ssh_config(vault, path, tofu_if_missing_host_keys=True)
        if not c2.host_keys:
            raise RuntimeError("TOFU expected to populate host_keys, none found.")
        print(f"   host_keys => {c2.host_keys}")

        print("=== 5) soft-delete => expect 404 on read ===")
        await delete_ssh_config(vault, path, hard_delete=False)
        try:
            await vault.read_secret(path)
            raise RuntimeError("Expected 404, but secret still present.")
        except RuntimeError as ex:
            if "404" not in str(ex):
                raise
            print("   confirmed => not found after soft-delete.")

        print("=== 6) hard-delete => confirm metadata => empty ===")
        await delete_ssh_config(vault, path, hard_delete=True)
        meta = await vault.secret_history(path)
        if meta:
            raise RuntimeError(f"Expected empty metadata, got {meta}")
        print("   confirmed => metadata empty after hard-delete.")

        print("=== 7) create & immediate hard-delete => test direct removal ===")
        direct_path = base_path + "demo_ssh_harddelete"
        newc = SSHConfig(
            user="harddel",
            hostname="127.0.0.1",
            port=22,
            private_key="dummy",
            host_keys=None,
        )
        await store_ssh_config(vault, direct_path, newc)
        print(f"   created => {direct_path}")
        await delete_ssh_config(vault, direct_path, hard_delete=True)
        direct_meta = await vault.secret_history(direct_path)
        if direct_meta:
            raise RuntimeError(
                f"Expected empty after direct hard-delete => got {direct_meta}"
            )
        print("   direct hard-delete => metadata gone, success.")

        print("\nSSH secrets lifecycle test completed successfully.")


def main() -> None:
    """
    A CLI demonstration for the SSH secrets lifecycle in Vault, including TOFU.
    """
    parser = argparse.ArgumentParser(description="SSH lifecycle in Vault, incl. TOFU.")
    parser.add_argument("--user", required=True)
    parser.add_argument("--hostname", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--private-key", required=True)
    parser.add_argument(
        "--vault-addr", default="http://vault.vault.svc.cluster.local:8200"
    )
    parser.add_argument("--vault-role-name", default="amoebius-admin-role")
    parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
    )
    parser.add_argument("--verify-ssl", action="store_true", default=False)
    parser.add_argument("--base-path", default="amoebius/tests")

    args = parser.parse_args()
    vault_settings = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        token_path=args.vault_token_path,
        verify_ssl=args.verify_ssl,
        renew_threshold_seconds=60,
        check_interval_seconds=30,
    )

    import os

    if not os.path.isfile(args.private_key):
        print(f"Private key file not found: {args.private_key}", file=sys.stderr)
        sys.exit(1)

    key_data = open(args.private_key, "r", encoding="utf-8").read()

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
