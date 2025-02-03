"""
Async Command and SSH Utilities (AsyncSSH Version)
==================================================

Provides asynchronous utilities to execute shell commands, both locally
and via SSH, and includes a helper class for constructing `kubectl exec` commands.

Key Features
------------
1. **Local Commands**  
   - `run_command(...)`: Executes a local command asynchronously using `asyncio.create_subprocess_exec`,
     with retry logic and error reporting. Arguments are provided as a list, avoiding shell
     expansion and thus mitigating injection risks.

2. **SSH Commands (AsyncSSH)**  
   - `run_ssh_command(...)`: Executes a command on a remote host via SSH, with either strict
     host key checking (if a known server key is provided) or trust-on-first-use (TOFU) if none
     is specified.  
   - Environment variables can be passed to the remote command via `conn.run(..., env=...)`.

3. **Kubectl Exec Commands**  
   - `KubectlCommand`: A Pydantic model describing a `kubectl exec` invocation, including
     namespace, pod, container, the command, and optional environment variables.
   - `run_kubectl(...)`: Runs kubectl locally using `run_command(...)`.
   - `run_ssh_kubectl_command(...)`: Combines SSH + kubectl for remote usage.

Security Considerations
-----------------------
1. **Local Shell Safety**  
   When calling `run_command`, arguments are passed as a list to `create_subprocess_exec`,
   avoiding shell parsing. This protects against common command-injection vectors if arguments
   contain special shell characters.

2. **Remote Shell Safety**  
   `run_ssh_command(...)` passes a list of tokens to AsyncSSH’s `conn.run(...)`, which similarly
   avoids an intervening shell. If you provide a single string, it might be interpreted by a
   shell on the remote side; thus, we recommend splitting the command into tokens if possible.

3. **TOFU vs. Strict Host Key Checking**  
   - If `SSHConfig.server_key` is non-empty, we enforce strict checking against that key string.
   - Otherwise, we do trust-on-first-use via `TofuHostKeyPolicy`, capturing the new host key so
     the caller can store it for future strict checks.

4. **Kubectl Command**  
   The `KubectlCommand` model builds a list of tokens for `kubectl exec`. If environment variables
   are specified, they are inserted via an `env` subcommand, again minimizing shell expansion risk.

All code here is structured to pass MyPy's `--strict` checks, including the custom host key policies
and typed handling of AsyncSSH’s stdout/stderr values.
"""

import asyncio
import os
import base64
from typing import Dict, List, Optional, Union

import asyncssh
from asyncssh import SSHCompletedProcess, SSHKey

from pydantic import BaseModel, Field, validator

from .async_retry import async_retry


class CommandError(Exception):
    """
    Represents a failure when executing a shell command, either locally or remotely.

    Attributes:
        message (str): Description of the error.
        return_code (Optional[int]): The command's exit code, if available.
    """

    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        super().__init__(message)
        self.return_code = return_code


