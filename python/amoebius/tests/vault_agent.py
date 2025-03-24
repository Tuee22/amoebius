"""
amoebius/tests/vault_agent.py

Tests a hypothetical "vault agent" scenario, referencing a TerraformBackendRef
for "tests/vault-agent".
"""

from __future__ import annotations

import asyncio
import argparse
from getpass import getpass
import sys
from typing import Optional

from amoebius.secrets.vault_unseal import load_vault_init_data_from_file
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    read_terraform_state,
    get_output_from_state,
)
from amoebius.models.terraform import TerraformBackendRef


TERRAFORM_REF = TerraformBackendRef(root="tests/vault-agent")


async def main() -> None:
    """Example test scenario for a vault agent using Terraform states."""
    parser = argparse.ArgumentParser(description="Terraform ops with Vault secrets")
    parser.add_argument(
        "--destroy", action="store_true", help="Destroy instead of apply"
    )
    parser.add_argument(
        "--print-root-token", action="store_true", help="Print the Vault root token"
    )
    args = parser.parse_args()

    password = getpass("Enter the password to decrypt Vault secrets: ")
    vault_init_data = load_vault_init_data_from_file(password=password)

    tfs = await read_terraform_state(ref=TERRAFORM_REF)
    vault_addr = get_output_from_state(tfs, "vault_addr", str)

    if args.print_root_token:
        print(f"Vault root token: {vault_init_data.root_token}")

    variables = {
        "vault_addr": vault_addr,
        "vault_token": vault_init_data.root_token,
    }

    async def tf_apply() -> None:
        """Init + apply with the given variables."""
        await init_terraform(ref=TERRAFORM_REF)
        await apply_terraform(ref=TERRAFORM_REF, variables=variables)

    async def tf_destroy() -> None:
        """Destroy with the given variables."""
        await destroy_terraform(ref=TERRAFORM_REF, variables=variables)

    selected_action = tf_destroy if args.destroy else tf_apply
    print("Destroying Terraform..." if args.destroy else "Applying Terraform...")
    await selected_action()


if __name__ == "__main__":
    asyncio.run(main())
