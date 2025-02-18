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
    secret_data = await vault_client.read_secret(vault_path)
    return get_provider_env_from_secret_data(provider, secret_data)


async def deploy(
    provider: _ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str,
    cluster_deploy: ClusterDeploy,
    destroy: bool = False,
) -> None:
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)
    tf_vars = cluster_deploy.model_dump()

    root_name = f"providers/{provider.value}"

    if destroy:
        print(f"[{provider}] => Running destroy with variables = {tf_vars}")
        await destroy_terraform(
            root_name, env=env_vars, variables=tf_vars, sensitive=False
        )
    else:
        print(f"[{provider}] => init+apply with variables = {tf_vars}")
        await init_terraform(root_name, env=env_vars, reconfigure=True, sensitive=False)
        await apply_terraform(
            root_name, env=env_vars, variables=tf_vars, sensitive=False
        )

    print(f"[{provider}] => done (destroy={destroy}).")


# Re-export for mypy
ProviderName = _ProviderName

__all__ = [
    "ProviderName",
    "get_provider_env_from_vault",
    "deploy",
]
