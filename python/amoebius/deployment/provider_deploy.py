"""
provider_deploy.py

We define:
  - get_provider_env_from_vault(provider, vault_client, vault_path)
    -> environment variables from Vault credentials.

  - deploy(provider, vault_client, vault_path, variables, destroy=False)
    -> uses the environment from get_provider_env_from_vault,
       runs terraform init/apply or destroy with the given dictionary of variables.
"""

import json
from enum import Enum
from typing import Dict, Any

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.api_keys import AWSApiKey, AzureCredentials, GCPServiceAccountKey
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
) -> Dict[str, str]:
    """
    Reads credentials from Vault at 'vault_path' for the given provider,
    returns environment variables for Terraform.

    E.g. for AWS, sets AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, [AWS_SESSION_TOKEN].
    """
    secret_data = await vault_client.read_secret(vault_path)

    if provider == ProviderName.aws:
        aws_creds = AWSApiKey(**secret_data)
        env = {
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
    variables: Dict[str, Any],
    destroy: bool = False,
) -> None:
    """
    1) environment = get_provider_env_from_vault
    2) run terraform init+apply or destroy with 'variables'
    3) The root directory is /amoebius/terraform/roots/providers/<provider>

    The 'variables' param is typically cluster_config.model_dump() from your Pydantic model.
    """
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)
    root_name = f"providers/{provider}"

    if destroy:
        print(f"[{provider}] => running terraform destroy with variables = {variables}")
        await destroy_terraform(
            root_name=root_name,
            env=env_vars,
            variables=variables,
            sensitive=False,
        )
    else:
        print(f"[{provider}] => init+apply with variables = {variables}")
        await init_terraform(
            root_name=root_name,
            env=env_vars,
            reconfigure=True,
            sensitive=False,
        )
        await apply_terraform(
            root_name=root_name,
            env=env_vars,
            variables=variables,
            sensitive=False,
        )

    print(f"[{provider}] => done. destroy={destroy}")
