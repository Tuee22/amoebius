#!/usr/bin/env python3
"""
gcp_deploy_test.py

An async end-to-end script that:
  - Reads GCP service account credentials from Vault at path "amoebius/tests/api_keys/gcp"
  - Validates them with GCPServiceAccountKey (the full JSON key)
  - Depending on CLI flags, either:
      * init + apply (default)
      * only destroy if --destroy is passed

We now set the JSON key as an environment variable (GOOGLE_CREDENTIALS)
so that Terraform's Google provider picks it up implicitly.
"""
import sys
import json
import asyncio
import argparse
from typing import NoReturn, Dict, Any

from pydantic import ValidationError

# Vault + Terraform
from amoebius.models.vault import VaultSettings
from amoebius.models.api_keys.gcp import GCPServiceAccountKey
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
)

VAULT_ROLE_NAME = "amoebius-admin-role"
VAULT_PATH = "amoebius/tests/api_keys/gcp"
TERRAFORM_ROOT_NAME = "tests/deploy-standalone/gcp"  # in /amoebius/terraform/roots


async def run_gcp_deploy_test(destroy_only: bool = False) -> None:
    """
    Reads GCP creds from Vault, validates them, then either:
      - (default) run terraform init + apply
      - (if destroy_only=True) run terraform destroy.
    """
    # 1) Fetch credentials from Vault
    vault_settings = VaultSettings(
        vault_role_name=VAULT_ROLE_NAME,
        verify_ssl=True,  # or False if self-signed
    )

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            # Vault should return a dict matching the standard GCP SA key structure
            secret_data = await vault.read_secret(VAULT_PATH)
        except RuntimeError as exc:
            raise RuntimeError(
                f"Failed to read GCP credentials from '{VAULT_PATH}': {exc}"
            ) from exc

        # 2) Validate them with GCPServiceAccountKey
        try:
            gcp_key = GCPServiceAccountKey(**secret_data)
        except ValidationError as ve:
            raise RuntimeError(
                f"Vault data at '{VAULT_PATH}' failed GCPServiceAccountKey validation: {ve}"
            ) from ve

        # 3) Instead of passing key JSON via -var, pass it via environment variable
        env_vars = {
            # The standard variable the Google provider checks:
            "GOOGLE_CREDENTIALS": json.dumps(gcp_key.model_dump()),
        }

        # If you want, you can also set "CLOUDSDK_CORE_PROJECT" or "GOOGLE_PROJECT"
        # to reflect the default project. But typically, Terraform uses var.project_id.
        env_vars["GOOGLE_PROJECT"] = gcp_key.project_id

        # We'll still pass 'project_id' to Terraform as a variable (non-sensitive),
        # but the credentials are in the env only.
        tf_vars: Dict[str,Any] = {}

        # 4) Either destroy only, or init+apply
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

            print("Terraform apply completed (no destroy unless --destroy is given).")


def main() -> NoReturn:
    """
    Entry point: parse arguments, run the test, exit(0) on success, exit(1) on error.
    """
    parser = argparse.ArgumentParser(
        description=(
            "Perform an async test to read GCP service account credentials from Vault, "
            "then either init+apply (default) or only destroy (--destroy). "
            "Credentials are passed to Terraform as env variables."
        )
    )
    parser.add_argument(
        "--destroy",
        action="store_true",
        help="If set, skip init+apply and ONLY run terraform destroy.",
    )
    args = parser.parse_args()

    try:
        asyncio.run(run_gcp_deploy_test(destroy_only=args.destroy))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
