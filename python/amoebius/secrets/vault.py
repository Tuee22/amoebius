import asyncio
import json
import aiohttp
from typing import List, Dict, Any, Optional
from ..utils.async_command_runner import run_command, CommandError

async def check_if_initialized(vault_url: str) -> Optional[bool]:
    """Check if the Vault server is initialized."""
    try:
        output = await run_command(['vault', 'status', '-address', vault_url], sensitive=True)
        return "true" in output.lower() if "Initialized" in output else None
    except CommandError:
        print("Error checking Vault status")
        return None

async def initialize_vault(
    vault: str,
    secret_shares: int,
    secret_threshold: int,
    port: int = 8200,
) -> Optional[Dict[str, Any]]:
    """Initialize the Vault server asynchronously."""
    try:
        command = [
            'vault', 'operator', 'init',
            f'-key-shares={str(secret_shares)}',
            f'-key-threshold={str(secret_threshold)}',
            '-format=json'
        ]
        env={'VAULT_ADDR':f'http://{vault}:{port}'}
        output = await run_command(command, env=env, sensitive=True)
        return json.loads(output) if output else None
    except CommandError:
        print("Error initializing Vault")
        return None

async def unseal_vault_pod(
    session: aiohttp.ClientSession, 
    pod: str, 
    key: str, 
    port: int = 8200, 
    unseal_url: str = '/v1/sys/unseal'
) -> None:
    """Send an unseal key to a single Vault pod asynchronously."""
    url = f'http://{pod}:{port}{unseal_url}'
    print('unseal command',url)
    try:
        async with session.put(url, json={"key": key}) as response:
            print(f"{'Successfully unsealed' if response.status == 200 else 'Failed to unseal'} {pod}")
    except aiohttp.ClientError:
        print(f"Failed to connect to {pod}")

async def unseal_vault_pods_concurrently(vault_pods: List[str] | str, unseal_keys: List[str]) -> None:
    """Unseal multiple Vault pods concurrently."""
    vault_pods_list = [vault_pods] if isinstance(vault_pods,str) else vault_pods
    async with aiohttp.ClientSession() as session:
        tasks = [
            unseal_vault_pod(session, pod, key)
            for pod in vault_pods_list
            for key in unseal_keys
        ]
        await asyncio.gather(*tasks)