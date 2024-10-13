#!/usr/bin/env python
from amoebius.secrets.encrypted_dict import get_password, get_new_password, decrypt_dict_from_file, encrypt_dict_to_file
from amoebius.secrets.vault import unseal_vault_pods_concurrently, initialize_vault
from amoebius.secrets.terraform import get_terraform_output
import asyncio
import os

def get_int_input(prompt, min_value=1):
    while True:
        try:
            value = int(input(prompt))
            if value < min_value:
                print(f"Please enter a value of at least {min_value}.")
            else:
                return value
        except ValueError:
            print("Please enter a valid integer.")

def main():
    # Define the path for vault_secrets.bin
    secrets_file_path = '/amoebius/data/vault_secrets.bin'

    # Check if the vault_secrets.bin file exists
    if not os.path.exists(secrets_file_path):
        print("vault_secrets.bin not found. Initializing new vault...")
        
        # Get new password with confirmation
        password = get_new_password()
        
        # Get secret shares and threshold from user
        secret_shares = get_int_input("Enter the number of key shares to create: ", 1)
        secret_threshold = get_int_input(f"Enter the number of shares required to reconstruct the master key (1-{secret_shares}): ", 1)
        
        while secret_threshold > secret_shares:
            print("Error: Threshold cannot be greater than the number of shares.")
            secret_threshold = get_int_input(f"Enter the number of shares required to reconstruct the master key (1-{secret_shares}): ", 1)

        # Define the Vault pod URL (using the default from the official Helm chart)
        terraform_dir = '/amoebius/terraform/roots/kind'
        output_name = 'vault_raft_pod_dns_names'
        local_vault_hosts = get_terraform_output(terraform_dir, output_name)

        # Initialize the vault with custom shares and threshold
        root_token, unseal_keys = asyncio.run(initialize_vault(local_vault_hosts[0], secret_shares, secret_threshold))

        # Create a dictionary with the initialization data
        secrets_dict = {
            "ROOT_TOKEN": root_token,
            "UNSEAL_KEYS": unseal_keys,
            "SECRET_SHARES": secret_shares,
            "SECRET_THRESHOLD": secret_threshold
        }

        # Encrypt and save the secrets
        encrypt_dict_to_file(secrets_dict, password, secrets_file_path)
        print("Vault initialized and secrets saved.")
        print(f"IMPORTANT: {len(unseal_keys)} unseal keys have been generated.")
        print(f"You will need at least {secret_threshold} of these keys to unseal the vault.")
        print("Make sure to securely back up these keys separately.")
    else:
        # Get user-supplied password for existing vault
        password = get_password("Enter password to decrypt vault secrets: ")

        # Open and decrypt the vault_secrets.bin file
        try:
            secrets_dict = decrypt_dict_from_file(password, secrets_file_path)
        except Exception as e:
            print(f"Error decrypting file: {str(e)}")
            return

    # Get the UNSEAL_KEYS and threshold from the decrypted dictionary
    unseal_keys = secrets_dict.get("UNSEAL_KEYS")
    secret_threshold = secrets_dict.get("SECRET_THRESHOLD")
    if not unseal_keys or not secret_threshold:
        print("Error: UNSEAL_KEYS or SECRET_THRESHOLD not found in the decrypted secrets.")
        return

    # Define the Vault pod URL (using the default from the official Helm chart)
    terraform_dir = '/amoebius/terraform/roots/kind'
    output_name = 'vault_raft_pod_dns_names'
    local_vault_hosts = get_terraform_output(terraform_dir, output_name)

    # Run the vault unseal function
    print(f"Unsealing Vault pods: {local_vault_hosts}")
    print(f"Using {secret_threshold} out of {len(unseal_keys)} unseal keys.")
    asyncio.run(unseal_vault_pods_concurrently(local_vault_hosts, unseal_keys[:secret_threshold]))

if __name__ == "__main__":
    main()