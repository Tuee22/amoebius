"""
This module runs Terraform commands with optional ephemeral state and Vault transit encryption,
in a way that is compatible with Terraform 1.10+.

We also introduce K8sSecretStorage, which stores transit-encrypted state in a Kubernetes Secret.

Features:
  - Polymorphic storage classes (NoStorage, VaultKVStorage, MinioStorage, K8sSecretStorage)
  - Ephemeral usage in /dev/shm, encryption with Vault transit (out-of-band from TF)
  - "terraform show -json" => `read_terraform_state` -> returns `TerraformState`
  - `get_output_from_state` => retrieve typed outputs
  - All shell calls via `run_command(...)` from `async_command_runner`

Requires:
  - A vault_client with `is_vault_sealed()` for ephemeral usage
  - The pydantic-based `TerraformState` model from `amoebius.models.terraform_state`
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

from amoebius.utils.k8s import get_k8s_secret_data, put_k8s_secret_data

T = TypeVar("T")


# -----------------------------------------------------------------------------
# Abstract Storage
# -----------------------------------------------------------------------------
class StateStorage(ABC):
    """Abstract base class for reading/writing Terraform state ciphertext.

    Each implementation deals with the ciphertext for a given (root_module, workspace).
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        """Initialize a StateStorage.

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
        """Read the stored ciphertext for this (root_module, workspace).

        Args:
            vault_client (Optional[AsyncVaultClient]): For Vault-based usage, if any.
            minio_client (Optional[Minio]): For MinIO-based usage, if any.

        Returns:
            Optional[str]: The ciphertext string, or None if not found.
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
        """Write/overwrite the ciphertext for this (root_module, workspace).

        Args:
            ciphertext (str): The ciphertext to store.
            vault_client (Optional[AsyncVaultClient]): For Vault usage, if any.
            minio_client (Optional[Minio]): For MinIO usage, if any.
        """
        pass


class NoStorage(StateStorage):
    """Indicates "vanilla" Terraform usage where read/write are no-ops."""

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        """Initialize NoStorage.

        Args:
            root_module (str): The Terraform root module name.
            workspace (Optional[str]): The workspace name, defaults to "default".
        """
        super().__init__(root_module, workspace)

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        """Return None, indicating no stored ciphertext."""
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        """No-op for writing ciphertext."""
        pass


