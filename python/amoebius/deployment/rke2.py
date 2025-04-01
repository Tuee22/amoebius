"""
amoebius/deployment/rke2.py

Implements an idempotent RKE2 cluster deployment on Ubuntu 22.04 using apt-based commands.
All ephemeral SSH usage is in amoebius.utils.ssh, and Vault-based SSH config retrieval 
is from amoebius.secrets.ssh. We support multiple control-plane nodes for HA.

We do not return RKE2Credentials from deploy_rke2_cluster; instead we store them in Vault
using secrets/rke2.py.
"""

from __future__ import annotations

from typing import Optional, Dict, List, Callable
import textwrap
import asyncio

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
    Deploy an RKE2 cluster across all groups, with a multi-CP approach for the group 'control_plane_group'.

    Steps:
      1) Prepare all VMs (swap off, sysctl, etc.)
      2) For each instance in 'control_plane_group', install RKE2 as a server:
         - The first CP node becomes the "bootstrap" node, forming the cluster
         - We fetch its node token
         - Additional CP nodes also run 'INSTALL_RKE2_TYPE=server', referencing the same node token + server IP
      3) All non-CP groups become agents, referencing the first CP node's private IP + token
      4) We gather final credentials (kubeconfig from the first CP node, the join token,
         plus each CP node's vault path), and store them in Vault at credentials_vault_path.

    Args:
      rke2_output: Flattened instance data
      control_plane_group: The name of the group holding the CP nodes
      vault_client: For retrieving SSH config and for storing final RKE2 creds
      credentials_vault_path: Where we store the final RKE2Credentials in Vault
      install_channel: e.g. 'stable', controls which channel RKE2 uses

    Returns:
      None. We store the final RKE2Credentials in Vault via secrets/rke2.py
    """
    # 1) Prepare all VMs
    prep_tasks = [
        _prepare_single_vm(inst, vault_client)
        for grp, insts in rke2_output.instances.items()
        for inst in insts
    ]
    await asyncio.gather(*prep_tasks)

    # 2) Multi-CP approach: the "first" node in the group is the bootstrap node
    cp_list = rke2_output.instances.get(control_plane_group, [])
    if not cp_list:
        raise ValueError(f"No instances in control_plane_group '{control_plane_group}'")

    bootstrap_cp = cp_list[0]
    ssh_bootstrap = await _retrieve_ssh_cfg(bootstrap_cp, vault_client)
    await _install_server(ssh_bootstrap, install_channel)
    token = await _get_node_token(ssh_bootstrap)

    # If more CP nodes beyond the first => also servers
    # They join referencing the bootstrap node as the "server" IP
    if len(cp_list) > 1:
        join_tasks = []
        for cp_node in cp_list[1:]:
            node_ssh = await _retrieve_ssh_cfg(cp_node, vault_client)
            join_tasks.append(
                _install_server(
                    node_ssh,
                    install_channel,
                    existing_server_ip=bootstrap_cp.private_ip,
                    node_token=token,
                )
            )
        await asyncio.gather(*join_tasks)

    # 3) Agents = any instance not in the CP group
    agent_tasks = []
    for grp, insts in rke2_output.instances.items():
        if grp == control_plane_group:
            continue
        for inst in insts:
            node_ssh = await _retrieve_ssh_cfg(inst, vault_client)
            agent_tasks.append(
                _install_agent(
                    node_ssh,
                    install_channel,
                    server_ip=bootstrap_cp.private_ip,
                    node_token=token,
                )
            )
    await asyncio.gather(*agent_tasks)

    # 4) Gather final credentials from the first CP node, store in Vault
    kubeconfig = await _fetch_kubeconfig(ssh_bootstrap)
    # We'll gather CP node vault_paths for 'control_plane_ssh' list
    cp_paths = [cp.vault_path for cp in cp_list]
    creds = RKE2Credentials(
        kubeconfig=kubeconfig, join_token=token, control_plane_ssh=cp_paths
    )
    await save_rke2_credentials(vault_client, credentials_vault_path, creds)


async def _prepare_single_vm(
    instance: RKE2Instance, vault_client: AsyncVaultClient
) -> None:
    """
    Retrieve the instance's SSH config from Vault, then run OS-level prep commands:
     - disable swap
     - load kernel modules (overlay, br_netfilter)
     - set sysctl for bridging
     - set up nvidia drivers if instance.has_gpu
    """
    ssh_cfg = await _retrieve_ssh_cfg(instance, vault_client)
    await disable_swap(ssh_cfg)
    await load_kernel_modules(ssh_cfg)
    await _set_sysctl(ssh_cfg)
    await _setup_selinux_ubuntu(ssh_cfg)  # no yum, assume ubuntu
    if instance.has_gpu:
        await _install_nvidia_drivers(ssh_cfg)


async def _retrieve_ssh_cfg(
    instance: RKE2Instance, vault_client: AsyncVaultClient
) -> SSHConfig:
    """
    Use secrets.ssh.get_ssh_config to fetch from Vault. This also does ephemeral-based
    accept-new if host_keys are missing.
    """
    from amoebius.secrets.ssh import get_ssh_config

    return await get_ssh_config(
        vault_client, instance.vault_path, tofu_if_missing_host_keys=True
    )


@async_retry(retries=3, delay=1.0)
async def _set_sysctl(ssh_cfg: SSHConfig) -> None:
    """
    Writes a small snippet to /etc/sysctl.d/99-rke2.conf enabling bridging, ip_forward,
    then runs `sudo sysctl --system`. This ensures bridging is properly recognized even after reboot.
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


@async_retry(retries=3, delay=1.0)
async def _setup_selinux_ubuntu(ssh_cfg: SSHConfig) -> None:
    """
    On Ubuntu, SELinux is typically permissive or disabled by default, but we ensure
    the rke2-selinux package is not needed for apt-based Ubuntu. We'll remain consistent
    with the approach that RKE2 does not rely on SELinux here.
    This function is mostly a no-op for Ubuntu, but we keep it for parity with prior logic.
    """
    # We'll do a short check or do nothing, no silent fail.
    # Possibly we can check if selinux is installed.
    # We'll not do a 'yum' approach since user wants ubuntu 22.04.
    script = textwrap.dedent(
        """\
    #!/usr/bin/env bash
    set -eux
    echo "Ubuntu 22.04 => skipping SELinux package step."
    """
    )
    enc = script.encode("utf-8").hex()
    cmd = f"echo '{enc}' | xxd -r -p | sudo bash -s"
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)


