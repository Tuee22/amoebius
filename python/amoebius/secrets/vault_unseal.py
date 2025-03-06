"""
amoebius/secrets/vault_unseal.py

Handles Vault initialization, unseal, and configuration, including storing/loading
Vault init data in encrypted form.

Uses:
  - "VaultInitData" from amoebius.models.vault
  - "TerraformState" from amoebius.models.terraform_state
  - "read_terraform_state", "get_output_from_state" from amoebius.utils.terraform
  - "encrypt_dict_to_file", "decrypt_dict_from_file" from amoebius.secrets.encrypted_dict

All functions typed to pass mypy --strict, assuming a compatible environment.
"""

from __future__ import annotations

import asyncio
import json
import os
import random
from getpass import getpass
from typing import Any, Dict, List, Optional

import yaml
import aiohttp

from amoebius.models.vault import VaultInitData
from amoebius.models.terraform_state import TerraformState
from amoebius.models.validator import validate_type
from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.utils.terraform import read_terraform_state, get_output_from_state
from amoebius.utils.async_retry import async_retry
from amoebius.secrets.encrypted_dict import encrypt_dict_to_file, decrypt_dict_from_file

DEFAULT_SECRETS_FILE_PATH = "/amoebius/data/vault_secrets.bin"
DEFAULT_KUBERNETES_HOST = "https://kubernetes.default.svc.cluster.local/"


