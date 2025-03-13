"""
Provides utilities to interact with Kubernetes objects via 'kubectl',
including reading/writing secrets.
"""

import json
import base64
from typing import Any, Dict, Optional, Set, Tuple

from amoebius.models.k8s import KubernetesServiceAccount
from amoebius.utils.async_command_runner import run_command, CommandError


async def get_service_accounts() -> Set[KubernetesServiceAccount]:
    """Retrieves all Kubernetes ServiceAccounts from the cluster via 'kubectl'.

    Returns:
        Set[KubernetesServiceAccount]: A set of KubernetesServiceAccount objects,
            each holding a namespace and name.

    Raises:
        CommandError: If 'kubectl' fails to run or returns a non-zero exit code.
    """

    def _extract_ns_name(item: Dict[str, Any]) -> Tuple[str, str]:
        """Return (namespace, name) from a single service account item.

        Args:
            item (Dict[str, Any]): A service account JSON item from kubectl output.

        Returns:
            Tuple[str, str]: The (namespace, name).
        """
        meta = item.get("metadata", {})
        return meta.get("namespace", ""), meta.get("name", "")

    cmd_sa = ["kubectl", "get", "serviceaccounts", "-A", "-o", "json"]
    raw_sa_json = await run_command(cmd_sa, retries=0, sensitive=False)
    parsed = json.loads(raw_sa_json)
    items = parsed.get("items", [])

    service_accounts = {
        KubernetesServiceAccount(namespace=ns, name=nm)
        for item in items
        for ns, nm in [_extract_ns_name(item)]
        if ns and nm
    }

    return service_accounts


async def get_k8s_secret_data(
    secret_name: str, namespace: str
) -> Optional[Dict[str, str]]:
    """Retrieve the data fields of a K8s secret, decoding from base64.

    Args:
        secret_name (str): The name of the Kubernetes Secret.
        namespace (str): The namespace in which the Secret resides.

    Returns:
        Optional[Dict[str, str]]: A dict of key->value (decoded from base64) if found,
            or None if the Secret does not exist.

    Raises:
        CommandError: If the kubectl command fails for reasons other than 'NotFound'.
    """
    cmd_get = [
        "kubectl",
        "-n",
        namespace,
        "get",
        "secret",
        secret_name,
        "-o",
        "json",
    ]
    try:
        raw_json = await run_command(cmd_get, retries=0, sensitive=False)
    except CommandError as ex:
        # If it's a "NotFound" error, we consider that as returning None.
        if "NotFound" in str(ex):
            return None
        raise

    secret_obj = json.loads(raw_json)
    b64_data = secret_obj.get("data", {})
    decoded_data: Dict[str, str] = {}
    for key, b64_val in b64_data.items():
        # Safely decode each item
        decoded_data[key] = base64.b64decode(b64_val).decode("utf-8")

    return decoded_data if decoded_data else None


async def put_k8s_secret_data(
    secret_name: str,
    namespace: str,
    data: Dict[str, str],
) -> None:
    """Create or update a K8s secret with the given data as base64-encoded strings.

    Uses 'kubectl apply -f -' to apply a generated JSON manifest to the cluster.

    Args:
        secret_name (str): The name of the Kubernetes Secret.
        namespace (str): The namespace in which to create or update the Secret.
        data (Dict[str, str]): A dict of key->plaintext_value to store (base64-encoded).

    Raises:
        CommandError: If 'kubectl apply' fails.
    """
    # Convert each data value to base64
    b64_data: Dict[str, str] = {}
    for key, val in data.items():
        b64_data[key] = base64.b64encode(val.encode("utf-8")).decode("utf-8")

    # Build a minimal Secret manifest
    manifest = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": secret_name,
            "namespace": namespace,
        },
        "type": "Opaque",
        "data": b64_data,
    }

    manifest_json = json.dumps(manifest, indent=2)
    cmd_apply = ["kubectl", "apply", "-f", "-"]

    # Use input_data (NOT stdin_data) for run_command
    await run_command(cmd_apply, retries=0, sensitive=False, input_data=manifest_json)
