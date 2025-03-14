"""
filename: amoebius/models/providers/api_keys/azure.py

Provides the AzureCredentials pydantic model for credentials.
"""

from typing import Dict
from pydantic import BaseModel, Field


class AzureCredentials(BaseModel):
    """Pydantic model for AzureCredentials."""

    client_id: str = Field(..., description="Azure Client ID")
    client_secret: str = Field(..., description="Azure Client Secret")
    tenant_id: str = Field(..., description="Azure Tenant ID")
    subscription_id: str = Field(..., description="Azure Subscription ID")

    def to_env_dict(self) -> Dict[str, str]:
        """Converts Azure credentials to environment variables.

        Returns:
            Dict[str, str]: A dictionary containing ARM_* environment variables.
        """
        return {
            "ARM_CLIENT_ID": self.client_id,
            "ARM_CLIENT_SECRET": self.client_secret,
            "ARM_TENANT_ID": self.tenant_id,
            "ARM_SUBSCRIPTION_ID": self.subscription_id,
        }


__all__ = ["AzureCredentials"]
