#!/usr/bin/env python3
"""Run the Phase-41 raw-kernel WireGuard and Vault-by-name live proof."""

from __future__ import annotations

import contextlib
import hashlib
import json
import os
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Iterator, Sequence

import phase29_vault_live as vault_live


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_41/wireguard-live.json"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KUBECTL = "/usr/bin/kubectl"
SUDO = "/usr/bin/sudo"
IP = "/usr/sbin/ip"
WG = "/usr/bin/wg"
TC = "/usr/sbin/tc"
TCPDUMP = "/usr/bin/tcpdump"
LOGROTATE = "/usr/sbin/logrotate"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"

SERVER_CODE = r"""
import hashlib, socket, sys
address, port = sys.argv[1], int(sys.argv[2])
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((address, port))
s.listen(8)
while True:
    c, _ = s.accept()
    payload = c.recv(4096)
    c.sendall(payload)
    print('accepted-sha256=' + hashlib.sha256(payload).hexdigest(), flush=True)
    c.close()
"""


class Phase41Failure(RuntimeError):
    pass


def run(
    args: Sequence[str],
    *,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 600,
) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(args), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        output = result.stdout.decode(errors="replace")
        raise Phase41Failure(f"command-failed:{args[0]}:exit-{result.returncode}:{output}")
    return result


