"""
terraform.py

This module provides a declarative approach to managing Terraform workspaces
and running Terraform commands asynchronously. Notable behaviors:

1) Idempotent Workspace Creation:
   - 'ensure_terraform_workspace' checks if a workspace exists and creates
     it if missing.

2) Skip Destroy if Workspace Doesn't Exist:
   - In 'destroy_terraform', if a non-default workspace is requested but
     not found, we skip the destroy entirely.

3) Local vs. Remote State:
   Even if you use a remote backend (e.g., S3), Terraform still needs a local
   .terraform folder for provider plugins, backend configs, and workspace
   metadata. So, you must run 'init_terraform' at least once in each fresh
   environment.

Requires:
---------
- Terraform 1.3+ for the global '-workspace=<NAME>' CLI flag.
- 'run_command' from amoebius.utils.async_command_runner for async command execution.
- 'TerraformState' from amoebius.models.terraform_state for parsing JSON output.
"""

import os
from typing import Any, Optional, Dict, Type, TypeVar

from pydantic import ValidationError

from amoebius.models.terraform_state import TerraformState
from amoebius.models.validator import validate_type
from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.utils.async_retry import async_retry

T = TypeVar("T")

# Default path for Terraform root directories
DEFAULT_TERRAFORM_ROOTS = "/amoebius/terraform/roots"


def _validate_root_name(root_name: str, base_path: str) -> str:
    """
    Validate the Terraform root name, returning the absolute path to the
    corresponding directory.

    Args:
        root_name: A string name for the Terraform root folder (no slashes allowed).
        base_path: Base path under which the named Terraform root resides.

    Returns:
        A string with the full path to the Terraform root directory.

    Raises:
        ValueError: If 'root_name' is empty or if the directory does not exist.
    """
    if not root_name.strip():
        raise ValueError("Root name cannot be empty")

    terraform_path = os.path.join(base_path, root_name)
    if not os.path.isdir(terraform_path):
        raise ValueError(f"Terraform root directory not found: {terraform_path}")

    return terraform_path


async def _list_workspaces(
    terraform_path: str, env: Optional[Dict[str, str]], sensitive: bool
) -> list[str]:
    """
    Returns a list of existing Terraform workspace names for the given path.

    Calls:
        terraform workspace list -no-color

    Then strips out the leading "*" from the currently selected workspace
    and any leading/trailing whitespace.

    Args:
        terraform_path: Absolute path to the Terraform root directory.
        env:            Environment variables for 'run_command'.
        sensitive:      If True, hides detailed output when command fails.

    Returns:
        A list of workspace names (e.g. ["default", "staging", "prod"]).

    Raises:
        CommandError: If 'terraform workspace list' fails.
    """
    list_cmd = ["terraform", "workspace", "list", "-no-color"]
    list_output = await run_command(
        list_cmd, sensitive=sensitive, env=env, cwd=terraform_path
    )

    def strip_workspace_line(line: str) -> str:
        return line.lstrip("*").strip()

    return [strip_workspace_line(line) for line in list_output.splitlines()]


