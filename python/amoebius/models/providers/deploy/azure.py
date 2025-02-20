from typing import List, Dict
from pydantic import BaseModel, Field
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup


# ----------------------------------------
# AzureClusterDeploy
# ----------------------------------------
class AzureClusterDeploy(ClusterDeploy):
    def __init__(
        self,
        region: str = "westus2",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = ["1", "2", "3"],
        instance_type_map: Dict[str, str] = {
            "arm_small": "Standard_D2ps_v5",
            "arm_medium": "Standard_D4ps_v5",
            "arm_large": "Standard_D8ps_v5",
            "x86_small": "Standard_D2s_v5",
            "x86_medium": "Standard_D4s_v5",
            "x86_large": "Standard_D8s_v5",
            "nvidia_small": "Standard_NC4as_T4_v3",
            "nvidia_medium": "Standard_NC6s_v3",
            "nvidia_large": "Standard_ND96amsr_A100_v4",
        },
        arm_default_image: str = "/subscriptions/123abc/.../22_04_arm",
        x86_default_image: str = "/subscriptions/123abc/.../22_04_x86",
        instance_groups: List[InstanceGroup] = [],
        ssh_user: str = "azureuser",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ):
        # If an InstanceGroup has image=None, fill with either ARM or x86 default:
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
            arm_default_image=arm_default_image,
            x86_default_image=x86_default_image,
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
