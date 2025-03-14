"""
gcp_deploy.py

Reads GCP creds from Vault, uses GCPServiceAccountKey.to_env_dict() for environment vars,
then runs terraform init+apply or destroy. This version has stable indentation.
"""

import sys
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
            env_vars = GCPServiceAccountKey(**secret_data).to_env_dict()
        except ValidationError as ve:
            raise RuntimeError(f"Invalid GCP key: {ve}") from ve

        tf_vars: Dict[str, Any] = {}

        if destroy_only:
            print("Terraform destroy only for GCP.")
            await destroy_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                env=env_vars,
                variables=tf_vars,
            )
        else:
            print("Terraform init+apply for GCP.")
            await init_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                env=env_vars,
                reconfigure=True,
            )
            await apply_terraform(
                root_name=TERRAFORM_ROOT_NAME,
                env=env_vars,
                variables=tf_vars,
            )


def main() -> NoReturn:
    parser = argparse.ArgumentParser("GCP deploy script sample.")
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
