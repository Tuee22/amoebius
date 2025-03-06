"""
amoebius/utils/minio.py

Provides:
  - MinioSettings (pydantic) with url, access_key, secret_key
  - get_minio_client(...) that either loads from Vault or uses direct credentials
  - create_minio_identity(...) to create a new identity in Minio (placeholder admin logic),
    store it in Vault, and set a read-only policy for that path.
  - put_readonly_kv_policy(...) that only grants 'read' to secret/data/amoebius/minio/id/<role_name>
  - deploy_minio_cluster(...) / destroy_minio_cluster(...) that use ephemeral Terraform usage
    plus a root credential stored in Vault at amoebius/minio/root
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
        url: The Minio server endpoint, e.g. "http://minio.minio.svc.cluster.local:9000".
        access_key: Minio identity's access key (username).
        secret_key: Minio identity's secret key (password).
    """

    url: str = Field(
        ...,
        description="Minio server endpoint, e.g. 'http://minio.minio.svc.cluster.local:9000'.",
    )
    access_key: str = Field(..., description="Minio identity access key (username).")
    secret_key: str = Field(..., description="Minio identity secret key (password).")


def _get_minio_client_from_settings(settings: MinioSettings, secure: bool) -> Minio:
    """
    Internal helper to create a Minio client from MinioSettings, plus a secure (bool).

    Args:
        settings: The MinioSettings object with URL, access key, secret key.
        secure: If True => use HTTPS, else HTTP.

    Returns:
        A Minio client.
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
    Retrieve a Minio client via either:
      1) Vault-sourced credentials at 'secret/data/<vault_path>'
      2) Direct MinioSettings
    Exactly one approach must be used.

    Args:
        vault_client: If loading from Vault, supply the AsyncVaultClient.
        vault_path: The vault KV path storing {url, access_key, secret_key}.
        direct_settings: If using direct credentials, supply MinioSettings.
        secure: If True => use HTTPS, else HTTP.

    Returns:
        A Minio client.

    Raises:
        RuntimeError if neither or both approaches are provided, or if
        Vault credentials are invalid, or if vault_client is missing.
    """
    if (vault_path is None) == (direct_settings is None):
        raise RuntimeError(
            "Exactly one of (vault_path, direct_settings) must be provided."
        )

    if direct_settings is not None:
        return _get_minio_client_from_settings(direct_settings, secure=secure)

    if vault_client is None or vault_path is None:
        raise RuntimeError(
            "Must provide vault_client and vault_path for Vault-based credentials."
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
            f"Invalid Minio credentials at '{vault_path}': {exc}"
        ) from exc

    return _get_minio_client_from_settings(settings, secure=secure)


async def put_readonly_kv_policy(
    vault_client: AsyncVaultClient,
    policy_name: str,
    role_name: str,
) -> None:
    """
    Create/update a read-only policy for secret/data/amoebius/minio/id/<role_name>.

    Args:
        vault_client: The AsyncVaultClient to call put_policy(...).
        policy_name: The name of the policy, e.g. "minio-id-devuser".
        role_name: The portion used in the path amoebius/minio/id/<role_name>.

    Raises:
        RuntimeError: If role_name or policy_name contain forward slashes, or if policy write fails.
    """
    if "/" in role_name:
        raise RuntimeError(f"role_name '{role_name}' must not contain forward slashes.")

    kv_full_path = f"amoebius/minio/id/{role_name}"
    policy_text = f"""
path "secret/data/{kv_full_path}" {{
  capabilities = ["read"]
}}
"""
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
    Creates a Minio identity with given bucket perms (placeholder), storing credentials in Vault.

    Steps:
      1) Retrieve root Minio credential from 'amoebius/minio/root'.
      2) Create root Minio client.
      3) Create user in Minio (placeholder).
      4) Validate new user's credentials with MinioSettings, store in vault at 'amoebius/minio/id/<role_name>'.
      5) Create a read-only policy for that path.

    Args:
        vault_client: The Vault client for reading/writing secrets + policy.
        role_name: The identity name (also used as the new user's access_key).
        buckets_permissions: A dict of bucket => perms (placeholder logic).
        fqdn_service: The FQDN for Minio, e.g. "minio.minio.svc.cluster.local:9000".
        secure: If True => use HTTPS for the Minio client.

    Raises:
        RuntimeError if reading/writing secrets or policy fails.
    """
    root_cred_path = "amoebius/minio/root"
    root_secret = await vault_client.read_secret(root_cred_path)

    root_client = await get_minio_client(
        direct_settings=MinioSettings(
            url=f"https://{fqdn_service}" if secure else f"http://{fqdn_service}",
            access_key=root_secret["root_user"],
            secret_key=root_secret["root_password"],
        ),
        secure=secure,
    )

    new_access_key = role_name
    new_secret_key = secrets.token_urlsafe(16)

    # e.g. root_client.admin_add_user(new_access_key, new_secret_key)
    # for bucket, perm in buckets_permissions.items():
    #     # e.g. set policy
    #     pass

    new_settings = MinioSettings(
        url=f"https://{fqdn_service}" if secure else f"http://{fqdn_service}",
        access_key=new_access_key,
        secret_key=new_secret_key,
    )

    new_identity_path = f"amoebius/minio/id/{role_name}"
    new_secret: Dict[str, Any] = {
        "url": new_settings.url,
        "access_key": new_settings.access_key,
        "secret_key": new_settings.secret_key,
    }
    await vault_client.write_secret(new_identity_path, new_secret)

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
    Deploy a Minio cluster via Terraform, storing ephemeral TF state in Vault.

    Args:
        vault_client: For reading/writing the minio root credentials.
        base_path: Path to the Minio terraform root.
        workspace: The Terraform workspace.
        env: Optional environment variables.
        sensitive: If True, mask logs.
        transit_key_name: Optional Vault transit key for ephemeral encryption.

    Raises:
        RuntimeError if reading or writing secrets fails.
    """
    root_cred_path = "amoebius/minio/root"
    try:
        root_secret = await vault_client.read_secret(root_cred_path)
    except RuntimeError as ex:
        if "404" in str(ex):
            root_user = "admin"
            root_pass = secrets.token_urlsafe(16)
            root_secret = {"root_user": root_user, "root_password": root_pass}
            await vault_client.write_secret(root_cred_path, root_secret)
        else:
            raise

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
    Destroy a Minio cluster via Terraform, ephemeral TF state in Vault.

    Args:
        vault_client: The Vault client for ephemeral usage and root cred reading.
        base_path: The Terraform root path for Minio.
        workspace: The Terraform workspace name.
        env: Optional environment variables for Terraform.
        sensitive: If True, mask logs.
        transit_key_name: Optional Vault transit key name.
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
