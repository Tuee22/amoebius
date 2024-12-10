import asyncio
from typing import List, Optional, Dict

class CommandError(Exception):
    """Custom exception for command execution errors."""

    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        super().__init__(message)
        self.return_code = return_code


async def run_command(
    command: List[str],
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    cwd: Optional[str] = None,
    input_data: Optional[str] = None
) -> str:
    """
    Run a shell command asynchronously and return its output.

    Args:
        command: List of command arguments.
        sensitive: If True, hides command details in error messages.
        env: Optional dictionary of environment variables to set for the command.
        cwd: Optional working directory where the command should be executed.
        input_data: Optional string to send to the process's stdin.

    Returns:
        The stdout output of the command as a string.

    Raises:
        CommandError: If the command execution fails.
    """
    process = await asyncio.create_subprocess_exec(
        *command,
        stdin=asyncio.subprocess.PIPE if input_data else None,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=env,
        cwd=cwd,
    )
    stdout_bytes, stderr_bytes = await process.communicate(
        input=input_data.encode() if input_data else None
    )
    if process.returncode != 0:
        error_message = (
            f"Command failed with return code {process.returncode}" +
            (
                f"\nCommand: {' '.join(command)}\nStdout: {stdout_bytes.decode()}\nStderr: {stderr_bytes.decode()}"
                if not sensitive else ""
            )
        )
        raise CommandError(error_message, process.returncode)
    return stdout_bytes.decode().strip()