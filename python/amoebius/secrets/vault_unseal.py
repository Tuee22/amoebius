"""
amoebius/secrets/vault_unseal.py

This module handles initialization, unseal, and configuration of Vault,
including storing and loading the Vault init data in encrypted form.

It uses "VaultInitData" from amoebius.models.vault, which is expected to have:
  - root_token: str
  - unseal_keys_b64: list[str]
  - unseal_threshold: int
  (or corresponding fields if your model differs).

References:
  - amoebius.utils.async_command_runner.run_command
  - amoebius.utils.terraform.read_terraform_state
  - amoebius.secrets.encrypted_dict.encrypt_dict_to_file
  - amoebius.secrets.encrypted_dict.decrypt_dict_from_file

All functions are type-annotated and should pass mypy --strict, given a
compatible VaultInitData model and environment.
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
    Check if Vault is initialized by running `vault status -format=json`.

    This function is decorated with @async_retry, which will retry up to 30 times
    if any step fails (useful if Vault isn't ready yet).

    Args:
        vault_addr: The Vault server address (e.g. http://vault:8200).

    Returns:
        True if Vault is initialized, False otherwise.

    Raises:
        ValueError: If the 'initialized' field is missing or invalid in the JSON.
        CommandError: If the vault status command fails.
        Exception: After 30 retries, the last exception is re-raised.
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

    # If we fail to get a valid boolean "initialized", raise ValueError
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
        A VaultInitData object, typically containing unseal keys and root token.

    Raises:
        CommandError: If the initialization command fails or returns a bad status.
        ValueError: If the JSON output does not parse into VaultInitData properly.
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
    # We rely on VaultInitData.model_validate_json(...) to parse the output
    return VaultInitData.model_validate_json(out)


async def unseal_vault_pods(
    pod_names: List[str],
    vault_init_data: VaultInitData,
) -> None:
    """
    Unseal a list of Vault pods using a subset of unseal keys.

    This code randomly selects 'vault_init_data.unseal_threshold' keys from
    'vault_init_data.unseal_keys_b64', then uses them on each pod.

    Args:
        pod_names: List of DNS names or addresses for each Vault pod.
        vault_init_data: The Vault initialization data with unseal_keys_b64
            and unseal_threshold fields.

    Returns:
        None. On success, each pod is unsealed.

    Raises:
        CommandError: If any vault unseal command fails.
    """
    # Randomly sample the required number of keys
    unseal_keys = random.sample(
        vault_init_data.unseal_keys_b64, vault_init_data.unseal_threshold
    )

    async def run_unseal(pod: str, key: str) -> str:
        env = {"VAULT_ADDR": pod}
        return await run_command(["vault", "operator", "unseal", key], env=env)

    # We attempt unsealing each pod with each of the randomly chosen keys
    tasks = [run_unseal(pod, key) for pod in pod_names for key in unseal_keys]
    await asyncio.gather(*tasks)


async def configure_vault(
    vault_init_data: VaultInitData,
    tfs: TerraformState,
    kubernetes_host: str = DEFAULT_KUBERNETES_HOST,
) -> None:
    """
    Configure Vault for Kubernetes authentication, enabling KV v2, transit engine, and policies.

    Steps performed:
        1. Enable (or confirm enabled) Kubernetes auth.
        2. Create a long-lived token for the vault service account (via kubectl).
        3. Configure auth/kubernetes with the cluster's CA and the reviewer token.
        4. Enable (or confirm enabled) KV v2 at path=secret.
        5. Enable (or confirm enabled) Transit engine at path=transit.
        6. Create an 'amoebius-policy' with relevant capabilities.
        7. Create an 'amoebius-admin-role' bound to the 'amoebius-admin' service account.

    Args:
        vault_init_data: The VaultInitData, used for root_token.
        tfs: TerraformState containing deployment details and outputs.
        kubernetes_host: The cluster API host, defaults to "https://kubernetes.default.svc.cluster.local/".
    """
    vault_sa_name = get_output_from_state(tfs, "vault_service_account_name", str)
    vault_service_name = get_output_from_state(tfs, "vault_service_name", str)
    vault_sa_namespace = get_output_from_state(tfs, "vault_namespace", str)
    vault_common_name = get_output_from_state(tfs, "vault_common_name", str)
    vault_secret_path = get_output_from_state(tfs, "vault_secret_path", str)

    env = {
        "VAULT_ADDR": vault_common_name,
        "VAULT_TOKEN": vault_init_data.root_token,
    }

    print("Checking if Kubernetes authentication is already enabled in Vault...")
    auth_methods_output = await run_command(
        ["vault", "auth", "list", "-format=json"], env=env, retries=30
    )
    auth_methods: Dict[str, Any] = json.loads(auth_methods_output)

    if "kubernetes/" not in auth_methods:
        print("Enabling Kubernetes authentication in Vault...")
        await run_command(["vault", "auth", "enable", "kubernetes"], env=env)
    else:
        print("Kubernetes auth is already enabled. Skipping enable step.")

    # Create a 10-year token for the service account
    print("Creating a long-lived token for the vault service account via kubectl...")
    sa_token = await run_command(
        [
            "kubectl",
            "create",
            "token",
            vault_sa_name,
            "--duration=315360000s",  # 10 years
            "-n",
            vault_sa_namespace,
        ]
    )

    # Get the cluster root CA cert
    print("Retrieving cluster CA cert from configmap kube-root-ca.crt...")
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

    print("Configuring the Kubernetes auth method in Vault...")
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

    # Check secrets engines
    print("Checking which secrets engines are enabled (vault secrets list)...")
    secrets_list_output = await run_command(
        ["vault", "secrets", "list", "-format=json"], env=env
    )
    secrets_list: Dict[str, Any] = json.loads(secrets_list_output)

    # KV v2
    if "secret/" not in secrets_list:
        print("Enabling KV v2 at path=secret/")
        await run_command(
            ["vault", "secrets", "enable", "-path=secret", "-version=2", "kv"],
            env=env,
        )
    else:
        print("KV v2 at path=secret/ is already enabled. Skipping.")

    # Transit engine
    if "transit/" not in secrets_list:
        print("Enabling Transit engine at path=transit/")
        await run_command(
            ["vault", "secrets", "enable", "-path=transit", "transit"], env=env
        )
    else:
        print("Transit engine at path=transit/ is already enabled. Skipping.")

    # Write a policy named 'amoebius-policy'
    print("Creating policy 'amoebius-policy'...")
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
    """
    await run_command(
        ["vault", "policy", "write", "amoebius-policy", "-"],
        input_data=policy_hcl,
        env=env,
    )

    # Create a K8s auth role => 'amoebius-admin-role'
    print("Configuring auth role 'amoebius-admin-role' for the 'amoebius-admin' SA...")
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

    print("\n=== Vault Configuration Completed ===\n")


