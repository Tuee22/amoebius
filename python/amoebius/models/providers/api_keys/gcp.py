"""
filename: amoebius/models/providers/api_keys/gcp.py

Provides the GCPServiceAccountKey pydantic model for credentials.
"""

import json
from typing import Dict, Literal
from pydantic import BaseModel, Field


class GCPServiceAccountKey(BaseModel):
    """Pydantic model for GCP service account credentials."""

    type: Literal["service_account"]
    project_id: str
    private_key_id: str
    private_key: str
    client_email: str
    client_id: str
    auth_uri: str
    token_uri: str
    auth_provider_x509_cert_url: str
    client_x509_cert_url: str
    universe_domain: str = Field(..., description="Typically 'googleapis.com'")

    def to_env_dict(self) -> Dict[str, str]:
        """Converts GCP service account key to environment variables.

        Returns:
            Dict[str, str]: A dictionary containing GOOGLE_CREDENTIALS and GOOGLE_PROJECT.
        """
        return {
            "GOOGLE_CREDENTIALS": json.dumps(self.model_dump()),
            "GOOGLE_PROJECT": self.project_id,
        }


__all__ = ["GCPServiceAccountKey"]
