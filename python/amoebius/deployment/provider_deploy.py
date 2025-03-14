"""
filename: amoebius/deployment/provider_deploy.py

Defines the logic for deploying/destroying infrastructure for each cloud provider.
Refactored to use MinioStorage for Terraform state, now requiring a Minio client
passed to each Terraform command.
"""

from typing import Dict, Any

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.cluster_deploy import ClusterDeploy
from amoebius.models.providers import ProviderName as _ProviderName
from amoebius.models.providers import get_provider_env_from_secret_data
from amoebius.utils.terraform import init_terraform, apply_terraform, destroy_terraform
from amoebius.utils.terraform.storage import MinioStorage
from amoebius.secrets.minio import get_minio_client


ProviderName = _ProviderName  # Re-export for mypy


async def get_provider_env_from_vault(
    provider: ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str,
) -> Dict[str, str]:
    """Retrieve provider-specific environment variables from Vault.

    Args:
        provider (ProviderName): The provider enum (aws, azure, gcp).
        vault_client (AsyncVaultClient): Vault client for reading secrets.
        vault_path (str): The path in Vault where the secrets reside.

    Returns:
        Dict[str, str]: Environment variables derived from the Vault secret data.
    """
    secret_data = await vault_client.read_secret(vault_path)
    return get_provider_env_from_secret_data(provider, secret_data)


async def deploy(
    provider: ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str,
    cluster_deploy: ClusterDeploy,
    workspace: str,
    destroy: bool = False,
) -> None:
    """Deploy (or destroy) infrastructure for a given provider using Terraform and Minio-based state.

    This function:
      1) Retrieves provider environment variables from Vault.
      2) Fetches Minio credentials from Vault for "amoebius/services/minio/root" and
         constructs a MinioStorage backend for Terraform ephemeral usage.
      3) Calls `init_terraform`, `apply_terraform`, or `destroy_terraform` with the
         appropriate environment and storage arguments.

    Args:
        provider (ProviderName): The cloud provider (AWS, Azure, GCP).
        vault_client (AsyncVaultClient): Vault client for retrieving secrets and Minio credentials.
        vault_path (str): Vault path where relevant provider credentials are stored.
        cluster_deploy (ClusterDeploy): A model containing deployment configuration.
        workspace (str): Terraform workspace to use.
        destroy (bool): If True, executes 'terraform destroy'; otherwise 'init+apply'.

    Raises:
        RuntimeError: If Minio credentials are missing or the Terraform operation fails.
    """
    # 1) Provider env from Vault
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)
    tf_vars = cluster_deploy.model_dump()

    # 2) Construct a Minio client from "amoebius/services/minio/root"
    minio_client = await get_minio_client(
        vault_client=vault_client,
        vault_path="amoebius/services/minio/root",
    )

    # 3) Prepare MinioStorage for Terraform ephemeral usage
    storage = MinioStorage(
        root_module=f"providers/{provider.value}",
        workspace=workspace,
        bucket_name="amoebius",
        transit_key_name="amoebius",
        minio_client=minio_client,  # pass the client to the storage class
    )

    root_name = f"providers/{provider.value}"

    if destroy:
        print(f"[{provider}] => Running destroy with variables = {tf_vars}")
        await destroy_terraform(
            root_name=root_name,
            env=env_vars,
            variables=tf_vars,
            storage=storage,
            vault_client=vault_client,
            workspace=workspace,
        )
    else:
        print(f"[{provider}] => init+apply with variables = {tf_vars}")
        await init_terraform(
            root_name=root_name,
            env=env_vars,
            storage=storage,
            vault_client=vault_client,
        )
        await apply_terraform(
            root_name=root_name,
            env=env_vars,
            variables=tf_vars,
            storage=storage,
            vault_client=vault_client,
            workspace=workspace,
        )

    print(f"[{provider}] => done (destroy={destroy}).")


__all__ = [
    "ProviderName",
    "get_provider_env_from_vault",
    "deploy",
]
