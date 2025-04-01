"""
amoebius/secrets/ssh.py

Vault-based SSH management (store_ssh_config, store_ssh_config_with_tofu,
delete_ssh_config, tofu_populate_ssh_config, get_ssh_config). Any ephemeral usage
for missing host_keys references amoebius.utils.ssh, but no ephemeral logic is duplicated here.

Demo-lifecycle logic has been removed per request; see original code for references if needed.
"""

from __future__ import annotations

import time
from typing import Optional

from pydantic import ValidationError

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.ssh import SSHConfig, SSHVaultData
from amoebius.utils.ssh import ssh_get_server_key
from amoebius.utils.async_retry import async_retry


def _is_expired(expiry: Optional[float]) -> bool:
    """
    Determine if the expiry epoch is in the past.

    Args:
        expiry: epoch seconds or None

    Returns:
        True if expired, else False
    """
    if expiry is None:
        return False
    return expiry < time.time()


@async_retry(retries=3)
async def get_ssh_config(
    vault_client: AsyncVaultClient, path: str, tofu_if_missing_host_keys: bool = True
) -> SSHConfig:
    """
    Retrieve SSHVaultData from Vault, parse to SSHConfig. If host_keys is empty
    and tofu_if_missing_host_keys is True => ephemeral handshake to discover them.

    Raises:
      - If expired => forcibly hard-delete => raises error
      - If data is not valid => raises
    """
    raw = await vault_client.read_secret(path)
    data_obj = SSHVaultData(**raw)

    if _is_expired(data_obj.expires_at):
        await vault_client.delete_secret(path, hard=True)
        raise RuntimeError(f"SSH config at '{path}' expired, removed from Vault.")

    if tofu_if_missing_host_keys and not data_obj.ssh_config.host_keys:
        await tofu_populate_ssh_config(vault_client, path)
        updated_raw = await vault_client.read_secret(path)
        data_obj = SSHVaultData(**updated_raw)

    return data_obj.ssh_config


async def store_ssh_config(
    vault_client: AsyncVaultClient, path: str, cfg: SSHConfig
) -> None:
    """
    Store an SSHConfig in Vault at path. If no host_keys => expire in 1 hour.
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
    Store an SSHConfig, then do TOFU if no host_keys. If TOFU fails => forcibly remove from Vault.
    """
    await store_ssh_config(vault_client, path, cfg)
    if not cfg.host_keys:
        try:
            await tofu_populate_ssh_config(vault_client, path)
        except Exception as e:
            await delete_ssh_config(vault_client, path, hard_delete=True)
            raise RuntimeError(
                f"TOFU failed for path '{path}'; forcibly removed. {e}"
            ) from e


@async_retry(retries=30)
async def tofu_populate_ssh_config(vault_client: AsyncVaultClient, path: str) -> None:
    """
    If host_keys is empty => ephemeral handshake => store them => clear expiry.
    """
    existing = await get_ssh_config(vault_client, path, tofu_if_missing_host_keys=False)
    if existing.host_keys:
        raise RuntimeError(
            f"SSHConfig at '{path}' already has host_keys; aborting TOFU."
        )

    lines = await ssh_get_server_key(existing)
    existing.host_keys = lines
    final_data = SSHVaultData(ssh_config=existing, expires_at=None).model_dump()
    await vault_client.write_secret(path, final_data)


async def delete_ssh_config(
    vault_client: AsyncVaultClient, path: str, hard_delete: bool = False
) -> None:
    """
    Delete the SSH config from Vault, either soft or hard.

    Hard => remove all versions (metadata). Soft => remove only the latest version.
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
            raise RuntimeError(
                f"Data at '{path}' is not a valid SSHVaultData. {ve}"
            ) from ve

        await vault_client.delete_secret(path, hard=True)
        return

    # Soft-delete => read+validate => delete
    try:
        raw = await vault_client.read_secret(path)
        SSHVaultData(**raw)
    except RuntimeError as ex:
        if "404" in str(ex):
            raise RuntimeError(
                f"No SSH config found at path '{path}' to delete."
            ) from ex
        raise
    except ValidationError as ve:
        raise RuntimeError(
            f"Data at '{path}' is not a valid SSHVaultData. Cannot delete as SSH config. {ve}"
        ) from ve

    await vault_client.delete_secret(path, hard=False)
