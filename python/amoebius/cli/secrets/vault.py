#!/usr/bin/env python3
"""
amoebius/cli/secrets/vault.py

CLI for basic Vault secret operations:
  - read
  - write-idempotent
  - list
  - delete
  - unseal

The unseal command calls `init_unseal_configure_vault()` from `amoebius.secrets.vault_unseal`.
"""

from __future__ import annotations

import argparse
import asyncio
import importlib
import json
import sys
from typing import (
    Any,
    Callable,
    Coroutine,
    Dict,
    List,
    Optional,
    Type,
    TypedDict,
)

from pydantic import BaseModel

from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.vault_unseal import init_unseal_configure_vault

# Import your validator
from amoebius.models.validator import validate_type


#
# Typed result from the write_secret_idempotent(...) call
#
class WriteIdempotentResult(TypedDict):
    """
    Represents the expected structure from vault.write_secret_idempotent().
    Here we only require a 'changed' key that is a bool.

    If your actual return structure has more fields, add them here.
    """

    changed: bool


#
# Subcommand handlers
#
async def run_read(args: argparse.Namespace) -> None:
    """
    Read a secret from Vault at a given path and print JSON.

    Raises SystemExit on error.
    """
    vault_settings: VaultSettings = _build_vault_settings(args)
    async with AsyncVaultClient(vault_settings) as vault:
        try:
            data: Dict[str, Any] = await vault.read_secret(args.path)
        except RuntimeError as exc:
            print(f"Error: cannot read secret at '{args.path}': {exc}", file=sys.stderr)
            sys.exit(1)
    print(json.dumps(data, indent=2))


