import json
import os
from typing import Dict, Any, cast
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.backends import default_backend
from cryptography.exceptions import InvalidTag
from amoebius.models.validator import validate_type


def encrypt_dict(data: Dict[str, Any], password: str) -> bytes:
    """Serialize and encrypt a dictionary using AES-GCM after validation."""
    # Validate the data using Pydantic
    json_data = json.dumps(data)
    salt = os.urandom(16)
    key = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100_000,
        backend=default_backend(),
    ).derive(password.encode())
    iv = os.urandom(12)
    encrypted_data = AESGCM(key).encrypt(iv, json_data.encode(), None)
    return salt + iv + encrypted_data


def decrypt_dict(encrypted_data: bytes, password: str) -> Dict[str, Any]:
    """Decrypt and deserialize data into a dictionary using AES-GCM and validate with Pydantic.

    Raises:
        ValueError: If the password is incorrect or data is corrupted.
    """
    try:
        salt, iv, ciphertext = (
            encrypted_data[:16],
            encrypted_data[16:28],
            encrypted_data[28:],
        )
        key = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100_000,
            backend=default_backend(),
        ).derive(password.encode())
        decrypted_data = AESGCM(key).decrypt(iv, ciphertext, None)
        decrypted_dict = json.loads(decrypted_data.decode("utf-8"))
        return validate_type(decrypted_dict, Dict[str, Any])
    except InvalidTag:
        # This exception is raised if the password is incorrect or data is tampered with
        raise ValueError("Decryption failed: Incorrect password or corrupted data.")
    except (json.JSONDecodeError, TypeError) as e:
        # Handle JSON decoding errors or validation issues
        raise ValueError(f"Decryption failed: {str(e)}")


def encrypt_dict_to_file(data: Dict[str, Any], password: str, file_path: str) -> None:
    """Encrypt a dictionary and write it to a file."""
    dict_bytes = encrypt_dict(data, password)
    with open(file_path, "wb") as file:
        file.write(dict_bytes)


def decrypt_dict_from_file(password: str, file_path: str) -> Dict[str, Any]:
    """Read encrypted data from a file and decrypt it into a dictionary."""
    with open(file_path, "rb") as file:
        return decrypt_dict(file.read(), password)
