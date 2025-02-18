#!/usr/bin/env python3
"""
gcp_deploy_test.py
Reads GCP service account from Vault => set GOOGLE_CREDENTIALS => init+apply or destroy
"""

import sys
import json
import asyncio
import argparse
from typing import NoReturn, Dict, Any
from pydantic import ValidationError

from amoebius.models.vault import VaultSettings
from amoebius.models.providers.api_keys.gcp import GCPServiceAccountKey
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
)

VAULT_ROLE_NAME = "amoebius-admin-role"
VAULT_PATH = "amoebius/tests/api_keys/gcp"
TERRAFORM_ROOT_NAME = "tests/deploy-standalone/gcp"


async def run_gcp_deploy_test(destroy_only: bool = False) -> None:
    vs = VaultSettings(vault_role_name=VAULT_ROLE_NAME, verify_ssl=True)
    async with AsyncVaultClient(vs) as vault:
        try:
            secret_data = await vault.read_secret(VAULT_PATH)
        except RuntimeError as exc:
            raise RuntimeError(f"Failed to read GCP creds: {exc}") from exc

        try:
            gcp_key = GCPServiceAccountKey(**secret_data)
        except ValidationError as ve:
            raise RuntimeError(f"Invalid GCP key: {ve}") from ve

        env_vars = {
            "GOOGLE_CREDENTIALS": json.dumps(gcp_key.model_dump()),
            "GOOGLE_PROJECT": gcp_key.project_id,
        }

        tf_vars: Dict[str, Any] = {}

        if destroy_only:
            print("Terraform destroy only for GCP.")
            await destroy_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                env=env_vars,
                variables=tf_vars,
                sensitive=False,
            )
        else:
            print("Terraform init+apply for GCP.")
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
    parser = argparse.ArgumentParser("GCP deploy test.")
    parser.add_argument("--destroy", action="store_true")
    args = parser.parse_args()

    try:
        asyncio.run(run_gcp_deploy_test(destroy_only=args.destroy))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
