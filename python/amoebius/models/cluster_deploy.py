"""
cluster_deploy.py

Base Pydantic model: ClusterDeploy (all fields required, no defaults).
Subclasses must define an __init__ if they want to allow no-arg usage.
"""

from typing import List, Dict
from pydantic import BaseModel
from typing import Optional


class InstanceGroup(BaseModel):
    """
    For instance_groups[]:
      name: str
      category: str
      count_per_zone: int
      image: Optional[str]
    """

    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None


class ClusterDeploy(BaseModel):
    """
    The base cluster deploy model, all required:
    region, vpc_cidr, availability_zones, instance_type_map,
    arm_default_image, x86_default_image, instance_groups,
    ssh_user, vault_role_name, no_verify_ssl
    """

    region: str
    vpc_cidr: str
    availability_zones: List[str]
    instance_type_map: Dict[str, str]

    arm_default_image: str
    x86_default_image: str
    instance_groups: List[InstanceGroup]

    ssh_user: str
    vault_role_name: str
    no_verify_ssl: bool
