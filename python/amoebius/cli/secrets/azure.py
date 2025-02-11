#!/usr/bin/env python3
"""
amoebius/cli/secrets/azure.py

Adds a 'store-key-from-json' subcommand for uploading an Azure Service Principal
JSON key (downloaded manually) into Vault, using Pydantic validation (AzureServicePrincipal).

Usage example:
  python -m amoebius.cli.secrets.azure store-key-from-json \
      --json-file my_azure_sp_key.json \
      --path secrets/amoebius/azure_key \
      --vault-role-name amoebius-admin-role
"""

import argparse
import asyncio
import sys
import os
import json
from typing import NoReturn
from pydantic import ValidationError

from amoebius.models.api_keys.azure import AzureCredentials
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient


def main() -> NoReturn:
    """
    Entry point for 'store-key-from-json' subcommand usage.
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.azure",
        description="CLI to store Azure SP JSON key in Vault with validation.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    store_json_parser = subparsers.add_parser(
        "store-key-from-json",
        help="Parse an Azure SP JSON file and store in Vault with AzureServicePrincipal validation.",
    )
    store_json_parser.add_argument(
        "--json-file",
        required=True,
        help="Path to the Azure SP JSON key file.",
    )
    store_json_parser.add_argument(
        "--path",
        required=True,
        help="Vault path to write the JSON data (e.g. 'secrets/amoebius/azure_key').",
    )

    group = store_json_parser.add_mutually_exclusive_group()
    group.add_argument(
        "--vault-role-name",
        help="Vault K8s auth role name (mutually exclusive with --vault-token).",
    )
    group.add_argument(
        "--vault-token",
        help="A direct Vault token (mutually exclusive with --vault-role-name).",
    )
    store_json_parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    store_json_parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help=(
            "Path to JWT token for K8s auth (default: "
            "/var/run/secrets/kubernetes.io/serviceaccount/token)."
        ),
    )
    store_json_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification (default: verify).",
    )

    store_json_parser.set_defaults(func=_store_key_from_json)

    args = parser.parse_args()

    try:
        asyncio.run(args.func(args))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    else:
        sys.exit(0)


async def _store_key_from_json(args: argparse.Namespace) -> None:
    """
    Parse an Azure Service Principal JSON file into AzureServicePrincipal, then store it in Vault.
    """
    azure_key = _parse_azure_sp_json(json_file_path=args.json_file)

    vault_settings = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
        token_path=args.vault_token_path,
        verify_ssl=(not args.no_verify_ssl),
    )

    async with AsyncVaultClient(vault_settings) as client:
        await client.write_secret_idempotent(args.path, azure_key.model_dump())


def _parse_azure_sp_json(json_file_path: str) -> AzureCredentials:
    """
    Reads the provided JSON file and validates it against AzureServicePrincipal.
    """
    if not os.path.isfile(json_file_path):
        raise ValueError(f"JSON file not found: {json_file_path}")

    with open(json_file_path, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    try:
        return AzureCredentials(
            client_id=raw_data["ARM_CLIENT_ID"],
            client_secret=raw_data["ARM_CLIENT_SECRET"],
            tenant_id=raw_data["ARM_TENANT_ID"],
            subscription_id=raw_data["ARM_SUBSCRIPTION_ID"],
        )
    except ValidationError as exc:
        raise ValueError(f"Invalid Azure SP JSON file: {exc}") from exc


if __name__ == "__main__":
    main()
