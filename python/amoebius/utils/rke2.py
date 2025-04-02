"""
amoebius/utils/rke2.py

Helpers for RKE2. Specifically, a function to read Terraform state and build
an RKE2InstancesOutput by flattening 'instances' using comprehensions.
"""

from __future__ import annotations
from typing import Dict, List

from amoebius.models.terraform import TerraformBackendRef
from amoebius.models.rke2 import RKE2Instance, RKE2InstancesOutput
from amoebius.utils.terraform import read_terraform_state, get_output_from_state


async def get_rke2_instances_output(ref: TerraformBackendRef) -> RKE2InstancesOutput:
    """
    Reads the Terraform state for the given TerraformBackendRef,
    retrieves the "instances" output (a nested map), flattens it
    into RKE2InstancesOutput using comprehensions.

    Args:
      ref: The Terraform backend reference (root, workspace).

    Returns:
      RKE2InstancesOutput: group => list of RKE2Instance.
    """
    tfstate = await read_terraform_state(ref=ref)
    raw_instances = get_output_from_state(tfstate, "instances", dict)

    flattened: Dict[str, List[RKE2Instance]] = {
        grp_name: [
            RKE2Instance(
                name=info["name"],
                private_ip=info["private_ip"],
                public_ip=info.get("public_ip"),
                vault_path=info["vault_path"],
                has_gpu=bool(info.get("is_nvidia_instance", False)),
            )
            for info in grp_map.values()
        ]
        for grp_name, grp_map in raw_instances.items()
    }

    return RKE2InstancesOutput(instances=flattened)
