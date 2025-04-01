"""
amoebius/deployment/rke2.py

Implements RKE2 cluster deployment referencing ephemeral-based SSH usage from 
amoebius.utils.ssh and Vault-based config retrieval from amoebius.secrets.ssh.
"""

from __future__ import annotations

import asyncio
import textwrap
from typing import Optional, Dict, List, Callable

from amoebius.models.rke2 import RKE2InstancesOutput, RKE2Instance, RKE2Credentials
from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.ssh import get_ssh_config
from amoebius.models.ssh import SSHConfig
from amoebius.utils.ssh import run_ssh_command


async def disable_swap(ssh_cfg: SSHConfig) -> None:
    await run_ssh_command(ssh_cfg, ["sudo", "swapoff", "-a"], sensitive=True)
    sed_cmd = r"sudo sed -i.bak '/\sswap\s/s/^/#/g' /etc/fstab || true"
    await run_ssh_command(ssh_cfg, ["bash", "-c", sed_cmd], sensitive=True)


async def load_kernel_modules(ssh_cfg: SSHConfig) -> None:
    for mod in ["overlay", "br_netfilter"]:
        await run_ssh_command(ssh_cfg, ["sudo", "modprobe", mod], sensitive=True)


async def set_sysctl(ssh_cfg: SSHConfig) -> None:
    contents = textwrap.dedent(
        """\
    net.ipv4.ip_forward=1
    net.bridge.bridge-nf-call-iptables=1
    net.bridge.bridge-nf-call-ip6tables=1
    """
    )
    enc = contents.encode("utf-8").hex()
    cmd = f"echo '{enc}' | xxd -r -p | sudo tee /etc/sysctl.d/99-rke2.conf >/dev/null"
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)
    await run_ssh_command(ssh_cfg, ["sudo", "sysctl", "--system"], sensitive=True)


async def setup_selinux(ssh_cfg: SSHConfig) -> None:
    await run_ssh_command(
        ssh_cfg,
        [
            "bash",
            "-c",
            "which yum &>/dev/null && sudo yum install -y rke2-selinux || true",
        ],
        sensitive=True,
    )
    await run_ssh_command(
        ssh_cfg, ["bash", "-c", "sudo setenforce 1 || true"], sensitive=True
    )


async def install_nvidia_drivers(ssh_cfg: SSHConfig) -> None:
    # minimal approach
    try:
        await run_ssh_command(ssh_cfg, ["which", "nvidia-smi"], sensitive=True)
    except Exception:
        import textwrap

        script = textwrap.dedent(
            """\
        #!/usr/bin/env bash
        set -eux
        sudo apt-get update -y
        sudo apt-get install -y ubuntu-drivers-common
        sudo ubuntu-drivers autoinstall
        """
        )
        enc = script.encode("utf-8").hex()
        cmd = f"echo '{enc}' | xxd -r -p | sudo bash -s"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)

    try:
        await run_ssh_command(
            ssh_cfg, ["which", "nvidia-container-runtime"], sensitive=True
        )
    except Exception:
        import textwrap

        script = textwrap.dedent(
            """\
        #!/usr/bin/env bash
        set -eux
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        wget https://nvidia.github.io/libnvidia-container/gpgkey -O /tmp/nvidia_gpg.pub
        sudo apt-key add /tmp/nvidia_gpg.pub
        curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
          sed 's#deb https://#deb [arch=amd64] https://#g' | \
          sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        sudo apt-get update -y
        sudo apt-get install -y nvidia-container-toolkit
        """
        )
        enc = script.encode("utf-8").hex()
        cmd = f"echo '{enc}' | xxd -r -p | sudo bash -s"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)

    import textwrap

    patch = textwrap.dedent(
        """\
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
        BinaryName = "nvidia-container-runtime"
    """
    )
    encoded = patch.encode("utf-8").hex()
    cmd2 = f"echo '{encoded}' | xxd -r -p | sudo tee /etc/containerd/config_nvidia.toml >/dev/null"
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd2], sensitive=True)
    await run_ssh_command(
        ssh_cfg, ["sudo", "systemctl", "restart", "containerd"], sensitive=True
    )


async def prepare_vm(ssh_cfg: SSHConfig, has_gpu: bool) -> None:
    await disable_swap(ssh_cfg)
    await load_kernel_modules(ssh_cfg)
    await set_sysctl(ssh_cfg)
    await setup_selinux(ssh_cfg)
    if has_gpu:
        await install_nvidia_drivers(ssh_cfg)


