"""
amoebius/utils/terraform/__init__.py

Provides a convenient import interface for the Terraform submodules:

- storage.py for storage classes
- ephemeral.py for ephemeral usage
- commands.py for Terraform commands

Exports:
  - Storage classes (StateStorage, NoStorage, VaultKVStorage, MinioStorage, K8sSecretStorage)
  - Terraform command functions (init_terraform, apply_terraform, destroy_terraform, read_terraform_state)
  - Ephemeral context managers (ephemeral_tfstate_if_needed, maybe_tfvars)
  - get_output_from_state for typed retrieval of Terraform outputs
"""

from amoebius.utils.terraform.storage import (
    StateStorage,
    NoStorage,
    VaultKVStorage,
    MinioStorage,
    K8sSecretStorage,
)
from amoebius.utils.terraform.ephemeral import (
    ephemeral_tfstate_if_needed,
    maybe_tfvars,
)
from amoebius.utils.terraform.commands import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    read_terraform_state,
    get_output_from_state,
)

__all__ = [
    "NoStorage",
    "VaultKVStorage",
    "MinioStorage",
    "K8sSecretStorage",
    "init_terraform",
    "apply_terraform",
    "destroy_terraform",
    "read_terraform_state",
    "get_output_from_state",
]
