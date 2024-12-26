import os
import asyncio
import socket
from contextlib import asynccontextmanager
from typing import Dict, List, Optional


class CommandError(Exception):
    """Custom exception for command execution errors.

    Attributes:
        message: A description of the error.
        return_code: The return code of the failed command, if applicable.
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
    retries: int = 3,
    retry_delay: int = 1,
    successful_return_codes: List[int] = [0],
) -> str:
    """Run a shell command asynchronously and return its stdout output.

    Args:
        command: The command and arguments to execute.
        sensitive: If True, command details and output are hidden in errors.
        env: Optional environment variables to set for the process.
        cwd: Optional working directory for the process.
        input_data: Optional string to pass to the process's stdin.
        retries: Number of times to retry the command if it fails.
        retry_delay: Delay in seconds between retries.
        successful_return_codes: List of all return codes to be treated as success.

    Returns:
        The stdout output of the command as a string.

    Raises:
        CommandError: If the command fails after the given number of retries.
    """
    try:
        process = await asyncio.create_subprocess_exec(
            *command,
            stdin=asyncio.subprocess.PIPE if input_data else None,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env={**os.environ, **env} if env else None,
            cwd=cwd,
        )
        stdout_bytes, stderr_bytes = await process.communicate(
            input=input_data.encode() if input_data else None
        )
        if process.returncode not in successful_return_codes:
            raise CommandError(
                (
                    f"Command failed with return code {process.returncode}"
                    + (
                        f"\nCommand: {' '.join(command)}"
                        f"\nStdout: {stdout_bytes.decode()}"
                        f"\nStderr: {stderr_bytes.decode()}"
                        if not sensitive
                        else ""
                    )
                ),
                process.returncode,
            )
        return stdout_bytes.decode().strip()
    except CommandError as e:
        if retries > 0:
            await asyncio.sleep(retry_delay)
            return await run_command(
                command, sensitive, env, cwd, input_data, retries - 1, retry_delay
            )
        else:
            raise e
