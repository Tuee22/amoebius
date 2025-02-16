"""
provider_deploy.py

We define:
  - get_provider_env_from_vault(...) -> Dict[str, Any]
  - deploy(..., cluster_deploy: ClusterDeploy) -> None
"""

import json
from enum import Enum
from typing import Dict, Any

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.api_keys import AWSApiKey, AzureCredentials, GCPServiceAccountKey
from amoebius.models.cluster_deploy import ClusterDeploy
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
)


class ProviderName(str, Enum):
    aws = "aws"
    azure = "azure"
    gcp = "gcp"


async def get_provider_env_from_vault(
    provider: ProviderName, vault_client: AsyncVaultClient, vault_path: str
) -> Dict[str, Any]:
    secret_data = await vault_client.read_secret(vault_path)

    if provider == ProviderName.aws:
        aws_creds = AWSApiKey(**secret_data)
        env: Dict[str, Any] = {
            "AWS_ACCESS_KEY_ID": aws_creds.access_key_id,
            "AWS_SECRET_ACCESS_KEY": aws_creds.secret_access_key,
        }
        if aws_creds.session_token:
            env["AWS_SESSION_TOKEN"] = aws_creds.session_token
        return env
    elif provider == ProviderName.azure:
        az_creds = AzureCredentials(**secret_data)
        return {
            "ARM_CLIENT_ID": az_creds.client_id,
            "ARM_CLIENT_SECRET": az_creds.client_secret,
            "ARM_TENANT_ID": az_creds.tenant_id,
            "ARM_SUBSCRIPTION_ID": az_creds.subscription_id,
        }
    elif provider == ProviderName.gcp:
        gcp_creds = GCPServiceAccountKey(**secret_data)
        return {
            "GOOGLE_CREDENTIALS": json.dumps(gcp_creds.model_dump()),
            "GOOGLE_PROJECT": gcp_creds.project_id,
        }
    else:
        raise ValueError(f"Unknown provider: {provider}")


async def deploy(
    provider: ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str,
    cluster_deploy: ClusterDeploy,
    destroy: bool = False,
) -> None:
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)
    tf_vars = cluster_deploy.model_dump()

    root_name = f"providers/{provider}"

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
