import os
from typing import Any, Optional, Dict, Type, TypeVar
from ..models.terraform_state import TerraformState
from ..models.validator import validate_type
from ..utils.async_command_runner import run_command

T = TypeVar('T')

# Default path in container
DEFAULT_TERRAFORM_ROOTS = "/amoebius/terraform/roots"

async def read_terraform_state(
    root_name: str, 
    base_path: str = DEFAULT_TERRAFORM_ROOTS
) -> TerraformState:
    """
    Read the Terraform state for a given root directory using terraform show.
    
    Args:
        root_name: Name of the Terraform root directory (no slashes allowed)
        base_path: Base path where terraform roots are located. 
                  Defaults to container path /amoebius/terraform/roots
    
    Returns:
        TerraformState object containing the parsed and validated terraform state
        
    Raises:
        ValueError: If root_name contains invalid characters
        CommandError: If terraform commands fail
        ValidationError: If terraform state doesn't match expected schema
    """
    # Validate root_name to prevent directory traversal
    if "/" in root_name or "\\" in root_name:
        raise ValueError("Root name cannot contain slashes")
        
    if not root_name.strip():
        raise ValueError("Root name cannot be empty")

    # Construct the path to the terraform root
    terraform_path = os.path.join(base_path, root_name)
    
    # Verify the directory exists
    if not os.path.isdir(terraform_path):
        raise ValueError(f"Terraform root directory not found: {terraform_path}")
    
    # Initialize terraform if needed
    await run_command(
        ["terraform", "init", "-no-color"],
        sensitive=False,
        cwd=terraform_path
    )
    
    # Get the state as JSON
    state_json = await run_command(
        ["terraform", "show", "-json"],
        sensitive=False,
        cwd=terraform_path
    )
    
    # Parse and validate using Pydantic model
    return TerraformState.parse_raw(state_json)

def get_output_from_state(
    state: TerraformState, 
    output_name: str, 
    output_type: Type[T]
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