async def run_command(
    command: List[str],
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    cwd: Optional[str] = None,
    input_data: Optional[str] = None,
    successful_return_codes: List[int] = [0],
    *,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Executes a local command in a subprocess, asynchronously, using asyncio.create_subprocess_exec.

    This function:
      1. Accepts command tokens as a list (no shell parsing), mitigating injection risks.
      2. Captures stdout and stderr. If the command’s return code is outside `successful_return_codes`,
         raises CommandError.
      3. Retries on failure up to `retries` times, waiting `retry_delay` seconds each attempt.

    Args:
        command (List[str]): Command tokens for local execution, e.g. ["ls", "-l", "/tmp"].
        sensitive (bool): If True, error messages omit stdout/stderr if the command fails.
        env (Optional[Dict[str, str]]): Additional environment variables for the subprocess.
        cwd (Optional[str]): Working directory for the subprocess.
        input_data (Optional[str]): Text to send to the command’s stdin.
        successful_return_codes (List[int]): Treated as success if the process exits with these codes.
        retries (int): Number of retry attempts on transient failures.
        retry_delay (float): Seconds between retries.

    Returns:
        str: The stdout content if the command succeeds.

    Raises:
        CommandError: If all retries fail or the command returns a code not in `successful_return_codes`.
    """

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_command() -> str:
        process_env: Dict[str, str] = dict(os.environ)
        if env:
            process_env.update(env)

        proc = await asyncio.create_subprocess_exec(
            *command,
            stdin=asyncio.subprocess.PIPE if input_data else None,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=process_env,
            cwd=cwd,
        )
        stdout_bytes, stderr_bytes = await proc.communicate(
            input=input_data.encode() if input_data else None
        )
        stdout_str: str = stdout_bytes.decode(errors="replace").strip()
        stderr_str: str = stderr_bytes.decode(errors="replace").strip()

        if proc.returncode not in successful_return_codes:
            details: str = ""
            if not sensitive:
                details = (
                    f"\nCommand: {' '.join(command)}"
                    f"\nStdout: {stdout_str}"
                    f"\nStderr: {stderr_str}"
                )
            raise CommandError(
                f"Command failed with return code {proc.returncode}.{details}",
                proc.returncode,
            )
        return stdout_str

    return await _inner_run_command()


class SSHConfig(BaseModel):
    """
    SSH configuration for connecting to a remote host via AsyncSSH.

    Fields:
        user (str): SSH username.
        hostname (str): Remote host/IP.
        port (int): SSH port, default 22.
        private_key (str): Private key contents (text), not a path. Must be non-empty.
        server_key (Optional[str]): If specified, we do strict host key checking; otherwise, TOFU.
    """

    user: str
    hostname: str
    port: int = Field(default=22, ge=1, le=65535)
    private_key: str
    server_key: Optional[str] = None

    @validator("private_key")
    def validate_private_key(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("private_key must be a non-empty string")
        return v


class SSHResult(BaseModel):
    """
    Represents the output of a remote SSH command.

    Fields:
        stdout (str): The remote command's standard output.
        newly_accepted_server_key (Optional[str]): If we used TOFU and accepted
            a new host key, it is recorded here.
    """

    stdout: str
    newly_accepted_server_key: Optional[str] = None


class StrictHostKeyPolicy:
    """
    A custom policy enforcing strict host key checking:
    the remote host key must match the known server_key exactly.
    Raises KeyExchangeFailed if there's a mismatch.
    """

    def __init__(self, expected_key_line: str) -> None:
        self.expected_key_line: str = expected_key_line.strip()

    async def verify_host_key(
        self, conn: asyncssh.SSHClientConnection, host: str, port: int, key: SSHKey
    ) -> bool:
        """
        Verifies the remote host key equals expected_key_line.
        Returns True if it matches, otherwise raises KeyExchangeFailed.
        """
        actual_key_line: str = encode_host_key(key)
        if actual_key_line.strip() == self.expected_key_line:
            return True
        raise asyncssh.KeyExchangeFailed(
            f"Host key mismatch:\n"
            f"  expected: {self.expected_key_line}\n"
            f"  got:      {actual_key_line}"
        )


class TofuHostKeyPolicy:
    """
    A trust-on-first-use (TOFU) policy: automatically accepts any presented host key,
    recording it so the caller can store it for future strict checking.
    """

    def __init__(self) -> None:
        self.newly_accepted_key: Optional[str] = None

    async def verify_host_key(
        self, conn: asyncssh.SSHClientConnection, host: str, port: int, key: SSHKey
    ) -> bool:
        """
        Accepts any host key, capturing it in newly_accepted_key.
        Returns True unconditionally.
        """
        self.newly_accepted_key = encode_host_key(key)
        return True


def encode_host_key(key: SSHKey) -> str:
    """
    Converts an AsyncSSH SSHKey to the typical "ssh-rsa AAAAB3Nza..." format.

    Args:
        key (SSHKey): The public key object from AsyncSSH.

    Returns:
        str: e.g. "ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB..."
    """
    key_type: str = key.get_algorithm()
    b64_data: str = base64.b64encode(key.public_data).decode("ascii")
    return f"{key_type} {b64_data}"


async def run_ssh_command(
    ssh_config: SSHConfig,
    remote_command: List[str],
    env: Optional[Dict[str, str]] = None,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> SSHResult:
    """
    Executes a command on a remote host via AsyncSSH, supporting strict or TOFU host key checks.

    If ssh_config.server_key is set, we create a StrictHostKeyPolicy. Otherwise, we create
    TofuHostKeyPolicy to accept any new host key. In that case, we return the newly accepted key
    so the caller can record it.

    We pass remote_command as a list to avoid shell parsing, which helps mitigate injection.

    Args:
        ssh_config (SSHConfig): SSH connection config (username, hostname, etc.).
        remote_command (List[str]): The command tokens to run remotely.
        env (Optional[Dict[str, str]]): Additional environment variables for the remote command.
        sensitive (bool): If True, omit stdout/stderr from CommandError on failure.
        retries (int): Number of retry attempts on failure.
        retry_delay (float): Seconds between retries.

    Returns:
        SSHResult: stdout of the command and possibly a newly accepted host key.

    Raises:
        CommandError: If the command fails after all retries or returns a nonzero exit code.
    """
    # We'll define a union of possible host key policy types
    HostKeyPolicyType = Union[StrictHostKeyPolicy, TofuHostKeyPolicy]
    host_key_policy: HostKeyPolicyType

    if ssh_config.server_key:
        host_key_policy = StrictHostKeyPolicy(ssh_config.server_key)
        tofu_policy: Optional[TofuHostKeyPolicy] = None
    else:
        tofu = TofuHostKeyPolicy()
        host_key_policy = tofu
        tofu_policy = tofu

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_ssh() -> SSHResult:
        client_key = asyncssh.import_private_key(ssh_config.private_key)

        async with asyncssh.connect(
            host=ssh_config.hostname,
            port=ssh_config.port,
            username=ssh_config.user,
            client_keys=[client_key],
            known_hosts=None,
            host_key_policy=host_key_policy,
        ) as conn:
            # Provide command tokens to run() to avoid shell expansion on the remote side.
            result: SSHCompletedProcess = await conn.run(
                remote_command, env=env, check=False, encoding="utf-8"
            )

            raw_out = result.stdout
            raw_err = result.stderr

            # Convert result.stdout/stderr to strings safely
            out_str: str
            if raw_out is None:
                out_str = ""
            elif isinstance(raw_out, bytes):
                out_str = raw_out.decode("utf-8", "replace").strip()
            else:
                out_str = raw_out.strip()

            err_str: str
            if raw_err is None:
                err_str = ""
            elif isinstance(raw_err, bytes):
                err_str = raw_err.decode("utf-8", "replace").strip()
            else:
                err_str = raw_err.strip()

            if result.returncode != 0:
                detail = ""
                if not sensitive:
                    detail = (
                        f"\nCommand: {remote_command}"
                        f"\nStdout: {out_str}"
                        f"\nStderr: {err_str}"
                    )
                raise CommandError(
                    f"Remote command failed with exit status {result.returncode}.{detail}",
                    result.returncode,
                )

            # If we used TOFU, retrieve any newly accepted host key
            new_key: Optional[str] = None
            if tofu_policy and tofu_policy.newly_accepted_key:
                new_key = tofu_policy.newly_accepted_key

            return SSHResult(stdout=out_str, newly_accepted_server_key=new_key)

    return await _inner_run_ssh()


class KubectlCommand(BaseModel):
    """
    Describes a 'kubectl exec' command in Pydantic form.

    Fields:
        namespace (str): Kubernetes namespace of the pod.
        pod (str): The name of the pod to exec into.
        container (Optional[str]): The container name, if multiple exist.
        command (List[str]): The actual command and arguments to run in the container.
        env (Optional[Dict[str, str]]): Optional environment variables to pass via an 'env' subcommand.
    """

    namespace: str
    pod: str
    container: Optional[str] = None
    command: List[str]
    env: Optional[Dict[str, str]] = None

    def build_kubectl_args(self) -> List[str]:
        """
        Constructs the argument list for 'kubectl exec'.

        Example:
          - "kubectl exec mypod -n default [-c mycontainer] -- env FOO=bar BAZ=qux <command...>"

        Returns:
            List[str]: Tokens suitable for 'run_command()' or 'run_ssh_command()'.
        """
        base = ["kubectl", "exec", self.pod, "-n", self.namespace]

        if self.container:
            base += ["-c", self.container]

        base.append("--")

        if self.env:
            # If environment variables exist, we insert an 'env' subcommand
            # e.g. ["env", "FOO=bar", "BAZ=qux"]
            env_part = ["env"] + [f"{k}={v}" for k, v in self.env.items()]
            base += env_part

        base += self.command
        return base


async def run_kubectl(
    kube_cmd: KubectlCommand,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Executes a 'kubectl exec' command locally via run_command, using the tokenized
    argument list from build_kubectl_args().

    Args:
        kube_cmd (KubectlCommand): Pydantic model describing 'kubectl exec'.
        sensitive (bool): If True, hides stdout/stderr in error messages upon failure.
        retries (int): Number of times to retry on failure.
        retry_delay (float): Seconds to wait between retries.

    Returns:
        str: The stdout from 'kubectl exec' if successful.

    Raises:
        CommandError: If the command fails after all retries.
    """
    args = kube_cmd.build_kubectl_args()
    return await run_command(
        command=args, sensitive=sensitive, retries=retries, retry_delay=retry_delay
    )


async def run_ssh_kubectl_command(
    ssh_config: SSHConfig,
    kube_cmd: KubectlCommand,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> SSHResult:
    """
    Executes a 'kubectl exec' command on a remote host via SSH, combining run_ssh_command
    with the arguments built by the KubectlCommand model.

    Args:
        ssh_config (SSHConfig): Remote SSH settings (user, host, key, etc.).
        kube_cmd (KubectlCommand): The 'kubectl exec' definition (namespace, pod, etc.).
        sensitive (bool): If True, omits stdout/stderr from error messages on failure.
        retries (int): Number of retries for transient failures.
        retry_delay (float): Delay in seconds between retries.

    Returns:
        SSHResult: Contains stdout from 'kubectl exec' and a newly accepted server key if using TOFU.

    Raises:
        CommandError: If all retries fail or the remote command returns a non-zero exit code.
    """
    remote_args = kube_cmd.build_kubectl_args()
    return await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=remote_args,
        env=None,
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )
