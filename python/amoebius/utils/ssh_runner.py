# ssh_runner.py

import argparse
import asyncio
import os
import shlex
import tempfile
from pathlib import Path
from typing import Dict, List, Optional

from amoebius.utils.async_command_runner import run_command, CommandError
from amoebius.models.ssh import SSHConfig, KubectlCommand


async def ssh_get_server_key(
    cfg: SSHConfig,
    *,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> List[str]:
    """
    TOFU step: minimal SSH handshake with StrictHostKeyChecking=accept-new.
    Creates ephemeral known_hosts and ephemeral private key in /dev/shm,
    then cleans them up in a single finally block.
    Returns the lines from known_hosts (the host's key).
    """
    kh_file = tempfile.NamedTemporaryFile(
        dir="/dev/shm", prefix="knownhosts_", delete=False
    )
    kh_path = kh_file.name
    kh_file.close()

    pk_file = tempfile.NamedTemporaryFile(dir="/dev/shm", prefix="idkey_", delete=False)
    pk_path = pk_file.name
    pk_file.close()

    try:
        # Write private key
        with open(pk_path, "wb") as fpk:
            fpk.write(cfg.private_key.encode("utf-8"))
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
            f"-o",
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

        # Read back the ephemeral known_hosts
        with open(kh_path, "r", encoding="utf-8") as fkh:
            lines = [ln.strip() for ln in fkh if ln.strip()]

        if not lines:
            raise CommandError(
                "ssh_get_server_key found no lines; server key not retrieved."
            )

        return lines

    finally:
        # Single cleanup block
        for tmp_path in (kh_path, pk_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


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
    Strict host key checking. Fails if ssh_config.host_keys is empty.
    Creates ephemeral known_hosts + ephemeral private key, cleans them up in one finally block.
    """
    if not ssh_config.host_keys:
        raise CommandError("run_ssh_command requires ssh_config.host_keys (strict)")

    kh_file = tempfile.NamedTemporaryFile(
        dir="/dev/shm", prefix="knownhosts_", delete=False
    )
    kh_path = kh_file.name
    kh_file.close()

    pk_file = tempfile.NamedTemporaryFile(dir="/dev/shm", prefix="idkey_", delete=False)
    pk_path = pk_file.name
    pk_file.close()

    try:
        # Write known_hosts lines
        with open(kh_path, "w", encoding="utf-8") as fkh:
            for line in ssh_config.host_keys:
                fkh.write(line + "\n")

        # Write private key
        with open(pk_path, "wb") as fpk:
            fpk.write(ssh_config.private_key.encode("utf-8"))
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
            f"-o",
            f"UserKnownHostsFile={kh_path}",
            "-o",
            "GlobalKnownHostsFile=/dev/null",
            f"{ssh_config.user}@{ssh_config.hostname}",
        ]
        # Possibly prefix with environment variables
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

    finally:
        for tmp_path in (kh_path, pk_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


async def run_kubectl(
    kube_cmd: KubectlCommand,
    *,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Local 'kubectl exec' usage via run_command(...).
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
    'kubectl exec' on a remote host (strict mode).
    Requires ssh_config.host_keys to be set.
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
    Demo: 1) TOFU => retrieve server key lines
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

    asyncio.run(_demo())


if __name__ == "__main__":
    main()
