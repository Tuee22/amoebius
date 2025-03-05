"""
amoebius/terraform/transit_terraform.py

This module runs Terraform commands with optional ephemeral state + Vault transit encryption.
We also check if Vault is sealed/unavailable before ephemeral usage, ensuring we never run
Terraform if Vault is not ready.

Key Points:
  - We rely on "AsyncVaultClient.is_vault_sealed()" to check Vault status.
  - If sealed => we raise => no Terraform calls are made.
  - We store ephemeral partial data in /dev/shm, handle partial encryption in a finally block.
  - read_terraform_state uses 'terraform show -json'.

Requires the updated vault_client with 'is_vault_sealed()'.
"""

from __future__ import annotations

import os
import io
import json
import asyncio
import aiofiles
import tempfile
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional, Type, TypeVar, List, AsyncGenerator

from contextlib import asynccontextmanager

from amoebius.utils.async_command_runner import run_command
from amoebius.utils.async_retry import async_retry
from amoebius.models.terraform_state import TerraformState
from amoebius.models.validator import validate_type
from amoebius.secrets.vault_client import AsyncVaultClient
from minio import Minio

T = TypeVar("T")


# -----------------------------------------------------------------------------
# Abstract Storage
# -----------------------------------------------------------------------------
class StateStorage(ABC):
    """
    An abstract base class that reads/writes ciphertext for (root_module, workspace).
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        self.root_module = root_module
        self.workspace = workspace or "default"

    @abstractmethod
    async def read_ciphertext(
        self, *, vault_client: Optional[AsyncVaultClient], minio_client: Optional[Minio]
    ) -> Optional[str]:
        pass

    @abstractmethod
    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        pass


class NoStorage(StateStorage):
    """
    Indicates no ephemeral override (vanilla Terraform). read/write => do nothing.
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        super().__init__(root_module, workspace)

    async def read_ciphertext(
        self, *, vault_client: Optional[AsyncVaultClient], minio_client: Optional[Minio]
    ) -> Optional[str]:
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        pass


class VaultKVStorage(StateStorage):
    """
    Stores ciphertext in Vault's KV under "secret/data/amoebius/terraform-backends/<root>/<ws>"
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        super().__init__(root_module, workspace)

    def _kv_path(self) -> str:
        return f"amoebius/terraform-backends/{self.root_module}/{self.workspace}"

    async def read_ciphertext(
        self, *, vault_client: Optional[AsyncVaultClient], minio_client: Optional[Minio]
    ) -> Optional[str]:
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        try:
            resp = await vault_client.read_secret(self._kv_path())
            return resp.get("ciphertext")
        except RuntimeError as ex:
            if "404" in str(ex):
                return None
            raise

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        await vault_client.write_secret(self._kv_path(), {"ciphertext": ciphertext})


class MinioStorage(StateStorage):
    """
    Stores ciphertext in MinIO object bucket: <root>/<workspace>.enc
    We do blocking calls in a threadpool, so we pass minio_client.
    """

    def __init__(
        self,
        root_module: str,
        workspace: Optional[str] = None,
        bucket_name: str = "tf-states",
    ) -> None:
        super().__init__(root_module, workspace)
        self.bucket_name = bucket_name

    def _object_key(self) -> str:
        return f"{self.root_module}/{self.workspace}.enc"

    async def read_ciphertext(
        self, *, vault_client: Optional[AsyncVaultClient], minio_client: Optional[Minio]
    ) -> Optional[str]:
        if not minio_client:
            raise RuntimeError("MinioStorage requires a minio_client.")

        loop = asyncio.get_running_loop()
        response = None
        try:
            response = await loop.run_in_executor(
                None,
                lambda: minio_client.get_object(self.bucket_name, self._object_key()),
            )
            data = response.read()
            return data.decode("utf-8")
        except Exception as ex:
            if any(msg in str(ex) for msg in ("NoSuchKey", "NoSuchObject", "404")):
                return None
            raise
        finally:
            if response:
                response.close()
                response.release_conn()

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        if not minio_client:
            raise RuntimeError("MinioStorage requires a minio_client.")

        loop = asyncio.get_running_loop()
        data_bytes = ciphertext.encode("utf-8")
        length = len(data_bytes)

        def put_object() -> None:
            stream = io.BytesIO(data_bytes)
            minio_client.put_object(
                self.bucket_name,
                self._object_key(),
                data=stream,
                length=length,
                content_type="text/plain",
            )

        await loop.run_in_executor(None, put_object)


# -----------------------------------------------------------------------------
# Encryption Helpers
# -----------------------------------------------------------------------------
@async_retry(retries=30)
async def _encrypt_and_store(
    storage: StateStorage,
    ephemeral_path: str,
    vault_client: AsyncVaultClient,
    minio_client: Optional[Minio],
    transit_key_name: str,
) -> None:
    """
    Read ephemeral_path -> encrypt => store in 'storage'. Retries on failures.
    """
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
    """
    If we rely on Vault, read ciphertext from storage -> decrypt -> ephemeral_path.
    """
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
    """
    If we rely on Vault, read ephemeral_path -> encrypt -> store => remove ephemeral file.
    """
    try:
        if not transit_key_name or isinstance(storage, NoStorage) or not vault_client:
            return
        await _encrypt_and_store(
            storage, ephemeral_path, vault_client, minio_client, transit_key_name
        )
    finally:
        if os.path.exists(ephemeral_path):
            os.remove(ephemeral_path)


# -----------------------------------------------------------------------------
# Async context managers for ephemeral usage and optional tfvars
# -----------------------------------------------------------------------------
@asynccontextmanager
async def ephemeral_tfstate_if_needed(
    storage: StateStorage,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    transit_key_name: Optional[str],
) -> AsyncGenerator[Optional[str], None]:
    """
    If ephemeral usage is needed => create /dev/shm file, decrypt partial state,
    then re-encrypt on exit. Also check if Vault is sealed => raise to avoid Terraform usage.
    """
    ephemeral_needed = not (isinstance(storage, NoStorage) and not transit_key_name)
    if not ephemeral_needed:
        yield None
        return

    # If ephemeral usage => we rely on Vault. Check if sealed:
    if not vault_client:
        raise RuntimeError("Vault usage required, but no vault_client is provided.")

    sealed = await vault_client.is_vault_sealed()
    if sealed:
        raise RuntimeError(
            "Vault is sealed/unavailable; cannot proceed with Terraform ephemeral usage."
        )

    fd, ephemeral_path = tempfile.mkstemp(dir="/dev/shm", suffix=".tfstate")
    os.close(fd)

    await _decrypt_to_file(
        storage, ephemeral_path, vault_client, minio_client, transit_key_name
    )
    try:
        yield ephemeral_path
    finally:
        await _encrypt_from_file(
            storage, ephemeral_path, vault_client, minio_client, transit_key_name
        )


@asynccontextmanager
async def maybe_tfvars(
    action: str, variables: Optional[Dict[str, Any]]
) -> AsyncGenerator[List[str], None]:
    """
    If action is 'apply' or 'destroy' & variables exist => yield ['-var-file', tmp_path].
    Otherwise => yield [].
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
                os.remove(tfvars_file)
    else:
        yield []


