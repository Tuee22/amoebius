"""
amoebius/utils/async_command_runner.py

Provides a reusable asynchronous command runner with retry logic.

Usage example:
    from amoebius.utils.async_command_runner import run_command, CommandError

    try:
        output = await run_command(["ls", "-l"], env={"EXAMPLE": "1"}, retries=3)
        print(output)
    except CommandError as err:
        print(f"Command failed: {err}")
"""

import os
import asyncio
from typing import Dict, List, Optional

from typing_extensions import ParamSpec, TypeVar

from amoebius.utils.async_retry import async_retry

P = ParamSpec("P")
R = TypeVar("R")


class CommandError(Exception):
    """
    Represents a failure when executing a shell command.

    Attributes:
        message (str): The error message describing the command failure.
        return_code (Optional[int]): The return code if available.
    """

    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        """
        Initialize a CommandError.

        Args:
            message (str): The error message describing the command failure.
            return_code (Optional[int]): The exit code if known.
        """
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
    Executes a local command in a subprocess, asynchronously, with optional retries.

    This function supports input data via stdin, environment variable overrides,
    and ignoring certain return codes as successful.

    Args:
        command (List[str]): The command and arguments to execute.
        sensitive (bool, optional): If True, command details won't appear in the exception message.
        env (Optional[Dict[str, str]], optional): Extra environment variables to add or override.
        cwd (Optional[str], optional): Working directory for the command.
        input_data (Optional[str], optional): If provided, this string is passed to stdin.
        successful_return_codes (List[int], optional): Which return codes won't be treated as errors. Defaults to [0].
        retries (int, optional): How many times to retry on failure. Defaults to 3.
        retry_delay (float, optional): Delay in seconds between retries. Defaults to 1.0.
        suppress_env_vars (Optional[List[str]], optional):
            A list of environment variables to remove from the environment before execution.

    Returns:
        str: The captured stdout of the command on success.

    Raises:
        CommandError: If the command fails after retries or returns a code not in `successful_return_codes`.
    """

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_command() -> str:
        # Prepare environment if necessary
        if env is None and not suppress_env_vars:
            proc_env = None
        else:
            proc_env = os.environ.copy()
            if suppress_env_vars:
                for var in suppress_env_vars:
                    proc_env.pop(var, None)
            if env:
                proc_env.update(env)

        # If input_data is provided, we'll pass a PIPE for stdin; otherwise /dev/null.
        stdin = asyncio.subprocess.PIPE if input_data else asyncio.subprocess.DEVNULL

        proc = await asyncio.create_subprocess_exec(
            *command,
            stdin=stdin,
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
