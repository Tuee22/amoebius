"""
Stub re-export for AzureCredentials, preserving old import paths if code references
`from amoebius.models.providers.api_keys.azure import AzureCredentials`.
Points to the real definition in `amoebius.models.providers.deploy.azure`.
"""

from amoebius.models.providers.deploy.azure import AzureCredentials

__all__ = ["AzureCredentials"]
