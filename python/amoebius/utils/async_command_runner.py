"""
amoebius/utils/async_command_runner.py

Provides a reusable asynchronous command runner with retry logic. Optionally,
allows passing a custom error_parser callback that can parse stderr for known
errors (e.g., Docker Hub rate limits) and return a short user-friendly message.

We also keep an optional argument for `successful_return_codes`, which indicates
which return codes won't be treated as errors (defaults to [0]).

Usage example:
    from amoebius.utils.async_command_runner import run_command, CommandError

    def dockerhub_parser(stderr_str: str) -> Optional[str]:
        lower = stderr_str.lower()
        if "429 too many requests" in lower or "toomanyrequests" in lower:
            return "Docker Hub rate limit encountered. Consider authenticating or upgrading."
        return None

    try:
        output = await run_command(
            ["helm", "install", "..."],
            retries=3,
            error_parser=dockerhub_parser,
        )
        print(output)
    except CommandError as err:
        print(f"Command failed: {err}")
"""

from __future__ import annotations

import os
import asyncio
from typing import Callable, Dict, List, Optional
from typing_extensions import ParamSpec, TypeVar

from amoebius.utils.async_retry import async_retry

P = ParamSpec("P")
R = TypeVar("R")


class CommandError(Exception):
    """Represents a failure when executing a shell command.

    Attributes:
        message (str): The error message describing the command failure.
        return_code (Optional[int]): The exit code if available.
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
    error_parser: Optional[Callable[[str], Optional[str]]] = None,
) -> str:
    """
    Executes a local command in a subprocess, asynchronously, with optional retries
    and an optional error parser callback.

    If the command fails (return code not in successful_return_codes), we raise
    CommandError. If `error_parser` is given, we pass stderr to it, and if it returns
    a non-None string, we raise that as a short user-friendly message. Otherwise, we
    raise the usual "Command failed" message.

    When `sensitive=True`, we omit the command, stdout, and stderr from the final error
    message.

    Args:
        command (List[str]):
            The command and arguments to execute.
        sensitive (bool):
            If True, hides command details in the raised error.
        env (Optional[Dict[str, str]]):
            Additional environment variables to add or override.
        cwd (Optional[str]):
            Working directory for the command.
        input_data (Optional[str]):
            If provided, passed to stdin.
        successful_return_codes (List[int]):
            Which return codes won't be treated as errors. Defaults to [0].
        retries (int):
            How many times to retry on failure. Defaults to 3.
        retry_delay (float):
            Delay in seconds between retries. Defaults to 1.0.
        suppress_env_vars (Optional[List[str]]):
            A list of environment variables to remove from the environment.
        error_parser (Optional[Callable[[str], Optional[str]]]):
            A callback that receives stderr (as a string). If it returns a non-None
            value, we raise a short CommandError with that message. This can detect
            known errors like Docker Hub rate limits.

    Returns:
        str: The captured stdout of the command on success.

    Raises:
        CommandError: If the command fails after all retries or returns a code not in
            `successful_return_codes`. Also if `error_parser` returns a message.
    """

    @async_retry(retries=retries, delay=retry_delay)
    async def _inner_run_command() -> str:
        # Build environment
        if env is None and not suppress_env_vars:
            proc_env = None
        else:
            proc_env = os.environ.copy()
            if suppress_env_vars:
                for var in suppress_env_vars:
                    proc_env.pop(var, None)
            if env:
                proc_env.update(env)

        # Decide how we pass stdin
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

        # Check return code
        if proc.returncode not in successful_return_codes:
            # If user provided an error_parser, see if it returns a custom message
            short_message = None
            if error_parser:
                short_message = error_parser(stderr_str)

            if short_message is not None:
                # Raise short, custom message from the error parser
                raise CommandError(short_message, proc.returncode)

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


async def run_command_interactive(command: List[str]) -> int:
    """
    Launches the given command in an interactive manner, attaching local stdin/out.
    Returns the exit code on completion.

    This function does not do ephemeral approach or TTY bridging automatically.
    It's a minimal approach: we spawn a child process that inherits local FDs
    so the user can interact directly. The user must be on a real TTY for it to work well.

    Args:
        command: The command and arguments to run in interactive mode.

    Returns:
        The exit code of the child process.
    """
    proc = await asyncio.create_subprocess_exec(
        *command, stdin=None, stdout=None, stderr=None
    )
    return_code = await proc.wait()
    return return_code
