"""
amoebius/services/minio.py

Defines two functions:

1) minio_deploy(...) -> None
   - Idempotently deploy Minio based on a MinioDeployment,
     creating or reusing a root credential in Vault if missing.

2) rotate_minio_secrets(...) -> None
   - Rotates both root and user credentials by listing all from Vault
     and updating them in Minio.
"""

import asyncio
import secrets
from typing import Optional

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
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    VaultKVStorage,
)
from amoebius.utils.minio import MinioAdminClient
from amoebius.utils.k8s import get_service_accounts


async def minio_deploy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
    skip_missing_sas: bool = True,
) -> None:
    """Idempotently deploy a Minio cluster and configure buckets/policies.

    Steps:
      1) Retrieve or create root credential from Vault at amoebius/minio/root.
      2) Perform Terraform init/apply.
      3) Create the 'root bucket' if missing.
      4) Retrieve K8s service accounts from the cluster.
      5) For each SA => create user/policy if missing, store in vault if newly created.

    Args:
        deployment (MinioDeployment):
            Describes the root bucket name and which K8s SAs need access.
        vault_client (AsyncVaultClient):
            The Vault client for reading/writing credentials.
        base_path (str, optional):
            Path to Terraform. Defaults to "/amoebius/terraform/roots/minio".
        workspace (str, optional):
            Terraform workspace name. Defaults to "default".
        skip_missing_sas (bool, optional):
            If True, skip SAs not found. Defaults to True.
    """
    root_cred_path = "amoebius/minio/root"

    # 1) Retrieve existing root or create a new one if missing
    existing_root = await get_minio_settings_from_vault(vault_client, root_cred_path)
    if existing_root is None:
        # Create new root
        existing_root = MinioSettings(
            url="http://minio.minio.svc.cluster.local:9000",
            access_key="admin",
            secret_key=secrets.token_urlsafe(16),
            secure=False,
        )
        await store_user_credentials_in_vault(
            vault_client, root_cred_path, existing_root
        )

    # 2) Terraform init + apply
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

    # 3) Create root bucket if missing
    async with MinioAdminClient(existing_root) as client:
        await client.create_bucket(deployment.minio_root_bucket)

        # 4) Retrieve K8s SAs
        cluster_sas = await get_service_accounts()

        # 5) For each SA => create user + policy if missing
        async def configure_sa(sa_obj: MinioServiceAccountAccess) -> None:
            ksa = sa_obj.service_account
            if skip_missing_sas and (ksa not in cluster_sas):
                return

            user_name = f"{ksa.namespace}:{ksa.name}"
            user_vault_path = f"amoebius/minio/id/{user_name}"

            # Check if credentials exist
            user_settings = await get_minio_settings_from_vault(
                vault_client, user_vault_path
            )
            if user_settings is None:
                # Generate new
                user_settings = MinioSettings(
                    url=existing_root.url,
                    access_key=user_name,
                    secret_key=secrets.token_urlsafe(16),
                    secure=existing_root.secure,
                )
                await store_user_credentials_in_vault(
                    vault_client, user_vault_path, user_settings
                )

            # Create user if missing
            await client.create_user(
                user_settings.access_key,
                user_settings.secret_key,
            )
            # Upsert policy
            policy_name = f"policy-{user_name}"
            await client.create_policy(policy_name, sa_obj.bucket_permissions)
            await client.attach_policy_to_user(user_name, policy_name)

        tasks = [configure_sa(sa) for sa in deployment.service_accounts]
        await asyncio.gather(*tasks)


async def rotate_minio_secrets(
    vault_client: AsyncVaultClient,
    *,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
) -> None:
    """Rotates both root and user secrets:
       1) Regenerate root creds, re-apply Terraform
       2) List user secrets in 'amoebius/minio/id/', update them concurrently

    Raises:
        RuntimeError: If no existing root secret is found in Vault, or if operations fail.
    """
    root_cred_path = "amoebius/minio/root"
    user_secrets_prefix = "amoebius/minio/id/"

    # 1) Read existing root or fail
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

    # Re-apply Terraform
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

    # 2) Rotate user creds
    async with MinioAdminClient(new_root_settings) as client:
        user_paths = await vault_client.list_secrets(user_secrets_prefix)

        async def rotate_user(path_frag: str) -> None:
            user_vault_path = f"{user_secrets_prefix}{path_frag}"
            user_settings = await get_minio_settings_from_vault(
                vault_client, user_vault_path
            )
            if user_settings is None:
                # user doesn't exist => skip
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

        tasks = [rotate_user(path_frag) for path_frag in user_paths]
        await asyncio.gather(*tasks)
