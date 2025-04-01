#!/usr/bin/env python3
"""
amoebius/tests/rke2_deploy.py

A CLI test script, reading 'instances' from Terraform output,
flattening them into RKE2Instance objects, then calling deploy_rke2_cluster.
"""

import sys
import argparse
import asyncio
from typing import Optional, List, Dict

from amoebius.utils.terraform import read_terraform_state, get_output_from_state
from amoebius.models.terraform import TerraformBackendRef
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.vault import VaultSettings
from amoebius.models.rke2 import RKE2Instance, RKE2InstancesOutput
from amoebius.deployment.rke2 import deploy_rke2_cluster


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Simple test script for RKE2 cluster deployment."
    )
    parser.add_argument(
        "--root", required=True, help="Terraform root (e.g. providers/aws)"
    )
    parser.add_argument("--workspace", default="default")
    parser.add_argument("--control-plane-group", default="control-plane")
    parser.add_argument(
        "--vault-addr", default="http://vault.vault.svc.cluster.local:8200"
    )
    parser.add_argument("--vault-role-name", default=None)
    parser.add_argument("--vault-token", default=None)
    parser.add_argument("--no-verify-ssl", action="store_true")

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
) -> None:
    """Reads TF state => flatten => call deploy_rke2_cluster => print creds."""
    ref = TerraformBackendRef(root=root, workspace=workspace)
    tfstate = await read_terraform_state(ref=ref)

    raw_instances = get_output_from_state(tfstate, "instances", dict)
    flattened: Dict[str, List[RKE2Instance]] = {}
    for grp_name, grp_map in raw_instances.items():
        inst_list: List[RKE2Instance] = []
        for inst_info in grp_map.values():
            rke_inst = RKE2Instance(
                name=inst_info["name"],
                private_ip=inst_info["private_ip"],
                public_ip=inst_info.get("public_ip"),
                vault_path=inst_info["vault_path"],
                has_gpu=bool(inst_info.get("is_nvidia_instance", False)),
            )
            inst_list.append(rke_inst)
        flattened[grp_name] = inst_list

    rke2_data = RKE2InstancesOutput(instances=flattened)

    vsettings = VaultSettings(
        vault_addr=vault_addr,
        vault_role_name=vault_role_name,
        direct_vault_token=vault_token,
        verify_ssl=not no_verify_ssl,
    )

    async with AsyncVaultClient(vsettings) as vc:
        creds = await deploy_rke2_cluster(
            rke2_output=rke2_data,
            control_plane_group=control_plane_group,
            vault_client=vc,
            install_channel="stable",
            retrieve_credentials=True,
        )
        if creds:
            print("=== RKE2 DEPLOYMENT COMPLETE ===")
            print("Node Join Token:", creds.join_token)
            print("Kubeconfig:\n", creds.kubeconfig)
            print("Control plane SSH map:", creds.control_plane_ssh)


if __name__ == "__main__":
    sys.exit(main())
