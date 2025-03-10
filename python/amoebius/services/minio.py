"""
amoebius/services/minio.py

Defines two primary functions for managing a Minio cluster:
1) minio_deploy(...)
   - Idempotently deploy Minio based on a MinioDeployment,
     creating or reusing a root credential in Vault,
     ensuring a Vault transit key for ephemeral encryption,
     creating user-specific Vault policies and K8s roles,
     removing stale resources for removed SAs,
     passing root_user and root_password to Terraform 'apply'.

2) rotate_minio_secrets(...)
   - Rotates both root and user credentials by listing them from Vault
     and updating them in Minio (not affecting user-specific policies).
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


async def minio_deploy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    workspace: str = "default",
    skip_missing_sas: bool = True,
) -> None:
    """
    Idempotently deploy a Minio cluster + user-specific Vault resources,
    cleaning up removed SAs but never deleting buckets.

    Steps:
      1) Retrieve/create Minio 'root' credential in Vault (amoebius/services/minio/root).
      2) Create an idempotent Vault transit key 'amoebius/vault-backend' for ephemeral usage.
      3) Terraform init+apply for Minio, passing root_user & root_password.
      4) Create the 'root bucket' if missing.
      5) Possibly skip SAs not in cluster if skip_missing_sas=True.
      6) For each SA => create user + policy in Minio, plus user policy + K8s role in Vault.
      7) Remove stale SAs no longer in the new deployment.

    Args:
        deployment: Declares the root bucket + SAs needing Minio perms.
        vault_client: Vault client for reading/storing credentials + transit usage.
        workspace: Terraform workspace. Defaults to 'default'.
        skip_missing_sas: If True => skip SAs not found in cluster. Defaults to True.

    Raises:
        RuntimeError: If any step fails or resources cannot be created.
    """
    # 1) Retrieve or create root credentials
    root_cred_path = "amoebius/services/minio/root"
    root = await get_minio_settings_from_vault(vault_client, root_cred_path)
    if root is None:
        root = MinioSettings(
            url="http://minio.minio.svc.cluster.local:9000",
            access_key="admin",
            secret_key=secrets.token_urlsafe(16),
            secure=False,
        )
        await store_user_credentials_in_vault(vault_client, root_cred_path, root)

    # 2) Ensure the 'amoebius/vault-backend' transit key is present (idempotent)
    await vault_client.write_transit_key(key_name=TRANSIT_KEY_NAME, idempotent=True)

    # 3) Terraform init+apply for Minio, storing ephemeral .tfstate in K8s secrets,
    #    referencing TRANSIT_KEY_NAME if ephemeral encryption is used
    storage = K8sSecretStorage(
        root_module="minio",
        workspace=workspace,
        namespace="amoebius",
        transit_key_name=TRANSIT_KEY_NAME,
    )
    await init_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        sensitive=False,
    )
    await apply_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        variables={
            "root_user": root.access_key,
            "root_password": root.secret_key,
        },
        sensitive=False,
    )

    # 4) Create the 'root bucket' if missing
    async with MinioAdminClient(root) as client:
        await client.create_bucket(deployment.minio_root_bucket)

        # 5) Possibly skip SAs not in cluster
        cluster_sas = await get_service_accounts()
        cluster_sa_keys: Set[str] = {f"{sa.namespace}:{sa.name}" for sa in cluster_sas}

        # Our set of desired SAs
        desired_sa_keys = {
            f"{sa_obj.service_account.namespace}:{sa_obj.service_account.name}"
            for sa_obj in deployment.service_accounts
        }

        # Filter out SAs if skip_missing_sas => not found in cluster
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
            Configure a single SA => create user + policy in Minio,
            plus user policy + K8s role in Vault.
            """
            sa_ns = sa_obj.service_account.namespace
            sa_nm = sa_obj.service_account.name
            sa_key = f"{sa_ns}:{sa_nm}"

            user_vault_path = f"amoebius/services/minio/id/{sa_key}"
            user_settings = await get_minio_settings_from_vault(
                vault_client, user_vault_path
            )
            if user_settings is None:
                # Create brand-new user credentials
                user_settings = MinioSettings(
                    url=root.url,
                    access_key=sa_key,
                    secret_key=secrets.token_urlsafe(16),
                    secure=root.secure,
                )
                await store_user_credentials_in_vault(
                    vault_client, user_vault_path, user_settings
                )

            # Create user in Minio
            await client.create_user(user_settings.access_key, user_settings.secret_key)

            # Upsert Minio policy
            policy_name = f"policy-{sa_key}"
            await client.create_policy(policy_name, sa_obj.bucket_permissions)
            await client.attach_policy_to_user(user_settings.access_key, policy_name)

            # Create Vault policy => read-only to that secret path
            vault_policy_name = f"minio-user-{sa_key}"
            secret_subpath = f"amoebius/services/minio/id/{sa_key}"
            await vault_client.create_user_secret_policy(
                vault_policy_name, secret_subpath
            )

            # Create a Vault K8s role => "role-minio-{ns}:{name}"
            role_name = f"role-minio-{sa_key}"
            await vault_client.create_k8s_role(
                role_name=role_name,
                bound_sa_names=[sa_nm],
                bound_sa_namespaces=[sa_ns],
                policies=[vault_policy_name],
                ttl="1h",
            )

        # Configure relevant SAs
        await asyncio.gather(*[configure_sa(sa) for sa in sas_to_configure])

        # Remove stale SAs
        user_prefix = "amoebius/services/minio/id/"
        existing_paths = await vault_client.list_secrets(user_prefix)
        existing_sa_keys = {p.rstrip("/") for p in existing_paths}
        stale_sa_keys = existing_sa_keys - desired_sa_keys

        async def remove_stale_sa(sa_key: str) -> None:
            """Remove stale SA from both Minio and Vault."""
            await client.delete_user(sa_key)
            await client.delete_policy(f"policy-{sa_key}")

            vault_pol = f"minio-user-{sa_key}"
            await vault_client.delete_policy(vault_pol)

            role_name = f"role-minio-{sa_key}"
            await vault_client.delete_k8s_role(role_name)

            user_secret_path = f"{user_prefix}{sa_key}"
            await vault_client.delete_secret(user_secret_path, hard=False)

        await asyncio.gather(*[remove_stale_sa(k) for k in stale_sa_keys])


