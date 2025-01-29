from __future__ import annotations

from typing import Any, Dict, List, Union, Literal
import yaml
from pydantic import BaseModel, Field, model_validator

# ----------------------------------------------------------------------
# 1) Type Definitions
# ----------------------------------------------------------------------

TerraformValue = Union[str, int, float, bool, None, Dict[str, Any], List[Any]]
AmoebiusService = Literal["vault", "minio", "pulsar"]


# ----------------------------------------------------------------------
# 2) AmoebiusTree (Nested Hierarchy)
# ----------------------------------------------------------------------


class AmoebiusTree(BaseModel):
    """
    Represents a nested hierarchy of Amoebius nodes, each with:
      - name:          A unique identifier.
      - cluster_config: Dict[AmoebiusService, List[TerraformValue]].
      - children:      Zero or more child nodes (AmoebiusTree).

    After initialization, we verify that all 'name' fields in the hierarchy
    are unique.
    """

    name: str
    cluster_config: Dict[AmoebiusService, Dict[str,TerraformValue]] = Field(
        default_factory=dict
    )
    children: List[AmoebiusTree] = Field(default_factory=list)

    @model_validator(mode="after")
    def check_unique_names(self) -> AmoebiusTree:
        """
        Ensure all node names in this hierarchy are unique.
        """
        all_names = _collect_names(self)
        if len(all_names) != len(set(all_names)):
            raise ValueError(
                "Duplicate name(s) detected in the AmoebiusTree hierarchy."
            )
        return self

    def to_yaml(self, *, sort_keys: bool = False) -> str:
        """
        Serialize this AmoebiusTree to a YAML string using PyYAML.
        """
        return yaml.dump(self.model_dump(), sort_keys=sort_keys)

    @classmethod
    def from_yaml(cls, yaml_str: str) -> AmoebiusTree:
        """
        Deserialize an AmoebiusTree from a YAML string.
        """
        data = yaml.safe_load(yaml_str)
        return cls.model_validate(data)


# ----------------------------------------------------------------------
# 3) Helper: Collect All Names with Comprehensions
# ----------------------------------------------------------------------


def _collect_names(node: AmoebiusTree) -> List[str]:
    """
    Returns all node names in this subtree, including the node's own name,
    using comprehensions only (no for loops).
    """
    return [node.name] + [
        child_name for child in node.children for child_name in _collect_names(child)
    ]


# ----------------------------------------------------------------------
# 4) Rebuild Models for Forward References (Pydantic v2)
# ----------------------------------------------------------------------
AmoebiusTree.model_rebuild()


# ----------------------------------------------------------------------
# 5) Example Usage
# ----------------------------------------------------------------------
if __name__ == "__main__":
    example_data = {
        "name": "root",
        "cluster_config": {
            "vault": {'config':"root_vault_config",'oscillates':True},
            "minio": {'rankings':[1, 2, 3]},
            "pulsar": {'something':[]},
        },
        "children": [
            {
                "name": "child1",
                "cluster_config": {
                    "vault": {'a':["child1_vault"]},
                    "minio": {'b':[]},
                    "pulsar": {'c':["child1_pulsar"]},
                },
                "children": [],
            },
            {
                "name": "child2",
                "cluster_config": {
                    "vault": {'d':[]},
                    "minio": {'e':["child2_minio"]},
                    "pulsar": {'f':[]},
                },
                "children": [
                    {
                        "name": "grandchild1",
                        "cluster_config": {
                            "vault": {'g':[]},
                            "minio": {'h':["grandchild_minio"]},
                            "pulsar": {'i':[False]},
                        },
                        "children": [],
                    }
                ],
            },
        ],
    }

    # Parse untyped data through model_validate (avoid **kwargs)
    tree = AmoebiusTree.model_validate(example_data)
    print("Constructed AmoebiusTree:\n", tree, "\n")

    # YAML round-trip
    yaml_str = tree.to_yaml()
    print("-- YAML serialization --\n", yaml_str)

    reloaded = AmoebiusTree.from_yaml(yaml_str)
    print("-- Round-trip check --\nEquivalent?", tree == reloaded)
