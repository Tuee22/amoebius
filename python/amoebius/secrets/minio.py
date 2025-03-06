"""
amoebius/secrets/minio.py

Holds logic that involves both Vault and Minio. For example:
 - get_minio_client(...) that awaits reading credentials from Vault
 - storing user credentials in Vault, reading them back, etc.
"""

import json
from typing import Any, Dict, Optional

from minio import Minio

from amoebius.models.minio import MinioSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.validator import validate_type


async def get_minio_client(vault_client: AsyncVaultClient, vault_path: str) -> Minio:
    """
    Reads Minio credentials from Vault at the given path, returns a Minio client.

    Args:
        vault_client (AsyncVaultClient): The Vault client to read secrets with.
        vault_path (str): Path under 'secret/data/...' that stores MinioSettings fields.

    Returns:
        Minio: A configured Minio client instance.

    Raises:
        RuntimeError: If the read fails or the settings are invalid.
    """
    secret_data: Dict[str, Any] = await vault_client.read_secret(vault_path)
    settings = MinioSettings(**secret_data)
    return Minio(
        endpoint=settings.url,
        access_key=settings.access_key,
        secret_key=settings.secret_key,
        secure=settings.secure,
    )


async def store_user_credentials_in_vault(
    vault_client: AsyncVaultClient,
    vault_path: str,
    minio_settings: MinioSettings,
) -> None:
    """
    Stores a MinioSettings credential set in Vault at 'vault_path'.

    Args:
        vault_client (AsyncVaultClient): The Vault client to write secrets.
        vault_path (str): The KV path to store the credentials (e.g. "amoebius/minio/id/<user>").
        minio_settings (MinioSettings): The settings to store (url, keys, secure).

    Raises:
        RuntimeError: If the write fails or status is unexpected.
    """
    # Convert to dict
    data_dict = minio_settings.dict()
    await vault_client.write_secret(vault_path, data_dict)
