"""
amoebius/models/minio.py

Holds all Pydantic models (and Enums) relevant to Minio usage:
  - MinioSettings
  - MinioBucketPermission (Enum)
  - MinioPolicySpec
  - MinioServiceAccountAccess
  - MinioDeployment
"""

from enum import Enum
from typing import List
from pydantic import BaseModel, Field


class MinioSettings(BaseModel):
    """
    Represents connection settings to a Minio server.

    Attributes:
        url (str): Full endpoint, e.g. "http://minio.svc:9000".
        access_key (str): The user's access key.
        secret_key (str): The user's secret key.
        secure (bool): If True => https usage, else http. Default True.
    """

    url: str = Field(..., description="Full Minio server endpoint.")
    access_key: str = Field(..., description="Minio access key (username).")
    secret_key: str = Field(..., description="Minio secret key (password).")
    secure: bool = Field(True, description="If True => use https (default).")


class MinioBucketPermission(str, Enum):
    """
    Enum for bucket-level permissions in Minio.
    """

    NONE = "none"
    READ = "read"
    WRITE = "write"
    READWRITE = "readwrite"


class MinioPolicySpec(BaseModel):
    """
    Represents a single bucket + permission pair for building a policy.

    Attributes:
        bucket_name (str): The bucket's name in Minio.
        permission (MinioBucketPermission): The permission level for this bucket.
    """

    bucket_name: str
    permission: MinioBucketPermission


class MinioServiceAccountAccess(BaseModel):
    """
    Represents a single Kubernetes SA's intended Minio bucket permissions.

    Attributes:
        service_account_name (str): The K8s service account name.
        bucket_permissions (List[MinioPolicySpec]): The bucket+permission list for this SA.
    """

    service_account_name: str
    bucket_permissions: List[MinioPolicySpec]


class MinioDeployment(BaseModel):
    """
    A declarative, idempotent model describing all aspects of a Minio deployment,
    including which buckets to create, and which K8s service accounts get which perms.

    Attributes:
        minio_root_bucket (str): A default or admin-level bucket name.
        service_accounts (List[MinioServiceAccountAccess]): The SAs and their bucket perms.
    """

    minio_root_bucket: str = "amoebius"
    service_accounts: List[MinioServiceAccountAccess] = []
