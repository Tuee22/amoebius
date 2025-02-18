"""
Stub re-export for AWSApiKey, preserving old import paths if code references
`from amoebius.models.providers.api_keys.aws import AWSApiKey`.
Points to the real definition in `amoebius.models.providers.deploy.aws`.
"""

from amoebius.models.providers.deploy.aws import AWSApiKey

__all__ = ["AWSApiKey"]
