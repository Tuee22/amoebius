"""
amoebius/utils/terraform/storage.py

Defines storage classes for reading/writing ciphertext of Terraform state:
  - NoStorage (always skip)
  - VaultKVStorage
  - MinioStorage
  - K8sSecretStorage

All imports are at the top, no local imports, no for loops for side-effect removal.
"""

from __future__ import annotations

import asyncio
import io
from abc import ABC, abstractmethod
from typing import Optional

from minio import Minio
from amoebius.secrets.vault_client import AsyncVaultClient


class StateStorage(ABC):
    """Abstract base class for reading/writing Terraform state ciphertext."""

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        """
        Initialize a StateStorage.

        Args:
            root_module: The Terraform root module name.
            workspace: The workspace name, defaults to 'default'.
        """
        self.root_module = root_module
        self.workspace = workspace or "default"

    @abstractmethod
    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        """
        Read the stored ciphertext for this (root_module, workspace).

        Args:
            vault_client: For Vault usage if any.
            minio_client: For Minio usage if any.

        Returns:
            The ciphertext, or None if not found.
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
        Write/overwrite the ciphertext for this (root_module, workspace).

        Args:
            ciphertext: The ciphertext to store.
            vault_client: For Vault usage if any.
            minio_client: For Minio usage if any.
        """
        pass


class NoStorage(StateStorage):
    """Indicates 'vanilla' Terraform usage where read/write => no-op."""

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        super().__init__(root_module, workspace)

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
    """Stores ciphertext in Vault's KV under
    'secret/data/amoebius/terraform-backends/<root>/<workspace>'.
    """

    def __init__(self, root_module: str, workspace: Optional[str] = None) -> None:
        super().__init__(root_module, workspace)

    def _kv_path(self) -> str:
        return f"amoebius/terraform-backends/{self.root_module}/{self.workspace}"

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
            return data.get("ciphertext")
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
    """Stores ciphertext in a MinIO bucket => '<root_module>/<workspace>.enc'."""

    def __init__(
        self,
        root_module: str,
        workspace: Optional[str] = None,
        bucket_name: str = "tf-states",
    ) -> None:
        super().__init__(root_module, workspace)
        self.bucket_name = bucket_name

    def _object_key(self) -> str:
        return f"{self.root_module}/{self.workspace}.enc"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        if not minio_client:
            raise RuntimeError("MinioStorage requires a minio_client.")

        loop = asyncio.get_running_loop()
        response = None
        try:
            response = await loop.run_in_executor(
                None,
                lambda: minio_client.get_object(self.bucket_name, self._object_key()),
            )
            data = response.read()
            return data.decode("utf-8")
        except Exception as ex:
            if any(msg in str(ex) for msg in ("NoSuchKey", "NoSuchObject", "404")):
                return None
            raise
        finally:
            if response:
                response.close()
                response.release_conn()

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        if not minio_client:
            raise RuntimeError("MinioStorage requires a minio_client.")

        loop = asyncio.get_running_loop()
        data_bytes = ciphertext.encode("utf-8")
        length = len(data_bytes)

        def put_object() -> None:
            stream = io.BytesIO(data_bytes)
            minio_client.put_object(
                self.bucket_name,
                self._object_key(),
                data=stream,
                length=length,
                content_type="text/plain",
            )

        await loop.run_in_executor(None, put_object)


class K8sSecretStorage(StateStorage):
    """
    Stores ciphertext in a K8s Secret => 'tf-backend-<root>-<workspace>' => data['ciphertext'].
    """

    def __init__(
        self,
        root_module: str,
        workspace: Optional[str] = None,
        namespace: str = "amoebius",
    ) -> None:
        super().__init__(root_module, workspace)
        self.namespace = namespace

    def _secret_name(self) -> str:
        return f"tf-backend-{self.root_module}-{self.workspace}"

    async def read_ciphertext(
        self,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> Optional[str]:
        from amoebius.utils.k8s import get_k8s_secret_data

        secret_data = await get_k8s_secret_data(self._secret_name(), self.namespace)
        if not secret_data:
            return None
        return secret_data.get("ciphertext")

    async def write_ciphertext(
        self,
        ciphertext: str,
        *,
        vault_client: Optional[AsyncVaultClient],
        minio_client: Optional[Minio],
    ) -> None:
        from amoebius.utils.k8s import put_k8s_secret_data

        data_dict = {"ciphertext": ciphertext}
        await put_k8s_secret_data(self._secret_name(), self.namespace, data_dict)
