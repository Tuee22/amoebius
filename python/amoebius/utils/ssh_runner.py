# ssh_stuff.py

import argparse
import asyncio
import os
import shlex
import tempfile
from pathlib import Path
from typing import List, Optional, Dict

# Import your local run_command & CommandError
from .async_command_runner import run_command, CommandError

# Import the Pydantic models
from ..models.ssh import SSHConfig, KubectlCommand


###############################################################################
# ssh_get_server_key (TOFU)
###############################################################################
async def ssh_get_server_key(
    cfg: SSHConfig,
    *,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> List[str]:
    """
    Accept-new approach: minimal SSH handshake to get the server key lines.
    """
    kh_file = tempfile.NamedTemporaryFile(
        dir="/dev/shm", prefix="knownhosts_", delete=False
    )
    kh_path = kh_file.name
    kh_file.close()

    pk_file = tempfile.NamedTemporaryFile(dir="/dev/shm", prefix="idkey_", delete=False)
    pk_path = pk_file.name
    try:
        pk_file.write(cfg.private_key.encode("utf-8"))
        pk_file.flush()
        os.fchmod(pk_file.fileno(), 0o600)
    finally:
        pk_file.close()

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
        # minimal command
        "exit",
        "0",
    ]

    try:
        await run_command(
            ssh_cmd,
            retries=retries,
            retry_delay=retry_delay,
        )
    except Exception:
        # cleanup
        try:
            os.unlink(kh_path)
        except OSError:
            pass
        try:
            os.unlink(pk_path)
        except OSError:
            pass
        raise

    # read ephemeral known_hosts
    with open(kh_path, "r", encoding="utf-8") as f:
        lines = [ln.strip() for ln in f if ln.strip()]

    # cleanup
    try:
        os.unlink(kh_path)
    except OSError:
        pass
    try:
        os.unlink(pk_path)
    except OSError:
        pass

    if not lines:
        raise CommandError(
            "ssh_get_server_key: no lines returned; server key not found."
        )
    return lines


###############################################################################
# run_ssh_command => strict checking only
###############################################################################
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
    Strict host key checking: ssh_config.host_keys must not be empty.
    """
    if not ssh_config.host_keys or len(ssh_config.host_keys) == 0:
        raise CommandError(
            "run_ssh_command: host_keys is empty; strict mode cannot proceed."
        )

    kh_file = tempfile.NamedTemporaryFile(
        dir="/dev/shm", prefix="knownhosts_", delete=False
    )
    kh_path = kh_file.name
    kh_file.close()

    # ephemeral private key
    pk_file = tempfile.NamedTemporaryFile(dir="/dev/shm", prefix="idkey_", delete=False)
    pk_path = pk_file.name
    try:
        pk_file.write(ssh_config.private_key.encode("utf-8"))
        pk_file.flush()
        os.fchmod(pk_file.fileno(), 0o600)
    finally:
        pk_file.close()

    # write known_hosts lines
    with open(kh_path, "w", encoding="utf-8") as f:
        for line in ssh_config.host_keys:
            f.write(line + "\n")

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

    if env:
        env_tokens = ["env"] + [f"{k}={v}" for k, v in env.items()]
        remote_command = env_tokens + remote_command

    cmd_str = " ".join(shlex.quote(x) for x in remote_command)
    ssh_cmd.append(cmd_str)

    try:
        return await run_command(
            ssh_cmd,
            sensitive=sensitive,
            retries=retries,
            retry_delay=retry_delay,
        )
    finally:
        # cleanup ephemeral
        try:
            os.unlink(kh_path)
        except OSError:
            pass
        try:
            os.unlink(pk_path)
        except OSError:
            pass


###############################################################################
# run_kubectl (local)
###############################################################################
async def run_kubectl(
    kube_cmd: KubectlCommand,
    *,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Executes a 'kubectl exec' command locally.
    """
    args = kube_cmd.build_kubectl_args()
    return await run_command(
        args,
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )


###############################################################################
# run_ssh_kubectl_command (remote => strict)
###############################################################################
async def run_ssh_kubectl_command(
    ssh_config: SSHConfig,
    kube_cmd: KubectlCommand,
    *,
    sensitive: bool = True,
    retries: int = 3,
    retry_delay: float = 1.0,
) -> str:
    """
    Executes 'kubectl exec ...' on a remote host via strict SSH.
    """
    if not ssh_config.host_keys:
        raise CommandError("run_ssh_kubectl_command: need host_keys for strict mode.")

    remote_args = kube_cmd.build_kubectl_args()
    return await run_ssh_command(
        ssh_config,
        remote_args,
        sensitive=sensitive,
        retries=retries,
        retry_delay=retry_delay,
    )


###############################################################################
# main() => demonstrates tofu -> strict
###############################################################################
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Demonstrate a two-step TOFU -> Strict SSH approach"
    )
    parser.add_argument("--hostname", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--user", required=True)
    parser.add_argument("--key-file", required=True)
    args = parser.parse_args()

    async def _run_demo() -> None:
        key_txt = Path(args.key_file).read_text()

        # Step 1: retrieve server key via accept-new
        tofu_cfg = SSHConfig(
            user=args.user,
            hostname=args.hostname,
            port=args.port,
            private_key=key_txt,
        )
        print("=== Step 1: Getting server key via TOFU ===")
        lines = await ssh_get_server_key(tofu_cfg)
        for ln in lines:
            print("   ", ln)

        # Step 2: strict => run "whoami"
        strict_cfg = SSHConfig(
            user=args.user,
            hostname=args.hostname,
            port=args.port,
            private_key=key_txt,
            host_keys=lines,
        )
        print("\n=== Step 2: Strict => run 'whoami' ===")
        whoami_out = await run_ssh_command(strict_cfg, ["whoami"])
        print("whoami =>", whoami_out)

    asyncio.run(_run_demo())


if __name__ == "__main__":
    main()
