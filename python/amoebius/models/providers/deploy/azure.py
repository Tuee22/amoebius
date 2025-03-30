"""
filename: amoebius/models/providers/deploy/azure.py

Provides cluster deployment logic for the 'azure' provider (e.g. AzureClusterDeploy).
"""

from typing import List, Dict
from pydantic import BaseModel, Field
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup, Deployment
from amoebius.models.providers.api_keys.azure import AzureCredentials  # credentials


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
            # x86-based (currently using ARM since it's hard to get a x86 small instance)
            "x86_small": "Standard_D2ps_v5",
            "x86_medium": "Standard_D4ps_v5",
            "x86_large": "Standard_D8ps_v5",
            # NVIDIA GPU
            "nvidia_small": "Standard_NC4as_T4_v3",
            "nvidia_medium": "Standard_NC6s_v3",
            "nvidia_large": "Standard_NC24s_v3",
        },
        arm_default_image: str = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest",
        x86_default_image: str = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest",
        #x86_default_image: str = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest",
        deployment: Deployment = Deployment(),
        ssh_user: str = "azureuser",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ):
        """Initialize Azure-specific deployment parameters.

        Args:
            region: Azure region (e.g. 'eastus').
            vpc_cidr: The CIDR block for the VNet.
            availability_zones: A list of availability zones (e.g. ['1','2','3']).
            instance_type_map: A mapping from categories to Azure machine types.
            arm_default_image: Default ARM-based Azure image.
            x86_default_image: Default x86-based Azure image.
            deployment: A Deployment keyed by group name.
            ssh_user: SSH username on Azure VMs.
            vault_role_name: Vault role name.
            no_verify_ssl: Whether to disable SSL verification.
        """
        # Fill in default images if none specified
        for ig in deployment.root.values():
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
            deployment=deployment,
            ssh_user=ssh_user,
            vault_role_name=vault_role_name,
            no_verify_ssl=no_verify_ssl,
        )


__all__ = ["AzureClusterDeploy", "AzureCredentials"]
