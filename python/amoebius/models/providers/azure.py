"""
azure.py

AzureClusterDeploy -> define __init__ with defaults, call super().
"""

from typing import List, Dict
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup


class AzureClusterDeploy(ClusterDeploy):
    def __init__(
        self,
        region: str = "eastus",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = ["1", "2", "3"],
        instance_type_map: Dict[str, str] = {
            "arm_small": "Standard_D2ps_v5",
            "x86_small": "Standard_D2s_v5",
            "x86_medium": "Standard_D4s_v5",
            "nvidia_small": "Standard_NC4as_T4_v3",
        },
        arm_default_image: str = "/subscriptions/123abc/.../24_04_arm",
        x86_default_image: str = "/subscriptions/123abc/.../24_04_x86",
        instance_groups: List[InstanceGroup] = [],
        ssh_user: str = "azureuser",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ) -> None:
        super().__init__(
            region=region,
            vpc_cidr=vpc_cidr,
            availability_zones=availability_zones,
            instance_type_map=instance_type_map,
            arm_default_image=arm_default_image,
            x86_default_image=x86_default_image,
            instance_groups=instance_groups,
            ssh_user=ssh_user,
            vault_role_name=vault_role_name,
            no_verify_ssl=no_verify_ssl,
        )
