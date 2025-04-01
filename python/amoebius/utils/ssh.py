"""
amoebius/utils/ssh.py

Provides high-level functions for SSH-related operations, leveraging
ephemeral_manager from amoebius/utils/ephemeral_file.py to manage ephemeral
known_hosts and private keys in /dev/shm. No manual tempfile or cleanup is needed,
and no direct Vault usage occurs here.

We use validate_type from amoebius.models.validator to ensure ephemeral_manager
yields a plain str (single-file mode).

Additionally, file I/O has been converted to asynchronous operations via aiofiles,
except for os.chmod() calls, which remain synchronous to avoid mypy errors.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import shlex
import sys
from pathlib import Path
from typing import Dict, List, Optional

import aiofiles
import aiofiles.ospath

from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.models.ssh import SSHConfig, KubectlCommand
from amoebius.models.validator import validate_type
from amoebius.utils.ephemeral_file import ephemeral_manager


async def ssh_get_server_key(
    cfg: SSHConfig,
    *,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> List[str]:
    """
    Perform a minimal SSH handshake with StrictHostKeyChecking=accept-new to retrieve
    the server's host key lines (TOFU).

    Creates two ephemeral single-file contexts in /dev/shm:
      1) known_hosts (initially empty)
      2) private key

    After writing the private key and performing the handshake, we read the ephemeral
    known_hosts file to extract the server key lines.

    Args:
        cfg: SSHConfig with user, hostname, port, private_key. host_keys not needed here.
        retries: Number of times to retry on failure.
        retry_delay: Delay in seconds between retries.

    Returns:
        A list of lines from ephemeral known_hosts (the server's key lines).

    Raises:
        CommandError: If handshake fails or if no keys are discovered.
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
) -> str:
    """
    Run an SSH command in strict host-key-checking mode, requiring host_keys in ssh_config.
    We create ephemeral known_hosts + ephemeral private key.

    Args:
        ssh_config: Must have user, hostname, port, private_key, host_keys.
        remote_command: The command to run on the remote.
        sensitive: If True, omit details from error logs on failure.
        env: If provided, prefix remote_command with "env VAR=VAL".
        retries: Number of times to retry on error.
        retry_delay: Delay in seconds between retries.

    Returns:
        Captured stdout from the SSH command on success.

    Raises:
        CommandError: If host_keys is empty or the command fails repeatedly.
    """
    if not ssh_config.host_keys:
        raise CommandError("run_ssh_command requires non-empty host_keys (strict).")

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

            return await run_command(
                ssh_cmd,
                sensitive=sensitive,
                retries=retries,
                retry_delay=retry_delay,
            )


async def run_kubectl(
    kube_cmd: KubectlCommand,
    *,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Execute a local "kubectl exec" command. This does not do SSH; it's purely local.
    """
    args = kube_cmd.build_kubectl_args()
    return await run_command(
        args, sensitive=sensitive, retries=retries, retry_delay=retry_delay
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
        ssh_config: Must have host_keys
        kube_cmd:   The KubectlCommand describing the action
    """
    if not ssh_config.host_keys:
        raise CommandError("run_ssh_kubectl_command requires non-empty host_keys.")

    remote_args = kube_cmd.build_kubectl_args()
    return await run_ssh_command(
        ssh_config,
        remote_args,
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )


def main() -> None:
    """
    CLI demonstration:
      1) TOFU => retrieve server key lines
      2) Strict => run 'whoami'
    """
    parser = argparse.ArgumentParser(
        description="Demonstrate ephemeral SSH usage: TOFU -> Strict"
    )
    parser.add_argument("--hostname", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--user", required=True)
    parser.add_argument("--key-file", required=True)
    args = parser.parse_args()

    async def _demo() -> None:
        key_txt = Path(args.key_file).read_text()

        tofu_cfg = SSHConfig(
            user=args.user,
            hostname=args.hostname,
            port=args.port,
            private_key=key_txt,
        )
        print("=== Step 1: TOFU => retrieving server key ===")
        lines = await ssh_get_server_key(tofu_cfg)
        for ln in lines:
            print("   ", ln)

        strict_cfg = SSHConfig(
            user=args.user,
            hostname=args.hostname,
            port=args.port,
            private_key=key_txt,
            host_keys=lines,
        )
        print("\n=== Step 2: Strict => run 'whoami' ===")
        who = await run_ssh_command(strict_cfg, ["whoami"])
        print("whoami =>", who)

    try:
        asyncio.run(_demo())
    except Exception as ex:
        print(f"Error: {ex}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
