from pydantic import BaseModel
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