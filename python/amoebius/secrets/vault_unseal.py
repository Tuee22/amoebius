"""
Handles Vault initialization, unseal, and configuration, including storing/loading
Vault init data in encrypted form.

We also set a K8s secret "vault-config-status" in namespace "amoebius"
with a single field "configured". We set it to "false" immediately before unsealing,
and update it to "true" once the Vault configuration is done.

Uses:
  - "VaultInitData" from amoebius.models.vault
  - "TerraformState" from amoebius.models.terraform_state
  - "read_terraform_state", "get_output_from_state" from amoebius.utils.terraform
  - "encrypt_dict_to_file", "decrypt_dict_from_file" from amoebius.secrets.encrypted_dict
"""

from __future__ import annotations

import asyncio
import json
import os
import random
from getpass import getpass
from typing import Any, Dict, List, Optional

from amoebius.models.vault import VaultInitData
from amoebius.models.terraform_state import TerraformState
from amoebius.models.validator import validate_type
from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.utils.terraform import read_terraform_state, get_output_from_state
from amoebius.utils.async_retry import async_retry
from amoebius.secrets.encrypted_dict import encrypt_dict_to_file, decrypt_dict_from_file
from amoebius.utils.k8s import put_k8s_secret_data

DEFAULT_SECRETS_FILE_PATH = "/amoebius/data/vault_secrets.bin"
DEFAULT_KUBERNETES_HOST = "https://kubernetes.default.svc.cluster.local/"


@async_retry(retries=30)
async def is_vault_initialized(vault_addr: str) -> bool:
    """Check if Vault is initialized by running `vault status -format=json`, retrying up to 30 times.

    Args:
        vault_addr (str): The Vault server address (e.g. http://vault:8200).

    Returns:
        bool: True if Vault is initialized, False otherwise.

    Raises:
        ValueError: If the 'initialized' field is missing or invalid in the JSON.
        CommandError: If the vault status command fails.
        Exception: After 30 retries, re-raises the last exception.
    """
    env = {"VAULT_ADDR": vault_addr}
    out = await run_command(
        ["vault", "status", "-format=json"],
        sensitive=False,
        env=env,
        successful_return_codes=[0, 1, 2],
        retries=0,
    )

    data = json.loads(out)
    status = data.get("initialized", None)
    if status is None or not isinstance(status, bool):
        raise ValueError("'initialized' field is missing or invalid")

    return validate_type(status, bool)


async def initialize_vault(
    vault_addr: str,
    num_shares: int,
    threshold: int,
) -> VaultInitData:
    """Initialize Vault with Shamir's secret sharing using `vault operator init`.

    Args:
        vault_addr (str): The Vault server address, e.g. "http://vault:8200".
        num_shares (int): Number of unseal keys to generate.
        threshold (int): Minimum number of keys required to unseal Vault.

    Returns:
        VaultInitData: Object with unseal keys and root token.

    Raises:
        CommandError: If the init command fails.
        ValueError: If the JSON output doesn't parse into VaultInitData properly.
    """
    env = {"VAULT_ADDR": vault_addr}
    out = await run_command(
        [
            "vault",
            "operator",
            "init",
            f"-key-shares={num_shares}",
            f"-key-threshold={threshold}",
            "-format=json",
        ],
        env=env,
    )
    return VaultInitData.model_validate_json(out)


async def unseal_vault_pods(
    pod_names: List[str],
    vault_init_data: VaultInitData,
) -> None:
    """Unseal each Vault pod using 'vault operator unseal' and a subset of Shamir keys.

    Args:
        pod_names (List[str]): DNS names or addresses for each Vault pod.
        vault_init_data (VaultInitData): Vault initialization data (keys, threshold).

    Raises:
        CommandError: If any unseal command fails.
    """
    # Randomly sample threshold keys from unseal_keys_b64
    unseal_keys = random.sample(
        vault_init_data.unseal_keys_b64, vault_init_data.unseal_threshold
    )

    async def run_unseal(pod: str, key: str) -> str:
        env = {"VAULT_ADDR": pod}
        return await run_command(
            ["vault", "operator", "unseal", key],
            env=env,
            retries=30,
        )

    tasks = [run_unseal(pod, key) for pod in pod_names for key in unseal_keys]
    await asyncio.gather(*tasks)


