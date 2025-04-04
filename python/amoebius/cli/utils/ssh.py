#!/usr/bin/env python3
"""
amoebius/cli/utils/ssh.py

Provides a CLI tool for interactive SSH sessions using credentials stored in Vault.
Example usage:

    python -m amoebius.cli.utils.ssh shell \
       --ssh-config-path amoebius/ssh/somehost \
       --vault-addr http://vault.vault.svc.cluster.local:8200

This retrieves the SSHConfig from Vault, ensures host_keys are present,
and opens an interactive SSH shell with strict host-key checking.
"""

import argparse
import asyncio
import sys
from typing import Optional

from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.ssh import get_ssh_config
from amoebius.utils.ssh import ssh_interactive_shell


async def _run_shell(args: argparse.Namespace) -> None:
    """
    Handler for the 'shell' subcommand:
      1) Retrieve SSHConfig from Vault
      2) Start interactive SSH session
    """
    if args.vault_token and args.vault_role_name:
        print(
            "Error: --vault-token and --vault-role-name are mutually exclusive.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Build VaultSettings
    vs = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
        token_path=args.vault_token_path,
        verify_ssl=not args.no_verify_ssl,
    )

    async with AsyncVaultClient(vs) as vc:
        # Retrieve or error out if missing
        ssh_cfg = await get_ssh_config(
            vault_client=vc, path=args.ssh_config_path, tofu_if_missing_host_keys=True
        )

        print(
            f"Opening interactive shell to {ssh_cfg.user}@{ssh_cfg.hostname}:{ssh_cfg.port}"
        )
        retcode = await ssh_interactive_shell(ssh_cfg)
        print(f"Interactive SSH session exited with code: {retcode}")


def main() -> None:
    """
    Entry point for the 'ssh' CLI utility.
    Subcommands:
      - shell: opens an interactive SSH shell
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.utils.ssh",
        description="CLI for interactive SSH sessions using credentials from Vault.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    shell_parser = subparsers.add_parser(
        "shell", help="Open an interactive SSH shell session."
    )
    shell_parser.add_argument(
        "--ssh-config-path",
        required=True,
        help="Vault KV path containing the SSHConfig + host_keys.",
    )
    g_shell = shell_parser.add_mutually_exclusive_group()
    g_shell.add_argument(
        "--vault-role-name",
        default="amoebius-admin-role",
        help="Name of a Vault K8s auth role (mutually exclusive with --vault-token).",
    )
    g_shell.add_argument(
        "--vault-token",
        default=None,
        help="Direct Vault token (mutually exclusive with --vault-role-name).",
    )
    shell_parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault server address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    shell_parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help="Path to a K8s JWT token if using role-based auth.",
    )
    shell_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault.",
    )

    shell_parser.set_defaults(func=_run_shell)

    args = parser.parse_args()
    try:
        asyncio.run(args.func(args))
    except Exception as exc:
        print(f"SSH CLI error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
