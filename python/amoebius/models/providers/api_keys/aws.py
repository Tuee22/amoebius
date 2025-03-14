"""
filename: amoebius/models/providers/api_keys/aws.py

Provides the AWSApiKey pydantic model for credentials.
"""

from typing import Dict, Optional
from pydantic import BaseModel


class AWSApiKey(BaseModel):
    """Pydantic model for AWSApiKey credentials."""

    access_key_id: str
    secret_access_key: str
    session_token: Optional[str] = None

    def to_env_dict(self) -> Dict[str, str]:
        """Converts credentials to a dictionary of environment variables.

        Returns:
            Dict[str, str]: A dictionary containing AWS environment variables.
        """
        env = {
            "AWS_ACCESS_KEY_ID": self.access_key_id,
            "AWS_SECRET_ACCESS_KEY": self.secret_access_key,
        }
        if self.session_token:
            env["AWS_SESSION_TOKEN"] = self.session_token
        return env


__all__ = ["AWSApiKey"]