async def configure_vault(
    vault_init_data: VaultInitData,
    tfs: TerraformState,
    kubernetes_host: str = DEFAULT_KUBERNETES_HOST,
) -> None:
    """Configure Vault for Kubernetes auth, KV v2, Transit, and an 'amoebius-policy'.

    Once complete, sets a K8s secret "vault-config-status" with "configured" = "true".

    Args:
        vault_init_data (VaultInitData): Contains root_token/unseal keys.
        tfs (TerraformState): A TerraformState with Vault outputs (e.g. SA name).
        kubernetes_host (str): The cluster API host. Defaults to K8s internal URL.

    Raises:
        CommandError: If any Vault CLI command fails.
    """
    vault_sa_name: str = get_output_from_state(tfs, "vault_service_account_name", str)
    vault_service_name: str = get_output_from_state(tfs, "vault_service_name", str)
    vault_sa_namespace: str = get_output_from_state(tfs, "vault_namespace", str)
    vault_addr: str = get_output_from_state(tfs, "vault_addr", str)
    vault_secret_path: str = get_output_from_state(tfs, "vault_secret_path", str)

    env = {
        "VAULT_ADDR": vault_addr,
        "VAULT_TOKEN": vault_init_data.root_token,
    }

    auth_methods_output = await run_command(
        ["vault", "auth", "list", "-format=json"], env=env, retries=30
    )
    auth_methods: Dict[str, Any] = json.loads(auth_methods_output)
    if "kubernetes/" not in auth_methods:
        await run_command(["vault", "auth", "enable", "kubernetes"], env=env)
    else:
        print("Kubernetes auth is already enabled, skipping.")

    # Create a 10-year token via kubectl for the vault SA
    sa_token = await run_command(
        [
            "kubectl",
            "create",
            "token",
            vault_sa_name,
            "--duration=315360000s",
            "-n",
            vault_sa_namespace,
        ]
    )

    # Grab CA cert from configmap
    ca_cert = await run_command(
        [
            "kubectl",
            "get",
            "configmap",
            "kube-root-ca.crt",
            "-n",
            "kube-public",
            "-o",
            "jsonpath={.data['ca\\.crt']}",
        ]
    )

    # Write k8s auth config to Vault
    await run_command(
        [
            "vault",
            "write",
            "auth/kubernetes/config",
            f"token_reviewer_jwt={sa_token}",
            f"kubernetes_host={kubernetes_host}",
            f"kubernetes_ca_cert={ca_cert}",
        ],
        env=env,
    )

    secrets_list_output = await run_command(
        ["vault", "secrets", "list", "-format=json"],
        env=env,
    )
    secrets_list: Dict[str, Any] = json.loads(secrets_list_output)

    # KV v2
    if "secret/" not in secrets_list:
        await run_command(
            ["vault", "secrets", "enable", "-path=secret", "-version=2", "kv"], env=env
        )

    # Transit
    if "transit/" not in secrets_list:
        await run_command(
            ["vault", "secrets", "enable", "-path=transit", "transit"], env=env
        )

    policy_hcl = r"""
    path "secret/data/amoebius/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/metadata/amoebius/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "transit/keys/amoebius" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "transit/+/amoebius" {
      capabilities = ["update"]
    }

    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "auth/kubernetes/role/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    """
    await run_command(
        ["vault", "policy", "write", "amoebius-policy", "-"],
        input_data=policy_hcl,
        env=env,
    )

    # Create a Vault k8s role for the "amoebius-admin" SA
    await run_command(
        [
            "vault",
            "write",
            "auth/kubernetes/role/amoebius-admin-role",
            "bound_service_account_names=amoebius-admin",
            "bound_service_account_namespaces=amoebius",
            "policies=amoebius-policy",
            "ttl=1h",
        ],
        env=env,
    )

    print("Vault configuration completed. Setting 'vault-config-status' to 'true'...")
    # Mark "configured" = "true"
    await put_k8s_secret_data(
        secret_name="vault-config-status",
        namespace="amoebius",
        data={"configured": "true"},
    )


def save_vault_init_data_to_file(
    vault_init_data: VaultInitData,
    file_path: str,
    password: str,
) -> None:
    """Save Vault initialization data to an encrypted file on disk.

    Args:
        vault_init_data (VaultInitData): The Vault initialization data.
        file_path (str): The path where encrypted data is written.
        password (str): The password used to encrypt.
    """
    encrypt_dict_to_file(
        data=vault_init_data.model_dump(),
        password=password,
        file_path=file_path,
    )


def load_vault_init_data_from_file(
    password: str,
    file_path: str = DEFAULT_SECRETS_FILE_PATH,
) -> VaultInitData:
    """Load Vault initialization data from an encrypted file on disk.

    Args:
        password (str): The password used to decrypt.
        file_path (str): The path of the encrypted data file.

    Returns:
        VaultInitData: Parsed unseal data.
    """
    decrypted_data = decrypt_dict_from_file(password=password, file_path=file_path)
    return VaultInitData.model_validate(decrypted_data)


