"""
amoebius/cli/secrets/ssh.py

Thin CLI wrapper around the SSH Vault operations. Each CLI function
invokes exactly one function from /amoebius/secrets/ssh.py:

  - `store` subcommand -> calls `store_ssh_config_with_tofu`
  - `delete` subcommand -> calls `delete_ssh_config`
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
    store_ssh_config_with_tofu,
    delete_ssh_config,
)


async def run_store(args: argparse.Namespace) -> None:
    """
    Store an SSHConfig in Vault (with potential TOFU), by calling a single
    function `store_ssh_config_with_tofu`. If TOFU fails, that function
    will do a hard-delete automatically and raise an error.
    """
    vault_settings = _build_vault_settings(args)

    # You can either treat --private-key as a path or inline string.
    # Example: read from a file, or assume it's already the key content.
    try:
        with open(args.private_key, "r", encoding="utf-8") as fpk:
            key_data = fpk.read()
    except OSError:
        # Fall back if it's not a file path; treat as inline
        key_data = args.private_key

    ssh_config = SSHConfig(
        user=args.user,
        hostname=args.hostname,
        port=args.port,
        private_key=key_data,
        host_keys=None,  # We rely on TOFU to populate these
    )

    async with AsyncVaultClient(vault_settings) as vault:
        await store_ssh_config_with_tofu(vault, args.path, ssh_config)

    print(f"Successfully stored SSH config & performed TOFU at '{args.path}'")


async def run_delete(args: argparse.Namespace) -> None:
    """
    Hard-delete an SSH config from Vault by calling a single function:
    `delete_ssh_config`.
    """
    vault_settings = _build_vault_settings(args)
    async with AsyncVaultClient(vault_settings) as vault:
        await delete_ssh_config(vault, args.path, hard_delete=True)
    print(f"Hard-deleted SSH config at '{args.path}'")


def main() -> None:
    """
    CLI entry point for storing or deleting SSH configs in Vault,
    relying on the high-level functions from amoebius.secrets.ssh.
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.ssh",
        description="CLI to store (with TOFU) or hard-delete SSH configs in Vault.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # store
    store_parser = subparsers.add_parser(
        "store",
        help="Store an SSH config in Vault, then run TOFU automatically.",
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
        "--private-key",
        required=True,
        help="Path or inline text for the SSH private key (PEM).",
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
    Add CLI arguments for Vault connectivity:
      - Mutually exclusive: K8s auth role vs direct token
      - Vault address, token path, SSL verification toggles
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
    Build a VaultSettings object from CLI arguments. Enforces mutual exclusivity
    of K8s role vs direct token.
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
