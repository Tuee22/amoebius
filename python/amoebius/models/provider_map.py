"""
provider_map.py

Central place to define 'provider_model_map' to avoid circular imports.

Usage:
    from amoebius.models.provider_map import provider_model_map
"""

from typing import Dict, Type
from amoebius.models.cluster_deploy import ClusterDeploy
from amoebius.models.providers import ProviderName
from amoebius.models.providers.deploy.aws import AWSClusterDeploy
from amoebius.models.providers.deploy.azure import AzureClusterDeploy
from amoebius.models.providers.deploy.gcp import GCPClusterDeploy

provider_model_map: Dict[ProviderName, Type[ClusterDeploy]] = {
    ProviderName.aws: AWSClusterDeploy,
    ProviderName.azure: AzureClusterDeploy,
    ProviderName.gcp: GCPClusterDeploy,
}

__all__ = ["provider_model_map"]
