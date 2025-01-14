import asyncio
import os
import json
import random
from getpass import getpass
from typing import Any, Dict, List, Optional, Tuple

from ..models.vault import VaultInitData
from ..models.terraform_state import TerraformState
from ..models.validator import validate_type

import yaml
import aiohttp

from ..utils.async_command_runner import run_command, CommandError
from ..utils.terraform import read_terraform_state, get_output_from_state
from .encrypted_dict import encrypt_dict_to_file, decrypt_dict_from_file

DEFAULT_SECRETS_FILE_PATH = "/amoebius/data/vault_secrets.bin"
DEFAULT_KUBERNETES_HOST = "https://kubernetes.default.svc.cluster.local/"


# ------------------------
# Vault Operations Module
# ------------------------


import asyncio
import json


async def is_vault_initialized(
    vault_addr: str, retries: int = 30
) -> bool:
    """
    Check if Vault is initialized by running `vault status -format=json`. If any step in
    the try block fails, this function retries up to `retries` times (waiting `delay`
    seconds between attempts).

    Args:
        vault_addr: The Vault server address.
        retries: Max number of recursive attempts.
        delay: Seconds to wait between retries.

    Returns:
        True if Vault is initialized, False otherwise.

    Raises:
        RuntimeError: If we run out of retries.
        CommandError: If the `vault status` command fails unexpectedly.
    """
    if retries <= 0:
        raise RuntimeError(
            "Exceeded maximum retries while determining Vault initialization status."
        )

    try:
        env = {"VAULT_ADDR": vault_addr}
        out = await run_command(
            ["vault", "status", "-format=json"],
            sensitive=False,
            env=env,
            successful_return_codes=[0, 1, 2],
        )

        data = json.loads(out)
        status = data.get("initialized", None)

        # If we fail to get a valid boolean "initialized", force a retry
        if status is None or not isinstance(status, bool):
            raise ValueError("'initialized' field is missing or invalid")

        # If everything works, return the validated status
        return validate_type(status, bool)

    except Exception as exc:
        # Any error triggers a retry (unless we're out of retries)
        print(
            f"[Retry {31 - retries}/30] Vault status check failed: {exc}\n"
            f"Waiting {delay}s before retry..."
        )
        await asyncio.sleep(1.0)
        return await is_vault_initialized(vault_addr, retries - 1, delay)


