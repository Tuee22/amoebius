"""
filename: amoebius/models/providers/deploy/gcp.py

Provides cluster deployment logic for the 'gcp' provider (e.g. GCPClusterDeploy).
"""

from typing import List, Dict
import json
from pydantic import BaseModel, Field
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup, Deployment

# Import the credential model from new location
from amoebius.models.providers.api_keys.gcp import GCPServiceAccountKey


class GCPClusterDeploy(ClusterDeploy):
    """Cluster deployment parameters for GCP."""

    def __init__(
        self,
        region: str = "us-central1",
        vpc_cidr: str = "10.0.0.0/16",
        availability_zones: List[str] = [
            "us-central1-a",
            "us-central1-b",
            "us-central1-f",
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
        deployment: Deployment = Deployment(),
        ssh_user: str = "ubuntu",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ):
        """Initialize GCP-specific deployment parameters.

        Args:
            region: GCP region (e.g. 'us-central1').
            vpc_cidr: The CIDR block for the VPC.
            availability_zones: A list of availability zones in the region.
            instance_type_map: A mapping from categories (e.g. 'arm_small') to GCP machine types.
            arm_default_image: Default ARM image for GCP if none is provided.
            x86_default_image: Default x86 image for GCP if none is provided.
            deployment: A Deployment keyed by group name.
            ssh_user: SSH username on GCP VMs.
            vault_role_name: Vault role name.
            no_verify_ssl: Whether to disable SSL verification.
        """
        # Assign default images based on architecture
        for ig in deployment.__root__.values():
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


__all__ = ["GCPClusterDeploy", "GCPServiceAccountKey"]
