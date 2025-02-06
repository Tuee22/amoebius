from __future__ import annotations

from typing import Optional, List
from pydantic import BaseModel, Field
from pydantic.functional_validators import model_validator


class VaultSettings(BaseModel):
    vault_addr: str = Field(default="http://vault.vault.svc.cluster.local:8200")
    vault_role_name: Optional[str] = None
    token_path: str = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    verify_ssl: bool = True
    renew_threshold_seconds: float = 60.0
    check_interval_seconds: float = 30.0
    direct_vault_token: Optional[str] = None

    @model_validator(mode="after")
    def check_exclusivity(self) -> VaultSettings:
        """
        Ensure vault_role_name and direct_vault_token are not both set.
        Runs after fields are validated, returning 'self' or raising an error.
        """
        if self.vault_role_name and self.direct_vault_token:
            raise ValueError(
                "vault_role_name and direct_vault_token are mutually exclusive."
            )
        return self


class VaultInitData(BaseModel):
    unseal_keys_b64: List[str]
    unseal_keys_hex: List[str]
    unseal_shares: int
    unseal_threshold: int
    recovery_keys_b64: List[str]
    recovery_keys_hex: List[str]
    recovery_keys_shares: int
    recovery_keys_threshold: int
    root_token: str
