"""
amoebius/utils/minio.py

Contains:
  - A placeholder S3 v4 signing approach for Minio admin REST calls.
  - Raw admin-like calls (create/delete bucket/user/policy, etc.) referencing _signed_request.
"""

import aiohttp
import hmac
import hashlib
import datetime
import urllib.parse
from typing import Dict, Any, List
from amoebius.models.minio import (
    MinioSettings,
    MinioPolicySpec,
    MinioBucketPermission,
)
from amoebius.models.validator import validate_type
import json

# -----------------------------------------------------------------------------
# Minimal S3 V4 Signer (placeholder)
# -----------------------------------------------------------------------------


def _sign_request_v4(
    method: str,
    url: str,
    region: str,
    service: str,
    access_key: str,
    secret_key: str,
    body: bytes = b"",
) -> Dict[str, str]:
    """
    Produce HTTP headers for an AWS S3 v4 style signature. A placeholder approach
    suitable for Minio's admin endpoints if they accept standard S3 signature.

    Args:
        method (str): HTTP method (e.g. "GET", "POST").
        url (str): Full endpoint URL (with query).
        region (str): AWS region. With Minio, might often be "us-east-1" placeholder.
        service (str): Usually "s3".
        access_key (str): The root or user access key.
        secret_key (str): The root or user secret key.
        body (bytes, optional): The request body bytes.

    Returns:
        Dict[str, str]: A dict of headers, including "Authorization" and "x-amz-date".

    Note:
        Real usage with Minio admin might differ. Adjust as needed.
    """
    # This is an intentionally minimal approach that might work if Minio
    # admin endpoints accept standard s3 v4 signatures for admin calls.

    # 1) parse host, path, queries
    parsed = urllib.parse.urlparse(url)
    host = parsed.netloc
    canonical_uri = parsed.path or "/"
    canonical_query = parsed.query  # we won't re-sort, keep as is

    # 2) times
    now_utc = datetime.datetime.utcnow()
    amz_date = now_utc.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now_utc.strftime("%Y%m%d")

    # 3) payload hash
    payload_hash = hashlib.sha256(body).hexdigest()

    # 4) build canonical headers
    canonical_headers = (
        f"host:{host}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    signed_headers = "host;x-amz-content-sha256;x-amz-date"

    # 5) canonical request
    canonical_request = (
        f"{method}\n"
        f"{canonical_uri}\n"
        f"{canonical_query}\n"
        f"{canonical_headers}\n"
        f"{signed_headers}\n"
        f"{payload_hash}"
    )
    cr_hash = hashlib.sha256(canonical_request.encode("utf-8")).hexdigest()

    # 6) string to sign
    algorithm = "AWS4-HMAC-SHA256"
    credential_scope = f"{date_stamp}/{region}/{service}/aws4_request"
    string_to_sign = (
        f"{algorithm}\n" f"{amz_date}\n" f"{credential_scope}\n" f"{cr_hash}"
    )

    # 7) sign
    def _sign(key: bytes, msg: str) -> bytes:
        return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

    k_date = _sign(("AWS4" + secret_key).encode("utf-8"), date_stamp)
    k_region = _sign(k_date, region)
    k_service = _sign(k_region, service)
    k_signing = _sign(k_service, "aws4_request")
    signature = hmac.new(
        k_signing, string_to_sign.encode("utf-8"), hashlib.sha256
    ).hexdigest()

    authorization_header = (
        f"{algorithm} Credential={access_key}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, "
        f"Signature={signature}"
    )

    return {
        "Host": host,
        "X-Amz-Date": amz_date,
        "X-Amz-Content-Sha256": payload_hash,
        "Authorization": authorization_header,
    }


async def _signed_request(
    method: str,
    url: str,
    settings: MinioSettings,
    data: bytes = b"",
) -> aiohttp.ClientResponse:
    """
    Perform an HTTP request with minimal S3 V4 signing headers for Minio admin usage.

    Args:
        method (str): e.g. "GET", "PUT", ...
        url (str): The full URL with query.
        settings (MinioSettings): Contains access_key, secret_key, url, secure usage.
        data (bytes, optional): Request body bytes.

    Returns:
        ClientResponse: The aiohttp response object.
    """
    # region=us-east-1, service=s3 => placeholders for Minio usage
    # Real usage might require different region or service name.
    region = "us-east-1"
    service = "s3"

    headers = _sign_request_v4(
        method=method,
        url=url,
        region=region,
        service=service,
        access_key=settings.access_key,
        secret_key=settings.secret_key,
        body=data,
    )

    # Prepare the session request
    async with aiohttp.ClientSession() as session:
        req_func = {
            "GET": session.get,
            "POST": session.post,
            "PUT": session.put,
            "DELETE": session.delete,
        }.get(method.upper())

        if not req_func:
            raise ValueError(f"Unsupported method {method}")

        resp = await req_func(url, headers=headers, data=data)
        return resp


def build_policy_json(policy_items: List[MinioPolicySpec]) -> str:
    """
    Same as before: build a minimal JSON doc for the S3-style policy.
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
    Create a bucket in Minio with S3 v4-signed PUT.
    """
    put_url = f"{settings.url}/{bucket_name}"
    resp = await _signed_request("PUT", put_url, settings)
    async with resp:
        if resp.status not in (200, 204):
            text = await resp.text()
            raise RuntimeError(
                f"Failed to create bucket '{bucket_name}': {resp.status}, {text}"
            )


async def delete_bucket(settings: MinioSettings, bucket_name: str) -> None:
    """
    Delete a bucket in Minio with S3 v4-signed DELETE.
    """
    del_url = f"{settings.url}/{bucket_name}"
    resp = await _signed_request("DELETE", del_url, settings)
    async with resp:
        if resp.status not in (200, 204, 404):
            text = await resp.text()
            raise RuntimeError(
                f"Failed to delete bucket '{bucket_name}': {resp.status}, {text}"
            )


async def create_policy(
    settings: MinioSettings, policy_name: str, policy_items: List[MinioPolicySpec]
) -> None:
    """
    Create or update a named policy in Minio. Using S3 v4-signed POST to /minio/admin/v3/add-canned-policy.
    """
    policy_json = build_policy_json(policy_items)
    admin_url = f"{settings.url}/minio/admin/v3/add-canned-policy?name={policy_name}"
    resp = await _signed_request(
        "POST", admin_url, settings, data=policy_json.encode("utf-8")
    )
    async with resp:
        if resp.status not in (200, 204):
            text = await resp.text()
            raise RuntimeError(
                f"Failed to create policy '{policy_name}': {resp.status}, {text}"
            )


async def delete_policy(settings: MinioSettings, policy_name: str) -> None:
    """
    Delete a named policy in Minio with S3 v4-signed DELETE.
    """
    admin_url = f"{settings.url}/minio/admin/v3/remove-canned-policy?name={policy_name}"
    resp = await _signed_request("DELETE", admin_url, settings)
    async with resp:
        if resp.status not in (200, 204, 404):
            text = await resp.text()
            raise RuntimeError(
                f"Failed to delete policy '{policy_name}': {resp.status}, {text}"
            )


async def create_user(settings: MinioSettings, username: str, password: str) -> None:
    """
    Create a user in Minio. S3 v4-signed POST to /minio/admin/v3/add-user?accessKey=...&secretKey=...
    """
    admin_url = f"{settings.url}/minio/admin/v3/add-user?accessKey={username}&secretKey={password}"
    resp = await _signed_request("POST", admin_url, settings)
    async with resp:
        if resp.status not in (200, 204):
            text = await resp.text()
            raise RuntimeError(
                f"Failed to create user '{username}': {resp.status}, {text}"
            )


async def delete_user(settings: MinioSettings, username: str) -> None:
    """
    Delete a user in Minio.
    """
    admin_url = f"{settings.url}/minio/admin/v3/remove-user?accessKey={username}"
    resp = await _signed_request("DELETE", admin_url, settings)
    async with resp:
        if resp.status not in (200, 204, 404):
            text = await resp.text()
            raise RuntimeError(
                f"Failed to delete user '{username}': {resp.status}, {text}"
            )


async def attach_policy_to_user(
    settings: MinioSettings, username: str, policy_name: str
) -> None:
    """
    Attach a named policy to a user in Minio.
    """
    admin_url = f"{settings.url}/minio/admin/v3/set-user-policy?accessKey={username}&name={policy_name}"
    resp = await _signed_request("POST", admin_url, settings)
    async with resp:
        if resp.status not in (200, 204):
            text = await resp.text()
            raise RuntimeError(
                f"Failed to attach policy '{policy_name}' to user '{username}': {resp.status}, {text}"
            )
