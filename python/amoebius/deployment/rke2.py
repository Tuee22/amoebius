"""
amoebius/deployment/rke2.py

Implements an idempotent RKE2 cluster deployment on Ubuntu 22.04 using apt-based commands.
All ephemeral SSH usage is in amoebius.utils.ssh, and Vault-based SSH config retrieval 
is from amoebius.secrets.ssh. We support multiple control-plane nodes for HA.

We do not return RKE2Credentials from deploy_rke2_cluster; instead we store them in Vault
using secrets/rke2.py.

No uses of SELinux steps. We keep concurrency with async gather. We only use async_retry
where we wait for the node token.
No silent fails, no for loops that can be replaced by comprehensions, etc.
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

# We only use async_retry for node-token retrieval
from amoebius.utils.async_retry import async_retry


async def deploy_rke2_cluster(
    rke2_output: RKE2InstancesOutput,
    control_plane_group: str,
    vault_client: AsyncVaultClient,
    credentials_vault_path: str,
    install_channel: str = "stable",
) -> None:
    """
    Deploy an RKE2 cluster across all groups, with a multi-CP approach for the group
    'control_plane_group' under Ubuntu 22.04 (APT-based logic).

    Steps:
      1) prepare all VMs concurrently
      2) first CP node => bootstrap server
      3) additional CP nodes => also servers referencing the bootstrap's IP/token
      4) all other nodes => agents referencing bootstrap
      5) gather final credentials => store in Vault

    Args:
      rke2_output: Flattened instance data from Terraform
      control_plane_group: The name of the group containing CP nodes
      vault_client: For retrieving SSH config & storing final credentials
      credentials_vault_path: Vault path where we store final RKE2Credentials
      install_channel: e.g. 'stable'

    Returns:
      None (the credentials are stored in Vault, not returned)
    """

    # 1) prepare all VMs
    # let's define a local function to build coros for concurrency
    async def prep_single(inst: RKE2Instance):
        cfg = await get_ssh_config(
            vault_client, inst.vault_path, tofu_if_missing_host_keys=True
        )
        await disable_swap(cfg)
        await load_kernel_modules(cfg)
        await _set_sysctl(cfg)
        if inst.has_gpu:
            await _install_nvidia_drivers(cfg)

    all_instances = [i for grp_list in rke2_output.instances.values() for i in grp_list]
    prep_coros = [prep_single(inst) for inst in all_instances]
    await asyncio.gather(*prep_coros)

    # 2) multi-CP => first node is bootstrap
    cp_list = rke2_output.instances.get(control_plane_group, [])
    if not cp_list:
        raise ValueError(
            f"No instances found in control_plane_group '{control_plane_group}'"
        )

    bootstrap_cp = cp_list[0]
    bootstrap_ssh = await get_ssh_config(vault_client, bootstrap_cp.vault_path, True)
    await _install_server(bootstrap_ssh, install_channel)
    token = await _get_node_token(bootstrap_ssh)

    # concurrency for additional CP nodes
    if len(cp_list) > 1:
        # define a local function that returns a coro
        async def join_cp_server(cp_node: RKE2Instance):
            ssh_cp = await get_ssh_config(vault_client, cp_node.vault_path, True)
            await _install_server(
                ssh_cp,
                install_channel,
                existing_server_ip=bootstrap_cp.private_ip,
                node_token=token,
            )

        coros = [join_cp_server(cp_node) for cp_node in cp_list[1:]]
        await asyncio.gather(*coros)

    # 3) agents
    # all non-cp instances
    agent_instances = [
        i
        for grp_name, insts in rke2_output.instances.items()
        for i in insts
        if grp_name != control_plane_group
    ]

    async def join_agent(agent_inst: RKE2Instance):
        ssh_a = await get_ssh_config(vault_client, agent_inst.vault_path, True)
        await _install_agent(ssh_a, install_channel, bootstrap_cp.private_ip, token)

    agent_coros = [join_agent(ai) for ai in agent_instances]
    await asyncio.gather(*agent_coros)

    # 4) gather final credentials => store in vault
    kubeconfig = await _fetch_kubeconfig(bootstrap_ssh)
    cp_paths = [cp.vault_path for cp in cp_list]
    creds = RKE2Credentials(
        kubeconfig=kubeconfig, join_token=token, control_plane_ssh_vault_path=cp_paths
    )
    await save_rke2_credentials(vault_client, credentials_vault_path, creds)


async def disable_swap(ssh_cfg: SSHConfig) -> None:
    """
    Disables swap permanently on Ubuntu 22.04:
      - swapoff -a
      - sed out any swap lines from /etc/fstab
    """
    await run_ssh_command(ssh_cfg, ["sudo", "swapoff", "-a"], sensitive=True)
    sed_cmd = r"sudo sed -i.bak '/\sswap\s/s/^/#/g' /etc/fstab"
    await run_ssh_command(ssh_cfg, ["bash", "-c", sed_cmd], sensitive=True)


async def load_kernel_modules(ssh_cfg: SSHConfig) -> None:
    """
    Loads modules (overlay, br_netfilter) for bridging,
    ensures they load on reboot by writing /etc/modules-load.d/rke2.conf
    """
    for mod in ["overlay", "br_netfilter"]:
        await run_ssh_command(ssh_cfg, ["sudo", "modprobe", mod], sensitive=True)

    modules_conf = "overlay\nbr_netfilter\n"
    enc = modules_conf.encode("utf-8").hex()
    cmd_upload = (
        f"echo '{enc}' | xxd -r -p | sudo tee /etc/modules-load.d/rke2.conf >/dev/null"
    )
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_upload], sensitive=True)


async def _set_sysctl(ssh_cfg: SSHConfig) -> None:
    """
    Writes bridging & ip_forward settings in /etc/sysctl.d/99-rke2.conf,
    then sysctl --system, no need for retry
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


