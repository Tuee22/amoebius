"""
amoebius/tests/deploy_standalone/aws.py

Reads AWS creds from Vault, uses AWSApiKey.to_env_dict() for environment vars,
then runs terraform init+apply or destroy, referencing a TerraformBackendRef for
'tests/deploy-standalone/aws'.
"""

from __future__ import annotations

import sys
import asyncio
import argparse
from typing import NoReturn
from pydantic import ValidationError

from amoebius.models.vault import VaultSettings
from amoebius.models.providers.api_keys.aws import AWSApiKey
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import init_terraform, apply_terraform, destroy_terraform
from amoebius.models.terraform import TerraformBackendRef

VAULT_ROLE_NAME = "amoebius-admin-role"
VAULT_PATH = "amoebius/tests/api_keys/aws"
TERRAFORM_REF = TerraformBackendRef(root="tests/deploy-standalone/aws")


async def run_aws_deploy_test(destroy_only: bool = False) -> None:
    """Perform a standalone AWS deploy test via Terraform.

    Args:
        destroy_only (bool): If True, runs destroy only. Otherwise init+apply.
    """
    vs = VaultSettings(vault_role_name=VAULT_ROLE_NAME, verify_ssl=True)
    async with AsyncVaultClient(vs) as vault:
        try:
            secret_data = await vault.read_secret(VAULT_PATH)
        except RuntimeError as exc:
            raise RuntimeError(f"Failed to read AWS creds: {exc}") from exc

        try:
            env_vars = AWSApiKey(**secret_data).to_env_dict()
        except ValidationError as ve:
            raise RuntimeError(f"Invalid AWS creds: {ve}") from ve

        if destroy_only:
            print("Terraform destroy only for AWS.")
            await destroy_terraform(ref=TERRAFORM_REF, env=env_vars)
        else:
            print("Terraform init+apply for AWS.")
            await init_terraform(ref=TERRAFORM_REF, env=env_vars, reconfigure=True)
            await apply_terraform(ref=TERRAFORM_REF, env=env_vars)


def main() -> NoReturn:
    """CLI entry point for AWS deploy tests."""
    parser = argparse.ArgumentParser("AWS deploy script sample.")
    parser.add_argument("--destroy", action="store_true")
    args = parser.parse_args()

    try:
        asyncio.run(run_aws_deploy_test(destroy_only=args.destroy))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
