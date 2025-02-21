from typing import List, Dict
from pydantic import BaseModel, Field
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup


# ----------------------------------------
# AzureClusterDeploy
# ----------------------------------------
class AzureClusterDeploy(ClusterDeploy):
    def __init__(
        self,
        region: str = "eastus2",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = ["1", "2", "3"],
        instance_type_map: Dict[str, str] = {
            # ARM-based
            "arm_small": "Standard_D2ps_v5",  # 2 vCPUs, 8 GiB
            "arm_medium": "Standard_D4ps_v5",  # 4 vCPUs, 16 GiB
            "arm_large": "Standard_D8ps_v5",  # 8 vCPUs, 32 GiB
            # x86-based
            "x86_small": "Standard_D2s_v5",  # 2 vCPUs, 8 GiB
            "x86_medium": "Standard_D4s_v5",  # 4 vCPUs, 16 GiB
            "x86_large": "Standard_D8s_v5",  # 8 vCPUs, 32 GiB
            # NVIDIA GPU
            "nvidia_small": "Standard_NC4as_T4_v3",  # 4 vCPUs, T4 GPU
            "nvidia_medium": "Standard_NC6s_v3",  # 6 vCPUs, V100 GPU
            "nvidia_large": "Standard_NC24s_v3",  # 24 vCPUs, V100 GPU
        },
        arm_default_image: str = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest",
        x86_default_image: str = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest",
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


# ----------------------------------------
# AzureCredentials
# ----------------------------------------
class AzureCredentials(BaseModel):
    client_id: str = Field(..., description="Azure Client ID")
    client_secret: str = Field(..., description="Azure Client Secret")
    tenant_id: str = Field(..., description="Azure Tenant ID")
    subscription_id: str = Field(..., description="Azure Subscription ID")

    def to_env_dict(self) -> Dict[str, str]:
        return {
            "ARM_CLIENT_ID": self.client_id,
            "ARM_CLIENT_SECRET": self.client_secret,
            "ARM_TENANT_ID": self.tenant_id,
            "ARM_SUBSCRIPTION_ID": self.subscription_id,
        }
