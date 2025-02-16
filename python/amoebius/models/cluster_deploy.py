"""
cluster_deploy.py

Contains:
  - InstanceGroup: submodel
  - ClusterDeploy: the base model (all fields required, no defaults).
"""

from typing import List, Dict, Optional
from pydantic import BaseModel

class InstanceGroup(BaseModel):
    """
    Submodel for instance_groups[]:
      {
        name           = string
        category       = string
        count_per_zone = number
        image          = optional(string, "")
      }
    """
    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None

class ClusterDeploy(BaseModel):
    """
    The base cluster "deploy" model, with all fields required, no defaults.

    Fields:
      region               : str
      vpc_cidr             : str
      availability_zones   : List[str]
      instance_type_map    : Dict[str, str]
      arm_default_image    : str
      x86_default_image    : str
      instance_groups      : List[InstanceGroup]
      ssh_user             : str
      vault_role_name      : str
      no_verify_ssl        : bool
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
