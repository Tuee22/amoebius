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
from amoebius.models.terraform import TerraformBackendRef
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
        provider: The provider enum (aws, azure, gcp).
        vault_client: Vault client for reading secrets.
        vault_path: The path in Vault where the secrets reside.

    Returns:
        Environment variables derived from the Vault secret data.
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
    """Deploy (or destroy) infra for a given provider using Terraform + Minio-based ephemeral storage.

    Steps:
      1) Retrieve provider environment from Vault.
      2) Fetch Minio credentials from 'amoebius/services/minio/root'.
      3) Build a TerraformBackendRef (root = f"providers/{provider.value}", workspace=...).
      4) Construct a MinioStorage referencing that ref + 'amoebius' bucket.
      5) init/apply or destroy with the specified variables from cluster_deploy.

    Args:
        provider: The cloud provider (aws, azure, gcp).
        vault_client: Vault client for retrieving secrets / Minio credentials.
        vault_path: Path in Vault where provider credentials are stored.
        cluster_deploy: Model with region, instance_groups, etc.
        workspace: Terraform workspace name.
        destroy: If True => runs 'destroy_terraform'; else init+apply.

    Raises:
        RuntimeError: If Minio credentials are missing or the Terraform op fails.
    """
    # 1) Provider env from Vault
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)
    tf_vars = cluster_deploy.model_dump()

    # 2) Construct a Minio client from "amoebius/services/minio/root"
    minio_client = await get_minio_client(
        vault_client=vault_client,
        vault_path="amoebius/services/minio/root",
    )

    # 3) Build a TerraformBackendRef => e.g. root="providers/aws"
    ref = TerraformBackendRef(root=f"providers/{provider.value}", workspace=workspace)

    # 4) Construct a MinioStorage referencing that ref
    storage = MinioStorage(
        ref=ref,
        bucket_name="amoebius",
        transit_key_name="amoebius",
        minio_client=minio_client,
    )

    if destroy:
        print(f"[{provider}] => Running destroy with variables = {tf_vars}")
        await destroy_terraform(
            ref=ref,
            env=env_vars,
            variables=tf_vars,
            storage=storage,
            vault_client=vault_client,
        )
    else:
        print(f"[{provider}] => init+apply with variables = {tf_vars}")
        await init_terraform(
            ref=ref,
            env=env_vars,
            storage=storage,
            vault_client=vault_client,
        )
        await apply_terraform(
            ref=ref,
            env=env_vars,
            variables=tf_vars,
            storage=storage,
            vault_client=vault_client,
        )

    print(f"[{provider}] => done (destroy={destroy}).")
