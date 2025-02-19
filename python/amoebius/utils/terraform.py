"""
terraform.py

This module provides a declarative approach to managing Terraform workspaces
and running Terraform commands asynchronously, while ensuring workspace creation
is idempotent. If a workspace does not exist, it is automatically created.
Otherwise, if it already exists, no error is raised.

Key Points:
-----------
1) Local vs. Remote State:
   Even if you configure Terraform to store its state remotely (e.g., in S3),
   Terraform still requires a local .terraform folder for provider plugins,
   backend configuration, and workspace metadata. If you run Terraform in a
   fresh environment (like a new container), you must call 'init_terraform'
   at least once to re-establish that local folder.

2) Workspace Handling:
   - The 'ensure_terraform_workspace' function is idempotent: it checks if a
     workspace already exists and only creates it if missing.
   - Each core command (init, apply, destroy, read_state) takes an optional
     'workspace' parameter. If provided, it calls 'ensure_terraform_workspace'
     and then appends '-workspace=<NAME>' to the actual Terraform command.

3) No Hidden State Merging:
   We pass 'env' (environment variables) directly to 'run_command'. If 'env' is
   None, 'run_command' uses its defaults. If 'env' is a dict, 'run_command'
   merges it with the current process environment on your behalf.

Requires:
---------
- Terraform 1.3+ for the global '-workspace=<NAME>' flag (currently marked
  “unstable” by HashiCorp).
- Your existing 'run_command' function from 'amoebius.utils.async_command_runner'.
- A 'TerraformState' model to deserialize JSON state output.
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


async def ensure_terraform_workspace(
    root_name: str,
    workspace_name: str,
    base_path: str = DEFAULT_TERRAFORM_ROOTS,
    env: Optional[Dict[str, str]] = None,
    sensitive: bool = True,
) -> None:
    """
    Idempotently ensures that 'workspace_name' exists in the specified Terraform
    root directory. If it doesn't exist, it is created. If it does exist,
    this function returns without error.

    Implementation:
    ---------------
    1) 'terraform workspace list' is called to check existing workspaces.
    2) Transform each line to remove leading '*' and whitespace.
    3) If 'workspace_name' is missing, call 'terraform workspace new <name>'.

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

    # 1) List existing workspaces
    list_cmd = ["terraform", "workspace", "list", "-no-color"]
    list_output = await run_command(
        list_cmd, sensitive=sensitive, env=env, cwd=terraform_path
    )

    # 2) Transform each line to remove leading '*' and whitespace
    def strip_workspace_line(line: str) -> str:
        return line.lstrip("*").strip()

    existing_workspaces = [
        strip_workspace_line(line) for line in list_output.splitlines()
    ]

    # 3) If not in the list, create it
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

    # If user requested a workspace, ensure it exists
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

    # Ensure workspace, if requested
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
    If 'workspace' is provided, ensures that workspace is present and uses
    '-workspace=<NAME>'.

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

    # Ensure workspace, if requested
    if workspace:
        await ensure_terraform_workspace(
            root_name, workspace, base_path, env, sensitive
        )

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
) -> "TerraformState":
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

    # Ensure workspace, if requested
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
    state: "TerraformState", output_name: str, output_type: Type[T]
) -> T:
    """
    Retrieves and validates a specific output from a TerraformState object.

    Args:
        state:       A TerraformState object representing the current Terraform outputs.
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
