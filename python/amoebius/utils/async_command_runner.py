import asyncio
import logging
from typing import List

class CommandError(Exception):
    """Custom exception for command execution errors."""
    def __init__(self, message: str, returncode: int):
        super().__init__(message)
        self.returncode = returncode

async def run_command(command: List[str], sensitive: bool = False) -> str:
    """
    Run a command asynchronously using asyncio and return the command output as a string.

    Args:
        command (List[str]): A list of command parts, where the first element is the command
                             and subsequent elements are the arguments.
        sensitive (bool): If True, treat the command and its output as sensitive.
    
    Returns:
        str: The output (stdout) from the command execution.
    
    Raises:
        CommandError: If the command fails (non-zero return code).
        ValueError: If the command list is empty.
    """
    if not command:
        raise ValueError("Command list cannot be empty")

    try:
        # Create a subprocess to run the command asynchronously
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        # Capture stdout and stderr
        stdout, stderr = await process.communicate()

        # Decode the stdout and stderr from bytes to string
        stdout_str = stdout.decode().strip()
        stderr_str = stderr.decode().strip()

        # If the command failed (non-zero return code), raise an error
        if process.returncode != 0:
            if sensitive:
                logging.error("Sensitive command failed")
                raise CommandError("Sensitive command failed", process.returncode)
            else:
                logging.error(f"Command failed: {' '.join(command)}")
                logging.debug(f"Command stderr: {stderr_str}")
                raise CommandError(f"Command failed with return code {process.returncode}", process.returncode)

        return stdout_str
    
    except asyncio.SubprocessError as e:
        if sensitive:
            logging.error("Subprocess error occurred during sensitive command execution")
            raise CommandError("Subprocess error during sensitive command execution", -1)
        else:
            logging.error(f"Subprocess error while running command: {' '.join(command)}")
            raise CommandError(f"Subprocess error: {str(e)}", -1)
    except Exception as e:
        if sensitive:
            logging.error("Unexpected error occurred during sensitive command execution")
            raise CommandError("Unexpected error during sensitive command execution", -1)
        else:
            logging.error(f"Unexpected error while running command: {' '.join(command)}")
            raise CommandError(f"Unexpected error: {str(e)}", -1)