async def rke2_server_install(ssh_cfg: SSHConfig, channel: str = "stable") -> bool:
    try:
        await run_ssh_command(ssh_cfg, ["which", "rke2"], sensitive=True)
        await run_ssh_command(
            ssh_cfg,
            ["sudo", "systemctl", "enable", "rke2-server", "||", "true"],
            sensitive=True,
        )
        await run_ssh_command(
            ssh_cfg,
            ["sudo", "systemctl", "start", "rke2-server", "||", "true"],
            sensitive=True,
        )
        return False
    except Exception:
        pass

    install_cmd = [
        "curl",
        "-sfL",
        "https://get.rke2.io",
        "|",
        "sudo",
        f"INSTALL_RKE2_CHANNEL={channel}",
        "INSTALL_RKE2_TYPE=server",
        "sh",
        "-",
    ]
    await run_ssh_command(
        ssh_cfg, ["bash", "-c", " ".join(install_cmd)], sensitive=True
    )
    await run_ssh_command(
        ssh_cfg, ["sudo", "systemctl", "enable", "rke2-server"], sensitive=True
    )
    await run_ssh_command(
        ssh_cfg, ["sudo", "systemctl", "start", "rke2-server"], sensitive=True
    )
    return True


async def rke2_agent_install(
    ssh_cfg: SSHConfig, channel: str, server_ip: str, join_token: str
) -> None:
    try:
        await run_ssh_command(ssh_cfg, ["which", "rke2"], sensitive=True)
    except Exception:
        install_cmd = [
            "curl",
            "-sfL",
            "https://get.rke2.io",
            "|",
            "sudo",
            f"INSTALL_RKE2_CHANNEL={channel}",
            "INSTALL_RKE2_TYPE=agent",
            "sh",
            "-",
        ]
        await run_ssh_command(
            ssh_cfg, ["bash", "-c", " ".join(install_cmd)], sensitive=True
        )

    config_yaml = f"""server: https://{server_ip}:9345
token: {join_token}
tls-san:
  - {server_ip}
"""
    enc = config_yaml.encode("utf-8").hex()
    script = (
        f"echo '{enc}' | xxd -r -p | sudo tee /etc/rancher/rke2/config.yaml >/dev/null"
    )
    await run_ssh_command(ssh_cfg, ["bash", "-c", script], sensitive=True)
    await run_ssh_command(
        ssh_cfg,
        ["sudo", "systemctl", "enable", "rke2-agent", "||", "true"],
        sensitive=True,
    )
    await run_ssh_command(
        ssh_cfg,
        ["sudo", "systemctl", "start", "rke2-agent", "||", "true"],
        sensitive=True,
    )


async def wait_for_server_token(ssh_cfg: SSHConfig, attempts_left: int = 30) -> str:
    if attempts_left <= 0:
        raise RuntimeError("Failed to retrieve RKE2 node-token after many tries.")

    try:
        raw = await run_ssh_command(
            ssh_cfg,
            ["sudo", "cat", "/var/lib/rancher/rke2/server/node-token"],
            sensitive=True,
        )
        if raw.strip():
            return raw.strip()
    except Exception:
        pass
    await asyncio.sleep(2)
    return await wait_for_server_token(ssh_cfg, attempts_left - 1)


async def fetch_kubeconfig(ssh_cfg: SSHConfig) -> str:
    return await run_ssh_command(
        ssh_cfg, ["sudo", "cat", "/etc/rancher/rke2/rke2.yaml"], sensitive=True
    )


async def deploy_rke2_cluster(
    rke2_output: RKE2InstancesOutput,
    control_plane_group: str,
    vault_client: AsyncVaultClient,
    install_channel: str = "stable",
    retrieve_credentials: bool = True,
) -> Optional[RKE2Credentials]:
    cp_list = rke2_output.instances.get(control_plane_group, [])
    if not cp_list:
        raise ValueError(f"No instances found in group '{control_plane_group}'")

    # VM prep in parallel
    prep_tasks = [
        _prepare_single_vm(i, vault_client)
        for grp, insts in rke2_output.instances.items()
        for i in insts
    ]
    await asyncio.gather(*prep_tasks)

    cp_primary = cp_list[0]
    ssh_cp = await _retrieve_ssh_cfg(cp_primary, vault_client)
    await rke2_server_install(ssh_cp, channel=install_channel)
    node_token = await wait_for_server_token(ssh_cp)

    # agent on all others
    agent_tasks = [
        rke2_agent_install(
            await _retrieve_ssh_cfg(i, vault_client),
            install_channel,
            cp_primary.private_ip,
            node_token,
        )
        for grp_name, inst_list in rke2_output.instances.items()
        for i in inst_list
        if not (grp_name == control_plane_group and i is cp_primary)
    ]
    await asyncio.gather(*agent_tasks)

    if not retrieve_credentials:
        return None

    kubeconfig = await fetch_kubeconfig(ssh_cp)
    return RKE2Credentials(
        kubeconfig=kubeconfig,
        join_token=node_token,
        control_plane_ssh={cp_primary.name: cp_primary.vault_path},
    )


