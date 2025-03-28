"""
filename: amoebius/models/providers/deploy/aws.py

Provides cluster deployment logic for the 'aws' provider (e.g. AWSClusterDeploy).
"""

from typing import List, Dict
from pydantic import BaseModel
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup, Deployment
from amoebius.models.providers.api_keys.aws import AWSApiKey  # credentials


class AWSClusterDeploy(ClusterDeploy):
    """Cluster deployment parameters for AWS."""

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
        arm_default_image: str = "ami-0d11a661ebb283897",  # Ubuntu 22.04 LTS ARM64
        x86_default_image: str = "ami-0181d6b00c4160daf",  # Ubuntu 22.04 LTS x86_64
        deployment: Deployment = Deployment(),
        ssh_user: str = "ubuntu",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ):
        """Initialize AWS-specific deployment parameters.

        Args:
            region: AWS region.
            vpc_cidr: CIDR block for the VPC.
            availability_zones: Availability zones in the given region.
            instance_type_map: Maps categories (e.g. 'arm_small') to AWS instance types.
            arm_default_image: Default ARM image if an instance group's image is None.
            x86_default_image: Default x86 image if an instance group's image is None.
            deployment: A Deployment keyed by group name.
            ssh_user: The SSH user for AWS instances.
            vault_role_name: The Vault role name to use.
            no_verify_ssl: Whether to disable SSL verification.
        """
        # Fill in default images
        for ig in deployment.root.values():
            if ig.image is None:
                if ig.category.startswith("arm_"):
                    ig.image = arm_default_image
                else:
                    ig.image = x86_default_image

        super().__init__(
            region=region,
            vpc_cidr=vpc_cidr,
            availability_zones=availability_zones,
            instance_type_map=instance_type_map,
            deployment=deployment,
            ssh_user=ssh_user,
            vault_role_name=vault_role_name,
            no_verify_ssl=no_verify_ssl,
        )


__all__ = ["AWSClusterDeploy", "AWSApiKey"]
