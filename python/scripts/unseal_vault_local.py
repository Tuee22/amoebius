import subprocess
import sys

# Install or upgrade pip, wheel, and setuptools
subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pip", "wheel", "setuptools"])

# Install or upgrade aiohttp and cryptography
subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "aiohttp", "cryptography"])

from amoebius.secrets.encrypted_dict import get_password, decrypt_dict_from_file
from amoebius.secrets import unseal_vault

def main():
    # Get user-supplied password
    password = get_password("Enter password to decrypt vault secrets: ")

    # Open and decrypt the vault_secrets.bin file
    try:
        secrets_dict = decrypt_dict_from_file(password, '/amoebius/data/vault_secrets.bin')
    except FileNotFoundError:
        print("Error: vault_secrets.bin file not found.")
        return
    except Exception as e:
        print(f"Error decrypting file: {str(e)}")
        return

    # Get the UNSEAL_KEY from the decrypted dictionary
    unseal_key = secrets_dict.get("UNSEAL_KEY")
    if not unseal_key:
        print("Error: UNSEAL_KEY not found in the decrypted secrets.")
        return

    # Define the Vault pod URL (using the default from the official Helm chart)
    vault_pod = "http://vault-0.vault.vault.svc.cluster.local:8200/"

    # Run the vault unseal function
    print(f"Unsealing Vault pod: {vault_pod}")
    unseal_vault.run_unseal_concurrently([vault_pod], [unseal_key])

if __name__ == "__main__":
    main()