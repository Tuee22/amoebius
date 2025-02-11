from pydantic import BaseModel, Field


class AzureCredentials(BaseModel):
    client_id: str = Field(
        ..., title="Client ID", description="Azure Application (Client) ID"
    )
    client_secret: str = Field(
        ..., title="Client Secret", description="Azure Client Secret Value"
    )
    tenant_id: str = Field(
        ..., title="Tenant ID", description="Azure Directory (Tenant) ID"
    )
    subscription_id: str = Field(
        ..., title="Subscription ID", description="Azure Subscription ID"
    )
