from typing import List, Dict
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup


class AWSClusterDeploy(ClusterDeploy):
    def __init__(
        self,
        region: str = "us-west-2",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = ["us-west-2a", "us-west-2b", "us-west-2c"],
        instance_type_map: Dict[str, str] = {
            "arm_small": "t4g.small",
            "arm_medium": "t4g.medium",
            "arm_large": "t4g.large",
            "x86_small": "t3.small",
            "x86_medium": "t3.medium",
            "x86_large": "t3.large",
            "nvidia_small": "g4dn.xlarge",
            "nvidia_medium": "g5.2xlarge",
            "nvidia_large": "p4d.24xlarge",
        },
        arm_default_image: str = "ami-04b70fa74e45c3917",  # Ubuntu 22.04 LTS ARM64
        x86_default_image: str = "ami-053b0d53c279acc90",  # Ubuntu 22.04 LTS x86_64
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
