from typing import List, Dict
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup


class GCPClusterDeploy(ClusterDeploy):
    def __init__(
        self,
        region: str = "us-west2",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = [
            "us-west2-a",
            "us-west2-b",
            "us-west2-c",
        ],
        instance_type_map: Dict[str, str] = {
            "arm_small": "t2a-standard-1",
            "arm_medium": "t2a-standard-4",
            "arm_large": "t2a-standard-8",
            "x86_small": "e2-small",
            "x86_medium": "e2-standard-4",
            "x86_large": "n2-standard-8",
            "nvidia_small": "a2-highgpu-1g",
            "nvidia_medium": "a2-highgpu-2g",
            "nvidia_large": "a2-highgpu-4g",
        },
        arm_default_image: str = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts-arm64",
        x86_default_image: str = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts",
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
