"""
amoebius/models/k8s.py

Defines Pydantic models representing Kubernetes objects, such as ServiceAccounts.
"""

from pydantic import BaseModel, Field


class KubernetesServiceAccount(BaseModel):
    """Represents a Kubernetes ServiceAccount with namespace and name.

    Attributes:
        namespace (str): The Kubernetes namespace in which the SA resides.
        name (str): The name of the service account within that namespace.
    """

    namespace: str = Field(..., description="Kubernetes namespace.")
    name: str = Field(..., description="Kubernetes service account name.")
