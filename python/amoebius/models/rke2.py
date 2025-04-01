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
    Represents a single VM's essential data for RKE2 deployment.

    Attributes:
        name: VM name or unique ID for reference
        private_ip: VM's private IP address
        public_ip: VM's optional public IP address
        vault_path: Vault path referencing this VM's SSH credentials
        has_gpu: True if the instance includes an NVIDIA GPU
    """

    name: str
    private_ip: str
    public_ip: Optional[str] = None
    vault_path: str
    has_gpu: bool = False


class RKE2InstancesOutput(BaseModel):
    """
    Flattened map of group_name => list of RKE2Instance objects,
    typically derived from Terraform's nested 'instances' output.
    """

    instances: Dict[str, List[RKE2Instance]]


class RKE2Credentials(BaseModel):
    """
    Captures essential cluster credentials post-deployment:
      - kubeconfig: The admin kubeconfig YAML for the cluster
      - join_token: The RKE2 node token used by new servers/agents to join
      - control_plane_ssh_vault_path: A list of Vault paths for SSH credentials
        of all control-plane nodes, enabling multi-CP approach
    """

    kubeconfig: str
    join_token: str
    control_plane_ssh_vault_path: List[str] = Field(default_factory=list)