# -----------------------------------------------------------------------------
# Base Command Builders
# -----------------------------------------------------------------------------
def make_base_command(action: str, override_lock: bool, reconfigure: bool) -> List[str]:
    """
    Construct a Terraform command list. If action=show => add -json,
    if action in apply/destroy => add -auto-approve, etc.
    """
    cmd = ["terraform", action, "-no-color"]
    if action == "show":
        cmd.append("-json")
    elif action in ("apply", "destroy"):
        cmd.append("-auto-approve")
        if override_lock:
            cmd.append("-lock=false")
    if action == "init" and reconfigure:
        cmd.append("-reconfigure")
    return cmd


def build_final_command(
    base_cmd: List[str],
    ephemeral_path: Optional[str],
    tfvars_args: List[str],
) -> List[str]:
    """
    Combine the base_cmd, ephemeral usage, and tfvars usage into a final List[str].
    """
    final_cmd = list(base_cmd)
    final_cmd.extend(tfvars_args)
    if ephemeral_path:
        final_cmd.extend(["-backend=false", "-state", ephemeral_path])
    return final_cmd


# -----------------------------------------------------------------------------
# The Single Internal Command
# -----------------------------------------------------------------------------
async def _terraform_command(
    action: str,
    root_name: str,
    workspace: Optional[str],
    base_path: str,
    env: Optional[Dict[str, str]],
    storage: Optional[StateStorage],
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    transit_key_name: Optional[str],
    override_lock: bool,
    variables: Optional[Dict[str, Any]],
    reconfigure: bool,
    sensitive: bool,
    capture_output: bool,
) -> Optional[str]:
    ws = workspace or "default"
    store = storage or NoStorage(root_name, ws)
    terraform_dir = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_dir):
        raise ValueError(f"Terraform directory not found: {terraform_dir}")

    base_cmd = make_base_command(action, override_lock, reconfigure)

    async def run_tf(cmd_list: List[str]) -> str:
        return await run_command(
            cmd_list, sensitive=sensitive, env=env, cwd=terraform_dir
        )

    async with ephemeral_tfstate_if_needed(
        store, vault_client, minio_client, transit_key_name
    ) as ephemeral_path:
        async with maybe_tfvars(action, variables) as tfvars_args:
            final_cmd = build_final_command(base_cmd, ephemeral_path, tfvars_args)
            output = await run_tf(final_cmd)
            return output if capture_output else None


# -----------------------------------------------------------------------------
# Public Wrappers
# -----------------------------------------------------------------------------
async def init_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    sensitive: bool = True,
) -> None:
    """
    Runs 'terraform init'. If ephemeral usage is needed, checks Vault seal status first.
    """
    await _terraform_command(
        action="init",
        root_name=root_name,
        workspace=workspace,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        override_lock=False,
        variables=None,
        reconfigure=reconfigure,
        sensitive=sensitive,
        capture_output=False,
    )


async def apply_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    transit_key_name: Optional[str] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    """
    Runs 'terraform apply -auto-approve'. If ephemeral usage is needed, checks Vault seal status first.
    """
    await _terraform_command(
        action="apply",
        root_name=root_name,
        workspace=workspace,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        override_lock=override_lock,
        variables=variables,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=False,
    )


async def destroy_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    transit_key_name: Optional[str] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    """
    Runs 'terraform destroy -auto-approve'. If ephemeral usage is needed, checks Vault seal status first.
    """
    await _terraform_command(
        action="destroy",
        root_name=root_name,
        workspace=workspace,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        override_lock=override_lock,
        variables=variables,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=False,
    )


async def read_terraform_state(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    transit_key_name: Optional[str] = None,
    sensitive: bool = True,
) -> TerraformState:
    """
    Runs 'terraform show -json', returning a TerraformState. If ephemeral usage is needed, checks vault seal status.
    """
    output = await _terraform_command(
        action="show",
        root_name=root_name,
        workspace=workspace,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        override_lock=False,
        variables=None,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=True,
    )
    return TerraformState.model_validate_json(output or "")


def get_output_from_state(
    state: TerraformState, output_name: str, output_type: Type[T]
) -> T:
    """
    Retrieves a typed output from a TerraformState object.
    Raises KeyError if not found, ValueError if type mismatch.
    """
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)
