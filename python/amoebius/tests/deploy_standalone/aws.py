#!/usr/bin/env python3
"""
aws_deploy.py

An async end-to-end script that:
  - Reads AWS credentials from Vault at path "amoebius/tests/api_keys/aws"
  - Validates them with AWSApiKey
  - Depending on CLI flags, either:
      * init + apply (default)
      * only destroy if --destroy is passed

AWS credentials are *not* passed in as Terraform variables; we set them via
environment variables: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN.
"""
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
VAULT_PATH = "amoebius/tests/api_keys/aws"
TERRAFORM_ROOT_NAME = "tests/deploy-standalone/aws"  # Subdir in /amoebius/terraform/roots


async def run_aws_deploy_test(destroy_only: bool = False) -> None:
    """
    Reads AWS creds from Vault, validates them, then either:
      - (default) run terraform init + apply
      - (if destroy_only=True) run terraform destroy.
    """
    # 1) Read credentials from Vault
    vault_settings = VaultSettings(
        vault_role_name=VAULT_ROLE_NAME,
        verify_ssl=True,  # or False if self-signed
    )

    async with AsyncVaultClient(vault_settings) as vault:
        # Read AWS credentials from Vault
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

        # Instead of passing as TF variables, set as environment variables:
        env_vars = {
            "AWS_ACCESS_KEY_ID": aws_key.access_key_id,
            "AWS_SECRET_ACCESS_KEY": aws_key.secret_access_key,
        }
        if aws_key.session_token is not None:
            env_vars["AWS_SESSION_TOKEN"] = aws_key.session_token

        # Optionally set the region if you want AWS CLI / AWS SDK to use the
        # same region as Terraform. Typically, Terraform itself uses var.region,
        # but environment variables also work:
        # env_vars["AWS_DEFAULT_REGION"] = "us-east-1"  # or from your var.region

        # 3) Either destroy only, or init+apply
        if destroy_only:
            print("Skipping init/apply. Proceeding with terraform destroy only...")
            await destroy_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                # Do *not* pass these as -var, use env=env_vars
                env=env_vars,
                sensitive=False,
            )
        else:
            print(f"Initializing Terraform for root '{TERRAFORM_ROOT_NAME}'...")
            await init_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                reconfigure=True,
                sensitive=False,
                env=env_vars,
            )

            print("Applying Terraform configuration (auto-approve)...")
            await apply_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                # No -var usage for credentials
                env=env_vars,
                sensitive=False,
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
            "'tests/aws-deploy'. AWS creds are passed as environment variables."
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