async def rotate_minio_secrets(
    vault_client: AsyncVaultClient,
    *,
    workspace: str = "default",
) -> None:
    """
    Rotate both root and user secrets, reapplying Terraform for root user changes.

    Steps:
      1) Generate new root credentials, store in Vault, re-apply Terraform with new root creds.
      2) For each user => update password in Minio, store updated secret in Vault.

    Args:
        vault_client: Vault client for reading/writing credentials, transit usage.
        workspace: Terraform workspace. Defaults to 'default'.

    Raises:
        RuntimeError: If no existing root is found in Vault.
    """
    root_cred_path = "amoebius/services/minio/root"
    user_secrets_prefix = "amoebius/services/minio/id/"

    old_root = await get_minio_settings_from_vault(vault_client, root_cred_path)
    if old_root is None:
        raise RuntimeError(
            "No existing root credential found in Vault, cannot rotate secrets."
        )

    new_root_settings = MinioSettings(
        url=old_root.url,
        access_key="admin",
        secret_key=secrets.token_urlsafe(16),
        secure=old_root.secure,
    )
    await store_user_credentials_in_vault(
        vault_client, root_cred_path, new_root_settings
    )

    # Ensure the 'amoebius/vault-backend' transit key for ephemeral usage is present
    await vault_client.write_transit_key(key_name=TRANSIT_KEY_NAME, idempotent=True)

    # Use K8sSecretStorage for Terraform ephemeral usage
    storage = K8sSecretStorage(
        root_module="minio",
        workspace=workspace,
        namespace="amoebius",
        transit_key_name=TRANSIT_KEY_NAME,
    )
    await init_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
    )
    await apply_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        variables={
            "root_user": new_root_settings.access_key,
            "root_password": new_root_settings.secret_key,
        },
    )

    async with MinioAdminClient(new_root_settings) as client:
        user_paths = await vault_client.list_secrets(user_secrets_prefix)

        async def rotate_user(path_frag: str) -> None:
            user_vault_path = f"{user_secrets_prefix}{path_frag}"
            user_settings = await get_minio_settings_from_vault(
                vault_client, user_vault_path
            )
            if user_settings is None:
                return

            new_pass = secrets.token_urlsafe(16)
            await client.update_user_password(user_settings.access_key, new_pass)

            updated_user_settings = MinioSettings(
                url=new_root_settings.url,
                access_key=user_settings.access_key,
                secret_key=new_pass,
                secure=new_root_settings.secure,
            )
            await store_user_credentials_in_vault(
                vault_client, user_vault_path, updated_user_settings
            )

        await asyncio.gather(*[rotate_user(path_frag) for path_frag in user_paths])
