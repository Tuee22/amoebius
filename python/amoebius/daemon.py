"""
amoebius/daemon.py

A daemon that:
  1) Ensures Docker is running or fails => K8s restarts container.
  2) Deploys Linkerd + Vault once, or fails => K8s restarts container.
  3) Reads TF state for 'vault_addr' once, or fails => K8s restarts container.
  4) Creates a single AsyncVaultClient outside the loop.
  5) Each loop iteration:
       - Redeploy Linkerd+Vault (idempotent).
       - Checks if vault is sealed => if sealed, skip.
       - Checks if vault is configured => if not, skip.
       - Otherwise, run minio_deploy(...) => Sleep => repeat.
"""

from __future__ import annotations

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
from amoebius.models.terraform import TerraformBackendRef
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
    """Deploy Linkerd + Vault in an idempotent way, or raise on failure."""
    print("Deploying Linkerd...")
    await install_linkerd()

    print("Deploying Vault via Terraform...")
    ref_vault = TerraformBackendRef(root="services/vault")
    await init_terraform(ref=ref_vault)
    await apply_terraform(ref=ref_vault)

    print("Deployment (Linkerd + Vault) completed.")


async def run_amoebius(vclient: AsyncVaultClient) -> None:
    """Run MinIO deployment logic with a guaranteed Vault client.

    Args:
        vclient (AsyncVaultClient): Pre-initialized Vault client.
    """
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
    """Main daemon logic.

    1) Ensure Docker is running or fail => K8s restarts.
    2) Deploy Linkerd + Vault once or fail => K8s restarts.
    3) Read TF for vault_addr => if missing => fail => K8s restarts.
    4) Create one VaultClient.
    5) In a loop => re-deploy infra, check vault sealed/config => run minio => sleep => repeat.
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

    # 2) Deploy Linkerd + Vault
    await deploy_infra()

    # 3) Read Terraform for vault_addr => or fail
    ref_vault = TerraformBackendRef(root="services/vault")
    tfs = await read_terraform_state(ref=ref_vault)
    vault_addr = get_output_from_state(tfs, "vault_addr", str)
    print(f"Got vault_addr from TF: {vault_addr}")

    # Build a VaultSettings
    vault_settings = VaultSettings(
        vault_addr=vault_addr,
        vault_role_name="amoebius-admin-role",
        verify_ssl=False,
    )
    async with AsyncVaultClient(vault_settings) as vclient:
        print("Vault client instantiated successfully.")

        try:
            while True:
                print("Daemon iteration: re-deploy infra, then check Vault status.")
                await deploy_infra()

                sealed = await vclient.is_vault_sealed()
                if sealed:
                    print("Vault is sealed => skipping MinIO logic.")
                else:
                    configured = await vclient.is_vault_configured()
                    if not configured:
                        print("Vault is unsealed but not yet configured => skipping.")
                    else:
                        await run_amoebius(vclient)

                print("Iteration done. Sleeping 5s...")
                await asyncio.sleep(5)

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
