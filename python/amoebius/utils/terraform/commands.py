"""
amoebius/utils/terraform/commands.py

Provides user-callable Terraform command functions with ephemeral usage, plus
logic to detect Docker Hub "too many requests" errors when installing Helm charts.
"""

from __future__ import annotations

import os
import asyncio
from typing import Any, Dict, Optional, Type, TypeVar, List

from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.models.validator import validate_type
from amoebius.models.terraform import TerraformState, TerraformBackendRef
from amoebius.secrets.vault_client import AsyncVaultClient
from minio import Minio

from amoebius.utils.terraform.storage import StateStorage, NoStorage
from amoebius.utils.terraform.ephemeral import ephemeral_tfstate_if_needed, maybe_tfvars

T = TypeVar("T")


def _make_base_command(
    action: str, override_lock: bool, reconfigure: bool
) -> List[str]:
    """Internal: Build the base Terraform command with optional flags."""
    base = ["terraform", action, "-no-color"]

    show_flags = ["-json"] if action == "show" else []
    apply_destroy_flags = (
        (["-auto-approve"] + (["-lock=false"] if override_lock else []))
        if action in ("apply", "destroy")
        else []
    )
    init_flags = ["-reconfigure"] if (action == "init" and reconfigure) else []

    return base + show_flags + apply_destroy_flags + init_flags


def _build_final_command(base_cmd: List[str], tfvars_args: List[str]) -> List[str]:
    """Internal: Combine base_cmd with optional var-file flags."""
    return base_cmd + tfvars_args


async def _terraform_command(
    action: str,
    ref: TerraformBackendRef,
    base_path: str,
    env: Optional[Dict[str, str]],
    storage: Optional[StateStorage],
    vault_client: Optional[AsyncVaultClient],
    minio_client: Optional[Minio],
    override_lock: bool,
    variables: Optional[Dict[str, Any]],
    reconfigure: bool,
    sensitive: bool,
    capture_output: bool,
    retries: int,
) -> Optional[str]:
    """
    Internal runner for 'terraform <action>' with ephemeral usage => .tfstate in memory only.

    ephemeral_tfstate_if_needed checks if `storage.transit_key_name` is set to do encryption.
    The working directory is `os.path.join(base_path, ref.root)`.

    Returns:
        Optional[str]: Terraform stdout if capture_output=True, else None.
    """
    store = storage or NoStorage(ref=ref)
    terraform_dir = os.path.join(base_path, ref.root)
    if not os.path.isdir(terraform_dir):
        raise ValueError(f"Terraform directory not found: {terraform_dir}")

    base_cmd = _make_base_command(action, override_lock, reconfigure)

    async def run_tf(cmd_list: List[str]) -> str:
        try:
            return await run_command(
                cmd_list, sensitive=sensitive, env=env, cwd=terraform_dir, retries=retries
            )
        except CommandError as exc:
            # Detect Docker Hub rate-limit in the error message
            lower_msg = str(exc).lower()
            if ("429 too many requests" in lower_msg or 
                "you have reached your pull rate limit" in lower_msg or
                "toomanyrequests" in lower_msg):
                raise CommandError(
                    "Terraform failed due to a Docker Hub rate limit error. "
                    "Please consider authenticating or upgrading your Docker Hub plan."
                ) from exc

            # Otherwise, re-raise the original error
            raise

    async with ephemeral_tfstate_if_needed(
        store, vault_client, minio_client, terraform_dir
    ):
        async with maybe_tfvars(action, variables) as tfvars_args:
            final_cmd = _build_final_command(base_cmd, tfvars_args)
            output = await run_tf(final_cmd)
            return output if capture_output else None


