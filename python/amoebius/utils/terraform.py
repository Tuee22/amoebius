"""
amoebius/utils/terraform.py

This module runs Terraform commands with optional ephemeral state + Vault transit encryption.
We also check if Vault is sealed/unavailable before ephemeral usage, ensuring we never run
Terraform if Vault is not ready.

Features:
 - Polymorphic storage classes (NoStorage, VaultKVStorage, MinioStorage)
 - Ephemeral usage in /dev/shm, encryption with Vault transit
 - "terraform show -json" => read_terraform_state -> returns TerraformState
 - "get_output_from_state" => retrieve typed outputs
 - All shell calls via run_command(...) from async_command_runner

Requires:
 - A vault_client with is_vault_sealed()
 - The pydantic-based TerraformState model from amoebius.models.terraform_state
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
    An abstract base class that reads/writes ciphertext for a Terraform state,
    based on (root_module, workspace).
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        """
        Initialize a StateStorage.

        Args:
            root_module (str): The Terraform root module name.
            workspace (Optional[str]): The workspace name, or defaults to "default".
        """
        self.root_module = root_module
        self.workspace = workspace or "default"

    @abstractmethod
    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        """
        Read the stored ciphertext for this (root_module, workspace).

        Args:
            vault_client: For Vault-based usage, if any.
            minio_client: For MinIO-based usage, if any.

        Returns:
            The ciphertext string, or None if not found.
        """
        pass

    @abstractmethod
    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        """
        Write/overwrite the ciphertext for this (root_module, workspace).

        Args:
            ciphertext (str): The ciphertext to store.
            vault_client: For Vault usage, if any.
            minio_client: For MinIO usage, if any.
        """
        pass


class NoStorage(StateStorage):
    """
    Indicates "vanilla" Terraform usage. read/write => no-op.
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        super().__init__(root_module, workspace)

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
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
        """
        Construct the Vault KV path e.g.: "amoebius/terraform-backends/{root}/{ws}"
        """
        return f"amoebius/terraform-backends/{self.root_module}/{self.workspace}"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        try:
            data = await vault_client.read_secret(self._kv_path())
            return data.get("ciphertext")
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
    Stores ciphertext in a MinIO bucket + object => {root_module}/{workspace}.enc
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
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
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
            import io

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
    Read ephemeral_path -> encrypt via Vault transit -> write ciphertext to 'storage'.
    Retries up to 30 times on failure.

    Args:
        storage (StateStorage): The storage approach for writing ciphertext.
        ephemeral_path (str): The local .tfstate path with plaintext.
        vault_client (AsyncVaultClient): For Vault transit usage.
        minio_client (Optional[Minio]): For Minio usage if storing in Minio.
        transit_key_name (str): The Vault transit key name.
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
    If ephemeral usage => read ciphertext => decrypt => ephemeral_path.

    Args:
        storage: The storage approach for reading ciphertext.
        ephemeral_path: The local file to store the decrypted plaintext.
        vault_client: For vault usage if we do transit decryption.
        minio_client: For minio usage if that is the store.
        transit_key_name: The vault transit key name if encryption is used.
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
    If ephemeral usage => read ephemeral_path => encrypt => store => remove ephemeral file.

    Args:
        storage (StateStorage): For writing ciphertext.
        ephemeral_path (str): Local file with plaintext.
        vault_client (Optional[AsyncVaultClient]): For vault usage if transit is used.
        minio_client (Optional[Minio]): For minio usage if storing in Minio.
        transit_key_name (Optional[str]): The vault transit key name if encryption is used.
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
    Yield an ephemeral_path if ephemeral usage is needed; else yield None.
    Check if Vault is sealed => raise if sealed => no Terraform usage if ephemeral is required.

    Args:
        storage (StateStorage): The storage approach.
        vault_client (Optional[AsyncVaultClient]): For checking seal + transit usage.
        minio_client (Optional[Minio]): For reading/writing if Minio is used.
        transit_key_name (Optional[str]): If provided => ephemeral usage is needed.

    Yields:
        Optional[str]: The ephemeral filepath, or None if no ephemeral usage needed.
    """
    ephemeral_needed = not (
        isinstance(storage, NoStorage) and (not vault_client or not transit_key_name)
    )
    if not ephemeral_needed:
        yield None
        return

    if not vault_client:
        raise RuntimeError("Vault usage required, but no vault_client is provided.")
    sealed = await vault_client.is_vault_sealed()
    if sealed:
        raise RuntimeError("Vault is sealed => cannot proceed with ephemeral usage.")

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
    If action in ("apply","destroy") and variables exist => create ephemeral tfvars in /dev/shm, yield ["-var-file", path].
    Else yield [].

    Args:
        action (str): The terraform subcommand, e.g. "apply", "destroy".
        variables (Optional[Dict[str, Any]]): The TF vars to store if needed.

    Yields:
        List[str]: The arguments to pass to terraform, or empty list if none.
    """
    if action in ("apply", "destroy") and variables:
        fd, tfvars_file = tempfile.mkstemp(dir="/dev/shm", suffix=".auto.tfvars.json")
        os.close(fd)
        try:
            import json

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
    Build the base Terraform command list, adding flags for apply/destroy => -auto-approve,
    show => -json, init => -reconfigure if requested, etc.

    Args:
        action (str): "init","apply","destroy","show"
        override_lock (bool): If True => add '-lock=false' for apply/destroy.
        reconfigure (bool): If True => for init => add '-reconfigure'.

    Returns:
        List[str]: The partial terraform command.
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
    Combine base_cmd with ephemeral usage and tfvars usage.

    Args:
        base_cmd (List[str]): The starting command (e.g. ["terraform","apply","-auto-approve"]).
        ephemeral_path (Optional[str]): If we have ephemeral usage => add '-backend=false' '-state path'.
        tfvars_args (List[str]): Possibly ["-var-file","/dev/shm/xxx"] or [].

    Returns:
        List[str]: The final command list for run_command.
    """
    final_cmd = list(base_cmd)
    final_cmd.extend(tfvars_args)
    if ephemeral_path:
        final_cmd.extend(["-backend=false", "-state", ephemeral_path])
    return final_cmd


# -----------------------------------------------------------------------------
# Internal Single Command
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
    Internal runner for "terraform <action>" with ephemeral usage if needed.

    Args:
        action (str): "init","apply","destroy","show"
        root_name (str): The Terraform root module name.
        workspace (Optional[str]): The workspace name or None => "default".
        base_path (str): The top-level path for Terraform modules.
        env (Optional[Dict[str,str]]): Extra environment variables for the command.
        storage (Optional[StateStorage]): The polymorphic storage approach for ephemeral usage.
        vault_client (Optional[AsyncVaultClient]): For transit encryption if ephemeral usage.
        minio_client (Optional[Minio]): For Minio usage if ephemeral store is Minio.
        transit_key_name (Optional[str]): The vault transit key name for encryption.
        override_lock (bool): If True => pass '-lock=false' for apply/destroy.
        variables (Optional[Dict[str,Any]]): For ephemeral tfvars usage.
        reconfigure (bool): If True => pass '-reconfigure' for "init".
        sensitive (bool): If True => do not display command in exception messages.
        capture_output (bool): If True => return stdout, else None.

    Returns:
        Optional[str]: The stdout if capture_output=True, else None.

    Raises:
        ValueError: If the terraform_dir does not exist.
        RuntimeError: If ephemeral usage is needed but Vault is sealed.
    """
    ws = workspace or "default"
    store = storage or NoStorage(root_name, ws)

    terraform_dir = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_dir):
        raise ValueError(f"Terraform directory not found: {terraform_dir}")

    base_cmd = make_base_command(action, override_lock, reconfigure)

    # We'll run TF by calling run_command(...) from async_command_runner
    async def run_tf(cmd_list: List[str]) -> str:
        """
        Actually run the constructed terraform command, returning stdout.
        """
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
    Runs 'terraform init'. If ephemeral usage is needed, checks if Vault is sealed.

    Args:
        root_name: The Terraform root module name.
        workspace: The workspace name if any.
        env: Extra environment variables for the command.
        base_path: The top-level path for Terraform modules, default /amoebius/terraform/roots.
        storage: The storage approach for ephemeral usage (NoStorage, VaultKV, MinioStorage).
        vault_client: For ephemeral usage if using Vault transit encryption.
        minio_client: For ephemeral usage if storing in Minio.
        transit_key_name: The vault transit key name if encryption is used.
        reconfigure: If True => pass '-reconfigure' to 'terraform init'.
        sensitive: If True => do not show command details in exception messages.
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
    Runs 'terraform apply -auto-approve'. If ephemeral usage is needed, checks Vault seal.

    Args:
        root_name: The Terraform root module name.
        workspace: The workspace name if any.
        env: Extra environment variables for the command.
        base_path: The base path for Terraform modules.
        storage: The storage approach for ephemeral usage.
        vault_client: For ephemeral usage if using Vault transit encryption.
        minio_client: For ephemeral usage if storing in Minio.
        transit_key_name: The vault transit key name if encryption is used.
        override_lock: If True => pass '-lock=false' to 'terraform apply'.
        variables: If provided, create ephemeral tfvars file for the command.
        sensitive: If True => do not show command details in exceptions.
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
    Runs 'terraform destroy -auto-approve'. If ephemeral usage is needed, checks Vault seal.

    Args:
        root_name: The Terraform root module name.
        workspace: The workspace name if any.
        env: Extra environment variables for the command.
        base_path: The base path for Terraform modules.
        storage: The storage approach for ephemeral usage.
        vault_client: For ephemeral usage if using Vault transit encryption.
        minio_client: For ephemeral usage if storing in Minio.
        transit_key_name: The vault transit key name if encryption is used.
        override_lock: If True => pass '-lock=false' to 'terraform destroy'.
        variables: If provided, create ephemeral tfvars file for the command.
        sensitive: If True => do not show command details in exceptions.
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
    Runs 'terraform show -json', returning a TerraformState. If ephemeral usage is needed, checks vault seal.

    Args:
        root_name: The Terraform root module name.
        workspace: The workspace name if any.
        env: Extra environment variables for the command.
        base_path: The base path for Terraform modules.
        storage: The ephemeral storage approach (NoStorage, VaultKV, Minio).
        vault_client: For ephemeral usage with Vault transit encryption.
        minio_client: For ephemeral usage if storing in Minio.
        transit_key_name: The vault transit key name if encryption is used.
        sensitive: If True => do not show command details in exceptions.

    Returns:
        TerraformState: The parsed state object from 'terraform show -json'.

    Raises:
        RuntimeError: If the command output is empty or parse fails.
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
    if not output:
        raise RuntimeError("Failed to retrieve terraform state (empty output).")

    return TerraformState.model_validate_json(output)


def get_output_from_state(
    state: TerraformState, output_name: str, output_type: Type[T]
) -> T:
    """
    Retrieve a typed output from a TerraformState object.

    Args:
        state (TerraformState): The parsed TerraformState from read_terraform_state.
        output_name (str): The name of the output to retrieve.
        output_type (Type[T]): The Python type to cast/validate to.

    Returns:
        T: The typed value if present.

    Raises:
        KeyError: If the output does not exist.
        ValueError: If type validation fails.
    """
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)
