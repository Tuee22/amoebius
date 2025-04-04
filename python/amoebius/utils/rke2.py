from __future__ import annotations
from typing import Dict, List, Optional

from minio import Minio
from amoebius.models.terraform import TerraformBackendRef
from amoebius.models.rke2 import RKE2Instance, RKE2InstancesOutput
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform.commands import (
    read_terraform_state,
    get_output_from_state,
)
from amoebius.utils.terraform.storage import StateStorage


async def get_rke2_instances_output(
    ref: TerraformBackendRef,
    storage: StateStorage,
    vault_client: AsyncVaultClient,
    minio_client: Optional[Minio] = None,
) -> RKE2InstancesOutput:
    """
    Reads the Terraform state for the given TerraformBackendRef using the provided
    storage, Vault client, and optional Minio client. It then retrieves the "instances"
    output (a nested map), flattens it into an RKE2InstancesOutput using comprehensions.

    Args:
        ref: The Terraform backend reference (root, workspace).
        storage: A StateStorage instance for storing or retrieving the state ciphertext.
        vault_client: The AsyncVaultClient for reading the state if needed (e.g. KV, Minio).
        minio_client: Optional Minio client if the backend uses Minio for the tfstate.

    Returns:
        RKE2InstancesOutput: group => list of RKE2Instance objects, each describing
        name, IPs, vault path, GPU presence, etc.
    """
    tfstate = await read_terraform_state(
        ref=ref,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
    )

    raw_instances = get_output_from_state(tfstate, "instances", dict)

    # We expect raw_instances to be a dict: group_name => (instance_key => {...})
    # We'll flatten each group's instance_key values into a list of RKE2Instance.
    flattened: Dict[str, List[RKE2Instance]] = {
        grp_name: [
            RKE2Instance(
                name=info["name"],
                private_ip=info["private_ip"],
                public_ip=info.get("public_ip"),
                vault_path=info["vault_path"],
                # If "is_nvidia_instance" is present and truthy => has_gpu=True.
                # Otherwise, false.
                has_gpu=bool(info.get("is_nvidia_instance", False)),
            )
            for info in grp_map.values()
        ]
        for grp_name, grp_map in raw_instances.items()
    }

    return RKE2InstancesOutput(instances=flattened)
