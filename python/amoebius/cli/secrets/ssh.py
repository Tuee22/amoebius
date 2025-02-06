# ameobius/cli/secrets/ssh.py

from __future__ import annotations

import argparse
import asyncio
import sys
from typing import NoReturn

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
    Handle the 'store' subcommand:
      1. Store an SSHConfig (no host_keys) in Vault.
      2. Attempt TOFU population immediately.
      3. If TOFU fails, hard-delete the secret and exit with error.
    """
    ssh_config = SSHConfig(
        user=args.user,
        hostname=args.hostname,
        port=args.port,
        private_key=args.private_key,
        host_keys=None,  # We do not allow specifying host keys via CLI
    )

    vault_settings = VaultSettings(
        vault_role_name=args.vault_role_name, verify_ssl=not args.no_verify_ssl
    )

    async with AsyncVaultClient(vault_settings) as vault:
        # Step 1: Store the config
        await store_ssh_config(
            vault=vault,
            path=args.path,
            config=ssh_config,
            # set_expiry_if_no_keys=True by default
        )

        # Step 2: Attempt TOFU
        try:
            await tofu_populate_ssh_config(vault=vault, path=args.path)
        except Exception as exc:
            # Step 3: If TOFU fails, remove the newly created secret (hard delete)
            print(
                f"Error: TOFU population failed: {exc}\n"
                "Deleting the newly stored SSH config from Vault...",
                file=sys.stderr,
            )
            await delete_ssh_config(vault=vault, path=args.path, hard_delete=True)
            sys.exit(1)

    print(
        f"Successfully stored SSH config and performed TOFU at Vault path: {args.path}"
    )


async def run_delete(args: argparse.Namespace) -> None:
    """
    Handle the 'delete' subcommand: always perform a hard delete
    on the given Vault path.
    """
    vault_settings = VaultSettings(
        vault_role_name=args.vault_role_name, verify_ssl=not args.no_verify_ssl
    )

    async with AsyncVaultClient(vault_settings) as vault:
        await delete_ssh_config(
            vault=vault,
            path=args.path,
            hard_delete=True,  # Enforced hard delete
        )
    print(f"Successfully hard-deleted SSH config at Vault path: {args.path}")


def main() -> None:
    """
    CLI entry point for storing or deleting SSH configurations in Vault.

    Examples:

      - To store an SSH config (inline private key) and do immediate TOFU:
        python -m ameobius.cli.secrets.ssh store \
            --vault-role-name my_vault_role \
            --path secrets/ssh/my_server \
            --user myuser \
            --hostname myhost.com \
            --port 22 \
            --private-key "-----BEGIN PRIVATE KEY-----\n..."

      - To delete (hard-delete) the config:
        python -m ameobius.cli.secrets.ssh delete \
            --vault-role-name my_vault_role \
            --path secrets/ssh/my_server
    """
    parser = argparse.ArgumentParser(
        prog="ameobius.cli.secrets.ssh",
        description="CLI to store (with immediate TOFU) or hard-delete SSH configurations in Vault.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # ---- store subcommand ----
    store_parser = subparsers.add_parser(
        "store",
        help="Store an SSH configuration (inline private key) in Vault, then run TOFU.",
    )
    store_parser.add_argument(
        "--vault-role-name", required=True, help="Vault K8s auth role name."
    )
    store_parser.add_argument(
        "--path", required=True, help="Vault path at which to store SSH config."
    )
    store_parser.add_argument("--user", required=True, help="SSH username.")
    store_parser.add_argument(
        "--hostname", required=True, help="SSH server hostname/IP."
    )
    store_parser.add_argument(
        "--port", type=int, default=22, help="SSH server port (default: 22)."
    )
    store_parser.add_argument(
        "--private-key",
        required=True,
        help="Inline private key contents (PEM) to use for SSH authentication.",
    )
    store_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault (default: verify).",
    )

    # ---- delete subcommand ----
    delete_parser = subparsers.add_parser(
        "delete", help="Permanently hard-delete an SSH configuration from Vault."
    )
    delete_parser.add_argument(
        "--vault-role-name", required=True, help="Vault K8s auth role name."
    )
    delete_parser.add_argument(
        "--path", required=True, help="Vault path to hard-delete."
    )
    delete_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault (default: verify).",
    )

    args = parser.parse_args()

    if args.command == "store":
        asyncio.run(run_store(args))
    elif args.command == "delete":
        asyncio.run(run_delete(args))
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
