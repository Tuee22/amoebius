"""
amoebius/models/terraform.py

Defines Pydantic models related to Terraform, including:
 - TerraformState: A parsed Terraform JSON state.
 - TerraformBackendRef: A reference to a root + workspace backend in Minio,
   with naming validations enforced by pydantic validators.

Fixes the mypy “missing argument” error by providing a custom __init__ on TerraformBackendRef.
"""

from __future__ import annotations

from typing import Any, Dict, List, Union
from pydantic import BaseModel, Field, field_validator


class TerraformBackendRef(BaseModel):
    """Represents a root + workspace combination for a Terraform backend reference.

    Naming Validations:
      - root: Slashes are allowed; dots/newlines are NOT allowed.
      - workspace: Dots, slashes, and newline are NOT allowed.
                  Defaults to "default" if not explicitly provided.

    Attributes:
        root (str): Slash-based Terraform root path (no dots/newlines).
        workspace (str): Terraform workspace name (no dots/slashes).
                         Defaults to "default".
    """

    root: str
    workspace: str

    def __init__(
        __pydantic_self__, root: str, workspace: str = "default", **data: Any
    ) -> None:
        """Create a TerraformBackendRef with optional workspace defaulting to 'default'.

        Args:
            root: Slash-based Terraform root, no dots/newlines.
            workspace: Terraform workspace, no dots/slashes. Defaults to 'default'.
            **data: Any additional data for Pydantic (ignored here).
        """
        # We call BaseModel.__init__ with named args so mypy sees them
        super().__init__(root=root, workspace=workspace, **data)

    @field_validator("root")
    @classmethod
    def validate_root(cls, value: str) -> str:
        """Check that `root` does not contain dots or newline."""
        if "." in value or "\n" in value:
            raise ValueError("Dots/newline not allowed in 'root'.")
        return value

    @field_validator("workspace")
    @classmethod
    def validate_workspace(cls, value: str) -> str:
        """Check that `workspace` does not contain dots, slash, or newline."""
        if any(x in value for x in [".", "/", "\n"]):
            raise ValueError("Dots/slash/newline not allowed in 'workspace'.")
        return value


class OutputValue(BaseModel):
    """Represents a Terraform output value as parsed from 'terraform show -json'.

    Attributes:
        sensitive: True if the output is marked sensitive.
        value: Arbitrary data from the Terraform output.
        type: Optional Terraform type hint (string, list, etc.).
    """

    sensitive: bool
    value: Any
    type: Union[str, List[Any], None] = None


class Values(BaseModel):
    """Represents the 'values' block in a Terraform JSON state.

    Attributes:
        outputs: Mapping of output_name -> OutputValue for all outputs.
        root_module: Dictionary containing resources and possibly child modules.
    """

    outputs: Dict[str, OutputValue]
    root_module: Dict[str, Any]


class TerraformState(BaseModel):
    """Represents a Terraform JSON state at a high level.

    Attributes:
        format_version: The format version string of the Terraform state.
        terraform_version: The version of Terraform that generated this state.
        values: A Values instance including outputs and resource info.
    """

    format_version: str
    terraform_version: str
    values: Values

    def _count_resources_in_module(self, module_data: Dict[str, Any]) -> int:
        """Recursively count resources in a module, including child modules."""
        resources = module_data.get("resources")
        resources_count = len(resources) if isinstance(resources, list) else 0

        child_modules = module_data.get("child_modules")
        child_sum = (
            sum(
                self._count_resources_in_module(child)
                for child in child_modules
                if isinstance(child, dict)
            )
            if isinstance(child_modules, list)
            else 0
        )
        return resources_count + child_sum

    def is_empty(self) -> bool:
        """Check if this Terraform state contains zero resources.

        Returns:
            True if no resources are present, otherwise False.
        """
        return self._count_resources_in_module(self.values.root_module) == 0