async def retrieve_vault_init_data(
    password: str,
    vault_addr: str,
    num_shares: int,
    threshold: int,
    secrets_file_path: str,
) -> VaultInitData:
    """Retrieve (or create) Vault initialization data from an encrypted file, or initialize Vault if absent.

    Args:
        password (str): The encryption password for the file.
        vault_addr (str): The Vault server address.
        num_shares (int): Number of Shamir unseal keys to create if init is needed.
        threshold (int): The threshold to unseal.
        secrets_file_path (str): The encrypted file path.

    Returns:
        VaultInitData: Contains unseal keys, root token, etc.
    """
    if os.path.exists(secrets_file_path):
        return load_vault_init_data_from_file(
            password=password, file_path=secrets_file_path
        )

    vault_init_data = await initialize_vault(
        vault_addr=vault_addr,
        num_shares=num_shares,
        threshold=threshold,
    )
    save_vault_init_data_to_file(
        vault_init_data=vault_init_data,
        file_path=secrets_file_path,
        password=password,
    )
    return vault_init_data


@async_retry(retries=30)
async def is_vault_initialized_wrapper(vault_addr: str) -> bool:
    """Wrapper for is_vault_initialized, using async_retry."""
    return await is_vault_initialized(vault_addr)


async def init_unseal_configure_vault(
    default_shamir_shares: int = 5,
    default_shamir_threshold: int = 3,
    secrets_file_path: str = DEFAULT_SECRETS_FILE_PATH,
    user_supplied_password: Optional[str] = None,
) -> None:
    """High-level workflow to:
      1) Read Terraform state for root_name="vault".
      2) Determine if Vault is initialized; prompt or confirm password if needed.
      3) Retrieve or create VaultInitData (initializes Vault if needed).
      4) Set "vault-config-status" = "false" immediately before unseal.
      5) Unseal all pods.
      6) Configure Vault for K8s auth, secrets, policies => sets "vault-config-status"="true".

    Args:
        default_shamir_shares (int, optional): Number of unseal key shares. Defaults to 5.
        default_shamir_threshold (int, optional): Threshold to unseal. Defaults to 3.
        secrets_file_path (str, optional): Path to store/read VaultInitData. Defaults to /amoebius/data/vault_secrets.bin.
        user_supplied_password (Optional[str], optional): If provided, use it directly. Otherwise prompt.
    """
    print("Reading vault terraform state ...")
    tfs = await read_terraform_state(root_name="vault", retries=30)

    vault_raft_pod_dns_names: List[str] = get_output_from_state(
        tfs, "vault_raft_pod_dns_names", List[str]
    )
    if not vault_raft_pod_dns_names:
        raise RuntimeError("No 'vault_raft_pod_dns_names' found in Terraform outputs.")

    vault_init_addr = vault_raft_pod_dns_names[0]

    # Acquire password (prompt or user-supplied)
    vault_is_init = await is_vault_initialized_wrapper(vault_addr=vault_init_addr)
    if user_supplied_password is not None:
        password = user_supplied_password
    else:

        def get_password_once() -> str:
            return getpass("Enter password to decrypt existing Vault secrets: ")

        def get_password_twice() -> str:
            pwd = getpass("Enter password to encrypt new Vault secrets: ")
            confirm_pwd = getpass("Confirm password: ")
            if pwd != confirm_pwd:
                raise ValueError("Passwords do not match. Aborting.")
            return pwd

        password = get_password_once() if vault_is_init else get_password_twice()

    vault_init_data = await retrieve_vault_init_data(
        password=password,
        vault_addr=vault_init_addr,
        num_shares=default_shamir_shares,
        threshold=default_shamir_threshold,
        secrets_file_path=secrets_file_path,
    )

    # 4) Immediately before unseal => set "vault-config-status" = "false"
    print("Setting 'vault-config-status' to 'false' just before unseal...")
    await put_k8s_secret_data(
        secret_name="vault-config-status",
        namespace="amoebius",
        data={"configured": "false"},
    )

    # 5) Unseal
    await unseal_vault_pods(
        pod_names=vault_raft_pod_dns_names,
        vault_init_data=vault_init_data,
    )

    # 6) Configure => sets "vault-config-status"="true"
    await configure_vault(
        vault_init_data=vault_init_data,
        tfs=tfs,
    )


def main() -> None:
    """Command-line entry point to init/unseal/configure Vault in one go."""
    asyncio.run(init_unseal_configure_vault())


if __name__ == "__main__":
    main()
