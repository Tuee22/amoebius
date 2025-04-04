"""
Provides an idempotent RKE2 cluster deployment on Ubuntu 22.04 (APT-based).
Ephemeral SSH usage is in amoebius.utils.ssh, Vault-based SSH config retrieval
is from amoebius.secrets.ssh. We support multi-control-plane (HA) if multiple
nodes exist in the "control_plane_group."

We store final RKE2Credentials in Vault (via secrets/rke2.py), not returning them.
All VM config steps are idempotent, and we do a reboot at the end of VM prep
to ensure changes persist post-reboot. Then we wait for SSH to come back.

**Key changes**:
- We now allow the reboot command to exit with code 255 (expected upon SSH termination).
- The `_wait_for_ssh` function uses `@async_retry` for cleaner retry logic.

Usage example:
  1) Prepare instances => reboot => re-connect
  2) Install RKE2 control-plane on first node => get token
  3) Install RKE2 control-plane on subsequent nodes => join via token
  4) Install RKE2 agents => join via token
  5) Fetch kubeconfig => store RKE2Credentials in Vault
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
from amoebius.utils.async_command_runner import CommandError


async def deploy_rke2_cluster(
    rke2_output: RKE2InstancesOutput,
    control_plane_group: str,
    vault_client: AsyncVaultClient,
    credentials_vault_path: str,
    install_channel: str = "stable",
) -> None:
    """
    Deploys a multi-node RKE2 cluster on Ubuntu 22.04. All steps are idempotent:
      1) Prepare each VM (disable swap, load modules, configure sysctl, install GPU drivers).
         - Then reboot, allowing exit code 255 from SSH, and wait for SSH to come back.
      2) The first node in control_plane_group is the bootstrap CP (server).
      3) Any additional CP nodes join using the bootstrap node's token/IP.
      4) All other nodes become agents using the same token.
      5) We retrieve the kubeconfig from the bootstrap node and store final RKE2Credentials in Vault.

    Args:
        rke2_output: Flattened instance data including IPs and Vault SSH references.
        control_plane_group: Name of the group containing CP nodes.
        vault_client: The Vault client for SSH retrieval and final credential storage.
        credentials_vault_path: Where we store RKE2Credentials in Vault.
        install_channel: e.g. "stable" or "latest" for the RKE2 install script.
    """

    async def _prepare_instance(inst: RKE2Instance) -> None:
        """
        Handle base OS configuration for a single VM:
          - Disable swap permanently.
          - Load required kernel modules.
          - Configure sysctl for bridging, IP-forwarding.
          - If has_gpu => install GPU drivers.
          - Reboot, accepting code 255 (SSH close) as normal.
          - Then wait for SSH to become available again.
        """
        ssh_config: SSHConfig = await get_ssh_config(
            vault_client=vault_client,
            path=inst.vault_path,
            tofu_if_missing_host_keys=True,
        )

        # Basic VM config
        await _disable_swap(ssh_config=ssh_config)
        await _load_kernel_modules(ssh_config=ssh_config)
        await _configure_sysctl(ssh_config=ssh_config)

        # GPU-specific config
        if inst.has_gpu:
            await _install_nvidia_drivers(ssh_config=ssh_config)

        # Reboot and allow code 255 to be treated as success
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "reboot", "now"],
            sensitive=True,
            retries=0,
            retry_delay=0.0,
            successful_return_codes=[
                0,
                255,
            ],  # 255 is normal for abrupt SSH termination
        )
        await _wait_for_ssh(ssh_config=ssh_config)

    # 1) Prepare all VMs concurrently
    all_preps = [
        _prepare_instance(inst)
        for group_insts in rke2_output.instances.values()
        for inst in group_insts
    ]
    await asyncio.gather(*all_preps)

    # 2) multi-CP => first node is bootstrap
    cp_list: List[RKE2Instance] = rke2_output.instances.get(control_plane_group, [])
    if not cp_list:
        raise ValueError(f"No instances found in group '{control_plane_group}'")

    bootstrap_cp = cp_list[0]
    bootstrap_ssh = await get_ssh_config(
        vault_client=vault_client,
        path=bootstrap_cp.vault_path,
        tofu_if_missing_host_keys=True,
    )
    await _install_server(ssh_config=bootstrap_ssh, channel=install_channel)
    token = await _get_node_token(ssh_config=bootstrap_ssh)

    # 3) Additional CP nodes
    if len(cp_list) > 1:

        async def _join_cp_server(cp_inst: RKE2Instance) -> None:
            cp_ssh: SSHConfig = await get_ssh_config(
                vault_client=vault_client,
                path=cp_inst.vault_path,
                tofu_if_missing_host_keys=True,
            )
            await _install_server(
                ssh_config=cp_ssh,
                channel=install_channel,
                existing_server_ip=bootstrap_cp.private_ip,
                node_token=token,
            )

        addl_cp = [_join_cp_server(n) for n in cp_list[1:]]
        await asyncio.gather(*addl_cp)

    # 4) Agents => all non-CP
    agent_insts = [
        inst
        for grp_name, grp_insts in rke2_output.instances.items()
        for inst in grp_insts
        if grp_name != control_plane_group
    ]

    async def _join_agent(a_inst: RKE2Instance) -> None:
        agent_ssh: SSHConfig = await get_ssh_config(
            vault_client=vault_client,
            path=a_inst.vault_path,
            tofu_if_missing_host_keys=True,
        )
        await _install_agent(
            ssh_config=agent_ssh,
            channel=install_channel,
            server_ip=bootstrap_cp.private_ip,
            node_token=token,
        )

    agent_tasks = [_join_agent(ai) for ai in agent_insts]
    await asyncio.gather(*agent_tasks)

    # 5) Gather final credentials => store in vault
    kubeconfig: str = await _fetch_kubeconfig(ssh_config=bootstrap_ssh)
    cp_vault_paths: List[str] = [cp.vault_path for cp in cp_list]
    creds = RKE2Credentials(
        kubeconfig=kubeconfig,
        join_token=token,
        control_plane_ssh_vault_path=cp_vault_paths,
    )
    await save_rke2_credentials(
        vault_client=vault_client, vault_path=credentials_vault_path, creds=creds
    )


async def _disable_swap(ssh_config: SSHConfig) -> None:
    """
    Permanently disable swap:
      - swapoff -a
      - comment out swap lines in /etc/fstab
    Safe if already disabled.
    """
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "swapoff", "-a"],
        sensitive=True,
    )
    sed_cmd = r"sudo sed -i.bak '/\sswap\s/s/^/#/g' /etc/fstab"
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["bash", "-c", sed_cmd],
        sensitive=True,
    )


async def _load_kernel_modules(ssh_config: SSHConfig) -> None:
    """
    Ensure br_netfilter, overlay modules are loaded, and persist in /etc/modules-load.d/rke2.conf
    """
    for mod in ["overlay", "br_netfilter"]:
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "modprobe", mod],
            sensitive=True,
        )

    modules_conf = "overlay\nbr_netfilter\n"
    enc = modules_conf.encode("utf-8").hex()
    cmd_upload = (
        f"echo '{enc}' | xxd -r -p | sudo tee /etc/modules-load.d/rke2.conf >/dev/null"
    )
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["bash", "-c", cmd_upload],
        sensitive=True,
    )


async def _configure_sysctl(ssh_config: SSHConfig) -> None:
    """
    Set up net.bridge.bridge-nf-call-iptables=1, net.ipv4.ip_forward=1, etc.
    Overwrite /etc/sysctl.d/99-rke2.conf and apply sysctl --system.
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
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["bash", "-c", cmd_upload],
        sensitive=True,
    )
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "sysctl", "--system"],
        sensitive=True,
    )


