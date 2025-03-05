"""
amoebius/utils/minio.py

This module provides:

1. MinioSettings (pydantic model) containing just url, access_key, and secret_key.
   - We omit "secure" or "region" from the model to minimize confusion.

2. get_minio_client(...) which can:
   - Read credentials from Vault (vault_client + vault_path), or
   - Use a direct MinioSettings instance (direct_settings),
   and also takes a "secure" bool to decide HTTPS vs. HTTP.

3. create_minio_identity(...):
   - Fetches root Minio credentials from Vault (amoebius/minio/root).
   - Creates a root Minio client.
   - Creates a new user/identity in Minio (placeholder) with the specified bucket permissions.
   - Validates that user's credential with MinioSettings, then stores it in Vault at
     amoebius/minio/id/<role_name>.
   - Calls put_readonly_kv_policy(...) to create a narrower Vault policy
     that grants read-only access to just that identity's secret path.

4. put_readonly_kv_policy(...) that only grants read to
   secret/data/amoebius/minio/id/<some_role> and ensures the policy name is safe.

5. deploy_minio_cluster(...) and destroy_minio_cluster(...):
   - Terraform-based placeholders for ephemeral usage via VaultKVStorage.
   - Root credential is stored at amoebius/minio/root in Vault.
"""

from __future__ import annotations

import secrets
from typing import Any, Dict, Optional

from pydantic import BaseModel, Field, ValidationError
from minio import Minio

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import (
    VaultKVStorage,
    init_terraform,
    apply_terraform,
    destroy_terraform,
)


class MinioSettings(BaseModel):
    """
    A pydantic model describing Minio connection settings.

    Attributes:
        url (str): FQDN endpoint for the Minio server, e.g. "http://minio.minio.svc.cluster.local:9000".
        access_key (str): The Minio user's access key (username).
        secret_key (str): The Minio user's secret key (password).
    """

    url: str = Field(
        ...,
        description="The Minio server endpoint, e.g. 'http://minio.minio.svc.cluster.local:9000'.",
    )
    access_key: str = Field(..., description="Minio identity's access key (username).")
    secret_key: str = Field(..., description="Minio identity's secret key (password).")


def _get_minio_client_from_settings(settings: MinioSettings, secure: bool) -> Minio:
    """
    Internal helper to create a Minio client from a MinioSettings instance plus
    a secure flag for HTTPS.

    Args:
        settings (MinioSettings): The Minio configuration (URL, keys).
        secure (bool): If True => use HTTPS, else HTTP.

    Returns:
        Minio: A Minio client configured from the settings + secure mode.
    """
    return Minio(
        endpoint=settings.url.replace("http://", "").replace("https://", ""),
        access_key=settings.access_key,
        secret_key=settings.secret_key,
        secure=secure,
    )


async def get_minio_client(
    vault_client: Optional[AsyncVaultClient] = None,
    vault_path: Optional[str] = None,
    direct_settings: Optional[MinioSettings] = None,
    secure: bool = True,
) -> Minio:
    """
    Retrieve a Minio client, either by:
      - Reading credentials from Vault (vault_client + vault_path), or
      - Using a direct MinioSettings instance (direct_settings).
    Exactly one approach must be used.

    Args:
        vault_client (Optional[AsyncVaultClient]):
            If retrieving credentials from Vault, supply this client.
        vault_path (Optional[str]):
            The path under 'secret/data/<vault_path>' to retrieve credentials.
            Must contain "url", "access_key", "secret_key".
        direct_settings (Optional[MinioSettings]):
            If providing credentials directly, pass them here.
        secure (bool, optional):
            If True => use HTTPS, else HTTP. Defaults to True if retrieving from Vault.

    Returns:
        Minio: A configured Minio client instance.

    Raises:
        RuntimeError: If neither or both of (vault_path, direct_settings) are provided,
                      or if Vault credentials are malformed,
                      or if vault_client is missing when vault_path is used.
    """
    # Validate approach
    if (vault_path is None) == (direct_settings is None):
        raise RuntimeError(
            "Exactly one of (vault_path, direct_settings) must be provided."
        )

    # If direct settings are provided, just use them
    if direct_settings is not None:
        return _get_minio_client_from_settings(direct_settings, secure=secure)

    # Otherwise, fetch from Vault
    if vault_client is None or vault_path is None:
        raise RuntimeError(
            "Must provide vault_client and vault_path to load from Vault."
        )

    secret_data: Dict[str, Any] = await vault_client.read_secret(vault_path)
    try:
        settings = MinioSettings(
            url=secret_data["url"],
            access_key=secret_data["access_key"],
            secret_key=secret_data["secret_key"],
        )
    except ValidationError as exc:
        raise RuntimeError(
            f"Invalid Minio credentials in Vault path '{vault_path}': {exc}"
        ) from exc

    return _get_minio_client_from_settings(settings, secure=secure)


