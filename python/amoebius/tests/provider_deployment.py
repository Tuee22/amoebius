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
