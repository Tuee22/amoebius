#!/usr/bin/env python3
"""
amoebius/cli/secrets/aws.py

Adds a 'store-key-from-csv' subcommand for uploading AWS credentials
(from a CSV file downloaded via the AWS console) into Vault, with
Pydantic validation using AWSApiKey.

Usage example:
  python -m amoebius.cli.secrets.aws store-key-from-csv \
      --csv-file my_aws_creds.csv \
      --path secrets/amoebius/aws_key \
      --vault-role-name amoebius-admin-role

CSV columns typically include exactly two columns:
  "Access key ID", "Secret access key"

We enforce a strict 2×2 CSV shape:
  - Row 0: The column headers (e.g., "Access key ID", "Secret access key")
  - Row 1: The credential values
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import os
from typing import NoReturn

import pandas as pd

from amoebius.models.providers.api_keys.aws import AWSApiKey
from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient


def main() -> NoReturn:
    """
    Entry point for 'store-key-from-csv' subcommand usage.
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.api_keys.aws",
        description="CLI to store AWS credentials in Vault from a CSV file.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    store_csv_parser = subparsers.add_parser(
        "store-key-from-csv",
        help="Parse an AWS credentials CSV file and store in Vault with AWSApiKey validation.",
    )

    store_csv_parser.add_argument(
        "--csv-file",
        required=True,
        help="Path to the AWS credentials CSV (with 'Access key ID' and 'Secret access key').",
    )
    store_csv_parser.add_argument(
        "--path",
        required=True,
        help="Vault path to write the JSON data (e.g. 'secrets/amoebius/aws_key').",
    )

    # Vault auth arguments (mirroring vault.py style)
    group = store_csv_parser.add_mutually_exclusive_group()
    group.add_argument(
        "--vault-role-name",
        help="Vault K8s auth role name (mutually exclusive with --vault-token).",
    )
    group.add_argument(
        "--vault-token",
        help="A direct Vault token (mutually exclusive with --vault-role-name).",
    )
    store_csv_parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    store_csv_parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help="Path to JWT token for K8s auth (default: /var/run/secrets/kubernetes.io/serviceaccount/token).",
    )
    store_csv_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification (default: verify).",
    )

    store_csv_parser.set_defaults(func=_store_key_from_csv)

    args = parser.parse_args()

    try:
        asyncio.run(args.func(args))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    else:
        sys.exit(0)


async def _store_key_from_csv(args: argparse.Namespace) -> None:
    """
    Parse a CSV file of AWS credentials into an AWSApiKey, then directly call
    write_secret(...) on an AsyncVaultClient using that data.
    """
    # 1) Parse/validate CSV into a Pydantic model
    aws_api_key = _parse_aws_csv(csv_file_path=args.csv_file)

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
        await client.write_secret_idempotent(args.path, aws_api_key.model_dump())


def _parse_aws_csv(csv_file_path: str) -> AWSApiKey:
    """
    Reads the CSV with pandas (header=None) and enforces a strict 2×2 shape:
      - Row 0: Headers ("Access key ID", "Secret access key")
      - Row 1: Values (the actual credentials)

    Then constructs an AWSApiKey with access_key_id and secret_access_key.

    Raises ValueError if:
      - The file isn't found
      - The DataFrame isn't exactly 2×2
      - Required headers are missing
    """
    if not os.path.isfile(csv_file_path):
        raise ValueError(f"CSV file not found: {csv_file_path}")

    # Read with no header, so the first row is row 0, second row is row 1
    df = pd.read_csv(csv_file_path, header=None)

    # Must be exactly 2x2
    if df.shape != (2, 2):
        raise ValueError(f"Expected CSV to be 2×2, but got shape {df.shape}.")

    # Create a Series where row 0 is the index, row 1 is the data
    series = df.iloc[1].copy()
    # Convert the first row into a pandas.Index
    series.index = pd.Index(df.iloc[0].to_list())

    # Construct and return the AWSApiKey
    return AWSApiKey(
        access_key_id=str(series["Access key ID"]),
        secret_access_key=str(series["Secret access key"]),
    )


if __name__ == "__main__":
    main()
