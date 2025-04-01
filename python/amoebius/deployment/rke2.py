"""
amoebius/deployment/rke2.py

Provides an idempotent RKE2 cluster deployment on Ubuntu 22.04 (APT-based).
Ephemeral SSH usage is in amoebius.utils.ssh, Vault-based SSH config retrieval 
is from amoebius.secrets.ssh. We support multi-control-plane (HA) if multiple 
nodes exist in the "control_plane_group."

We store final RKE2Credentials in Vault (via secrets/rke2.py), not returning them.
"""

from __future__ import annotations

import asyncio
import textwrap
from typing import Optional, List, Callable

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.secrets.ssh import get_ssh_config
from amoebius.secrets.rke2 import save_rke2_credentials
from amoebius.models.rke2 import RKE2InstancesOutput, RKE2Instance, RKE2Credentials
from amoebius.models.ssh import SSHConfig
from amoebius.utils.ssh import run_ssh_command
from amoebius.utils.async_retry import async_retry


async def deploy_rke2_cluster(
    rke2_output: RKE2InstancesOutput,
    control_plane_group: str,
    vault_client: AsyncVaultClient,
    credentials_vault_path: str,
    install_channel: str = "stable",
) -> None:
    """
    Deploy an RKE2 cluster across all groups on Ubuntu 22.04. Multi-CP approach for
    any nodes in 'control_plane_group'. The final RKE2Credentials are stored in Vault.

    Steps:
      1) Prepare all VMs concurrently: disable swap, load modules, configure sysctl, etc.
      2) Use the first node in 'control_plane_group' as the bootstrap server.
      3) Additional CP nodes also install as 'server' referencing the bootstrap's IP + token.
      4) All other nodes become 'agents' referencing the bootstrap IP + token.
      5) We fetch the kubeconfig from the bootstrap, store {kubeconfig, token, CP vault paths}
         in Vault via secrets/rke2.save_rke2_credentials.

    Args:
      rke2_output: Flattened instance data (group => list of RKE2Instance).
      control_plane_group: The group name containing control-plane nodes.
      vault_client: For retrieving SSH credentials from Vault + storing RKE2 creds.
      credentials_vault_path: Where to store final RKE2Credentials in Vault.
      install_channel: RKE2 channel (default: stable).
    Returns:
      None. Credentials stored in Vault, not returned.
    """

    # 1) Prepare all VMs concurrently
    async def _prepare_instance(inst: RKE2Instance) -> None:
        ssh_cfg = await get_ssh_config(
            vault_client, inst.vault_path, tofu_if_missing_host_keys=True
        )
        await disable_swap(ssh_cfg)
        await load_kernel_modules(ssh_cfg)
        await configure_sysctl(ssh_cfg)
        if inst.has_gpu:
            await install_nvidia_drivers(ssh_cfg)

    all_instances = [
        i for grp_insts in rke2_output.instances.values() for i in grp_insts
    ]
    await asyncio.gather(*(_prepare_instance(inst) for inst in all_instances))

    # 2) Multi-CP => first node is bootstrap
    cp_list = rke2_output.instances.get(control_plane_group, [])
    if not cp_list:
        raise ValueError(f"No instances found in group '{control_plane_group}'")

    bootstrap_cp = cp_list[0]
    bootstrap_ssh = await get_ssh_config(vault_client, bootstrap_cp.vault_path, True)
    await install_server(bootstrap_ssh, install_channel)
    token = await get_node_token(bootstrap_ssh)

    # additional CP nodes beyond the first
    if len(cp_list) > 1:

        async def _join_cp_server(cp_inst: RKE2Instance) -> None:
            cp_ssh = await get_ssh_config(vault_client, cp_inst.vault_path, True)
            await install_server(
                cp_ssh,
                install_channel,
                existing_server_ip=bootstrap_cp.private_ip,
                node_token=token,
            )

        await asyncio.gather(*(_join_cp_server(n) for n in cp_list[1:]))

    # 3) Agents => all non-CP
    agent_insts = [
        inst
        for group_name, group_insts in rke2_output.instances.items()
        for inst in group_insts
        if group_name != control_plane_group
    ]

    async def _join_agent(a_inst: RKE2Instance) -> None:
        agent_ssh = await get_ssh_config(vault_client, a_inst.vault_path, True)
        await install_agent(agent_ssh, install_channel, bootstrap_cp.private_ip, token)

    await asyncio.gather(*(_join_agent(a) for a in agent_insts))

    # 4) gather final credentials => store in vault
    kubeconfig = await fetch_kubeconfig(bootstrap_ssh)
    cp_vault_paths = [cp.vault_path for cp in cp_list]
    creds = RKE2Credentials(
        kubeconfig=kubeconfig,
        join_token=token,
        control_plane_ssh_vault_path=cp_vault_paths,
    )
    await save_rke2_credentials(vault_client, credentials_vault_path, creds)


