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

CSV columns typically include:
  "Access key ID", "Secret access key", and optionally "Session token".
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import os
import sys
import tempfile
from typing import Dict, Optional, Any, List, Mapping, NoReturn

from amoebius.cli.secrets.vault import run_write_idempotent
from amoebius.models.api_keys.aws import AWSApiKey


def main() -> NoReturn:
    """
    Entry point for 'store-key-from-csv' subcommand usage.
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.aws",
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
    Parse a CSV file of AWS credentials into a dict, then call
    run_write_idempotent(...) to store it in Vault with AWSApiKey validation.
    """
    creds_dict = _parse_aws_csv(csv_file_path=args.csv_file)

    # Prepare the JSON in a temporary file for run_write_idempotent
    with tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".json") as tmpf:
        tmp_file_path = tmpf.name
        json.dump(creds_dict, tmpf, indent=2)

    # Construct new argparse.Namespace to pass to run_write_idempotent
    new_args = argparse.Namespace(
        command="write-idempotent",  # Not really used inside run_write_idempotent
        path=args.path,
        json_file=tmp_file_path,
        pydantic_model="amoebius.models.api_keys.aws.AWSApiKey",
        vault_role_name=args.vault_role_name,
        vault_token=args.vault_token,
        vault_addr=args.vault_addr,
        vault_token_path=args.vault_token_path,
        no_verify_ssl=args.no_verify_ssl,
    )

    try:
        await run_write_idempotent(new_args)
    finally:
        if os.path.exists(tmp_file_path):
            os.remove(tmp_file_path)


def _parse_aws_csv(csv_file_path: str) -> Dict[str, Optional[str]]:
    """
    Return a dict matching AWSApiKey fields:
      {
        "access_key_id": ...,
        "secret_access_key": ...,
        "session_token": ...
      }

    We parse the first row that contains valid "Access key ID" and
    "Secret access key". If "Session token" is present and non-empty,
    include it; otherwise it's None.

    Raises ValueError if no row has the required columns.
    """
    if not os.path.isfile(csv_file_path):
        raise ValueError(f"CSV file not found: {csv_file_path}")

    with open(csv_file_path, "r", newline="", encoding="utf-8") as f:
        # Read all rows via comprehension (instead of a for loop)
        rows: List[Mapping[str, str]] = [row for row in csv.DictReader(f)]

    # Use a generator expression to parse each row, yielding either a creds dict or None
    parsed_rows = (_try_parse_row(row) for row in rows)
    # Filter out any None results, then return the first valid dict
    first_valid = next((d for d in parsed_rows if d is not None), None)
    if first_valid is None:
        raise ValueError(
            "No CSV row has valid 'Access key ID' and 'Secret access key'."
        )
    return first_valid


def _try_parse_row(row: Mapping[str, str]) -> Optional[Dict[str, Optional[str]]]:
    """
    Attempt to extract the AWS credential fields from a single CSV row.
    Returns the dict if successful, or None if invalid.
    """
    # Potential column names
    akid_candidates = ["Access key ID", "Access Key ID"]
    sak_candidates = ["Secret access key", "Secret Access Key"]
    st_candidates = ["Session token", "Session Token"]

    # Use generator expressions & next(...) to pick the first non-empty match
    akid_col: str = next(
        (col for col in akid_candidates if col in row and row[col].strip()), ""
    )
    sak_col: str = next(
        (col for col in sak_candidates if col in row and row[col].strip()), ""
    )

    if not akid_col or not sak_col:
        return None

    # Session token is optional
    st_col: Optional[str] = next(
        (col for col in st_candidates if col in row and row[col].strip()), None
    )

    return {
        "access_key_id": row[akid_col].strip(),
        "secret_access_key": row[sak_col].strip(),
        "session_token": row[st_col].strip() if st_col else None,
    }


if __name__ == "__main__":
    main()