async def _install_nvidia_drivers(ssh_config: SSHConfig) -> None:
    """
    Install official Ubuntu GPU drivers + nvidia-container-toolkit if not present.
    Safe to re-run if already installed.
    """
    try:
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["which", "nvidia-smi"],
            sensitive=True,
        )
    except CommandError:
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
        await run_ssh_command(
            ssh_config=ssh_config, remote_command=["bash", "-c", cmd], sensitive=True
        )

    try:
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["which", "nvidia-container-runtime"],
            sensitive=True,
        )
    except CommandError:
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
        await run_ssh_command(
            ssh_config=ssh_config, remote_command=["bash", "-c", cmd], sensitive=True
        )

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
    await run_ssh_command(
        ssh_config=ssh_config, remote_command=["bash", "-c", cmd2], sensitive=True
    )
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "systemctl", "restart", "containerd"],
        sensitive=True,
    )


async def _install_server(
    ssh_config: SSHConfig,
    channel: str,
    existing_server_ip: Optional[str] = None,
    node_token: Optional[str] = None,
) -> None:
    """
    Install RKE2 as 'server'. If existing_server_ip and node_token are provided,
    join existing cluster. Otherwise, become the first CP node.
    Re-checking is safe if RKE2 is already installed.
    """
    try:
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["which", "rke2"],
            sensitive=True,
        )
    except CommandError:
        # Not installed => install fresh
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
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["bash", "-c", cmd_install],
            sensitive=True,
        )
    else:
        # Already present => ensure it is enabled and started
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "systemctl", "enable", "rke2-server"],
            sensitive=True,
        )
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "systemctl", "start", "rke2-server"],
            sensitive=True,
        )

    # If we have an existing cluster to join, rewrite /etc/rancher/rke2/config.yaml
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
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["bash", "-c", cmd_upload],
            sensitive=True,
        )
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "systemctl", "restart", "rke2-server"],
            sensitive=True,
        )


