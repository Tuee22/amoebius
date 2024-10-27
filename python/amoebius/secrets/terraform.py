# terraform.py

import os
import json
from typing import Any, Optional, Type, TypeVar
from pydantic import ValidationError
from ..models.terraform_state import TerraformState
from ..models.validator import validate_type

T = TypeVar('T')

def load_state_file(file_path: str) -> Optional[dict]:
    """
    Load and parse a Terraform state file from JSON format.

    Args:
        file_path (str): Path to the Terraform state file.

    Returns:
        Optional[dict]: The loaded JSON content as a dictionary, or None if an error occurs.
    """
    try:
        with open(file_path, 'r') as state_file:
            return json.load(state_file)
    except FileNotFoundError:
        print(f"Error: Terraform state file not found at {file_path}")
    except json.JSONDecodeError:
        print(f"Error: Unable to parse Terraform state file at {file_path}")
    except Exception as e:
        print(f"An unexpected error occurred: {str(e)}")
    return None

def read_terraform_state(terraform_dir: str) -> Optional[TerraformState]:
    """
    Read and parse the Terraform state file from the specified directory into a TerraformState object.

    Args:
        terraform_dir (str): Path to the directory containing the Terraform state file.

    Returns:
        Optional[TerraformState]: The parsed Terraform state as a TerraformState object, or None if an error occurs.
    """
    state_file_path = os.path.join(terraform_dir, "terraform.tfstate")
    state_json = load_state_file(state_file_path)
    
    if state_json is None:
        return None

    try:
        return TerraformState.parse_obj(state_json)
    except ValidationError as ve:
        print(f"Error: Terraform state validation failed: {ve}")
    return None

def get_output_from_state(state: TerraformState, output_name: str, output_type: Type[T]) -> Optional[T]:
    """
    Retrieve a specific output from a TerraformState object, validating it against the expected type.

    Args:
        state (TerraformState): The TerraformState object.
        output_name (str): Name of the output to retrieve.
        output_type (Type[T]): The expected type of the output value.

    Returns:
        Optional[T]: The output value parsed as type T, or None if not found or an error occurs.
    """
    output_value = state.outputs.get(output_name)

    if output_value is None:
        print(f"Error: Output '{output_name}' not found in Terraform state")
        return None

    try:
        # Use validate_type from validator.py for consistent validation
        result: T = validate_type(output_value.value, output_type)
        return result
    except ValueError as ve:
        print(f"Error: Output '{output_name}' could not be parsed as {output_type}: {ve}")
    except Exception as e:
        print(f"An unexpected error occurred while parsing output '{output_name}': {str(e)}")

    return None
