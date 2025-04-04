"""
amoebius/utils/ssh.py

Provides high-level functions for SSH-related operations, leveraging ephemeral
known_hosts and private keys stored in /dev/shm. This includes:
  - ssh_get_server_key: minimal handshake to retrieve server host key (TOFU).
  - run_ssh_command: strict host-key-checking SSH (expects host_keys in SSHConfig).
  - run_kubectl: local 'kubectl exec' command.
  - run_ssh_kubectl_command: remote 'kubectl exec' via SSH in strict mode.
  - ssh_interactive_shell: an interactive shell session with strict host-key-checking.

We allow specifying 'successful_return_codes' for run_ssh_command in case you need
to accept non-zero codes as successes (e.g., disconnection codes on reboot).
"""

from __future__ import annotations

import asyncio
import os
import shlex
import aiofiles
import aiofiles.ospath
from pathlib import Path
from typing import Dict, List, Optional

from amoebius.models.k8s import KubectlCommand
from amoebius.models.ssh import SSHConfig
from amoebius.models.validator import validate_type
from amoebius.utils.async_command_runner import (
    run_command,
    run_command_interactive,
    CommandError,
)
from amoebius.utils.ephemeral_file import ephemeral_manager


async def ssh_get_server_key(
    cfg: SSHConfig,
    *,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> List[str]:
    """
    Perform a minimal SSH handshake with StrictHostKeyChecking=accept-new
    to retrieve the server's host key lines (TOFU).

    Args:
      cfg: SSHConfig with user, hostname, port, private_key.
      retries: times to retry if error
      retry_delay: seconds between retries

    Returns:
      A list of lines from ephemeral known_hosts (the server's keys).

    Raises:
      CommandError: if handshake fails or no host keys found
    """
    async with ephemeral_manager(
        single_file_name="ssh_known_hosts", prefix="sshkh-"
    ) as kh_path_union:
        kh_path = validate_type(kh_path_union, str)

        async with ephemeral_manager(
            single_file_name="ssh_idkey", prefix="sshpk-"
        ) as pk_path_union:
            pk_path = validate_type(pk_path_union, str)

            # Write private key
            async with aiofiles.open(pk_path, "wb") as fpk:
                await fpk.write(cfg.private_key.encode("utf-8"))
            os.chmod(pk_path, 0o600)

            ssh_cmd = [
                "ssh",
                "-p",
                str(cfg.port),
                "-i",
                pk_path,
                "-o",
                "BatchMode=yes",
                "-o",
                "StrictHostKeyChecking=accept-new",
                "-o",
                f"UserKnownHostsFile={kh_path}",
                "-o",
                "GlobalKnownHostsFile=/dev/null",
                f"{cfg.user}@{cfg.hostname}",
                "exit",
                "0",
            ]
            await run_command(
                ssh_cmd,
                retries=retries,
                retry_delay=retry_delay,
            )

            lines: List[str] = []
            if await aiofiles.ospath.exists(kh_path):
                async with aiofiles.open(kh_path, "r", encoding="utf-8") as fkh:
                    content = await fkh.readlines()
                    lines = [ln.strip() for ln in content if ln.strip()]

            if not lines:
                raise CommandError(
                    "ssh_get_server_key found no lines; server key not retrieved."
                )

            return lines


async def run_ssh_command(
    ssh_config: SSHConfig,
    remote_command: List[str],
    *,
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    retries: int = 3,
    retry_delay: float = 1.0,
    successful_return_codes: Optional[List[int]] = None,
) -> str:
    """
    Run an SSH command in strict host-key-checking mode, requiring host_keys in ssh_config.

    Args:
      ssh_config: Must have user, hostname, port, private_key, host_keys
      remote_command: The actual remote command tokens
      sensitive: If True, hides details on error
      env: optional environment variables
      retries: how many times to retry
      retry_delay: seconds between retries
      successful_return_codes: Additional exit codes considered "non-error."

    Returns:
      captured stdout from the remote command

    Raises:
      CommandError: if host_keys empty or the command fails (unless the code
                    is in `successful_return_codes`).
    """
    if not ssh_config.host_keys:
        raise CommandError("run_ssh_command requires non-empty host_keys.")

    async with ephemeral_manager(
        single_file_name="ssh_known_hosts", prefix="sshkh-"
    ) as kh_path_union:
        kh_path = validate_type(kh_path_union, str)

        async with ephemeral_manager(
            single_file_name="ssh_idkey", prefix="sshpk-"
        ) as pk_path_union:
            pk_path = validate_type(pk_path_union, str)

            # Write known_hosts
            async with aiofiles.open(kh_path, "w", encoding="utf-8") as fkh:
                for line in ssh_config.host_keys:
                    await fkh.write(line + "\n")

            # Write private key
            async with aiofiles.open(pk_path, "wb") as fpk:
                await fpk.write(ssh_config.private_key.encode("utf-8"))
            os.chmod(pk_path, 0o600)

            # Build the ssh command
            ssh_cmd = [
                "ssh",
                "-p",
                str(ssh_config.port),
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
                f"{ssh_config.user}@{ssh_config.hostname}",
            ]
            if env:
                env_tokens = ["env"] + [f"{k}={v}" for k, v in env.items()]
                remote_command = env_tokens + remote_command

            cmd_str = " ".join(shlex.quote(x) for x in remote_command)
            ssh_cmd.append(cmd_str)

            # If user didn't specify, default to [0]
            if successful_return_codes is None:
                successful_return_codes = [0]

            return await run_command(
                ssh_cmd,
                sensitive=sensitive,
                retries=retries,
                retry_delay=retry_delay,
                successful_return_codes=successful_return_codes,
            )


async def run_kubectl(
    kube_cmd: KubectlCommand,
    *,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Execute a local "kubectl exec" command. This is purely local, with no SSH.
    """
    args = kube_cmd.build_kubectl_args()
    return await run_command(
        args,
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )


async def run_ssh_kubectl_command(
    ssh_config: SSHConfig,
    kube_cmd: KubectlCommand,
    *,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Run a 'kubectl exec' command on a remote host via SSH in strict mode.

    Args:
      ssh_config: Must have user, host_keys
      kube_cmd: The KubectlCommand from amoebius.models.k8s
    """
    if not ssh_config.host_keys:
        raise CommandError("run_ssh_kubectl_command requires non-empty host_keys.")

    remote_args = kube_cmd.build_kubectl_args()
    return await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=remote_args,
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )


async def ssh_interactive_shell(
    ssh_config: SSHConfig,
) -> int:
    """
    Open an interactive SSH shell session with the remote host, using strict host key checking.

    This function uses ephemeral known_hosts and the ephemeral private key in /dev/shm,
    then invokes an interactive subprocess with 'ssh -t'.

    Args:
        ssh_config: Must have user, hostname, port, private_key, host_keys.

    Returns:
        The numeric exit code from the SSH session (e.g. 0 if clean exit).

    Raises:
        CommandError: If host_keys is empty or if we fail to launch the SSH session at all.
                      (Once the interactive session starts, the user is interacting directly,
                      so any remote command errors won't be thrown as CommandError.)
    """
    if not ssh_config.host_keys:
        raise CommandError("ssh_interactive_shell requires non-empty host_keys.")

    async with ephemeral_manager(
        single_file_name="ssh_known_hosts", prefix="sshkh-"
    ) as kh_path_union:
        kh_path = validate_type(kh_path_union, str)

        async with ephemeral_manager(
            single_file_name="ssh_idkey", prefix="sshpk-"
        ) as pk_path_union:
            pk_path = validate_type(pk_path_union, str)

            # Write known_hosts lines
            async with aiofiles.open(kh_path, "w", encoding="utf-8") as fkh:
                for line in ssh_config.host_keys:
                    await fkh.write(line + "\n")

            # Write private key
            async with aiofiles.open(pk_path, "wb") as fpk:
                await fpk.write(ssh_config.private_key.encode("utf-8"))
            os.chmod(pk_path, 0o600)

            # Build an SSH command that allocates a TTY (-t)
            ssh_cmd = [
                "ssh",
                "-t",  # force pseudo-tty allocation
                "-p",
                str(ssh_config.port),
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
                f"{ssh_config.user}@{ssh_config.hostname}",
            ]

            # Now run interactively. If we fail to start, we raise CommandError.
            # Once the user is in the shell, the session is direct.
            try:
                rc = await run_command_interactive(ssh_cmd)
            except Exception as exc:
                raise CommandError(
                    f"Failed to start interactive SSH session: {exc}"
                ) from exc

            return rc
