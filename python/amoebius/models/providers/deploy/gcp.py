from typing import List, Dict
import json
from pydantic import BaseModel, Field, ValidationError
from typing import Literal

from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup


# ----------------------------------------
# GCPClusterDeploy
# ----------------------------------------
class GCPClusterDeploy(ClusterDeploy):
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
            "arm_small": "t2a-standard-1",  # T2A supported in a, b, f
            "arm_medium": "t2a-standard-4",  # T2A supported in a, b, f
            "arm_large": "t2a-standard-8",  # T2A supported in a, b, f
            "x86_small": "e2-small",  # E2 supported in a, b, f
            "x86_medium": "e2-standard-4",  # E2 supported in a, b, f
            "x86_large": "n2-standard-8",  # N2 supported in a, b, f
            "nvidia_small": "a2-highgpu-1g",  # A2 supported in a, b, f
            "nvidia_medium": "a2-highgpu-2g",  # A2 supported in a, b, f
            "nvidia_large": "a2-highgpu-4g",  # A2 supported in a, b, f
        },
        arm_default_image: str = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts-arm64",
        x86_default_image: str = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts",
        instance_groups: List[InstanceGroup] = [],
        ssh_user: str = "ubuntu",
        vault_role_name: str = "amoebius-admin-role",
        no_verify_ssl: bool = True,
    ):
        # Assign default images based on architecture
        for ig in instance_groups:
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
            instance_groups=instance_groups,
            ssh_user=ssh_user,
            vault_role_name=vault_role_name,
            no_verify_ssl=no_verify_ssl,
        )


# ----------------------------------------
# GCPServiceAccountKey
# ----------------------------------------
class GCPServiceAccountKey(BaseModel):
    type: Literal["service_account"]
    project_id: str
    private_key_id: str
    private_key: str
    client_email: str
    client_id: str
    auth_uri: str
    token_uri: str
    auth_provider_x509_cert_url: str
    client_x509_cert_url: str
    universe_domain: str = Field(..., description="Typically 'googleapis.com'")

    def to_env_dict(self) -> Dict[str, str]:
        return {
            "GOOGLE_CREDENTIALS": json.dumps(self.model_dump()),
            "GOOGLE_PROJECT": self.project_id,
        }
