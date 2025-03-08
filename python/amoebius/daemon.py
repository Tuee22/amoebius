"""
amoebius/daemon.py

A daemon that:
1) Deploys Linkerd + Vault each iteration (attempting re-deploy if it fails).
2) Checks Terraform state for "vault_addr".
3) If vault_addr is present, creates a Vault client, checks if sealed.
4) If unsealed, calls run_amoebius with that client.
5) Sleeps 5s and repeats.

No local variable mutation is used for flags.
No is_vault_unsealed wrapper – we call vclient.is_vault_sealed() directly.
"""

import asyncio
import sys
from typing import Optional

from amoebius.utils.docker import is_docker_running, start_dockerd
from amoebius.utils.linkerd import install_linkerd
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    read_terraform_state,
    get_output_from_state,
)

# Import the client from vault_client, but import VaultSettings from models.vault
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.vault import VaultSettings  # <--- from amoebius.models.vault
from amoebius.services.minio import minio_deploy
from amoebius.models.minio import (
    MinioDeployment,
    MinioServiceAccountAccess,
    MinioPolicySpec,
    MinioBucketPermission,
)
from amoebius.models.k8s import KubernetesServiceAccount


async def deploy_infra() -> None:
    """Deploy Linkerd + Vault (via Terraform).

    Raises:
        Exception: If deployment fails, which will be caught by the caller.
    """
    print("Deploying Linkerd...")
    await install_linkerd()

    print("Deploying Vault via Terraform...")
    await init_terraform(root_name="vault")
    await apply_terraform(root_name="vault")

    print("Infrastructure deploy attempt finished (Linkerd + Vault).")


async def get_vault_addr_from_tf() -> Optional[str]:
    """Reads the 'vault_addr' from Terraform state, returning None if not available.

    Returns:
        Optional[str]: The Vault address if found, else None.
    """
    try:
        tfs = await read_terraform_state(root_name="vault")
        vault_addr = get_output_from_state(tfs, "vault_addr", str)
        return vault_addr
    except Exception as ex:
        print(f"Cannot retrieve vault_addr from TF state: {ex}")
        return None


async def run_amoebius(vclient: AsyncVaultClient) -> None:
    """Runs the main MinIO deployment logic with a guaranteed Vault client.

    Args:
        vclient (AsyncVaultClient): The Vault client, guaranteed to be unsealed.
    """
    # Provide read/write perms on the 'amoebius' bucket for a SA named 'amoebius'
    # in the 'amoebius-admin' namespace
    service_account_access = MinioServiceAccountAccess(
        service_account=KubernetesServiceAccount(
            namespace="amoebius",
            name="amoebius-admin",
        ),
        bucket_permissions=[
            MinioPolicySpec(
                bucket_name="amoebius",
                permission=MinioBucketPermission.READWRITE,
            )
        ],
    )
    deployment = MinioDeployment(
        minio_root_bucket="amoebius",
        service_accounts=[service_account_access],
    )
    await minio_deploy(deployment, vclient)
    print(
        "MinIO deployment or update complete (amoebius user in amoebius-admin namespace)."
    )


async def daemon_loop() -> None:
    """The main daemon loop, running indefinitely.

    Each iteration:
      1) Attempt to deploy Linkerd+Vault (infra).
      2) Check TF for vault_addr.
      3) If found => create vault client => check sealed => if unsealed => run_amoebius
      4) Sleep 5s and repeat.
    """
    while True:
        print(
            "Daemon iteration: deploying infra, checking vault, maybe running MinIO..."
        )

        # 1) Deploy infra
        try:
            await deploy_infra()
        except Exception as ex:
            print(f"Infrastructure deployment failed this iteration: {ex}")

        # 2) Read vault_addr from TF
        vault_addr = await get_vault_addr_from_tf()
        if not vault_addr:
            print("Vault address not found in TF, skipping this iteration.")
        else:
            # Create the Vault client
            vault_settings = VaultSettings(
                vault_addr=vault_addr,
                vault_role_name="amoebius-admin-role",
                verify_ssl=False,
            )
            async with AsyncVaultClient(vault_settings) as vclient:
                # 3) Check if Vault is sealed
                sealed = True
                try:
                    sealed = await vclient.is_vault_sealed()
                except Exception as check_ex:
                    print(f"Error checking vault seal status: {check_ex}")

                if sealed:
                    print("Vault is sealed or error => skipping MinIO deployment.")
                else:
                    # 4) If unsealed => run amoebius
                    try:
                        await run_amoebius(vclient)
                    except Exception as run_ex:
                        print(f"Error in run_amoebius: {run_ex}")

        print("Daemon iteration done. Sleeping 5 seconds.")
        await asyncio.sleep(5)


async def main() -> None:
    """Ensures Docker is running, then enters the daemon loop."""
    print("Daemon starting...")
    docker_process: Optional[asyncio.subprocess.Process] = None

    if not await is_docker_running():
        print("Docker is not running. Starting dockerd...")
        docker_process = await start_dockerd()
        if docker_process is None:
            print("Failed to start Docker daemon, exiting.", file=sys.stderr)
            return
        print("dockerd started.")
    else:
        print("Docker daemon already running.")

    try:
        await daemon_loop()
    except asyncio.CancelledError:
        print("Daemon shutting down (cancelled).")
    finally:
        if docker_process:
            print("Terminating dockerd...")
            docker_process.terminate()
            await docker_process.wait()
            print("dockerd stopped.")


if __name__ == "__main__":
    asyncio.run(main())
