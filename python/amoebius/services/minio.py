"""
amoebius/services/minio.py

Defines high-level, idempotent "deploy" and "destroy" functions for Minio,
tying together:
 - Terraform (init/apply/destroy)
 - Vault storage for root cred (amoebius/minio/root)
 - K8s SA listing via kubectl
 - "Root" usage to create users/policies in Minio
 - concurrency with gather(*)
"""

import asyncio
import json
import secrets
from typing import Optional

from amoebius.models.minio import (
    MinioDeployment,
    MinioSettings,
    MinioServiceAccountAccess,
)
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    VaultKVStorage,
)
from amoebius.utils.minio import MinioAdminClient  # <-- Correct import here
from amoebius.utils.async_command_runner import run_command, CommandError


async def minio_deploy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
    skip_missing_sas: bool = True,
) -> None:
    """Idempotently deploy a Minio cluster and configure buckets/policies.

    This function:
      1. Retrieves or generates a root credential from Vault (path=amoebius/minio/root).
      2. Performs a Terraform init/apply for the Minio cluster.
      3. Creates the 'root bucket' specified in the deployment.
      4. Retrieves K8s service accounts from the cluster.
      5. For each SA in the deployment config:
         - (Optionally) skips if not found in the cluster,
         - Creates a Minio user, policy, attaches policy,
         - Stores user creds in Vault at 'amoebius/minio/id/<sa_name>'.

    Args:
        deployment (MinioDeployment):
            The desired Minio deployment specification, including root bucket name,
            service account settings, etc.
        vault_client (AsyncVaultClient):
            Vault client used to read/write root credentials and user credentials.
        base_path (str, optional):
            Filesystem path to the Terraform directory. Defaults to
            "/amoebius/terraform/roots/minio".
        workspace (str, optional):
            Name of the Terraform workspace. Defaults to "default".
        skip_missing_sas (bool, optional):
            Whether to skip creating Minio accounts if the specified K8s SA
            cannot be found in the cluster. Defaults to True.

    Raises:
        RuntimeError: Propagates any errors from Vault, Terraform, or Minio operations.
    """
    # 1) Generate or retrieve "root" credentials from Vault
    root_cred_path = "amoebius/minio/root"
    try:
        stored_root_secret = await vault_client.read_secret(root_cred_path)
    except RuntimeError as ex:
        if "404" in str(ex):
            stored_root_secret = {}
        else:
            raise

    if not stored_root_secret:
        # Create random root credential
        root_access_key = "admin"
        root_secret_key = secrets.token_urlsafe(16)
        new_root_settings = {
            "url": "http://minio.minio.svc.cluster.local:9000",
            "access_key": root_access_key,
            "secret_key": root_secret_key,
            "secure": False,
        }
        await vault_client.write_secret(root_cred_path, new_root_settings)
        stored_root_secret = new_root_settings

    # Build root minio settings
    root_settings_model = MinioSettings(**stored_root_secret)

    # 2) Terraform init + apply
    storage = VaultKVStorage(root_module="minio", workspace=workspace)
    await init_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        base_path=base_path,
    )
    await apply_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        base_path=base_path,
    )

    # 3) Use MinioAdminClient to create the root bucket and configure SAs
    async with MinioAdminClient(root_settings_model) as client:
        await client.create_bucket(deployment.minio_root_bucket)

        # 4) Retrieve actual K8s SAs
        cmd_sa = ["kubectl", "get", "serviceaccounts", "-A", "-o", "json"]
        raw_sa_json = await run_command(cmd_sa, retries=0)
        parsed = json.loads(raw_sa_json)
        found_sas = set()
        for item in parsed.get("items", []):
            ns = item.get("metadata", {}).get("namespace", "")
            nm = item.get("metadata", {}).get("name", "")
            if ns and nm:
                found_sas.add(f"{ns}:{nm}")

        # 5) For each SA, create a user/policy if relevant
        async def configure_sa(sa_obj: MinioServiceAccountAccess) -> None:
            user_name = sa_obj.service_account_name
            if skip_missing_sas:
                # If not found in the cluster, skip
                # We interpret "any namespace" => must be anyNs:user_name in found_sas
                if not any(user_name == s.split(":", 1)[1] for s in found_sas):
                    return

            # Random password for user
            user_password = secrets.token_urlsafe(16)

            # Create user
            await client.create_user(user_name, user_password)
            # Create policy
            policy_name = f"policy-{user_name}"
            await client.create_policy(policy_name, sa_obj.bucket_permissions)
            # Attach policy
            await client.attach_policy_to_user(user_name, policy_name)

            # Store in vault => "amoebius/minio/id/<sa_name>"
            user_creds = MinioSettings(
                url=root_settings_model.url,
                access_key=user_name,
                secret_key=user_password,
                secure=root_settings_model.secure,
            )
            path_in_vault = f"amoebius/minio/id/{user_name}"
            await vault_client.write_secret(path_in_vault, user_creds.dict())

        tasks = [configure_sa(sa) for sa in deployment.service_accounts]
        await asyncio.gather(*tasks)


async def minio_destroy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
) -> None:
    """Idempotently remove an entire Minio cluster, buckets, policies, and users.

    This function:
      1. Retrieves the root Minio credential from Vault (or uses a fallback).
      2. Removes each configured user and policy from Minio.
      3. Removes the root bucket.
      4. Performs a Terraform destroy to remove the Minio infrastructure.

    Args:
        deployment (MinioDeployment):
            The Minio deployment specification, including root bucket and service accounts.
        vault_client (AsyncVaultClient):
            Vault client used for reading/writing secrets.
        base_path (str, optional):
            The Terraform directory path for the Minio module. Defaults to
            "/amoebius/terraform/roots/minio".
        workspace (str, optional):
            The Terraform workspace name. Defaults to "default".

    Raises:
        RuntimeError: Propagates any errors from Vault, Terraform, or Minio operations.
    """
    root_cred_path = "amoebius/minio/root"
    try:
        stored_root_secret = await vault_client.read_secret(root_cred_path)
    except RuntimeError as ex:
        if "404" in str(ex):
            stored_root_secret = {}
        else:
            raise

    if not stored_root_secret:
        # fallback if none found
        stored_root_secret = {
            "url": "http://minio.minio.svc.cluster.local:9000",
            "access_key": "admin",
            "secret_key": "admin123",
            "secure": False,
        }

    root_settings_model = MinioSettings(**stored_root_secret)

    async with MinioAdminClient(root_settings_model) as client:
        # Remove each service account user and policy, plus vault creds
        async def remove_sa(sa_obj: MinioServiceAccountAccess) -> None:
            user_name = sa_obj.service_account_name
            policy_name = f"policy-{user_name}"

            await client.delete_user(user_name)
            await client.delete_policy(policy_name)

            path_in_vault = f"amoebius/minio/id/{user_name}"
            try:
                await vault_client.delete_secret(path_in_vault, hard=False)
            except RuntimeError as ex:
                if "404" in str(ex):
                    pass
                else:
                    raise

        tasks = [remove_sa(sa) for sa in deployment.service_accounts]
        await asyncio.gather(*tasks)

        # Remove the root bucket
        await client.delete_bucket(deployment.minio_root_bucket)

    # Finally destroy the Terraform-managed Minio infra
    storage = VaultKVStorage(root_module="minio", workspace=workspace)
    await destroy_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        base_path=base_path,
    )
