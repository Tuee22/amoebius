"""
amoebius/models/k8s.py

Defines Pydantic models representing Kubernetes objects, such as ServiceAccounts.
"""

from pydantic import BaseModel, Field


class KubernetesServiceAccount(BaseModel):
    """Represents a Kubernetes ServiceAccount with namespace and name."""

    namespace: str = Field(..., description="Kubernetes namespace.")
    name: str = Field(..., description="Kubernetes service account name.")

    class Config:
        frozen = True
