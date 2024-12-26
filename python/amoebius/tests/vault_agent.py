import asyncio
from getpass import getpass
import argparse
from ..secrets.vault import load_vault_init_data_from_file
from ..utils.terraform import init_terraform, apply_terraform, destroy_terraform, read_terraform_state, get_output_from_state

TERRAFORM_ROOT_NAME = "tests/vault"


async def main() -> None:
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description="Terraform operations with Vault secrets"
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
    args = parser.parse_args()

    # Prompt for the Vault password
    password = getpass("Enter the password to decrypt Vault secrets: ")
    vault_init_data = load_vault_init_data_from_file(password=password)

    tfs = await read_terraform_state(root_name="vault")
    vault_addr=get_output_from_state(tfs, "vault_service_name", str)

    # Check if the --print-root-token flag is set
    if args.print_root_token:
        print(f"Vault root token: {vault_init_data.root_token}")
        return

    variables = {"vault_addr":vault_addr,"vault_root_token": vault_init_data.root_token}

    # Define local functions for apply and destroy
    async def tf_apply() -> None:
        await init_terraform(root_name=TERRAFORM_ROOT_NAME)
        await apply_terraform(root_name=TERRAFORM_ROOT_NAME, variables=variables)

    async def tf_destroy() -> None:
        await destroy_terraform(root_name=TERRAFORM_ROOT_NAME, variables=variables)

    # Select the appropriate function using a ternary operator
    selected_action = tf_destroy if args.destroy else tf_apply
    print(
        "Destroying Terraform resources..."
        if args.destroy
        else "Applying Terraform configurations..."
    )
    await selected_action()


if __name__ == "__main__":
    asyncio.run(main())
