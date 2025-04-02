"""
amoebius/services/minio.py

Defines two primary functions for managing a Minio cluster:
1) minio_deploy(...)
2) rotate_minio_secrets(...)
"""

from __future__ import annotations

import asyncio
import secrets
from typing import Optional, Set

from amoebius.models.minio import (
    MinioDeployment,
    MinioSettings,
    MinioServiceAccountAccess,
)
from amoebius.models.terraform import TerraformBackendRef
from amoebius.secrets.minio import (
    get_minio_settings_from_vault,
    store_user_credentials_in_vault,
)
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.minio import MinioAdminClient
from amoebius.utils.k8s import get_service_accounts
from amoebius.utils.terraform.storage import K8sSecretStorage
from amoebius.utils.terraform.commands import init_terraform, apply_terraform


TRANSIT_KEY_NAME = "amoebius"
SERVICE_NAME = "services/minio"


async def minio_deploy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    workspace: str = "default",
    skip_missing_sas: bool = True,
) -> None:
    """
    Idempotently deploy a Minio cluster + user-specific Vault resources.

    Args:
        deployment (MinioDeployment): The desired Minio deployment state,
            including the root bucket name and service account permissions.
        vault_client (AsyncVaultClient): Authenticated Vault client for reading/writing secrets.
        workspace (str): Terraform workspace name, defaults to "default".
        skip_missing_sas (bool): If True, skip configuring user roles/policies for
            K8s service accounts not currently found in the cluster.
            If False, attempt to configure them anyway.

    Returns:
        None

    Raises:
        RuntimeError: If there's a failure in Terraform steps or Vault steps.
    """
    # Root Minio credentials path in Vault
    root_cred_path = "amoebius/services/minio/root"
    root = await get_minio_settings_from_vault(vault_client, root_cred_path)
    if root is None:
        # If missing, create a random secret key
        root = MinioSettings(
            url="http://minio.minio.svc.cluster.local:9000",
            access_key="admin",
            secret_key=secrets.token_urlsafe(16),
            secure=False,
        )
        await store_user_credentials_in_vault(vault_client, root_cred_path, root)

    # Prepare the transit key
    await vault_client.write_transit_key(key_name=TRANSIT_KEY_NAME, idempotent=True)

    # Use a K8s secret-based storage for ephemeral Terraform state
    ref = TerraformBackendRef(root=SERVICE_NAME, workspace=workspace)
    storage = K8sSecretStorage(
        ref=ref,
        namespace="amoebius",
        transit_key_name=TRANSIT_KEY_NAME,
    )

    # Initialize + apply Terraform for the Minio root user secrets
    await init_terraform(
        ref=ref,
        storage=storage,
        vault_client=vault_client,
    )
    await apply_terraform(
        ref=ref,
        storage=storage,
        vault_client=vault_client,
        variables={
            "root_user": root.access_key,
            "root_password": root.secret_key,
        },
    )

    async with MinioAdminClient(root) as client:
        # Create the root bucket (idempotent if it exists)
        await client.create_bucket(deployment.minio_root_bucket)

        # Retrieve K8s SAs in cluster (or skip if not found)
        cluster_sas = await get_service_accounts()
        cluster_sa_keys: Set[str] = {f"{sa.namespace}:{sa.name}" for sa in cluster_sas}

        desired_sa_keys = {
            f"{sa_obj.service_account.namespace}:{sa_obj.service_account.name}"
            for sa_obj in deployment.service_accounts
        }

        # Only configure SAs that exist in the cluster if skip_missing_sas is True
        sas_to_configure = [
            sa_obj
            for sa_obj in deployment.service_accounts
            if (
                not skip_missing_sas
                or f"{sa_obj.service_account.namespace}:{sa_obj.service_account.name}"
                in cluster_sa_keys
            )
        ]

        async def configure_sa(sa_obj: MinioServiceAccountAccess) -> None:
            """
            Create a user in Minio and attach the appropriate policy. Then create
            a read-only Vault policy for the user credentials, and finally
            create a K8s role in Vault that binds the credentials to the K8s SA.
            """
            sa_ns = sa_obj.service_account.namespace
            sa_nm = sa_obj.service_account.name
            sa_key = f"{sa_ns}:{sa_nm}"

            # Path in Vault where user credentials are stored
            user_vault_path = f"amoebius/services/minio/id/{sa_key}"
            user_settings = await get_minio_settings_from_vault(
                vault_client, user_vault_path
            )
            if user_settings is None:
                # Generate random password
                user_settings = MinioSettings(
                    url=root.url,
                    access_key=sa_key,
                    secret_key=secrets.token_urlsafe(16),
                    secure=root.secure,
                )
                await store_user_credentials_in_vault(
                    vault_client, user_vault_path, user_settings
                )

            # Ensure user in Minio
            await client.create_user(user_settings.access_key, user_settings.secret_key)

            # Create or update a policy for that user in Minio
            policy_name = f"policy-{sa_key}"
            await client.create_policy(policy_name, sa_obj.bucket_permissions)
            await client.attach_policy_to_user(user_settings.access_key, policy_name)

            # Create a Vault policy giving read on that user path
            vault_policy_name = f"minio-user-{sa_key}"
            secret_subpath = f"amoebius/services/minio/id/{sa_key}"
            await vault_client.create_user_secret_policy(
                vault_policy_name, secret_subpath
            )

            # Create a K8s role for that SA => minimal read policy
            role_name = f"role-minio-{sa_key}"
            await vault_client.create_k8s_role(
                role_name=role_name,
                bound_sa_names=[sa_nm],
                bound_sa_namespaces=[sa_ns],
                policies=[vault_policy_name],
                ttl="1h",
            )

        # Configure each desired SA in parallel
        await asyncio.gather(*[configure_sa(sa) for sa in sas_to_configure])

        # Now remove any stale SAs that are no longer desired
        user_prefix = "amoebius/services/minio/id/"
        existing_paths = await vault_client.list_secrets(user_prefix)
        existing_sa_keys = {p.rstrip("/") for p in existing_paths}
        stale_sa_keys = existing_sa_keys - desired_sa_keys

        async def remove_stale_sa(sa_key: str) -> None:
            """
            Remove stale user from Minio, its policy, role, and the Vault secrets.
            """
            await client.delete_user(sa_key)
            await client.delete_policy(f"policy-{sa_key}")

            # Remove Vault policy
            vault_pol = f"minio-user-{sa_key}"
            await vault_client.delete_policy(vault_pol)

            # Remove K8s role
            role_name = f"role-minio-{sa_key}"
            await vault_client.delete_k8s_role(role_name)

            # Remove the user secret from Vault (soft delete)
            user_secret_path = f"{user_prefix}{sa_key}"
            await vault_client.delete_secret(user_secret_path, hard=False)

        await asyncio.gather(*[remove_stale_sa(k) for k in stale_sa_keys])


