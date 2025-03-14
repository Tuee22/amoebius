"""
amoebius/secrets/minio.py

Holds logic that involves both Vault and Minio, including:
 - Retrieving a MinioSettings from Vault (get_minio_settings_from_vault)
 - Storing a MinioSettings to Vault (store_user_credentials_in_vault)
 - Creating a Minio client (get_minio_client)
"""

from typing import Any, Dict, Optional

from minio import Minio

from amoebius.models.minio import MinioSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.validator import validate_type


async def get_minio_settings_from_vault(
    vault_client: AsyncVaultClient,
    vault_path: str,
) -> Optional[MinioSettings]:
    """Reads Minio credentials from Vault at vault_path and returns a MinioSettings object.

    If a 404 is encountered, returns None. If any other error occurs, raises a RuntimeError.

    Args:
        vault_client (AsyncVaultClient):
            The Vault client to read secrets with.
        vault_path (str):
            The KV path storing MinioSettings fields (url, access_key, secret_key, secure).

    Returns:
        Optional[MinioSettings]:
            A MinioSettings object if found, or None if the path is 404.

    Raises:
        RuntimeError: If reading fails with a non-404 error, or pydantic validation fails.
    """
    try:
        secret_data: Dict[str, Any] = await vault_client.read_secret(vault_path)
    except RuntimeError as ex:
        # If it's a 404, return None; otherwise raise
        if "404" in str(ex):
            return None
        raise

    try:
        return MinioSettings(**secret_data)
    except Exception as e:
        raise RuntimeError(
            f"Failed to parse MinioSettings at {vault_path}: {secret_data}"
        ) from e


async def store_user_credentials_in_vault(
    vault_client: AsyncVaultClient,
    vault_path: str,
    minio_settings: MinioSettings,
) -> None:
    """Stores a MinioSettings credential set in Vault at vault_path.

    Args:
        vault_client (AsyncVaultClient):
            The Vault client to write secrets.
        vault_path (str):
            The KV path to store the credentials (e.g. "amoebius/minio/id/<user>" or "amoebius/minio/root").
        minio_settings (MinioSettings):
            The settings to store (url, keys, secure).

    Raises:
        RuntimeError: If the write fails or status is unexpected.
    """
    data_dict = minio_settings.dict()
    await vault_client.write_secret(vault_path, data_dict)


async def get_minio_client(vault_client: AsyncVaultClient, vault_path: str) -> Minio:
    """Reads Minio credentials from Vault at vault_path, returns a Minio client.

    Args:
        vault_client (AsyncVaultClient):
            The Vault client to read secrets.
        vault_path (str):
            KV path containing MinioSettings fields.

    Returns:
        Minio: A configured Minio client instance.

    Raises:
        RuntimeError: If the read fails (non-404) or pydantic validation fails,
                      or if there's no credential at that path (None).
    """
    settings = await get_minio_settings_from_vault(vault_client, vault_path)
    if not settings:
        raise RuntimeError(f"Vault credential not found at {vault_path}")
    return Minio(
        endpoint=settings.url.replace("http://", "").replace("https://", ""),
        access_key=settings.access_key,
        secret_key=settings.secret_key,
        secure=settings.secure,
    )
