"""
amoebius/daemon.py

A daemon that:
1) Ensures Docker is running or fails => K8s restarts.
2) Deploys Linkerd + Vault once, or fails => K8s restarts.
3) Reads Terraform state for 'vault_addr' once, or fails => K8s restarts.
4) Creates a single AsyncVaultClient outside the loop.
5) Each loop iteration:
   - Redeploy Linkerd+Vault (idempotent),
   - Check if vault is sealed => if sealed, skip; if unsealed, run minio,
   - Sleep 5s,
   - Repeats forever or until canceled => K8s can also restart it on crash.
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

# We import AsyncVaultClient from vault_client, but import VaultSettings from amoebius.models.vault
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.vault import VaultSettings
from amoebius.services.minio import minio_deploy
from amoebius.models.minio import (
    MinioDeployment,
    MinioServiceAccountAccess,
    MinioPolicySpec,
    MinioBucketPermission,
)
from amoebius.models.k8s import KubernetesServiceAccount


async def deploy_infra() -> None:
    """
    Deploy Linkerd + Vault (idempotent).

    If it fails, let the exception propagate => k8s restarts.
    """
    print("Deploying Linkerd...")
    await install_linkerd()

    print("Deploying Vault via Terraform...")
    await init_terraform(root_name="vault")
    await apply_terraform(root_name="vault")

    print("Deployment (Linkerd + Vault) completed.")


async def run_amoebius(vclient: AsyncVaultClient) -> None:
    """
    Runs the MinIO deployment logic with a guaranteed Vault client.

    Args:
        vclient: The already-initialized and unsealed Vault client.
    """
    # Provide read/write perms on the 'amoebius' bucket for the 'amoebius' user
    # in the 'amoebius-admin' namespace
    service_account_access = MinioServiceAccountAccess(
        service_account=KubernetesServiceAccount(
            namespace="amoebius-admin",
            name="amoebius",
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
    print("MinIO deployed/updated for 'amoebius' user in 'amoebius-admin' namespace.")


async def main() -> None:
    """
    Main daemon:
      1) Ensures docker is running or crash => k8s restarts.
      2) Deploys Linkerd + Vault once, or crash => k8s restarts.
      3) Reads TF for vault_addr => if missing => crash => k8s restarts.
      4) Creates one VaultClient outside the loop.
      5) In the loop:
         - Redeploy infra each iteration (idempotent),
         - is_vault_sealed() => if sealed => skip, else run_amoebius,
         - Sleep 5s, repeat.
    """
    print("Daemon starting...")
    docker_process: Optional[asyncio.subprocess.Process] = None

    # 1) Ensure Docker or fail
    if not await is_docker_running():
        print("Docker not running. Starting dockerd...")
        docker_process = await start_dockerd()
        if docker_process is None:
            print("Failed to start Docker => crash.")
            sys.exit(1)
        print("dockerd started.")
    else:
        print("Docker daemon already running.")

    # 2) Deploy Linkerd + Vault once or fail => k8s restarts
    await deploy_infra()

    # 3) Read Terraform state => get vault_addr => or fail => k8s restarts
    tfs = await read_terraform_state(root_name="vault")
    vault_addr = get_output_from_state(tfs, "vault_addr", str)
    print(f"Got vault_addr from TF: {vault_addr}")

    # Create a single Vault client outside the loop
    vault_settings = VaultSettings(
        vault_addr=vault_addr,
        vault_role_name="amoebius-admin-role",
        verify_ssl=False,
    )
    async with AsyncVaultClient(vault_settings) as vclient:
        print("Vault client instantiated successfully.")

        try:
            while True:
                print(
                    "Daemon iteration: redeploy infra, check sealed, run minio if unsealed."
                )
                # Redeploy infra each iteration
                await deploy_infra()

                # If is_vault_sealed fails => crash => k8s restarts
                sealed = await vclient.is_vault_sealed()
                if sealed:
                    print("Vault is sealed => skipping MinIO logic.")
                else:
                    await run_amoebius(vclient)

                print("Iteration done. Sleeping 5s...")
                await asyncio.sleep(5)

        except asyncio.CancelledError:
            print("Daemon shutting down (cancelled).")
        finally:
            # Clean up if needed
            if docker_process:
                print("Terminating dockerd...")
                docker_process.terminate()
                await docker_process.wait()
                print("dockerd stopped.")


if __name__ == "__main__":
    asyncio.run(main())