def save_vault_init_data_to_file(
    vault_init_data: VaultInitData,
    file_path: str,
    password: str,
) -> None:
    """
    Save Vault initialization data to an encrypted file on disk.

    Args:
        vault_init_data: The Vault initialization data (root token, unseal keys, etc.).
        file_path: The file path where the encrypted data will be written.
        password: The password used to encrypt the file.

    Returns:
        None. The encrypted file is created or overwritten.
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
    """
    Load Vault initialization data from an encrypted file on disk.

    Args:
        password: The password to decrypt the file.
        file_path: The file path of the encrypted data (defaults to /amoebius/data/vault_secrets.bin).

    Returns:
        A VaultInitData instance loaded from the decrypted JSON.
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
    """
    Retrieve (or create) Vault initialization data from an encrypted file, or initialize Vault if not present.

    1. If 'secrets_file_path' exists, load VaultInitData from that file (decrypt).
    2. Otherwise, run 'initialize_vault' to get new data, then save it to the file.

    Args:
        password: Password for encrypt/decrypt of the VaultInitData file.
        vault_addr: The Vault server address used if we need to initialize Vault.
        num_shares: Number of unseal keys to generate if initialization is required.
        threshold: Minimum number of keys required to unseal Vault.
        secrets_file_path: The path to the encrypted secrets file.

    Returns:
        A VaultInitData object, either loaded from disk or newly created.

    Raises:
        CommandError: If initialization fails or the file is unreadable.
    """
    if os.path.exists(secrets_file_path):
        return load_vault_init_data_from_file(
            password=password,
            file_path=secrets_file_path,
        )

    # Otherwise initialize a new Vault
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


