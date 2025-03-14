# amoebius/cli/utils/minio.py
"""
This module provides a CLI interface to interact with Minio using credentials
stored in Vault. It supports two main operations (verbs): 'read' and 'list'.

- The 'read' command fetches and prints the contents of a specific object.
- The 'list' command lists the objects in a specified bucket.

If no command is provided, the script will show usage instructions.

Usage Examples:
    python -m amoebius.cli.utils.minio read \
        --bucket my-bucket \
        --object-key myfile.txt \
        --vault-role-name amoebius-admin-role \
        --vault-addr http://vault.vault.svc.cluster.local:8200 \
        --vault-token-path /var/run/secrets/kubernetes.io/serviceaccount/token \
        --minio-credentials-path amoebius/services/minio/root

    python -m amoebius.cli.utils.minio list \
        --bucket my-bucket \
        --prefix logs/ \
        --recursive \
        --vault-role-name amoebius-admin-role \
        --vault-addr http://vault.vault.svc.cluster.local:8200 \
        --vault-token-path /var/run/secrets/kubernetes.io/serviceaccount/token \
        --minio-credentials-path amoebius/services/minio/root
"""

import argparse
import asyncio
import sys
from typing import Optional

from amoebius.models.vault import VaultSettings
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.minio import get_minio_client