async def _install_agent(
    ssh_config: SSHConfig, channel: str, server_ip: str, node_token: str
) -> None:
    """
    Install RKE2 as an 'agent' node, referencing the main server IP and token.
    Safe to rerun if already installed.
    """
    try:
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["which", "rke2"],
            sensitive=True,
        )
    except CommandError:
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
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["bash", "-c", cmd_install],
            sensitive=True,
        )
    else:
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "systemctl", "enable", "rke2-agent"],
            sensitive=True,
        )
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "systemctl", "start", "rke2-agent"],
            sensitive=True,
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
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["bash", "-c", cmd_upload],
        sensitive=True,
    )
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "systemctl", "restart", "rke2-agent"],
        sensitive=True,
    )


@async_retry(retries=30, delay=2.0)
async def _get_node_token(ssh_config: SSHConfig) -> str:
    """
    Retrieve the node token from the primary (bootstrap) server, with up to 30 retries
    in case the file does not exist yet. If still empty, raises RuntimeError.
    """
    out = await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "cat", "/var/lib/rancher/rke2/server/node-token"],
        sensitive=True,
    )
    token_val = out.strip()
    if not token_val:
        raise RuntimeError("Empty node-token from server node.")
    return token_val


async def _fetch_kubeconfig(ssh_config: SSHConfig) -> str:
    """
    Fetch /etc/rancher/rke2/rke2.yaml for the admin kubeconfig.
    Raises CommandError if missing or empty.
    """
    result = await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "cat", "/etc/rancher/rke2/rke2.yaml"],
        sensitive=True,
    )
    return result


@async_retry(retries=30, delay=5.0)
async def _wait_for_ssh(ssh_config: SSHConfig) -> None:
    """
    After issuing a reboot, wait for SSH to become available again.
    The @async_retry wrapper tries up to 30 times, with 5s delay each,
    re-raising the exception if still unreachable.
    """
    # A simple 'true' command indicates a successful SSH connection.
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["true"],
        sensitive=True,
        retries=1,
        retry_delay=1.0,
    )


####################################################################
# Lifecycle / Maintenance
####################################################################


