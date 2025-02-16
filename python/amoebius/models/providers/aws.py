"""
aws.py

AWSClusterDeploy -> override __init__ to allow no-arg usage, must keep same field types.
"""

from typing import List, Dict
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup


class AWSClusterDeploy(ClusterDeploy):
    def __init__(
        self,
        region: str = "us-east-1",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = ["us-east-1a", "us-east-1b", "us-east-1c"],
        instance_type_map: Dict[str, str] = {
            "arm_small": "t4g.micro",
            "x86_small": "t3.micro",
            "x86_medium": "t3.small",
            "nvidia_small": "g4dn.xlarge",
        },
        arm_default_image: str = "ami-0faefad027f3b5de6",
        x86_default_image: str = "ami-0c8a4fc5fa843b2c2",
        instance_groups: List[InstanceGroup] = [],
        ssh_user: str = "ubuntu",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ):
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
