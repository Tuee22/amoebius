import asyncio
import json
import aiohttp
from typing import List, Dict, Any, Optional
from ..utils.async_command_runner import run_command, CommandError

async def check_if_initialized(vault_url: str) -> Optional[bool]:
    """Check if the Vault server is initialized.

    Args:
        vault_url (str): The URL of the Vault server.

    Returns:
        Optional[bool]: True if initialized, False if not, None if an error occurs.
    """
    try:
        output = await run_command(['vault', 'status', '-address', vault_url], sensitive=True)
        if "Initialized" in output:
            initialized_line = next((line for line in output.splitlines() if "Initialized" in line), "")
            return "true" in initialized_line.lower()
        else:
            print("Could not determine initialization status from output.")
            return None
    except CommandError:
        print("Error checking Vault status")
        return None

async def initialize_vault(
    vault: str,
    secret_shares: int,
    secret_threshold: int,
    port: int = 8200,
) -> Dict[str, Any]:
    """Initialize the Vault server asynchronously.

    Args:
        vault (str): The address of the Vault server.
        secret_shares (int): Number of key shares to create.
        secret_threshold (int): Number of key shares required to unseal.
        port (int, optional): Port on which Vault is running. Defaults to 8200.

    Returns:
        Dict[str, Any]: A dictionary containing the initialization data.

    Raises:
        CommandError: If the initialization command fails.
        json.JSONDecodeError: If the output cannot be parsed as JSON.
    """
    command = [
        'vault', 'operator', 'init',
        f'-key-shares={secret_shares}',
        f'-key-threshold={secret_threshold}',
        '-format=json'
    ]
    env = {'VAULT_ADDR': f'http://{vault}:{port}'}
    output = await run_command(command, env=env, sensitive=True)
    if output:
        return json.loads(output)
    else:
        raise CommandError("No output received from Vault initialization command.")

async def unseal_vault_pod(
    session: aiohttp.ClientSession,
    pod: str,
    key: str,
    port: int = 8200,
    unseal_url: str = '/v1/sys/unseal'
) -> None:
    """Send an unseal key to a single Vault pod asynchronously.

    Args:
        session (aiohttp.ClientSession): The HTTP session to use for the request.
        pod (str): The address of the Vault pod.
        key (str): The unseal key to use.
        port (int, optional): Port on which Vault is running. Defaults to 8200.
        unseal_url (str, optional): The API endpoint for unsealing. Defaults to '/v1/sys/unseal'.
    """
    url = f'http://{pod}:{port}{unseal_url}'
    try:
        async with session.put(url, json={"key": key}) as response:
            if response.status == 200:
                print(f"Successfully unsealed {pod}")
            else:
                response_text = await response.text()
                print(f"Failed to unseal {pod}: {response.status} - {response_text}")
    except aiohttp.ClientError as e:
        print(f"Failed to connect to {pod}: {str(e)}")

async def unseal_vault_pods_concurrently(vault_pods: List[str], unseal_keys: List[str]) -> None:
    """Unseal multiple Vault pods concurrently.

    Args:
        vault_pods (List[str]): A list of Vault pod addresses.
        unseal_keys (List[str]): A list of unseal keys to use.
    """
    async with aiohttp.ClientSession() as session:
        tasks = []
        for pod in vault_pods:
            for key in unseal_keys:
                tasks.append(unseal_vault_pod(session, pod, key))
        await asyncio.gather(*tasks)
