from pydantic import BaseModel
from pydantic_settings import BaseSettings
from typing import List


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


class VaultSettings(BaseSettings):
    """
    Pydantic settings for configuring the Vault client.
    By default, these fields map to environment variables prefixed with `VAULT_`.
    For example, `VAULT_ROLE_NAME`, `VAULT_ADDR`, etc.
    """

    vault_role_name: str  # No default => must be set (e.g., VAULT_ROLE_NAME)
    vault_addr: str = "http://vault.vault.svc.cluster.local:8200"
    token_path: str = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    verify_ssl: bool = True
    renew_threshold_seconds: float = 60.0
    check_interval_seconds: float = 60.0

    class Config:
        # This means if you set `VAULT_ROLE_NAME="my-role"`,
        # it populates vault_role_name automatically.
        env_prefix = "VAULT_"
        # You can also parse .env files by setting `env_file = ".env"` etc.
