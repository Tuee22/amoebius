import asyncio
import argparse
from getpass import getpass
import sys
from typing import Optional

# Import your new Vault client
from amoebius.secrets.vault_client import AsyncVaultClient

# Import your existing helpers
from amoebius.secrets.vault import load_vault_init_data_from_file
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    read_terraform_state,
    get_output_from_state,
)

# Terraform directory name/path
TERRAFORM_ROOT_NAME = "tests/vault"


async def vault_daemon(
    vault_addr: str = "http://vault.vault.svc.cluster.local:8200",
    role_name: str = "vault-test-role",
    secret_path: str = "secret/data/vault-test/hello",
    interval_seconds: float = 5.0,
) -> None:
    """
    Periodically retrieve and print a secret from Vault using an AsyncVaultClient.
    This function never returns unless interrupted.
    """
    print("Starting Vault daemon. Will fetch and print secret every 5 seconds...")
    async with AsyncVaultClient(vault_addr=vault_addr, role_name=role_name) as client:
        # Perform initial login
        await client.login()

        while True:
            try:
                secret_data = await client.read_secret(secret_path)
                # The Terraform code stores { "message": "hello world" }
                message = secret_data.get("message", "No message found")
                print(f"Vault secret message: {message}", flush=True)
            except Exception as e:
                # In production you’d want logging or more robust error handling
                print(f"Error reading secret: {e}", file=sys.stderr)

            await asyncio.sleep(interval_seconds)


async def main() -> None:
    """
    Main entrypoint that can:
    1. Apply or destroy Terraform resources using the Vault root token.
    2. Print the Vault root token if requested.
    3. Run a daemon that fetches and prints secrets from Vault every 5 seconds.
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
        "--role-name",
        default="vault-test-role",
        help="Kubernetes auth role name to use (default: vault-test-role)",
    )
    parser.add_argument(
        "--secret-path",
        default="secret/data/vault-test/hello",
        help='Which secret path to read (default: "secret/data/vault-test/hello")',
    )
    args = parser.parse_args()

    # If --daemon, skip Terraform logic and just run the app
    if args.daemon:
        print("Running Vault daemon within container...")
        await vault_daemon(
            vault_addr=args.vault_addr,
            role_name=args.role_name,
            secret_path=args.secret_path,
            interval_seconds=5.0,
        )
        return

    # Otherwise, handle Terraform logic
    password = getpass("Enter the password to decrypt Vault secrets: ")
    vault_init_data = load_vault_init_data_from_file(password=password)

    # Read the base Terraform state for the Vault server (to get its address)
    tfs = await read_terraform_state(root_name="vault")
    vault_addr = get_output_from_state(tfs, "vault_common_name", str)
    # If the user overrides via --vault-addr, we could respect that, but typically
    # we rely on the Terraform output for the real address.

    # Print root token if requested
    if args.print_root_token:
        print(f"Vault root token: {vault_init_data.root_token}")
        return

    variables = {
        "vault_addr": vault_addr,
        "vault_token": vault_init_data.root_token,
    }

    # Apply or destroy Terraform
    async def tf_apply() -> None:
        await init_terraform(root_name=TERRAFORM_ROOT_NAME)
        await apply_terraform(root_name=TERRAFORM_ROOT_NAME, variables=variables)

    async def tf_destroy() -> None:
        await destroy_terraform(root_name=TERRAFORM_ROOT_NAME, variables=variables)

    selected_action = tf_destroy if args.destroy else tf_apply
    print(
        "Destroying Terraform resources..."
        if args.destroy
        else "Applying Terraform configurations..."
    )
    await selected_action()


if __name__ == "__main__":
    asyncio.run(main())
