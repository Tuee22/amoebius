#!/usr/bin/env python3
"""
azure_deploy_test.py
Reads Azure creds from Vault => sets env => init+apply or destroy.
"""

import sys
import asyncio
import argparse
from typing import NoReturn, Dict, Any
from pydantic import ValidationError

from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
)
from amoebius.models.api_keys.azure import AzureCredentials

VAULT_ROLE_NAME = "amoebius-admin-role"
VAULT_PATH = "amoebius/tests/api_keys/azure"
TERRAFORM_ROOT_NAME = "tests/deploy-standalone/azure"


async def run_azure_deploy_test(destroy_only: bool = False) -> None:
    vs = VaultSettings(vault_role_name=VAULT_ROLE_NAME, verify_ssl=False)
    async with AsyncVaultClient(vs) as vault:
        try:
            secret_data = await vault.read_secret(VAULT_PATH)
        except RuntimeError as exc:
            raise RuntimeError(f"Failed to read Azure creds: {exc}") from exc

        try:
            azure_creds = AzureCredentials(**secret_data)
        except ValidationError as ve:
            raise RuntimeError(f"Invalid Azure creds: {ve}") from ve

        env_vars = {
            "ARM_CLIENT_ID": azure_creds.client_id,
            "ARM_CLIENT_SECRET": azure_creds.client_secret,
            "ARM_TENANT_ID": azure_creds.tenant_id,
            "ARM_SUBSCRIPTION_ID": azure_creds.subscription_id,
        }

        tf_vars: Dict[str, Any] = {}

        if destroy_only:
            print("Terraform destroy only for Azure.")
            await destroy_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                env=env_vars,
                variables=tf_vars,
                sensitive=False,
            )
        else:
            print("Terraform init+apply for Azure.")
            await init_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                env=env_vars,
                reconfigure=True,
                sensitive=False,
            )
            await apply_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                env=env_vars,
                variables=tf_vars,
                sensitive=False,
            )


def main() -> NoReturn:
    parser = argparse.ArgumentParser("Azure deploy test.")
    parser.add_argument("--destroy", action="store_true")
    args = parser.parse_args()

    try:
        asyncio.run(run_azure_deploy_test(destroy_only=args.destroy))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
