"""
amoebius/models/rke2.py

Defines Pydantic models for RKE2 usage:
 - RKE2Instance
 - RKE2InstancesOutput
 - RKE2Credentials
"""

from __future__ import annotations

from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class RKE2Instance(BaseModel):
    """
    One VM's essential data for RKE2 deployment.

    Attributes:
        name: VM name or unique ID
        private_ip: VM's private IP
        public_ip: optional
        vault_path: Vault path referencing SSH credentials
        has_gpu: True if GPU is present
    """

    name: str
    private_ip: str
    public_ip: Optional[str] = None
    vault_path: str
    has_gpu: bool = False


class RKE2InstancesOutput(BaseModel):
    """
    Flattened map group_name => list[RKE2Instance], typical from TF's nested output.
    """

    instances: Dict[str, List[RKE2Instance]]


class RKE2Credentials(BaseModel):
    """
    Captures essential cluster credentials post-deploy:
      - kubeconfig
      - join_token
      - control_plane_ssh
    """

    kubeconfig: str
    join_token: str
    control_plane_ssh: Dict[str, str] = Field(default_factory=dict)
