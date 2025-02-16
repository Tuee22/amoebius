"""
provider_deploy.py

This module provides:
  - a standalone function get_provider_env_from_vault() that reads credentials from Vault,
    parses them with the correct Pydantic model, and returns environment variables.
  - deploy_provider(...): a generic function that calls get_provider_env_from_vault, then
    runs terraform init+apply or destroy, optionally passing 'variables' to apply/destroy.
"""

import json
from enum import Enum
from typing import Dict, Any, Optional

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
    provider: ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str
) -> Dict[str, str]:
    """
    Reads credentials from 'vault_path', uses the correct Pydantic model
    for 'provider', and returns a dict of environment variables suitable
    for Terraform.

    :param provider: ProviderName
    :param vault_client: an already-authenticated Vault client
    :param vault_path: Vault path containing the secret data
    :return: dictionary of environment variables for Terraform
    """
    # 1) Read from Vault
    secret_data = await vault_client.read_secret(vault_path)

    # 2) Parse & build env
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


async def deploy_provider(
    provider: ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str,
    variables: Optional[Dict[str, Any]] = None,
    destroy: bool = False,
) -> None:
    """
    1) get env = get_provider_env_from_vault(provider, vault_client, vault_path)
    2) If destroy => destroy_terraform(..., env=env, variables=variables)
       else => init_terraform(..., env=env), apply_terraform(..., env=env, variables=variables)
    3) The root path is assumed /amoebius/terraform/roots/providers/<provider>.

    :param provider: provider name
    :param vault_client: existing, authenticated Vault client
    :param vault_path: path in Vault for credentials
    :param variables: optional dict of tf variables to pass to apply/destroy
    :param destroy: if True, only run 'destroy'; else init+apply
    """
    # 1) Get environment variables from Vault
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)

    # 2) The terraform root name
    root_name = f"providers/{provider}"

    # 3) Run Terraform
    if destroy:
        print(f"[{provider}] destroy only, skipping init+apply ...")
        await destroy_terraform(root_name=root_name, env=env_vars, variables=variables, sensitive=False)
    else:
        print(f"[{provider}] init + apply with optional variables ...")
        await init_terraform(root_name=root_name, env=env_vars, reconfigure=True, sensitive=False)
        await apply_terraform(root_name=root_name, env=env_vars, variables=variables, sensitive=False)

    print(f"[{provider}] done (destroy={destroy}).")
