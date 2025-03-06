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
from typing import Optional, List, Dict, Any

from amoebius.models.minio import (
    MinioDeployment,
    MinioSettings,
    MinioServiceAccountAccess,
    MinioPolicySpec,
    MinioBucketPermission,
)
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
    VaultKVStorage,
)
from amoebius.utils.minio import (
    create_bucket,
    delete_bucket,
    create_policy,
    delete_policy,
    create_user,
    delete_user,
    attach_policy_to_user,
)
from amoebius.utils.async_command_runner import run_command, CommandError


async def minio_deploy(
    deployment: MinioDeployment,
    vault_client: AsyncVaultClient,
    *,
    base_path: str = "/amoebius/terraform/roots/minio",
    workspace: str = "default",
    skip_missing_sas: bool = True,
) -> None:
    """
    Idempotently deploy a Minio cluster + relevant buckets/policies, store credentials in Vault.

    Steps:
      1) Generate or retrieve "root" credentials from vault path=amoebius/minio/root
      2) Terraform init/apply for the Minio cluster
      3) Create the "root bucket" from deployment
      4) Retrieve K8s SAs with "kubectl get serviceaccounts -A -o json"
      5) For each SA in 'deployment.service_accounts':
         - If skip_missing_sas=True and SA not found, skip
         - Create user + policy in Minio
         - Attach policy
         - Store credential in Vault => 'amoebius/minio/id/<sa_name>'

    Args:
        deployment (MinioDeployment): The entire desired config.
        vault_client (AsyncVaultClient): For storing creds + ephemeral usage.
        base_path (str): Terraform directory path. Default is /amoebius/terraform/roots/minio.
        workspace (str): Terraform workspace. Default 'default'.
        skip_missing_sas (bool): If True, skip SAs that don't exist in the cluster.
    """
    # 1) Generate or retrieve "root" credentials from vault
    root_cred_path = "amoebius/minio/root"
    try:
        stored_root_secret = await vault_client.read_secret(root_cred_path)
    except RuntimeError as ex:
        if "404" in str(ex):
            stored_root_secret = {}
        else:
            raise

    if not stored_root_secret:
        # create random root credential
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

    # 3) Create the "root bucket"
    await create_bucket(root_settings_model, deployment.minio_root_bucket)

    # 4) Retrieve actual K8s SAs
    cmd_sa = ["kubectl", "get", "serviceaccounts", "-A", "-o", "json"]
    raw_sa_json = await run_command(cmd_sa, retries=0)
    parsed = json.loads(raw_sa_json)
    # Build a set of "ns:name"
    found_sas = set()
    for item in parsed.get("items", []):
        ns = item.get("metadata", {}).get("namespace", "")
        nm = item.get("metadata", {}).get("name", "")
        if ns and nm:
            found_sas.add(f"{ns}:{nm}")

    # 5) For each SA in the deployment, concurrency
    async def configure_sa(sa_obj: MinioServiceAccountAccess) -> None:
        user_name = sa_obj.service_account_name
        # if skip_missing_sas => check if found in cluster
        if skip_missing_sas:
            # We'll interpret "any namespace" => must be {anyNs}:{user_name} in found_sas
            # Or user might have to specify "namespace"? This is a placeholder approach
            # We'll just check if user_name is in the set "someNamespace:user_name"
            if not any(user_name == s.split(":", 1)[1] for s in found_sas):
                return  # skip

        # random password
        user_password = secrets.token_urlsafe(16)

        await create_user(root_settings_model, user_name, user_password)
        policy_name = f"policy-{user_name}"
        await create_policy(root_settings_model, policy_name, sa_obj.bucket_permissions)
        await attach_policy_to_user(root_settings_model, user_name, policy_name)

        # store in vault => "amoebius/minio/id/<sa_name>"
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
    """
    Idempotently remove the entire Minio cluster + relevant buckets/policies/users.

    Steps:
      1) Retrieve root cred from Vault
      2) For each SA, remove user & policy, remove vault secret
      3) Remove root bucket
      4) Terraform destroy
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
        # fallback
        stored_root_secret = {
            "url": "http://minio.minio.svc.cluster.local:9000",
            "access_key": "admin",
            "secret_key": "admin123",
            "secure": False,
        }

    root_settings_model = MinioSettings(**stored_root_secret)

    # concurrency to remove SAs
    import asyncio

    async def remove_sa(sa_obj: MinioServiceAccountAccess) -> None:
        user_name = sa_obj.service_account_name
        policy_name = f"policy-{user_name}"
        await delete_user(root_settings_model, user_name)
        await delete_policy(root_settings_model, policy_name)
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

    # remove root bucket
    await delete_bucket(root_settings_model, deployment.minio_root_bucket)

    # tf destroy
    storage = VaultKVStorage(root_module="minio", workspace=workspace)
    await destroy_terraform(
        root_name="minio",
        workspace=workspace,
        storage=storage,
        vault_client=vault_client,
        base_path=base_path,
    )
