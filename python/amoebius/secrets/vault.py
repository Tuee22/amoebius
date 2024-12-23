import asyncio
import os
import json
import base64
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


async def is_vault_initialized(vault_addr: str) -> bool:
    """Check if Vault is initialized by running `vault status -format=json`.

    Args:
        vault_addr: The Vault server address.

    Returns:
        True if Vault is initialized, False otherwise.

    Raises:
        CommandError: If the `vault status` command fails unexpectedly.
    """
    try:
        env = {"VAULT_ADDR": vault_addr}
        out = await run_command(
            ["vault", "status", "-format=json"],
            sensitive=False,
            env=env,
            successful_return_codes=[0, 1, 2],
        )
        status = json.loads(out)["initialized"]
        return validate_type(status, bool)
    except CommandError as e:
        raise CommandError(
            "Failed to determine Vault initialization status", e.return_code
        )


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


async def get_vault_pods(namespace: str) -> List[str]:
    """Retrieve the names of Vault pods in the given namespace.

    Args:
        namespace: Kubernetes namespace where Vault is deployed.

    Returns:
        List[str]: List of Vault pod names.
    """
    pods_output = await run_command(
        [
            "kubectl",
            "get",
            "pods",
            "-l",
            "app.kubernetes.io/name=vault",
            "-n",
            namespace,
            "-o",
            "jsonpath={.items[*].metadata.name}",
        ]
    )
    return pods_output.strip().split()


async def unseal_vault_pods(
    pod_names: List[str], vault_init_data: VaultInitData
) -> None:
    """Unseal all Vault pods using unseal keys.

    Args:
        pod_names: list of DNS names for pods
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
    terraform_state: TerraformState,
) -> None:
    """Configure Vault for Kubernetes authentication and sidecar injection.

    Args:
        vault_init_data: Vault init secrets
        terraform_state: Terraform state containing deployment details for Vault and Kubernetes.
    """
    vault_sa_name = get_output_from_state(
        terraform_state, "vault_service_account_name", str
    )
    vault_service_name = get_output_from_state(
        terraform_state, "vault_service_name", str
    )
    vault_sa_namespace = get_output_from_state(terraform_state, "vault_namespace", str)
    vault_common_name = get_output_from_state(terraform_state, "vault_common_name", str)
    vault_cluster_role = get_output_from_state(
        terraform_state, "vault_cluster_role", str
    )
    vault_secret_path = get_output_from_state(terraform_state, "vault_secret_path", str)
    kubernetes_host = "https://kubernetes.default.svc:6443"
    env = {"VAULT_ADDR": vault_common_name, "VAULT_TOKEN": vault_init_data.root_token}

    print("Checking if Kubernetes authentication is already enabled in Vault...")
    auth_methods_output = await run_command(
        ["vault", "auth", "list", "-format=json"], env=env
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
            "--duration=600s",
            "-n",
            vault_sa_namespace,
        ]
    )
    # get root CA cert
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

    print("Configured Kubernetes auth method in Vault.")

    print("\n=== Creating Vault Policy ===")
    # Define Vault policy
    vault_policy_name = f"{vault_service_name}-policy"
    vault_policy = f"""
    path "{vault_secret_path}/*" {{
        capabilities = ["read"]
    }}
    """

    # Write the Vault policy
    await run_command(
        ["vault", "policy", "write", vault_policy_name, "-"],
        env=env,
        input_data=vault_policy,
    )
    print(f"Created Vault policy '{vault_policy_name}'.")

    print("\n=== Creating Vault Role ===")
    # Define Vault role
    vault_role = f"{vault_service_name}-role"

    # Write the Vault role configuration
    await run_command(
        [
            "vault",
            "write",
            f"auth/kubernetes/role/{vault_role}",
            f"bound_service_account_names={vault_sa_name}",
            f"bound_service_account_namespaces={vault_sa_namespace}",
            f"policies={vault_policy_name}",
            "ttl=24h",
        ],
        env=env,
        input_data=None,
    )
    print(f"Created Vault role '{vault_role}'.")

    print(
        "\n=== Vault Kubernetes Authentication Configuration Completed Successfully ==="
    )


async def init_unseal_configure_vault(
    default_shamir_shares: int = 5, default_shamir_threshold: int = 3
) -> None:
    """Initialize, unseal, and configure Vault for Kubernetes integration."""
    terraform_state = await read_terraform_state(root_name="vault")

    # Retrieve values from Terraform outputs
    vault_namespace = get_output_from_state(terraform_state, "vault_namespace", str)
    vault_raft_pod_dns_names = get_output_from_state(
        terraform_state, "vault_raft_pod_dns_names", List[str]
    )
    vault_init_addr = vault_raft_pod_dns_names[0]
    secrets_file_path = "/amoebius/data/vault_secrets.bin"

    async def get_initialized_secrets_from_file() -> VaultInitData:
        """Retrieve secrets from an encrypted file."""
        password = getpass("Enter the password to decrypt Vault secrets: ")
        decrypted_data = decrypt_dict_from_file(
            password=password, file_path=secrets_file_path
        )
        return VaultInitData.model_validate(decrypted_data)

    async def initialize_vault_and_save_secrets() -> VaultInitData:
        """Initialize Vault and save secrets to an encrypted file."""
        if os.path.exists(secrets_file_path):
            raise FileExistsError(
                f"Secrets file already exists at {secrets_file_path}."
            )

        password = getpass("Enter a password to encrypt Vault secrets: ")
        confirm_password = getpass("Confirm the password: ")
        if password != confirm_password:
            raise ValueError("Passwords do not match. Aborting initialization.")

        vault_init_data = await initialize_vault(
            vault_addr=vault_init_addr,
            num_shares=default_shamir_shares,
            threshold=default_shamir_threshold,
        )
        encrypt_dict_to_file(
            data=vault_init_data.model_dump(),
            password=password,
            file_path=secrets_file_path,
        )
        return VaultInitData.model_validate(vault_init_data)

    # Check if Vault is already initialized
    is_initialized = await is_vault_initialized(vault_addr=vault_init_addr)
    vault_init_data_getter = (
        get_initialized_secrets_from_file
        if is_initialized
        else initialize_vault_and_save_secrets
    )
    vault_init_data: VaultInitData = await vault_init_data_getter()

    # Unseal Vault pods
    await unseal_vault_pods(
        pod_names=vault_raft_pod_dns_names, vault_init_data=vault_init_data
    )

    # Configure Vault for Kubernetes integration
    await configure_vault_kubernetes_for_k8s_auth_and_sidecar(
        vault_init_data, terraform_state
    )


if __name__ == "__main__":
    asyncio.run(init_unseal_configure_vault())
