"""
amoebius/cli/secrets/vault.py

A CLI wrapper around amoebius.secrets.vault_client.AsyncVaultClient
exposing basic Vault operations:
  - read_secret
  - write_secret_idempotent
  - list_secrets
  - delete_secret

Optionally, it supports Pydantic validation for the JSON
passed to write_secret_idempotent.
"""

from __future__ import annotations

import argparse
import asyncio
import importlib
import json
import sys
from typing import Any, Dict, Optional, Type

from pydantic import BaseModel

from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient

# If you'd like to use your custom validator for other purposes:
# from amoebius.models.validator import validate_type


async def run_read(args: argparse.Namespace) -> None:
    """
    Read a secret from Vault at a given path and print it as JSON.

    Args:
        args (argparse.Namespace):
            - vault_role_name (str): The Vault K8s auth role name used for login.
            - path (str): The Vault path of the secret to read.
            - no_verify_ssl (bool): If True, disables SSL certificate verification.

    Raises:
        SystemExit: If reading the secret fails for any reason, prints an error and exits.
    """
    vault_settings = VaultSettings(
        vault_role_name=args.vault_role_name,
        verify_ssl=not args.no_verify_ssl,
    )

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            data = await vault.read_secret(args.path)
        except RuntimeError as exc:
            print(
                f"Error: could not read secret at '{args.path}': {exc}", file=sys.stderr
            )
            sys.exit(1)

    # Print as pretty-printed JSON
    print(json.dumps(data, indent=2))


