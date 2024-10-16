from pydantic import BaseModel
from typing import Any, Dict, List, Optional

class OutputValue(BaseModel):
    value: Any
    type: Optional[Any] = None
    sensitive: Optional[bool] = None

class Instance(BaseModel):
    schema_version: int
    attributes: Dict[str, Any]
    private: Optional[str] = None
    dependencies: Optional[List[str]] = None

class Resource(BaseModel):
    module: Optional[str] = None
    mode: str
    type: str
    name: str
    provider: Optional[str] = None
    instances: List[Instance]

class TerraformState(BaseModel):
    version: int
    terraform_version: str
    serial: int
    lineage: str
    outputs: Dict[str, OutputValue]
    resources: List[Resource]

# Example usage:
# json_data = '{"version": 4, "terraform_version": "1.0.0", ... }'
# state = TerraformState.parse_raw(json_data)
