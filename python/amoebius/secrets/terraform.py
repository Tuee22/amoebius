# terraform_output_reader.py

import os
import json
from typing import Any, Dict, Optional

def read_terraform_state(terraform_dir: str) -> Optional[Dict[str, Any]]:
    """
    Read the Terraform state file from the specified directory.
    
    Args:
    terraform_dir (str): Path to the directory containing the Terraform state file.
    
    Returns:
    Optional[Dict[str, Any]]: The parsed Terraform state as a dictionary, or None if an error occurs.
    """
    state_file_path = os.path.join(terraform_dir, "terraform.tfstate")
    
    try:
        with open(state_file_path, 'r') as state_file:
            return json.load(state_file)
    except FileNotFoundError:
        print(f"Error: Terraform state file not found at {state_file_path}")
    except json.JSONDecodeError:
        print(f"Error: Unable to parse Terraform state file at {state_file_path}")
    except Exception as e:
        print(f"An unexpected error occurred: {str(e)}")
    
    return None

def get_terraform_output(terraform_dir: str, output_name: str) -> Optional[Any]:
    """
    Get a specific output from the Terraform state.
    
    Args:
    terraform_dir (str): Path to the directory containing the Terraform state file.
    output_name (str): Name of the output to retrieve.
    
    Returns:
    Optional[Any]: The value of the specified output, or None if not found or an error occurs.
    """
    state_data = read_terraform_state(terraform_dir)
    if not state_data:
        return None
    
    outputs = state_data.get('outputs', {})
    output_data = outputs.get(output_name)
    
    if output_data is None:
        print(f"Error: Output '{output_name}' not found in Terraform state")
        return None
    
    return output_data.get('value')