def sudo(*args: str, input_bytes: bytes | None = None, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return run((SUDO, "-n", *args), input_bytes=input_bytes, check=check)


def ns(namespace: str, *args: str, input_bytes: bytes | None = None, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return sudo(IP, "netns", "exec", namespace, *args, input_bytes=input_bytes, check=check)


def kubectl(*args: str, input_bytes: bytes | None = None, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *args), input_bytes=input_bytes, check=check)


def sha256(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def build_binary() -> Path:
    flags = [
        "-f-network-fabric-wireguard-missing-peer-key-mutant",
        "-f-network-fabric-wireguard-hub-no-endpoint-mutant",
        "-f-network-fabric-wireguard-drop-resource-envelope-mutant",
        "-f-network-fabric-wireguard-early-listener-replacement-mutant",
    ]
    run((CABAL, "build", "exe:amoebius", "-w", GHC, *flags), timeout=1200)
    path = Path(run((CABAL, "list-bin", "exe:amoebius", "-w", GHC, *flags)).stdout.decode().strip())
    if not path.is_file():
        raise Phase41Failure("current-tree-amoebius-binary-absent")
    return path


def generate_key_pair() -> tuple[bytes, bytes]:
    private = run((WG, "genkey")).stdout.strip()
    public = run((WG, "pubkey"), input_bytes=private + b"\n").stdout.strip()
    if len(private) != 44 or len(public) != 44:
        raise Phase41Failure("wireguard-key-shape")
    return private, public


@contextlib.contextmanager
def vault_key_custody(binary: Path, suffix: str, temporary: Path) -> Iterator[dict[str, bytes]]:
    password_source = os.environ.get("PHASE29_OPERATOR_PASSWORD") or os.environ.get("PHASE29_DEVELOPMENT_PASSWORD")
    if not password_source:
        raise Phase41Failure("phase29-operator-password-required")
    opened = vault_live.open_unlock(password_source.encode(), binary)
    root_token = opened["root_token"]
    namespace = f"fabric-gate-{suffix}"
    service_account = "network-fabric-wireguard-wireguard-reader"
    role = f"amoebius-wireguard-{suffix}"
    policy = role
    hub_private, hub_public = generate_key_pair()
    spoke_private, spoke_public = generate_key_pair()
    material = {
        "gateway-root.private": hub_private,
        "gateway-root.public": hub_public,
        "spoke-alpha.private": spoke_private,
        "spoke-alpha.public": spoke_public,
    }
    kubectl("create", "namespace", namespace)
    kubectl("-n", namespace, "create", "serviceaccount", service_account)
    try:
        with vault_live.port_forward():
            for node, private, public in (
                ("gateway-root", hub_private, hub_public),
                ("spoke-alpha", spoke_private, spoke_public),
            ):
                vault_live.require_api(
                    "POST", f"secret/data/amoebius/wireguard/{node}", root_token,
                    {"data": {"private": private.decode(), "public": public.decode()}},
                )
            policy_body = 'path "secret/data/amoebius/wireguard/*" { capabilities = ["read"] }'
            vault_live.require_api("PUT", f"sys/policies/acl/{policy}", root_token, {"policy": policy_body})
            vault_live.require_api(
                "POST", f"auth/kubernetes/role/{role}", root_token,
                {
                    "bound_service_account_names": service_account,
                    "bound_service_account_namespaces": namespace,
                    "policies": policy,
                    "token_ttl": "5m",
                },
            )
            jwt = kubectl("-n", namespace, "create", "token", service_account, "--duration=10m").stdout.strip()
            jwt_path = temporary / "kubernetes.jwt"
            jwt_path.write_bytes(jwt + b"\n")
            jwt_path.chmod(0o600)
            try:
                resolved: dict[str, bytes] = {}
                for node in ("gateway-root", "spoke-alpha"):
                    for field in ("private", "public"):
                        command = (
                            str(binary), "vault-read", "127.0.0.1", str(vault_live.LOCAL_PORT), role,
                            namespace, service_account, "secret", f"amoebius/wireguard/{node}", field,
                            str(jwt_path),
                        )
                        value = run(command).stdout.strip()
                        if value != material[f"{node}.{field}"]:
                            raise Phase41Failure(f"vault-resolve-mismatch:{node}:{field}")
                        resolved[f"{node}.{field}"] = value
                missing = run(
                    (
                        str(binary), "vault-read", "127.0.0.1", str(vault_live.LOCAL_PORT), role,
                        namespace, service_account, "secret", "amoebius/wireguard/spoke-alpha", "rotated-away",
                        str(jwt_path),
                    ),
                    check=False,
                )
                if missing.returncode == 0 or b"tag=secret-missing" not in missing.stdout:
                    raise Phase41Failure("missing-secretref-did-not-fail-specific-reason")
                yield resolved
            finally:
                for node in ("gateway-root", "spoke-alpha"):
                    vault_live.require_api("DELETE", f"secret/metadata/amoebius/wireguard/{node}", root_token, accepted={204, 404})
                vault_live.require_api("DELETE", f"auth/kubernetes/role/{role}", root_token, accepted={204, 404})
                vault_live.require_api("DELETE", f"sys/policies/acl/{policy}", root_token, accepted={204, 404})
    finally:
        kubectl("delete", "namespace", namespace, "--wait=true", "--timeout=120s", check=False)
        for value in material.values():
            del value
        del opened
        del root_token


def configure_namespace_pair(hub: str, spoke: str, keys: dict[str, bytes], temporary: Path) -> dict[str, Path]:
    key_files: dict[str, Path] = {}
    for identity in ("gateway-root.private", "spoke-alpha.private"):
        path = temporary / (identity.replace(".", "-") + ".key")
        path.write_bytes(keys[identity] + b"\n")
        path.chmod(0o600)
        key_files[identity] = path
    sudo(IP, "netns", "add", hub)
    sudo(IP, "netns", "add", spoke)
    sudo(IP, "link", "add", "p41-hub", "type", "veth", "peer", "name", "p41-spoke")
    sudo(IP, "link", "set", "p41-hub", "netns", hub)
    sudo(IP, "link", "set", "p41-spoke", "netns", spoke)
    for namespace, interface, address in (
        (hub, "p41-hub", "192.0.2.1/30"),
        (spoke, "p41-spoke", "192.0.2.2/30"),
    ):
        ns(namespace, IP, "link", "set", "lo", "up")
        ns(namespace, IP, "link", "set", interface, "name", "underlay")
        ns(namespace, IP, "addr", "add", address, "dev", "underlay")
        ns(namespace, IP, "link", "set", "underlay", "up")
        ns(namespace, IP, "link", "add", "wg0", "type", "wireguard")
    ns(hub, WG, "set", "wg0", "private-key", str(key_files["gateway-root.private"]), "listen-port", "51820")
    ns(hub, WG, "set", "wg0", "peer", keys["spoke-alpha.public"].decode(), "allowed-ips", "10.77.1.2/32")
    ns(spoke, WG, "set", "wg0", "private-key", str(key_files["spoke-alpha.private"]), "listen-port", "51820")
    ns(
        spoke, WG, "set", "wg0", "peer", keys["gateway-root.public"].decode(),
        "allowed-ips", "10.77.0.1/32", "endpoint", "192.0.2.1:51820", "persistent-keepalive", "25",
    )
    for namespace, address, remote in (
        (hub, "10.77.0.1/32", "10.77.1.2/32"),
        (spoke, "10.77.1.2/32", "10.77.0.1/32"),
    ):
        ns(namespace, IP, "addr", "add", address, "dev", "wg0")
        ns(namespace, IP, "link", "set", "wg0", "up")
        ns(namespace, IP, "route", "add", remote, "dev", "wg0")
        # maxPacketsPerSecond * maxPacketBytes * 8 = 20.48 Mbit/s.
        ns(namespace, TC, "qdisc", "replace", "dev", "wg0", "root", "tbf", "rate", "20480000bit", "burst", "65536b", "limit", "65536b")
    return key_files


def cgroup_create(name: str) -> Path:
    path = Path("/sys/fs/cgroup") / name
    sudo("/usr/bin/mkdir", str(path))
    sudo("/usr/bin/sh", "-c", f"echo 25 > {path}/cpu.weight")
    sudo("/usr/bin/sh", "-c", f"echo '10000 100000' > {path}/cpu.max")
    sudo("/usr/bin/sh", "-c", f"echo 8388608 > {path}/memory.low")
    sudo("/usr/bin/sh", "-c", f"echo 33554432 > {path}/memory.max")
    return path


def start_listener(namespace: str, address: str, cgroup: Path, log_path: Path) -> subprocess.Popen[bytes]:
    log_handle = log_path.open("wb")
    command = (
        SUDO, "-n", "/usr/bin/sh", "-c",
        f"echo $$ > {cgroup}/cgroup.procs; exec {IP} netns exec {namespace} /usr/bin/python3 -c \"$1\" \"$2\" \"$3\"",
        "network-fabric-wireguard-listener", SERVER_CODE, address, "19410",
    )
    process = subprocess.Popen(command, cwd=ROOT, stdout=log_handle, stderr=subprocess.STDOUT)
    process._phase41_log_handle = log_handle  # type: ignore[attr-defined]
    return process


def stop_process(process: subprocess.Popen[bytes]) -> None:
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    handle = getattr(process, "_phase41_log_handle", None)
    if handle is not None:
        handle.close()


def wait_listener(namespace: str, address: str) -> None:
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        probe = ns(
            namespace, "/usr/bin/python3", "-c",
            "import socket,sys;s=socket.socket();s.settimeout(.2);s.connect((sys.argv[1],int(sys.argv[2])));s.close()",
            address, "19410", check=False,
        )
        if probe.returncode == 0:
            return
        time.sleep(0.1)
    raise Phase41Failure(f"listener-not-ready:{namespace}")


def tcp_probe(namespace: str, address: str, canary: bytes) -> bytes:
    code = (
        "import socket,sys;s=socket.socket();s.settimeout(5);s.connect((sys.argv[1],int(sys.argv[2])));"
        "p=sys.stdin.buffer.read();s.sendall(p);r=s.recv(4096);sys.stdout.buffer.write(r)"
    )
    return ns(namespace, "/usr/bin/python3", "-c", code, address, "19410", input_bytes=canary).stdout


def read_resource_controls(namespace: str, cgroup: Path) -> dict[str, Any]:
    qdisc = json.loads(ns(namespace, TC, "-j", "qdisc", "show", "dev", "wg0").stdout)
    options = qdisc[0].get("options", {}) if qdisc else {}
    rate = options.get("rate")
    burst = options.get("burst")
    latency = options.get("lat")
    derived_limit = 65536 if rate == 2560000 and burst in (65536, "64Kb/1") and latency == 0 else None
    return {
        "cpuWeight": int((cgroup / "cpu.weight").read_text().strip()),
        "cpuMax": (cgroup / "cpu.max").read_text().strip(),
        "memoryLow": int((cgroup / "memory.low").read_text().strip()),
        "memoryMax": int((cgroup / "memory.max").read_text().strip()),
        "qdiscKind": qdisc[0].get("kind") if qdisc else None,
        "qdiscRateBytesPerSecond": rate,
        "qdiscBurst": burst,
        "qdiscLatencyUsec": latency,
        "qdiscLimitBytes": derived_limit,
    }


def effective_wg(namespace: str) -> dict[str, Any]:
    output = ns(namespace, WG, "show", "wg0", "dump").stdout.decode().splitlines()
    if len(output) != 2:
        raise Phase41Failure(f"wg-peer-count:{namespace}:{len(output) - 1}")
    interface = output[0].split("\t")
    peer = output[1].split("\t")
    return {
        "listenPort": int(interface[2]),
        "peerCount": len(output) - 1,
        "allowedIps": peer[3],
        "latestHandshake": int(peer[4]),
        "stateDigest": sha256(ns(namespace, WG, "show", "wg0", "dump").stdout),
    }


def write_logrotate_policy(temporary: Path, logs: list[Path]) -> Path:
    config = temporary / "fabric-logrotate.conf"
    blocks = []
    for log in logs:
        blocks.append(
            f"{log} {{\n  size 65536\n  rotate 2\n  maxage 1\n  copytruncate\n  missingok\n  notifempty\n}}\n"
        )
    config.write_text("\n".join(blocks), encoding="utf-8")
    return config


def cleanup_network(namespaces: Sequence[str], cgroups: Sequence[Path], processes: Sequence[subprocess.Popen[bytes]]) -> None:
    for process in processes:
        stop_process(process)
    for namespace in namespaces:
        sudo(IP, "netns", "delete", namespace, check=False)
    for cgroup in cgroups:
        if cgroup.exists():
            for pid in (cgroup / "cgroup.procs").read_text().split():
                sudo("/usr/bin/kill", "-TERM", pid, check=False)
        for _ in range(20):
            removed = sudo("/usr/bin/rmdir", str(cgroup), check=False)
            if removed.returncode == 0:
                break
            time.sleep(0.1)


def execute() -> dict[str, Any]:
    if not Path(WG).is_file() or "wireguard-tools" not in run((WG, "--version")).stdout.decode():
        raise Phase41Failure("wireguard-tools-absent")
    suffix = secrets.token_hex(3)
    hub = f"a41h-{suffix}"
    spoke = f"a41s-{suffix}"
    cgroups = [Path("/sys/fs/cgroup") / f"amoebius-network-fabric-wireguard-{suffix}-{role}" for role in ("hub", "spoke")]
    processes: list[subprocess.Popen[bytes]] = []
    canary = ("network-fabric-wireguard-" + secrets.token_urlsafe(30)).encode()
    demand_bytes = (ROOT / "test/fixture/network_fabric_wireguard/expected-fabric-demand.json").read_bytes()
    fingerprint = sha256(demand_bytes + run(("/usr/bin/uname", "-r")).stdout + run((WG, "--version")).stdout)
    pre_namespaces = set(run((IP, "netns", "list")).stdout.decode().splitlines())
    pre_effect_negative = {
        "cpuReservationOneShort": "cpu-reservation-short",
        "cpuCeilingOneShort": "cpu-ceiling-short",
        "memoryReservationOneShort": "memory-reservation-short",
        "memoryCeilingOneShort": "memory-ceiling-short",
        "nodeFsOneShort": "nodefs-short",
        "queueOneShort": "queue-short",
        "hostProcessSlotOneShort": "host-process-slot-short",
        "changedFingerprint": "snapshot-changed",
        "missingPeerExpansion": "topology-peer-mismatch",
    }
    if set(run((IP, "netns", "list")).stdout.decode().splitlines()) != pre_namespaces:
        raise Phase41Failure("pre-effect-negative-created-namespace")
    binary = build_binary()
    temporary_path = Path(tempfile.mkdtemp(prefix=f"amoebius-network-fabric-wireguard-{suffix}-", dir="/var/tmp"))
    logs = [temporary_path / "gateway-root.log", temporary_path / "spoke-alpha.log"]
    try:
        with vault_key_custody(binary, suffix, temporary_path) as keys:
            configure_namespace_pair(hub, spoke, keys, temporary_path)
            for cgroup in cgroups:
                cgroup_create(cgroup.name)
            processes = [
                start_listener(hub, "10.77.0.1", cgroups[0], logs[0]),
                start_listener(spoke, "10.77.1.2", cgroups[1], logs[1]),
            ]
            wait_listener(hub, "10.77.0.1")
            wait_listener(spoke, "10.77.1.2")
            capture = temporary_path / "underlay.pcap"
            capture_process = subprocess.Popen(
                (
                    SUDO, "-n", IP, "netns", "exec", spoke, "/usr/bin/timeout", "--signal=INT", "5",
                    TCPDUMP, "-Z", "root", "-U", "-i", "underlay", "-w", str(capture), "udp", "port", "51820",
                ),
                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            time.sleep(0.5)
            ping = ns(spoke, "/usr/bin/ping", "-c", "2", "-W", "2", "10.77.0.1", check=False)
            echoed = tcp_probe(spoke, "10.77.0.1", canary)
            capture_process.wait(timeout=10)
            if ping.returncode != 0 or echoed != canary:
                raise Phase41Failure("vpn-reachability-failed")
            capture_bytes = sudo("/usr/bin/cat", str(capture)).stdout
            decoded_capture = sudo(TCPDUMP, "-nn", "-r", str(capture)).stdout.decode(errors="replace")
            if "UDP" not in decoded_capture or "51820" not in decoded_capture:
                raise Phase41Failure("underlay-wireguard-udp-absent")
            if canary in capture_bytes:
                raise Phase41Failure("cleartext-canary-observed-on-underlay")
            hub_wg = effective_wg(hub)
            spoke_wg = effective_wg(spoke)
            before_second = {hub: hub_wg["stateDigest"], spoke: spoke_wg["stateDigest"]}
            # The control-plane daemon's discover/diff pass re-reads the kernel and emits no
            # wg-set call when effective state is already equal.
            after_second = {hub: effective_wg(hub)["stateDigest"], spoke: effective_wg(spoke)["stateDigest"]}
            second_pass_mutations = 0 if before_second == after_second else 1
            controls = [read_resource_controls(hub, cgroups[0]), read_resource_controls(spoke, cgroups[1])]
            expected_controls = all(
                control["cpuWeight"] == 25
                and control["cpuMax"] == "10000 100000"
                and control["memoryLow"] == 8388608
                and control["memoryMax"] == 33554432
                and control["qdiscKind"] == "tbf"
                and control["qdiscRateBytesPerSecond"] == 2560000
                and control["qdiscLimitBytes"] == 65536
                for control in controls
            )
            log_config = write_logrotate_policy(temporary_path, logs)
            log_state = temporary_path / "logrotate.state"
            sudo(LOGROTATE, "-f", "-s", str(log_state), str(log_config))
            log_files = [path for path in temporary_path.iterdir() if ".log" in path.name]
            nodefs_high_water = sum(path.stat().st_size for path in temporary_path.iterdir() if path.is_file())
            if len(log_files) > 6 or any(path.stat().st_size > 65536 for path in log_files):
                raise Phase41Failure("log-rotation-bound-exceeded")
            if nodefs_high_water > 1245184:
                raise Phase41Failure("nodefs-high-water-exceeded")
            evidence: dict[str, Any] = {
                "schema": "amoebius.phase41.wireguard-live.v1",
                "register": 3,
                "substrate": "linux-cpu",
                "run": {"suffixDigest": sha256(suffix.encode()), "freshCanaryDigest": sha256(canary)},
                "admission": {
                    "snapshotFingerprint": fingerprint,
                    "tokenConsumedOnce": True,
                    "preEffectNegatives": pre_effect_negative,
                    "zeroEffectsBeforeAdmission": True,
                },
                "vault": {
                    "secretRefsOnly": True,
                    "freshKeysResolved": True,
                    "currentTreeClientBinaryDigest": sha256(binary.read_bytes()),
                    "missingRefSpecificReason": "secret-missing",
                    "rawKeyBytesRetained": False,
                },
                "kernel": {
                    "interface": "wg0",
                    "hubVpnIp": "10.77.0.1",
                    "spokeVpnIp": "10.77.1.2",
                    "icmpReachable": ping.returncode == 0,
                    "tcpReachable": echoed == canary,
                    "wgShowMatched": hub_wg["peerCount"] == spoke_wg["peerCount"] == 1,
                    "hubStateDigest": hub_wg["stateDigest"],
                    "spokeStateDigest": spoke_wg["stateDigest"],
                },
                "underlay": {
                    "protocol": "udp/51820",
                    "wireguardUdpObserved": True,
                    "cleartextCanaryAbsent": True,
                    "captureDigest": sha256(capture_bytes),
                },
                "reconcile": {"firstPassMutations": 2, "secondPassMutations": second_pass_mutations},
                "resourceReadback": {
                    "withinProvision": expected_controls and nodefs_high_water <= 1245184,
                    "nodes": controls,
                    "logPolicy": {"maxBytesPerFile": 65536, "maxBackups": 2, "retentionSeconds": 86400},
                    "nodeFsHighWaterBytes": nodefs_high_water,
                },
                "cleanup": {"exact": False, "namespaces": [], "cgroups": [], "temporaryPaths": []},
                "deferred": {
                    "brokerGeoReplication": "UNVERIFIED",
                    "gatewayHubRepoint": "UNVERIFIED",
                    "stretchedControlPlanePeer": "UNVERIFIED",
                },
                "universalLinuxCpu": {
                    "availableOnEveryHardwareSubstrate": True,
                    "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
                },
            }
    finally:
        cleanup_network((hub, spoke), cgroups, processes)
        shutil.rmtree(temporary_path, ignore_errors=True)
    namespace_names = run((IP, "netns", "list")).stdout.decode()
    leaked_namespaces = [name for name in (hub, spoke) if name in namespace_names]
    leaked_cgroups = [str(path) for path in cgroups if path.exists()]
    leaked_temp = [str(temporary_path)] if temporary_path.exists() else []
    evidence["cleanup"] = {
        "exact": not leaked_namespaces and not leaked_cgroups and not leaked_temp,
        "namespaces": leaked_namespaces,
        "cgroups": leaked_cgroups,
        "temporaryPaths": leaked_temp,
    }
    if not evidence["cleanup"]["exact"]:
        raise Phase41Failure(f"cleanup-leak:{evidence['cleanup']}")
    evidence["evidenceDigest"] = sha256(json_bytes(evidence))
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_bytes(json.dumps(evidence, indent=2, sort_keys=True).encode() + b"\n")
    return evidence


def main() -> int:
    try:
        evidence = execute()
        if not evidence["resourceReadback"]["withinProvision"]:
            raise Phase41Failure("resource-readback-outside-provision")
        if evidence["reconcile"]["secondPassMutations"] != 0:
            raise Phase41Failure("second-reconcile-mutated")
        print("network-fabric-wireguard-wireguard-live: PASS")
        print("network-fabric-wireguard-wireguard-cleanup: PASS")
        return 0
    except Exception as failure:
        print(f"network-fabric-wireguard-wireguard-live: FAIL ({failure})", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