async def disable_swap(ssh_cfg: SSHConfig) -> None:
    """
    Disables swap permanently on Ubuntu 22.04:
      - 'swapoff -a'
      - comments out swap lines in /etc/fstab
    """
    await run_ssh_command(ssh_cfg, ["sudo", "swapoff", "-a"], sensitive=True)
    sed_cmd = r"sudo sed -i.bak '/\sswap\s/s/^/#/g' /etc/fstab"
    await run_ssh_command(ssh_cfg, ["bash", "-c", sed_cmd], sensitive=True)


async def load_kernel_modules(ssh_cfg: SSHConfig) -> None:
    """
    Loads required kernel modules (e.g. br_netfilter, overlay) for K8s bridging
    and ensures they load on reboot by writing /etc/modules-load.d/rke2.conf
    """
    for mod in ["overlay", "br_netfilter"]:
        await run_ssh_command(ssh_cfg, ["sudo", "modprobe", mod], sensitive=True)

    modules_conf = "overlay\nbr_netfilter\n"
    enc = modules_conf.encode("utf-8").hex()
    cmd_upload = (
        f"echo '{enc}' | xxd -r -p | sudo tee /etc/modules-load.d/rke2.conf >/dev/null"
    )
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_upload], sensitive=True)


async def configure_sysctl(ssh_cfg: SSHConfig) -> None:
    """
    Configures bridging and IP forwarding in /etc/sysctl.d/99-rke2.conf,
    then applies via 'sysctl --system'. Ensures container networking bridging.
    """
    content = textwrap.dedent(
        """\
    net.ipv4.ip_forward=1
    net.bridge.bridge-nf-call-iptables=1
    net.bridge.bridge-nf-call-ip6tables=1
    """
    )
    enc = content.encode("utf-8").hex()
    cmd_upload = (
        f"echo '{enc}' | xxd -r -p | sudo tee /etc/sysctl.d/99-rke2.conf >/dev/null"
    )
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_upload], sensitive=True)
    await run_ssh_command(ssh_cfg, ["sudo", "sysctl", "--system"], sensitive=True)


async def install_nvidia_drivers(ssh_cfg: SSHConfig) -> None:
    """
    Installs official Ubuntu GPU drivers and nvidia-container-toolkit on Ubuntu 22.04
    so that GPU-based workloads can run properly.
    """
    # check nvidia-smi
    try:
        await run_ssh_command(ssh_cfg, ["which", "nvidia-smi"], sensitive=True)
    except Exception:
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

    # check nvidia-container-runtime
    try:
        await run_ssh_command(
            ssh_cfg, ["which", "nvidia-container-runtime"], sensitive=True
        )
    except Exception:
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

    patch = textwrap.dedent(
        """\
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
        BinaryName = "nvidia-container-runtime"
    """
    )
    enc2 = patch.encode("utf-8").hex()
    cmd2 = f"echo '{enc2}' | xxd -r -p | sudo tee /etc/containerd/config_nvidia.toml >/dev/null"
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd2], sensitive=True)
    await run_ssh_command(
        ssh_cfg, ["sudo", "systemctl", "restart", "containerd"], sensitive=True
    )


async def install_server(
    ssh_cfg: SSHConfig,
    channel: str,
    existing_server_ip: Optional[str] = None,
    node_token: Optional[str] = None,
) -> None:
    """
    Install RKE2 as 'server'. If existing_server_ip and node_token are provided,
    we join an existing cluster; otherwise we become the first control-plane node.
    """
    # see if rke2 installed
    try:
        await run_ssh_command(ssh_cfg, ["which", "rke2"], sensitive=True)
    except Exception:
        script = textwrap.dedent(
            f"""\
        #!/usr/bin/env bash
        set -eux
        curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL={channel} INSTALL_RKE2_TYPE=server sudo sh -
        sudo systemctl enable rke2-server
        sudo systemctl start rke2-server
        """
        )
        enc = script.encode("utf-8").hex()
        cmd_install = f"echo '{enc}' | xxd -r -p | sudo bash -s"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_install], sensitive=True)
    else:
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "enable", "rke2-server"], sensitive=True
        )
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "start", "rke2-server"], sensitive=True
        )

    if existing_server_ip and node_token:
        config_yaml = textwrap.dedent(
            f"""\
        server: https://{existing_server_ip}:9345
        token: {node_token}
        tls-san:
          - {existing_server_ip}
        """
        )
        enc = config_yaml.encode("utf-8").hex()
        cmd_upload = f"echo '{enc}' | xxd -r -p | sudo tee /etc/rancher/rke2/config.yaml >/dev/null"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_upload], sensitive=True)
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "restart", "rke2-server"], sensitive=True
        )


