"""
amoebius/utils/linkerd.py

Provides helper functions for installing/uninstalling Linkerd in a Kubernetes cluster,
verifying its health, and ensuring that a sidecar is present on certain pods. Also
runs minimal Terraform steps to annotate the 'amoebius' deployment for injection.

Updated to handle Gateway API CRDs explicitly before installing Linkerd.
"""

from __future__ import annotations

import asyncio
import json
from typing import Any

from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.utils.terraform.commands import init_terraform, apply_terraform
from amoebius.models.terraform import TerraformBackendRef


# Official Gateway API CRD manifest for reference; choose the version that Linkerd expects
# (This URL may change; keep it updated with the recommended Gateway API CRD release.)
GATEWAY_API_CRD_URL = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"


async def configmap_exists(name: str, namespace: str) -> bool:
    """Check whether a ConfigMap exists.

    Args:
        name (str): The name of the ConfigMap.
        namespace (str): The namespace in which to look.

    Returns:
        bool: True if the ConfigMap exists, otherwise False.
    """
    try:
        await run_command(["kubectl", "get", "configmap", name, "-n", namespace])
        return True
    except CommandError:
        return False


async def linkerd_check_ok() -> bool:
    """Wait for Linkerd to become healthy and run 'linkerd check'.

    Returns:
        bool: True if Linkerd is confirmed healthy, otherwise False.
    """
    try:
        # Wait for the control plane deployments to become Available/Ready
        await run_command(
            [
                "kubectl",
                "wait",
                "-n",
                "linkerd",
                "--for=condition=Available",
                "deployment/linkerd-proxy-injector",
                "--timeout=300s",
            ],
            sensitive=False,
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
            ],
            sensitive=False,
        )

        # Check overall Linkerd health
        await run_command(["linkerd", "check"], sensitive=False)
        return True
    except CommandError:
        return False


async def linkerd_sidecar_attached(namespace: str, pod_name: str) -> bool:
    """Check whether a specific pod has the 'linkerd-proxy' sidecar.

    Args:
        namespace (str): The namespace of the pod.
        pod_name (str): The name of the pod.

    Returns:
        bool: True if the pod has a 'linkerd-proxy' container, otherwise False.
    """
    try:
        output = await run_command(
            ["kubectl", "get", "pod", pod_name, "-n", namespace, "-o", "json"]
        )
        pod_data: dict[str, Any] = json.loads(output)
        spec = pod_data.get("spec", {})
        containers = spec.get("containers", [])
        return any(container.get("name") == "linkerd-proxy" for container in containers)
    except CommandError:
        return False


async def uninstall_linkerd() -> None:
    """Uninstall Linkerd by running 'linkerd uninstall' then 'kubectl delete -f -'."""
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


async def install_gateway_api_crds() -> None:
    """Install Gateway API CRDs, if they are not already present."""
    print("Applying Gateway API CRDs from official source...")
    try:
        await run_command(["kubectl", "apply", "-f", GATEWAY_API_CRD_URL])
        print("Gateway API CRDs applied successfully.")
    except CommandError as e:
        print(f"Error applying Gateway API CRDs: {e}")
        raise


async def install_linkerd() -> None:
    """Install or re-install Linkerd in an idempotent manner, verifying readiness.

    Steps:
      1) Install Gateway API CRDs (if not present) or skip if Linkerd manages them entirely.
      2) Check if 'linkerd-config' exists. If not, do a fresh install.
      3) If it does exist, run 'linkerd check'. If fail => uninstall + reinstall.
      4) Wait for readiness via linkerd_check_ok().
      5) Annotate 'amoebius' with linkerd injection if needed.
      6) Possibly remove the 'amoebius-0' pod to force injection if sidecar is absent.
    """

    # 1) Make sure Gateway API CRDs are installed. If you'd rather have Linkerd manage them,
    #    remove or comment out this function call.
    await install_gateway_api_crds()

    # 2) Check if 'linkerd-config' exists
    cm_exists = await configmap_exists("linkerd-config", "linkerd")
    if not cm_exists:
        print("No 'linkerd-config' found. Doing a fresh Linkerd install...")
        try:
            crds_yaml = await run_command(["linkerd", "install", "--crds"])
            await run_command(["kubectl", "apply", "-f", "-"], input_data=crds_yaml)
            print("Linkerd CRDs installed successfully.")

            control_plane_yaml = await run_command(["linkerd", "install"])
            await run_command(
                ["kubectl", "apply", "-f", "-"], input_data=control_plane_yaml
            )
            print("Linkerd control plane installed successfully.")
        except CommandError as e:
            print(
                "Error during 'linkerd install --crds' or 'linkerd install':\n"
                f"{e}\n"
                "A partial install may exist. Investigate or uninstall manually."
            )
            raise
    else:
        print("'linkerd-config' found. Checking Linkerd health with 'linkerd check'...")
        healthy = await linkerd_check_ok()
        if not healthy:
            print("Linkerd check failed. We'll uninstall then reinstall.")
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
        else:
            print("Linkerd is healthy, skipping re-install.")

    # 4) Wait for readiness
    print("Waiting for Linkerd to become ready...")
    is_ok = await linkerd_check_ok()
    assert is_ok, "Error: Linkerd health check failed"
    print("Linkerd is ready and healthy.")

    # 5) Annotate 'amoebius' for auto-injection
    print("Adding linkerd annotation to amoebius...")
    ref = TerraformBackendRef(root="utils/annotate_amoebius_linkerd")
    await init_terraform(ref=ref)
    await apply_terraform(ref=ref)

    # 6) Check if the sidecar is attached; if not, delete the pod to force injection
    print("Checking if 'amoebius-0' has a 'linkerd-proxy' container...")
    sidecar_present = await linkerd_sidecar_attached("amoebius", "amoebius-0")
    if not sidecar_present:
        print("Sidecar missing. Deleting 'amoebius-0' to force injection restart.")
        try:
            await run_command(
                ["kubectl", "delete", "pod", "amoebius-0", "-n", "amoebius"]
            )
            print("'amoebius-0' deleted; new pod will appear with the sidecar.")
            print("Waiting forever to keep container alive...")
            while True:
                await asyncio.sleep(3600)
        except CommandError as e:
            print(f"Failed to delete 'amoebius-0': {e}. Proceeding anyway.")
    else:
        print("Sidecar is already attached. No action needed.")
