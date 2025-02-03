# models.py

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Dict


class SSHConfig(BaseModel):
    """
    SSH configuration for connecting to a remote host.
    If host_keys is empty => no known keys => must do TOFU or fail in strict mode.
    """

    user: str
    hostname: str
    port: int = Field(default=22, ge=1, le=65535)
    private_key: str
    host_keys: Optional[List[str]] = None  # If None/empty => no known keys

    @field_validator("private_key")
    @classmethod
    def validate_private_key(cls, val: str) -> str:
        if not val.strip():
            raise ValueError("private_key must be a non-empty string")
        return val


class KubectlCommand(BaseModel):
    """
    Describes a 'kubectl exec' command: namespace, pod, container, etc.
    """

    namespace: str
    pod: str
    container: Optional[str] = None
    command: List[str]
    env: Optional[Dict[str, str]] = None

    def build_kubectl_args(self) -> List[str]:
        base = ["kubectl", "exec", self.pod, "-n", self.namespace]

        if self.container:
            base += ["-c", self.container]

        base.append("--")

        if self.env:
            env_part = ["env"] + [f"{k}={v}" for k, v in self.env.items()]
            base += env_part

        base += self.command
        return base