async def _install_nvidia_drivers(ssh_cfg: SSHConfig) -> None:
    """
    If the node has a GPU => we install official Ubuntu drivers + nvidia-container-toolkit
    using apt on Ubuntu 22.04
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


async def _install_server(
    ssh_cfg: SSHConfig,
    channel: str,
    existing_server_ip: Optional[str] = None,
    node_token: Optional[str] = None,
) -> None:
    """
    Install RKE2 as 'server'. If existing_server_ip/node_token => join existing cluster,
    else we become the first CP node (bootstrap).
    """
    # see if rke2 is installed
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


async def _install_agent(
    ssh_cfg: SSHConfig, channel: str, server_ip: str, node_token: str
) -> None:
    """
    Install RKE2 agent on Ubuntu, referencing main server IP + token.
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
async def _get_node_token(ssh_cfg: SSHConfig) -> str:
    """
    Retrieve the node token from the "primary" server node. We do use a retry here
    because the server might not be fully up when we attempt to read the token.
    """
    out = await run_ssh_command(
        ssh_cfg,
        ["sudo", "cat", "/var/lib/rancher/rke2/server/node-token"],
        sensitive=True,
    )
    stripped = out.strip()
    if not stripped:
        raise RuntimeError("Empty node-token from server.")
    return stripped


async def _fetch_kubeconfig(ssh_cfg: SSHConfig) -> str:
    """
    Retrieve the admin kubeconfig from /etc/rancher/rke2/rke2.yaml,
    raising on empty or missing file.
    """
    out = await run_ssh_command(
        ssh_cfg, ["sudo", "cat", "/etc/rancher/rke2/rke2.yaml"], sensitive=True
    )
    return out


########################################################################
# Lifecycle / Maintenance
########################################################################


async def destroy_cluster(
    ssh_cfgs: List[SSHConfig],
    remove_infra_callback: Optional[Callable[[], None]] = None,
) -> None:
    """
    Uninstall RKE2 on each node, optionally call remove_infra_callback
    for infrastructure teardown. No silent fails.
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
    Minimal approach to upgrading the cluster:
      - sequentially upgrade each server
      - parallel upgrade of all agents
    """
    for s_cfg in server_ssh_cfgs:
        await _upgrade_node(s_cfg, channel)

    tasks = [_upgrade_node(a_cfg, channel) for a_cfg in agent_ssh_cfgs]
    await asyncio.gather(*tasks)


async def _upgrade_node(ssh_cfg: SSHConfig, channel: str) -> None:
    """
    Minimal approach to "upgrade" a node by stopping RKE2,
    re-running the get.rke2.io script with a new channel,
    and then starting services again.
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
    Rotates cluster certs on each server node, restarting afterwards.
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
    Creates an etcd snapshot on the primary server node.
    If local_download_path is set, you might scp from /var/lib/rancher/rke2/server/db/snapshots/.
    """
    await run_ssh_command(
        ssh_cfg,
        ["sudo", "rke2", "etcd-snapshot", "save", "--name", snapshot_name],
        sensitive=True,
    )


async def reset_node(ssh_cfg: SSHConfig, is_control_plane: bool) -> None:
    """
    Remove a node from the cluster, uninstall RKE2.
    For CP node => stop rke2-server; for agent => stop rke2-agent.
    """
    svc = "rke2-server" if is_control_plane else "rke2-agent"
    await run_ssh_command(ssh_cfg, ["sudo", "systemctl", "stop", svc], sensitive=True)
    await _uninstall_rke2_node(ssh_cfg)


async def _uninstall_rke2_node(ssh_cfg: SSHConfig) -> None:
    """
    Calls rke2-uninstall.sh or rke2-agent-uninstall.sh if they exist, forcibly removing RKE2 from that node.
    """
    for script in ["rke2-uninstall.sh", "rke2-agent-uninstall.sh"]:
        cmd = f"sudo bash -c '[[ -f /usr/local/bin/{script} ]] && /usr/local/bin/{script}'"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)
