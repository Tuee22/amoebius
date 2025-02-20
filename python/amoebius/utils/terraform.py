import os
import json
import tempfile
from typing import Any, Optional, Dict, Type, TypeVar

import aiofiles  # Ensure you've installed aiofiles

from pydantic import ValidationError

from amoebius.models.terraform_state import TerraformState
from amoebius.models.validator import validate_type
from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.utils.async_retry import async_retry

T = TypeVar("T")

DEFAULT_TERRAFORM_ROOTS = "/amoebius/terraform/roots"


def _validate_root_name(root_name: str, base_path: str) -> str:
    """
    Validate the Terraform root name, returning the absolute path to the
    corresponding directory.
    """
    if not root_name.strip():
        raise ValueError("Root name cannot be empty")

    terraform_path = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_path):
        raise ValueError(f"Terraform root directory not found: {terraform_path}")

    return terraform_path


async def _list_workspaces(
    terraform_path: str,
    env: Optional[Dict[str, str]],
    sensitive: bool,
) -> list[str]:
    """
    Returns a list of existing Terraform workspace names for the given path,
    by running:
        terraform workspace list -no-color
    and stripping out leading '*' and whitespace from each line.

    We explicitly suppress TF_WORKSPACE in the environment to avoid Terraform's
    "workspace override" error when just listing.
    """
    list_cmd = ["terraform", "workspace", "list", "-no-color"]
    list_output = await run_command(
        list_cmd,
        sensitive=sensitive,
        env=env,
        cwd=terraform_path,
        suppress_env_vars=["TF_WORKSPACE"],  # << Key addition
    )

    def strip_workspace_line(line: str) -> str:
        return line.lstrip("*").strip()

    return [strip_workspace_line(line) for line in list_output.splitlines()]


