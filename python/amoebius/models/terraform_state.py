"""
amoebius/models/terraform_state.py
"""

from pydantic import BaseModel
from typing import Any, Dict, List, Optional, Union


class OutputValue(BaseModel):
    sensitive: bool
    value: Any
    type: Union[str, List[Any], None] = None


class Values(BaseModel):
    outputs: Dict[str, OutputValue]
    root_module: Dict[str, Any]  # We could model this further if needed


class TerraformState(BaseModel):
    format_version: str
    terraform_version: str
    values: Values
