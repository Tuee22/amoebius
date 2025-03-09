"""
amoebius/utils/terraform/ephemeral.py

Handles ephemeral file usage for Terraform state:
 - .tfstate & .tfstate.backup in /dev/shm
 - Encryption/decryption via Vault transit or other storage
 - A helper function returning bool for side-effect file removal, satisfying mypy.

No local imports, no for loops for removal, no ignoring or casting types.
"""

from __future__ import annotations

import os
import json
import aiofiles
import tempfile
from typing import Any, Dict, Optional, AsyncGenerator, List

from contextlib import asynccontextmanager

from amoebius.models.validator import validate_type
from amoebius.models.terraform_state import TerraformState
from amoebius.utils.async_retry import async_retry
from amoebius.secrets.vault_client import AsyncVaultClient
from minio import Minio

from amoebius.utils.async_command_runner import run_command
from amoebius.utils.k8s import get_k8s_secret_data, put_k8s_secret_data
from amoebius.utils.terraform.storage import StateStorage, NoStorage


async def _delete_file(path: str) -> bool:
    """
    Remove a file or symlink, returning True if successful.
    This yields a bool so comprehensions have a non-None item type.
    """
    os.remove(path)
    return True


@async_retry(retries=30)
async def _encrypt_and_store(
    storage: StateStorage,
    ephemeral_path: str,
    vault_client: AsyncVaultClient,
    minio_client: Optional[Minio],
    transit_key_name: str,
) -> None:
    async with aiofiles.open(ephemeral_path, "rb") as f:
        plaintext = await f.read()
    ciphertext = await vault_client.encrypt_transit_data(transit_key_name, plaintext)
    await storage.write_ciphertext(
        ciphertext, vault_client=vault_client, minio_client=minio_client
    )


async def _decrypt_to_file(
    storage: StateStorage,
    ephemeral_path: str,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    transit_key_name: Optional[str],
) -> None:
    if not transit_key_name or isinstance(storage, NoStorage) or not vault_client:
        return

    ciphertext = await storage.read_ciphertext(
        vault_client=vault_client, minio_client=minio_client
    )
    if ciphertext:
        plaintext = await vault_client.decrypt_transit_data(
            transit_key_name, ciphertext
        )
        async with aiofiles.open(ephemeral_path, "wb") as f:
            await f.write(plaintext)


async def _encrypt_from_file(
    storage: StateStorage,
    ephemeral_path: str,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    transit_key_name: Optional[str],
) -> None:
    try:
        if not transit_key_name or isinstance(storage, NoStorage) or not vault_client:
            return
        await _encrypt_and_store(
            storage, ephemeral_path, vault_client, minio_client, transit_key_name
        )
    finally:
        if os.path.exists(ephemeral_path):
            os.remove(ephemeral_path)


@asynccontextmanager
async def ephemeral_tfstate_if_needed(
    storage: StateStorage,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    transit_key_name: Optional[str],
    terraform_dir: str,
) -> AsyncGenerator[None, None]:
    """
    If ephemeral usage => store .tfstate & .tfstate.backup in memory (random dir in /dev/shm),
    symlink them from terraform_dir.
    """
    ephemeral_needed = not (
        isinstance(storage, NoStorage) and (not vault_client or not transit_key_name)
    )
    if not ephemeral_needed:
        yield
        return

    if not vault_client:
        raise RuntimeError("Vault usage required, but no vault_client is provided.")
    if await vault_client.is_vault_sealed():
        raise RuntimeError("Vault is sealed => cannot proceed with ephemeral usage.")

    ephemeral_dir = tempfile.mkdtemp(dir="/dev/shm", prefix="tfstate-")
    ephemeral_file = os.path.join(ephemeral_dir, "terraform.tfstate")
    ephemeral_backup = os.path.join(ephemeral_dir, "terraform.tfstate.backup")

    local_tfstate = os.path.join(terraform_dir, "terraform.tfstate")
    local_backup = os.path.join(terraform_dir, "terraform.tfstate.backup")

    # Remove existing symlinks/files with comprehension
    _ = [
        await _delete_file(p)
        for p in (local_tfstate, local_backup)
        if os.path.lexists(p)
    ]

    os.symlink(ephemeral_file, local_tfstate)
    os.symlink(ephemeral_backup, local_backup)

    # Create ephemeral_file => decrypt
    async with aiofiles.open(ephemeral_file, "wb") as f:
        await f.write(b"")

    await _decrypt_to_file(
        storage, ephemeral_file, vault_client, minio_client, transit_key_name
    )

    try:
        yield
    finally:
        # re-encrypt ephemeral => remove ephemeral file
        await _encrypt_from_file(
            storage, ephemeral_file, vault_client, minio_client, transit_key_name
        )

        # Remove symlinks
        _ = [
            await _delete_file(p)
            for p in (local_tfstate, local_backup)
            if os.path.lexists(p)
        ]

        # Remove ephemeral_dir
        items = os.listdir(ephemeral_dir)
        _ = [
            await _delete_file(os.path.join(ephemeral_dir, i))
            for i in items
            if os.path.isfile(os.path.join(ephemeral_dir, i))
        ]
        os.rmdir(ephemeral_dir)


@asynccontextmanager
async def maybe_tfvars(
    action: str, variables: Optional[Dict[str, Any]]
) -> AsyncGenerator[List[str], None]:
    """
    If action in ('apply','destroy') & variables => ephemeral .auto.tfvars in /dev/shm => yield flags, else []
    """
    if action in ("apply", "destroy") and variables:
        fd, tfvars_file = tempfile.mkstemp(dir="/dev/shm", suffix=".auto.tfvars.json")
        os.close(fd)
        try:
            async with aiofiles.open(tfvars_file, "w") as f:
                await f.write(json.dumps(variables, indent=2))
            yield ["-var-file", tfvars_file]
        finally:
            if os.path.exists(tfvars_file):
                _ = [await _delete_file(tfvars_file)]
    else:
        yield []
