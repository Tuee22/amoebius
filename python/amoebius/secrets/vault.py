import asyncio
import os
import json
import base64
import random
from getpass import getpass
from typing import Any, Dict, List, Optional, Tuple
from ..models.vault import VaultInitData

import yaml
import aiohttp

from ..utils.async_command_runner import run_command, CommandError
from ..utils.terraform import read_terraform_state, get_output_from_state
from .encrypted_dict import encrypt_dict_to_file, decrypt_dict_from_file

async def is_vault_initialized(vault_addr: str) -> bool:
    """Check if Vault is initialized by running `vault status -format=json`.

    Returns:
        True if Vault is initialized, False otherwise.

    Raises:
        CommandError: If the `vault status` command fails unexpectedly.
    """
    try:
        env = {"VAULT_ADDR": vault_addr}
        out = await run_command(
            ["vault", "status", "-format=json"],
            env=env,
        )
        status = json.loads(output)
        return status.get("initialized", False)
    except CommandError as e:
        raise CommandError("Failed to determine Vault initialization status", e.return_code)


async def initialize_vault(vault_addr: str, num_shares: int, threshold: int) -> VaultInitData:
    env = {"VAULT_ADDR": vault_addr}
    out = await run_command(
        ["vault", "operator", "init", f"-key-shares={num_shares}", f"-key-threshold={threshold}", "-format=json"],
        env=env
    )
    return VaultInitData.parse_raw(out)


async def get_vault_pods(namespace: str) -> List[str]:
    pods_output = await run_command([
        "kubectl", "get", "pods",
        "-l", "app.kubernetes.io/name=vault",
        "-n", namespace,
        "-o", "jsonpath={.items[*].metadata.name}"
    ])
    return pods_output.strip().split()


async def unseal_vault_pods(vault_init_data: VaultInitData, namespace: str) -> None:
    pod_names = await get_vault_pods(namespace)
    unseal_keys = random.sample(vault_init_data.unseal_keys_b64,vault_init_data.unseal_threshold)

    async def run_unseal(pod: str, key: str) -> str:
        env = {"VAULT_ADDR": f"http://{pod}.{namespace}.svc.cluster.local:8200"}
        return await run_command(["vault", "operator", "unseal", key], env=env)

    tasks = [run_unseal(pod, key) for pod in pod_names for key in unseal_keys]
    await asyncio.gather(*tasks)

async def configure_vault_kubernets_for_k8s_auth_and_sidecar(env:Dict[str,Any]):
    # implement logic from bash script here using run_command


async def init_unseal_configure_vault(
    default_shamir_shares: int = 5,
    default_shamir_threshold: int = 3
) -> None:
    # Read terraform state for vault
    state = await read_terraform_state(root_name="vault")

    # Retrieve values from terraform outputs
    vault_namespace = get_output_from_state(state, "vault_namespace", str)
    vault_replicas = get_output_from_state(state, "vault_replicas", int)
    vault_service_name = get_output_from_state(state, "vault_service_name", str)
    vault_common_name = get_output_from_state(state, "vault_common_name", str)
    vault_raft_pod_dns_names = get_output_from_state(state, "vault_raft_pod_dns_names", List[str])

    vault_init_addr = vault_raft_pod_dns_names[0]
    secrets_file_path = "/amoebius/data/vault_secrets.bin"

    async def get_initialized_secrets_from_file() -> VaultInitData:
        """Retrieve secrets from an encrypted file."""
        password = getpass("Enter the password to decrypt Vault secrets: ")
        decrypted_data = decrypt_dict_from_file(secrets_file_path, password)
        return VaultInitData.parse_obj(decrypted_data)

    async def initialize_vault_and_save_secrets() -> VaultInitData:
        """Initialize Vault and save secrets to an encrypted file."""
        if os.path.exists(secrets_file_path):
            raise FileExistsError(f"Secrets file already exists at {secrets_file_path}.")
        
        password = getpass("Enter a password to encrypt Vault secrets: ")
        confirm_password = getpass("Confirm the password: ")
        if password != confirm_password:
            raise ValueError("Passwords do not match. Aborting initialization.")

        vault_init_data = await initialize_vault(
            vault_addr=f"http://{vault_init_addr}",
            num_shares=default_shamir_shares,
            threshold=default_shamir_threshold
        )
        
        encrypt_dict_to_file(vault_init_data.dict(), secrets_file_path, password)
        return vault_init_data

    is_initialized = await is_vault_initialized(vault_addr=f"http://{vault_init_addr}")
    vault_init_data_getter = (
        get_initialized_secrets_from_file if is_initialized else initialize_vault_and_save_secrets
    )
    vault_init_data: VaultInitData = await vault_init_data_getter()

    # Unseal Vault pods
    await unseal_vault_pods(vault_init_data, vault_namespace)

    vault_cli_env={"VAULT_ADDR": vault_addr, "VAULT_TOKEN": vault_init_data.root_token}
    await configure_vault_kubernets_for_k8s_auth_and_sidecar(env=vault_cli_env)



if __name__ == "__main__":
    # Adjust root_name if needed
    asyncio.run(init_unseal_configure_vault())
