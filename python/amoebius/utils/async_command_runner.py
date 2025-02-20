import os
import asyncio
from typing import Dict, List, Optional
from typing_extensions import ParamSpec, TypeVar

from .async_retry import async_retry

P = ParamSpec("P")
R = TypeVar("R")


class CommandError(Exception):
    """
    Represents a failure when executing a shell command.
    """

    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        super().__init__(message)
        self.return_code = return_code


async def run_command(
    command: List[str],
    *,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    cwd: Optional[str] = None,
    input_data: Optional[str] = None,
    successful_return_codes: List[int] = [0],
    retries: int = 3,
    retry_delay: float = 1.0,
    suppress_env_vars: Optional[List[str]] = None,
) -> str:
    """
    Executes a local command in a subprocess, asynchronously, retrying if needed.

    :param command: The command and arguments to execute.
    :param sensitive: If True, we won't print command details in exceptions.
    :param env: Environment variables to merge on top of the parent process env.
    :param cwd: Working directory for the subprocess.
    :param input_data: Optional string data to pass to stdin.
    :param successful_return_codes: List of acceptable return codes that won't raise an exception.
    :param retries: How many times to retry failures.
    :param retry_delay: Delay (seconds) between retries.
    :param suppress_env_vars: List of environment variable names to remove from
                              the final environment before running the command.
    :return: The captured stdout of the command on success.
    :raises CommandError: If the command fails more than `retries` times or returns
                         a code not in `successful_return_codes`.
    """

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_command() -> str:
        # If no env modifications are requested, pass None to create_subprocess_exec
        # to avoid copying the environment unnecessarily (for performance).
        if env is None and not suppress_env_vars:
            proc_env = None
        else:
            # Otherwise, start with a copy of the parent process environment
            proc_env = os.environ.copy()

            # Remove (suppress) specific environment variables if needed
            if suppress_env_vars:
                for var in suppress_env_vars:
                    proc_env.pop(var, None)

            # Merge in any environment variables the caller wants to set/override
            if env:
                proc_env.update(env)

        proc = await asyncio.create_subprocess_exec(
            *command,
            stdin=asyncio.subprocess.PIPE if input_data else None,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=proc_env,
            cwd=cwd,
        )
        stdout_bytes, stderr_bytes = await proc.communicate(
            input=input_data.encode() if input_data else None
        )
        stdout_str = stdout_bytes.decode(errors="replace").strip()
        stderr_str = stderr_bytes.decode(errors="replace").strip()

        if proc.returncode not in successful_return_codes:
            detail = ""
            if not sensitive:
                detail = (
                    f"\nCommand: {' '.join(command)}"
                    f"\nStdout: {stdout_str}"
                    f"\nStderr: {stderr_str}"
                )
            raise CommandError(
                f"Command failed with return code {proc.returncode}.{detail}",
                proc.returncode,
            )
        return stdout_str

    return await _inner_run_command()
