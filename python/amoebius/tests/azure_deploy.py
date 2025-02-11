#!/usr/bin/env python3
"""
azure_deploy_test.py

An async end-to-end script that:
  - Reads Azure creds from Vault at path "amoebius/tests/api_keys/azure"
  - Validates them with AzureCredentials
  - Depending on the CLI flags:
      * init + apply (default)
      * only destroy if --destroy is passed

It then sets environment variables:
  ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
so Terraform's azurerm provider can authenticate implicitly.
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
from amoebius.models.api_keys.azure import AzureCredentials  # your Pydantic model

VAULT_ROLE_NAME = "amoebius-admin-role"
VAULT_PATH = "amoebius/tests/api_keys/azure"
TERRAFORM_ROOT_NAME = "tests/azure-deploy"  # In /amoebius/terraform/roots


async def run_azure_deploy_test(destroy_only: bool = False) -> None:
    """
    1. Read Azure creds from Vault
    2. Validate them with AzureCredentials
    3. Set environment variables for Terraform
    4. Either init+apply or destroy
    """
    vault_settings = VaultSettings(
        vault_role_name=VAULT_ROLE_NAME,
        verify_ssl=True,  # or False in dev environment
    )

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            secret_data = await vault.read_secret(VAULT_PATH)
        except RuntimeError as exc:
            raise RuntimeError(
                f"Failed to read Azure credentials from '{VAULT_PATH}': {exc}"
            ) from exc

        # Validate with our Pydantic model
        try:
            azure_creds = AzureCredentials(**secret_data)
        except ValidationError as ve:
            raise RuntimeError(
                f"Vault data at '{VAULT_PATH}' failed AzureCredentials validation: {ve}"
            ) from ve

        # Build environment variables for Terraform
        env_vars = {
            "ARM_CLIENT_ID": azure_creds.client_id,
            "ARM_CLIENT_SECRET": azure_creds.client_secret,
            "ARM_TENANT_ID": azure_creds.tenant_id,
            "ARM_SUBSCRIPTION_ID": azure_creds.subscription_id,
        }

        # If you want to pass other non-secret variables to Terraform as -var,
        # you can do so. For example, resource_group_name or location.
        # For now, let's assume they have defaults in the .tf code:
        tf_vars: Dict[str, Any] = {}

        if destroy_only:
            print("Skipping init/apply. Proceeding with terraform destroy only...")
            await destroy_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                variables=tf_vars,
                env=env_vars,
                sensitive=False,
            )
        else:
            print(f"Initializing Terraform for root '{TERRAFORM_ROOT_NAME}'...")
            await init_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                reconfigure=True,
                env=env_vars,
                sensitive=False,
            )

            print("Applying Terraform configuration (auto-approve)...")
            await apply_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                variables=tf_vars,
                env=env_vars,
                sensitive=False,
            )

            print("Terraform apply completed.")


def main() -> NoReturn:
    parser = argparse.ArgumentParser(
        description="Read Azure creds from Vault, run Terraform init+apply or destroy."
    )
    parser.add_argument(
        "--destroy",
        action="store_true",
        help="If set, only run terraform destroy (skip apply).",
    )
    args = parser.parse_args()

    try:
        asyncio.run(run_azure_deploy_test(destroy_only=args.destroy))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
