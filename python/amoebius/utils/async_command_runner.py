import asyncio
import os
from typing import List, Optional, Dict

class CommandError(Exception):
    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        super().__init__(message)
        self.return_code: Optional[int] = return_code

async def run_command(
    command: List[str],
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None
) -> str:
    if isinstance(command, str):
        raise ValueError("Command should be a list of arguments, not a string")
    
    # Create a copy of the current environment and override if any overrides were passed
    if env is not None:
        complete_env = os.environ.copy()
        complete_env.update(env)
    else:
        complete_env = None

    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=complete_env,
    )

    stdout_bytes, stderr_bytes = await process.communicate()

    if process.returncode != 0:
        error_message = f"Command failed with return code {process.returncode}"
        if not sensitive:
            error_message += (
                f"\nCommand: {' '.join(command)}"
                f"\nStdout: {stdout_bytes.decode()}"
                f"\nStderr: {stderr_bytes.decode()}"
            )
        raise CommandError(error_message, process.returncode)

    return stdout_bytes.decode().strip()
