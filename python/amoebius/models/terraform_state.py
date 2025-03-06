"""
amoebius/models/terraform_state.py

Holds the single pydantic TerraformState model used across the codebase.
No local duplicates should appear in utils.terraform or similar modules.
"""

from pydantic import BaseModel
from typing import Any, Dict, List, Union


class OutputValue(BaseModel):
    """
    Represents a Terraform output value, as parsed from 'terraform show -json'.

    Attributes:
        sensitive: Whether the output is sensitive.
        value: The actual output data, can be any type.
        type: Optional type hint from Terraform (string, list, etc.).
    """

    sensitive: bool
    value: Any
    type: Union[str, List[Any], None] = None


class Values(BaseModel):
    """
    Represents the 'values' block in Terraform JSON output.

    Attributes:
        outputs: A dictionary of output_name -> OutputValue.
        root_module: A dictionary representing the root module, if needed.
    """

    outputs: Dict[str, OutputValue]
    root_module: Dict[str, Any]


class TerraformState(BaseModel):
    """
    A pydantic model for the high-level structure of a Terraform JSON state.

    Attributes:
        format_version: The format version string.
        terraform_version: The version of Terraform that created this state.
        values: A Values object containing outputs and the root module.
    """

    format_version: str
    terraform_version: str
    values: Values
