"""
amoebius/utils/terraform/ephemeral.py

Handles ephemeral usage for Terraform state in /dev/shm, relying on the generic
ephemeral_symlinks context manager from amoebius/utils/ephemeral_file.py for
symlinking 'tfstate' files to an actual Terraform working directory. Also
handles optional Vault-based encryption/decryption of state if a transit key
is provided.

We revert to for-loops for side effects to avoid mypy issues.
"""

from __future__ import annotations

import os
import json
import tempfile
import aiofiles
from contextlib import asynccontextmanager
from typing import Any, Dict, Optional, AsyncGenerator

from amoebius.secrets.vault_client import AsyncVaultClient
from minio import Minio
from amoebius.utils.terraform.storage import StateStorage
from amoebius.utils.ephemeral_file import ephemeral_symlinks


@asynccontextmanager
async def ephemeral_tfstate_if_needed(
    storage: StateStorage,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    terraform_dir: str,
) -> AsyncGenerator[None, None]:
    """
    Asynchronous context manager that, if ephemeral usage is desired, places
    the Terraform state files in a memory-based temporary directory (/dev/shm),
    symlinks them back to the 'terraform_dir', and optionally encrypts/decrypts
    the data via Vault transit if a 'transit_key_name' is set on the given storage.

    Steps:
      1) Create ephemeral directory in /dev/shm.
      2) Symlink ephemeral 'terraform.tfstate' and 'terraform.tfstate.backup'
         into the actual Terraform directory.
      3) If a Vault client and a 'transit_key_name' are present, decrypt
         the ciphertext from the storage backend into ephemeral memory.
      4) Yield control for Terraform commands (init, apply, destroy, show, etc.).
      5) If encryption was used, read updated data from ephemeral memory,
         re-encrypt it, and store it back in the backend.
      6) Cleanup ephemeral directory and symlinks on exit.

    Args:
        storage (StateStorage):
            The storage class that may hold ciphertext for Terraform state.
        vault_client (Optional[AsyncVaultClient]):
            A Vault client used for encryption/decryption if 'transit_key_name' is set.
        minio_client (Optional[Minio]):
            An optional Minio client for remote storage usage, if needed.
        terraform_dir (str):
            The directory containing Terraform configuration. We place symlinks in
            this directory for 'terraform.tfstate' and 'terraform.tfstate.backup'.

    Yields:
        None: On exit, ephemeral files are cleaned up and any updated ciphertext
        is written back (if transit-based encryption is enabled).
    """
    ephemeral_map = {
        "terraform.tfstate": os.path.join(terraform_dir, "terraform.tfstate"),
        "terraform.tfstate.backup": os.path.join(
            terraform_dir, "terraform.tfstate.backup"
        ),
    }

    # Check if we need encryption/decryption
    transit_key_name: Optional[str] = storage.transit_key_name if storage else None
    use_vault_encryption = (vault_client is not None) and (transit_key_name is not None)

    async with ephemeral_symlinks(
        symlink_map=ephemeral_map, prefix="tfstate-"
    ) as ephemeral_paths:
        tfstate_path = ephemeral_paths["terraform.tfstate"]

        if use_vault_encryption:
            # For mypy's benefit:
            assert vault_client is not None, "Vault client unexpectedly None"
            assert transit_key_name is not None, "Transit key unexpectedly None"

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
                # re-encrypt any updated state
                assert vault_client is not None, "Vault client unexpectedly None"
                assert transit_key_name is not None, "Transit key unexpectedly None"

                try:
                    async with aiofiles.open(tfstate_path, "rb") as f:
                        new_plaintext = await f.read()

                    new_ciphertext = await vault_client.encrypt_transit_data(
                        transit_key_name, new_plaintext
                    )
                    await storage.write_ciphertext(
                        new_ciphertext,
                        vault_client=vault_client,
                        minio_client=minio_client,
                    )
                except FileNotFoundError:
                    # Possibly no state file was created
                    pass


@asynccontextmanager
async def maybe_tfvars(
    action: str, variables: Optional[Dict[str, Any]]
) -> AsyncGenerator[list[str], None]:
    """
    Creates an ephemeral .auto.tfvars.json file in /dev/shm if `variables` are provided
    and the Terraform action is 'apply' or 'destroy'. Then yields the `-var-file` argument
    so you can pass it to the Terraform command.

    This is a specialized ephemeral usage that doesn't do any encryption—just ephemeral.

    Args:
        action (str):
            One of "apply", "destroy", "init", etc.
        variables (Optional[Dict[str, Any]]):
            Key-value pairs to place into a .auto.tfvars.json file. If None or empty,
            no ephemeral file is created.

    Yields:
        list[str]: e.g. ["-var-file", "/dev/shm/xxxx.auto.tfvars.json"] if ephemeral needed,
        or an empty list otherwise.
    """
    if action not in ("apply", "destroy") or not variables:
        yield []
        return

    fd, tfvars_file = tempfile.mkstemp(dir="/dev/shm", suffix=".auto.tfvars.json")
    os.close(fd)

    try:
        async with aiofiles.open(tfvars_file, "w") as f:
            await f.write(json.dumps(variables, indent=2))

        yield ["-var-file", tfvars_file]
    finally:
        if os.path.exists(tfvars_file):
            os.remove(tfvars_file)
