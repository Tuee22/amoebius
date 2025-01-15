# from __future__ import annotations

import asyncio
import json
from typing import Any

from .async_command_runner import run_command, CommandError
from .terraform import init_terraform, apply_terraform


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
        # Use dict[str, Any] to accommodate arbitrary JSON structure
        pod_data: dict[str, Any] = json.loads(output)
        spec = pod_data.get("spec", {})
        containers = spec.get("containers", [])
        return any(container.get("name") == "linkerd-proxy" for container in containers)
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
            f"Warning: linkerd uninstall failed: {e}. "
            "Proceeding anyway (some resources may remain)."
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
      5) Wait forever (but only if we actually delete the pod).
    """

    # 1) Detect partial or full installs by checking for the config map
    cm_exists: bool = await configmap_exists("linkerd-config", "linkerd")
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
        healthy: bool = await linkerd_check_ok()
        if healthy:
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

    print("Linkerd is ready. Adding annotation to amoebius")
    await init_terraform("annotate_amoebius_linkerd")
    await apply_terraform("annotate_amoebius_linkerd")

    # 3) Delete 'amoebius-0' if sidecar is missing
    print("Checking if 'amoebius-0' has a 'linkerd-proxy' container...")
    sidecar_present: bool = await linkerd_sidecar_attached("amoebius", "amoebius-0")
    if not sidecar_present:
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


if __name__ == "__main__":
    """
    Entry point for script usage. Runs install_linkerd() to ensure
    Linkerd is installed in an idempotent manner.
    """
    asyncio.run(install_linkerd())
