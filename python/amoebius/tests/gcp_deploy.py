#!/usr/bin/env python3
"""
gcp_deploy_test.py

An async end-to-end script that:
  - Reads GCP service account credentials from Vault at path "amoebius/tests/api_keys/gcp"
  - Validates them with GCPServiceAccountKey (the full JSON key)
  - Depending on the CLI flags, either:
      A) init + apply (default)
      B) only destroy if --destroy is passed

Usage:
    python gcp_deploy_test.py            # init + apply
    python gcp_deploy_test.py --destroy  # only destroy

Requirements:
  - "amoebius/utils/terraform.py" with init_terraform, apply_terraform, destroy_terraform
  - "amoebius/secrets/vault_client.py" with AsyncVaultClient for reading from Vault
  - "amoebius/models/api_keys/gcp.py" with GCPServiceAccountKey (shown above)
  - A Vault secret at "amoebius/tests/api_keys/gcp" containing the standard GCP SA key JSON:
      {
        "type": "service_account",
        "project_id": "my-gcp-project",
        "private_key_id": "...",
        "private_key": "...",
        "client_email": "...",
        ...
      }
    validated against GCPServiceAccountKey
  - Terraform CLI installed and in PATH
  - Terraform root "amoebius/terraform/roots/tests/gcp-deploy" referencing
    var.project_id, var.service_account_key_json, etc.
"""

from __future__ import annotations

import sys
import json
import asyncio
import argparse
from typing import NoReturn
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
TERRAFORM_ROOT_NAME = "tests/gcp-deploy"  # Folder in /amoebius/terraform/roots


async def run_gcp_deploy_test(destroy_only: bool = False) -> None:
    """
    Reads GCP creds from Vault, validates them, then either:
      - (default) run terraform init + apply, or
      - (if destroy_only=True) skip init/apply and run terraform destroy.

    Raises RuntimeError on any failure.
    """
    # 1) Read credentials from Vault
    vault_settings = VaultSettings(
        vault_role_name=VAULT_ROLE_NAME,
        verify_ssl=True,  # or False if self-signed or dev environment
    )

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            # Vault should return a dict that matches the GCP SA JSON structure
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

        # 3) Prepare Terraform variables
        #    - We'll pass 'project_id' by itself,
        #    - and re-serialize the ENTIRE SA JSON as a single string
        #      for the google provider "credentials" param.
        tf_vars = {
            "project_id": gcp_key.project_id,
            "service_account_key_json": json.dumps(
                gcp_key.model_dump()
            ),  # .encode("unicode_escape").decode("utf-8"),
        }

        # 4) Either destroy only, or init+apply
        if destroy_only:
            print("Skipping init/apply. Proceeding with terraform destroy only...")
            await destroy_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                variables=tf_vars,
                sensitive=False,
            )
        else:
            print(f"Initializing Terraform for root '{TERRAFORM_ROOT_NAME}'...")
            await init_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                reconfigure=True,
                sensitive=False,
            )

            print("Applying Terraform configuration (auto-approve)...")
            await apply_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                variables=tf_vars,
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
            "then either init+apply (default) or only destroy (--destroy) "
            "the Terraform root 'tests/gcp-deploy'."
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
