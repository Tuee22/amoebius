from .async_command_runner import run_command, CommandError
from typing import Optional
import asyncio
import sys


async def is_docker_running() -> bool:
    """
    Checks whether the Docker daemon is running by invoking 'docker info'.
    Returns True if Docker is running, False otherwise.
    """
    try:
        # Uses run_command() for idempotent check. If Docker isn't running,
        # CommandError is raised, and we return False.
        await run_command(["docker", "info"], sensitive=True, retries=1)
        return True
    except CommandError:
        return False
    except Exception:
        return False


async def wait_for_docker_ready(attempts_remaining: int) -> bool:
    """
    Recursively waits for the Docker daemon to become ready.
    Returns True if Docker is detected within the given attempts,
    otherwise returns False.
    """
    if attempts_remaining <= 0:
        return False

    if await is_docker_running():
        return True

    # Sleep briefly and then recurse
    await asyncio.sleep(1)
    return await wait_for_docker_ready(attempts_remaining - 1)


async def start_dockerd() -> Optional[asyncio.subprocess.Process]:
    """
    Starts the Docker daemon in the background by calling dockerd directly.
    Returns the Process handle if successful, or None if it fails to start.
    """
    try:
        # Create a subprocess for dockerd, capturing its stdout and stderr.
        process = await asyncio.create_subprocess_exec(
            "dockerd", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
        )

        # Recursively wait for Docker to become ready (30 attempts).
        success = await wait_for_docker_ready(30)
        if success:
            return process

        print("Failed to start Docker daemon", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error starting Docker daemon: {e}", file=sys.stderr)
        return None
