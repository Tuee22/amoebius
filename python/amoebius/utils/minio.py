"""
amoebius/utils/minio.py

Provides a MinioAdminClient for performing MinIO administrative actions using
AWS Signature Version 4 (S3-compatible) authentication with aiohttp.

Features:
    - create_bucket (idempotent if bucket exists)
    - create_user (idempotent if user already exists)
    - update_user_password (upsert in some MinIO versions)
    - create_policy (create/update a named policy)
    - attach_policy_to_user
    - delete_user (destructive, raises on 404)
    - delete_policy (destructive, raises on 404)
"""

from __future__ import annotations

import asyncio
import datetime
import hashlib
import hmac
import json
import urllib.parse
from types import TracebackType
from typing import Dict, List, Optional, Tuple, Type, TypeVar

import aiohttp

from amoebius.utils.async_retry import async_retry
from amoebius.models.minio import (
    MinioSettings,
    MinioPolicySpec,
    MinioBucketPermission,
)

T = TypeVar("T", bound=BaseException)

# Constants for standardized retries
RETRIES = 3


class MinioAdminClient:
    """
    An asynchronous client for MinIO Admin REST API calls (S3-compatible SigV4).

    This client manages:
      - Bucket creation
      - User creation/update/delete
      - Policy creation/update/delete
      - Attaching policies to users

    The client reuses a single aiohttp session for performance and can optionally retry on
    transient errors via the @async_retry decorator.
    """

    _REGION = "us-east-1"
    _SERVICE = "s3"

    def __init__(
        self,
        settings: MinioSettings,
        total_timeout: float = 10.0,
    ) -> None:
        """
        Initialize the MinioAdminClient.

        Args:
            settings (MinioSettings):
                Connection details (endpoint, access_key, secret_key, etc.).
            total_timeout (float, optional):
                Total request timeout in seconds. Defaults to 10.0.
        """
        self._settings = settings
        self._timeout = aiohttp.ClientTimeout(total=total_timeout)
        self._closed = False
        self._session: Optional[aiohttp.ClientSession] = None
        self._signing_key_cache: Dict[str, bytes] = {}

    async def __aenter__(self) -> MinioAdminClient:
        """
        Enter the async context, creating an aiohttp session.

        Returns:
            MinioAdminClient: self
        """
        self._session = aiohttp.ClientSession(timeout=self._timeout)
        return self

    async def __aexit__(
        self,
        exc_type: Optional[Type[T]],
        exc_val: Optional[T],
        exc_tb: Optional[TracebackType],
    ) -> None:
        """Exit the async context, closing the aiohttp session."""
        await self.close()

    async def close(self) -> None:
        """Close the internal aiohttp session if not already closed."""
        if not self._closed and self._session is not None:
            await self._session.close()
            self._closed = True

    @async_retry(retries=RETRIES)
    async def create_bucket(self, bucket_name: str) -> None:
        """
        Create a new bucket in MinIO, skipping if it already exists.

        Args:
            bucket_name (str): The bucket name.

        Raises:
            RuntimeError: If operation fails with an unexpected status code,
                          or if we can't interpret 409 as 'BucketAlreadyOwnedByYou'.
        """
        url = f"{self._settings.url}/{bucket_name}"
        resp_text, status = await self._make_request("PUT", url)
        if status not in (200, 204):
            if status == 409:
                # Check the error text to see if it's "already owned by you"
                # or "BucketAlreadyOwnedByYou"
                lower_text = resp_text.lower()
                if (
                    "already owned by you" in lower_text
                    or "bucketalreadyownedbyyou" in lower_text
                ):
                    # treat as idempotent
                    return
            raise RuntimeError(
                f"Failed to create bucket '{bucket_name}': status={status}, response={resp_text}"
            )

    @async_retry(retries=RETRIES)
    async def create_user(self, username: str, password: str) -> None:
        """
        Create a user in MinIO, ignoring if 'already exists'.

        Args:
            username (str): MinIO access key (username).
            password (str): MinIO secret key (password).

        Raises:
            RuntimeError: If creation fails or 'already exists' can't be handled.
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/add-user"
            f"?accessKey={urllib.parse.quote_plus(username)}"
            f"&secretKey={urllib.parse.quote_plus(password)}"
        )
        resp_text, status = await self._make_request("POST", url)
        if status not in (200, 204):
            if status in (409, 400) and "already exists" in resp_text.lower():
                return
            raise RuntimeError(
                f"Failed to create user '{username}': status={status}, response={resp_text}"
            )

    @async_retry(retries=RETRIES)
    async def update_user_password(self, username: str, new_password: str) -> None:
        """
        Update a user's password in MinIO (or upsert in some versions).

        Args:
            username (str): The user's MinIO access key.
            new_password (str): The new secret key (password).
        """
        # Many MinIO versions treat "add-user" as an upsert for password changes.
        await self.create_user(username, new_password)

    @async_retry(retries=RETRIES)
    async def create_policy(
        self,
        policy_name: str,
        policy_items: List[MinioPolicySpec],
    ) -> None:
        """
        Create or update a named policy in MinIO.

        Args:
            policy_name (str): The policy name.
            policy_items (List[MinioPolicySpec]): A list of bucket permission specs.

        Raises:
            RuntimeError: If creation fails or returns an unexpected status.
        """
        policy_doc = self._build_policy_json(policy_items)
        url = (
            f"{self._settings.url}/minio/admin/v3/add-canned-policy"
            f"?name={urllib.parse.quote_plus(policy_name)}"
        )
        resp_text, status = await self._make_request("POST", url, body=policy_doc)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to create/update policy '{policy_name}': "
                f"status={status}, response={resp_text}"
            )

    @async_retry(retries=RETRIES)
    async def attach_policy_to_user(self, username: str, policy_name: str) -> None:
        """
        Attach an existing policy to a user in MinIO.

        Args:
            username (str): The user's name (access key).
            policy_name (str): The MinIO policy name to attach.
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/set-user-policy"
            f"?accessKey={urllib.parse.quote_plus(username)}"
            f"&name={urllib.parse.quote_plus(policy_name)}"
        )
        resp_text, status = await self._make_request("POST", url)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to attach policy '{policy_name}' to user '{username}': "
                f"status={status}, response={resp_text}"
            )

    @async_retry(retries=RETRIES)
    async def delete_user(self, username: str) -> None:
        """
        Delete a user from MinIO, raises if user doesn't exist.

        Args:
            username (str): MinIO access key.

        Raises:
            RuntimeError: If 404 => user missing, or any unexpected status not in [200, 204].
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/remove-user"
            f"?accessKey={urllib.parse.quote_plus(username)}"
        )
        resp_text, status = await self._make_request("DELETE", url)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to delete user '{username}': status={status}, response={resp_text}"
            )

    @async_retry(retries=RETRIES)
    async def delete_policy(self, policy_name: str) -> None:
        """
        Delete a named policy from MinIO, raises if not found.

        Args:
            policy_name (str): The MinIO policy name to remove.

        Raises:
            RuntimeError: If 404 => missing policy, or unexpected status not in [200,204].
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/remove-canned-policy"
            f"?name={urllib.parse.quote_plus(policy_name)}"
        )
        resp_text, status = await self._make_request("DELETE", url)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to delete policy '{policy_name}': status={status}, response={resp_text}"
            )

    # -------------------------------------------------------------------------
    # Internal Logic
    # -------------------------------------------------------------------------
    async def _make_request(
        self,
        method: str,
        url: str,
        *,
        body: Optional[str] = None,
    ) -> Tuple[str, int]:
        """
        Make an HTTP request with SigV4 signing and optional request body.

        The @async_retry decorator handles transient failures.

        Args:
            method: The HTTP method, e.g. "GET", "POST", "PUT", "DELETE".
            url: The full request URL (including query).
            body: An optional JSON string for the request body.

        Returns:
            A tuple of (response_text, status_code).

        Raises:
            RuntimeError: If the session is closed or if we get a 5xx error => triggers a retry.
        """
        if self._session is None or self._closed:
            raise RuntimeError("Client session is not available or already closed.")

        data_bytes = body.encode("utf-8") if body else b""
        sigv4_headers = self._sign_request_v4(method, url, data_bytes)
        headers = {
            **sigv4_headers,
            "Content-Type": "application/json",
        }

        async with self._session.request(
            method,
            url,
            headers=headers,
            data=data_bytes,
        ) as response:
            resp_text = await response.text()
            status = response.status

            if 500 <= status < 600:
                raise RuntimeError(
                    f"Server error {status} from {method} {url}: {resp_text}"
                )

            return resp_text, status

    def _sign_request_v4(
        self,
        method: str,
        url: str,
        body: bytes,
    ) -> Dict[str, str]:
        """
        Sign a request using AWS Signature Version 4 for S3-compatibility.
        """
        parsed = urllib.parse.urlparse(url)
        host = parsed.netloc
        canonical_uri = parsed.path or "/"
        canonical_query = parsed.query

        now_utc = datetime.datetime.utcnow()
        amz_date = now_utc.strftime("%Y%m%dT%H%M%SZ")
        date_stamp = now_utc.strftime("%Y%m%d")

        payload_hash = hashlib.sha256(body).hexdigest()
        canonical_headers = (
            f"host:{host}\n"
            f"x-amz-content-sha256:{payload_hash}\n"
            f"x-amz-date:{amz_date}\n"
        )
        signed_headers = "host;x-amz-content-sha256;x-amz-date"

        canonical_request = (
            f"{method}\n"
            f"{canonical_uri}\n"
            f"{canonical_query}\n"
            f"{canonical_headers}\n"
            f"{signed_headers}\n"
            f"{payload_hash}"
        )
        cr_hash = hashlib.sha256(canonical_request.encode("utf-8")).hexdigest()

        algorithm = "AWS4-HMAC-SHA256"
        credential_scope = f"{date_stamp}/{self._REGION}/{self._SERVICE}/aws4_request"
        string_to_sign = f"{algorithm}\n{amz_date}\n{credential_scope}\n{cr_hash}"

        signing_key = self._get_signing_key(date_stamp)
        signature = hmac.new(
            signing_key, string_to_sign.encode("utf-8"), hashlib.sha256
        ).hexdigest()

        authorization_header = (
            f"{algorithm} Credential={self._settings.access_key}/{credential_scope}, "
            f"SignedHeaders={signed_headers}, "
            f"Signature={signature}"
        )

        return {
            "Host": host,
            "X-Amz-Date": amz_date,
            "X-Amz-Content-Sha256": payload_hash,
            "Authorization": authorization_header,
        }

    def _get_signing_key(self, date_stamp: str) -> bytes:
        """
        Retrieve or derive the SigV4 signing key for the given date.
        """
        cache_key = f"{date_stamp}-{self._REGION}-{self._SERVICE}"
        if cache_key in self._signing_key_cache:
            return self._signing_key_cache[cache_key]

        def _sign(key: bytes, msg: str) -> bytes:
            return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

        secret_bytes = self._settings.secret_key.encode("utf-8")
        k_date = _sign(b"AWS4" + secret_bytes, date_stamp)
        k_region = _sign(k_date, self._REGION)
        k_service = _sign(k_region, self._SERVICE)
        k_signing = _sign(k_service, "aws4_request")

        self._signing_key_cache[cache_key] = k_signing
        return k_signing

    def _build_policy_json(self, policy_items: List[MinioPolicySpec]) -> str:
        """
        Build an S3-style JSON policy from a list of bucket permission specs.
        """
        permission_map = {
            MinioBucketPermission.READ: ["s3:GetObject"],
            MinioBucketPermission.WRITE: ["s3:PutObject"],
            MinioBucketPermission.READWRITE: ["s3:GetObject", "s3:PutObject"],
        }

        statements = [
            {
                "Effect": "Allow",
                "Action": permission_map[item.permission],
                "Resource": f"arn:aws:s3:::{item.bucket_name}/*",
            }
            for item in policy_items
            if item.permission in permission_map
        ]

        doc = {
            "Version": "2012-10-17",
            "Statement": statements,
        }
        return json.dumps(doc, indent=2)
