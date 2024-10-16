import asyncio
import os
from typing import List, Optional, Dict

class CommandError(Exception):
    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        super().__init__(message)
        self.return_code = return_code

async def run_command(
    command: List[str],
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None
) -> str:
    """Run a shell command asynchronously and return its output."""
    if isinstance(command, str):
        raise ValueError("Command should be a list of arguments, not a string")
    
    complete_env = (
        {**os.environ, **env} if env else None
    )
    
    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=complete_env,
    )
    stdout_bytes, stderr_bytes = await process.communicate()
    
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
