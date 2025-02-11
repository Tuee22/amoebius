from pydantic import BaseModel


class AzureCredentials(BaseModel):
    subscription_id: str
    client_id: str
    client_secret: str
    tenant_id: str
