"""
gcp.py

GCPClusterDeploy inherits from ClusterDeploy with optional fields + GCP defaults
"""

from typing import Optional, List, Dict
from pydantic import Field

from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup

class GCPClusterDeploy(ClusterDeploy):
    region: Optional[str] = Field(default="us-central1")
    vpc_cidr: Optional[str] = Field(default="10.0.0.0/16")
    availability_zones: Optional[List[str]] = Field(default=["us-central1-a","us-central1-b","us-central1-f"])
    instance_type_map: Optional[Dict[str, str]] = Field(default={
        "arm_small": "t2a-standard-1",
        "x86_small": "e2-small",
        "x86_medium": "e2-standard-4",
        "nvidia_small": "a2-highgpu-1g"
    })
    arm_default_image: Optional[str] = Field(default="projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-arm64")
    x86_default_image: Optional[str] = Field(default="projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts")
    instance_groups: Optional[List[InstanceGroup]] = Field(default=[])
    ssh_user: Optional[str] = Field(default="ubuntu")
    vault_role_name: Optional[str] = Field(default="amoebius-admin-role")
    no_verify_ssl: Optional[bool] = Field(default=True)
