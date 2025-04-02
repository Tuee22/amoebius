#!/usr/bin/env python3
"""
amoebius/tests/rke2_deploy.py

Simple test script that calls get_rke2_instances_output from amoebius/utils/rke2.py
and then calls deploy_rke2_cluster on the resulting data.
We do not print final RKE2Credentials because the function now stores them in Vault.
"""

from __future__ import annotations

import sys
import argparse
import asyncio
from typing import Optional

from amoebius.utils.terraform import read_terraform_state
from amoebius.models.terraform import TerraformBackendRef
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.vault import VaultSettings
from amoebius.utils.rke2 import get_rke2_instances_output
from amoebius.deployment.rke2 import deploy_rke2_cluster


def main() -> int:
    """CLI entrypoint for testing RKE2 cluster deployment."""
    parser = argparse.ArgumentParser(
        description="Test script for multi-CP RKE2 cluster deployment on Ubuntu 22.04."
    )
    parser.add_argument(
        "--root", required=True, help="Terraform root (e.g. providers/aws)."
    )
    parser.add_argument(
        "--workspace", default="default", help="Terraform workspace name."
    )
    parser.add_argument(
        "--control-plane-group",
        default="control-plane",
        help="Group name for CP nodes.",
    )
    parser.add_argument(
        "--vault-addr", default="http://vault.vault.svc.cluster.local:8200"
    )
    parser.add_argument("--vault-role-name", default=None)
    parser.add_argument("--vault-token", default=None)
    parser.add_argument("--no-verify-ssl", action="store_true")
    parser.add_argument(
        "--credentials-vault-path",
        default="secret/data/rke2/cluster1",
        help="Vault path where we store final RKE2Credentials.",
    )

    args = parser.parse_args()

    try:
        asyncio.run(
            run_rke2_deploy_test(
                root=args.root,
                workspace=args.workspace,
                control_plane_group=args.control_plane_group,
                vault_addr=args.vault_addr,
                vault_role_name=args.vault_role_name,
                vault_token=args.vault_token,
                no_verify_ssl=args.no_verify_ssl,
                credentials_vault_path=args.credentials_vault_path,
            )
        )
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


async def run_rke2_deploy_test(
    root: str,
    workspace: str,
    control_plane_group: str,
    vault_addr: str,
    vault_role_name: Optional[str],
    vault_token: Optional[str],
    no_verify_ssl: bool,
    credentials_vault_path: str,
) -> None:
    """
    Main async test function:
      1) read RKE2InstancesOutput from terraform
      2) call deploy_rke2_cluster
      3) final RKE2Credentials are stored in Vault at credentials_vault_path
    """
    ref = TerraformBackendRef(root=root, workspace=workspace)
    rke2_data = await get_rke2_instances_output(ref)

    vsettings = VaultSettings(
        vault_addr=vault_addr,
        vault_role_name=vault_role_name,
        direct_vault_token=vault_token,
        verify_ssl=not no_verify_ssl,
    )

    async with AsyncVaultClient(vsettings) as vc:
        await deploy_rke2_cluster(
            rke2_output=rke2_data,
            control_plane_group=control_plane_group,
            vault_client=vc,
            credentials_vault_path=credentials_vault_path,
            install_channel="stable",
        )
        print(
            f"RKE2 cluster deployed. Credentials stored at vault path = '{credentials_vault_path}'."
        )


if __name__ == "__main__":
    sys.exit(main())
