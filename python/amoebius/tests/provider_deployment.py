#!/usr/bin/env python3
"""
A minimal usage script to pick AWS, Azure, or GCP, create the corresponding
*ClusterDeploy object, call 'deploy(...)'.

All fields strictly typed, each provider subclass defines __init__ with defaults,
so no defaults needed in the .tf roots.

Usage:
  ./provider_deployment.py --provider aws --vault-path amoebius/tests/api_keys/aws
  ./provider_deployment.py --provider azure --vault-path amoebius/tests/api_keys/azure --destroy
"""

import sys
import argparse
import asyncio
from amoebius.models.providers import (
    AWSClusterDeploy,
    AzureClusterDeploy,
    GCPClusterDeploy,
)
from amoebius.deployment.provider_deploy import deploy, ProviderName
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.cluster_deploy import ClusterDeploy


async def run_deployment(
    provider: ProviderName, vault_path: str, destroy: bool
) -> None:
    vs = VaultSettings(vault_role_name="amoebius-admin-role", verify_ssl=False)

    cluster_obj: ClusterDeploy
    if provider == ProviderName.aws:
        cluster_obj = AWSClusterDeploy()
    elif provider == ProviderName.azure:
        cluster_obj = AzureClusterDeploy()
    elif provider == ProviderName.gcp:
        cluster_obj = GCPClusterDeploy()
    else:
        raise ValueError("Unknown provider")

    async with AsyncVaultClient(vs) as vc:
        await deploy(
            provider=provider,
            vault_client=vc,
            vault_path=vault_path,
            cluster_deploy=cluster_obj,
            destroy=destroy,
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        "Simple test script for cluster deploy with Mypy-friendly code."
    )
    parser.add_argument("--provider", choices=["aws", "azure", "gcp"], required=True)
    parser.add_argument("--vault-path", required=True)
    parser.add_argument("--destroy", action="store_true")
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