async def run_write_idempotent(args: argparse.Namespace) -> None:
    """
    Write JSON data to Vault using an idempotent approach (only writes if the data differs).

    Optionally validate the JSON data with a user-specified Pydantic model.

    Args:
        args (argparse.Namespace):
            - vault_role_name (str): The Vault K8s auth role name used for login.
            - path (str): The Vault path at which to write the JSON data.
            - json_file (Optional[str]): If provided, the path to a JSON file to load.
              If omitted, JSON is read from stdin.
            - pydantic_model (Optional[str]): A dotted path to a Pydantic model
              (e.g. 'my_pkg.my_mod.MyModel') for JSON validation.
            - no_verify_ssl (bool): If True, disables SSL certificate verification.

    Raises:
        SystemExit: If JSON parsing fails, validation fails, or Vault write fails.
    """
    vault_settings = VaultSettings(
        vault_role_name=args.vault_role_name,
        verify_ssl=not args.no_verify_ssl,
    )

    # Load JSON from either --json-file or stdin
    if args.json_file:
        try:
            with open(args.json_file, "r", encoding="utf-8") as f:
                raw_data = json.load(f)
        except (OSError, ValueError) as exc:
            print(
                f"Error: failed to read or parse JSON file '{args.json_file}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        # Read from stdin
        try:
            raw_data = json.load(sys.stdin)
        except ValueError as exc:
            print(f"Error: failed to parse JSON from stdin: {exc}", file=sys.stderr)
            sys.exit(1)

    # Optionally validate with a user-provided pydantic model
    validated_data: Dict[str, Any] = {}
    if args.pydantic_model:
        try:
            model_cls = _load_pydantic_model(args.pydantic_model)
        except (ImportError, AttributeError, ValueError, TypeError) as exc:
            print(
                f"Error: could not load pydantic model '{args.pydantic_model}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)
        try:
            obj = model_cls(**raw_data)  # Validate
            validated_data = obj.dict()
        except Exception as exc:
            print(f"Error: pydantic validation failed: {exc}", file=sys.stderr)
            sys.exit(1)
    else:
        # No validation
        validated_data = raw_data

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            result = await vault.write_secret_idempotent(args.path, validated_data)
        except RuntimeError as exc:
            print(
                f"Error: could not write (idempotent) to Vault at '{args.path}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)

    # If result is non-empty, a new version was created
    if result:
        print(f"Secret updated at path: {args.path}")
    else:
        print(f"No changes (secret data identical) at path: {args.path}")


async def run_list(args: argparse.Namespace) -> None:
    """
    List child keys under a Vault path (KV v2) and print them one per line.

    Args:
        args (argparse.Namespace):
            - vault_role_name (str): The Vault K8s auth role name used for login.
            - path (str): The Vault path prefix (often ends with a slash).
            - no_verify_ssl (bool): If True, disables SSL certificate verification.

    Raises:
        SystemExit: If listing fails (e.g., permission or connectivity issue).
    """
    vault_settings = VaultSettings(
        vault_role_name=args.vault_role_name,
        verify_ssl=not args.no_verify_ssl,
    )

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            keys = await vault.list_secrets(args.path)
        except RuntimeError as exc:
            print(
                f"Error: could not list secrets under '{args.path}': {exc}",
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
    Delete a secret from Vault. By default, performs a soft-delete (keeps version history).
    Use --hard-delete to remove the entire version history.

    Args:
        args (argparse.Namespace):
            - vault_role_name (str): The Vault K8s auth role name used for login.
            - path (str): The Vault path of the secret to delete.
            - hard_delete (bool): If True, performs a hard-delete (removes all versions).
            - no_verify_ssl (bool): If True, disables SSL certificate verification.

    Raises:
        SystemExit: If deletion fails.
    """
    vault_settings = VaultSettings(
        vault_role_name=args.vault_role_name,
        verify_ssl=not args.no_verify_ssl,
    )

    async with AsyncVaultClient(vault_settings) as vault:
        try:
            await vault.delete_secret(args.path, hard=args.hard_delete)
        except RuntimeError as exc:
            print(
                f"Error: could not delete secret at '{args.path}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)

    if args.hard_delete:
        print(f"Successfully hard-deleted secret at path: {args.path}")
    else:
        print(f"Successfully soft-deleted secret at path: {args.path}")


def _load_pydantic_model(dotted_path: str) -> Type[BaseModel]:
    """
    Dynamically import a Pydantic model from a dotted path string.

    Examples:
        "my_package.my_module.MyModel"
        "amoebius.secrets.APIKeys.aws.AWSApiKey"

    Args:
        dotted_path: The dotted path to the Pydantic model.

    Returns:
        The Pydantic model class (Type[BaseModel]).

    Raises:
        ValueError: If the dotted path is invalid or the resolved class is not a subclass of BaseModel.
        ImportError: If the module cannot be imported.
        AttributeError: If the class name is not found in the imported module.
        TypeError: If the retrieved object is not a class.
    """
    module_name, _, class_name = dotted_path.rpartition(".")
    if not module_name or not class_name:
        raise ValueError(f"Invalid dotted path for model: '{dotted_path}'")

    mod = importlib.import_module(module_name)
    candidate_obj = getattr(mod, class_name, None)
    if candidate_obj is None:
        raise AttributeError(f"No attribute '{class_name}' in module '{module_name}'.")

    if not isinstance(candidate_obj, type):
        raise TypeError(f"'{class_name}' is not a class.")

    if not issubclass(candidate_obj, BaseModel):
        raise ValueError(
            f"Class '{class_name}' is not a subclass of pydantic.BaseModel."
        )

    return candidate_obj


def main() -> None:
    """
    CLI entry point to manage generic Vault secrets.

    Supported Subcommands:
      - read: Read a secret and print JSON.
      - write-idempotent: Write JSON data to Vault if it differs, optionally with Pydantic validation.
      - list: List child secrets/keys under a given path.
      - delete: Delete a secret (soft or hard delete).

    Examples:
        # 1) Read a secret and print JSON
        python -m amoebius.cli.secrets.vault read \\
            --vault-role-name my_role \\
            --path secrets/data/my_secret

        # 2) Write a secret only if it differs, reading JSON from stdin
        echo '{"foo": "bar"}' | python -m amoebius.cli.secrets.vault write-idempotent \\
            --vault-role-name my_role \\
            --path secrets/data/my_secret

        # 3) Write a secret, validating JSON with a Pydantic model
        echo '{"access_key_id": "...", "secret_access_key": "..."}' | python -m amoebius.cli.secrets.vault write-idempotent \\
            --vault-role-name my_role \\
            --path secrets/data/aws_key \\
            --pydantic-model amoebius.secrets.APIKeys.aws.AWSApiKey

        # 4) List secrets under a path
        python -m amoebius.cli.secrets.vault list \\
            --vault-role-name my_role \\
            --path secrets/data/

        # 5) Delete a secret (soft delete)
        python -m amoebius.cli.secrets.vault delete \\
            --vault-role-name my_role \\
            --path secrets/data/my_secret

        # 6) Delete a secret (hard delete)
        python -m amoebius.cli.secrets.vault delete \\
            --vault-role-name my_role \\
            --path secrets/data/my_secret \\
            --hard-delete
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.secrets.vault",
        description="CLI for basic Vault secret operations (read, write-idempotent, list, delete).",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # read subcommand
    read_parser = subparsers.add_parser(
        "read",
        help="Read a secret from Vault at the given path and print JSON to stdout.",
    )
    read_parser.add_argument(
        "--vault-role-name", required=True, help="Vault K8s auth role name."
    )
    read_parser.add_argument(
        "--path", required=True, help="Vault path of the secret to read."
    )
    read_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault (default: verify).",
    )

    # write-idempotent subcommand
    write_parser = subparsers.add_parser(
        "write-idempotent",
        help="Write JSON data to Vault if it differs from existing data. "
        "Optionally validate with a Pydantic model.",
    )
    write_parser.add_argument(
        "--vault-role-name", required=True, help="Vault K8s auth role name."
    )
    write_parser.add_argument(
        "--path", required=True, help="Vault path at which to write the JSON data."
    )
    write_parser.add_argument(
        "--json-file",
        help="Path to JSON file. If omitted, JSON is read from stdin.",
    )
    write_parser.add_argument(
        "--pydantic-model",
        help="Dotted path to a Pydantic model (e.g. 'my_pkg.my_mod.MyModel') for JSON validation. Optional.",
    )
    write_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault (default: verify).",
    )

    # list subcommand
    list_parser = subparsers.add_parser(
        "list",
        help="List child secrets/keys under a given Vault path.",
    )
    list_parser.add_argument(
        "--vault-role-name", required=True, help="Vault K8s auth role name."
    )
    list_parser.add_argument(
        "--path", required=True, help="Vault path prefix (usually ends with a slash)."
    )
    list_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault (default: verify).",
    )

    # delete subcommand
    delete_parser = subparsers.add_parser(
        "delete",
        help="Delete a secret from Vault (soft delete by default, --hard-delete to remove all versions).",
    )
    delete_parser.add_argument(
        "--vault-role-name", required=True, help="Vault K8s auth role name."
    )
    delete_parser.add_argument(
        "--path", required=True, help="Vault path of the secret to delete."
    )
    delete_parser.add_argument(
        "--hard-delete",
        action="store_true",
        default=False,
        help="Perform a hard delete (remove all version history).",
    )
    delete_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL certificate verification for Vault (default: verify).",
    )

    args = parser.parse_args()

    if args.command == "read":
        asyncio.run(run_read(args))
    elif args.command == "write-idempotent":
        asyncio.run(run_write_idempotent(args))
    elif args.command == "list":
        asyncio.run(run_list(args))
    elif args.command == "delete":
        asyncio.run(run_delete(args))
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
