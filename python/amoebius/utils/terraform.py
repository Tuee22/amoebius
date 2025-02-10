# /amoebius/utils/terraform.py

import os
import asyncio
from typing import Any, Optional, Dict, Type, TypeVar

from pydantic import ValidationError

from amoebius.models.terraform_state import TerraformState
from amoebius.models.validator import validate_type
from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.async_retry import async_retry


T = TypeVar("T")

# Default path in container
DEFAULT_TERRAFORM_ROOTS = "/amoebius/terraform/roots"


async def init_terraform(
    root_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    reconfigure: bool = False,
    sensitive: bool = True,
) -> None:
    """
    Initialize a Terraform working directory, possibly using Vault as backend.

    If vault_client is provided, fetch the Vault token and set VAULT_TOKEN
    in the environment. Otherwise pass None.

    Args:
        root_name:    Name of the Terraform root directory (no slashes allowed).
        base_path:    Base path where terraform roots are located.
        reconfigure:  If True, forces reconfiguration of backend.
        vault_client: Optional AsyncVaultClient to obtain VAULT_TOKEN from.
        sensitive:    If True, hides detailed output on command failure.

    Raises:
        ValueError:   If root_name is invalid or directory not found.
        CommandError: If terraform commands fail.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    cmd = ["terraform", "init", "-no-color"]
    if reconfigure:
        cmd.append("-reconfigure")

    await run_command(cmd, sensitive=sensitive, cwd=terraform_path)


async def apply_terraform(
    root_name: str,
    variables: Optional[Dict[str, Any]] = None,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    override_lock: bool = False,
    sensitive: bool = True,
) -> None:
    """
    Apply Terraform configuration with auto-approve.

    If vault_client is provided, fetch the Vault token and set VAULT_TOKEN
    in the environment. Otherwise pass None.

    Args:
        root_name:    Name of the Terraform root directory.
        variables:    Optional dict of variables to pass to terraform.
        base_path:    Base path where terraform roots are located.
        override_lock:If True, disables state lock.
        vault_client: Optional AsyncVaultClient to obtain VAULT_TOKEN from.
        sensitive:    If True, hides detailed output on command failure.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    cmd = ["terraform", "apply", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    if variables:
        for key, value in variables.items():
            cmd.extend(["-var", f'{key}="{value}"'])
    print(" ".join(cmd))

    await run_command(cmd, sensitive=sensitive, cwd=terraform_path)


async def destroy_terraform(
    root_name: str,
    variables: Optional[Dict[str, Any]] = None,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    override_lock: bool = False,
    sensitive: bool = True,
) -> None:
    """
    Destroy Terraform-managed infrastructure with auto-approve.

    If vault_client is provided, fetch the Vault token and set VAULT_TOKEN
    in the environment. Otherwise pass None.

    Args:
        root_name:     Name of the Terraform root directory.
        variables:     Optional dict of variables to pass to terraform.
        base_path:     Base path where terraform roots are located.
        override_lock: If True, disables state lock.
        vault_client:  Optional AsyncVaultClient to obtain VAULT_TOKEN from.
        sensitive:     If True, hides detailed output on command failure.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    cmd = ["terraform", "destroy", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    if variables:
        for key, value in variables.items():
            cmd.extend(["-var", f"{key}={value}"])

    await run_command(cmd, sensitive=sensitive, cwd=terraform_path)


@async_retry(retries=30, delay=1.0)
async def read_terraform_state(
    root_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    sensitive: bool = True,
) -> TerraformState:
    """
    Read the current Terraform state as JSON, parse it into a TerraformState object.

    Retries up to 30 times if model validation fails.

    Args:
        root_name:    Name of the Terraform root directory (no slashes allowed).
        base_path:    Base path where terraform roots are located.
        sensitive:    If True, hides detailed output on command failure.

    Returns:
        TerraformState object if successful.

    Raises:
        ValueError:    If root_name is invalid or directory not found.
        ValidationError: If state doesn't match the expected schema.
        CommandError:  If terraform commands fail.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    cmd = ["terraform", "show", "-json"]
    state_json = await run_command(
        cmd, sensitive=sensitive, cwd=terraform_path
    )

    return TerraformState.model_validate_json(state_json)

def get_output_from_state(
    state: TerraformState, output_name: str, output_type: Type[T]
) -> T:
    """
    Retrieve a specific output from a TerraformState object, validating it.

    Args:
        state:       The TerraformState object.
        output_name: Name of the output to retrieve.
        output_type: The expected type of the output value.

    Raises:
        KeyError: If the output name is not found.
        ValueError: If the output value cannot be parsed as the expected type.
    """
    output_value = state.values.outputs.get(output_name)
    if output_value is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state")
    return validate_type(output_value.value, output_type)


def _validate_root_name(root_name: str, base_path: str) -> str:
    """
    Validate root_name and return the full path to the Terraform root directory.

    Raises:
        ValueError: If root_name is empty or path doesn't exist.
    """
    if not root_name.strip():
        raise ValueError("Root name cannot be empty")

    terraform_path = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_path):
        raise ValueError(f"Terraform root directory not found: {terraform_path}")

    return terraform_path
