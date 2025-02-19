"""
provider_deploy.py

We define:
  - get_provider_env_from_vault(...) -> Dict[str, Any]
  - deploy(..., cluster_deploy: ClusterDeploy) -> None

Relies on ProviderName re-export, so we do:

    from amoebius.models.providers import ProviderName as _ProviderName

Then at bottom:
    ProviderName = _ProviderName
    __all__ = ["ProviderName", "get_provider_env_from_vault", "deploy"]
"""

from typing import Dict, Any

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.cluster_deploy import ClusterDeploy

# Import the real ProviderName under an alias, then re-export
from amoebius.models.providers import ProviderName as _ProviderName
from amoebius.models.providers import get_provider_env_from_secret_data
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
)


async def get_provider_env_from_vault(
    provider: _ProviderName, vault_client: AsyncVaultClient, vault_path: str
) -> Dict[str, str]:
    """
    Retrieves provider-specific environment variables from Vault.

    Args:
        provider:      The provider name (e.g. AWS, GCP, etc.).
        vault_client:  An AsyncVaultClient for reading secrets.
        vault_path:    The path in Vault where the secrets reside.

    Returns:
        A dictionary of environment variables derived from the Vault secret data.
    """
    secret_data = await vault_client.read_secret(vault_path)
    return get_provider_env_from_secret_data(provider, secret_data)


async def deploy(
    provider: _ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str,
    cluster_deploy: ClusterDeploy,
    workspace: str,
    destroy: bool = False,
) -> None:
    """
    Deploys (or destroys) infrastructure for a given provider using Terraform,
    in a specified workspace. Requires that workspace be passed explicitly.

    Args:
        provider:       The cloud provider (AWS, GCP, etc.) to deploy against.
        vault_client:   Vault client for retrieving environment secrets.
        vault_path:     Vault path where relevant provider secrets are stored.
        cluster_deploy: A ClusterDeploy model containing configuration variables.
        workspace:      The mandatory Terraform workspace to use (auto-created if missing).
        destroy:        If True, executes 'terraform destroy'; otherwise 'init+apply'.

    Returns:
        None. Logs out a completion message.

    Raises:
        CommandError: If underlying Terraform commands fail.
        ValueError:   If 'root_name' is invalid or the directory doesn't exist.
    """
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)
    tf_vars = cluster_deploy.model_dump()

    # Terraform root directory named for the provider (e.g., "providers/aws").
    root_name = f"providers/{provider.value}"

    if destroy:
        print(f"[{provider}] => Running destroy with variables = {tf_vars}")
        await destroy_terraform(
            root_name,
            env=env_vars,
            variables=tf_vars,
            sensitive=False,
            workspace=workspace,
        )
    else:
        print(f"[{provider}] => init+apply with variables = {tf_vars}")
        await init_terraform(
            root_name,
            env=env_vars,
            reconfigure=True,
            sensitive=False,
            workspace=workspace,
        )
        await apply_terraform(
            root_name,
            env=env_vars,
            variables=tf_vars,
            sensitive=False,
            workspace=workspace,
        )

    print(f"[{provider}] => done (destroy={destroy}).")


# Re-export for mypy
ProviderName = _ProviderName

__all__ = [
    "ProviderName",
    "get_provider_env_from_vault",
    "deploy",
]