@async_retry(retries=3, delay=1.0)
async def _install_nvidia_drivers(ssh_cfg: SSHConfig) -> None:
    """
    If the node has a GPU => we install the official Ubuntu drivers and
    nvidia-container-toolkit using apt on Ubuntu 22.04, ensuring it persists after reboot.
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

    # enable containerd with nvidia runtime
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


@async_retry(retries=3, delay=1.0)
async def _install_server(
    ssh_cfg: SSHConfig,
    channel: str,
    existing_server_ip: Optional[str] = None,
    node_token: Optional[str] = None,
) -> None:
    """
    Install RKE2 as a 'server' on Ubuntu. If existing_server_ip/node_token provided,
    we join an existing cluster referencing the known server IP and token.

    If no existing_server_ip => this node becomes the bootstrap node (the first CP).
    """
    # see if rke2 installed
    try:
        await run_ssh_command(ssh_cfg, ["which", "rke2"], sensitive=True)
    except Exception:
        # not installed => do so
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
        # RKE2 is installed => ensure server is enabled + started
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "enable", "rke2-server"], sensitive=True
        )
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "start", "rke2-server"], sensitive=True
        )

    if existing_server_ip and node_token:
        # create /etc/rancher/rke2/config.yaml referencing the existing cluster
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
        # restart
        await run_ssh_command(
            ssh_cfg, ["sudo", "systemctl", "restart", "rke2-server"], sensitive=True
        )


@async_retry(retries=3, delay=1.0)
async def _install_agent(
    ssh_cfg: SSHConfig, channel: str, server_ip: str, node_token: str
) -> None:
    """
    Install RKE2 agent on Ubuntu. We reference the main server IP + token to join.

    The effect of editing /etc/rancher/rke2/config.yaml + systemctl enable is persistent across reboots.
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

    # write config
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
    # restart
    await run_ssh_command(
        ssh_cfg, ["sudo", "systemctl", "restart", "rke2-agent"], sensitive=True
    )


