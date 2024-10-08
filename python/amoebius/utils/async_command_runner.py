import asyncio
import json
import aiohttp
from typing import List, Dict, Any, Optional
from amoebius.utils.async_command_runner import run_command, CommandError

async def check_if_initialized(vault_url: str) -> Optional[bool]:
    """Check if the Vault server is initialized."""
    try:
        output = await run_command(['vault', 'status', '-address', vault_url], sensitive=True)
        return "true" in output.lower() if "Initialized" in output else None
    except CommandError:
        print("Error checking Vault status")
        return None

async def initialize_vault(vault_url: str, secret_shares: int, secret_threshold: int) -> Optional[Dict[str, Any]]:
    """Initialize the Vault server asynchronously."""
    try:
        command = [
            'vault', 'operator', 'init',
            '-address', vault_url,
            '-key-shares', str(secret_shares),
            '-key-threshold', str(secret_threshold),
            '-format', 'json'
        ]
        output = await run_command(command, sensitive=True)
        return json.loads(output) if output else None
    except CommandError:
        print("Error initializing Vault")
        return None

def parse_vault_output(vault_init_output: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Parse the Vault initialization output."""
    return {
        "unseal_keys": vault_init_output.get('unseal_keys_b64', []),
        "root_token": vault_init_output.get('root_token', '')
    } if vault_init_output else None

async def unseal_vault_pod(
    session: aiohttp.ClientSession, 
    pod: str, 
    key: str, 
    port: int = 8200, 
    unseal_url: str = '/v1/sys/unseal'
) -> None:
    """Send an unseal key to a single Vault pod asynchronously."""
    url = f'http://{pod}:{port}{unseal_url}'
    try:
        async with session.put(url, json={"key": key}) as response:
            print(f"{'Successfully unsealed' if response.status == 200 else 'Failed to unseal'} {pod}")
    except aiohttp.ClientError:
        print(f"Failed to connect to {pod}")

async def unseal_vault_pods_concurrently(vault_pods: List[str], unseal_keys: List[str]) -> None:
    """Unseal multiple Vault pods concurrently."""
    async with aiohttp.ClientSession() as session:
        tasks = [unseal_vault_pod(session, pod, key) for pod in vault_pods for key in unseal_keys]
        await asyncio.gather(*tasks)

def run_unseal_concurrently(vault_pods: List[str], unseal_keys: List[str]) -> None:
    """Run the unseal process for Vault pods concurrently using asyncio."""
    asyncio.run(unseal_vault_pods_concurrently(vault_pods, unseal_keys))

async def main_vault_workflow(vault_url: str, vault_pods: List[str], secret_shares: int, secret_threshold: int):
    """Main function demonstrating the initialization and unsealing of Vault pods."""
    is_initialized = await check_if_initialized(vault_url)
    
    if is_initialized is None:
        print("Error checking Vault status.")
        return

    if is_initialized:
        print("Vault is already initialized.")
        return

    print("Vault is not initialized. Initializing now...")
    init_output = await initialize_vault(vault_url, secret_shares, secret_threshold)
    
    if not init_output:
        print("Error initializing Vault.")
        return

    vault_secrets = parse_vault_output(init_output)
    if not vault_secrets:
        print("Error parsing Vault initialization output.")
        return

    print("Vault initialized successfully. Root token and unseal keys generated.")
    await unseal_vault_pods_concurrently(vault_pods, vault_secrets['unseal_keys'])

if __name__ == "__main__":
    VAULT_URL = "http://127.0.0.1:8200"
    VAULT_PODS = [
        "vault-0.vault.default.svc.cluster.local",
        "vault-1.vault.default.svc.cluster.local",
        "vault-2.vault.default.svc.cluster.local"
    ]
    SECRET_SHARES = 5
    SECRET_THRESHOLD = 3
    
    asyncio.run(main_vault_workflow(VAULT_URL, VAULT_PODS, SECRET_SHARES, SECRET_THRESHOLD))