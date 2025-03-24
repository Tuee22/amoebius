"""
amoebius/utils/terraform/commands.py

Implements Terraform commands (init, apply, destroy, show, etc.), plus helpers
for building command arrays. Uses ephemeral usage from ephemeral.py so no secrets
remain on disk if 'transit_key_name' is set in the provided storage. Also integrates
a Docker Hub rate limit detection parser, by passing an `error_parser` function to
`run_command`, raising a short user-friendly error if that limit is encountered.

Exports the following primary functions:
    - init_terraform
    - apply_terraform
    - destroy_terraform
    - read_terraform_state
    - get_output_from_state
    - list_minio_backends
    - delete_empty_minio_backends
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

from amoebius.utils.terraform.storage import StateStorage, NoStorage, MinioStorage
from amoebius.utils.terraform.ephemeral import ephemeral_tfstate_if_needed, maybe_tfvars

T = TypeVar("T")


def _dockerhub_rate_parser(stderr: str) -> Optional[str]:
    """Parse stderr for Docker Hub rate-limit messages, returning a short message if found.

    Args:
        stderr (str): The standard error output from Terraform.

    Returns:
        Optional[str]: A short user-friendly message if the Docker Hub pull limit was hit,
            otherwise None.
    """
    low = stderr.lower()
    if (
        "429 too many requests" in low
        or "toomanyrequests" in low
        or "pull rate limit" in low
        or "you have reached your pull rate limit" in low
    ):
        return (
            "Docker Hub rate limit encountered. Please authenticate or "
            "upgrade your Docker Hub plan to avoid pull limit errors."
        )
    return None


def _make_base_command(
    action: str, override_lock: bool, reconfigure: bool
) -> List[str]:
    """Builds the initial Terraform command, optionally adding flags.

    Args:
        action: "init", "apply", "destroy", "show", etc.
        override_lock: If True, add '-lock=false' for apply/destroy.
        reconfigure: If True, add '-reconfigure' for init.

    Returns:
        A list of command tokens, e.g. ["terraform","apply","-auto-approve"].
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
    """Combine the base Terraform command list with optional var-file flags."""
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
    ephemeral_tfstate_if_needed sees if storage.transit_key_name is set to do encryption.

    Passes a Docker Hub parser `_dockerhub_rate_parser` to `run_command` so that any
    Docker Hub rate-limit message in stderr triggers a short user-friendly error.

    Args:
        action (str):
            The Terraform action: "init","apply","destroy","show".
        ref (TerraformBackendRef):
            Reference to the Terraform root+workspace.
        base_path (str):
            Base directory containing the terraform config, e.g. "/amoebius/terraform/roots".
        env (Optional[Dict[str,str]]):
            Additional environment variables for Terraform.
        storage (Optional[StateStorage]):
            A chosen storage class for ephemeral usage or no-op.
        vault_client (Optional[AsyncVaultClient]):
            If ephemeral usage with Vault encryption is desired.
        minio_client (Optional[Minio]):
            If ephemeral usage storing ciphertext in Minio is desired.
        override_lock (bool):
            If True => '-lock=false' for apply/destroy.
        variables (Optional[Dict[str,Any]]):
            Key-value map for -var or var-file usage.
        reconfigure (bool):
            If True => '-reconfigure' for "terraform init".
        sensitive (bool):
            If True => do not show full command or stdout/stderr in raised errors.
        capture_output (bool):
            If True => return Terraform stdout from the function.
        retries (int):
            Number of times to retry the underlying command on failure.

    Returns:
        Optional[str]: The Terraform stdout if capture_output=True, else None.

    Raises:
        CommandError: If the command fails after all retries or if Docker Hub rate-limit
            is detected.
    """
    store = storage or NoStorage(ref=ref)
    terraform_dir = os.path.join(base_path, ref.root)
    if not os.path.isdir(terraform_dir):
        raise ValueError(f"Terraform directory not found: {terraform_dir}")

    base_cmd = _make_base_command(action, override_lock, reconfigure)

    async def run_tf(cmd_list: List[str]) -> str:
        return await run_command(
            cmd_list,
            sensitive=sensitive,
            env=env,
            cwd=terraform_dir,
            retries=retries,
            error_parser=_dockerhub_rate_parser,
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
    workspace: Optional[str] = None,  # ignored if user passes ref
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    reconfigure: bool = False,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """Run 'terraform init' with ephemeral usage if needed, storing .tfstate in memory or remote.

    Args:
        ref (TerraformBackendRef):
            The reference to root + workspace for terraform.
        workspace (Optional[str]):
            Ignored in this usage. The TerraformBackendRef already has workspace info.
        env (Dict[str,str], optional):
            Additional environment variables for Terraform.
        base_path (str):
            Directory containing the TF root modules. Default /amoebius/terraform/roots.
        storage (StateStorage, optional):
            The chosen storage class for ephemeral usage or no storage.
        vault_client (AsyncVaultClient, optional):
            If ephemeral usage with Vault encryption is desired.
        minio_client (Minio, optional):
            If ephemeral usage storing ciphertext in Minio.
        reconfigure (bool):
            If True => '-reconfigure' for 'terraform init'.
        sensitive (bool):
            If True => omit command details from error logs.
        retries (int):
            Number of times to retry on failure. Defaults to 3.
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
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """Run 'terraform apply' with ephemeral usage for .tfstate & .tfstate.backup.

    ephemeral_tfstate_if_needed references storage.transit_key_name if encryption is needed.
    Also checks for Docker Hub rate-limit errors via a custom parser.

    Args:
        ref (TerraformBackendRef):
            The reference to root + workspace for terraform.
        workspace (Optional[str]):
            Ignored. The TerraformBackendRef already has workspace info.
        env (Dict[str,str], optional):
            Additional environment variables for Terraform.
        base_path (str):
            Directory containing the TF root modules.
        storage (StateStorage, optional):
            If ephemeral usage is desired, pass an appropriate StateStorage instance.
        vault_client (AsyncVaultClient, optional):
            If ephemeral usage with Vault encryption is desired.
        minio_client (Minio, optional):
            If ephemeral usage storing ciphertext in Minio.
        override_lock (bool):
            If True => '-lock=false' for apply.
        variables (Dict[str,Any], optional):
            Variables to pass to the terraform CLI.
        sensitive (bool):
            If True => do not show full command or stdout/stderr in error messages.
        retries (int):
            Retry count.
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
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    override_lock: bool = False,
    variables: Optional[Dict[str, Any]] = None,
    sensitive: bool = True,
    retries: int = 3,
) -> None:
    """Run 'terraform destroy' with ephemeral usage, referencing storage.transit_key_name if set.

    Also checks for Docker Hub rate-limit errors via a custom parser.

    Args:
        ref (TerraformBackendRef):
            The reference to root + workspace for terraform.
        workspace (Optional[str]):
            Ignored. The TerraformBackendRef already has workspace info.
        env (Dict[str,str], optional):
            Additional environment variables for Terraform.
        base_path (str):
            Directory containing the TF root modules.
        storage (StateStorage, optional):
            If ephemeral usage is desired, pass a suitable StateStorage instance.
        vault_client (AsyncVaultClient, optional):
            If ephemeral usage with Vault encryption is desired.
        minio_client (Minio, optional):
            If ephemeral usage storing ciphertext in Minio.
        override_lock (bool):
            If True => '-lock=false' for destroy.
        variables (Dict[str,Any], optional):
            Variables to pass to the terraform CLI.
        sensitive (bool):
            If True => hide details in error messages.
        retries (int):
            Number of retries for command invocation.
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
    workspace: Optional[str] = None,
    env: Optional[Dict[str, str]] = None,
    base_path: str = "/amoebius/terraform/roots",
    storage: Optional[StateStorage] = None,
    vault_client: Optional[AsyncVaultClient] = None,
    minio_client: Optional[Minio] = None,
    sensitive: bool = True,
    retries: int = 0,
) -> TerraformState:
    """Run 'terraform show -json' with ephemeral usage, returning a parsed TerraformState.

    Also checks for Docker Hub rate-limit errors via the custom parser.

    Args:
        ref (TerraformBackendRef):
            The reference to root + workspace for terraform.
        workspace (Optional[str]):
            Ignored. The TerraformBackendRef has workspace info.
        env (Dict[str,str], optional):
            Additional environment variables for Terraform.
        base_path (str):
            Directory containing the TF root modules. Default is /amoebius/terraform/roots.
        storage (StateStorage, optional):
            The ephemeral or no-op storage for state.
        vault_client (AsyncVaultClient, optional):
            If ephemeral usage with Vault encryption is desired.
        minio_client (Minio, optional):
            If ephemeral usage storing ciphertext in Minio.
        sensitive (bool):
            If True => do not show full command or stdout/stderr in error messages.
        retries (int):
            Retry count for the command.

    Returns:
        TerraformState: Parsed JSON state object.

    Raises:
        RuntimeError: If the show output is empty or cannot parse.
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
    """Retrieve a typed output from a TerraformState object.

    Args:
        state (TerraformState):
            The parsed Terraform state.
        output_name (str):
            Which output to retrieve by name.
        output_type (Type[T]):
            The Python type to validate/cast the output to.

    Returns:
        The typed output if present.

    Raises:
        KeyError: If the output is missing.
        ValueError: If validation to output_type fails.
    """
    output_val = state.values.outputs.get(output_name)
    if output_val is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_val.value, output_type)


# -------------- Minio-based backend listing & cleanup ----------------


def _build_object_name(root: str, workspace: str) -> str:
    """Build a Minio object key, e.g. 'terraform-backends/<dotted_root>/<workspace>.enc'."""
    dotted_root = root.replace("/", ".")
    return f"terraform-backends/{dotted_root}/{workspace}.enc"


def _parse_object_name(obj_name: str) -> Optional[TerraformBackendRef]:
    """Parse Minio object name => TerraformBackendRef if matching known pattern."""
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

    If delete_empty_backends=True, calls delete_empty_minio_backends() first.

    Args:
        vault_client (AsyncVaultClient):
            For ephemeral usage if needed.
        minio_client (Minio):
            A Minio client instance with credentials.
        delete_empty_backends (bool):
            If True => calls delete_empty_minio_backends, removing leftover backends
            that have no resources or that fail reading.

    Returns:
        List[TerraformBackendRef]: The recognized root/workspace backends from Minio.
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
        result: List[TerraformBackendRef] = []
        for obj in objects:
            parsed = _parse_object_name(obj.object_name)
            if parsed:
                result.append(parsed)
        return result
    except Exception:
        return []


async def delete_empty_minio_backends(
    vault_client: AsyncVaultClient,
    minio_client: Minio,
) -> None:
    """Remove Minio-based Terraform backend objects that have no resources or fail reading.

    Steps:
      1) List recognized backends (delete_empty_backends=False).
      2) read_terraform_state for each. If empty or fails => remove the object in parallel.
    """
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
            tfstate = await read_terraform_state(
                ref=ref,
                storage=store,
                vault_client=vault_client,
                minio_client=minio_client,
                retries=0,
            )
            return tfstate.is_empty()
        except Exception:
            return True

    tasks = [asyncio.create_task(check_backend(b)) for b in backends]
    results = await asyncio.gather(*tasks)
    empties = [b for b, is_empty in zip(backends, results) if is_empty]

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
                _build_object_name(b.root, b.workspace),
            )
            for b in empties
        ]
    )