@async_retry(retries=30, delay=2.0)
async def _get_node_token(ssh_cfg: SSHConfig) -> str:
    """
    Retrieves the node token from the primary server node. This is used for
    subsequent CP nodes and agents to join the cluster.

    We retry multiple times if the file isn't present yet (the server may still be starting).
    """
    raw = await run_ssh_command(
        ssh_cfg,
        ["sudo", "cat", "/var/lib/rancher/rke2/server/node-token"],
        sensitive=True,
    )
    stripped = raw.strip()
    if not stripped:
        raise RuntimeError("Empty node-token from the server node.")
    return stripped


async def _fetch_kubeconfig(ssh_cfg: SSHConfig) -> str:
    """
    Retrieve the admin kubeconfig from /etc/rancher/rke2/rke2.yaml,
    ensuring it's present. This is used for post-deploy operations.
    """
    out = await run_ssh_command(
        ssh_cfg, ["sudo", "cat", "/etc/rancher/rke2/rke2.yaml"], sensitive=True
    )
    return out


################################ LIFECYCLE/MAINTENANCE ################################


async def destroy_cluster(
    ssh_cfgs: List[SSHConfig],
    remove_infra_callback: Optional[Callable[[], None]] = None,
) -> None:
    """
    Uninstall RKE2 on each node, optionally call remove_infra_callback for infra removal.
    No silent fails: we raise if commands fail.
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


@async_retry(retries=3, delay=2.0)
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
    Rotates cluster certs on each server node, restarting the server each time.
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
    Create an etcd snapshot on the primary server node. If local_download_path is set,
    you might scp it to local, but that's not shown here.
    """
    await run_ssh_command(
        server_ssh_cfg,
        ["sudo", "rke2", "etcd-snapshot", "save", "--name", snapshot_name],
        sensitive=True,
    )
    # if local_download_path => scp from /var/lib/rancher/rke2/server/db/snapshots/


async def reset_node(ssh_cfg: SSHConfig, is_control_plane: bool) -> None:
    """
    Remove a node from the cluster, uninstall RKE2.
    For CP node => stop rke2-server; for agent => stop rke2-agent.
    """
    svc = "rke2-server" if is_control_plane else "rke2-agent"
    await run_ssh_command(ssh_cfg, ["sudo", "systemctl", "stop", svc], sensitive=True)
    await _uninstall_rke2_node(ssh_cfg)


@async_retry(retries=3, delay=1.0)
async def _uninstall_rke2_node(ssh_cfg: SSHConfig) -> None:
    """
    Calls rke2-uninstall.sh or rke2-agent-uninstall.sh if they exist,
    forcibly removing RKE2 from that node.
    """
    for script in ["rke2-uninstall.sh", "rke2-agent-uninstall.sh"]:
        cmd = f"sudo bash -c '[[ -f /usr/local/bin/{script} ]] && /usr/local/bin/{script}'"
        await run_ssh_command(ssh_cfg, ["bash", "-c", cmd], sensitive=True)


async def disable_swap(ssh_cfg: SSHConfig) -> None:
    """
    Disables swap permanently and comments out any swap lines in /etc/fstab on Ubuntu 22.04.
    This ensures K8s best practices (swap must be off).
    Raises a CommandError on failure, no silent ignoring.
    """
    await run_ssh_command(ssh_cfg, ["sudo", "swapoff", "-a"], sensitive=True)

    # Remove or comment out swap lines from fstab
    # no '|| true' => raise if sed fails
    sed_cmd = r"sudo sed -i.bak '/\\sswap\\s/s/^/#/g' /etc/fstab"
    await run_ssh_command(ssh_cfg, ["bash", "-c", sed_cmd], sensitive=True)


async def load_kernel_modules(ssh_cfg: SSHConfig) -> None:
    """
    Loads kernel modules required for bridging (br_netfilter) and overlay fs if not present,
    ensuring changes persist across reboots by adding them to /etc/modules-load.d.
    Raises CommandError on any failure.
    """
    for mod in ["overlay", "br_netfilter"]:
        await run_ssh_command(ssh_cfg, ["sudo", "modprobe", mod], sensitive=True)

    # Also ensure they're listed in /etc/modules-load.d/rke2.conf so they load at reboot
    modules_conf = "overlay\nbr_netfilter\n"
    encoded = modules_conf.encode("utf-8").hex()
    cmd_upload = f"echo '{encoded}' | xxd -r -p | sudo tee /etc/modules-load.d/rke2.conf >/dev/null"
    await run_ssh_command(ssh_cfg, ["bash", "-c", cmd_upload], sensitive=True)
