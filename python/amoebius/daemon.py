import asyncio
import sys
from typing import Optional

async def is_docker_running() -> bool:
    try:
        process = await asyncio.create_subprocess_exec(
            'docker', 'info',
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL
        )
        await process.communicate()
        return process.returncode == 0
    except Exception:
        return False

async def start_dockerd() -> Optional[asyncio.subprocess.Process]:
    try:
        process = await asyncio.create_subprocess_exec(
            'dockerd',
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        # Wait for Docker to start (adjust timeout as needed)
        for _ in range(30):  # 30 second timeout
            if await is_docker_running():
                return process
            await asyncio.sleep(1)
        print("Failed to start Docker daemon", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error starting Docker daemon: {e}", file=sys.stderr)
        return None

async def main() -> None:
    print("Script started")
    docker_process: Optional[asyncio.subprocess.Process] = None

    # Ensure Docker is running before starting the main loop
    if not await is_docker_running():
        print("Docker daemon not running. Starting dockerd...")
        docker_process = await start_dockerd()
        if docker_process is None:
            print("Failed to start Docker daemon. Exiting.", file=sys.stderr)
            return
        print("dockerd started")
    else:
        print("Docker daemon is already running")

    try:
        # Main loop
        while True:
            print("Daemon is running...")
            await asyncio.sleep(5)  # Sleep for 5 seconds
    except asyncio.CancelledError:
        print("Daemon is shutting down...")
    finally:
        if docker_process is not None:
            print("Stopping dockerd...")
            docker_process.terminate()
            await docker_process.wait()
            print("dockerd stopped")

if __name__ == "__main__":
    asyncio.run(main())