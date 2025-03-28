"""
cluster_deploy.py

We define a base Pydantic model (ClusterDeploy) with no defaults,
so all fields must be explicitly provided except for the 'image'
field in InstanceGroup, which can be None or a string.
"""

from typing import List, Dict, Optional
from pydantic import BaseModel, Field


class InstanceGroup(BaseModel):
    """Represents a group of instances with the same category, image, and count per zone.

    Attributes:
        category: The category of the instance group (e.g., 'x86_small', 'arm_large').
        count_per_zone: The number of instances to deploy in each zone.
        image: An optional custom image. If None, a default image may be assigned.
    """

    category: str
    count_per_zone: int
    image: Optional[str] = None


class Deployment(BaseModel):
    """A mapping from group name to its corresponding InstanceGroup configuration.

    The dictionary keys represent logical group names (e.g. 'control-plane', 'workers').
    """

    __root__: Dict[str, InstanceGroup] = Field(default_factory=dict)


class ClusterDeploy(BaseModel):
    """A base deployment model with default values.

    Attributes:
        region: The cloud region to use (e.g., 'us-west-2').
        vpc_cidr: The CIDR block for the VPC (e.g., '10.0.0.0/16').
        availability_zones: A list of availability zones within the region.
        instance_type_map: A mapping from instance-group categories to instance types.
        deployment: A Deployment containing one or more instance groups, keyed by name.
        ssh_user: The SSH user used to connect to VMs.
        vault_role_name: The Vault role name used within the cluster.
        no_verify_ssl: Whether to skip SSL verification for Vault or other services.
    """

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
    deployment: Deployment = Field(default_factory=Deployment)
    ssh_user: str = "ubuntu"
    vault_role_name: str = "amoebius-admin-role"
    no_verify_ssl: bool = True


__all__ = [
    "InstanceGroup",
    "Deployment",
    "ClusterDeploy",
]
