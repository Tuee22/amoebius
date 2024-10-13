import json
import os
import getpass
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.backends import default_backend

# Function to serialize and encrypt the dictionary
def encrypt_dict(data: dict, password: str) -> bytes:
    # 1. Serialize the dictionary to a JSON string
    json_data = json.dumps(data).encode('utf-8')

    # 2. Derive an AES key from the password using a key derivation function (KDF)
    salt = os.urandom(16)  # Securely generate a random salt
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,  # AES-256 requires a 32-byte key
        salt=salt,
        iterations=100000,
        backend=default_backend()
    )
    key = kdf.derive(password.encode())

    # 3. Encrypt the serialized data using AES GCM mode (provides authentication and encryption)
    iv = os.urandom(12)  # Initialization vector for AES GCM
    aesgcm = AESGCM(key)
    encrypted_data = aesgcm.encrypt(iv, json_data, None)  # None is for associated data (optional)

    # 4. Return the encrypted data with the salt and iv (for decryption later)
    return salt + iv + encrypted_data

# Function to decrypt the data back into a dictionary
def decrypt_dict(encrypted_data: bytes, password: str) -> dict:
    # 1. Extract the salt, iv, and encrypted data from the input
    salt = encrypted_data[:16]
    iv = encrypted_data[16:28]
    ciphertext = encrypted_data[28:]

    # 2. Derive the same AES key from the password and salt
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
        backend=default_backend()
    )
    key = kdf.derive(password.encode())

    # 3. Decrypt the encrypted data
    aesgcm = AESGCM(key)
    decrypted_data = aesgcm.decrypt(iv, ciphertext, None)

    # 4. Deserialize the JSON string back into a Python dictionary
    return json.loads(decrypted_data.decode('utf-8'))

# Function to write encrypted data to a file
def encrypt_dict_to_file(data: dict, password: str, file_path: str) -> None:
    encrypted_data = encrypt_dict(data, password)
    with open(file_path, 'wb') as file:
        file.write(encrypted_data)

# Function to read encrypted data from a file and decrypt it
def decrypt_dict_from_file(password: str, file_path: str) -> dict:
    with open(file_path, 'rb') as file:
        encrypted_data = file.read()
    return decrypt_dict(encrypted_data, password)

# Function to get a password from the user interactively (without echoing it)
def get_password(prompt: str = "Enter password: ") -> str:
    return getpass.getpass(prompt)

def get_new_password():
    while True:
        password = get_password("Enter a new password to encrypt vault secrets: ")
        confirm_password = get_password("Confirm the password: ")
        if password == confirm_password:
            return password
        else:
            print("Passwords do not match. Please try again.")

# Example usage
if __name__ == "__main__":
    my_dict = {"username": "user1", "password": "my_secure_password"}
    password = get_password("Enter encryption password: ")

    # Encrypt and write to file
    encrypt_dict_to_file(my_dict, password, 'encrypted_data.bin')
    print("Data has been encrypted and written to file.")

    # Decrypt from file
    decrypted_dict = decrypt_dict_from_file(password, 'encrypted_data.bin')
    print("Decrypted data from file:", decrypted_dict)
