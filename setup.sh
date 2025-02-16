#!/usr/bin/env bash
#
# deploy_python_changes.sh
#
# Creates or overwrites:
#  1) /amoebius/python/amoebius/models/api_keys/__init__.py
#  2) /amoebius/python/amoebius/deployment/provider_deploy.py
#  3) /amoebius/python/amoebius/tests/provider_deployment.py
#
# Key changes:
#  - A separate function get_provider_env_from_vault() does the provider-specific
#    credential parsing & environment variable creation.
#  - deploy_provider() now has a "variables: Optional[Dict[str,Any]]" param
#    passed through to terraform apply/destroy.
#  - We unify the Pydantic models in __init__.py for easy import.
#
# Usage:
#   1) chmod +x deploy_python_changes.sh
#   2) ./deploy_python_changes.sh
#

set -e

BASE_DIR="/amoebius/python/amoebius"
API_KEYS_DIR="$BASE_DIR/models/api_keys"
DEPLOY_DIR="$BASE_DIR/deployment"
TESTS_DIR="$BASE_DIR/tests"

echo "Ensuring directories exist..."
mkdir -p "$API_KEYS_DIR"
mkdir -p "$DEPLOY_DIR"
mkdir -p "$TESTS_DIR"

############################################
# 1) /amoebius/python/amoebius/models/api_keys/__init__.py
############################################
cat << 'EOF' > "$API_KEYS_DIR/__init__.py"
"""
models/api_keys/__init__.py

Aggregate imports so these models can be accessed directly from this package.

Any new pydantic models should go in /amoebius/python/amoebius/models if they
are not specifically for API keys.
"""

from amoebius.models.api_keys.aws import AWSApiKey
from amoebius.models.api_keys.azure import AzureCredentials
from amoebius.models.api_keys.gcp import GCPServiceAccountKey

__all__ = [
    "AWSApiKey",
    "AzureCredentials",
    "GCPServiceAccountKey",
]
EOF

############################################
# 2) /amoebius/python/amoebius/deployment/provider_deploy.py
############################################
cat << 'EOF' > "$DEPLOY_DIR/provider_deploy.py"
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
EOF

############################################
# 3) /amoebius/python/amoebius/tests/provider_deployment.py
############################################
cat << 'EOF' > "$TESTS_DIR/provider_deployment.py"
#!/usr/bin/env python3
"""
provider_deployment.py

A Python script to deploy or destroy AWS, Azure, or GCP from credentials in Vault,
using the generic 'deploy_provider' function which references the root
/amoebius/terraform/roots/providers/<provider>.

Usage examples:
  python provider_deployment.py --provider aws --vault-path amoebius/tests/api_keys/aws
  python provider_deployment.py --provider all --vault-path amoebius/tests/api_keys/aws --destroy
  python provider_deployment.py --provider azure --vault-path amoebius/tests/api_keys/azure --vault-args verify_ssl=False

You can also pass terraform variables via --tf-vars "key=val" "key2=val2" if you like.
"""

import sys
import asyncio
import argparse
from typing import Dict, Any, NoReturn, Optional

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.vault import VaultSettings
from amoebius.deployment.provider_deploy import deploy_provider, ProviderName


def parse_keyvals(args_list) -> Dict[str, str]:
    """
    Convert something like ["vault_role_name=amoebius-admin-role", "verify_ssl=False"]
    or ["myvar=someval", "other_var=stuff"] into dicts. Everything is string.
    """
    output: Dict[str, str] = {}
    for item in args_list:
        if "=" in item:
            key, val = item.split("=", 1)
            output[key] = val
        else:
            output[item] = "True"
    return output

async def run_provider(
    provider: ProviderName,
    vault_settings: VaultSettings,
    vault_path: str,
    destroy: bool,
    tf_variables: Optional[Dict[str, Any]] = None
):
    """
    Create a single AsyncVaultClient, then call deploy_provider.
    """
    async with AsyncVaultClient(vault_settings) as vc:
        await deploy_provider(
            provider=provider,
            vault_client=vc,
            vault_path=vault_path,
            variables=tf_variables,
            destroy=destroy
        )

async def run_all(
    vault_settings: VaultSettings,
    vault_path: str,
    destroy: bool,
    tf_variables: Optional[Dict[str, Any]] = None
):
    """
    Deploy or destroy all 3 providers in sequence: AWS, Azure, GCP
    """
    async with AsyncVaultClient(vault_settings) as vc:
        for prov in [ProviderName.aws, ProviderName.azure, ProviderName.gcp]:
            await deploy_provider(
                provider=prov,
                vault_client=vc,
                vault_path=vault_path,
                variables=tf_variables,
                destroy=destroy
            )

def main() -> NoReturn:
    parser = argparse.ArgumentParser(
        description="Deploy or destroy AWS, Azure, or GCP with credentials from Vault."
    )
    parser.add_argument(
        "--provider",
        choices=["aws","azure","gcp","all"],
        required=True,
        help="Which provider to deploy/destroy, or 'all'"
    )
    parser.add_argument(
        "--vault-path",
        required=True,
        help="Vault path containing the credentials, e.g. amoebius/tests/api_keys/aws"
    )
    parser.add_argument(
        "--destroy",
        action="store_true",
        help="If set, skip apply and do terraform destroy only"
    )
    # Vault arguments
    parser.add_argument(
        "--vault-args",
        nargs="*",
        default=[],
        help="Additional vault settings in key=val form, e.g. vault_role_name=amoebius-admin-role verify_ssl=False"
    )
    # Terraform variables
    parser.add_argument(
        "--tf-vars",
        nargs="*",
        default=[],
        help="Additional terraform variables in key=val form, e.g. myvar=stuff region=us-east-1"
    )

    args = parser.parse_args()

    # 1) Build vault settings
    raw_vault_args = parse_keyvals(args.vault_args)
    vault_settings = VaultSettings(**raw_vault_args)

    # 2) Build a dict for tf variables
    tf_var_dict: Dict[str, Any] = parse_keyvals(args.tf_vars) if args.tf_vars else {}

    # 3) Decide single or all
    try:
        if args.provider == "all":
            asyncio.run(
                run_all(
                    vault_settings=vault_settings,
                    vault_path=args.vault_path,
                    destroy=args.destroy,
                    tf_variables=tf_var_dict if tf_var_dict else None
                )
            )
        else:
            prov_enum = ProviderName(args.provider)
            asyncio.run(
                run_provider(
                    provider=prov_enum,
                    vault_settings=vault_settings,
                    vault_path=args.vault_path,
                    destroy=args.destroy,
                    tf_variables=tf_var_dict if tf_var_dict else None
                )
            )
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
EOF

chmod +x "$TESTS_DIR/provider_deployment.py"

echo "Files have been updated with your requested changes:"
echo "1) get_provider_env_from_vault(...) is a standalone function"
echo "2) deploy_provider(...) now includes 'variables: Optional[Dict[str,Any]]'"
echo "3) /amoebius/python/amoebius/tests/provider_deployment.py to run with optional tf vars."
echo "Done!"