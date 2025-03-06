"""
amoebius/utils/minio.py

Provides a MinioAdminClient for performing MinIO administrative actions
(create buckets, create/delete users, attach policies, etc.) using AWS
Signature Version 4 authentication with aiohttp.
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


class MinioAdminClient:
    """An asynchronous client for MinIO Admin REST API calls using AWS SigV4 signing.

    The client reuses a single aiohttp session for performance, and
    can optionally retry on transient errors via the @async_retry decorator.

    Attributes:
        _REGION (str): Hardcoded SigV4 region placeholder (us-east-1).
        _SERVICE (str): Hardcoded SigV4 service placeholder (s3).
        _settings (MinioSettings): MinIO connection settings (URL, creds, etc.).
        _timeout (aiohttp.ClientTimeout): Total request timeout for all ops.
        _closed (bool): Tracks if the aiohttp session has been closed.
        _session (Optional[aiohttp.ClientSession]): The active aiohttp session, or None if closed.
        _signing_key_cache (Dict[str, bytes]): Cache of derived signing keys by date for SigV4.
    """

    _REGION = "us-east-1"
    _SERVICE = "s3"

    def __init__(
        self,
        settings: MinioSettings,
        total_timeout: float = 10.0,
    ) -> None:
        """Initializes the MinioAdminClient with the given settings.

        Args:
            settings (MinioSettings):
                The MinIO connection details (URL, access key, secret key).
            total_timeout (float, optional):
                Total request timeout in seconds for all operations.
                Defaults to 10.0.
        """
        self._settings = settings
        self._timeout = aiohttp.ClientTimeout(total=total_timeout)

        self._closed = False
        self._session: Optional[aiohttp.ClientSession] = None

        # Cache for derived signing keys (one per date, region, service)
        self._signing_key_cache: Dict[str, bytes] = {}

    async def __aenter__(self) -> MinioAdminClient:
        """Creates and enters an async context with an aiohttp session.

        Returns:
            MinioAdminClient: The current client instance, ready to make requests.
        """
        self._session = aiohttp.ClientSession(timeout=self._timeout)
        return self

    async def __aexit__(
        self,
        exc_type: Optional[Type[T]],
        exc_val: Optional[T],
        exc_tb: Optional[TracebackType],
    ) -> None:
        """Closes the aiohttp session when exiting the async context.

        Args:
            exc_type (Optional[Type[T]]): Exception type if raised in context.
            exc_val (Optional[T]): The exception instance if raised.
            exc_tb (Optional[TracebackType]): Traceback if an exception was raised.
        """
        await self.close()

    async def close(self) -> None:
        """Closes the underlying aiohttp session if it isn't already closed."""
        if not self._closed and self._session is not None:
            await self._session.close()
            self._closed = True

    @async_retry(retries=3, delay=1.0, noisy=True)
    async def create_bucket(self, bucket_name: str) -> None:
        """Creates a new bucket in MinIO.

        Args:
            bucket_name (str): The name of the bucket to create.

        Raises:
            RuntimeError: If the operation fails with an unexpected status code.
        """
        url = f"{self._settings.url}/{bucket_name}"
        resp_text, status = await self._make_request("PUT", url)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to create bucket '{bucket_name}'. "
                f"Status={status}, Response={resp_text}"
            )

    @async_retry(retries=3, delay=1.0, noisy=True)
    async def delete_bucket(self, bucket_name: str) -> None:
        """Deletes a bucket from MinIO.

        Args:
            bucket_name (str): The name of the bucket to delete.

        Raises:
            RuntimeError: If the operation fails with an unexpected status code.
        """
        url = f"{self._settings.url}/{bucket_name}"
        resp_text, status = await self._make_request("DELETE", url)
        if status not in (200, 204, 404):
            raise RuntimeError(
                f"Failed to delete bucket '{bucket_name}'. "
                f"Status={status}, Response={resp_text}"
            )

    @async_retry(retries=3, delay=1.0, noisy=True)
    async def create_user(self, username: str, password: str) -> None:
        """Creates a new user in MinIO.

        Args:
            username (str): The name (access key) of the new user.
            password (str): The user's secret key (password).

        Raises:
            RuntimeError: If the operation fails with an unexpected status code.
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/add-user"
            f"?accessKey={urllib.parse.quote_plus(username)}"
            f"&secretKey={urllib.parse.quote_plus(password)}"
        )
        resp_text, status = await self._make_request("POST", url)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to create user '{username}'. "
                f"Status={status}, Response={resp_text}"
            )

    @async_retry(retries=3, delay=1.0, noisy=True)
    async def delete_user(self, username: str) -> None:
        """Deletes a user from MinIO.

        Args:
            username (str): The user's name (access key).

        Raises:
            RuntimeError: If the operation fails with an unexpected status code.
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/remove-user"
            f"?accessKey={urllib.parse.quote_plus(username)}"
        )
        resp_text, status = await self._make_request("DELETE", url)
        if status not in (200, 204, 404):
            raise RuntimeError(
                f"Failed to delete user '{username}'. "
                f"Status={status}, Response={resp_text}"
            )

    @async_retry(retries=3, delay=1.0, noisy=True)
    async def create_policy(
        self, policy_name: str, policy_items: List[MinioPolicySpec]
    ) -> None:
        """Creates or updates a named policy in MinIO.

        Args:
            policy_name (str):
                The unique policy name to create or update.
            policy_items (List[MinioPolicySpec]):
                A list of bucket permissions defining the policy.

        Raises:
            RuntimeError: If the operation fails with an unexpected status code.
        """
        policy_doc = self._build_policy_json(policy_items)
        url = (
            f"{self._settings.url}/minio/admin/v3/add-canned-policy"
            f"?name={urllib.parse.quote_plus(policy_name)}"
        )
        resp_text, status = await self._make_request("POST", url, body=policy_doc)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to create or update policy '{policy_name}'. "
                f"Status={status}, Response={resp_text}"
            )

    @async_retry(retries=3, delay=1.0, noisy=True)
    async def delete_policy(self, policy_name: str) -> None:
        """Deletes a named policy from MinIO.

        Args:
            policy_name (str): The unique policy name to delete.

        Raises:
            RuntimeError: If the operation fails with an unexpected status code.
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/remove-canned-policy"
            f"?name={urllib.parse.quote_plus(policy_name)}"
        )
        resp_text, status = await self._make_request("DELETE", url)
        if status not in (200, 204, 404):
            raise RuntimeError(
                f"Failed to delete policy '{policy_name}'. "
                f"Status={status}, Response={resp_text}"
            )

    @async_retry(retries=3, delay=1.0, noisy=True)
    async def attach_policy_to_user(self, username: str, policy_name: str) -> None:
        """Attaches an existing policy to a user in MinIO.

        Args:
            username (str): The user's name (access key).
            policy_name (str): The name of the policy to attach.

        Raises:
            RuntimeError: If the operation fails with an unexpected status code.
        """
        url = (
            f"{self._settings.url}/minio/admin/v3/set-user-policy"
            f"?accessKey={urllib.parse.quote_plus(username)}"
            f"&name={urllib.parse.quote_plus(policy_name)}"
        )
        resp_text, status = await self._make_request("POST", url)
        if status not in (200, 204):
            raise RuntimeError(
                f"Failed to attach policy '{policy_name}' "
                f"to user '{username}'. Status={status}, Response={resp_text}"
            )

    # ------------------------------------------------------------------------
    # Internal Logic
    # ------------------------------------------------------------------------
    async def _make_request(
        self,
        method: str,
        url: str,
        *,
        body: Optional[str] = None,
    ) -> Tuple[str, int]:
        """Makes an HTTP request with SigV4 signing and custom timeouts.

        The retry logic is handled externally by the @async_retry decorator.

        Args:
            method (str):
                The HTTP method to use (e.g., 'GET', 'POST', 'PUT', 'DELETE').
            url (str):
                The full request URL (including query parameters).
            body (Optional[str], optional):
                A JSON string to send as the request body. Defaults to None.

        Returns:
            Tuple[str, int]:
                A tuple containing the response text and the HTTP status code.

        Raises:
            RuntimeError: If a 5xx status is encountered, triggering a retry.
            RuntimeError: If the client session is closed or unavailable.
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
        """Signs a request using AWS Signature Version 4 (S3-compatible).

        Args:
            method (str):
                The HTTP method (e.g., 'GET', 'POST').
            url (str):
                The full request URL with query parameters.
            body (bytes):
                The request body bytes (for hashing).

        Returns:
            Dict[str, str]:
                A dictionary of headers, including Authorization, X-Amz-Date,
                and X-Amz-Content-Sha256.
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
        """Retrieves or derives the SigV4 signing key for the given date.

        Args:
            date_stamp (str):
                The date in 'YYYYMMDD' format, e.g. '20230925'.

        Returns:
            bytes:
                The derived signing key used to sign the string-to-sign.
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
        """Builds an S3-style JSON policy document from a list of bucket permissions.

        Args:
            policy_items (List[MinioPolicySpec]):
                A list of (bucket_name, permission) pairs.

        Returns:
            str:
                A JSON string representing the policy, suitable for MinIO admin calls.
        """
        # Map each enum permission to the corresponding S3 actions
        PERMISSION_ACTIONS = {
            MinioBucketPermission.READ: ["s3:GetObject"],
            MinioBucketPermission.WRITE: ["s3:PutObject"],
            MinioBucketPermission.READWRITE: ["s3:GetObject", "s3:PutObject"],
        }

        statements = [
            {
                "Effect": "Allow",
                "Action": PERMISSION_ACTIONS[item.permission],
                "Resource": f"arn:aws:s3:::{item.bucket_name}/*",
            }
            for item in policy_items
            if item.permission in PERMISSION_ACTIONS
        ]

        doc = {
            "Version": "2012-10-17",
            "Statement": statements,
        }
        return json.dumps(doc, indent=2)


async def _demo() -> None:
    """Demonstrates usage of MinioAdminClient in a test scenario."""
    from amoebius.models.minio import MinioSettings

    # Example credentials
    settings = MinioSettings(
        url="http://localhost:9000",
        access_key="admin",
        secret_key="admin123",
        secure=False,
    )

    async with MinioAdminClient(settings) as client:
        bucket_name = "demo-bucket"
        await client.create_bucket(bucket_name)
        # ... do more operations ...
        await client.delete_bucket(bucket_name)


if __name__ == "__main__":
    asyncio.run(_demo())
