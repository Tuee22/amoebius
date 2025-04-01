"""
amoebius/secrets/rke2.py

Functions for saving/loading RKE2Credentials to/from Vault.
"""

from __future__ import annotations

from typing import Any

from pydantic import ValidationError

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.rke2 import RKE2Credentials


async def save_rke2_credentials(
    vault_client: AsyncVaultClient, vault_path: str, creds: RKE2Credentials
) -> None:
    """
    Save the given RKE2Credentials to Vault at vault_path.
    """
    await vault_client.write_secret_idempotent(vault_path, creds.model_dump())


async def load_rke2_credentials(
    vault_client: AsyncVaultClient, vault_path: str
) -> RKE2Credentials:
    """
    Retrieve the RKE2Credentials from a given Vault path, parse them with pydantic.

    Raises:
        RuntimeError if missing or invalid.
    """
    raw = await vault_client.read_secret(vault_path)
    try:
        return RKE2Credentials(**raw)
    except ValidationError as ve:
        raise RuntimeError(
            f"Failed to parse RKE2Credentials from Vault path '{vault_path}': {ve}"
        ) from ve