async def _read(args: argparse.Namespace) -> None:
    """Read an object from a Minio bucket and print its contents.

    This function retrieves Minio credentials from Vault (using either a direct
    token or a Kubernetes-based Vault role), creates a Minio client, and attempts
    to read the specified object from the given bucket. The object's contents are
    printed to stdout.

    Args:
        args (argparse.Namespace):
            The command-line arguments containing the following:
            - bucket (str): Name of the Minio bucket.
            - object_key (str): Key (path) of the object to read.
            - vault_addr (str): Vault server address.
            - vault_role_name (str): Vault Kubernetes auth role name.
            - vault_token (str): Direct Vault token.
            - vault_token_path (str): Path to JWT token for K8s auth.
            - no_verify_ssl (bool): Whether to disable SSL cert verification.
            - minio_credentials_path (str): Vault path for Minio credentials.

    Raises:
        SystemExit: If mutually exclusive Vault arguments are both provided
                    or if reading from Minio fails.
    """
    # Ensure the user didn't provide both Vault token and Vault role
    if args.vault_token and args.vault_role_name:
        print(
            "Error: --vault-token and --vault-role-name are mutually exclusive.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Build the Vault settings from CLI args
    vault_settings = VaultSettings(
        vault_addr=args.vault_addr,
        vault_role_name=args.vault_role_name,
        direct_vault_token=args.vault_token,
        token_path=args.vault_token_path,
        verify_ssl=(not args.no_verify_ssl),
    )

    # Create a Vault client and retrieve Minio credentials/client
    async with AsyncVaultClient(vault_settings) as vault_client:
        minio_client = await get_minio_client(
            vault_client,
            vault_path=args.minio_credentials_path,
        )

        response = None
        try:
            response = minio_client.get_object(args.bucket, args.object_key)
            data = response.read()
        except Exception as exc:
            print(
                f"ERROR: Failed to read object '{args.object_key}' "
                f"from bucket '{args.bucket}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)
        finally:
            if response is not None:
                response.close()
                response.release_conn()

    # Print the object contents to stdout
    # If it's binary data, this may produce garbled text.
    print(data.decode("utf-8"), end="")


async def _list(args: argparse.Namespace) -> None:
    """List objects in a Minio bucket.

    This function retrieves Minio credentials from Vault, creates a Minio client,
    and lists objects in the specified bucket. An optional prefix can be used
    to filter the listing, and a recursive flag can enable traversal of
    subdirectories.

    Args:
        args (argparse.Namespace):
            The command-line arguments containing the following:
            - bucket (str): Name of the Minio bucket.
            - prefix (str): Optional prefix to filter objects.
            - recursive (bool): Whether to list objects recursively.
            - vault_addr (str): Vault server address.
            - vault_role_name (str): Vault Kubernetes auth role name.
            - vault_token (str): Direct Vault token.
            - vault_token_path (str): Path to JWT token for K8s auth.
            - no_verify_ssl (bool): Whether to disable SSL cert verification.
            - minio_credentials_path (str): Vault path for Minio credentials.

    Raises:
        SystemExit: If mutually exclusive Vault arguments are both provided
                    or if listing objects from Minio fails.
    """
    # Ensure the user didn't provide both Vault token and Vault role
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
        verify_ssl=(not args.no_verify_ssl),
    )

    # Create a Vault client and retrieve Minio credentials/client
    async with AsyncVaultClient(vault_settings) as vault_client:
        minio_client = await get_minio_client(
            vault_client,
            vault_path=args.minio_credentials_path,
        )
        try:
            objects = minio_client.list_objects(
                args.bucket,
                prefix=args.prefix,
                recursive=args.recursive,
            )
            for obj in objects:
                print(obj.object_name)
        except Exception as exc:
            print(
                f"ERROR: Failed to list objects from bucket '{args.bucket}': {exc}",
                file=sys.stderr,
            )
            sys.exit(1)


def main() -> None:
    """CLI entry point for Minio operations via Vault credentials.

    This function parses command-line arguments to determine whether the user
    wants to 'read' a specific object or 'list' the objects in a bucket.
    It sets up subparsers for each verb and binds them to the appropriate
    async functions.
    """
    parser = argparse.ArgumentParser(
        prog="amoebius.cli.utils.minio",
        description=(
            "CLI to read or list objects from Minio using credentials stored in Vault."
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=False)

    #
    # read subcommand
    #
    read_parser = subparsers.add_parser(
        "read",
        help="Read a single object from Minio and write its contents to stdout.",
    )
    read_parser.add_argument(
        "--bucket", required=True, help="Name of the Minio bucket."
    )
    read_parser.add_argument("--object-key", required=True, help="Object key to read.")

    # Mutually exclusive Vault auth arguments for 'read'
    group_read = read_parser.add_mutually_exclusive_group()
    group_read.add_argument(
        "--vault-role-name",
        default="amoebius-admin-role",
        help="Vault K8s auth role name (mutually exclusive with --vault-token).",
    )
    group_read.add_argument(
        "--vault-token",
        help="Direct Vault token (mutually exclusive with --vault-role-name).",
    )

    read_parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    read_parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help=(
            "Path to JWT token for K8s auth "
            "(default: /var/run/secrets/kubernetes.io/serviceaccount/token)."
        ),
    )
    read_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL cert verification (default: verify).",
    )
    read_parser.add_argument(
        "--minio-credentials-path",
        default="amoebius/services/minio/root",
        help="Vault path storing Minio credentials (default: amoebius/services/minio/root).",
    )
    read_parser.set_defaults(func=_read)

    #
    # list subcommand
    #
    list_parser = subparsers.add_parser(
        "list",
        help="List objects in a Minio bucket.",
    )
    list_parser.add_argument(
        "--bucket",
        required=True,
        help="Name of the Minio bucket to list.",
    )
    list_parser.add_argument(
        "--prefix",
        default="",
        help="Optional prefix to filter objects in the bucket.",
    )
    list_parser.add_argument(
        "--recursive",
        action="store_true",
        default=False,
        help="If set, list objects recursively.",
    )

    # Mutually exclusive Vault auth arguments for 'list'
    group_list = list_parser.add_mutually_exclusive_group()
    group_list.add_argument(
        "--vault-role-name",
        default="amoebius-admin-role",
        help="Vault K8s auth role name (mutually exclusive with --vault-token).",
    )
    group_list.add_argument(
        "--vault-token",
        help="Direct Vault token (mutually exclusive with --vault-role-name).",
    )

    list_parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault address (default: http://vault.vault.svc.cluster.local:8200).",
    )
    list_parser.add_argument(
        "--vault-token-path",
        default="/var/run/secrets/kubernetes.io/serviceaccount/token",
        help=(
            "Path to JWT token for K8s auth "
            "(default: /var/run/secrets/kubernetes.io/serviceaccount/token)."
        ),
    )
    list_parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        default=False,
        help="Disable SSL cert verification (default: verify).",
    )
    list_parser.add_argument(
        "--minio-credentials-path",
        default="amoebius/services/minio/root",
        help="Vault path storing Minio credentials (default: amoebius/services/minio/root).",
    )
    list_parser.set_defaults(func=_list)

    # Parse the arguments
    args = parser.parse_args()

    # If no subcommand is provided, print help and exit
    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Run the chosen command
    asyncio.run(args.func(args))


if __name__ == "__main__":
    main()
