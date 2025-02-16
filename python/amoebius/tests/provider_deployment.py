#!/usr/bin/env python3
"""
provider_deployment.py

A minimal unit test or example script that:
  1) Takes provider name, vault path, and optionally --destroy.
  2) Creates a minimal provider-specific cluster config with defaults (AWSClusterDeploy, etc.).
  3) Calls `deploy(...)` from provider_deploy.py to run terraform init+apply or destroy.

Usage examples:
  ./provider_deployment.py --provider aws --vault-path amoebius/tests/api_keys/aws
  ./provider_deployment.py --provider gcp --vault-path amoebius/tests/api_keys/gcp --destroy
"""

import sys
import argparse
import asyncio

# Provider classes with default fields:
from amoebius.models.providers import (
    AWSClusterDeploy,
    AzureClusterDeploy,
    GCPClusterDeploy,
)

# The main deploy function & provider enum:
from amoebius.provider_deploy import deploy, ProviderName

# Minimal Vault usage:
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient


async def run_deployment(
    provider: ProviderName, vault_path: str, destroy: bool
) -> None:
    """
    1) Create a minimal provider-specific cluster config
    2) Create a minimal VaultSettings
    3) Call deploy(...)
    """
    # Step 1: create the cluster deploy object for this provider
    if provider == ProviderName.aws:
        cluster_deploy = AWSClusterDeploy()
    elif provider == ProviderName.azure:
        cluster_deploy = AzureClusterDeploy()
    elif provider == ProviderName.gcp:
        cluster_deploy = GCPClusterDeploy()
    else:
        raise ValueError(f"Unknown provider '{provider}'")

    # Step 2: Minimal VaultSettings (assuming defaults or a known role name)
    # Feel free to tweak if you have a self-signed Vault:
    vs = VaultSettings(
        vault_role_name="amoebius-admin-role",
        verify_ssl=False,  # adjust if your environment requires SSL verification
    )

    # Step 3: Terraform deploy
    async with AsyncVaultClient(vs) as vc:
        await deploy(
            provider=provider,
            vault_client=vc,
            vault_path=vault_path,
            cluster_deploy=cluster_deploy,
            destroy=destroy,
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Minimal script to test AWS/Azure/GCP deployment logic."
    )
    parser.add_argument(
        "--provider",
        choices=["aws", "azure", "gcp"],
        required=True,
        help="Which provider to deploy or destroy."
    )
    parser.add_argument(
        "--vault-path",
        required=True,
        help="Path in Vault to retrieve credentials, e.g. amoebius/tests/api_keys/aws"
    )
    parser.add_argument(
        "--destroy",
        action="store_true",
        help="If set, run terraform destroy instead of init+apply."
    )
    args = parser.parse_args()

    provider_enum = ProviderName(args.provider)

    try:
        asyncio.run(run_deployment(provider_enum, args.vault_path, args.destroy))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())