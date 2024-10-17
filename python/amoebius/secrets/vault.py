import asyncio
import json
import aiohttp
from typing import List, Dict, Any, Optional, Tuple
from ..utils.async_command_runner import run_command, CommandError

async def check_if_initialized(vault_url: str) -> Optional[bool]:
    """Check if the Vault server is initialized."""
    try:
        output = await run_command(['vault', 'status', '-address', vault_url], sensitive=True)
        initialized_line = next((line for line in output.splitlines() if "Initialized" in line), "")
        return "true" in initialized_line.lower() if initialized_line else None
    except CommandError:
        return None

async def initialize_vault(
    vault: str,
    secret_shares: int,
    secret_threshold: int,
    port: int = 8200,
) -> Dict[str, Any]:
    """Initialize the Vault server asynchronously."""
    command = [
        'vault', 'operator', 'init',
        f'-key-shares={secret_shares}',
        f'-key-threshold={secret_threshold}',
        '-format=json'
    ]
    env = {'VAULT_ADDR': f'http://{vault}:{port}'}
    output = await run_command(command, env=env, sensitive=True)
    return json.loads(output) if output else {}

async def unseal_vault_pod(
    session: aiohttp.ClientSession,
    pod: str,
    key: str,
    port: int = 8200,
    unseal_url: str = '/v1/sys/unseal'
) -> Tuple[str, bool]:
    """Send an unseal key to a single Vault pod asynchronously."""
    url = f'http://{pod}:{port}{unseal_url}'
    try:
        async with session.put(url, json={"key": key}) as response:
            success = response.status == 200
            return (pod, success)
    except aiohttp.ClientError:
        return (pod, False)

async def unseal_vault_pods_concurrently(
    vault_pods: List[str],
    unseal_keys: List[str]
) -> List[Tuple[str, bool]]:
    """Unseal multiple Vault pods concurrently and return their statuses."""
    async with aiohttp.ClientSession() as session:
        tasks = [
            unseal_vault_pod(session, pod, key)
            for pod in vault_pods
            for key in unseal_keys
        ]
        return await asyncio.gather(*tasks)
