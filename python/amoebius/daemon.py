import asyncio
import sys
from typing import Optional
from .utils.terraform import init_terraform, apply_terraform
from .utils.async_command_runner import run_command, CommandError


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
            "dockerd",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
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


async def install_linkerd() -> None:
    """
    Installs Linkerd by:
      1. Retrieving the CRD YAML from 'linkerd install --crds'
      2. Applying it with 'kubectl apply -f -'
      3. Retrieving the control plane YAML from 'linkerd install'
      4. Applying it with 'kubectl apply -f -'

    This ensures Linkerd is fully installed before proceeding with other setup.
    """
    print("Installing Linkerd CRDs...")
    crds_yaml = await run_command(["linkerd", "install", "--crds"], sensitive=False)
    await run_command(["kubectl", "apply", "-f", "-"], input_data=crds_yaml, sensitive=False)
    print("Linkerd CRDs installed successfully.")

    print("Installing Linkerd control plane...")
    control_plane_yaml = await run_command(["linkerd", "install"], sensitive=False)
    await run_command(["kubectl", "apply", "-f", "-"], input_data=control_plane_yaml, sensitive=False)
    print("Linkerd control plane installed successfully.")


async def run_amoebius() -> None:
    """
    Runs Terraform initialization and apply steps for the 'vault' configuration.
    """
    await init_terraform(root_name="vault")
    await apply_terraform(root_name="vault")


async def main() -> None:
    """
    Main entry point for the script.
    Ensures Linkerd is installed, ensures Docker is running, then
    periodically runs the 'amoebius' (Terraform) workflow in a loop.
    """
    print("Script started")

    # Install Linkerd before starting Docker or running the main loop.
    await install_linkerd()

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
