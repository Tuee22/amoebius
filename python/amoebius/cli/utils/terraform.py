#!/usr/bin/env python3
"""
amoebius/cli/utils/terraform.py

CLI offering two subcommands for Minio-based Terraform backends:

  1) "show": Retrieve and display JSON Terraform state for a root/workspace.
  2) "list": Enumerate all stored backends, optionally removing empty ones first.
"""

from __future__ import annotations
import argparse
import asyncio
import json
import sys
from typing import Any, Dict

from amoebius.models.terraform import TerraformBackendRef, TerraformState
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.minio import get_minio_client
from amoebius.utils.terraform.commands import (
    read_terraform_state,
    list_minio_backends,
)
from amoebius.utils.terraform.storage import MinioStorage, StateStorage


async def _run_show(args: argparse.Namespace) -> None:
    """Handle the 'show' subcommand to fetch and print Terraform state."""

    if args.vault_token and args.vault_role_name:
        print(
            "Error: --vault-token and --vault-role-name are mutually exclusive.",
            file=sys.stderr,
        )
        sys.exit(1)

    vault_settings = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
        token_path=args.vault_token_path,
        verify_ssl=not args.no_verify_ssl,
    )

    # Build a TerraformBackendRef from user args
    try:
        ref = TerraformBackendRef(root=args.root_name, workspace=args.workspace)
    except ValueError as exc:
        print(f"Invalid root/workspace: {exc}", file=sys.stderr)
        sys.exit(1)

    async with AsyncVaultClient(vault_settings) as vault_client:
        try:
            minio_client = await get_minio_client(
                vault_client=vault_client,
                vault_path=args.minio_vault_path,
            )
        except Exception as exc:
            print(f"Failed to retrieve Minio client: {exc}", file=sys.stderr)
            sys.exit(1)

        # Construct a MinioStorage referencing 'amoebius' as the bucket, for ephemeral usage if needed
        storage: StateStorage = MinioStorage(
            ref=ref,
            bucket_name="amoebius",
            transit_key_name="amoebius",
            minio_client=minio_client,
        )

        try:
            tf_state = await read_terraform_state(
                ref=ref,
                storage=storage,
                vault_client=vault_client,
                minio_client=minio_client,
                retries=args.retries,
            )
        except Exception as exc:
            print(f"ERROR: Failed to read Terraform state: {exc}", file=sys.stderr)
            sys.exit(1)

    state_dict: Dict[str, Any] = tf_state.model_dump()
    print(json.dumps(state_dict, indent=2))


async def _run_list(args: argparse.Namespace) -> None:
    """Handle the 'list' subcommand to enumerate Minio-based Terraform backends."""

    if args.vault_token and args.vault_role_name:
        print(
            "Error: --vault-token and --vault-role-name are mutually exclusive.",
            file=sys.stderr,
        )
        sys.exit(1)

    vault_settings = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
        token_path=args.vault_token_path,
        verify_ssl=not args.no_verify_ssl,
    )

    async with AsyncVaultClient(vault_settings) as vault_client:
        try:
            minio_client = await get_minio_client(
                vault_client=vault_client,
                vault_path=args.minio_vault_path,
            )
        except Exception as exc:
            print(f"Failed to retrieve Minio client: {exc}", file=sys.stderr)
            sys.exit(1)

        delete_empty = not args.no_delete_empty
        backends = await list_minio_backends(
            vault_client=vault_client,
            minio_client=minio_client,
            delete_empty_backends=delete_empty,
        )

    if not backends:
        print("No Terraform backends found.")
        return

    # Each backend is a TerraformBackendRef => we print root + workspace
    for ref in backends:
        print(f"Root: {ref.root} | Workspace: {ref.workspace}")


def main() -> None:
    """CLI entry point for managing Minio-based Terraform backends (show/list)."""
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.utils.terraform",
        description="CLI for retrieving or listing Minio-based Terraform states.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # "show" subcommand
    show_parser = subparsers.add_parser(
        "show", help="Retrieve and print a specific Terraform state from Minio."
    )
    show_parser.add_argument(
        "--root-name",
        required=True,
        help="Terraform root module path (e.g., 'providers/aws').",
    )
    show_parser.add_argument(
        "--workspace",
        default="default",
        help="Terraform workspace name (default: 'default').",
    )
    g_show = show_parser.add_mutually_exclusive_group()
    g_show.add_argument(
        "--vault-role-name",
        default="amoebius-admin-role",
        help="Name of a Vault K8s auth role (mutually exclusive with --vault-token).",
    )
    g_show.add_argument(
        "--vault-token",
        default=None,
        help="Direct Vault token (mutually exclusive with --vault-role-name).",
    )
    show_parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault server address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    show_parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help="Path to a K8s JWT token if using role-based auth.",
    )
    show_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault.",
    )
    show_parser.add_argument(
        "--minio-vault-path",
        default="amoebius/services/minio/root",
        help="Vault path storing Minio credentials (default: amoebius/services/minio/root).",
    )
    show_parser.add_argument(
        "--retries",
        type=int,
        default=0,
        help="Number of retries for reading the Terraform state.",
    )
    show_parser.set_defaults(func=_run_show)

    # "list" subcommand
    list_parser = subparsers.add_parser(
        "list",
        help="List all Minio-based Terraform backends, optionally removing empty ones.",
    )
    g_list = list_parser.add_mutually_exclusive_group()
    g_list.add_argument(
        "--vault-role-name",
        default="amoebius-admin-role",
        help="Name of a Vault K8s auth role (mutually exclusive with --vault-token).",
    )
    g_list.add_argument(
        "--vault-token",
        default=None,
        help="Direct Vault token (mutually exclusive with --vault-role-name).",
    )
    list_parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault server address.",
    )
    list_parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help="Path to a K8s JWT token if using role-based auth.",
    )
    list_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification (default: verify).",
    )
    list_parser.add_argument(
        "--minio-vault-path",
        default="amoebius/services/minio/root",
        help="Vault path storing Minio credentials (default: amoebius/services/minio/root).",
    )
    list_parser.add_argument(
        "--no-delete-empty",
        action="store_true",
        default=False,
        help="If set, do not remove empty backends before listing.",
    )
    list_parser.set_defaults(func=_run_list)

    args = parser.parse_args()
    asyncio.run(args.func(args))


if __name__ == "__main__":
    main()
