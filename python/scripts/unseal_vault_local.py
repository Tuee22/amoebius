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
from amoebius.secrets.terraform import get_terraform_output
from amoebius.utils.async_command_runner import CommandError
from typing import List, Callable

def get_int_input(prompt, min_value=1):
    def helper():
        try:
            value = int(input(prompt))
            return value if value >= min_value else (
                print(f"Please enter a value of at least {min_value}."),
                helper(),
            )[1]
        except ValueError:
            print("Please enter a valid integer.")
            return helper()

    return helper()

async def handle_vault_initialization(secrets_file_path):
    password = get_new_password()
    secret_shares = get_int_input("Enter the number of key shares to create: ", 1)
    secret_threshold = get_int_input(
        f"Enter the number of shares required to reconstruct the master key (1-{secret_shares}): ",
        1,
    )

    def validate_threshold(threshold: int, secret_shares: int, get_input: Callable[[str, int], int]) -> int:
        if threshold <= secret_shares:
            return threshold
        else:
            new_threshold = get_input(
                f"Error: Threshold cannot be greater than the number of shares.\n"
                f"Enter the number of shares required to reconstruct the master key (1-{secret_shares}): ",
                1
            )
            return validate_threshold(new_threshold, secret_shares, get_input)

    secret_threshold = validate_threshold(secret_threshold, secret_shares, get_int_input)
    terraform_dir = "/amoebius/terraform/roots/kind"
    output_name = "vault_raft_pod_dns_names"
    local_vault_hosts: List[str] = get_terraform_output(terraform_dir, output_name)

    try:
        secrets_dict = await initialize_vault(
            local_vault_hosts[0], secret_shares, secret_threshold
        )
        unseal_keys = secrets_dict["unseal_keys_b64"]
        await unseal_vault_pods_concurrently(
            local_vault_hosts[:1], random.sample(unseal_keys, secret_threshold)
        )
        await asyncio.sleep(3)
        await unseal_vault_pods_concurrently(
            local_vault_hosts[1:], random.sample(unseal_keys, secret_threshold)
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

async def handle_vault_unsealing(secrets_file_path):
    password = get_password("Enter password to decrypt vault secrets: ")
    try:
        secrets_dict = decrypt_dict_from_file(password, secrets_file_path)
    except Exception as e:
        print(f"Error decrypting file: {str(e)}")
        sys.exit(1)

    unseal_keys = secrets_dict.get("unseal_keys_b64")
    secret_threshold = secrets_dict.get("unseal_threshold")

    if not unseal_keys or not secret_threshold:
        print(
            "Error: UNSEAL_KEYS or SECRET_THRESHOLD not found in the decrypted secrets."
        )
        sys.exit(1)

    terraform_dir = "/amoebius/terraform/roots/kind"
    output_name = "vault_raft_pod_dns_names"
    local_vault_hosts: List[str] = get_terraform_output(terraform_dir, output_name)
    print(f"Unsealing Vault pods: {local_vault_hosts}")
    print(f"Using {secret_threshold} out of {len(unseal_keys)} unseal keys.")

    try:
        await unseal_vault_pods_concurrently(
            local_vault_hosts, random.sample(unseal_keys, secret_threshold)
        )
    except Exception as e:
        print(f"Error during vault unsealing: {str(e)}")
        sys.exit(1)

async def main():
    secrets_file_path = "/amoebius/data/vault_secrets.bin"
    await (
        handle_vault_unsealing
        if os.path.exists(secrets_file_path)
        else handle_vault_initialization
    )(secrets_file_path)

if __name__ == "__main__":
    asyncio.run(main())
