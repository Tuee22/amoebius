"""
amoebius/utils/k8s.py

Provides utilities to interact with Kubernetes objects via 'kubectl'.
"""

import json
from typing import Set

from amoebius.models.k8s import KubernetesServiceAccount
from amoebius.utils.async_command_runner import run_command, CommandError


async def get_service_accounts() -> Set[KubernetesServiceAccount]:
    """Retrieves all Kubernetes ServiceAccounts from the cluster via 'kubectl'.

    Returns:
        Set[KubernetesServiceAccount]: A set of namespace+name pairs for each ServiceAccount.

    Raises:
        CommandError: If 'kubectl' fails to run or returns a non-zero exit code.
    """
    cmd_sa = ["kubectl", "get", "serviceaccounts", "-A", "-o", "json"]
    # If 'kubectl' fails, CommandError is raised automatically by run_command.
    raw_sa_json = await run_command(cmd_sa, retries=0, sensitive=False)
    parsed = json.loads(raw_sa_json)

    found_sas: Set[KubernetesServiceAccount] = set()
    for item in parsed.get("items", []):
        ns = item.get("metadata", {}).get("namespace", "")
        nm = item.get("metadata", {}).get("name", "")
        if ns and nm:
            found_sas.add(KubernetesServiceAccount(namespace=ns, name=nm))

    return found_sas
