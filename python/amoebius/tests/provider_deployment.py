#!/usr/bin/env python3
"""
A minimal usage script to pick AWS, Azure, or GCP, create the corresponding
*ClusterDeploy object, and call 'deploy(...)'.

All fields are strictly typed; each provider subclass defines __init__ with defaults,
so no defaults are needed in the .tf roots.

Usage:
  ./provider_deployment.py --provider aws --vault-path amoebius/tests/api_keys/aws
  ./provider_deployment.py --provider azure --vault-path amoebius/tests/api_keys/azure --destroy
"""

import sys
import argparse
import asyncio
from typing import List

from amoebius.deployment.provider_deploy import deploy, ProviderName
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.cluster_deploy import (
    ClusterDeploy,
    InstanceGroup,
    provider_model_map,
)

# Define a list of InstanceGroup objects
instance_groups: List[InstanceGroup] = [
    InstanceGroup(
        name="web-servers",
        category="x86_small",
        count_per_zone=2,
        image=None,  # Use default x86 image
    ),
    InstanceGroup(
        name="app-servers",
        category="x86_medium",
        count_per_zone=2,
        image=None,  # Use default x86 image
    ),
    InstanceGroup(
        name="db-servers",
        category="x86_large",
        count_per_zone=1,
        image=None,  # Use default x86 image
    ),
    InstanceGroup(
        name="gpu-workers",
        category="nvidia_small",
        count_per_zone=1,
        image=None,  # Use default GPU image
    ),
]


async def run_deployment(
    provider: ProviderName, vault_path: str, destroy: bool
) -> None:
    vs = VaultSettings(vault_role_name="amoebius-admin-role", verify_ssl=False)

    # Get the provider-specific model from the dictionary
    model_cls = provider_model_map.get(provider)
    if not model_cls:
        raise ValueError(f"Unknown provider: {provider}")

    cluster_deploy = model_cls(instance_groups=instance_groups)

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
        description="Simple test script for cluster deploy with Mypy-friendly code."
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
