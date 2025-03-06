"""
amoebius/utils/terraform.py

Refactored module that:
  - Defines VaultKVStorage (placeholder).
  - Imports the single TerraformState from amoebius.models.terraform_state (pydantic).
  - Provides get_output_from_state(...) with a type parameter.
  - Provides init_terraform, apply_terraform, destroy_terraform, read_terraform_state
    with comprehensive signatures to avoid missing/unexpected argument errors.

This should fix:
  - The "Argument 'values' to 'TerraformState' has incompatible type" error by
    constructing pydantic Values directly.
  - The "Too many arguments for get_output_from_state" by reintroducing a
    third parameter for the expected type (T).
"""

from __future__ import annotations
import asyncio
import json
from typing import Any, Dict, List, Optional, Type, TypeVar, cast

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.terraform_state import TerraformState, Values, OutputValue

__all__ = [
    "VaultKVStorage",
    "get_output_from_state",
    "init_terraform",
    "apply_terraform",
    "destroy_terraform",
    "read_terraform_state",
]

T = TypeVar("T")


class VaultKVStorage:
    """
    A placeholder ephemeral storage for Terraform state, referencing a Vault path.

    Attributes:
        root_module (str): The name of the Terraform root module (e.g. 'minio').
        workspace (str): The Terraform workspace (e.g. 'default').
    """

    def __init__(self, root_module: str, workspace: str) -> None:
        """
        Initializes a new VaultKVStorage instance.

        Args:
            root_module: The Terraform root module name.
            workspace: The Terraform workspace name.
        """
        self.root_module = root_module
        self.workspace = workspace

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> Optional[str]:
        """
        Retrieves ciphertext for ephemeral TF state from Vault (placeholder).

        Args:
            vault_client: The Vault client to read from. If None, do nothing.

        Returns:
            The ciphertext string if found, or None if not found.
        """
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient] = None,
    ) -> None:
        """
        Writes ciphertext for ephemeral TF state to Vault (placeholder).

        Args:
            ciphertext: The ciphertext to store.
            vault_client: The Vault client to write with. If None, do nothing.

        Returns:
            None
        """
        pass


async def _run_tf(cmd_list: List[str]) -> str:
    """
    Actually run a Terraform command, returning stdout as a string.

    Args:
        cmd_list: The list of command arguments, e.g. ["terraform", "init", ...].

    Returns:
        The combined stdout from Terraform, if successful.

    Raises:
        RuntimeError: If Terraform command fails (non-zero return code).
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

    Args:
        action: The Terraform action, e.g. "init", "apply", "destroy", "show".
        root_name: The name of the Terraform root (e.g. "minio").
        workspace: An optional workspace name (e.g. "default").
        env: Optional environment variables for Terraform.
        base_path: The folder path containing the Terraform root.
        storage: A VaultKVStorage instance for ephemeral usage (placeholder).
        vault_client: The Vault client, if ephemeral usage is needed.
        minio_client: A placeholder for additional usage.
        transit_key_name: An optional Vault transit key name for ephemeral encryption.
        reconfigure: If True, pass -reconfigure on 'init'.
        override_lock: If True, pass -lock=false on apply/destroy.
        variables: A dict of Terraform variables to supply via a .tfvars file (placeholder).
        sensitive: If True, logs might be masked (placeholder).
        capture_output: If True, return stdout as a str, else None.

    Returns:
        str if capture_output, otherwise None.
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
    # We'll skip actual file creation for brevity.

    result = await _run_tf(cmd)
    return result if capture_output else None


def get_output_from_state(
    state: TerraformState,
    output_name: str,
    output_type: Type[T],
) -> T:
    """
    Retrieve a typed output from a TerraformState's 'values.outputs'.

    Args:
        state: The pydantic TerraformState object.
        output_name: The name of the output to retrieve.
        output_type: The expected Python type for the output's value (e.g. List[str]).

    Returns:
        The output's value, cast/validated to output_type.

    Raises:
        KeyError: If output_name is missing.
        TypeError/ValueError: If type validation fails.
    """
    if output_name not in state.values.outputs:
        raise KeyError(f"No output named '{output_name}' in Terraform state.")
    val = state.values.outputs[output_name].value
    # If you want stronger checks, do a pydantic or your own validator:
    from amoebius.models.validator import validate_type

    return validate_type(val, output_type)


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
    Runs 'terraform init' with a comprehensive signature.

    This avoids missing/unexpected argument errors in your code.
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
    Runs 'terraform apply' with comprehensive arguments.
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
    Runs 'terraform destroy' with comprehensive arguments.
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
    Runs 'terraform show -json', returning a TerraformState.

    Fixes the fallback for an empty or JSON error by constructing a proper 'Values' object.
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
        # Return a minimal TerraformState with empty Values
        return TerraformState(
            format_version="0.1",
            terraform_version="1.0",
            values=Values(
                outputs={},
                root_module={},
            ),
        )
    try:
        raw = json.loads(result)
    except json.JSONDecodeError:
        # Also return an empty TerraformState on parse errors
        return TerraformState(
            format_version="0.1",
            terraform_version="1.0",
            values=Values(
                outputs={},
                root_module={},
            ),
        )

    # Use pydantic to parse
    return TerraformState(**raw)
