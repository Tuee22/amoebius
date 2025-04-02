"""
amoebius/models/k8s.py

Defines Pydantic models representing Kubernetes objects, such as ServiceAccounts,
and now KubectlCommand (moved from models/ssh.py).
"""

from __future__ import annotations
from typing import Optional, List, Dict
from pydantic import BaseModel, Field


class KubernetesServiceAccount(BaseModel):
    """Represents a Kubernetes ServiceAccount with namespace and name."""

    namespace: str = Field(..., description="Kubernetes namespace.")
    name: str = Field(..., description="Kubernetes service account name.")

    class Config:
        frozen = True


class KubectlCommand(BaseModel):
    """
    Describes a 'kubectl exec' command: namespace, pod, container, etc.

    We can also pass environment variables, which become "env KEY=VAL" inside the exec.
    """

    namespace: str
    pod: str
    container: Optional[str] = None
    command: List[str]
    env: Optional[Dict[str, str]] = None

    def build_kubectl_args(self) -> List[str]:
        """
        Construct the final argument list for "kubectl exec ..."

        Returns:
            A list of tokens, e.g. ["kubectl","exec","mypod","-n","default","--","env","FOO=bar",...].
        """
        base = ["kubectl", "exec", self.pod, "-n", self.namespace]

        if self.container:
            base += ["-c", self.container]

        base.append("--")

        if self.env:
            env_part = ["env"] + [f"{k}={v}" for k, v in self.env.items()]
            base += env_part

        base += self.command
        return base
