"""
amoebius/utils/terraform/commands.py

Implements the Terraform commands (init, apply, destroy, read, etc.),
plus helper functions for building commands.
Uses ephemeral usage from ephemeral.py to ensure no secrets on local disk.
"""

from __future__ import annotations

import os
from typing import Any, Dict, Optional, Type, TypeVar, List

from amoebius.utils.async_command_runner import run_command
from amoebius.models.validator import validate_type
from amoebius.models.terraform_state import TerraformState
from amoebius.secrets.vault_client import AsyncVaultClient
from minio import Minio

from amoebius.utils.terraform.storage import StateStorage, NoStorage
from amoebius.utils.terraform.ephemeral import (
    ephemeral_tfstate_if_needed,
    maybe_tfvars,
)

T = TypeVar("T")


def make_base_command(action: str, override_lock: bool, reconfigure: bool) -> List[str]:
    """
    Build the base Terraform command in a purely functional style (no list mutation).
    """
    base = ["terraform", action, "-no-color"]

    show_flags = ["-json"] if action == "show" else []
    apply_destroy_flags = (
        (["-auto-approve"] + (["-lock=false"] if override_lock else []))
        if action in ("apply", "destroy")
        else []
    )
    init_flags = ["-reconfigure"] if (action == "init" and reconfigure) else []

    return base + show_flags + apply_destroy_flags + init_flags


def build_final_command(base_cmd: List[str], tfvars_args: List[str]) -> List[str]:
    """Combine base_cmd with optional var-file flags, no ephemeral flags used in TF 1.10."""
    return base_cmd + tfvars_args


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
    Internal runner for 'terraform <action>' with ephemeral usage => store .tfstate & .tfstate.backup in memory only.
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
        store, vault_client, minio_client, transit_key_name, terraform_dir
    ):
        async with maybe_tfvars(action, variables) as tfvars_args:
            final_cmd = build_final_command(base_cmd, tfvars_args)
            output = await run_tf(final_cmd)
            return output if capture_output else None


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
    """Run 'terraform init' with ephemeral usage if needed, covering .tfstate & .tfstate.backup."""
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
    """Run 'terraform apply' with ephemeral usage for .tfstate & .tfstate.backup."""
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
    """Run 'terraform destroy' with ephemeral usage for .tfstate & .tfstate.backup."""
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
    Run 'terraform show -json' with ephemeral usage for .tfstate & .tfstate.backup,
    returning the parsed TerraformState object.
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
        state: The parsed TerraformState from read_terraform_state.
        output_name: The name of the output to retrieve.
        output_type: The Python type to cast/validate to.

    Returns:
        T: The typed output value.

    Raises:
        KeyError: If the output is not found.
        ValueError: If type validation fails.
    """
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)
