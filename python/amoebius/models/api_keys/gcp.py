from pydantic import BaseModel, Field
from typing import Literal


class GCPServiceAccountKey(BaseModel):
    """
    Model for a full GCP Service Account JSON key as downloaded from the console.
    """

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
