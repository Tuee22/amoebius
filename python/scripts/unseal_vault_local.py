#!/usr/bin/env python
import asyncio
import os
import sys
import random
from amoebius.secrets.encrypted_dict import (
    get_password,
    get_new_password,
    decrypt_dict_from_file,
    encrypt_dict_to_file,
)
from amoebius.secrets.vault import unseal_vault_pods_concurrently, initialize_vault
from amoebius.secrets.terraform import read_terraform_state, get_output_from_state
from amoebius.utils.async_command_runner import CommandError
from typing import List, Callable, Dict, Any

def get_int_input(prompt: str, min_value: int = 1) -> int:
    while True:
        try:
            value = int(input(prompt))
            if value >= min_value:
                return value
            else:
                print(f"Please enter a value of at least {min_value}.")
        except ValueError:
            print("Please enter a valid integer.")

async def handle_vault_initialization(secrets_file_path: str) -> None:
    password: str = get_new_password()
    secret_shares: int = get_int_input("Enter the number of key shares to create: ", 1)
    secret_threshold: int = get_int_input(
        f"Enter the number of shares required to reconstruct the master key (1-{secret_shares}): ",
        1,
    )

    def validate_threshold(
        threshold: int, secret_shares: int, get_input: Callable[[str, int], int]
    ) -> int:
        if threshold <= secret_shares:
            return threshold
        else:
            new_threshold: int = get_input(
                f"Error: Threshold cannot be greater than the number of shares.\n"
                f"Enter the number of shares required to reconstruct the master key (1-{secret_shares}): ",
                1
            )
            return validate_threshold(new_threshold, secret_shares, get_input)

    secret_threshold = validate_threshold(secret_threshold, secret_shares, get_int_input)
    terraform_dir: str = "/amoebius/terraform/roots/kind"
    output_name: str = "vault_raft_pod_dns_names"
    terraform_state = read_terraform_state(terraform_dir)
    if terraform_state is None:
        print("Error: Failed to read Terraform state.")
        sys.exit(1)
    local_vault_hosts = get_output_from_state(
        state=terraform_state, output_name=output_name, output_type=List[str]
    )
    if local_vault_hosts is None or not isinstance(local_vault_hosts, list):
        print(f"Error: Output '{output_name}' not found in Terraform state or is not a list.")
        sys.exit(1)

    try:
        secrets_dict: Dict[str, Any] = await initialize_vault(
            local_vault_hosts[0], secret_shares, secret_threshold
        )
        unseal_keys = secrets_dict.get("unseal_keys_b64")
        if not isinstance(unseal_keys, list) or not all(isinstance(key, str) for key in unseal_keys):
            print("Error: 'unseal_keys_b64' is not a list of strings.")
            sys.exit(1)
        unseal_keys_str: List[str] = unseal_keys
        await unseal_vault_pods_concurrently(
            local_vault_hosts[:1], random.sample(unseal_keys_str, secret_threshold)
        )
        await asyncio.sleep(3)
        await unseal_vault_pods_concurrently(
            local_vault_hosts[1:], random.sample(unseal_keys_str, secret_threshold)
        )
        encrypt_dict_to_file(secrets_dict, password, secrets_file_path)
        print("Vault initialized and secrets saved.")
        print(f"IMPORTANT: {secret_shares} unseal keys have been generated.")
        print(
            f"You will need at least {secret_threshold} of these keys to unseal the vault."
        )
        print("Make sure to securely back up these keys separately.")
    except CommandError as e:
        print(f"Failed to initialize vault: {str(e)}")
        sys.exit(1)

async def handle_vault_unsealing(secrets_file_path: str) -> None:
    password: str = get_password("Enter password to decrypt vault secrets: ")
    try:
        secrets_dict: Dict[str, Any] = decrypt_dict_from_file(password, secrets_file_path)
    except ValueError as e:
        print(f"Error decrypting file: {str(e)}")
        sys.exit(1)

    unseal_keys = secrets_dict.get("unseal_keys_b64")
    secret_threshold = secrets_dict.get("unseal_threshold")

    if not isinstance(unseal_keys, list) or not all(isinstance(key, str) for key in unseal_keys) or not isinstance(secret_threshold, int):
        print("Error: Invalid data structure in the decrypted secrets.")
        sys.exit(1)
    
    unseal_keys_str: List[str] = unseal_keys

    terraform_dir: str = "/amoebius/terraform/roots/kind"
    output_name: str = "vault_raft_pod_dns_names"
    terraform_state = read_terraform_state(terraform_dir)
    if terraform_state is None:
        print("Error: Failed to read Terraform state.")
        sys.exit(1)
    local_vault_hosts = get_output_from_state(
        state=terraform_state, output_name=output_name, output_type=List[str]
    )
    if local_vault_hosts is None or not isinstance(local_vault_hosts, list):
        print(f"Error: Output '{output_name}' not found in Terraform state or is not a list.")
        sys.exit(1)

    print(f"Unsealing Vault pods: {local_vault_hosts}")
    print(f"Using {secret_threshold} out of {len(unseal_keys_str)} unseal keys.")

    try:
        await unseal_vault_pods_concurrently(
            local_vault_hosts, random.sample(unseal_keys_str, secret_threshold)
        )
    except Exception as e:
        print(f"Error during vault unsealing: {str(e)}")
        sys.exit(1)

async def main() -> None:
    secrets_file_path: str = "/amoebius/data/vault_secrets.bin"
    if os.path.exists(secrets_file_path):
        await handle_vault_unsealing(secrets_file_path)
    else:
        await handle_vault_initialization(secrets_file_path)

if __name__ == "__main__":
    asyncio.run(main())