class VaultKVStorage(StateStorage):
    """Stores ciphertext in Vault's KV under:
    `secret/data/amoebius/terraform-backends/<root>/<workspace>`.
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        """Initialize VaultKVStorage.

        Args:
            root_module (str): The Terraform root module name.
            workspace (Optional[str]): The workspace name, defaults to "default".
        """
        super().__init__(root_module, workspace)

    def _kv_path(self) -> str:
        """Construct the Vault KV path.

        Returns:
            str: e.g. `amoebius/terraform-backends/<root_module>/<workspace>`.
        """
        return f"amoebius/terraform-backends/{self.root_module}/{self.workspace}"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        """Read ciphertext from the Vault KV path."""
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
        """Write ciphertext to the Vault KV path."""
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        await vault_client.write_secret(self._kv_path(), {"ciphertext": ciphertext})


class MinioStorage(StateStorage):
    """Stores ciphertext in a MinIO bucket as: `<root_module>/<workspace>.enc`."""

    def __init__(
        self,
        root_module: str,
        workspace: Optional[str] = None,
        bucket_name: str = "tf-states",
    ) -> None:
        """Initialize MinioStorage.

        Args:
            root_module (str): The Terraform root module name.
            workspace (Optional[str]): The workspace name, defaults to "default".
            bucket_name (str): Name of the MinIO bucket to store objects in.
        """
        super().__init__(root_module, workspace)
        self.bucket_name = bucket_name

    def _object_key(self) -> str:
        """Compute the MinIO object key.

        Returns:
            str: e.g. `<root_module>/<workspace>.enc`
        """
        return f"{self.root_module}/{self.workspace}.enc"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        """Read ciphertext from MinIO."""
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
        """Write ciphertext to MinIO."""
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


class K8sSecretStorage(StateStorage):
    """Stores the transit-encrypted tfstate in a Kubernetes Secret in the 'amoebius' namespace.

    Secret Name Convention:
        tf-backend-<root_module>-<workspace>
    The data key is "ciphertext".
    """

    def __init__(
        self,
        root_module: str,
        workspace: Optional[str] = None,
        namespace: str = "amoebius",
    ) -> None:
        """Initialize K8sSecretStorage.

        Args:
            root_module (str): The Terraform root module name.
            workspace (Optional[str]): The workspace name, defaults to "default".
            namespace (str): The k8s namespace to store the secret in, defaults to "amoebius".
        """
        super().__init__(root_module, workspace)
        self.namespace = namespace

    def _secret_name(self) -> str:
        """Compute the name of the K8s Secret to store ciphertext in.

        Returns:
            str: e.g. `tf-backend-myroot-default`
        """
        return f"tf-backend-{self.root_module}-{self.workspace}"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        """Read ciphertext from the K8s secret's 'ciphertext' field."""
        secret_data = await get_k8s_secret_data(self._secret_name(), self.namespace)
        if not secret_data:
            return None
        return secret_data.get("ciphertext")

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        """Write ciphertext to the K8s secret's 'ciphertext' field."""
        data_dict = {"ciphertext": ciphertext}
        await put_k8s_secret_data(self._secret_name(), self.namespace, data_dict)


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
    """Encrypt ephemeral_path content via Vault transit, then store as ciphertext."""
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
    """Decrypt from storage into ephemeral_path (if transit is used)."""
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
    """Encrypt ephemeral_path content and store, then remove local file."""
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
    """Yield an ephemeral path if ephemeral usage is needed; else None.
    Vault must be unsealed if ephemeral usage is required.
    """
    ephemeral_needed = not (
        isinstance(storage, NoStorage) and (not vault_client or not transit_key_name)
    )
    if not ephemeral_needed:
        yield None
        return

    if not vault_client:
        raise RuntimeError("Vault usage required, but no vault_client is provided.")
    if await vault_client.is_vault_sealed():
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
    """If action is apply/destroy and variables exist, create ephemeral .auto.tfvars.json."""
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
    """Build the base Terraform command list for TF 1.10+."""
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
    tfvars_args: List[str],
) -> List[str]:
    """For TF 1.10, we do not use '-state' or '-backend=false' overrides.

    Just combine base_cmd with tfvars_args.
    """
    return base_cmd + tfvars_args


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
    """Internal runner for 'terraform <action>' with ephemeral usage if needed."""
    ws = workspace or "default"
    store = storage or NoStorage(root_name, ws)

    terraform_dir = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_dir):
        raise ValueError(f"Terraform directory not found: {terraform_dir}")

    base_cmd = make_base_command(action, override_lock, reconfigure)

    async def run_tf(cmd_list: List[str]) -> str:
        """Run the constructed Terraform command, returning stdout."""
        return await run_command(
            cmd_list,
            sensitive=sensitive,
            env=env,
            cwd=terraform_dir,
        )

    async with ephemeral_tfstate_if_needed(
        store, vault_client, minio_client, transit_key_name
    ) as _maybe_ephemeral:
        async with maybe_tfvars(action, variables) as tfvars_args:
            final_cmd = build_final_command(base_cmd, tfvars_args)
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
    """Run 'terraform init' with possible ephemeral encryption for TF 1.10+."""
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
    """Run 'terraform apply' with optional ephemeral usage, TF 1.10+."""
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
    """Run 'terraform destroy' with optional ephemeral usage, TF 1.10+."""
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
    """Run 'terraform show -json' and return a TerraformState object."""
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
    """Retrieve a typed output from a TerraformState object."""
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)
