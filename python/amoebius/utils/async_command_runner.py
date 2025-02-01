"""
Async Command and SSH Utilities (AsyncSSH Version)
==================================================

Provides asynchronous utilities to execute shell commands, including:
  - local commands (run_command)
  - SSH commands (run_ssh_command)
  - kubectl commands locally or via SSH

Uses AsyncSSH for SSH in a MyPy --strict friendly way,
defining our own verify_host_key classes instead of subclassing HostKeyPolicy.
"""

import asyncio
import os
import base64
from typing import Dict, List, Optional, Union

from pydantic import BaseModel, Field, validator

# If your "async_retry" decorator is the same, just import it:
from .async_retry import async_retry

# AsyncSSH
import asyncssh
from asyncssh import SSHCompletedProcess, SSHKey

###############################################################################
# CommandError
###############################################################################


class CommandError(Exception):
    """Exception raised when a shell command execution fails."""

    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        super().__init__(message)
        self.return_code = return_code


###############################################################################
# run_command (Local Shell)
###############################################################################


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
    Execute a local shell command asynchronously in a subprocess.
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


###############################################################################
# SSHConfig / SSHResult
###############################################################################


class SSHConfig(BaseModel):
    """
    SSH connection configuration for AsyncSSH usage.
    If 'server_key' is provided, we do strict host key checking.
    Otherwise, we trust on first use (TOFU).
    """

    user: str
    hostname: str
    port: int = Field(default=22, ge=1, le=65535)
    private_key: str
    server_key: Optional[str] = None  # e.g., "ssh-rsa AAAAB3NzaC1yc2E..."

    @validator("private_key")
    def validate_private_key(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("private_key must be a non-empty string")
        return v


class SSHResult(BaseModel):
    """
    Represents the result of an SSH command execution.

    Attributes:
        stdout (str): The remote command's stdout.
        newly_accepted_server_key (Optional[str]): If TOFU was used, the server's key.
    """

    stdout: str
    newly_accepted_server_key: Optional[str] = None


###############################################################################
# Custom "HostKeyPolicy"-like classes
###############################################################################
# AsyncSSH allows you to pass any object with a 'verify_host_key' method
# that returns True or raises an exception on mismatch.


class StrictHostKeyPolicy:
    """
    Enforces that the remote host key *exactly* matches SSHConfig.server_key.
    Raises KeyExchangeFailed if it does not match.
    """

    def __init__(self, expected_key_line: str) -> None:
        self.expected_key_line: str = expected_key_line.strip()

    async def verify_host_key(
        self, conn: asyncssh.SSHClientConnection, host: str, port: int, key: SSHKey
    ) -> bool:
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
    Trust On First Use policy. Automatically accepts any *new* host key.
    Records the accepted host key to return it to the caller if desired.
    """

    def __init__(self) -> None:
        self.newly_accepted_key: Optional[str] = None

    async def verify_host_key(
        self, conn: asyncssh.SSHClientConnection, host: str, port: int, key: SSHKey
    ) -> bool:
        self.newly_accepted_key = encode_host_key(key)
        return True


def encode_host_key(key: SSHKey) -> str:
    """Convert an AsyncSSH SSHKey to the typical "ssh-rsa AAAAB3Nza..." format."""
    key_type: str = key.get_algorithm()
    b64_data: str = base64.b64encode(key.public_data).decode("ascii")
    return f"{key_type} {b64_data}"


###############################################################################
# run_ssh_command
###############################################################################


async def run_ssh_command(
    ssh_config: SSHConfig,
    remote_command: List[str],
    env: Optional[Dict[str, str]] = None,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> SSHResult:
    shell_cmd: str = " ".join(remote_command)

    # Host key policy can be either Strict or TOFU
    from typing import Union

    host_key_policy: Union[StrictHostKeyPolicy, TofuHostKeyPolicy]

    if ssh_config.server_key:
        host_key_policy = StrictHostKeyPolicy(ssh_config.server_key)
        tofu_policy: Optional[TofuHostKeyPolicy] = None
    else:
        tofu = TofuHostKeyPolicy()
        host_key_policy = tofu
        tofu_policy = tofu

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_ssh() -> SSHResult:
        # Import private key (sync function).
        client_key = asyncssh.import_private_key(ssh_config.private_key)

        async with asyncssh.connect(
            host=ssh_config.hostname,
            port=ssh_config.port,
            username=ssh_config.user,
            client_keys=[client_key],
            known_hosts=None,
            host_key_policy=host_key_policy,  # we pass the object we created
        ) as conn:
            result: SSHCompletedProcess = await conn.run(
                shell_cmd, env=env, check=False, encoding="utf-8"
            )

            raw_out = result.stdout if result.stdout is not None else ""
            if isinstance(raw_out, bytes):
                out_str: str = raw_out.decode("utf-8", "replace").strip()
            else:
                out_str = raw_out.strip()

            raw_err = result.stderr if result.stderr is not None else ""
            if isinstance(raw_err, bytes):
                err_str: str = raw_err.decode("utf-8", "replace").strip()
            else:
                err_str = raw_err.strip()

            if result.returncode != 0:
                detail: str = ""
                if not sensitive:
                    detail = (
                        f"\nCommand: {shell_cmd}\nStdout: {out_str}\nStderr: {err_str}"
                    )
                raise CommandError(
                    f"Remote command failed with exit status {result.returncode}.{detail}",
                    result.returncode,
                )

            # If TOFU was used, retrieve any newly accepted server key
            new_key: Optional[str] = (
                tofu_policy.newly_accepted_key if tofu_policy else None
            )
            return SSHResult(stdout=out_str, newly_accepted_server_key=new_key)

    return await _inner_run_ssh()


###############################################################################
# KubectlCommand, run_kubectl, run_ssh_kubectl_command
###############################################################################


class KubectlCommand(BaseModel):
    """Model representing a kubectl exec command."""

    namespace: str
    pod: str
    container: Optional[str] = None
    command: List[str]
    env: Dict[str, str] = {}

    def build_kubectl_args(self) -> List[str]:
        """
        Construct the full argument list for `kubectl exec`.
        We'll do: kubectl exec <pod> -n <namespace> [-c container] -- env KEY=val ... <command...>
        """
        base = ["kubectl", "exec", self.pod, "-n", self.namespace]
        if self.container:
            base += ["-c", self.container]
        base.append("--")
        if self.env:
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
    """Execute a kubectl exec command locally (no SSH)."""
    args = kube_cmd.build_kubectl_args()
    return await run_command(
        command=args,
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )


async def run_ssh_kubectl_command(
    ssh_config: SSHConfig,
    kube_cmd: KubectlCommand,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> SSHResult:
    """
    Execute `kubectl exec` remotely via SSH using AsyncSSH.
    """
    remote_args = kube_cmd.build_kubectl_args()
    return await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=remote_args,
        env=None,  # environment is embedded in the kubectl command
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )


###############################################################################
# Example usage
###############################################################################
#
# async def example_usage():
#     ssh_conf = SSHConfig(
#         user="ubuntu",
#         hostname="my-remote-host",
#         private_key="-----BEGIN OPENSSH PRIVATE KEY-----\n...",
#         server_key=None  # means do TOFU
#     )
#
#     # We want to run a simple remote command:
#     result = await run_ssh_command(ssh_conf, ["echo", "'Hello from AsyncSSH'"])
#     print("Remote echo stdout:", result.stdout)
#     if result.newly_accepted_server_key:
#         print("Newly accepted host key:", result.newly_accepted_server_key)
#
#     # Kubectl example:
#     kube_cmd = KubectlCommand(
#         namespace="default",
#         pod="my-pod",
#         container="my-container",
#         command=["vault", "read", "secret/mysecret"],
#         env={"FOO": "123", "BAR": "xyz"}
#     )
#
#     # Run kubectl locally:
#     local_output = await run_kubectl(kube_cmd)
#     print("Local kubectl output:", local_output)
#
#     # Or run kubectl on a remote host:
#     ssh_result = await run_ssh_kubectl_command(ssh_conf, kube_cmd)
#     print("SSH kubectl stdout:", ssh_result.stdout)
#     if ssh_result.newly_accepted_server_key:
#         print("Newly accepted server key:", ssh_result.newly_accepted_server_key)