async def run_write_idempotent(args: argparse.Namespace) -> None:
    """
    Idempotently write JSON data to Vault; optionally validate with a pydantic model.

    Raises SystemExit on error.
    """
    vault_settings: VaultSettings = _build_vault_settings(args)

    # Load JSON (from --json-file or stdin)
    if args.json_file:
        try:
            with open(args.json_file, "r", encoding="utf-8") as f:
                raw_data = json.load(f)
        except (OSError, ValueError) as exc:
            print(
                f"Error reading/parsing file '{args.json_file}': {exc}", file=sys.stderr
            )
            sys.exit(1)
    else:
        try:
            raw_data = json.load(sys.stdin)
        except ValueError as exc:
            print(f"Error parsing JSON from stdin: {exc}", file=sys.stderr)
            sys.exit(1)

    # Optional validation
    data_for_vault: Dict[str, Any]
    if args.pydantic_model:
        try:
            model_cls: Type[BaseModel] = _load_pydantic_model(args.pydantic_model)
        except (ImportError, AttributeError, ValueError, TypeError) as exc:
            print(
                f"Error loading pydantic model '{args.pydantic_model}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)
        try:
            obj = model_cls(**raw_data)
            data_for_vault = obj.model_dump()
        except Exception as exc:
            print(f"Validation failed: {exc}", file=sys.stderr)
            sys.exit(1)
    else:
        data_for_vault = raw_data

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            raw_result: Dict[str, Any] = await vault.write_secret_idempotent(
                args.path, data_for_vault
            )
            # Validate the raw_result dict to ensure it matches WriteIdempotentResult
            write_result: WriteIdempotentResult = validate_type(
                raw_result,
                WriteIdempotentResult,
            )
        except RuntimeError as exc:
            print(
                f"Error: cannot write idempotently to '{args.path}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)
        except ValueError as exc:
            # This handles a mismatch between raw_result and WriteIdempotentResult
            print(f"Validation error for WriteIdempotentResult: {exc}", file=sys.stderr)
            sys.exit(1)

    # Check the 'changed' field rather than just using truthiness
    if write_result["changed"]:
        print(f"Secret updated at path: {args.path}")
    else:
        print(f"No changes (identical data) at path: {args.path}")


async def run_list(args: argparse.Namespace) -> None:
    """
    List child keys under a given Vault path prefix.

    Raises SystemExit on error.
    """
    vault_settings: VaultSettings = _build_vault_settings(args)
    async with AsyncVaultClient(vault_settings) as vault:
        try:
            keys: List[str] = await vault.list_secrets(args.path)
        except RuntimeError as exc:
            print(
                f"Error: cannot list secrets under '{args.path}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)

    if keys:
        for k in keys:
            print(k)
    else:
        print(f"No secrets found under path: {args.path}")


async def run_delete(args: argparse.Namespace) -> None:
    """
    Delete a secret from Vault. --hard-delete removes all version history.

    Raises SystemExit on error.
    """
    vault_settings: VaultSettings = _build_vault_settings(args)
    async with AsyncVaultClient(vault_settings) as vault:
        try:
            await vault.delete_secret(args.path, hard=args.hard_delete)
        except RuntimeError as exc:
            print(f"Error deleting secret '{args.path}': {exc}", file=sys.stderr)
            sys.exit(1)

    if args.hard_delete:
        print(f"Hard-deleted secret at '{args.path}'")
    else:
        print(f"Soft-deleted secret at '{args.path}'")


async def run_unseal(args: argparse.Namespace) -> None:
    """
    Runs init_unseal_configure_vault() to initialize, unseal, and configure Vault.
    """
    try:
        await init_unseal_configure_vault(
            default_shamir_shares=args.default_shamir_shares,
            default_shamir_threshold=args.default_shamir_threshold,
            user_supplied_password=args.user_supplied_password,
        )
        print("Vault unseal and configuration complete.")
    except Exception as exc:
        print(f"Error unsealing Vault: {exc}", file=sys.stderr)
        sys.exit(1)


#
# Helpers
#
def _build_vault_settings(args: argparse.Namespace) -> VaultSettings:
    """
    Construct a VaultSettings object from CLI arguments.

    Exits with error if both --vault-token and --vault-role-name are used.
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


def _load_pydantic_model(dotted_path: str) -> Type[BaseModel]:
    """
    Dynamically load a Pydantic model from dotted path, e.g. "my_mod.MyModel".
    """
    module_name, _, class_name = dotted_path.rpartition(".")
    if not module_name or not class_name:
        raise ValueError(f"Invalid dotted path: '{dotted_path}'")

    mod = importlib.import_module(module_name)
    candidate = getattr(mod, class_name, None)
    if candidate is None:
        raise AttributeError(f"No attribute '{class_name}' in {module_name}.")

    if not isinstance(candidate, type):
        raise TypeError(f"'{class_name}' is not a class.")
    if not issubclass(candidate, BaseModel):
        raise ValueError(f"'{class_name}' is not a subclass of pydantic.BaseModel.")

    return candidate


def main() -> None:
    """
    CLI entry point for Vault secret operations:
      - read
      - write-idempotent
      - list
      - delete
      - unseal
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.vault",
        description=(
            "CLI for basic Vault secret operations (read, write-idempotent, list, delete), "
            "plus a subcommand to unseal Vault."
        ),
    )

    subparsers = parser.add_subparsers(
        dest="command",
        required=True,
        help="Sub-command to run. Use -h/--help after a subcommand for more usage details.",
    )

    #
    # read
    #
    read_parser = subparsers.add_parser("read", help="Read a secret from Vault.")
    _add_vault_cli_args(read_parser)
    read_parser.add_argument("--path", required=True, help="Vault path to read.")
    read_parser.set_defaults(func=run_read)

    #
    # write-idempotent
    #
    write_parser = subparsers.add_parser(
        "write-idempotent",
        help=(
            "Write JSON data to Vault if it differs from existing data. "
            "Optionally validate via a Pydantic model."
        ),
    )
    _add_vault_cli_args(write_parser)
    write_parser.add_argument("--path", required=True, help="Vault path to write to.")
    write_parser.add_argument("--json-file", help="JSON file to load instead of stdin.")
    write_parser.add_argument(
        "--pydantic-model",
        help="Dotted path to a pydantic model (e.g. 'my_module.MyModel').",
    )
    write_parser.set_defaults(func=run_write_idempotent)

    #
    # list
    #
    list_parser = subparsers.add_parser("list", help="List child keys under a path.")
    _add_vault_cli_args(list_parser)
    list_parser.add_argument(
        "--path",
        required=True,
        help="Vault prefix path (should end with a slash, e.g. 'secret/').",
    )
    list_parser.set_defaults(func=run_list)

    #
    # delete
    #
    delete_parser = subparsers.add_parser(
        "delete",
        help="Delete a secret from Vault (soft by default, use --hard-delete to remove all versions).",
    )
    _add_vault_cli_args(delete_parser)
    delete_parser.add_argument("--path", required=True, help="Vault path to delete.")
    delete_parser.add_argument(
        "--hard-delete",
        action="store_true",
        default=False,
        help="Remove all version history if True.",
    )
    delete_parser.set_defaults(func=run_delete)

    #
    # unseal (NEW)
    #
    unseal_parser = subparsers.add_parser(
        "unseal",
        help=(
            "Initialize, unseal, and configure Vault (does not require standard Vault args). "
            "Calls init_unseal_configure_vault() internally."
        ),
    )
    # No vault CLI args for unseal
    unseal_parser.add_argument(
        "--default-shamir-shares",
        type=int,
        default=5,
        help="Number of unseal key shares if Vault needs initialization. (default: 5)",
    )
    unseal_parser.add_argument(
        "--default-shamir-threshold",
        type=int,
        default=3,
        help="Number of keys required to unseal if Vault needs initialization. (default: 3)",
    )
    unseal_parser.add_argument(
        "--user-supplied-password",
        type=str,
        default=None,
        help=(
            "Optional password for encrypt/decrypt of Vault init data. "
            "If omitted, the CLI will prompt."
        ),
    )
    unseal_parser.set_defaults(func=run_unseal)

    #
    # Parse + run
    #
    args = parser.parse_args()

    # The `args.func` is an async function, so we run it via asyncio
    func: Callable[[argparse.Namespace], Coroutine[Any, Any, None]] = args.func
    asyncio.run(func(args))


def _add_vault_cli_args(subparser: argparse.ArgumentParser) -> None:
    """
    Add Vault-related arguments to each subcommand parser,
    supporting either K8s auth or direct token.
    """
    group = subparser.add_mutually_exclusive_group()
    group.add_argument(
        "--vault-role-name",
        help="Vault K8s auth role name (mutually exclusive with --vault-token).",
        default="amoebius-admin-role",
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
        help=(
            "Path to JWT token for K8s auth. "
            "(default: /var/run/secrets/kubernetes.io/serviceaccount/token)."
        ),
    )
    subparser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification (default: verify SSL).",
    )


if __name__ == "__main__":
    main()
