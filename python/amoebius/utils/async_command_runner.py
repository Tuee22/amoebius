# async_command_runner.py

import os
import asyncio
from typing import Dict, List, Optional
from typing_extensions import ParamSpec, TypeVar
from typing import Awaitable, Callable

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
) -> str:
    """
    Executes a local command in a subprocess, asynchronously.
    We'll do manual retry by calling an inner function decorated by @async_retry.
    """

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_command() -> str:
        if env:
            proc_env = os.environ.copy()
            proc_env.update(env)

        proc = await asyncio.create_subprocess_exec(
            *command,
            stdin=asyncio.subprocess.PIPE if input_data else None,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=proc_env if env else None,
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