async def rotate_minio_secrets(
    vault_client: AsyncVaultClient,
    *,
    workspace: str = "default",
) -> None:
    """
    Rotate both root and user credentials for Minio. This updates:
      - The root credentials (in Vault and in Minio)
      - Reapplies Terraform for the root user
      - Updates every user credential in Minio
      - Re-stores the new credentials in Vault

    Args:
        vault_client (AsyncVaultClient): Authenticated Vault client
        workspace (str): Terraform workspace name for the "services/minio" backend

    Returns:
        None

    Raises:
        RuntimeError: If no existing root credential is found
    """
    root_cred_path = "amoebius/services/minio/root"
    user_secrets_prefix = "amoebius/services/minio/id/"

    old_root = await get_minio_settings_from_vault(vault_client, root_cred_path)
    if old_root is None:
        raise RuntimeError(
            "No existing root credential found in Vault, cannot rotate secrets."
        )

    # Create new root
    new_root_settings = MinioSettings(
        url=old_root.url,
        access_key="admin",
        secret_key=secrets.token_urlsafe(16),
        secure=old_root.secure,
    )
    # Save in Vault
    await store_user_credentials_in_vault(
        vault_client, root_cred_path, new_root_settings
    )

    # Make sure the transit key is set
    await vault_client.write_transit_key(key_name=TRANSIT_KEY_NAME, idempotent=True)

    # Re-apply Terraform with the new root
    ref = TerraformBackendRef(root=SERVICE_NAME, workspace=workspace)
    storage = K8sSecretStorage(
        ref=ref,
        namespace="amoebius",
        transit_key_name=TRANSIT_KEY_NAME,
    )
    await init_terraform(ref=ref, storage=storage, vault_client=vault_client)
    await apply_terraform(
        ref=ref,
        storage=storage,
        vault_client=vault_client,
        variables={
            "root_user": new_root_settings.access_key,
            "root_password": new_root_settings.secret_key,
        },
    )

    # Now connect to Minio with the new root
    from amoebius.utils.minio import MinioAdminClient

    async with MinioAdminClient(new_root_settings) as client:
        user_paths = await vault_client.list_secrets(user_secrets_prefix)

        async def rotate_user(path_frag: str) -> None:
            user_vault_path = f"{user_secrets_prefix}{path_frag}"
            user_settings = await get_minio_settings_from_vault(
                vault_client, user_vault_path
            )
            if user_settings is None:
                return  # Not a valid user config
            new_pass = secrets.token_urlsafe(16)
            # Update the user password in Minio
            await client.update_user_password(user_settings.access_key, new_pass)
            # Store updated secret in Vault
            updated_user_settings = MinioSettings(
                url=new_root_settings.url,
                access_key=user_settings.access_key,
                secret_key=new_pass,
                secure=new_root_settings.secure,
            )
            await store_user_credentials_in_vault(
                vault_client, user_vault_path, updated_user_settings
            )

        # Rotate each user in parallel
        await asyncio.gather(*(rotate_user(path_frag) for path_frag in user_paths))