async def init_terraform(
    ref: TerraformBackendRef,
    base_path: str = "/amoebius/terraform/roots",
    env: Optional[Dict[str, str]] = None,
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    reconfigure: bool = False,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """Initialize Terraform for the specified backend ref.

    Args:
        ref: Identifies the root + workspace.
        base_path: Path to Terraform modules. Default /amoebius/terraform/roots.
        env: Optional environment vars for Terraform.
        storage: Optional ephemeral/persistent storage for state.
        vault_client: If ephemeral usage with Vault encryption is desired.
        minio_client: If ephemeral usage storing ciphertext in Minio.
        reconfigure: If True => '-reconfigure' for init.
        sensitive: If True => does not print full logs on error.
        retries: Number of command retries.
    """
    await _terraform_command(
        action="init",
        ref=ref,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        override_lock=False,
        variables=None,
        reconfigure=reconfigure,
        sensitive=sensitive,
        capture_output=False,
        retries=retries,
    )


async def apply_terraform(
    ref: TerraformBackendRef,
    base_path: str = "/amoebius/terraform/roots",
    env: Optional[Dict[str, str]] = None,
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """Apply a Terraform plan for the specified backend ref."""
    await _terraform_command(
        action="apply",
        ref=ref,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        override_lock=override_lock,
        variables=variables,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=False,
        retries=retries,
    )


async def destroy_terraform(
    ref: TerraformBackendRef,
    base_path: str = "/amoebius/terraform/roots",
    env: Optional[Dict[str, str]] = None,
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """Destroy Terraform-managed resources for the specified backend ref."""
    await _terraform_command(
        action="destroy",
        ref=ref,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        override_lock=override_lock,
        variables=variables,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=False,
        retries=retries,
    )


async def read_terraform_state(
    ref: TerraformBackendRef,
    base_path: str = "/amoebius/terraform/roots",
    env: Optional[Dict[str, str]] = None,
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    sensitive: bool = True,
    retries: int = 0,
) -> TerraformState:
    """Read and parse Terraform state (JSON) for the specified backend ref."""
    output = await _terraform_command(
        action="show",
        ref=ref,
        base_path=base_path,
        env=env,
        storage=storage,
        vault_client=vault_client,
        minio_client=minio_client,
        override_lock=False,
        variables=None,
        reconfigure=False,
        sensitive=sensitive,
        capture_output=True,
        retries=retries,
    )
    if not output:
        raise RuntimeError("Failed to retrieve terraform state (empty output).")
    return TerraformState.model_validate_json(output)


def get_output_from_state(
    state: TerraformState, output_name: str, output_type: Type[T]
) -> T:
    """Retrieve a typed output value from a TerraformState object."""
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)


# Helm/destroy related internal code for listing Minio-based backends
def _build_object_name(root: str, workspace: str) -> str:
    """Construct a Minio object key for storing Terraform state, e.g. 'terraform-backends/<dotted_root>/<workspace>.enc'."""
    dotted_root = root.replace("/", ".")
    return f"terraform-backends/{dotted_root}/{workspace}.enc"


def _parse_object_name(obj_name: str) -> Optional[TerraformBackendRef]:
    """Parse a Minio object name => TerraformBackendRef if it matches the known pattern."""
    if not obj_name.startswith("terraform-backends/"):
        return None
    if not obj_name.endswith(".enc"):
        return None

    tail = obj_name[len("terraform-backends/") :]
    parts = tail.split("/", maxsplit=1)
    if len(parts) != 2:
        return None

    dotted_root, ws_enc = parts
    if not ws_enc.endswith(".enc"):
        return None

    workspace = ws_enc[: -len(".enc")]
    root = dotted_root.replace(".", "/")

    try:
        return TerraformBackendRef(root=root, workspace=workspace)
    except ValueError:
        return None


async def list_minio_backends(
    vault_client: AsyncVaultClient,
    minio_client: Minio,
    delete_empty_backends: bool = True,
) -> List[TerraformBackendRef]:
    """List all recognized Minio-based Terraform backends from the 'amoebius' bucket."""
    if delete_empty_backends:
        await delete_empty_minio_backends(vault_client, minio_client)
        return await list_minio_backends(vault_client, minio_client, delete_empty_backends=False)

    try:
        objects = minio_client.list_objects(
            "amoebius",
            prefix="terraform-backends/",
            recursive=True,
        )
        return [
            parsed
            for obj in objects
            if (parsed := _parse_object_name(obj.object_name)) is not None
        ]
    except Exception:
        return []


async def delete_empty_minio_backends(
    vault_client: AsyncVaultClient,
    minio_client: Minio,
) -> None:
    """Remove Minio-based Terraform backend objects that are empty or fail retrieval."""
    backends = await list_minio_backends(
        vault_client, minio_client, delete_empty_backends=False
    )
    if not backends:
        return

    async def check_backend(ref: TerraformBackendRef) -> bool:
        store = MinioStorage(
            ref=ref,
            bucket_name="amoebius",
            transit_key_name="amoebius",
            minio_client=minio_client,
        )
        try:
            tf_state = await read_terraform_state(
                ref=ref,
                storage=store,
                vault_client=vault_client,
                minio_client=minio_client,
                retries=0,
            )
            return tf_state.is_empty()
        except Exception:
            return True

    tasks = [asyncio.create_task(check_backend(r)) for r in backends]
    results = await asyncio.gather(*tasks)

    empties = [r for r, empty in zip(backends, results) if empty]

    def remove_object_ignore_errors(client: Minio, bucket: str, key: str) -> None:
        try:
            client.remove_object(bucket, key)
        except Exception:
            pass

    await asyncio.gather(
        *[
            asyncio.to_thread(
                remove_object_ignore_errors,
                minio_client,
                "amoebius",
                _build_object_name(r.root, r.workspace),
            )
            for r in empties
        ]
    )