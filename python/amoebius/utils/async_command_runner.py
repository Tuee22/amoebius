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
    input_data: Optional[str] = None,
    retries: int = 3,
    retry_delay: int = 1
) -> str:
    """
    Run a shell command asynchronously and return its output.

    Args:
        command: List of command arguments.
        sensitive: If True, hides command details in error messages.
        env: Optional dictionary of environment variables to set for the command.
        cwd: Optional working directory where the command should be executed.
        input_data: Optional string to send to the process's stdin.
        retries: Number of retry attempts if the command fails.
        retry_delay: Delay in seconds before retrying the command.

    Returns:
        The stdout output of the command as a string.

    Raises:
        CommandError: If the command execution fails after retries.
    """
    try:
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
            raise CommandError(
                f"Command failed with return code {process.returncode}" +
                (
                    f"\nCommand: {' '.join(command)}\nStdout: {stdout_bytes.decode()}\nStderr: {stderr_bytes.decode()}"
                    if not sensitive else ""
                ),
                process.returncode
            )
        return stdout_bytes.decode().strip()
    except CommandError as e:
        if retries > 0:
            await asyncio.sleep(retry_delay)  # Wait before retrying
            return await run_command(command, sensitive, env, cwd, input_data, retries - 1, retry_delay)
        else:
            raise e