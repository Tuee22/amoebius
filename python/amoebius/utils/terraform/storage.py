"""
amoebius/utils/terraform/storage.py

Defines storage classes for reading/writing Terraform state ciphertext:
  - NoStorage
  - VaultKVStorage
  - MinioStorage
  - K8sSecretStorage

All classes accept a TerraformBackendRef referencing (root, workspace).
For a non-existent state, each backend returns None, so the caller can detect
"No existing Terraform state" and proceed accordingly.
"""

from __future__ import annotations

import io
import asyncio
from abc import ABC, abstractmethod
from typing import Optional

from minio import Minio
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.k8s import get_k8s_secret_data, put_k8s_secret_data
from amoebius.models.terraform import TerraformBackendRef


class StateStorage(ABC):
    """Abstract base class for reading/writing Terraform state ciphertext."""

    def __init__(
        self,
        ref: TerraformBackendRef,
        transit_key_name: Optional[str] = None,
    ) -> None:
        """
        Initialize a StateStorage.

        Args:
            ref (TerraformBackendRef):
                Identifies the Terraform root + workspace.
            transit_key_name (Optional[str]):
                If set, ephemeral usage can do encryption with Vault transit.
        """
        self.ref = ref
        self.transit_key_name: Optional[str] = transit_key_name

    @abstractmethod
    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        """
        Read the stored ciphertext for this validated (root, workspace).

        Returns:
            Optional[str]: The ciphertext if it exists, or None if no state is found.
        """
        pass

    @abstractmethod
    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        """
        Write or overwrite the ciphertext for this validated (root, workspace).

        Args:
            ciphertext (str): The ciphertext to store.
            vault_client (Optional[AsyncVaultClient]): For Vault usage if any.
            minio_client (Optional[Minio]): For Minio usage if any.
        """
        pass


class NoStorage(StateStorage):
    """
    Indicates 'vanilla' Terraform usage where read/write => no-op, no encryption needed.
    """

    def __init__(self, ref: TerraformBackendRef) -> None:
        super().__init__(ref, transit_key_name=None)

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        return None

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        pass


class VaultKVStorage(StateStorage):
    """
    Stores ciphertext in Vault's KV under:
      'secret/data/amoebius/terraform-backends/<mapped_root>/<mapped_workspace>'.

    If no secret is found, returns None to indicate no existing state.
    """

    def __init__(
        self,
        ref: TerraformBackendRef,
        transit_key_name: Optional[str] = None,
    ) -> None:
        super().__init__(ref, transit_key_name)

    def _kv_path(self) -> str:
        """
        Build the path under 'secret/data/...' for storing the ciphertext.
        """
        mapped_root = self.ref.root.replace("/", ".")
        mapped_ws = self.ref.workspace.replace("/", ".")
        return f"amoebius/terraform-backends/{mapped_root}/{mapped_ws}"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        try:
            data = await vault_client.read_secret(self._kv_path())
            return data.get("ciphertext") if data else None
        except RuntimeError as ex:
            if "404" in str(ex):
                return None
            raise

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        if not vault_client:
            raise RuntimeError("VaultKVStorage requires a vault_client.")
        await vault_client.write_secret(self._kv_path(), {"ciphertext": ciphertext})


class MinioStorage(StateStorage):
    """
    Stores ciphertext in a Minio bucket => 'terraform-backends/<mapped_root>/<mapped_workspace>.enc'.
    If no object is found, returns None to indicate no existing state.
    """

    def __init__(
        self,
        ref: TerraformBackendRef,
        bucket_name: str,
        transit_key_name: Optional[str] = None,
        minio_client: Optional[Minio] = None,
    ) -> None:
        super().__init__(ref, transit_key_name)
        self.bucket_name = bucket_name
        self._minio_client = minio_client

    def _object_key(self) -> str:
        mapped_root = self.ref.root.replace("/", ".")
        mapped_ws = self.ref.workspace.replace("/", ".")
        return f"terraform-backends/{mapped_root}/{mapped_ws}.enc"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        client = self._minio_client or minio_client
        if not client:
            raise RuntimeError("MinioStorage requires a minio_client.")

        def do_get_and_read() -> Optional[str]:
            response = None
            try:
                response = client.get_object(self.bucket_name, self._object_key())
                data_b = response.read()
                return data_b.decode("utf-8")
            except Exception as ex:
                # If object not found => return None
                if any(msg in str(ex) for msg in ("NoSuchKey", "NoSuchObject", "404")):
                    return None
                raise
            finally:
                if response is not None:
                    response.close()
                    response.release_conn()

        return await asyncio.to_thread(do_get_and_read)

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        client = self._minio_client or minio_client
        if not client:
            raise RuntimeError("MinioStorage requires a minio_client.")

        data_bytes = ciphertext.encode("utf-8")
        length = len(data_bytes)

        def do_put_object() -> None:
            stream = io.BytesIO(data_bytes)
            client.put_object(
                bucket_name=self.bucket_name,
                object_name=self._object_key(),
                data=stream,
                length=length,
                content_type="text/plain",
            )

        await asyncio.to_thread(do_put_object)


class K8sSecretStorage(StateStorage):
    """
    Stores ciphertext in a K8s Secret => 'tf-backend-<mapped_root>-<mapped_workspace>',
    under data['ciphertext']. If no such secret or if 'ciphertext' not present, returns None.
    """

    def __init__(
        self,
        ref: TerraformBackendRef,
        namespace: str = "amoebius",
        transit_key_name: Optional[str] = None,
    ) -> None:
        super().__init__(ref, transit_key_name)
        self.namespace = namespace

    def _secret_name(self) -> str:
        mapped_root = self.ref.root.replace("/", ".")
        mapped_ws = self.ref.workspace.replace("/", ".")
        return f"terraform-backend-{mapped_root}-{mapped_ws}"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        secret_data = await get_k8s_secret_data(
            secret_name=self._secret_name(),
            namespace=self.namespace,
        )
        if not secret_data or "ciphertext" not in secret_data:
            return None
        return secret_data["ciphertext"]

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        data_dict = {"ciphertext": ciphertext}
        await put_k8s_secret_data(
            secret_name=self._secret_name(),
            namespace=self.namespace,
            data=data_dict,
        )
