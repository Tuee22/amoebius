import asyncio
import argparse
from getpass import getpass
import sys
from typing import Optional

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.vault_unseal import load_vault_init_data_from_file
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    read_terraform_state,
    get_output_from_state,
)

from amoebius.models.vault import VaultSettings

TERRAFORM_ROOT_NAME = "tests/vault-client"
VAULT_ROLE_NAME = "vault-client-role"


async def vault_daemon(
    vault_addr: str,
    secret_path: str,
    interval_seconds: float = 5.0,
) -> None:
    """
    Periodically retrieve and print a secret from Vault.
    This function never returns unless interrupted.
    """
    print("Starting Vault daemon. Will fetch and print secret every 5 seconds...")

    # Construct a VaultSettings object with the CLI args
    settings = VaultSettings(
        vault_addr=vault_addr,
        vault_role_name=VAULT_ROLE_NAME,
        verify_ssl=False,
    )

    async with AsyncVaultClient(settings=settings) as client:
        while True:
            try:
                secret_data = await client.read_secret(secret_path)
                message = secret_data.get("message", "No message found")
                print(f"Vault secret message: {message}", flush=True)
            except Exception as e:
                print(f"Error reading secret: {e}", file=sys.stderr)

            await asyncio.sleep(interval_seconds)


async def main() -> None:
    """
    Main entrypoint that can:
    1. Apply or destroy Terraform resources using the Vault root token.
    2. Print the Vault root token if requested.
    3. Run a daemon that fetches secrets from Vault every 5 seconds.
    """
    parser = argparse.ArgumentParser(
        description="Terraform operations with Vault secrets, or run the Vault daemon."
    )
    parser.add_argument(
        "--destroy",
        action="store_true",
        help="Destroy Terraform resources instead of applying",
    )
    parser.add_argument(
        "--print-root-token",
        action="store_true",
        help="Print the Vault root token and exit",
    )
    parser.add_argument(
        "--daemon",
        action="store_true",
        help="Run the secret-fetching daemon inside the container",
    )
    parser.add_argument(
        "--vault-addr",
        default="http://vault.vault.svc.cluster.local:8200",
        help="Vault address to connect to (default: http://vault.vault.svc.cluster.local:8200)",
    )
    parser.add_argument(
        "--secret-path",
        default="vault-client/hello",
        help='Which secret path to read (default: "secret/data/vault-test/hello")',
    )
    parser.add_argument(
        "--override-lock",
        action="store_true",
        help="If true overrides the terraform lock",
    )
    args = parser.parse_args()

    # If --daemon, skip Terraform logic and just run the app
    if args.daemon:
        print("Running Vault daemon within container...")
        await vault_daemon(
            vault_addr=args.vault_addr,
            secret_path=args.secret_path,
            interval_seconds=5.0,
        )
        return

    # Otherwise, handle Terraform logic
    password = getpass("Enter the password to decrypt Vault secrets: ")
    vault_init_data = load_vault_init_data_from_file(password=password)

    # Read the base Terraform state for the Vault server (to get its address)
    tfs = await read_terraform_state(root_name="vault")
    vault_addr = get_output_from_state(tfs, "vault_addr", str)

    # Print root token if requested
    if args.print_root_token:
        print(f"Vault root token: {vault_init_data.root_token}")
        return

    # We'll set environment variables for Terraform
    # so that the Vault provider can read them directly.
    env_vars = {
        "VAULT_ADDR": vault_addr,
        "VAULT_TOKEN": vault_init_data.root_token,
    }

    async def tf_apply() -> None:
        # Pass env=env_vars to init_terraform so it knows about these at init time
        await init_terraform(root_name=TERRAFORM_ROOT_NAME, env=env_vars)
        await apply_terraform(
            root_name=TERRAFORM_ROOT_NAME,
            env=env_vars,
            override_lock=args.override_lock,
        )

    async def tf_destroy() -> None:
        await destroy_terraform(
            root_name=TERRAFORM_ROOT_NAME,
            env=env_vars,
            override_lock=args.override_lock,
        )

    selected_action = tf_destroy if args.destroy else tf_apply
    print(
        "Destroying Terraform resources..."
        if args.destroy
        else "Applying Terraform configurations..."
    )
    await selected_action()


if __name__ == "__main__":
    asyncio.run(main())