async def init_unseal_configure_vault(
    default_shamir_shares: int = 5,
    default_shamir_threshold: int = 3,
    secrets_file_path: str = DEFAULT_SECRETS_FILE_PATH,
    user_supplied_password: Optional[str] = None,
) -> None:
    """
    High-level workflow to:
      1) Read Terraform state for Vault.
      2) Determine if Vault is initialized and prompt for password(s).
      3) Retrieve or create VaultInitData (initialize if needed).
      4) Unseal all Vault pods using the unseal keys.
      5) Configure Vault for Kubernetes integration (auth, secrets, policies).

    Args:
        default_shamir_shares: The default number of unseal key shares to create if we must initialize (5).
        default_shamir_threshold: The default threshold required to unseal Vault (3).
        secrets_file_path: Where to store/read the encrypted VaultInitData (defaults to /amoebius/data/vault_secrets.bin).
        user_supplied_password: If provided, use that password for encryption/decryption
            without prompting. Otherwise, we prompt the user.

    Raises:
        RuntimeError: If reading the vault terraform state fails or other steps fail.
        CommandError: If the vault CLI commands fail.
    """
    try:
        print("Attempting to retrieve vault terraform state...")
        tfs = await read_terraform_state(root_name="vault")
    except Exception as ex:
        raise RuntimeError(
            "Failed to read vault terraform state. Has terraform deploy completed?"
        ) from ex

    # Retrieve values from Terraform outputs
    vault_raft_pod_dns_names = get_output_from_state(
        tfs, "vault_raft_pod_dns_names", List[str]
    )
    if not vault_raft_pod_dns_names:
        raise RuntimeError("No 'vault_raft_pod_dns_names' found in Terraform outputs.")

    # Use the first DNS entry to check if Vault is initialized
    vault_init_addr = vault_raft_pod_dns_names[0]

    async def prompt_for_password() -> str:
        """
        Prompt the user for a password. If Vault is already initialized, prompt once,
        otherwise prompt twice for confirmation when we initialize Vault.
        """

        def get_password_once() -> str:
            return getpass("Enter the password to decrypt existing Vault secrets: ")

        def get_password_twice() -> str:
            pwd = getpass("Enter a password to encrypt new Vault secrets: ")
            confirm_pwd = getpass("Confirm the password: ")
            if pwd != confirm_pwd:
                raise ValueError("Passwords do not match. Aborting.")
            return pwd

        print("Waiting for vault raft to be online ...")
        vault_is_init = await is_vault_initialized(vault_addr=vault_init_addr)
        return get_password_once() if vault_is_init else get_password_twice()

    password: str
    if user_supplied_password is not None:
        password = user_supplied_password
    else:
        password = await prompt_for_password()

    # Retrieve or create Vault initialization data
    vault_init_data: VaultInitData = await retrieve_vault_init_data(
        password=password,
        vault_addr=vault_init_addr,
        num_shares=default_shamir_shares,
        threshold=default_shamir_threshold,
        secrets_file_path=secrets_file_path,
    )

    # Unseal the Vault pods
    await unseal_vault_pods(
        pod_names=vault_raft_pod_dns_names,
        vault_init_data=vault_init_data,
    )

    # Configure Vault (K8s, policies, etc.)
    await configure_vault(
        vault_init_data=vault_init_data,
        tfs=tfs,
    )


def main() -> None:
    """
    Command-line entry point:
      1) Runs init_unseal_configure_vault in an event loop
      2) On success, Vault is fully initialized, unsealed, and configured.

    By default, it prompts for user input if the secrets file is missing or
    if an existing file needs decryption. If you want to pass a password
    without prompting, you can adapt user_supplied_password and run in code.
    """
    asyncio.run(init_unseal_configure_vault())


if __name__ == "__main__":
    main()
