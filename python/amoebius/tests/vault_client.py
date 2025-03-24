"""
amoebius/tests/vault_client.py

Simulates or tests Vault client logic, referencing a TerraformBackendRef instead of
root_name=....
"""

from __future__ import annotations

import asyncio
import sys
from typing import Optional

from amoebius.models.vault import VaultInitData
from amoebius.models.terraform import TerraformBackendRef, TerraformState
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    read_terraform_state,
    get_output_from_state,
)


async def some_test_function() -> None:
    """Example test function that calls read_terraform_state on 'services/vault'."""

    ref_vault = TerraformBackendRef(root="services/vault")
    tfs = await read_terraform_state(ref=ref_vault)
    # do something
    print("Terraform state read for 'services/vault'.")

    await init_terraform(ref=ref_vault)
    await apply_terraform(ref=ref_vault)
    await destroy_terraform(ref=ref_vault)


def main() -> None:
    """Entry point for vault_client tests."""
    asyncio.run(some_test_function())


if __name__ == "__main__":
    main()
