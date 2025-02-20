"""
cluster_deploy.py

We define a base Pydantic model (ClusterDeploy) with no defaults,
so all fields must be explicitly provided except for the 'image'
field in InstanceGroup, which can be None or a string.
"""

from typing import List, Dict, Optional
from pydantic import BaseModel, Field


# ----------------------------------------------------------------------
# 1) InstanceGroup and ClusterDeploy
# ----------------------------------------------------------------------
class InstanceGroup(BaseModel):
    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None  # allow 'None' for image


class ClusterDeploy(BaseModel):
    """A base deployment model with default values."""

    region: str = "us-west-2"
    vpc_cidr: str = "10.0.0.0/16"
    availability_zones: List[str] = Field(
        default_factory=lambda: ["us-west-2a", "us-west-2b", "us-west-2c"]
    )
    instance_type_map: Dict[str, str] = Field(
        default_factory=lambda: {
            "arm_small": "t4g.small",
            "arm_medium": "t4g.medium",
            "arm_large": "t4g.large",
            "x86_small": "t3.small",
            "x86_medium": "t3.medium",
            "x86_large": "t3.large",
            "nvidia_small": "g4dn.xlarge",
            "nvidia_medium": "g5.2xlarge",
            "nvidia_large": "p4d.24xlarge",
        }
    )
    instance_groups: List[InstanceGroup] = Field(default_factory=list)
    ssh_user: str = "ubuntu"
    vault_role_name: str = "amoebius-admin-role"
    no_verify_ssl: bool = True


__all__ = [
    "InstanceGroup",
    "ClusterDeploy",
]
