#!/usr/bin/env python3
"""
amoebius/cli/secrets/gcp.py

Adds a 'store-key-from-json' subcommand for uploading a GCP Service Account
JSON key (downloaded from the GCP console) into Vault, using Pydantic
validation (GCPServiceAccountKey).

Usage example:
  python -m amoebius.cli.secrets.gcp store-key-from-json \
      --json-file my_gcp_sa_key.json \
      --path secrets/amoebius/gcp_key \
      --vault-role-name amoebius-admin-role

The GCP SA JSON typically looks like:
{
  "type": "service_account",
  "project_id": "...",
  "private_key_id": "...",
  "private_key": "...",
  "client_email": "...",
  "client_id": "...",
  "auth_uri": "...",
  "token_uri": "...",
  "auth_provider_x509_cert_url": "...",
  "client_x509_cert_url": "...",
  "universe_domain": "googleapis.com"
}

We parse and validate it with GCPServiceAccountKey, then store it in Vault.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import os
import json
from typing import NoReturn

from pydantic import ValidationError

from amoebius.models.providers.api_keys.gcp import GCPServiceAccountKey
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient


def main() -> NoReturn:
    """
    Entry point for 'store-key-from-json' subcommand usage.
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.gcp",
        description="CLI to store GCP SA JSON key in Vault with validation.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    store_json_parser = subparsers.add_parser(
        "store-key-from-json",
        help="Parse a GCP SA JSON file and store in Vault with GCPServiceAccountKey validation.",
    )

    store_json_parser.add_argument(
        "--json-file",
        required=True,
        help="Path to the GCP SA JSON key file (downloaded from the console).",
    )
    store_json_parser.add_argument(
        "--path",
        required=True,
        help="Vault path to write the JSON data (e.g. 'secrets/amoebius/gcp_key').",
    )

    # Vault auth arguments (similar to your AWS script)
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
    Parse a GCP service account JSON file into a GCPServiceAccountKey, then
    write it to Vault as-is.
    """
    # 1) Parse/validate JSON file
    gcp_key = _parse_gcp_sa_json(json_file_path=args.json_file)

    # 2) Build Vault settings from CLI args
    vault_settings = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
        token_path=args.vault_token_path,
        verify_ssl=(not args.no_verify_ssl),
    )

    # 3) Write the secret to Vault
    async with AsyncVaultClient(vault_settings) as client:
        # We can store the key as a dictionary in Vault
        await client.write_secret_idempotent(args.path, gcp_key.model_dump())


def _parse_gcp_sa_json(json_file_path: str) -> GCPServiceAccountKey:
    """
    Reads the provided JSON file and validates it against GCPServiceAccountKey.
    Raises ValueError or ValidationError if parsing fails.
    """
    if not os.path.isfile(json_file_path):
        raise ValueError(f"JSON file not found: {json_file_path}")

    with open(json_file_path, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    try:
        return GCPServiceAccountKey(**raw_data)
    except ValidationError as exc:
        raise ValueError(f"Invalid GCP SA JSON file: {exc}") from exc


if __name__ == "__main__":
    main()
