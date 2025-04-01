"""
amoebius/utils/ssh.py

Provides high-level ephemeral SSH-related operations, with no direct Vault usage.
We keep:
  - ssh_get_server_key(...) for TOFU accept-new
  - run_ssh_command(...) for strict SSH
  - run_kubectl(...) for local kubectl commands
  - run_ssh_kubectl_command(...) for remote kubectl via SSH
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
    Minimal SSH handshake with StrictHostKeyChecking=accept-new to retrieve
    the server's host key lines (TOFU). Ephemeral known_hosts + ephemeral private key.
    """
    async with ephemeral_manager(
        single_file_name="ssh_known_hosts", prefix="sshkh-"
    ) as kh_path_union:
        kh_path = validate_type(kh_path_union, str)

        async with ephemeral_manager(
            single_file_name="ssh_idkey", prefix="sshpk-"
        ) as pk_path_union:
            pk_path = validate_type(pk_path_union, str)

            # Write private key (async)
            async with aiofiles.open(pk_path, "wb") as fpk:
                await fpk.write(cfg.private_key.encode("utf-8"))

            # Protect private key (sync call to avoid mypy issues)
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

            # read ephemeral known_hosts
            lines = []
            if await aiofiles.ospath.exists(kh_path):
                async with aiofiles.open(kh_path, "r", encoding="utf-8") as fkh:
                    all_lines = await fkh.readlines()
                    lines = [ln.strip() for ln in all_lines if ln.strip()]

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
    Uses ephemeral known_hosts + ephemeral private key.
    """
    if not ssh_config.host_keys:
        raise CommandError("run_ssh_command requires ssh_config.host_keys (strict).")

    async with ephemeral_manager(
        single_file_name="ssh_known_hosts", prefix="sshkh-"
    ) as kh_path_union:
        kh_path = validate_type(kh_path_union, str)

        async with ephemeral_manager(
            single_file_name="ssh_idkey", prefix="sshpk-"
        ) as pk_path_union:
            pk_path = validate_type(pk_path_union, str)

            # Write known_hosts lines (async)
            async with aiofiles.open(kh_path, "w", encoding="utf-8") as fkh:
                for line in ssh_config.host_keys:
                    await fkh.write(line + "\n")

            # Write private key (async)
            async with aiofiles.open(pk_path, "wb") as fpk:
                await fpk.write(ssh_config.private_key.encode("utf-8"))

            # Protect private key
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
    Execute a local 'kubectl exec' command.
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
    """
    if not ssh_config.host_keys:
        raise CommandError("Cannot do run_ssh_kubectl_command: missing host_keys")

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
    Demonstration for ephemeral SSH usage:
      1) TOFU => retrieve server key lines
      2) Strict => run 'whoami'
    """
    import argparse, asyncio, sys
    from pathlib import Path

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

        # Step 1: No known keys => get them via accept-new
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

        # Step 2: Strict => 'whoami'
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
