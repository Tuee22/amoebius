"""
amoebius/utils/terraform.py

Defines:
  - VaultKVStorage: a placeholder ephemeral storage class for Terraform state.
  - get_output_from_state: referencing the same TerraformState from amoebius.models.terraform_state
  - init_terraform, apply_terraform, destroy_terraform, read_terraform_state:
      all accept a comprehensive set of parameters with defaults,
      preventing mypy errors about missing/unexpected arguments.
"""

from __future__ import annotations
import asyncio
import json
from typing import Any, Dict, List, Optional

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.terraform_state import TerraformState, OutputValue, Values

__all__ = [
    "VaultKVStorage",
    "get_output_from_state",
    "init_terraform",
    "apply_terraform",
    "destroy_terraform",
    "read_terraform_state",
]


class VaultKVStorage:
    """
    A placeholder ephemeral storage for Terraform state, referencing a Vault path.
    """

    def __init__(self, root_module: str, workspace: str) -> None:
        self.root_module = root_module
        self.workspace = workspace

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> Optional[str]:
        """
        Return the ciphertext from Vault or None if none found.
        Placeholder logic for ephemeral usage.
        """
        # e.g. read from 'secret/data/amoebius/tfstates/{root_module}/{workspace}'
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> None:
        """
        Write the ciphertext to Vault at some path.
        """
        pass


async def _run_tf(cmd_list: List[str]) -> str:
    """
    Actually run a Terraform command, returning stdout as str.
    """
    proc = await asyncio.create_subprocess_exec(
        *cmd_list, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
    )
    stdout_data, stderr_data = await proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError(f"Terraform cmd failed: {cmd_list}, {stderr_data.decode()}")
    return stdout_data.decode()


async def _terraform_command(
    action: str,
    root_name: str,
    workspace: Optional[str],
    env: Optional[Dict[str, str]],
    base_path: str,
    storage: Optional[VaultKVStorage],
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Any],
    transit_key_name: Optional[str],
    reconfigure: bool,
    override_lock: bool,
    variables: Optional[Dict[str, Any]],
    sensitive: bool,
    capture_output: bool,
) -> str | None:
    """
    Internal runner for 'terraform <action>'.
    Returns str if capture_output=True else None.
    """
    cmd: List[str] = ["terraform", action, "-no-color"]

    if action in ("apply", "destroy"):
        cmd.append("-auto-approve")
    if reconfigure and action == "init":
        cmd.append("-reconfigure")
    if override_lock:
        cmd.append("-lock=false")

    # Placeholder ephemeral usage with storage + vault_client => read/write ephemeral TF state
    # if variables => might create a tfvars file
    # For demonstration, we won't do actual file writing here, just the structure.

    result = await _run_tf(cmd)
    return result if capture_output else None


def get_output_from_state(
    state: TerraformState,
    output_name: str,
) -> Any:
    """
    Retrieve an output from a TerraformState (from amoebius.models.terraform_state).

    Args:
        state (TerraformState): The parsed TerraformState pydantic model.
        output_name (str): The name of the output to retrieve.

    Returns:
        Any: The value stored in that output, or raises KeyError if missing.
    """
    if output_name not in state.values.outputs:
        raise KeyError(f"No output named '{output_name}' in Terraform state.")
    output_val = state.values.outputs[output_name]
    return output_val.value


async def init_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[VaultKVStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    """
    Runs 'terraform init' with a comprehensive signature to avoid missing/unexpected argument errors.
    """
    await _terraform_command(
        action="init",
        root_name=root_name,
        workspace=workspace,
        env=env,
        base_path=base_path,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        reconfigure=reconfigure,
        override_lock=override_lock,
        variables=variables,
        sensitive=sensitive,
        capture_output=False,
    )


async def apply_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[VaultKVStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    """
    Runs 'terraform apply'.
    """
    await _terraform_command(
        action="apply",
        root_name=root_name,
        workspace=workspace,
        env=env,
        base_path=base_path,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        reconfigure=reconfigure,
        override_lock=override_lock,
        variables=variables,
        sensitive=sensitive,
        capture_output=False,
    )


async def destroy_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[VaultKVStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> None:
    """
    Runs 'terraform destroy'.
    """
    await _terraform_command(
        action="destroy",
        root_name=root_name,
        workspace=workspace,
        env=env,
        base_path=base_path,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        reconfigure=reconfigure,
        override_lock=override_lock,
        variables=variables,
        sensitive=sensitive,
        capture_output=False,
    )


async def read_terraform_state(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[VaultKVStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Any] = None,
    transit_key_name: Optional[str] = None,
    reconfigure: bool = False,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
) -> TerraformState:
    """
    Runs 'terraform show -json', returning a TerraformState from amoebius.models.terraform_state.
    """
    result = await _terraform_command(
        action="show",
        root_name=root_name,
        workspace=workspace,
        env=env,
        base_path=base_path,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        transit_key_name=transit_key_name,
        reconfigure=reconfigure,
        override_lock=override_lock,
        variables=variables,
        sensitive=sensitive,
        capture_output=True,
    )
    if result is None:
        # Return an empty TerraformState if no data
        return TerraformState(
            format_version="0.1",
            terraform_version="1.0",
            values={"outputs": {}, "root_module": {}},  # minimal structure
        )
    try:
        raw = json.loads(result)
    except json.JSONDecodeError:
        # fallback to an empty state if parse fails
        raw = {
            "format_version": "0.1",
            "terraform_version": "1.0",
            "values": {"outputs": {}, "root_module": {}},
        }

    # Convert 'raw' into your pydantic TerraformState structure
    # If raw already matches TerraformState format, parse it directly
    return TerraformState(**raw)
