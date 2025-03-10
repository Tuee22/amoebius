"""
amoebius/utils/terraform/ephemeral.py

Handles ephemeral file usage for Terraform state:
 - .tfstate & .tfstate.backup in /dev/shm
 - Encryption/decryption via Vault transit if storage.transit_key_name is set
 - A helper function returning bool for side-effect file removal, satisfying mypy.

No local imports, no for loops, passes mypy --strict.
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
) -> None:
    """
    Read ephemeral_path -> encrypt (with storage.transit_key_name) -> write ciphertext to storage.
    """
    async with aiofiles.open(ephemeral_path, "rb") as f:
        plaintext = await f.read()

    if not storage.transit_key_name:
        raise RuntimeError("Storage indicates encryption but has no transit_key_name.")

    ciphertext = await vault_client.encrypt_transit_data(
        storage.transit_key_name, plaintext
    )
    await storage.write_ciphertext(
        ciphertext, vault_client=vault_client, minio_client=minio_client
    )


async def _decrypt_to_file(
    storage: StateStorage,
    ephemeral_path: str,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
) -> None:
    """
    If storage.transit_key_name is set => read ciphertext => decrypt => ephemeral_path.
    Otherwise skip encryption entirely.
    """
    if (
        not storage.transit_key_name
        or isinstance(storage, NoStorage)
        or not vault_client
    ):
        return

    ciphertext = await storage.read_ciphertext(
        vault_client=vault_client, minio_client=minio_client
    )
    if ciphertext:
        plaintext = await vault_client.decrypt_transit_data(
            storage.transit_key_name, ciphertext
        )
        async with aiofiles.open(ephemeral_path, "wb") as f:
            await f.write(plaintext)


async def _encrypt_from_file(
    storage: StateStorage,
    ephemeral_path: str,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
) -> None:
    """
    Encrypt ephemeral_path => store => remove ephemeral file, if transit_key_name is set.
    """
    try:
        if (
            not storage.transit_key_name
            or isinstance(storage, NoStorage)
            or not vault_client
        ):
            return
        await _encrypt_and_store(storage, ephemeral_path, vault_client, minio_client)
    finally:
        if os.path.exists(ephemeral_path):
            os.remove(ephemeral_path)


@asynccontextmanager
async def ephemeral_tfstate_if_needed(
    storage: StateStorage,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    terraform_dir: str,
) -> AsyncGenerator[None, None]:
    """
    If ephemeral usage => store .tfstate & .tfstate.backup in memory (random dir in /dev/shm),
    symlink them from terraform_dir. Then decrypt/encrypt if storage.transit_key_name is set.
    """
    # We assume ephemeral is always desired for safety,
    # but if you only want ephemeral for certain storages, you can add logic.
    ephemeral_dir = tempfile.mkdtemp(dir="/dev/shm", prefix="tfstate-")
    ephemeral_file = os.path.join(ephemeral_dir, "terraform.tfstate")
    ephemeral_backup = os.path.join(ephemeral_dir, "terraform.tfstate.backup")

    local_tfstate = os.path.join(terraform_dir, "terraform.tfstate")
    local_backup = os.path.join(terraform_dir, "terraform.tfstate.backup")

    _ = [
        await _delete_file(p)
        for p in (local_tfstate, local_backup)
        if os.path.lexists(p)
    ]

    os.symlink(ephemeral_file, local_tfstate)
    os.symlink(ephemeral_backup, local_backup)

    async with aiofiles.open(ephemeral_file, "wb") as f:
        await f.write(b"")
    if vault_client:
        await _decrypt_to_file(storage, ephemeral_file, vault_client, minio_client)

    try:
        yield
    finally:
        if vault_client:
            await _encrypt_from_file(
                storage, ephemeral_file, vault_client, minio_client
            )

        _ = [
            await _delete_file(p)
            for p in (local_tfstate, local_backup)
            if os.path.lexists(p)
        ]

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
    If action in ('apply','destroy') and variables => ephemeral .auto.tfvars in /dev/shm => yield flags, else [].
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
