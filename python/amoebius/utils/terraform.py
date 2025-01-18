import os
import asyncio
from typing import Any, Optional, Dict, Type, TypeVar
from ..models.terraform_state import TerraformState
from ..models.validator import validate_type
from ..utils.async_command_runner import run_command
from pydantic import ValidationError

T = TypeVar("T")

# Default path in container
DEFAULT_TERRAFORM_ROOTS = "/amoebius/terraform/roots"


async def init_terraform(
    root_name: str, base_path: str = DEFAULT_TERRAFORM_ROOTS, reconfigure: bool = False
) -> None:
    """
    Initialize a Terraform working directory.

    Args:
        root_name: Name of the Terraform root directory (no slashes allowed)
        base_path: Base path where terraform roots are located
        reconfigure: If True, forces reconfiguration of backend

    Raises:
        ValueError: If root_name contains invalid characters or directory not found
        CommandError: If terraform commands fail
    """
    terraform_path = _validate_root_name(root_name, base_path)

    cmd = ["terraform", "init", "-no-color"]
    if reconfigure:
        cmd.append("-reconfigure")

    await run_command(cmd, sensitive=False, cwd=terraform_path)


async def apply_terraform(
    root_name: str,
    variables: Optional[Dict[str, Any]] = None,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    override_lock: bool = False,
) -> None:
    """
    Apply Terraform configuration with auto-approve.

    Args:
        root_name: Name of the Terraform root directory (no slashes allowed)
        variables: Optional dictionary of variables to pass to terraform
        base_path: Base path where terraform roots are located

    Raises:
        ValueError: If root_name contains invalid characters or directory not found
        CommandError: If terraform commands fail
    """
    terraform_path = _validate_root_name(root_name, base_path)

    cmd = ["terraform", "apply", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    if variables:
        for key, value in variables.items():
            cmd.extend(["-var", f"{key}={value}"])

    await run_command(cmd, sensitive=False, cwd=terraform_path)


async def destroy_terraform(
    root_name: str,
    variables: Optional[Dict[str, Any]] = None,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    override_lock: bool = False,
) -> None:
    """
    Destroy Terraform-managed infrastructure with auto-approve.

    Args:
        root_name: Name of the Terraform root directory (no slashes allowed)
        variables: Optional dictionary of variables to pass to terraform
        base_path: Base path where terraform roots are located

    Raises:
        ValueError: If root_name contains invalid characters or directory not found
        CommandError: If terraform commands fail
    """
    terraform_path = _validate_root_name(root_name, base_path)

    cmd = ["terraform", "destroy", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    if variables:
        for key, value in variables.items():
            cmd.extend(["-var", f"{key}={value}"])

    await run_command(cmd, sensitive=False, cwd=terraform_path)


async def read_terraform_state(
    root_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    attempt: int = 1,
    max_attempts: int = 30,
) -> TerraformState:
    """
    Read the Terraform state for a given root directory using terraform show,
    with up to 30 recursive retries (1 second apart) if model validation fails.

    Args:
        root_name: Name of the Terraform root directory (no slashes allowed).
        base_path: Base path where terraform roots are located.
                   Defaults to container path /amoebius/terraform/roots
        attempt: Current attempt number (internal use for recursion).
        max_attempts: Maximum allowed attempts before giving up.

    Returns:
        TerraformState object containing the parsed and validated terraform state.

    Raises:
        ValueError: If root_name contains invalid characters or directory not found.
        CommandError: If terraform commands fail.
        ValidationError: If terraform state doesn't match the expected schema
                         after all retries.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    # Get the state as JSON
    state_json = await run_command(
        ["terraform", "show", "-json"], sensitive=False, cwd=terraform_path
    )

    # Parse and validate using Pydantic model
    try:
        return TerraformState.model_validate_json(state_json)
    except ValidationError as e:
        if attempt < max_attempts:
            await asyncio.sleep(1)
            # Recursively call the same function with incremented attempt count
            return await read_terraform_state(
                root_name, base_path, attempt + 1, max_attempts
            )
        else:
            # If we've exhausted all attempts, re-raise the error
            raise e


def get_output_from_state(
    state: TerraformState, output_name: str, output_type: Type[T]
) -> T:
    """
    Retrieve a specific output from a TerraformState object, validating it against the expected type.

    Args:
        state: The TerraformState object
        output_name: Name of the output to retrieve
        output_type: The expected type of the output value

    Returns:
        The output value parsed as type T

    Raises:
        KeyError: If the output name is not found
        ValueError: If the output value cannot be parsed as the expected type
    """
    output_value = state.values.outputs.get(output_name)
    if output_value is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state")
    return validate_type(output_value.value, output_type)


def _validate_root_name(root_name: str, base_path: str) -> str:
    """
    Validate root_name and return the full terraform path.

    Args:
        root_name: Name to validate
        base_path: Base path where terraform roots are located

    Returns:
        str: Full path to the terraform root directory

    Raises:
        ValueError: If root_name contains invalid characters or directory not found
    """
    if not root_name.strip():
        raise ValueError("Root name cannot be empty")

    terraform_path = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_path):
        raise ValueError(f"Terraform root directory not found: {terraform_path}")

    return terraform_path
