"""
amoebius/services/minio.py

Defines high-level, idempotent "deploy" and "destroy" functions for Minio,
tying together Terraform, Vault, and bucket/policy logic in a declarative style.

Usage:
    from amoebius.services.minio import minio_deploy, minio_destroy
"""

import asyncio
from typing import Optional

from amoebius.models.minio import (
    MinioSettings,
    MinioDeployment,
    MinioServiceAccountAccess,
    MinioPolicySpec,
    MinioBucketPermission,
)
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.minio import store_user_credentials_in_vault
from amoebius.utils.minio import (
    create_bucket,
    delete_bucket,
    create_policy,
    delete_policy,
    create_user,
    delete_user,
    attach_policy_to_user,
)
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    VaultKVStorage,
)
from amoebius.models.validator import validate_type


async def minio_deploy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
    skip_missing_sas: bool = True,
) -> None:
    """
    Idempotently deploy a Minio cluster + relevant buckets/policies, store credentials in Vault.

    Steps:
      1) Terraform "init/apply" for the Minio cluster, storing ephemeral state in Vault if desired.
      2) Create the "root bucket" from deployment (e.g. "amoebius").
      3) For each SA in deployment.service_accounts:
          - Create or update a user with name = SA name
          - Create or update a policy for the bucket perms
          - Attach policy to user
          - Store the user credentials (MinioSettings) in Vault at "amoebius/minio/id/<sa_name>"
      4) If skip_missing_sas=True, we skip SAs that don't actually exist in K8s (placeholder).

    Args:
        deployment (MinioDeployment): A pydantic model describing the entire config.
        vault_client (AsyncVaultClient): For ephemeral usage and storing credentials.
        base_path (str): The path to the Minio Terraform root. Defaults to /amoebius/terraform/roots/minio.
        workspace (str): The Terraform workspace for minio. Defaults to "default".
        skip_missing_sas (bool): If True, skip service accounts that don't exist (placeholder).
    """
    # 1) Terraform init/apply
    storage = VaultKVStorage(root_module="minio", workspace=workspace)
    await init_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        base_path=base_path,
    )
    await apply_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        base_path=base_path,
    )

    # 2) Create the root bucket
    root_settings = MinioSettings(
        url="http://minio.minio.svc.cluster.local:9000",  # or from some known root cred...
        access_key="admin",
        secret_key="admin123",
        secure=False,  # example
    )
    await create_bucket(root_settings, deployment.minio_root_bucket)

    # 3) For each service account
    # Placeholder for skipping SAs that don't exist. Real usage => check K8s?
    for sa_access in deployment.service_accounts:
        if skip_missing_sas:
            # pretend we skip if "sa_access.service_account_name" not found
            pass

        user_name = sa_access.service_account_name
        user_password = "secret-" + user_name  # or generate random?

        # create user
        await create_user(root_settings, user_name, user_password)

        # build policy from the bucket_permissions
        policy_name = f"policy-{user_name}"
        await create_policy(root_settings, policy_name, sa_access.bucket_permissions)

        # attach
        await attach_policy_to_user(root_settings, user_name, policy_name)

        # store credentials in Vault => "amoebius/minio/id/<sa_name>"
        # This ensures the Pod using that SA can read from vault => build a MinioSettings => only the permitted buckets
        user_settings = MinioSettings(
            url=root_settings.url,
            access_key=user_name,
            secret_key=user_password,
            secure=root_settings.secure,
        )
        path_in_vault = f"amoebius/minio/id/{user_name}"
        await store_user_credentials_in_vault(
            vault_client=vault_client,
            vault_path=path_in_vault,
            minio_settings=user_settings,
        )


async def minio_destroy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
) -> None:
    """
    Idempotently remove the Minio cluster, plus relevant buckets/policies/users in Minio.

    Steps:
      1) For each service account in deployment, remove user, remove policy, remove vault credentials
      2) Remove root bucket
      3) Terraform "destroy" the cluster

    Args:
        deployment (MinioDeployment): The config describing what was previously deployed.
        vault_client (AsyncVaultClient): For ephemeral usage and removing credentials from Vault.
        base_path (str): Terraform path to minio. Defaults to /amoebius/terraform/roots/minio.
        workspace (str): Terraform workspace. Defaults to "default".
    """
    # 1) For each SA, remove user + policy + vault secret
    root_settings = MinioSettings(
        url="http://minio.minio.svc.cluster.local:9000",
        access_key="admin",
        secret_key="admin123",
        secure=False,
    )
    for sa_access in deployment.service_accounts:
        user_name = sa_access.service_account_name
        policy_name = f"policy-{user_name}"

        # remove user
        await delete_user(root_settings, user_name)

        # remove policy
        await delete_policy(root_settings, policy_name)

        # remove from vault
        path_in_vault = f"amoebius/minio/id/{user_name}"
        try:
            await vault_client.delete_secret(path_in_vault, hard=False)
        except RuntimeError as ex:
            if "404" in str(ex):
                pass
            else:
                raise

    # 2) remove root bucket
    await delete_bucket(root_settings, deployment.minio_root_bucket)

    # 3) Terraform destroy
    storage = VaultKVStorage(root_module="minio", workspace=workspace)
    await destroy_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        base_path=base_path,
    )
