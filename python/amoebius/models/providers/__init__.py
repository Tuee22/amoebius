"""
amoebius.models.providers

Unified aggregator import for:
- ProviderName
- The environment dispatch
- The cluster deploy classes (AWSClusterDeploy, etc.) and credentials (AWSApiKey, etc.)
- A provider_model_map for tests (mapping ProviderName -> specific cluster class).
"""

from enum import Enum
from typing import Dict, Any, Callable, Type

# Deploy subpackage
from amoebius.models.cluster_deploy import ClusterDeploy
from amoebius.models.providers.deploy.aws import AWSClusterDeploy
from amoebius.models.providers.deploy.azure import AzureClusterDeploy
from amoebius.models.providers.deploy.gcp import GCPClusterDeploy
from amoebius.models.providers.deploy.aws import AWSApiKey
from amoebius.models.providers.deploy.azure import AzureCredentials
from amoebius.models.providers.deploy.gcp import GCPServiceAccountKey


# --------------------------
# 1) ProviderName
# --------------------------
class ProviderName(str, Enum):
    aws = "aws"
    azure = "azure"
    gcp = "gcp"


# --------------------------
# 2) Dictionary-based ENV dispatch
# --------------------------
def _aws_env(raw: Dict[str, Any]) -> Dict[str, str]:
    return AWSApiKey(**raw).to_env_dict()


def _azure_env(raw: Dict[str, Any]) -> Dict[str, str]:
    return AzureCredentials(**raw).to_env_dict()


def _gcp_env(raw: Dict[str, Any]) -> Dict[str, str]:
    return GCPServiceAccountKey(**raw).to_env_dict()


ENV_MODEL_MAP: Dict[ProviderName, Callable[[Dict[str, Any]], Dict[str, str]]] = {
    ProviderName.aws: _aws_env,
    ProviderName.azure: _azure_env,
    ProviderName.gcp: _gcp_env,
}


def get_provider_env_from_secret_data(
    provider: ProviderName, raw_data: Dict[str, Any]
) -> Dict[str, str]:
    if provider not in ENV_MODEL_MAP:
        raise ValueError(f"Unsupported provider: {provider}")
    return ENV_MODEL_MAP[provider](raw_data)


# --------------------------
# 3) provider_model_map for test usage
# --------------------------
provider_model_map: Dict[ProviderName, Type[ClusterDeploy]] = {
    ProviderName.aws: AWSClusterDeploy,
    ProviderName.azure: AzureClusterDeploy,
    ProviderName.gcp: GCPClusterDeploy,
}


__all__ = [
    "ProviderName",
    "AWSClusterDeploy",
    "AWSApiKey",
    "AzureClusterDeploy",
    "AzureCredentials",
    "GCPClusterDeploy",
    "GCPServiceAccountKey",
    "get_provider_env_from_secret_data",
    "provider_model_map",
]