async def _prepare_single_vm(
    instance: RKE2Instance, vault_client: AsyncVaultClient
) -> None:
    ssh_cfg = await _retrieve_ssh_cfg(instance, vault_client)
    await prepare_vm(ssh_cfg, instance.has_gpu)


async def _retrieve_ssh_cfg(
    instance: RKE2Instance, vault_client: AsyncVaultClient
) -> SSHConfig:
    # we do vault-based retrieval from secrets/ssh
    from amoebius.secrets.ssh import get_ssh_config

    return await get_ssh_config(
        vault_client, instance.vault_path, tofu_if_missing_host_keys=True
    )


async def destroy_cluster(
    ssh_cfgs: List[SSHConfig],
    remove_infra_callback: Optional[Callable[[], None]] = None,
) -> None:
    tasks = [_uninstall_rke2_node(cfg) for cfg in ssh_cfgs]
    await asyncio.gather(*tasks)
    if remove_infra_callback:
        remove_infra_callback()


async def upgrade_cluster(
    server_ssh_cfgs: List[SSHConfig],
    agent_ssh_cfgs: List[SSHConfig],
    channel: str = "stable",
) -> None:
    # servers sequential
    for s_cfg in server_ssh_cfgs:
        await _upgrade_node(s_cfg, channel)

    # agents parallel
    tasks = [_upgrade_node(a_cfg, channel) for a_cfg in agent_ssh_cfgs]
    await asyncio.gather(*tasks)


async def rotate_certs(server_ssh_cfgs: List[SSHConfig]) -> None:
    for s_cfg in server_ssh_cfgs:
        await run_ssh_command(
            s_cfg, ["sudo", "rke2", "certificate", "rotate", "--force"], sensitive=True
        )
        await run_ssh_command(
            s_cfg, ["sudo", "systemctl", "restart", "rke2-server"], sensitive=True
        )


async def backup_cluster_state(
    server_ssh_cfg: SSHConfig,
    snapshot_name: str = "on-demand",
    local_download_path: Optional[str] = None,
) -> None:
    await run_ssh_command(
        server_ssh_cfg,
        ["sudo", "rke2", "etcd-snapshot", "save", "--name", snapshot_name],
        sensitive=True,
    )
    # scp if needed


async def reset_node(ssh_cfg: SSHConfig, is_control_plane: bool) -> None:
    svc = "rke2-server" if is_control_plane else "rke2-agent"
    await run_ssh_command(ssh_cfg, ["sudo", "systemctl", "stop", svc], sensitive=True)
    await _uninstall_rke2_node(ssh_cfg)


async def _uninstall_rke2_node(ssh_cfg: SSHConfig) -> None:
    for script in ["rke2-uninstall.sh", "rke2-agent-uninstall.sh"]:
        cmd = f"sudo bash -c '[[ -f /usr/local/bin/{script} ]] && /usr/local/bin/{script} || true'"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)


async def _upgrade_node(ssh_cfg: SSHConfig, channel: str) -> None:
    """
    Minimal approach to "upgrade" a node by stopping RKE2, re-running the get.rke2.io script
    with a new channel, and then starting services again.
    """
    await run_ssh_command(
        ssh_cfg,
        ["sudo", "systemctl", "stop", "rke2-server", "rke2-agent", "||", "true"],
        sensitive=True,
    )
    upgrade_cmd = [
        "curl",
        "-sfL",
        "https://get.rke2.io",
        "|",
        "sudo",
        f"INSTALL_RKE2_CHANNEL={channel}",
        "sh",
        "-",
    ]
    await run_ssh_command(
        ssh_cfg, ["bash", "-c", " ".join(upgrade_cmd)], sensitive=True
    )

    # Start the server and agent again, ignoring errors if one doesn't exist on this node.
    for svc in ["rke2-server", "rke2-agent"]:
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "start", svc, "||", "true"], sensitive=True
        )
