"""
amoebius/secrets/APIKeys/aws.py
A Pydantic model representing AWS API credentials.
"""

from typing import Optional
from pydantic import BaseModel


class AWSApiKey(BaseModel):
    access_key_id: str
    secret_access_key: str
    session_token: Optional[str] = None