async def destroy_cluster(
    ssh_cfgs: List[SSHConfig],
    remove_infra_callback: Optional[Callable[[], None]] = None,
) -> None:
    """
    Uninstall RKE2 from each node in ssh_cfgs, optionally call remove_infra_callback.
    Idempotent if repeated.
    """
    tasks = [_uninstall_rke2_node(ssh_config=cfg) for cfg in ssh_cfgs]
    await asyncio.gather(*tasks)
    if remove_infra_callback is not None:
        remove_infra_callback()


async def upgrade_cluster(
    server_ssh_cfgs: List[SSHConfig],
    agent_ssh_cfgs: List[SSHConfig],
    channel: str = "stable",
) -> None:
    """
    Minimal approach to cluster upgrade:
      - sequentially upgrade all servers
      - then concurrently upgrade all agents
    """
    for s_cfg in server_ssh_cfgs:
        await _upgrade_node(ssh_config=s_cfg, channel=channel)

    tasks = [
        _upgrade_node(ssh_config=a_cfg, channel=channel) for a_cfg in agent_ssh_cfgs
    ]
    await asyncio.gather(*tasks)


async def rotate_certs(server_ssh_cfgs: List[SSHConfig]) -> None:
    """
    Rotate cluster certs on each server node, forcing a restart.
    """
    for s_cfg in server_ssh_cfgs:
        await run_ssh_command(
            ssh_config=s_cfg,
            remote_command=["sudo", "rke2", "certificate", "rotate", "--force"],
            sensitive=True,
        )
        await run_ssh_command(
            ssh_config=s_cfg,
            remote_command=["sudo", "systemctl", "restart", "rke2-server"],
            sensitive=True,
        )


async def backup_cluster_state(
    ssh_config: SSHConfig,
    snapshot_name: str = "on-demand",
    local_download_path: Optional[str] = None,
) -> None:
    """
    Create an etcd snapshot on the CP node. If local_download_path is specified,
    user can scp it from /var/lib/rancher/rke2/server/db/snapshots.
    """
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=[
            "sudo",
            "rke2",
            "etcd-snapshot",
            "save",
            "--name",
            snapshot_name,
        ],
        sensitive=True,
    )
    # If needed, scp from /var/lib/rancher/rke2/server/db/snapshots.


async def reset_node(ssh_config: SSHConfig, is_control_plane: bool) -> None:
    """
    Remove a node from the cluster by stopping the relevant service
    then uninstalling RKE2.
    """
    svc = "rke2-server" if is_control_plane else "rke2-agent"
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "systemctl", "stop", svc],
        sensitive=True,
    )
    await _uninstall_rke2_node(ssh_config=ssh_config)


async def _uninstall_rke2_node(ssh_config: SSHConfig) -> None:
    """
    Runs rke2-uninstall.sh or rke2-agent-uninstall.sh if they exist, forcibly removing RKE2.
    No-op if already removed.
    """
    for script in ["rke2-uninstall.sh", "rke2-agent-uninstall.sh"]:
        cmd = f"sudo bash -c '[[ -f /usr/local/bin/{script} ]] && /usr/local/bin/{script}'"
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["bash", "-c", cmd],
            sensitive=True,
        )


async def _upgrade_node(ssh_config: SSHConfig, channel: str) -> None:
    """
    Stop RKE2, re-run the official installer for the new channel, and restart. Idempotent if already up to date.
    """
    await run_ssh_command(
        ssh_config=ssh_config,
        remote_command=["sudo", "systemctl", "stop", "rke2-server", "rke2-agent"],
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
        ssh_config=ssh_config,
        remote_command=["bash", "-c", " ".join(upgrade_cmd)],
        sensitive=True,
    )
    for svc in ["rke2-server", "rke2-agent"]:
        await run_ssh_command(
            ssh_config=ssh_config,
            remote_command=["sudo", "systemctl", "start", svc],
            sensitive=True,
        )
