"""
amoebius/cli/secrets/ssh.py

CLI to store (with immediate TOFU) or hard-delete SSH configurations in Vault.
Supports:
  - K8s auth (--vault-role-name), or
  - Direct token (--vault-token).
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from typing import Optional

from amoebius.models.ssh import SSHConfig
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.ssh import (
    store_ssh_config,
    delete_ssh_config,
    tofu_populate_ssh_config,
)


async def run_store(args: argparse.Namespace) -> None:
    """
    Store an SSHConfig in Vault, then run TOFU (if host_keys are missing).

    1) Store SSHConfig
    2) Attempt TOFU
    3) If TOFU fails, hard-delete the secret and exit(1).
    """
    vault_settings = _build_vault_settings(args)
    ssh_config = SSHConfig(
        user=args.user,
        hostname=args.hostname,
        port=args.port,
        private_key=args.private_key,
        host_keys=None,  # Do not allow CLI input of host_keys
    )
    async with AsyncVaultClient(vault_settings) as vault:
        # Step 1: Store
        await store_ssh_config(vault, args.path, ssh_config)

        # Step 2: TOFU
        try:
            await tofu_populate_ssh_config(vault, args.path)
        except Exception as exc:
            print(
                f"Error: TOFU failed for path '{args.path}': {exc}\nRemoving the SSH config...",
                file=sys.stderr,
            )
            await delete_ssh_config(vault, args.path, hard_delete=True)
            sys.exit(1)

    print(f"Successfully stored SSH config & performed TOFU at '{args.path}'")


async def run_delete(args: argparse.Namespace) -> None:
    """
    Permanently (hard) delete an SSH config from Vault.
    """
    vault_settings = _build_vault_settings(args)
    async with AsyncVaultClient(vault_settings) as vault:
        await delete_ssh_config(vault, args.path, hard_delete=True)
    print(f"Hard-deleted SSH config at '{args.path}'")


def main() -> None:
    """
    CLI entry point for storing or deleting SSH configs in Vault.

    Subcommands:
      - store
      - delete

    Examples:
      # Store via K8s auth
      python -m amoebius.cli.secrets.ssh store \
        --vault-role-name my_role \
        --path secrets/ssh/my_server \
        --user ubuntu \
        --hostname 1.2.3.4 \
        --port 22 \
        --private-key /path/to/id_rsa

      # Store via direct token
      python -m amoebius.cli.secrets.ssh store \
        --vault-token s.abcdefg \
        --path secrets/ssh/my_server \
        --user ubuntu \
        --hostname 1.2.3.4 \
        --port 22 \
        --private-key /path/to/id_rsa

      # Delete
      python -m amoebius.cli.secrets.ssh delete \
        --vault-role-name my_role \
        --path secrets/ssh/my_server
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.ssh",
        description="CLI to store (with immediate TOFU) or hard-delete SSH configs in Vault.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # store
    store_parser = subparsers.add_parser(
        "store",
        help="Store an SSH config in Vault, then run TOFU.",
    )
    _add_vault_cli_args(store_parser)
    store_parser.add_argument(
        "--path", required=True, help="Vault path to store SSH config."
    )
    store_parser.add_argument("--user", required=True, help="SSH username.")
    store_parser.add_argument("--hostname", required=True, help="SSH server hostname.")
    store_parser.add_argument(
        "--port", type=int, default=22, help="SSH port (default: 22)."
    )
    store_parser.add_argument(
        "--private-key", required=True, help="Path or inline private key."
    )
    store_parser.set_defaults(func=run_store)

    # delete
    delete_parser = subparsers.add_parser(
        "delete",
        help="Hard-delete an SSH config from Vault.",
    )
    _add_vault_cli_args(delete_parser)
    delete_parser.add_argument(
        "--path", required=True, help="Vault path to hard-delete."
    )
    delete_parser.set_defaults(func=run_delete)

    args = parser.parse_args()
    asyncio.run(args.func(args))


def _add_vault_cli_args(subparser: argparse.ArgumentParser) -> None:
    """
    Add mutually exclusive flags for K8s role vs direct token, plus vault address, token path,
    and SSL verification toggle.
    """
    group = subparser.add_mutually_exclusive_group()
    group.add_argument(
        "--vault-role-name",
        help="Vault K8s auth role name (mutually exclusive with --vault-token).",
    )
    group.add_argument(
        "--vault-token",
        help="Direct Vault token (mutually exclusive with --vault-role-name).",
    )
    subparser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    subparser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help="Path to JWT token for K8s auth (default: /var/run/secrets/kubernetes.io/serviceaccount/token).",
    )
    subparser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        help="Disable SSL certificate verification (default: verify SSL).",
    )


def _build_vault_settings(args: argparse.Namespace) -> VaultSettings:
    """
    Construct a VaultSettings from CLI args, respecting mutual exclusivity and SSL verification.
    """
    if args.vault_token and args.vault_role_name:
        print(
            "Error: --vault-token and --vault-role-name are mutually exclusive.",
            file=sys.stderr,
        )
        sys.exit(1)

    return VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
        token_path=args.vault_token_path,
        verify_ssl=not args.no_verify_ssl,
        renew_threshold_seconds=60.0,
        check_interval_seconds=30.0,
    )


if __name__ == "__main__":
    main()