async def ensure_terraform_workspace(
    root_name: str,
    workspace_name: str,
    base_path: str,
    env: Optional[Dict[str, str]],
    sensitive: bool,
) -> None:
    """
    Idempotently ensures that 'workspace_name' exists in the specified Terraform
    root directory. If it doesn't exist, calls 'terraform workspace new <workspace_name>'.

    We also suppress TF_WORKSPACE when creating so Terraform doesn't see it as an override.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    existing_workspaces = await _list_workspaces(terraform_path, env, sensitive)
    if workspace_name not in existing_workspaces:
        new_cmd = ["terraform", "workspace", "new", workspace_name, "-no-color"]
        await run_command(
            new_cmd,
            sensitive=sensitive,
            env=env,
            cwd=terraform_path,
            suppress_env_vars=["TF_WORKSPACE"],  # << Key addition
        )


def _set_tf_workspace(
    env: Optional[Dict[str, str]], workspace_name: str
) -> Dict[str, str]:
    """
    Returns a *copy* of the environment dict with TF_WORKSPACE set to
    'workspace_name'. Raises ValueError if env already contains TF_WORKSPACE.
    """
    new_env = dict(env) if env else {}
    if "TF_WORKSPACE" in new_env:
        raise ValueError(
            f"Cannot override existing TF_WORKSPACE={new_env['TF_WORKSPACE']} "
            f"with new workspace={workspace_name}"
        )
    new_env["TF_WORKSPACE"] = workspace_name
    return new_env


async def init_terraform(
    root_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    reconfigure: bool = False,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
) -> None:
    """
    Runs 'terraform init' in the specified root directory.
    Ensures Terraform does not get stuck due to TF_WORKSPACE remnants.
    """

    terraform_path = _validate_root_name(root_name, base_path)

    # 🔹 Step 1: Run Terraform init while suppressing TF_WORKSPACE
    cmd = ["terraform", "init", "-no-color"]
    if reconfigure:
        cmd.append("-reconfigure")

    await run_command(
        cmd,
        sensitive=sensitive,
        env=env,
        cwd=terraform_path,
        suppress_env_vars=["TF_WORKSPACE"],
    )


async def apply_terraform(
    root_name: str,
    variables: Optional[Dict[str, Any]] = None,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    override_lock: bool = False,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    workspace: Optional[str] = None,
) -> None:
    """
    Runs 'terraform apply' with -auto-approve, using a temporary .tfvars file
    for variables if provided. If a 'workspace' is given, it is created if
    missing, and TF_WORKSPACE is set in the environment.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    final_env = env
    if workspace:
        await ensure_terraform_workspace(
            root_name, workspace, base_path, env, sensitive
        )
        final_env = _set_tf_workspace(env, workspace)

    cmd = ["terraform", "apply", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    tfvars_path = None

    if variables:
        # Create a temporary JSON tfvars
        temp_file = tempfile.NamedTemporaryFile(
            mode="w", dir="/dev/shm", delete=False, suffix=".auto.tfvars.json"
        )
        tfvars_path = temp_file.name
        temp_file.close()  # We'll write to it asynchronously below

        try:
            async with aiofiles.open(tfvars_path, "w") as f:
                await f.write(json.dumps(variables, indent=2))

            cmd.extend(["-var-file", tfvars_path])

            await run_command(
                cmd, sensitive=sensitive, env=final_env, cwd=terraform_path
            )
        finally:
            if tfvars_path and os.path.exists(tfvars_path):
                os.remove(tfvars_path)
    else:
        # No variables => just run directly
        await run_command(cmd, sensitive=sensitive, env=final_env, cwd=terraform_path)


async def destroy_terraform(
    root_name: str,
    variables: Optional[Dict[str, Any]] = None,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    override_lock: bool = False,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    workspace: Optional[str] = None,
) -> None:
    """
    Runs 'terraform destroy' with -auto-approve, using a temporary .tfvars file
    if variables are provided. If a 'workspace' is given, we skip destroying
    entirely if that workspace doesn't exist.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    final_env = env
    if workspace:
        # Also suppress TF_WORKSPACE while listing existing workspaces
        existing_workspaces = await _list_workspaces(terraform_path, env, sensitive)
        if workspace not in existing_workspaces:
            print(
                f"[destroy_terraform] Workspace '{workspace}' not found at '{root_name}' "
                "=> skipping destroy."
            )
            return
        final_env = _set_tf_workspace(env, workspace)

    cmd = ["terraform", "destroy", "-no-color", "-auto-approve"]
    if override_lock:
        cmd.append("-lock=false")

    tfvars_path = None

    if variables:
        # Create a temporary JSON tfvars
        temp_file = tempfile.NamedTemporaryFile(
            mode="w", dir="/dev/shm", delete=False, suffix=".auto.tfvars.json"
        )
        tfvars_path = temp_file.name
        temp_file.close()

        try:
            async with aiofiles.open(tfvars_path, "w") as f:
                await f.write(json.dumps(variables, indent=2))

            cmd.extend(["-var-file", tfvars_path])
            await run_command(
                cmd, sensitive=sensitive, env=final_env, cwd=terraform_path
            )
        finally:
            if tfvars_path and os.path.exists(tfvars_path):
                os.remove(tfvars_path)
    else:
        await run_command(cmd, sensitive=sensitive, env=final_env, cwd=terraform_path)


@async_retry(retries=30, delay=1.0)
async def read_terraform_state(
    root_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    workspace: Optional[str] = None,
) -> TerraformState:
    """
    Reads and parses the current Terraform state as JSON by running
    'terraform show -json'. If a 'workspace' is specified, it is created
    if missing, and TF_WORKSPACE is set in the environment.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    final_env = env
    if workspace:
        await ensure_terraform_workspace(
            root_name, workspace, base_path, env, sensitive
        )
        final_env = _set_tf_workspace(env, workspace)

    cmd = ["terraform", "show", "-json"]
    state_json = await run_command(
        cmd, sensitive=sensitive, env=final_env, cwd=terraform_path
    )
    return TerraformState.model_validate_json(state_json)


def get_output_from_state(
    state: TerraformState, output_name: str, output_type: Type[T]
) -> T:
    """
    Retrieves and validates a specific output from a TerraformState object.
    Raises KeyError if the output_name is not found, or ValueError if the
    type conversion fails.
    """
    output_value = state.values.outputs.get(output_name)
    if output_value is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_value.value, output_type)