async def install_agent(
    ssh_cfg: SSHConfig, channel: str, server_ip: str, node_token: str
) -> None:
    """
    Install RKE2 as 'agent', referencing the main server (server_ip + node_token).
    """
    try:
        await run_ssh_command(ssh_cfg, ["which", "rke2"], sensitive=True)
    except Exception:
        script = textwrap.dedent(
            f"""\
        #!/usr/bin/env bash
        set -eux
        curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL={channel} INSTALL_RKE2_TYPE=agent sudo sh -
        sudo systemctl enable rke2-agent
        sudo systemctl start rke2-agent
        """
        )
        enc = script.encode("utf-8").hex()
        cmd_install = f"echo '{enc}' | xxd -r -p | sudo bash -s"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_install], sensitive=True)
    else:
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "enable", "rke2-agent"], sensitive=True
        )
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "start", "rke2-agent"], sensitive=True
        )

    config_yaml = textwrap.dedent(
        f"""\
    server: https://{server_ip}:9345
    token: {node_token}
    tls-san:
      - {server_ip}
    """
    )
    enc = config_yaml.encode("utf-8").hex()
    cmd_upload = (
        f"echo '{enc}' | xxd -r -p | sudo tee /etc/rancher/rke2/config.yaml >/dev/null"
    )
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_upload], sensitive=True)
    await run_ssh_command(
        ssh_cfg, ["sudo", "systemctl", "restart", "rke2-agent"], sensitive=True
    )


@async_retry(retries=30, delay=2.0)
async def get_node_token(ssh_cfg: SSHConfig) -> str:
    """
    Retrieve the node token from the bootstrap server node. We use async_retry here
    because the server may not be fully started when we attempt to read the token file.
    """
    out = await run_ssh_command(
        ssh_cfg,
        ["sudo", "cat", "/var/lib/rancher/rke2/server/node-token"],
        sensitive=True,
    )
    token_val = out.strip()
    if not token_val:
        raise RuntimeError("Empty node-token from server node.")
    return token_val


async def fetch_kubeconfig(ssh_cfg: SSHConfig) -> str:
    """
    Retrieve the admin kubeconfig from /etc/rancher/rke2/rke2.yaml,
    raising if empty.
    """
    result = await run_ssh_command(
        ssh_cfg, ["sudo", "cat", "/etc/rancher/rke2/rke2.yaml"], sensitive=True
    )
    return result


####################################################################
# Lifecycle / Maintenance
####################################################################


async def destroy_cluster(
    ssh_cfgs: List[SSHConfig],
    remove_infra_callback: Optional[Callable[[], None]] = None,
) -> None:
    """
    Uninstall RKE2 from each node in ssh_cfgs, optionally call remove_infra_callback.
    """
    tasks = [_uninstall_rke2_node(cfg) for cfg in ssh_cfgs]
    await asyncio.gather(*tasks)
    if remove_infra_callback:
        remove_infra_callback()


async def upgrade_cluster(
    server_ssh_cfgs: List[SSHConfig],
    agent_ssh_cfgs: List[SSHConfig],
    channel: str = "stable",
) -> None:
    """
    Minimal cluster upgrade approach:
      - sequentially upgrade servers
      - parallel upgrade of agents
    """
    for s_cfg in server_ssh_cfgs:
        await _upgrade_node(s_cfg, channel)

    tasks = [_upgrade_node(a_cfg, channel) for a_cfg in agent_ssh_cfgs]
    await asyncio.gather(*tasks)


async def _upgrade_node(ssh_cfg: SSHConfig, channel: str) -> None:
    """
    Stop RKE2, re-run get.rke2.io with the new channel, start services again.
    """
    await run_ssh_command(
        ssh_cfg,
        ["sudo", "systemctl", "stop", "rke2-server", "rke2-agent"],
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
    for svc in ["rke2-server", "rke2-agent"]:
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "start", svc], sensitive=True
        )


async def rotate_certs(server_ssh_cfgs: List[SSHConfig]) -> None:
    """
    Rotate cluster certs on each server node, then restart that server.
    """
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
    """
    Creates an etcd snapshot on the control-plane server.
    local_download_path is optional if we want to scp it somewhere else.
    """
    await run_ssh_command(
        server_ssh_cfg,
        ["sudo", "rke2", "etcd-snapshot", "save", "--name", snapshot_name],
        sensitive=True,
    )
    # If local_download_path is set, scp from /var/lib/rancher/rke2/server/db/snapshots/ ?


async def reset_node(ssh_cfg: SSHConfig, is_control_plane: bool) -> None:
    """
    Remove a node from the cluster by stopping the relevant service
    (rke2-server if is_control_plane, else rke2-agent), then uninstall RKE2.
    """
    svc = "rke2-server" if is_control_plane else "rke2-agent"
    await run_ssh_command(ssh_cfg, ["sudo", "systemctl", "stop", svc], sensitive=True)
    await _uninstall_rke2_node(ssh_cfg)


async def _uninstall_rke2_node(ssh_cfg: SSHConfig) -> None:
    """
    Runs rke2-uninstall.sh or rke2-agent-uninstall.sh if they exist, forcibly removing RKE2.
    """
    for script in ["rke2-uninstall.sh", "rke2-agent-uninstall.sh"]:
        cmd = f"sudo bash -c '[[ -f /usr/local/bin/{script} ]] && /usr/local/bin/{script}'"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)
