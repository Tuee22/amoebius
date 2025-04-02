"""
amoebius/utils/k8s.py

Provides utilities to interact with Kubernetes objects via 'kubectl', including
reading/writing secrets, listing service accounts, and running kubectl commands
either interactively or with captured output.

All code passes mypy --strict, with no for loops for side effects if possible,
and all imports are at the top of the module.
"""

from __future__ import annotations

import json
import base64
import os
import asyncio
import random
import shlex
from typing import Any, Dict, List, Optional, Set, Tuple

import aiofiles

from amoebius.utils.async_command_runner import (
    run_command,
    CommandError,
    run_command_interactive,
)
from amoebius.utils.ephemeral_file import ephemeral_manager
from amoebius.models.k8s import KubernetesServiceAccount
from amoebius.models.ssh import SSHConfig
from amoebius.models.validator import validate_type


async def get_service_accounts() -> Set[KubernetesServiceAccount]:
    """
    Retrieve all Kubernetes ServiceAccounts from the cluster via 'kubectl' (non-SSH).

    The output is converted to JSON and parsed. We then build each item into a
    KubernetesServiceAccount. The name is derived from metadata.name, the
    namespace from metadata.namespace.

    Returns:
        A set of KubernetesServiceAccount objects.

    Raises:
        CommandError: If 'kubectl' fails to run or returns a non-zero exit code.
    """
    cmd_sa = ["kubectl", "get", "serviceaccounts", "-A", "-o", "json"]
    raw_sa_json = await run_command(
        command=cmd_sa,
        retries=0,
        sensitive=False,
    )
    parsed = json.loads(raw_sa_json)
    items = parsed.get("items", [])

    def _extract_ns_name(item: Dict[str, Any]) -> Tuple[str, str]:
        """
        Return (namespace, name) from a single service account JSON item.
        """
        meta = item.get("metadata", {})
        return meta.get("namespace", ""), meta.get("name", "")

    return {
        KubernetesServiceAccount(namespace=ns, name=nm)
        for item in items
        for ns, nm in [_extract_ns_name(item)]
        if ns and nm
    }


async def get_k8s_secret_data(
    secret_name: str,
    namespace: str,
) -> Optional[Dict[str, str]]:
    """
    Retrieve the key-value data of a Kubernetes Secret (decoded from base64),
    by calling 'kubectl' (non-SSH).

    If the secret does not exist, we return None. Otherwise we parse the JSON
    to read each data field. The data values are base64-decoded prior to returning.

    Args:
        secret_name (str): The K8s Secret name.
        namespace (str):   The K8s namespace.

    Returns:
        A dict of key => plaintext value if found, else None if the Secret is missing.

    Raises:
        CommandError: If 'kubectl' fails for reasons other than 'NotFound'.
    """
    cmd = [
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
        raw_json = await run_command(command=cmd, retries=0, sensitive=False)
    except CommandError as ex:
        if "NotFound" in str(ex):
            return None
        raise

    secret_obj = json.loads(raw_json)
    b64_data = secret_obj.get("data", {})
    decoded_data = {
        key: base64.b64decode(val).decode("utf-8") for key, val in b64_data.items()
    }
    return decoded_data if decoded_data else None


async def put_k8s_secret_data(
    secret_name: str,
    namespace: str,
    data: Dict[str, str],
) -> None:
    """
    Create or update a Kubernetes Secret with the given key-value data, using
    'kubectl apply -f -'. The values are base64-encoded prior to writing.

    This is an idempotent approach: if the Secret does not exist, it is created;
    if it does exist, its data is updated.

    Args:
        secret_name (str): The name of the Kubernetes Secret.
        namespace (str):   The K8s namespace.
        data (Dict[str, str]): Plaintext key-value pairs to store in the Secret.

    Raises:
        CommandError: If 'kubectl apply' fails or returns a non-zero exit code.
    """
    b64_data = {
        k: base64.b64encode(v.encode("utf-8")).decode("utf-8") for k, v in data.items()
    }
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
    await run_command(command=cmd_apply, retries=0, input_data=manifest_json)


async def run_kubectl_command(
    ssh_config_list: List[SSHConfig],
    user_cmd: List[str],
    randomize: bool = True,
    interactive: bool = False,
) -> int:
    """
    Run a user-provided "kubectl" command on one of the given SSH configs (e.g. for an RKE2 control plane).
    If randomize=True, pick a random node from ssh_config_list; else pick the first.

    If interactive=True, we run the command in interactive mode (tie local stdin/stdout/tty).
    If interactive=False, we run in normal captured mode, returning the exit code.

    Args:
        ssh_config_list (List[SSHConfig]):
            The SSH configs for control plane nodes, each with host_keys, private_key, etc.
        user_cmd (List[str]):
            The raw kubectl command tokens the user typed (e.g. ["exec", "-it", "my-pod", "--", "bash"]).
        randomize (bool):
            If True, pick a random node from the list. If False, pick the first.
        interactive (bool):
            If True, run the command in interactive mode with run_command_interactive.

    Returns:
        int: The final exit code (0 for success, nonzero for fail).

    Raises:
        CommandError: If SSH or local command fails. (In practice, we try to catch
                      and return a code, but might raise if something is severely off.)
    """
    if not ssh_config_list:
        raise ValueError("No SSH configs provided for control plane nodes.")

    chosen = random.choice(ssh_config_list) if randomize else ssh_config_list[0]
    if not chosen.host_keys:
        raise CommandError("Cannot run kubectl: chosen CP node has empty host_keys.")

    # Build the user's kubectl command => single string
    remote_str = " ".join(shlex.quote(x) for x in (["kubectl"] + user_cmd))

    async with ephemeral_manager(
        single_file_name="ssh_known_hosts", prefix="sshkh-"
    ) as kh_path_union:
        kh_path = validate_type(kh_path_union, str)
        async with ephemeral_manager(
            single_file_name="ssh_idkey", prefix="sshpk-"
        ) as pk_path_union:
            pk_path = validate_type(pk_path_union, str)

            # Write known_hosts
            # For typed context, use "aiofiles.open(...)"
            async with aiofiles.open(kh_path, mode="w", encoding="utf-8") as f_know:
                for line in chosen.host_keys:
                    await f_know.write(line + "\n")

            # Write private key
            async with aiofiles.open(pk_path, mode="wb") as f_key:
                await f_key.write(chosen.private_key.encode("utf-8"))

            os.chmod(pk_path, 0o600)

            ssh_cmd = [
                "ssh",
                "-p",
                str(chosen.port),
                "-i",
                pk_path,
                "-o",
                "BatchMode=yes",
                "-o",
                "StrictHostKeyChecking=yes",
                "-o",
                f"UserKnownHostsFile={kh_path}",
                "-o",
                "GlobalKnownHostsFile=/dev/null",
                f"{chosen.user}@{chosen.hostname}",
                remote_str,
            ]
            if interactive:
                code = await run_command_interactive(command=ssh_cmd)
                return code
            else:
                # normal, captured
                try:
                    await run_command(command=ssh_cmd, retries=0)
                    return 0
                except CommandError as ex:
                    if ex.return_code is not None:
                        return ex.return_code
                    return 1
