#!/usr/bin/env python3
"""
amoebius/cli/utils/kubectl.py

A CLI wrapper around run_kubectl_command in amoebius.utils.k8s, allowing the user
to do something like:

    python -m amoebius.cli.utils.kubectl \
      --vault-addr ... \
      --vault-role-name ... \
      --creds-path secrets/rke2/whatever/creds \
      exec -it mypod -- bash

We fetch the RKE2Credentials from Vault, which includes a list of Vault paths
to each control-plane node's SSH config (the "control_plane_ssh_vault_path"
list). We load each SSH config from Vault, then pass them to run_kubectl_command.
If the user typed "-it" or "-i" or "-t", we assume interactive usage.

Everything is typed, passes mypy --strict, and imports are all at the top.
"""

from __future__ import annotations

import sys
import argparse
import asyncio

from typing import List

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.vault import VaultSettings
from amoebius.models.ssh import SSHConfig
from amoebius.secrets.rke2 import load_rke2_credentials
from amoebius.secrets.ssh import get_ssh_config
from amoebius.utils.k8s import run_kubectl_command


async def _gather_ssh_configs(
    vault_client: AsyncVaultClient,
    vault_paths: List[str],
) -> List[SSHConfig]:
    """
    For each path in vault_paths, load the SSHConfig from Vault by calling
    get_ssh_config(...). Return them as a list of SSHConfig.
    """

    async def load_one(path: str) -> SSHConfig:
        # We do tofu_if_missing_host_keys=False because presumably they're already set
        return await get_ssh_config(vault_client, path, tofu_if_missing_host_keys=False)

    return await asyncio.gather(*[load_one(vp) for vp in vault_paths])


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Wrapper around run_kubectl_command with CP node selection."
    )
    parser.add_argument(
        "--vault-addr", default="http://vault.vault.svc.cluster.local:8200"
    )
    parser.add_argument("--vault-role-name", default=None)
    parser.add_argument("--vault-token", default=None)
    parser.add_argument(
        "--creds-path", required=True, help="Path in Vault to RKE2Credentials."
    )
    parser.add_argument("kubectl_args", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    if not args.kubectl_args:
        print("No kubectl arguments provided. Exiting.")
        return 1

    try:
        asyncio.run(_run_kubectl(args))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


async def _run_kubectl(args: argparse.Namespace) -> None:
    """
    1) Build vault client
    2) Load RKE2Credentials from vault at args.creds_path
    3) Load each SSHConfig from the vault paths in 'control_plane_ssh_vault_path'
    4) Pass them to run_kubectl_command
    """
    if args.vault_token and args.vault_role_name:
        print("ERROR: --vault-token and --vault-role-name are mutually exclusive.")
        sys.exit(1)

    vs = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
    )
    async with AsyncVaultClient(vs) as client:
        creds = await load_rke2_credentials(
            vault_client=client,
            vault_path=args.creds_path,
        )
        # The RKE2Credentials includes a field "control_plane_ssh_vault_path"
        # which is a list of vault paths to SSH configs for each CP node.
        cp_vault_paths = creds.control_plane_ssh_vault_path

        # gather them as actual SSHConfig objects:
        cp_ssh_configs = await _gather_ssh_configs(client, cp_vault_paths)

        user_cmd = args.kubectl_args
        user_lower = [x.lower() for x in user_cmd]
        interactive = any(flag in user_lower for flag in ("-it", "-i", "-t"))

        code = await run_kubectl_command(
            ssh_config_list=cp_ssh_configs,
            user_cmd=user_cmd,
            randomize=True,
            interactive=interactive,
        )
        sys.exit(code)


if __name__ == "__main__":
    sys.exit(main())
