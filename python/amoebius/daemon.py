import asyncio
import sys
import json
from typing import Optional
from amoebius.utils.terraform import init_terraform, apply_terraform
from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.utils.linkerd import install_linkerd
from amoebius.utils.docker import is_docker_running, start_dockerd


async def run_amoebius() -> None:
    """
    Runs Terraform initialization and apply steps for the 'vault' configuration.
    """
    await install_linkerd()

    #await init_terraform(root_name="vault")
    #await apply_terraform(root_name="vault")


async def main() -> None:
    """
    Main entry point for the script.
    Ensures Linkerd is installed, ensures Docker is running, then
    periodically runs the 'amoebius' (Terraform) workflow in a loop.
    """
    print("Script started")

    docker_process: Optional[asyncio.subprocess.Process] = None

    # Ensure Docker is running before starting the main loop
    if not await is_docker_running():
        print("Docker daemon not running. Starting dockerd...")
        docker_process = await start_dockerd()
        if docker_process is None:
            print("Failed to start Docker daemon. Exiting.", file=sys.stderr)
            return
        print("dockerd started successfully.")
    else:
        print("Docker daemon is already running.")

    try:
        # Main daemon loop
        while True:
            print("Daemon is running...")
            await run_amoebius()
            await asyncio.sleep(5)
    except asyncio.CancelledError:
        print("Daemon is shutting down...")
    finally:
        # If dockerd was started here, terminate it to clean up
        if docker_process is not None:
            print("Stopping dockerd...")
            docker_process.terminate()
            await docker_process.wait()
            print("dockerd stopped.")


if __name__ == "__main__":
    asyncio.run(main())
