"""
filename: amoebius/models/providers/deploy/azure.py

Provides cluster deployment logic for the 'azure' provider (e.g. AzureClusterDeploy).
"""

from typing import List, Dict
from pydantic import BaseModel, Field
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup

# Import the credential model from new location
from amoebius.models.providers.api_keys.azure import AzureCredentials


class AzureClusterDeploy(ClusterDeploy):
    """Cluster deployment parameters for Azure."""

    def __init__(
        self,
        region: str = "eastus",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = ["1", "2", "3"],
        instance_type_map: Dict[str, str] = {
            # ARM-based
            "arm_small": "Standard_D2ps_v5",
            "arm_medium": "Standard_D4ps_v5",
            "arm_large": "Standard_D8ps_v5",
            # x86-based
            "x86_small": "Standard_D2ads_v6",
            "x86_medium": "Standard_D4ads_v6",
            "x86_large": "Standard_D8ads_v6",
            # NVIDIA GPU
            "nvidia_small": "Standard_NC4as_T4_v3",
            "nvidia_medium": "Standard_NC6s_v3",
            "nvidia_large": "Standard_NC24s_v3",
        },
        arm_default_image: str = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest",
        x86_default_image: str = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest",
        instance_groups: List[InstanceGroup] = [],
        ssh_user: str = "azureuser",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ):
        # Fill in default images if none specified
        for ig in instance_groups:
            if ig.image is None:
                if ig.category.startswith("arm_"):
                    ig.image = arm_default_image
                else:
                    ig.image = x86_default_image

        super().__init__(
            region=region,
            vpc_cidr=vpc_cidr,
            availability_zones=availability_zones,
            instance_type_map=instance_type_map,
            instance_groups=instance_groups,
            ssh_user=ssh_user,
            vault_role_name=vault_role_name,
            no_verify_ssl=no_verify_ssl,
        )


__all__ = ["AzureClusterDeploy", "AzureCredentials"]
