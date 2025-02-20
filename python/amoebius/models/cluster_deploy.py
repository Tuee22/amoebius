"""
cluster_deploy.py

We define a base Pydantic model (ClusterDeploy) with no defaults,
so all fields must be explicitly provided except for the 'image'
field in InstanceGroup, which can be None or a string.
"""

from typing import List, Dict, Optional
from pydantic import BaseModel


# ----------------------------------------------------------------------
# 1) InstanceGroup and ClusterDeploy
# ----------------------------------------------------------------------
class InstanceGroup(BaseModel):
    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None  # allow 'None' for image


class ClusterDeploy(BaseModel):
    region: str
    vpc_cidr: str
    availability_zones: List[str]
    instance_type_map: Dict[str, str]

    instance_groups: List[InstanceGroup]

    ssh_user: str
    vault_role_name: str
    no_verify_ssl: bool


__all__ = [
    "InstanceGroup",
    "ClusterDeploy",
]
