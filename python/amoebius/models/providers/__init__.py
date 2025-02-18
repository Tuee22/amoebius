"""
amoebius.models.providers

Unified aggregator import for:
- ProviderName
- The environment dispatch
- The cluster deploy classes (AWSClusterDeploy, etc.)
- The credentials (AWSApiKey, etc.)
(without referencing provider_model_map to avoid circular import).
"""

from enum import Enum
from typing import Dict, Any, Callable

from amoebius.models.providers.deploy.aws import AWSClusterDeploy, AWSApiKey
from amoebius.models.providers.deploy.azure import AzureClusterDeploy, AzureCredentials
from amoebius.models.providers.deploy.gcp import GCPClusterDeploy, GCPServiceAccountKey


class ProviderName(str, Enum):
    aws = "aws"
    azure = "azure"
    gcp = "gcp"


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


__all__ = [
    "ProviderName",
    "AWSClusterDeploy",
    "AWSApiKey",
    "AzureClusterDeploy",
    "AzureCredentials",
    "GCPClusterDeploy",
    "GCPServiceAccountKey",
    "get_provider_env_from_secret_data",
]