async def put_readonly_kv_policy(
    vault_client: AsyncVaultClient,
    policy_name: str,
    role_name: str,
) -> None:
    """
    Create or update a narrow Vault policy that only grants 'read'
    to secret/data/amoebius/minio/id/<role_name>.

    This ensures the policy is confined to the path "amoebius/minio/id/<role_name>",
    and we prevent forward slash usage in the role_name to keep the path consistent.

    Args:
        vault_client (AsyncVaultClient): The Vault client to put the policy.
        policy_name (str): The name of the policy, e.g. "minio-id-someuser".
        role_name (str): The portion for 'amoebius/minio/id/<role_name>'.

    Raises:
        RuntimeError: If policy creation fails or if role_name is invalid.
    """
    # Validate the role_name for safety
    if "/" in role_name:
        raise RuntimeError(f"role_name '{role_name}' must not contain forward slashes.")

    # Build the narrower policy text
    kv_full_path = f"amoebius/minio/id/{role_name}"
    policy_text = f"""
path "secret/data/{kv_full_path}" {{
  capabilities = ["read"]
}}
"""

    # Also validate the policy_name
    if "/" in policy_name:
        raise RuntimeError(
            f"policy_name '{policy_name}' must not contain forward slashes."
        )

    await vault_client.put_policy(policy_name, policy_text)


async def create_minio_identity(
    vault_client: AsyncVaultClient,
    role_name: str,
    buckets_permissions: Dict[str, str],
    fqdn_service: str = "minio.minio.svc.cluster.local:9000",
    secure: bool = False,
) -> None:
    """
    Creates a new Minio identity (user) with the specified bucket permissions, by:
      1) Retrieving the Minio root credential from 'amoebius/minio/root' in Vault.
      2) Creating a root Minio client via get_minio_client(...).
      3) Creating a new user in Minio (placeholder logic, as minio-py isn't an admin library).
      4) Validate the new credential with MinioSettings, store in Vault at 'amoebius/minio/id/{role_name}'.
      5) Call put_readonly_kv_policy(...) to create a narrow policy granting read-only to that path.

    Args:
        vault_client (AsyncVaultClient): For reading root credentials & creating the new identity's policy.
        role_name (str): The identity name (and user access key).
        buckets_permissions (Dict[str, str]): Mapping of {bucket_name -> permission} placeholders.
        fqdn_service (str): The FQDN for Minio, e.g. "minio.minio.svc.cluster.local:9000".
        secure (bool): Whether to connect to the root client via HTTPS. Defaults to False.

    Raises:
        RuntimeError: If reading/writing Vault secrets fails or user creation fails.
    """
    # 1) Read the root credential from Vault
    root_cred_path = "amoebius/minio/root"
    root_secret = await vault_client.read_secret(root_cred_path)

    # 2) Create a root Minio client
    root_client = await get_minio_client(
        direct_settings=MinioSettings(
            url=f"http://{fqdn_service}" if not secure else f"https://{fqdn_service}",
            access_key=root_secret["root_user"],
            secret_key=root_secret["root_password"],
        ),
        secure=secure,
    )

    # 3) Create the new user in Minio (placeholder logic)
    # In reality, you'd use an admin approach to attach a minio policy that
    # grants {bucket => permission} e.g. "read", "readwrite".
    new_access_key = role_name
    new_secret_key = secrets.token_urlsafe(16)
    # e.g.: root_client.admin_add_user(new_access_key, new_secret_key)
    # for bucket, perm in buckets_permissions.items():
    #    # create a minio policy with perm for that bucket, attach to user
    #    pass

    # 4) Validate new credential with MinioSettings, store in Vault
    new_settings = MinioSettings(
        url=f"http://{fqdn_service}" if not secure else f"https://{fqdn_service}",
        access_key=new_access_key,
        secret_key=new_secret_key,
    )
    # If this raises ValidationError => something is wrong with the new user.

    new_identity_path = f"amoebius/minio/id/{role_name}"
    new_secret: Dict[str, Any] = {
        "url": new_settings.url,
        "access_key": new_settings.access_key,
        "secret_key": new_settings.secret_key,
    }
    await vault_client.write_secret(new_identity_path, new_secret)

    # 5) Create a narrower read-only Vault policy for that path
    policy_name = f"minio-id-{role_name}"
    await put_readonly_kv_policy(vault_client, policy_name, role_name)


