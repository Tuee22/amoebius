"""
__init__.py for amoebius.models.providers

We define aggregator imports for AWSClusterDeploy, AzureClusterDeploy, GCPClusterDeploy
and provide a Union type for type checking.
"""

from typing import Type, Union
from .aws import AWSClusterDeploy
from .azure import AzureClusterDeploy
from .gcp import GCPClusterDeploy
from amoebius.models.cluster_deploy import ClusterDeploy

# Define a Union type for supported ClusterDeploy models
ClusterDeployModel = Union[
    Type[AWSClusterDeploy], Type[AzureClusterDeploy], Type[GCPClusterDeploy]
]

__all__ = [
    "AWSClusterDeploy",
    "AzureClusterDeploy",
    "GCPClusterDeploy",
    "ClusterDeployModel",
]
