#!/usr/bin/env python3
"""
A minimal usage script to pick AWS, Azure, or GCP, create the corresponding
*ClusterDeploy object, and call 'deploy(...)'.

All fields are strictly typed; each provider subclass defines __init__ with defaults,
so no defaults are needed in the .tf roots.

Usage:
  python -m amoebius.tests.provider_deploy --provider aws --vault-path amoebius/tests/api_keys/aws
  python -m amoebius.tests.provider_deploy --provider azure --vault-path amoebius/tests/api_keys/azure --destroy
"""

import sys
import argparse
import asyncio
from typing import Dict

from amoebius.deployment.provider_deploy import deploy, ProviderName
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup, Deployment
from amoebius.models.provider_map import provider_model_map


# Define an example Deployment (keys are group names, values are InstanceGroup configs)
example_deployment = Deployment(
    {
        "control-plane": InstanceGroup(
            category="x86_small",
            count_per_zone=1,
            image=None,  # Use default x86 image
        ),
        "workers": InstanceGroup(
            category="arm_small",
            count_per_zone=1,
            image=None,  # Use default ARM image
        ),
    }
)


async def run_deployment(
    provider: ProviderName, vault_path: str, destroy: bool
) -> None:
    """Run the deployment (or destruction) for the specified provider.

    Args:
        provider: The cloud provider to use (aws, azure, gcp).
        vault_path: The Vault path containing provider credentials.
        destroy: Whether to run 'terraform destroy'.
    """
    vs = VaultSettings(vault_role_name="amoebius-admin-role", verify_ssl=False)

    # Get the provider-specific deploy model from a dict (provider_model_map)
    model_cls = provider_model_map.get(provider)
    if not model_cls:
        raise ValueError(f"Unknown provider: {provider}")

    # Instantiate the provider-specific deploy model with our example deployment
    cluster_deploy = model_cls(deployment=example_deployment)

    async with AsyncVaultClient(vs) as vc:
        await deploy(
            provider=provider,
            vault_client=vc,
            vault_path=vault_path,
            cluster_deploy=cluster_deploy,
            workspace=f"{provider.value}-test-workspace",
            destroy=destroy,
        )


def main() -> int:
    """Entry point for the simple test script."""
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
