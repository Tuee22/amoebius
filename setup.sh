#!/usr/bin/env bash
#
# remove_defaults_in_cluster_deploy.sh
#
# Overwrites python/amoebius/models/cluster_deploy.py to remove all default values
# for both `InstanceGroup` and `ClusterDeploy`. Fields become fully required,
# except for `image` in InstanceGroup, which remains Optional[str].
#
# Run from /amoebius directory.

set -e

cat > python/amoebius/models/cluster_deploy.py <<'EOF'
"""
cluster_deploy.py

We define a base Pydantic model (ClusterDeploy) with no defaults,
so all fields must be explicitly provided except for the 'image'
field in InstanceGroup, which can be None or a string.
"""

from typing import List, Dict, Optional
from pydantic import BaseModel


# ----------------------------------------------------------------------
# 1) InstanceGroup and ClusterDeploy
# ----------------------------------------------------------------------
class InstanceGroup(BaseModel):
    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None  # allow 'None' for image


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


__all__ = [
    "InstanceGroup",
    "ClusterDeploy",
]
EOF

echo "Done. Removed all default values in cluster_deploy.py."