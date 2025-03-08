"""
amoebius/utils/k8s.py

Provides utilities to interact with Kubernetes objects via 'kubectl'.
"""

import json
from typing import Any, Dict, Set, Tuple

from amoebius.models.k8s import KubernetesServiceAccount
from amoebius.utils.async_command_runner import run_command, CommandError


async def get_service_accounts() -> Set[KubernetesServiceAccount]:
    """Retrieves all Kubernetes ServiceAccounts from the cluster via 'kubectl'.

    Returns:
        A set of KubernetesServiceAccount objects, each holding a namespace and name.

    Raises:
        CommandError: If 'kubectl' fails to run or returns a non-zero exit code.
    """

    def _extract_ns_name(item: Dict[str, Any]) -> Tuple[str, str]:
        """Return (namespace, name) from a single service account item."""
        meta = item.get("metadata", {})
        return meta.get("namespace", ""), meta.get("name", "")

    # Run 'kubectl' to retrieve SAs in JSON form
    cmd_sa = ["kubectl", "get", "serviceaccounts", "-A", "-o", "json"]
    raw_sa_json = await run_command(cmd_sa, retries=0, sensitive=False)
    parsed = json.loads(raw_sa_json)
    items = parsed.get("items", [])

    # Use a set comprehension, calling our helper to reduce .get() usage
    service_accounts = {
        KubernetesServiceAccount(namespace=ns, name=nm)
        for item in items
        for ns, nm in [_extract_ns_name(item)]
        if ns and nm
    }

    return service_accounts
