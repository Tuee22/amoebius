"""
cluster_deploy.py

A base Pydantic model (ClusterDeploy) with all fields required (no defaults).
Provider-specific classes must define an __init__ with default arguments if they
want no-arg usage. Mypy-friendly approach.
"""

from typing import List, Dict, Optional
from pydantic import BaseModel


class InstanceGroup(BaseModel):
    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None


class ClusterDeploy(BaseModel):
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
