#!/usr/bin/env bash
set -euo pipefail

# fix_cluster_deploy_map.sh
#
# Overwrites python/amoebius/models/cluster_deploy.py with a new version that:
#   1) Defines the ClusterDeploy & InstanceGroup classes (with the default/optional fields).
#   2) Imports and re-exports `provider_model_map` from amoebius.models.providers.
# This way, code that does "from amoebius.models.cluster_deploy import provider_model_map"
# will work, satisfying mypy.

TARGET="./python/amoebius/models/cluster_deploy.py"

if [ ! -f "$TARGET" ]; then
  echo "Error: $TARGET not found. Aborting."
  exit 1
fi

cat << 'EOF' > "$TARGET"
"""
cluster_deploy.py

We define a base Pydantic model (ClusterDeploy) with default fields so that
calls won't fail mypy for missing named arguments. Also, we re-export 
`provider_model_map` from `amoebius.models.providers`, so code can do:

    from amoebius.models.cluster_deploy import provider_model_map

without error.
"""

from typing import List, Dict, Optional
from pydantic import BaseModel, Field

# ----------------------------------------------------------------------
# 1) InstanceGroup and ClusterDeploy
# ----------------------------------------------------------------------
class InstanceGroup(BaseModel):
    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None  # allow 'None' for image

class ClusterDeploy(BaseModel):
    region: str = "us-west-1"
    vpc_cidr: str = "10.0.0.0/16"
    availability_zones: List[str] = Field(default_factory=lambda: ["us-west-1a"])
    instance_type_map: Dict[str, str] = Field(default_factory=dict)

    arm_default_image: str = "ARM_DEFAULT"
    x86_default_image: str = "X86_DEFAULT"
    instance_groups: List[InstanceGroup] = Field(default_factory=list)

    ssh_user: str = "ubuntu"
    vault_role_name: str = "amoebius-admin-role"
    no_verify_ssl: bool = True

# ----------------------------------------------------------------------
# 2) Re-export provider_model_map from providers
# ----------------------------------------------------------------------
from amoebius.models.providers import provider_model_map as _provider_model_map

provider_model_map = _provider_model_map

__all__ = [
    "InstanceGroup",
    "ClusterDeploy",
    "provider_model_map",
]
EOF

echo "Overwrote $TARGET to re-export provider_model_map."
echo "Now run: mypy . --strict"