async def deploy_minio_cluster(
    vault_client: AsyncVaultClient,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
    env: Optional[Dict[str, str]] = None,
    sensitive: bool = True,
    transit_key_name: Optional[str] = "amoebius/terraform-backends",
) -> None:
    """
    Deploy a Minio cluster via Terraform, storing ephemeral TF state in Vault via VaultKVStorage.
    The root credential is found or created at 'amoebius/minio/root'.

    Args:
        vault_client: For reading/writing the root credential in Vault.
        base_path: The Terraform root path (/amoebius/terraform/roots/minio).
        workspace: Terraform workspace name ("default").
        env: Env vars for Terraform.
        sensitive: If True, mask Terraform logs.
        transit_key_name: Vault transit key name for ephemeral encryption.
    """
    root_cred_path = "amoebius/minio/root"
    try:
        root_secret = await vault_client.read_secret(root_cred_path)
    except RuntimeError as ex:
        if "404" in str(ex):
            # Generate new root credential
            root_user = "admin"
            root_pass = secrets.token_urlsafe(16)
            root_secret = {"root_user": root_user, "root_password": root_pass}
            await vault_client.write_secret(root_cred_path, root_secret)
        else:
            raise

    # ephemeral TF variables
    variables = {
        "root_user": root_secret["root_user"],
        "root_password": root_secret["root_password"],
    }

    storage = VaultKVStorage(root_module="minio", workspace=workspace)

    await init_terraform(
        root_name="minio",
        workspace=workspace,
        env=env,
        base_path=base_path,
        storage=storage,
        vault_client=vault_client,
        minio_client=None,
        transit_key_name=transit_key_name,
        reconfigure=False,
        sensitive=sensitive,
    )

    await apply_terraform(
        root_name="minio",
        workspace=workspace,
        env=env,
        base_path=base_path,
        storage=storage,
        vault_client=vault_client,
        minio_client=None,
        transit_key_name=transit_key_name,
        override_lock=False,
        variables=variables,
        sensitive=sensitive,
    )


async def destroy_minio_cluster(
    vault_client: AsyncVaultClient,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
    env: Optional[Dict[str, str]] = None,
    sensitive: bool = True,
    transit_key_name: Optional[str] = "amoebius/terraform-backends",
) -> None:
    """
    Destroy the Minio cluster using Terraform, ephemeral TF state stored in Vault.

    Args:
        vault_client: For ephemeral usage + reading root credentials if needed.
        base_path: The Terraform root path (/amoebius/terraform/roots/minio).
        workspace: Terraform workspace name ("default").
        env: Environment variables for Terraform.
        sensitive: If True, mask Terraform logs.
        transit_key_name: Vault transit key name for ephemeral encryption.
    """
    storage = VaultKVStorage(root_module="minio", workspace=workspace)

    await destroy_terraform(
        root_name="minio",
        workspace=workspace,
        env=env,
        base_path=base_path,
        storage=storage,
        vault_client=vault_client,
        minio_client=None,
        transit_key_name=transit_key_name,
        override_lock=False,
        variables=None,
        sensitive=sensitive,
    )
