import os
import asyncio
from typing import Dict, List, Optional

# Import your retry decorator
from .async_retry import async_retry


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
    successful_return_codes: List[int] = [0],
    *,
    retries: int = 30,
    retry_delay: float = 1.0,
) -> str:
    """Run a shell command asynchronously and return its stdout output,
    with built-in retry logic.

    Args:
        command: The command and arguments to execute.
        sensitive: If True, command details and output are hidden in errors.
        env: Optional environment variables to set for the process.
        cwd: Optional working directory for the process.
        input_data: Optional string to pass to the process's stdin.
        successful_return_codes: List of return codes to treat as success.
        retries: Number of times to retry the command if it fails (default: 30).
        retry_delay: Delay in seconds between retries (default: 1).

    Returns:
        The stdout output of the command as a string.

    Raises:
        CommandError: If the command fails after the given number of retries.
    """

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_command() -> str:
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

    # Run the decorated function
    return await _inner_run_command()