async def initialize_vault(
    vault_addr: str, num_shares: int, threshold: int
) -> VaultInitData:
    """Initialize Vault with Shamir's secret sharing.

    Args:
        vault_addr: The Vault server address.
        num_shares: Number of unseal keys to generate.
        threshold: Minimum number of keys required to unseal Vault.

    Returns:
        VaultInitData: The initialization data including unseal keys and root token.

    Raises:
        CommandError: If the initialization command fails.
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
    pod_names: List[str], vault_init_data: VaultInitData
) -> None:
    """Unseal all Vault pods using unseal keys.

    Args:
        pod_names: List of Vault pod DNS names.
        vault_init_data: Vault initialization data containing unseal keys.
    """
    unseal_keys = random.sample(
        vault_init_data.unseal_keys_b64, vault_init_data.unseal_threshold
    )

    async def run_unseal(pod: str, key: str) -> str:
        env = {"VAULT_ADDR": pod}
        return await run_command(["vault", "operator", "unseal", key], env=env)

    tasks = [run_unseal(pod, key) for pod in pod_names for key in unseal_keys]
    await asyncio.gather(*tasks)


async def configure_vault_kubernetes_for_k8s_auth_and_sidecar(
    vault_init_data: VaultInitData,
    tfs: TerraformState,
    kubernetes_host: str = DEFAULT_KUBERNETES_HOST,
) -> None:
    """Configure Vault for Kubernetes authentication and sidecar injection.

    Args:
        vault_init_data: Vault init secrets.
        tfs: Terraform state containing deployment details for Vault and Kubernetes.
    """
    vault_sa_name = get_output_from_state(tfs, "vault_service_account_name", str)
    vault_service_name = get_output_from_state(tfs, "vault_service_name", str)
    vault_sa_namespace = get_output_from_state(tfs, "vault_namespace", str)
    vault_common_name = get_output_from_state(tfs, "vault_common_name", str)
    vault_secret_path = get_output_from_state(tfs, "vault_secret_path", str)
    env = {"VAULT_ADDR": vault_common_name, "VAULT_TOKEN": vault_init_data.root_token}

    print("Checking if Kubernetes authentication is already enabled in Vault...")
    auth_methods_output = await run_command(
        ["vault", "auth", "list", "-format=json"],
        env=env,
        retries=30,  # longer retry interval is to give raft a chance to sync
    )
    auth_methods = json.loads(auth_methods_output)

    if "kubernetes/" not in auth_methods:
        print("Enabling Kubernetes authentication in Vault...")
        await run_command(
            ["vault", "auth", "enable", "kubernetes"], sensitive=False, env=env
        )
    else:
        print(
            "Kubernetes authentication is already enabled in Vault. Skipping enable step."
        )

    sa_token = await run_command(
        [
            "kubectl",
            "create",
            "token",
            vault_sa_name,
            "--duration=315360000s",  # ten years
            "-n",
            vault_sa_namespace,
        ]
    )
    # Get root CA cert
    print("Configuring Kubernetes auth method in Vault")
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

    # configure the auth
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

    # Enable KV secrets engine in an idempotent way
    print("Checking if KV (v2) is already enabled at path=secret/")
    secrets_list_output = await run_command(
        ["vault", "secrets", "list", "-format=json"], env=env
    )
    secrets_list = json.loads(secrets_list_output)

    if "secret/" not in secrets_list:
        print("Enabling KV v2 at path=secret/")
        await run_command(
            [
                "vault",
                "secrets",
                "enable",
                "-path=secret",
                "-version=2",
                "kv",
            ],
            env=env,
        )
    else:
        print("KV v2 at path=secret/ is already enabled. Skipping secrets enable step.")
    print(
        "\n=== Vault Kubernetes Authentication Configuration Completed Successfully ==="
    )


# ------------------------
# File Operations Module
# ------------------------


def save_vault_init_data_to_file(
    vault_init_data: VaultInitData, file_path: str, password: str
) -> None:
    """Save Vault initialization data to an encrypted file.

    Args:
        vault_init_data: The Vault initialization data.
        file_path: Path to the file where data will be saved.
        password: Password to encrypt the data.
    """
    encrypt_dict_to_file(
        data=vault_init_data.model_dump(),
        password=password,
        file_path=file_path,
    )


def load_vault_init_data_from_file(
    password: str, file_path: str = DEFAULT_SECRETS_FILE_PATH
) -> VaultInitData:
    """Load Vault initialization data from an encrypted file.

    Args:
        file_path: Path to the encrypted secrets file.
        password: Password to decrypt the data.

    Returns:
        VaultInitData: The decrypted Vault initialization data.
    """
    decrypted_data = decrypt_dict_from_file(password=password, file_path=file_path)
    return VaultInitData.model_validate(decrypted_data)


# ------------------------
# Intermediary Function
# ------------------------


async def retrieve_vault_init_data(
    password: str,
    vault_addr: str,
    num_shares: int,
    threshold: int,
    secrets_file_path: str,
) -> VaultInitData:
    """Retrieve Vault initialization data either from file or by initializing Vault.

    Args:
        password: Password for encryption/decryption.
        vault_addr: The Vault server address.
        num_shares: Number of unseal keys to generate.
        threshold: Minimum number of keys required to unseal Vault.
        secrets_file_path: Path to the encrypted secrets file.

    Returns:
        VaultInitData: The Vault initialization data.
    """
    if os.path.exists(secrets_file_path):
        return load_vault_init_data_from_file(
            file_path=secrets_file_path, password=password
        )
    else:
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


# ------------------------
# Main Initialization
# ------------------------


async def init_unseal_configure_vault(
    default_shamir_shares: int = 5,
    default_shamir_threshold: int = 3,
    secrets_file_path: str = DEFAULT_SECRETS_FILE_PATH,
) -> None:
    """Initialize, unseal, and configure Vault for Kubernetes integration."""
    try:
        tfs = await read_terraform_state(root_name="vault")
    except:
        raise RuntimeError(
            "Failed to read vault terraform state-- has terraform deploy completed ?"
        )

    # Retrieve values from Terraform outputs
    vault_namespace = get_output_from_state(tfs, "vault_namespace", str)
    vault_raft_pod_dns_names = get_output_from_state(
        tfs, "vault_raft_pod_dns_names", List[str]
    )
    vault_init_addr = vault_raft_pod_dns_names[0]

    # Check if Vault is already initialized
    is_initialized = await is_vault_initialized(vault_addr=vault_init_addr)

    if is_initialized:
        # Prompt for password to decrypt existing secrets
        password = getpass("Enter the password to decrypt Vault secrets: ")
    else:
        # Prompt for password with confirmation to encrypt new secrets
        password = getpass("Enter a password to encrypt Vault secrets: ")
        confirm_password = getpass("Confirm the password: ")
        if password != confirm_password:
            raise ValueError("Passwords do not match. Aborting initialization.")

    # Retrieve Vault initialization data
    vault_init_data: VaultInitData = await retrieve_vault_init_data(
        password=password,
        vault_addr=vault_init_addr,
        num_shares=default_shamir_shares,
        threshold=default_shamir_threshold,
        secrets_file_path=secrets_file_path,
    )

    # Unseal Vault pods
    await unseal_vault_pods(
        pod_names=vault_raft_pod_dns_names, vault_init_data=vault_init_data
    )

    # Configure Vault for Kubernetes integration
    await configure_vault_kubernetes_for_k8s_auth_and_sidecar(vault_init_data, tfs)


if __name__ == "__main__":
    asyncio.run(init_unseal_configure_vault())
