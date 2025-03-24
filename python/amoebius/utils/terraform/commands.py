"""
amoebius/utils/terraform/commands.py

Provides user-callable Terraform command functions with ephemeral usage:
    - init_terraform
    - apply_terraform
    - destroy_terraform
    - read_terraform_state
    - get_output_from_state
    - list_minio_backends
    - delete_empty_minio_backends

All state is handled via ephemeral usage if a 'transit_key_name' is set on the
provided storage. We do NOT manually pass the transit key name to these functions.

We rely on TerraformBackendRef for the root + workspace references, with
workspace defaulting to "default" if not specified.
"""

from __future__ import annotations

import os
import asyncio
from typing import Any, Dict, Optional, Type, TypeVar, List

from amoebius.utils.async_command_runner import run_command
from amoebius.models.validator import validate_type
from amoebius.models.terraform import TerraformState, TerraformBackendRef
from amoebius.secrets.vault_client import AsyncVaultClient
from minio import Minio

from amoebius.utils.terraform.storage import StateStorage, NoStorage, MinioStorage
from amoebius.utils.terraform.ephemeral import ephemeral_tfstate_if_needed, maybe_tfvars

T = TypeVar("T")


def _make_base_command(
    action: str, override_lock: bool, reconfigure: bool
) -> List[str]:
    """Build the base Terraform command, optionally adding flags.

    Args:
        action (str): Terraform action, e.g. "init", "apply", "destroy", "show".
        override_lock (bool): If True, add '-lock=false' for apply/destroy.
        reconfigure (bool): If True, add '-reconfigure' for init.

    Returns:
        List[str]: The initial command list, e.g. ["terraform","apply","-auto-approve"].
    """
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
    """Combine base command with optional var-file flags."""
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
    Internal runner for 'terraform <action>' using ephemeral state storage if needed.

    ephemeral_tfstate_if_needed checks if 'transit_key_name' is set on storage.
    The working directory is base_path / ref.root.

    Returns:
        Optional[str]: Terraform stdout if capture_output=True, else None.
    """
    store = storage or NoStorage(ref=ref)
    terraform_dir = os.path.join(base_path, ref.root)
    if not os.path.isdir(terraform_dir):
        raise ValueError(f"Terraform directory not found: {terraform_dir}")

    base_cmd = _make_base_command(action, override_lock, reconfigure)

    async def run_tf(cmd_list: List[str]) -> str:
        return await run_command(
            cmd_list, sensitive=sensitive, env=env, cwd=terraform_dir, retries=retries
        )

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
        ref (TerraformBackendRef): Identifies the root + workspace.
        base_path (str): Folder containing Terraform directories, default /amoebius/terraform/roots.
        env (Dict[str, str], optional): Additional environment variables for Terraform.
        storage (StateStorage, optional): The ephemeral or persistent storage for state.
        vault_client (AsyncVaultClient, optional): If ephemeral with Vault encryption.
        minio_client (Minio, optional): If ephemeral with Minio-based storage.
        reconfigure (bool): If True, passes -reconfigure to 'terraform init'.
        sensitive (bool): If True, hides command details on error.
        retries (int): Number of retries for run_command.
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
    """Apply a Terraform plan for the specified backend ref.

    Args:
        ref (TerraformBackendRef): Identifies the root + workspace.
        base_path (str): Folder containing Terraform directories, default /amoebius/terraform/roots.
        env (Dict[str, str], optional): Additional environment variables for Terraform.
        storage (StateStorage, optional): The ephemeral or persistent storage for state.
        vault_client (AsyncVaultClient, optional): If ephemeral with Vault encryption.
        minio_client (Minio, optional): If ephemeral with Minio-based storage.
        override_lock (bool): If True, passes -lock=false for apply.
        variables (Dict[str, Any], optional): Key-value data for terraform variables.
        sensitive (bool): If True, hides command details on error.
        retries (int): Number of retries for run_command.
    """
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
    """Destroy Terraform-managed resources for the specified backend ref.

    Args:
        ref (TerraformBackendRef): Identifies the root + workspace.
        base_path (str): Folder containing Terraform directories, default /amoebius/terraform/roots.
        env (Dict[str, str], optional): Additional environment variables for Terraform.
        storage (StateStorage, optional): The ephemeral or persistent storage for state.
        vault_client (AsyncVaultClient, optional): If ephemeral with Vault encryption.
        minio_client (Minio, optional): If ephemeral with Minio-based storage.
        override_lock (bool): If True, passes -lock=false for destroy.
        variables (Dict[str, Any], optional): Key-value data for terraform variables.
        sensitive (bool): If True, hides command details on error.
        retries (int): Number of retries for run_command.
    """
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
    """Read and parse Terraform state (JSON) for the specified backend ref.

    Args:
        ref (TerraformBackendRef): Identifies the root + workspace.
        base_path (str): Folder containing Terraform directories, default /amoebius/terraform/roots.
        env (Dict[str, str], optional): Additional environment variables for Terraform.
        storage (StateStorage, optional): The ephemeral or persistent storage for state.
        vault_client (AsyncVaultClient, optional): If ephemeral with Vault encryption.
        minio_client (Minio, optional): If ephemeral with Minio-based storage.
        sensitive (bool): If True, hides command details on error.
        retries (int): Number of retries for run_command.

    Returns:
        TerraformState: The parsed state object.

    Raises:
        RuntimeError: If state retrieval fails or is empty.
    """
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
    """Retrieve a typed output value from a TerraformState.

    Args:
        state (TerraformState): Parsed state object.
        output_name (str): Which output name to retrieve.
        output_type (Type[T]): The Python type to validate against.

    Returns:
        T: The typed value from that output.

    Raises:
        KeyError: If the output is missing.
        ValueError: If validation fails.
    """
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)


def _build_object_name(root: str, workspace: str) -> str:
    """Construct a Minio object key for storing state.

    E.g. "terraform-backends/providers.aws/my-workspace.enc"
    Slash in root => replaced with dot, then appended with "/{workspace}.enc"
    """
    dotted_root = root.replace("/", ".")
    return f"terraform-backends/{dotted_root}/{workspace}.enc"


def _parse_object_name(obj_name: str) -> Optional[TerraformBackendRef]:
    """Parse a Minio object name => TerraformBackendRef if it matches the known pattern.

    Pattern: "terraform-backends/<dotted_root>/<workspace>.enc"

    Returns:
        TerraformBackendRef if parseable, else None.
    """
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
    """List all recognized Minio-based Terraform backends from the 'amoebius' bucket.

    Args:
        vault_client (AsyncVaultClient): For reading secrets if needed.
        minio_client (Minio): Minio client for listing objects.
        delete_empty_backends (bool): If True, calls `delete_empty_minio_backends` first.

    Returns:
        List[TerraformBackendRef]: A list of recognized backend references.
    """
    if delete_empty_backends:
        await delete_empty_minio_backends(vault_client, minio_client)
        return await list_minio_backends(
            vault_client, minio_client, delete_empty_backends=False
        )

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
    """Remove any Minio-based Terraform backend objects that are effectively empty or fail retrieval.

    Steps:
      1) List recognized backends (with delete_empty_backends=False).
      2) For each => read_terraform_state. If is_empty or fails => remove object.
      3) The removal is done in parallel threads for concurrency.

    Args:
        vault_client (AsyncVaultClient): For ephemeral usage if needed.
        minio_client (Minio): Minio client to remove objects from.
    """
    backends = await list_minio_backends(
        vault_client, minio_client, delete_empty_backends=False
    )
    if not backends:
        return

    async def check_backend(ref: TerraformBackendRef) -> bool:
        """Return True if the backend is empty or we fail reading the state."""
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

    tasks = [asyncio.create_task(check_backend(ref)) for ref in backends]
    results = await asyncio.gather(*tasks)
    empties = [ref for ref, empty in zip(backends, results) if empty]

    def remove_object_ignore_errors(client: Minio, bucket: str, key: str) -> None:
        try:
            client.remove_object(bucket, key)
        except Exception:
            pass

    # Parallel removal
    await asyncio.gather(
        *[
            asyncio.to_thread(
                remove_object_ignore_errors,
                minio_client,
                "amoebius",
                _build_object_name(ref.root, ref.workspace),
            )
            for ref in empties
        ]
    )
