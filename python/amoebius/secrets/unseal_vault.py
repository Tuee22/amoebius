import asyncio
import aiohttp
from typing import List

# Define the function to send an unseal key to a single Vault pod
async def unseal_vault_pod(
    session: aiohttp.ClientSession, 
    pod: str, 
    key: str, 
    port: int=8200,
    unseal_url: str='/v1/sys/unseal'    
) -> None:
    url = f'http://{pod}:{port}{unseal_url}'
    payload = {"key": key}
    async with session.put(url, json=payload) as response:
        if response.status == 200:
            print(f"Successfully sent unseal key to {pod}")
        else:
            print(f"Failed to unseal {pod}, status code: {response.status} test: {response.text}")

# Define the main unsealing function
async def unseal_vault_pods_concurrently(vault_pods: List[str], unseal_keys: List[str]) -> None:
    async with aiohttp.ClientSession() as session:
        tasks = []
        # For each pod, send all unseal keys
        for pod in vault_pods:
            for key in unseal_keys:
                tasks.append(unseal_vault_pod(session, pod, key))
        
        # Run all tasks concurrently
        await asyncio.gather(*tasks)

# Wrapper function to run asyncio event loop
def run_unseal_concurrently(vault_pods: List[str], unseal_keys: List[str]) -> None:
    asyncio.run(unseal_vault_pods_concurrently(vault_pods, unseal_keys))

# Example usage
if __name__ == "__main__":
    VAULT_PODS = ["vault-0.vault.default.svc.cluster.local", "vault-1.vault.default.svc.cluster.local", "vault-2.vault.default.svc.cluster.local"]
    UNSEAL_KEYS = ["unseal-key-1", "unseal-key-2", "unseal-key-3"]

    # Run the unsealing process concurrently
    run_unseal_concurrently(VAULT_PODS, UNSEAL_KEYS)
