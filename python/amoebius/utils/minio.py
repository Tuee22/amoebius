"""
amoebius/utils/minio.py

Contains raw "admin-like" HTTP calls to Minio (create/delete bucket, etc.),
plus a helper to build JSON policies. No Vault references here.
"""

import json
import aiohttp
from typing import List, Any

from amoebius.models.minio import (
    MinioSettings,
    MinioPolicySpec,
    MinioBucketPermission,
)


def build_policy_json(policy_items: List[MinioPolicySpec]) -> str:
    """
    Build a minimal JSON policy document from a list of bucket+permission specs.

    Args:
        policy_items (List[MinioPolicySpec]):
            The bucket name + permission pairs for the policy.

    Returns:
        str: The JSON policy document. Real usage in S3/Minio is more detailed.
    """
    statements = []
    for item in policy_items:
        if item.permission == MinioBucketPermission.NONE:
            continue
        elif item.permission == MinioBucketPermission.READ:
            actions = ["s3:GetObject"]
        elif item.permission == MinioBucketPermission.WRITE:
            actions = ["s3:PutObject"]
        else:
            actions = ["s3:GetObject", "s3:PutObject"]

        statements.append(
            {
                "Effect": "Allow",
                "Action": actions,
                "Resource": f"arn:aws:s3:::{item.bucket_name}/*",
            }
        )

    doc = {
        "Version": "2012-10-17",
        "Statement": statements,
    }
    return json.dumps(doc, indent=2)


async def create_bucket(settings: MinioSettings, bucket_name: str) -> None:
    """
    Creates a bucket in Minio using naive HTTP. Real usage needs proper auth.

    Args:
        settings (MinioSettings): Connection info.
        bucket_name (str): Name of the bucket to create.

    Raises:
        RuntimeError: If creation fails (non-200,204).
    """
    endpoint = settings.url
    async with aiohttp.ClientSession() as session:
        put_url = f"{endpoint}/{bucket_name}"
        async with session.put(put_url) as resp:
            if resp.status not in (200, 204):
                text = await resp.text()
                raise RuntimeError(
                    f"Failed to create bucket '{bucket_name}': {resp.status}, {text}"
                )


async def delete_bucket(settings: MinioSettings, bucket_name: str) -> None:
    """
    Deletes a bucket in Minio. Placeholder logic.

    Args:
        settings (MinioSettings): Connection info.
        bucket_name (str): Bucket to delete.

    Raises:
        RuntimeError: If deletion fails or returns an unexpected status.
    """
    endpoint = settings.url
    async with aiohttp.ClientSession() as session:
        del_url = f"{endpoint}/{bucket_name}"
        async with session.delete(del_url) as resp:
            if resp.status not in (200, 204, 404):
                text = await resp.text()
                raise RuntimeError(
                    f"Failed to delete bucket '{bucket_name}': {resp.status}, {text}"
                )


async def create_policy(
    settings: MinioSettings, policy_name: str, policy_items: List[MinioPolicySpec]
) -> None:
    """
    Creates or updates a named policy in Minio.

    Args:
        settings (MinioSettings): Connection info.
        policy_name (str): The policy name to create/update.
        policy_items (List[MinioPolicySpec]): Bucket permissions for the policy.

    Raises:
        RuntimeError: If policy creation fails.
    """
    policy_json = build_policy_json(policy_items)
    endpoint = settings.url
    async with aiohttp.ClientSession() as session:
        admin_url = f"{endpoint}/minio/admin/v3/add-canned-policy?name={policy_name}"
        async with session.post(admin_url, data=policy_json) as resp:
            if resp.status not in (200, 204):
                text = await resp.text()
                raise RuntimeError(
                    f"Failed to create policy '{policy_name}': {resp.status}, {text}"
                )


async def delete_policy(settings: MinioSettings, policy_name: str) -> None:
    """
    Deletes a named policy in Minio.

    Args:
        settings (MinioSettings): Connection info.
        policy_name (str): The policy to delete.

    Raises:
        RuntimeError: If deletion fails unexpectedly.
    """
    endpoint = settings.url
    async with aiohttp.ClientSession() as session:
        admin_url = f"{endpoint}/minio/admin/v3/remove-canned-policy?name={policy_name}"
        async with session.delete(admin_url) as resp:
            if resp.status not in (200, 204, 404):
                text = await resp.text()
                raise RuntimeError(
                    f"Failed to delete policy '{policy_name}': {resp.status}, {text}"
                )


async def create_user(settings: MinioSettings, username: str, password: str) -> None:
    """
    Creates a user in Minio with naive HTTP. Real usage needs auth.

    Args:
        settings (MinioSettings): Connection info.
        username (str): The new user name.
        password (str): The user's secret password.

    Raises:
        RuntimeError: If user creation fails.
    """
    endpoint = settings.url
    async with aiohttp.ClientSession() as session:
        admin_url = f"{endpoint}/minio/admin/v3/add-user?accessKey={username}&secretKey={password}"
        async with session.post(admin_url) as resp:
            if resp.status not in (200, 204):
                text = await resp.text()
                raise RuntimeError(
                    f"Failed to create user '{username}': {resp.status}, {text}"
                )


async def delete_user(settings: MinioSettings, username: str) -> None:
    """
    Deletes a user in Minio.

    Args:
        settings (MinioSettings): Connection info.
        username (str): The user to delete.

    Raises:
        RuntimeError: If user deletion fails.
    """
    endpoint = settings.url
    async with aiohttp.ClientSession() as session:
        admin_url = f"{endpoint}/minio/admin/v3/remove-user?accessKey={username}"
        async with session.delete(admin_url) as resp:
            if resp.status not in (200, 204, 404):
                text = await resp.text()
                raise RuntimeError(
                    f"Failed to delete user '{username}': {resp.status}, {text}"
                )


async def attach_policy_to_user(
    settings: MinioSettings, username: str, policy_name: str
) -> None:
    """
    Attaches a named policy to a user in Minio.

    Args:
        settings (MinioSettings): Connection info.
        username (str): The user name to attach the policy to.
        policy_name (str): The policy name.

    Raises:
        RuntimeError: If the operation fails.
    """
    endpoint = settings.url
    async with aiohttp.ClientSession() as session:
        admin_url = f"{endpoint}/minio/admin/v3/set-user-policy?accessKey={username}&name={policy_name}"
        async with session.post(admin_url) as resp:
            if resp.status not in (200, 204):
                text = await resp.text()
                raise RuntimeError(
                    f"Failed to attach policy '{policy_name}' to user '{username}': {resp.status}, {text}"
                )
