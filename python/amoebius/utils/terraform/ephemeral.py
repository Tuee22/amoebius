"""
amoebius/utils/terraform/ephemeral.py

Uses ephemeral_manager to handle ephemeral usage in two scenarios:
 1) ephemeral_tfstate_if_needed (symlink mode)
 2) maybe_tfvars (single-file mode)

We keep for-loops for side effects when needed, and use comprehensions only
for building final data structures.

Now, instead of assert isinstance(...), we use validate_type(...) to
narrow ephemeral_manager's union return type to either Dict[str,str] or str.
"""

from __future__ import annotations

import os
import json
import aiofiles
from contextlib import asynccontextmanager
from typing import Any, Dict, Optional, AsyncGenerator

from amoebius.secrets.vault_client import AsyncVaultClient
from minio import Minio
from amoebius.utils.terraform.storage import StateStorage
from amoebius.utils.ephemeral_file import ephemeral_manager
from amoebius.models.validator import validate_type


@asynccontextmanager
async def ephemeral_tfstate_if_needed(
    storage: StateStorage,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    terraform_dir: str,
) -> AsyncGenerator[None, None]:
    """
    Puts Terraform state (and backup) in ephemeral memory, symlinking them to
    {terraform_dir}/terraform.tfstate and {terraform_dir}/terraform.tfstate.backup.

    If a Vault transit key is configured, decrypt on entry, re-encrypt on exit.

    Args:
        storage: A StateStorage that may hold ciphertext if a transit key is set.
        vault_client: If using Vault-based encryption/decryption.
        minio_client: Optional, if storing ciphertext in Minio.
        terraform_dir: The directory containing terraform configuration files.

    Yields:
        None: On exit, ephemeral memory is cleaned up automatically.
    """
    symlink_map = {
        "terraform.tfstate": os.path.join(terraform_dir, "terraform.tfstate"),
        "terraform.tfstate.backup": os.path.join(
            terraform_dir, "terraform.tfstate.backup"
        ),
    }

    transit_key_name = storage.transit_key_name if storage else None
    use_vault_encryption = (vault_client is not None) and (transit_key_name is not None)

    async with ephemeral_manager(
        symlink_map=symlink_map, prefix="tfstate-"
    ) as ephemeral_paths_union:
        # ephemeral_paths_union is Union[str, Dict[str,str]].
        # Because we're in symlink_map mode, we expect a dict.
        ephemeral_paths = validate_type(ephemeral_paths_union, Dict[str, str])

        tfstate_path = ephemeral_paths["terraform.tfstate"]

        if use_vault_encryption:
            # Decrypt ephemeral -> memory
            if vault_client is None or transit_key_name is None:
                raise RuntimeError(
                    "Vault encryption indicated but vault_client or key missing."
                )

            ciphertext = await storage.read_ciphertext(
                vault_client=vault_client, minio_client=minio_client
            )
            if ciphertext is not None:
                plaintext = await vault_client.decrypt_transit_data(
                    transit_key_name, ciphertext
                )
                async with aiofiles.open(tfstate_path, "wb") as f:
                    await f.write(plaintext)

        try:
            yield
        finally:
            if use_vault_encryption:
                if vault_client is None or transit_key_name is None:
                    raise RuntimeError(
                        "Vault encryption indicated but vault_client or key missing."
                    )

                try:
                    async with aiofiles.open(tfstate_path, "rb") as f:
                        updated_plaintext = await f.read()

                    new_ciphertext = await vault_client.encrypt_transit_data(
                        transit_key_name, updated_plaintext
                    )
                    await storage.write_ciphertext(
                        new_ciphertext,
                        vault_client=vault_client,
                        minio_client=minio_client,
                    )
                except FileNotFoundError:
                    # Possibly no tfstate file was created
                    pass


@asynccontextmanager
async def maybe_tfvars(
    action: str, variables: Optional[Dict[str, Any]]
) -> AsyncGenerator[list[str], None]:
    """
    If the Terraform action is 'apply' or 'destroy' and variables are present,
    create a single ephemeral file for .auto.tfvars.json in /dev/shm and yield
    ["-var-file", that_path]. Otherwise, yield an empty list.

    Args:
        action: Typically "apply" or "destroy".
        variables: A dictionary of TF variables to write into the ephemeral file.

    Yields:
        A list with the "-var-file" argument if ephemeral usage is required, or an empty list otherwise.
    """
    if action not in ("apply", "destroy") or not variables:
        yield []
        return

    async with ephemeral_manager(
        single_file_name="tfvars.auto.tfvars.json", prefix="tfvars-"
    ) as ephemeral_union:
        # ephemeral_union is Union[str, Dict[str, str]]. single-file => str
        tfvars_path = validate_type(ephemeral_union, str)

        async with aiofiles.open(tfvars_path, "w") as f:
            await f.write(json.dumps(variables, indent=2))

        yield ["-var-file", tfvars_path]
