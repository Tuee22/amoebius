"""
aws.py

AWSClusterDeploy inherits from ClusterDeploy but fields are optional + AWS defaults
"""

from typing import Optional, List, Dict
from pydantic import Field

# Updated import
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup

class AWSClusterDeploy(ClusterDeploy):
    region: Optional[str] = Field(default="us-east-1")
    vpc_cidr: Optional[str] = Field(default="10.0.0.0/16")
    availability_zones: Optional[List[str]] = Field(default=["us-east-1a","us-east-1b","us-east-1c"])
    instance_type_map: Optional[Dict[str, str]] = Field(default={
        "arm_small": "t4g.micro",
        "x86_small": "t3.micro",
        "x86_medium": "t3.small",
        "nvidia_small": "g4dn.xlarge"
    })
    arm_default_image: Optional[str] = Field(default="ami-0faefad027f3b5de6")
    x86_default_image: Optional[str] = Field(default="ami-0c8a4fc5fa843b2c2")
    instance_groups: Optional[List[InstanceGroup]] = Field(default=[])
    ssh_user: Optional[str] = Field(default="ubuntu")
    vault_role_name: Optional[str] = Field(default="amoebius-admin-role")
    no_verify_ssl: Optional[bool] = Field(default=True)