@async_retry(retries=30)
async def is_vault_initialized(vault_addr: str) -> bool:
    """
    Check if Vault is initialized by running `vault status -format=json`, with up to 30 retries.

    Args:
        vault_addr: The Vault server address (e.g. http://vault:8200).

    Returns:
        True if Vault is initialized, False otherwise.

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
    """
    Initialize Vault with Shamir's secret sharing using 'vault operator init'.

    Args:
        vault_addr: The Vault server address (e.g. http://vault:8200).
        num_shares: Number of unseal keys to generate (e.g., 5).
        threshold: Minimum number of keys required to unseal Vault (e.g., 3).

    Returns:
        A VaultInitData object with unseal keys and root token.

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
    # Convert JSON to VaultInitData
    return VaultInitData.model_validate_json(out)


async def unseal_vault_pods(
    pod_names: List[str],
    vault_init_data: VaultInitData,
) -> None:
    """
    Unseal each Vault pod using 'vault operator unseal' and a subset of Shamir keys.

    Args:
        pod_names: DNS names or addresses for each Vault pod.
        vault_init_data: The Vault initialization data (unseal keys, threshold).

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
    """
    Configure Vault for Kubernetes auth, KV v2, Transit, and an 'amoebius-policy'.

    Args:
        vault_init_data: Contains root_token and unseal keys.
        tfs: A TerraformState with outputs for e.g. vault SA name/namespace.
        kubernetes_host: The cluster API host (defaults to standard K8s internal URL).

    Raises:
        CommandError: If any vault CLI commands fail.
    """
    # We now provide the third argument "output_type" to get_output_from_state
    # plus type annotations for the local variables.
    vault_sa_name: str = get_output_from_state(tfs, "vault_service_account_name", str)
    vault_service_name: str = get_output_from_state(tfs, "vault_service_name", str)
    vault_sa_namespace: str = get_output_from_state(tfs, "vault_namespace", str)
    vault_common_name: str = get_output_from_state(tfs, "vault_common_name", str)
    vault_secret_path: str = get_output_from_state(tfs, "vault_secret_path", str)

    env = {
        "VAULT_ADDR": vault_common_name,
        "VAULT_TOKEN": vault_init_data.root_token,
    }

    # Check if Kubernetes auth is enabled
    print("Checking if Kubernetes authentication is enabled in Vault...")
    auth_methods_output = await run_command(
        ["vault", "auth", "list", "-format=json"], env=env, retries=30
    )
    auth_methods: Dict[str, Any] = json.loads(auth_methods_output)
    if "kubernetes/" not in auth_methods:
        print("Enabling Kubernetes auth in Vault...")
        await run_command(["vault", "auth", "enable", "kubernetes"], env=env)
    else:
        print("Kubernetes auth is already enabled, skipping.")

    # Create a 10-year token for the SA
    print("Creating a long-lived token via kubectl for the vault SA...")
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
    print("Retrieving cluster CA cert from 'kube-root-ca.crt' configmap...")
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

    print("Writing k8s auth config to Vault...")
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

    # Check for secret/ and transit/ engines
    secrets_list_output = await run_command(
        ["vault", "secrets", "list", "-format=json"],
        env=env,
    )
    secrets_list: Dict[str, Any] = json.loads(secrets_list_output)

    # KV v2
    if "secret/" not in secrets_list:
        print("Enabling KV v2 at 'secret/' path.")
        await run_command(
            ["vault", "secrets", "enable", "-path=secret", "-version=2", "kv"], env=env
        )
    else:
        print("KV v2 at path=secret/ is already enabled. Skipping.")

    # Transit
    if "transit/" not in secrets_list:
        print("Enabling Transit engine at 'transit/' path.")
        await run_command(
            ["vault", "secrets", "enable", "-path=transit", "transit"], env=env
        )
    else:
        print("Transit engine already enabled. Skipping.")

    # Create a policy
    print("Creating 'amoebius-policy' policy in Vault...")
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

    path "transit/*/amoebius/*" {
        capabilities = ["update"]
    }

    path "sys/policies/acl/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
    }
    """
    await run_command(
        ["vault", "policy", "write", "amoebius-policy", "-"],
        input_data=policy_hcl,
        env=env,
    )

    print("Creating 'amoebius-admin-role' for 'amoebius-admin' SA...")
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

    print("Vault configuration completed.")


def save_vault_init_data_to_file(
    vault_init_data: VaultInitData,
    file_path: str,
    password: str,
) -> None:
    """
    Save Vault initialization data to an encrypted file on disk.

    Args:
        vault_init_data: The Vault initialization data (root token, unseal keys, etc.).
        file_path: The path where encrypted data is written.
        password: The password used to encrypt.
    """
    from amoebius.secrets.encrypted_dict import encrypt_dict_to_file

    encrypt_dict_to_file(
        data=vault_init_data.model_dump(),
        password=password,
        file_path=file_path,
    )


def load_vault_init_data_from_file(
    password: str,
    file_path: str = DEFAULT_SECRETS_FILE_PATH,
) -> VaultInitData:
    """
    Load Vault initialization data from an encrypted file on disk.

    Args:
        password: The password used to decrypt.
        file_path: The path of the encrypted data file.

    Returns:
        VaultInitData object.
    """
    from amoebius.secrets.encrypted_dict import decrypt_dict_from_file

    decrypted_data = decrypt_dict_from_file(password=password, file_path=file_path)
    return VaultInitData.model_validate(decrypted_data)


async def retrieve_vault_init_data(
    password: str,
    vault_addr: str,
    num_shares: int,
    threshold: int,
    secrets_file_path: str,
) -> VaultInitData:
    """
    Retrieve (or create) Vault initialization data from an encrypted file, or initialize Vault if not present.

    Args:
        password: The encryption password for the file.
        vault_addr: The Vault server address.
        num_shares: The number of Shamir unseal keys to create if init is needed.
        threshold: The threshold to unseal.
        secrets_file_path: The encrypted file path.

    Returns:
        VaultInitData object containing unseal keys, root token, etc.
    """
    import os

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
    """
    A wrapper for is_vault_initialized, to demonstrate usage with async_retry.
    """
    return await is_vault_initialized(vault_addr)


async def init_unseal_configure_vault(
    default_shamir_shares: int = 5,
    default_shamir_threshold: int = 3,
    secrets_file_path: str = DEFAULT_SECRETS_FILE_PATH,
    user_supplied_password: Optional[str] = None,
) -> None:
    """
    High-level workflow to:
      1) Read Terraform state for Vault (root_name="vault").
      2) Determine if Vault is initialized, prompt for password if needed.
      3) Retrieve or create VaultInitData (initializes Vault if needed).
      4) Unseal all pods.
      5) Configure Vault for K8s auth, secrets, policies.

    Args:
        default_shamir_shares: The default number of unseal key shares.
        default_shamir_threshold: The default threshold for unseal.
        secrets_file_path: Path to store/read the encrypted VaultInitData.
        user_supplied_password: If provided, use it directly.

    Raises:
        RuntimeError: If reading Terraform fails or other steps fail.
        CommandError: If vault CLI calls fail.
    """
    from amoebius.utils.terraform import read_terraform_state, get_output_from_state

    print("Reading vault terraform state with up to 30 retries...")
    try:
        tfs = await read_terraform_state(root_name="vault")
    except Exception as ex:
        raise RuntimeError(
            "Failed to read vault terraform state. Has terraform deploy completed?"
        ) from ex

    # Provide type annotation and third argument for get_output_from_state:
    vault_raft_pod_dns_names: List[str] = get_output_from_state(
        tfs, "vault_raft_pod_dns_names", List[str]
    )
    if not vault_raft_pod_dns_names:
        raise RuntimeError("No 'vault_raft_pod_dns_names' found in Terraform outputs.")

    vault_init_addr = vault_raft_pod_dns_names[0]

    # Determine password (prompt or user-supplied)
    if user_supplied_password is not None:
        password = user_supplied_password
    else:
        # Check if Vault is initialized => single vs double prompt
        vault_is_init = await is_vault_initialized_wrapper(vault_addr=vault_init_addr)

        def get_password_once() -> str:
            return getpass("Enter password to decrypt existing Vault secrets: ")

        def get_password_twice() -> str:
            pwd = getpass("Enter password to encrypt new Vault secrets: ")
            confirm_pwd = getpass("Confirm password: ")
            if pwd != confirm_pwd:
                raise ValueError("Passwords do not match. Aborting.")
            return pwd

        password = get_password_once() if vault_is_init else get_password_twice()

    # Retrieve or create the Vault init data
    vault_init_data = await retrieve_vault_init_data(
        password=password,
        vault_addr=vault_init_addr,
        num_shares=default_shamir_shares,
        threshold=default_shamir_threshold,
        secrets_file_path=secrets_file_path,
    )

    # Unseal
    await unseal_vault_pods(
        pod_names=vault_raft_pod_dns_names,
        vault_init_data=vault_init_data,
    )

    # Configure
    from amoebius.secrets.vault_unseal import configure_vault

    await configure_vault(vault_init_data=vault_init_data, tfs=tfs)


def main() -> None:
    """
    Command-line entry point to init/unseal/configure Vault in one go.
    """
    asyncio.run(init_unseal_configure_vault())


if __name__ == "__main__":
    main()
