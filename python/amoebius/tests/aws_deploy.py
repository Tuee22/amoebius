#!/usr/bin/env python3
"""
aws_deploy_test.py

An async end-to-end script that:
  - Reads AWS credentials from Vault at path "amoebius/tests/aws_key"
  - Validates them with AWSApiKey
  - Depending on the CLI flags, either:
      A) init + apply (default)
      B) only destroy if --destroy is passed

Usage:
    python aws_deploy_test.py            # init + apply
    python aws_deploy_test.py --destroy  # only destroy

Requirements:
  - "amoebius/utils/terraform.py" with init_terraform, apply_terraform, destroy_terraform
  - "amoebius/secrets/vault_client.py" with AsyncVaultClient for reading from Vault
  - "amoebius/models/api_keys/aws.py" with AWSApiKey
  - A Vault secret at "amoebius/tests/aws_key" containing:
      {
        "access_key_id": "AKIA...",
        "secret_access_key": "...",
        "session_token": null
      }
    validated against AWSApiKey
  - Terraform CLI installed and in PATH
  - Terraform root "amoebius/terraform/roots/tests/aws-deploy" referencing
    var.aws_access_key_id, var.aws_secret_access_key, var.aws_session_token, etc.
"""

from __future__ import annotations

import sys
import asyncio
import argparse
from typing import NoReturn

from pydantic import ValidationError

from amoebius.models.vault import VaultSettings
from amoebius.models.api_keys.aws import AWSApiKey
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
)

VAULT_ROLE_NAME = "amoebius-admin-role"
VAULT_PATH = "amoebius/tests/aws_key"
TERRAFORM_ROOT_NAME = "tests/aws-deploy"  # Folder in /amoebius/terraform/roots


async def run_aws_deploy_test(destroy_only: bool = False) -> None:
    """
    Reads AWS creds from Vault, validates them, then either:
      - (default) run terraform init + apply, or
      - (if destroy_only=True) skip init/apply and run terraform destroy.

    Raises RuntimeError on any failure.
    """
    # 1) Read credentials from Vault
    vault_settings = VaultSettings(
        vault_role_name=VAULT_ROLE_NAME,
        verify_ssl=True,  # or False if self-signed
    )

    async with AsyncVaultClient(vault_settings) as vault:
        # Read AWS credentials
        try:
            secret_data = await vault.read_secret(VAULT_PATH)
        except RuntimeError as exc:
            raise RuntimeError(
                f"Failed to read AWS credentials from '{VAULT_PATH}': {exc}"
            ) from exc

        # 2) Validate them with AWSApiKey
        try:
            aws_key = AWSApiKey(**secret_data)
        except ValidationError as ve:
            raise RuntimeError(
                f"Vault data at '{VAULT_PATH}' failed AWSApiKey validation: {ve}"
            ) from ve

        # Prepare Terraform variables
        tf_vars = {
            "aws_access_key_id": aws_key.access_key_id,
            "aws_secret_access_key": aws_key.secret_access_key,
        }
        if aws_key.session_token is not None:
            tf_vars["aws_session_token"] = aws_key.session_token

        # 3) Either destroy only, or init+apply
        if destroy_only:
            print("Skipping init/apply. Proceeding with terraform destroy only...")
            await destroy_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                variables=tf_vars,
                vault_client=vault,  # pass the Vault client
            )
        else:
            print(f"Initializing Terraform for root '{TERRAFORM_ROOT_NAME}'...")
            await init_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                reconfigure=True,
                vault_client=vault,  # pass the Vault client
            )

            print("Applying Terraform configuration (auto-approve)...")
            await apply_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                variables=tf_vars,
                vault_client=vault,  # pass the Vault client
            )

            print("Terraform apply completed (no destroy unless --destroy is given).")


def main() -> NoReturn:
    """
    Entry point: parse arguments, run the test, exit(0) on success, exit(1) on error.
    """
    parser = argparse.ArgumentParser(
        description=(
            "Perform an async test to read AWS credentials from Vault, then either "
            "init+apply (default) or only destroy (--destroy) the Terraform root "
            "'tests/aws-deploy'."
        )
    )
    parser.add_argument(
        "--destroy",
        action="store_true",
        help="If set, skip init+apply and ONLY run terraform destroy.",
    )
    args = parser.parse_args()

    try:
        asyncio.run(run_aws_deploy_test(destroy_only=args.destroy))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
