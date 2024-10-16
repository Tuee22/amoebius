# terraform_output_reader.py

import os
import json
from typing import Any, Optional, Type, TypeVar
from pydantic import parse_obj_as, ValidationError
from amoebius.models.terraform_state import TerraformState

T = TypeVar('T')

def read_terraform_state(terraform_dir: str) -> Optional[TerraformState]:
    """
    Read the Terraform state file from the specified directory and parse it into a TerraformState object.

    Args:
        terraform_dir (str): Path to the directory containing the Terraform state file.

    Returns:
        Optional[TerraformState]: The parsed Terraform state as a TerraformState object, or None if an error occurs.
    """
    state_file_path = os.path.join(terraform_dir, "terraform.tfstate")

    try:
        with open(state_file_path, 'r') as state_file:
            state_json = json.load(state_file)
            return TerraformState.parse_obj(state_json)
    except FileNotFoundError:
        print(f"Error: Terraform state file not found at {state_file_path}")
    except json.JSONDecodeError:
        print(f"Error: Unable to parse Terraform state file at {state_file_path}")
    except ValidationError as ve:
        print(f"Error: Terraform state validation failed: {ve}")
    except Exception as e:
        print(f"An unexpected error occurred: {str(e)}")

    return None

def get_output_from_state(state: TerraformState, output_name: str, output_type: Type[T]) -> Optional[T]:
    """
    Get a specific output from a TerraformState object, parsed as the specified type.

    Args:
        state (TerraformState): The TerraformState object.
        output_name (str): Name of the output to retrieve.
        output_type (Type[T]): The expected type of the output value.

    Returns:
        Optional[T]: The value of the specified output, parsed as type T, or None if not found or an error occurs.
    """
    output_value = state.outputs.get(output_name)

    if output_value is None:
        print(f"Error: Output '{output_name}' not found in Terraform state")
        return None

    try:
        # Use parse_obj_as to parse and validate the output value as the specified type
        result: T = parse_obj_as(output_type, output_value.value)
        return result
    except ValidationError as ve:
        print(f"Error: Output '{output_name}' could not be parsed as {output_type}: {ve}")
    except Exception as e:
        print(f"An unexpected error occurred while parsing output '{output_name}': {str(e)}")

    return None
