"""
amoebius/secrets/APIKeys/aws.py

A Pydantic model representing AWS API credentials.
"""

from typing import Optional
from pydantic import BaseModel


class AWSApiKey(BaseModel):
    """
    A Pydantic model representing an AWS API key.

    Attributes:
        access_key_id: The AWS Access Key ID.
        secret_access_key: The AWS Secret Access Key.
        session_token: An optional session token.
    """

    access_key_id: str
    secret_access_key: str
    session_token: Optional[str] = None
