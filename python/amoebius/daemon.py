import asyncio
import sys
import json
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


async def configmap_exists(name: str, namespace: str) -> bool:
    """
    Returns True if a ConfigMap with the given name exists in the given namespace.
    """
    try:
        await run_command(["kubectl", "get", "configmap", name, "-n", namespace])
        return True
    except CommandError:
        return False


async def linkerd_check_ok() -> bool:
    """
    Returns True if 'linkerd check' passes, meaning Linkerd is healthy.
    """
    try:
        await run_command(["linkerd", "check"])
        return True
    except CommandError:
        return False


async def linkerd_sidecar_attached(namespace: str, pod_name: str) -> bool:
    """
    Returns True if the named pod has a 'linkerd-proxy' container.
    """
    try:
        output = await run_command(
            ["kubectl", "get", "pod", pod_name, "-n", namespace, "-o", "json"]
        )
        pod_data = json.loads(output)
        containers = pod_data["spec"].get("containers", [])
        return any(c.get("name") == "linkerd-proxy" for c in containers)
    except CommandError:
        # If the pod doesn't exist or can't be fetched, treat it as missing the sidecar
        return False


async def uninstall_linkerd() -> None:
    """
    Calls 'linkerd uninstall | kubectl delete -f -' to remove all Linkerd resources.
    """
    print("Uninstalling Linkerd (linkerd uninstall)...")
    try:
        uninstall_yaml = await run_command(["linkerd", "uninstall"])
        await run_command(["kubectl", "delete", "-f", "-"], input_data=uninstall_yaml)
        print("Linkerd uninstalled successfully.")
    except CommandError as e:
        print(
            f"Warning: linkerd uninstall failed: {e}. Proceeding anyway (some resources may remain)."
        )


async def install_linkerd() -> None:
    """
    Installs (or re-installs) Linkerd in an idempotent way, without using 'linkerd upgrade':
      1) If 'ConfigMap/linkerd-config' doesn't exist, do a fresh install.
      2) If it does exist, run 'linkerd check':
         - If it passes, assume Linkerd is fully installed; do nothing.
         - If it fails, 'linkerd uninstall' then re-install.
      3) Wait for resources to be ready.
      4) Delete 'amoebius-0' only if sidecar is missing.
      5) Wait forever.
    """

    # 1) Detect partial or full installs by checking for the config map
    cm_exists = await configmap_exists("linkerd-config", "linkerd")
    if not cm_exists:
        print(
            "No 'linkerd-config' found. Assuming Linkerd is not installed. Doing a fresh install..."
        )
        try:
            # Step 1a: Install CRDs
            crds_yaml = await run_command(["linkerd", "install", "--crds"])
            await run_command(["kubectl", "apply", "-f", "-"], input_data=crds_yaml)
            print("Linkerd CRDs installed successfully.")

            # Step 1b: Install the control plane
            control_plane_yaml = await run_command(["linkerd", "install"])
            await run_command(
                ["kubectl", "apply", "-f", "-"], input_data=control_plane_yaml
            )
            print("Linkerd control plane installed successfully.")

        except CommandError as e:
            print(
                "Error during 'linkerd install --crds' or 'linkerd install':\n"
                f"{e}\n"
                "This might indicate a partial install was left behind. "
                "You'll need to investigate or uninstall manually."
            )
            raise
    else:
        # The config map is present => Linkerd is fully or partially installed.
        print("'linkerd-config' found. Checking Linkerd health with 'linkerd check'...")
        if await linkerd_check_ok():
            print(
                "Linkerd appears healthy (linkerd check passed). Skipping re-install."
            )
        else:
            print(
                "Linkerd check failed. We'll uninstall Linkerd, then do a fresh install."
            )
            await uninstall_linkerd()

            print("Re-installing Linkerd...")
            try:
                crds_yaml = await run_command(["linkerd", "install", "--crds"])
                await run_command(["kubectl", "apply", "-f", "-"], input_data=crds_yaml)

                control_plane_yaml = await run_command(["linkerd", "install"])
                await run_command(
                    ["kubectl", "apply", "-f", "-"], input_data=control_plane_yaml
                )
                print("Linkerd control plane re-installed successfully.")
            except CommandError as e:
                print(f"Error during re-install: {e}")
                raise

    # 2) Wait for Linkerd control plane resources
    print("Waiting for Linkerd deployments to become Available/Ready...")
    await run_command(
        [
            "kubectl",
            "wait",
            "-n",
            "linkerd",
            "--for=condition=Available",
            "deployment/linkerd-proxy-injector",
            "--timeout=300s",
        ]
    )
    await run_command(
        [
            "kubectl",
            "wait",
            "-n",
            "linkerd",
            "--for=condition=Ready",
            "pod",
            "--all",
            "--timeout=300s",
        ]
    )
    print("Linkerd is ready.")

    # 3) Delete 'amoebius-0' if sidecar is missing
    print("Checking if 'amoebius-0' has a 'linkerd-proxy' container...")
    if not await linkerd_sidecar_attached("amoebius", "amoebius-0"):
        print(
            "Sidecar missing. Deleting 'amoebius-0' so it can restart with injection..."
        )
        try:
            await run_command(
                ["kubectl", "delete", "pod", "amoebius-0", "-n", "amoebius"]
            )
            print("'amoebius-0' deleted; a new pod should appear with the sidecar.")

            print("Linkerd install/validation complete. Waiting forever...")
            while True:
                await asyncio.sleep(3600)
            
        except CommandError as e:
            print(f"Failed to delete 'amoebius-0': {e}. Proceeding anyway.")
    else:
        print("Sidecar is already attached. No need to delete 'amoebius-0'.")

    # 4) Wait forever


async def run_amoebius() -> None:
    """
    Runs Terraform initialization and apply steps for the 'vault' configuration.
    """
    # await init_terraform(root_name="vault")
    # await apply_terraform(root_name="vault")


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
