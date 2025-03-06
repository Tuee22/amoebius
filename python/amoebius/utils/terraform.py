"""
amoebius/utils/terraform.py

Restored logic for:
  - NoStorage
  - VaultKVStorage
  - MinioStorage
  - get_output_from_state
  - init/apply/destroy/read_terraform_state using async_command_runner.

All references to create_subprocess_exec are removed. We rely on run_command.
"""

import json
from typing import Any, Dict, List, Optional, Type, TypeVar

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.validator import validate_type
from amoebius.models.terraform_state import TerraformState
from amoebius.utils.async_command_runner import run_command

T = TypeVar("T")


class NoStorage:
    """
    A placeholder signifying "vanilla" Terraform usage with no special state override.
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        self.root_module = root_module
        self.workspace = workspace if workspace else "default"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> Optional[str]:
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> None:
        pass


class VaultKVStorage:
    """
    Represents ephemeral storage for Terraform state in Vault KV engine at some path.
    """

    def __init__(self, root_module: str, workspace: str) -> None:
        self.root_module = root_module
        self.workspace = workspace

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> Optional[str]:
        if not vault_client:
            return None
        path = f"amoebius/tfstates/{self.root_module}/{self.workspace}"
        try:
            raw = await vault_client.read_secret(path)
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
    ) -> None:
        if not vault_client:
            return
        path = f"amoebius/tfstates/{self.root_module}/{self.workspace}"
        data = {"ciphertext": ciphertext}
        await vault_client.write_secret(path, data)


class MinioStorage:
    """
    Stores ciphertext in a MinIO bucket (placeholder).
    Real usage might need concurrency with run_in_executor or S3 signing.
    """

    def __init__(
        self,
        root_module: str,
        workspace: str,
        bucket_name: str = "tf-states",
    ) -> None:
        self.root_module = root_module
        self.workspace = workspace
        self.bucket_name = bucket_name

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> Optional[str]:
        # Placeholder. For real usage, do S3 get object.
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> None:
        # Placeholder. For real usage, do S3 put object.
        pass


def get_output_from_state(
    state: TerraformState,
    output_name: str,
    output_type: Type[T],
) -> T:
    """
    Retrieve a typed output from a TerraformState's 'values.outputs'.

    Args:
        state (TerraformState): The parsed TerraformState.
        output_name (str): The name of the output to retrieve.
        output_type (Type[T]): The Python type to validate or cast to.

    Returns:
        T: The typed output's value.

    Raises:
        KeyError: If the output is missing.
        ValueError: If the type validation fails.
    """
    if output_name not in state.values.outputs:
        raise KeyError(f"No output named '{output_name}' in Terraform state.")
    val = state.values.outputs[output_name].value
    return validate_type(val, output_type)


async def init_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[Any] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    cmd: List[str] = ["terraform", "init", "-no-color"]
    if reconfigure:
        cmd.append("-reconfigure")
    if override_lock:
        cmd.append("-lock=false")

    await run_command(
        cmd,
        env=env,
        retries=0,
        sensitive=sensitive,
        cwd=f"{base_path}/{root_name}",
    )


async def apply_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[Any] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    cmd: List[str] = ["terraform", "apply", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    await run_command(
        cmd,
        env=env,
        retries=0,
        sensitive=sensitive,
        cwd=f"{base_path}/{root_name}",
    )


async def destroy_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[Any] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    cmd: List[str] = ["terraform", "destroy", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    await run_command(
        cmd,
        env=env,
        retries=0,
        sensitive=sensitive,
        cwd=f"{base_path}/{root_name}",
    )


async def read_terraform_state(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[Any] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> TerraformState:
    """
    Runs 'terraform show -json', returning a TerraformState. Raises RuntimeError if parse fails.

    Returns:
        TerraformState: The parsed state, guaranteed non-None.

    Raises:
        RuntimeError: If no output or parse fails.
    """
    cmd: List[str] = ["terraform", "show", "-json", "-no-color"]
    out = await run_command(
        cmd,
        env=env,
        retries=0,
        sensitive=sensitive,
        cwd=f"{base_path}/{root_name}",
    )
    if not out.strip():
        raise RuntimeError("No terraform state found (empty output).")

    try:
        raw = json.loads(out)
    except json.JSONDecodeError as ex:
        raise RuntimeError(f"Failed to parse terraform state JSON: {ex}") from ex

    try:
        return TerraformState(**raw)
    except Exception as ex:
        raise RuntimeError(
            f"Failed to build TerraformState pydantic model: {ex}"
        ) from ex
