#!/usr/bin/env bash
#
# fix_mypy_provider_deployment.sh
#
# This script overwrites /amoebius/python/amoebius/tests/provider_deployment.py
# so that the variable used to store the cluster deploy object is typed
# as the base `ClusterDeploy`, ensuring Mypy doesn't see an incompatible assignment
# when switching from AWSClusterDeploy -> AzureClusterDeploy, etc.
#
# Usage:
#   chmod +x fix_mypy_provider_deployment.sh
#   ./fix_mypy_provider_deployment.sh
#

set -e

TESTS_DIR="/amoebius/python/amoebius/tests"

cat << 'EOF' > "$TESTS_DIR/provider_deployment.py"
#!/usr/bin/env python3
"""
A minimal usage script to pick AWS, Azure, or GCP, create the corresponding
*ClusterDeploy object, call 'deploy(...)'.

All fields are strictly typed. Each provider subclass defines __init__
with defaults. We store the final object in a variable typed as the base
class `ClusterDeploy`, resolving Mypy conflicts.

Usage:
  ./provider_deployment.py --provider aws --vault-path amoebius/tests/api_keys/aws
  ./provider_deployment.py --provider azure --vault-path amoebius/tests/api_keys/azure --destroy
"""

import sys
import argparse
import asyncio

from amoebius.models.providers import AWSClusterDeploy, AzureClusterDeploy, GCPClusterDeploy
from amoebius.provider_deploy import deploy, ProviderName
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient

# The base class for any provider-specific cluster config:
from amoebius.models.cluster_deploy import ClusterDeploy

async def run_deployment(provider: ProviderName, vault_path: str, destroy: bool) -> None:
    # Minimal Vault settings
    vs = VaultSettings(
        vault_role_name="amoebius-admin-role",
        verify_ssl=False
    )

    # We define cluster_obj as the base type, so we can assign any subclass
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
            destroy=destroy
        )

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Simple test script for cluster deploy via Mypy-friendly code."
    )
    parser.add_argument("--provider", choices=["aws","azure","gcp"], required=True)
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
EOF

chmod +x "$TESTS_DIR/provider_deployment.py"

echo "All done! Mypy should no longer complain about 'Incompatible types in assignment'."
echo "Now 'cluster_obj' is typed as 'ClusterDeploy', so we can hold any of the subclasses."