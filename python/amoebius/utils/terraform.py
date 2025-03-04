"""
amoebius/terraform/transit_terraform.py

A revised version that keeps the _terraform_command(...) function smaller
by moving helper functions (and context managers) to the top level, and
avoiding in-place mutation of command lists.

Key points:
 - We define pure functions for base command creation, ephemeral usage, tfvars usage.
 - We combine them in _terraform_command with minimal code, focusing on
   building final commands in an immutable style.

Usage:
    storage=None => NoStorage => no ephemeral override
    If transit_key_name + storage => ephemeral usage with partial encryption
    The public wrappers remain standard (init/apply/destroy/read).
"""

from __future__ import annotations

import os
import io
import json
import aiofiles
import tempfile
import asyncio
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
# State Storage Classes
# -----------------------------------------------------------------------------
class StateStorage(ABC):
    """
    Abstract base for reading/writing Terraform state ciphertext to (root_module, workspace).
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        self.root_module: str = root_module
        self.workspace: str = workspace or "default"

    @abstractmethod
    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
    ) -> Optional[str]:
        raise NotImplementedError()

    @abstractmethod
    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
    ) -> None:
        raise NotImplementedError()


class NoStorage(StateStorage):
    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        super().__init__(root_module, workspace)

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
    ) -> Optional[str]:
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
    ) -> None:
        pass


class VaultKVStorage(StateStorage):
    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        super().__init__(root_module, workspace)

    def _kv_path(self) -> str:
        return f"amoebius/terraform-backends/{self.root_module}/{self.workspace}"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
    ) -> Optional[str]:
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        try:
            raw = await vault_client.read_secret(self._kv_path())
            return raw.get("ciphertext")
        except RuntimeError as ex:
            if "404" in str(ex):
                return None
            raise

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
    ) -> None:
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        await vault_client.write_secret(self._kv_path(), {"ciphertext": ciphertext})


class MinioStorage(StateStorage):
    def __init__(
        self,
        root_module: str,
        workspace: Optional[str] = None,
        bucket_name: str = "tf-states",
    ) -> None:
        super().__init__(root_module, workspace)
        self.bucket_name: str = bucket_name

    def _object_key(self) -> str:
        return f"{self.root_module}/{self.workspace}.enc"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
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
        vault_client: Optional[AsyncVaultClient] = None,
        minio_client: Optional[Minio] = None,
    ) -> None:
        if not minio_client:
            raise RuntimeError("MinioStorage.write_ciphertext requires a minio_client.")

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


# -----------------------------------------------------------------------------
# Async context managers for ephemeral usage and tfvars
# -----------------------------------------------------------------------------
@asynccontextmanager
async def ephemeral_tfstate_if_needed(
    storage: StateStorage,
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    transit_key_name: Optional[str],
) -> AsyncGenerator[Optional[str], None]:
    """
    Yields a string path if ephemeral usage is needed, else None.
    Decrypts partial changes on enter, re-encrypts on exit.
    """
    ephemeral_needed = not (isinstance(storage, NoStorage) and not transit_key_name)
    if not ephemeral_needed:
        yield None
        return

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
    action: str,
    variables: Optional[Dict[str, Any]],
) -> AsyncGenerator[List[str], None]:
    """
    If action is 'apply' or 'destroy' and variables exist, create a tfvars file,
    yield ['-var-file', that_file], then remove it. Otherwise yield [].
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
# Pure Functions for Building Commands
# -----------------------------------------------------------------------------
def make_base_command(action: str, override_lock: bool, reconfigure: bool) -> List[str]:
    """
    Returns the initial Terraform command list (immutable).
    """
    cmd = ["terraform", action, "-no-color"]
    if action in ("apply", "destroy"):
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
    Returns a new list representing the final command.

    If ephemeral_path is non-None => add ['-backend=false', '-state', ephemeral_path].
    Also append tfvars_args if present.
    """
    new_cmd = list(base_cmd)  # Copy
    new_cmd.extend(tfvars_args)
    if ephemeral_path is not None:
        new_cmd.extend(["-backend=false", "-state", ephemeral_path])
    return new_cmd


# -----------------------------------------------------------------------------
# Single internal _terraform_command
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
    """
    Runs a Terraform command (init/apply/destroy/show) with ephemeral usage if needed.
    The code is split among pure functions and context managers to minimize in-place mutations.

    Returns the command's stdout if capture_output=True, else None.
    """
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
    Runs 'terraform init' with optional ephemeral usage. No return value.
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
    Runs 'terraform apply -auto-approve' with ephemeral usage if needed. No return value.
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
    Runs 'terraform destroy -auto-approve' with ephemeral usage if needed. No return value.
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
    Runs 'terraform show -json' to retrieve the current state with ephemeral usage if needed.
    Returns a TerraformState object.
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
    Retrieve a typed output from the TerraformState. Raises KeyError if absent,
    ValueError if type conversion fails.
    """
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)
