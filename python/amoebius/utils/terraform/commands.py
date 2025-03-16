"""
amoebius/utils/terraform/commands.py

Implements Terraform commands (init, apply, destroy, show, etc.),
plus helpers for building command arrays.
Uses ephemeral usage from ephemeral.py so no secrets remain on disk.

We do NOT pass transit_key_name here; ephemeral usage reads from storage.transit_key_name.

No local imports, no for loops for side-effect removal, passes mypy --strict.
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
from amoebius.utils.terraform.ephemeral import ephemeral_tfstate_if_needed, maybe_tfvars

T = TypeVar("T")


def make_base_command(action: str, override_lock: bool, reconfigure: bool) -> List[str]:
    """
    Build the base Terraform command in a purely functional style (no list mutation).

    Args:
        action: One of "init","apply","destroy","show".
        override_lock: If True => '-lock=false' for apply/destroy.
        reconfigure: If True => '-reconfigure' for init.

    Returns:
        List of command tokens, e.g. ["terraform","apply","-auto-approve"].
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
    """
    Combine base_cmd with optional var-file flags, no ephemeral flags used in TF 1.10.
    """
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
    override_lock: bool,
    variables: Optional[Dict[str, Any]],
    reconfigure: bool,
    sensitive: bool,
    capture_output: bool,
    retries: int,
) -> Optional[str]:
    """
    Internal runner for 'terraform <action>' with ephemeral usage => .tfstate in memory only.
    ephemeral_tfstate_if_needed sees if storage.transit_key_name is set to do encryption.
    """
    ws = workspace or "default"
    store = storage or NoStorage(root_name, ws)

    terraform_dir = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_dir):
        raise ValueError(f"Terraform directory not found: {terraform_dir}")

    base_cmd = make_base_command(action, override_lock, reconfigure)

    async def run_tf(cmd_list: List[str]) -> str:
        return await run_command(
            cmd_list, sensitive=sensitive, env=env, cwd=terraform_dir, retries=retries
        )

    async with ephemeral_tfstate_if_needed(
        store, vault_client, minio_client, terraform_dir
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
    reconfigure: bool = False,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """
    Run 'terraform init' with ephemeral usage if needed, storing .tfstate in memory or remote.

    Args:
        root_name: Terraform root module name.
        workspace: The workspace name, defaults to 'default'.
        env: Additional env vars for Terraform.
        base_path: Path to Terraform modules, defaults to '/amoebius/terraform/roots'.
        storage: The chosen storage class for ciphertext, or NoStorage.
        vault_client: If ephemeral usage w/ Vault encryption is desired.
        minio_client: If ephemeral usage storing ciphertext in Minio.
        reconfigure: If True => '-reconfigure' for 'terraform init'.
        sensitive: If True => omit command details from error logs.
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
        override_lock=False,
        variables=None,
        reconfigure=reconfigure,
        sensitive=sensitive,
        capture_output=False,
        retries=retries,
    )


async def apply_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """
    Run 'terraform apply' with ephemeral usage for .tfstate & .tfstate.backup.

    ephemeral_tfstate_if_needed references storage.transit_key_name if encryption is needed.
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
        override_lock=override_lock,
        variables=variables,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=False,
        retries=retries,
    )


async def destroy_terraform(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """
    Run 'terraform destroy' with ephemeral usage, referencing storage.transit_key_name if set.
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
        override_lock=override_lock,
        variables=variables,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=False,
        retries=retries,
    )


async def read_terraform_state(
    root_name: str,
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    sensitive: bool = True,
    retries: int = 0,
) -> TerraformState:
    """
    Run 'terraform show -json' with ephemeral usage, returning the parsed TerraformState.

    ephemeral_tfstate_if_needed references storage.transit_key_name if encryption is needed.
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
        override_lock=False,
        variables=None,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=True,
        retries=retries,
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
        state: The parsed TerraformState.
        output_name: The name of the output to retrieve.
        output_type: The Python type to cast/validate to.

    Returns:
        The typed output if present.

    Raises:
        KeyError: If the output is missing.
        ValueError: If validation fails.
    """
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)
