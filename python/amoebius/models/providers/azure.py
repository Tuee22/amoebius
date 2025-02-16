"""
azure.py

AzureClusterDeploy inherits from ClusterDeploy with optional fields + Azure defaults
"""

from typing import Optional, List, Dict
from pydantic import Field

from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup

class AzureClusterDeploy(ClusterDeploy):
    region: Optional[str] = Field(default="eastus")
    vpc_cidr: Optional[str] = Field(default="10.0.0.0/16")
    availability_zones: Optional[List[str]] = Field(default=["1","2","3"])
    instance_type_map: Optional[Dict[str, str]] = Field(default={
        "arm_small":    "Standard_D2ps_v5",
        "x86_small":    "Standard_D2s_v5",
        "x86_medium":   "Standard_D4s_v5",
        "nvidia_small": "Standard_NC4as_T4_v3"
    })
    arm_default_image: Optional[str] = Field(default="/subscriptions/123abc/.../24_04_arm")
    x86_default_image: Optional[str] = Field(default="/subscriptions/123abc/.../24_04_x86")
    instance_groups: Optional[List[InstanceGroup]] = Field(default=[])
    ssh_user: Optional[str] = Field(default="azureuser")
    vault_role_name: Optional[str] = Field(default="amoebius-admin-role")
    no_verify_ssl: Optional[bool] = Field(default=True)