async def ensure_terraform_workspace(
    root_name: str,
    workspace_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    env: Optional[Dict[str, str]] = None,
    sensitive: bool = True,
) -> None:
    """
    Idempotently ensures that 'workspace_name' exists in the specified Terraform
    root directory. If it doesn't exist, it is created. If it does exist, this
    function does nothing.

    Implementation:
    ---------------
    1) Lists existing workspaces via '_list_workspaces(...)'.
    2) If 'workspace_name' is missing, calls 'terraform workspace new <workspace_name>'.

    Args:
        root_name:      Name of the Terraform root directory (no slashes allowed).
        workspace_name: The workspace to ensure. If it already exists, no error.
        base_path:      Base path where Terraform root directories are located.
        env:            Environment variables passed directly to run_command.
        sensitive:      If True, hides detailed output when command fails.

    Raises:
        ValueError:   If the Terraform root directory is invalid or not found.
        CommandError: If any underlying Terraform command fails unexpectedly.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    existing_workspaces = await _list_workspaces(terraform_path, env, sensitive)
    if workspace_name not in existing_workspaces:
        new_cmd = ["terraform", "workspace", "new", workspace_name, "-no-color"]
        await run_command(new_cmd, sensitive=sensitive, env=env, cwd=terraform_path)


async def init_terraform(
    root_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    reconfigure: bool = False,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    workspace: Optional[str] = None,
) -> None:
    """
    Runs 'terraform init' in the specified root directory. If 'workspace' is
    provided, ensures that workspace is present (idempotently creating it if
    missing) and then appends '-workspace=<NAME>' to the init command.

    Even if you configure a remote backend (e.g., S3), you still must run
    'init' at least once in a fresh environment to populate the local .terraform
    folder with provider plugins and backend metadata.

    Args:
        root_name:    Terraform root directory name (no slashes allowed).
        base_path:    Base path under which the Terraform root directory resides.
        reconfigure:  If True, includes '-reconfigure' in the init command.
        sensitive:    If True, hides detailed output when command fails.
        env:          Environment variables passed to run_command.
        workspace:    Optional workspace name to ensure and use for this command.

    Raises:
        ValueError:   If the root directory is invalid.
        CommandError: If Terraform commands fail.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    if workspace:
        await ensure_terraform_workspace(
            root_name, workspace, base_path, env, sensitive
        )

    cmd = ["terraform"]
    if workspace:
        cmd.append(f"-workspace={workspace}")
    cmd += ["init", "-no-color"]

    if reconfigure:
        cmd.append("-reconfigure")

    await run_command(cmd, sensitive=sensitive, env=env, cwd=terraform_path)


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
    Runs 'terraform apply' with -auto-approve on the specified root directory.
    If 'workspace' is provided, ensures that workspace is present and uses
    '-workspace=<NAME>'.

    If you specify variables, they are passed along as '-var key=value'.

    Args:
        root_name:     Terraform root directory name (no slashes allowed).
        variables:     Dict of variable key/value pairs to pass via '-var'.
        base_path:     Base path under which the Terraform root directory resides.
        override_lock: If True, adds '-lock=false' to skip Terraform state locking.
        sensitive:     If True, hides detailed output when command fails.
        env:           Environment variables passed to run_command.
        workspace:     Optional workspace name to ensure and use for this command.

    Raises:
        ValueError:   If the root directory is invalid.
        CommandError: If Terraform commands fail.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    if workspace:
        await ensure_terraform_workspace(
            root_name, workspace, base_path, env, sensitive
        )

    cmd = ["terraform"]
    if workspace:
        cmd.append(f"-workspace={workspace}")
    cmd += ["apply", "-no-color", "-auto-approve"]

    if override_lock:
        cmd.append("-lock=false")

    if variables:
        for key, value in variables.items():
            cmd.extend(["-var", f"{key}={value}"])

    await run_command(cmd, sensitive=sensitive, env=env, cwd=terraform_path)


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
    Runs 'terraform destroy' with -auto-approve on the specified root directory.
    If 'workspace' is provided, we skip everything if that workspace does not
    exist (no error raised). Otherwise, we proceed as normal.

    Logic:
    ------
    1) If 'workspace' is given:
       a) List all existing workspaces.
       b) If 'workspace' isn't found, simply return (do nothing).
       c) Otherwise, run 'terraform destroy -workspace=...'
    2) If no 'workspace' is given, run a standard 'destroy' in the default workspace.

    Args:
        root_name:     Terraform root directory name (no slashes allowed).
        variables:     Dict of variable key/value pairs to pass via '-var'.
        base_path:     Base path under which the Terraform root directory resides.
        override_lock: If True, adds '-lock=false' to skip Terraform state locking.
        sensitive:     If True, hides detailed output when command fails.
        env:           Environment variables passed to run_command.
        workspace:     Optional workspace name to check for and destroy.

    Raises:
        ValueError:   If the root directory is invalid.
        CommandError: If Terraform commands fail for other reasons.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    if workspace:
        # List existing workspaces
        existing_workspaces = await _list_workspaces(terraform_path, env, sensitive)
        if workspace not in existing_workspaces:
            # If the workspace doesn't exist, do nothing
            print(
                f"[destroy_terraform] Workspace '{workspace}' not found at '{root_name}' "
                "=> skipping destroy."
            )
            return

    cmd = ["terraform"]
    if workspace:
        cmd.append(f"-workspace={workspace}")
    cmd += ["destroy", "-no-color", "-auto-approve"]

    if override_lock:
        cmd.append("-lock=false")

    if variables:
        for key, value in variables.items():
            cmd.extend(["-var", f"{key}={value}"])

    await run_command(cmd, sensitive=sensitive, env=env, cwd=terraform_path)


@async_retry(retries=30, delay=1.0)
async def read_terraform_state(
    root_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    workspace: Optional[str] = None,
) -> TerraformState:
    """
    Reads and parses Terraform state from 'terraform show -json'. If 'workspace'
    is provided, ensures that workspace is present and uses '-workspace=<NAME>'.

    The @async_retry decorator allows up to 30 retries with a 1-second delay
    between attempts, useful if the state is not yet consistent or if commands
    have transient failures.

    Args:
        root_name:   Terraform root directory name (no slashes allowed).
        base_path:   Base path under which the Terraform root directory resides.
        sensitive:   If True, hides detailed output when command fails.
        env:         Environment variables passed to run_command.
        workspace:   Optional workspace name to ensure and use for this command.

    Returns:
        A TerraformState object, parsed via Pydantic from the JSON output.

    Raises:
        ValueError:       If the root directory is invalid.
        ValidationError:  If the JSON output cannot be validated against
                          TerraformState.
        CommandError:     If the Terraform command fails.
    """
    terraform_path = _validate_root_name(root_name, base_path)

    if workspace:
        await ensure_terraform_workspace(
            root_name, workspace, base_path, env, sensitive
        )

    cmd = ["terraform"]
    if workspace:
        cmd.append(f"-workspace={workspace}")
    cmd += ["show", "-json"]

    state_json = await run_command(
        cmd, sensitive=sensitive, env=env, cwd=terraform_path
    )
    return TerraformState.model_validate_json(state_json)


def get_output_from_state(
    state: TerraformState, output_name: str, output_type: Type[T]
) -> T:
    """
    Retrieves and validates a specific output from a TerraformState object.

    Args:
        state:       A TerraformState object representing current Terraform outputs.
        output_name: The name of the desired output variable.
        output_type: A Python type (e.g., str, list, dict) that the output should match.

    Returns:
        The output value, typed/cast to the provided output_type.

    Raises:
        KeyError:   If 'output_name' is not found in the state's outputs.
        ValueError: If the output value cannot be coerced into 'output_type'.
    """
    output_value = state.values.outputs.get(output_name)
    if output_value is None:
        raise KeyError(f"Output '{output_name}' not found in Terraform state.")
    return validate_type(output_value.value, output_type)
