#!/usr/bin/env python3
"""Run one rootful Docker daemon whose bytes belong to a marked amoebius test run.

The host Docker client is an operator prerequisite; its default daemon is never an
amoebius storage backend.  This launcher gives a live gate a private daemon socket,
data root, exec root, containerd namespace, bridge, and client environment.  Every
filesystem path is beneath the caller's marker-owned `.test_data` descendant.  Stop
removes the transient kernel boundary, restores ownership, and lets the containment
module perform the only recursive deletion after checking the unchanged marker.
"""

from __future__ import annotations

import hashlib
import ipaddress
import os
import re
import shlex
import signal
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Mapping

import containment


ROOT = Path(__file__).resolve().parents[1]
DOCKER = Path("/usr/bin/docker")
DOCKERD = Path("/usr/bin/dockerd")
CONTAINERD = Path("/usr/bin/containerd")
CTR = Path("/usr/bin/ctr")
SUDO = Path("/usr/bin/sudo")
IP = Path("/usr/sbin/ip")
LOSETUP = Path("/usr/sbin/losetup")
MKFS_EXT4 = Path("/usr/sbin/mkfs.ext4")
MOUNT = Path("/usr/bin/mount")
UMOUNT = Path("/usr/bin/umount")
IPTABLES = Path("/usr/sbin/iptables")
IPTABLES_SAVE = Path("/usr/sbin/iptables-save")


class EngineFailure(RuntimeError):
    """The project-scoped daemon could not be safely started or stopped."""


def _run(arguments: list[str], *, check: bool = True, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        arguments,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=timeout,
    )
    if check and result.returncode:
        raise EngineFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def _mount_targets(root: Path) -> list[Path]:
    """Return deepest-first mount targets strictly beneath one marked test run."""
    targets: set[Path] = set()
    try:
        lines = Path("/proc/self/mountinfo").read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    canonical_root = root.resolve(strict=False)
    for line in lines:
        fields = line.split()
        if len(fields) < 5:
            continue
        decoded = (
            fields[4]
            .replace("\\040", " ")
            .replace("\\011", "\t")
            .replace("\\134", "\\")
        )
        candidate = Path(decoded).resolve(strict=False)
        try:
            candidate.relative_to(canonical_root)
        except ValueError:
            continue
        if candidate != canonical_root:
            targets.add(candidate)
    return sorted(targets, key=lambda path: len(path.parts), reverse=True)


def _iptables_snapshot() -> tuple[tuple[str, str], ...]:
    """Read IPv4 rules with their table so this daemon can remove only its additions."""
    if not IPTABLES_SAVE.is_file():
        raise EngineFailure(f"required-executable-absent:{IPTABLES_SAVE}")
    result = _run([str(SUDO), "-n", str(IPTABLES_SAVE)])
    table = ""
    rows: list[tuple[str, str]] = []
    for line in result.stdout.splitlines():
        if line.startswith("*"):
            table = line[1:]
        elif table and line.startswith("-A "):
            rows.append((table, line))
    return tuple(rows)


def _remove_added_iptables_rules(
    baseline: tuple[tuple[str, str], ...],
    *,
    interface_names: set[str],
    networks: set[ipaddress.IPv4Network],
) -> list[str]:
    """Delete this engine's added rule instances, preserving every unrelated rule."""
    failures: list[str] = []
    before_counts: dict[tuple[str, str], int] = {}
    for row in baseline:
        before_counts[row] = before_counts.get(row, 0) + 1
    additions: list[tuple[str, str]] = []
    for row in _iptables_snapshot():
        available = before_counts.get(row, 0)
        if available:
            before_counts[row] = available - 1
        else:
            additions.append(row)
    def belongs_to_engine(rule: str) -> bool:
        if any(name in rule for name in interface_names):
            return True
        for token in re.findall(
            r"(?<![0-9.])(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?",
            rule,
        ):
            try:
                address = ipaddress.ip_interface(token).ip
            except ValueError:
                continue
            if any(address in network for network in networks):
                return True
        return False

    for table, rule in reversed([row for row in additions if belongs_to_engine(row[1])]):
        arguments = shlex.split(rule)
        if not arguments or arguments[0] != "-A":
            failures.append(f"firewall-rule-unparseable:{table}:{rule}")
            continue
        arguments[0] = "-D"
        removed = _run(
            [str(SUDO), "-n", str(IPTABLES), "-t", table, *arguments],
            check=False,
        )
        if removed.returncode:
            failures.append(f"firewall-rule-delete:{table}:{rule}:{removed.stdout.strip()}")
    return failures


def restore_build_ownership(paths: list[Path]) -> None:
    """Make retained container-produced build evidence manageable by its invoking user."""
    canonical = [containment.require_state_path(path, "build", actor="test") for path in paths]
    if not canonical:
        return
    ownership = _run(
        [
            str(SUDO), "-n", "/usr/bin/chown", "-R",
            f"{os.getuid()}:{os.getgid()}", *(str(path) for path in canonical),
        ],
        check=False,
        timeout=1800,
    )
    if ownership.returncode:
        raise EngineFailure(f"build-ownership-restore:{ownership.stdout.strip()}")
    access = _run(
        [str(SUDO), "-n", "/usr/bin/chmod", "-R", "u+rwX", *(str(path) for path in canonical)],
        check=False,
        timeout=1800,
    )
    if access.returncode:
        raise EngineFailure(f"build-access-restore:{access.stdout.strip()}")


@dataclass
class ProjectContainerEngine:
    """A daemon plus the exact resources its test run is authorized to remove."""

    test_run: containment.TestRun
    process: subprocess.Popen[bytes]
    log_handle: BinaryIO
    containerd_process: subprocess.Popen[bytes]
    containerd_log_handle: BinaryIO
    containerd_socket: Path
    socket: Path
    data_root: Path
    exec_root: Path
    bridge: str
    bridge_subnet: str
    client_config: Path
    iptables_baseline: tuple[tuple[str, str], ...]

    @property
    def environment(self) -> dict[str, str]:
        value = dict(os.environ)
        value.update(
            {
                "DOCKER_HOST": f"unix://{self.socket}",
                "DOCKER_CONFIG": str(self.client_config),
                "DOCKER_BUILDKIT": "1",
            }
        )
        return value

    def docker(self, *arguments: str, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [str(DOCKER), "--config", str(self.client_config), *arguments],
            cwd=ROOT,
            env=self.environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout,
        )
        if check and result.returncode:
            raise EngineFailure(f"docker:{arguments[0] if arguments else 'command'}:{result.stdout}")
        return result

    def verify_boundary(self) -> str:
        observed = self.docker("info", "--format", "{{.DockerRootDir}}").stdout.strip()
        actual = Path(observed).resolve(strict=False)
        expected = self.data_root.resolve(strict=False)
        if actual != expected:
            raise EngineFailure(f"daemon-data-root:{actual}!={expected}")
        containment.require_state_path(actual, "test", actor="test")
        driver_status = self.docker("info", "--format", "{{json .DriverStatus}}").stdout.strip()
        if "io.containerd.snapshotter.v1" in driver_status:
            raise EngineFailure("daemon-image-store:containerd-snapshotter-enabled")
        return str(actual)

    def stop(self) -> None:
        """Stop first, then remove only this launcher's bridge and restore test-root ownership."""
        failures: list[str] = []
        listed = self.docker("ps", "-aq", check=False, timeout=60)
        container_ids = [
            line.strip() for line in listed.stdout.splitlines()
            if len(line.strip()) == 64 and all(character in "0123456789abcdef" for character in line.strip())
        ]
        if listed.returncode:
            failures.append(f"container-list:{listed.stdout.strip()}")
        elif container_ids:
            removed = self.docker("rm", "--force", *container_ids, check=False, timeout=300)
            if removed.returncode:
                self.docker("stop", "--time", "60", *container_ids, check=False, timeout=120)
                removed = self.docker("rm", "--force", *container_ids, check=False, timeout=300)
                if removed.returncode:
                    failures.append(f"container-remove:{removed.stdout.strip()}")
        networks = self.docker(
            "network", "ls", "--no-trunc", "--filter", "type=custom", "--format", "{{.ID}} {{.Name}}",
            check=False,
            timeout=60,
        )
        owned_interfaces = {self.bridge}
        owned_networks = {ipaddress.ip_interface(self.bridge_subnet).network}
        if networks.returncode:
            failures.append(f"network-list:{networks.stdout.strip()}")
        else:
            network_ids: list[str] = []
            for line in networks.stdout.splitlines():
                identity, _, name = line.strip().partition(" ")
                if not (
                    len(identity) == 64
                    and all(character in "0123456789abcdef" for character in identity)
                    and name
                ):
                    failures.append(f"network-identity:{line.strip()}")
                    continue
                network_ids.append(identity)
                owned_interfaces.add("br-" + identity[:12])
                inspected = self.docker(
                    "network", "inspect", identity,
                    "--format", "{{range .IPAM.Config}}{{.Subnet}}{{println}}{{end}}",
                    check=False,
                    timeout=60,
                )
                if inspected.returncode:
                    failures.append(f"network-inspect:{identity}:{inspected.stdout.strip()}")
                else:
                    for subnet in inspected.stdout.splitlines():
                        if not subnet.strip():
                            continue
                        try:
                            network = ipaddress.ip_network(subnet.strip())
                        except ValueError:
                            failures.append(f"network-subnet:{identity}:{subnet.strip()}")
                            continue
                        if isinstance(network, ipaddress.IPv4Network):
                            owned_networks.add(network)
            if network_ids:
                removed = self.docker("network", "rm", *network_ids, check=False, timeout=300)
                if removed.returncode:
                    failures.append(f"network-remove:{removed.stdout.strip()}")
        pid_path = self.test_run.path / "r/docker.pid"
        if pid_path.is_file():
            try:
                pid = int(pid_path.read_text(encoding="utf-8").strip())
            except (OSError, ValueError):
                pid = 0
            if pid > 1:
                _run([str(SUDO), "-n", "/usr/bin/kill", f"-{signal.SIGTERM}", str(pid)], check=False)
        try:
            self.process.wait(timeout=60)
        except subprocess.TimeoutExpired:
            if pid_path.is_file():
                try:
                    pid = int(pid_path.read_text(encoding="utf-8").strip())
                except (OSError, ValueError):
                    pid = 0
                if pid > 1:
                    _run([str(SUDO), "-n", "/usr/bin/kill", f"-{signal.SIGKILL}", str(pid)], check=False)
            try:
                self.process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                failures.append("daemon-stop-timeout")
        finally:
            self.log_handle.close()
        if self.containerd_process.poll() is None:
            try:
                self.containerd_process.terminate()
            except ProcessLookupError:
                pass
        try:
            self.containerd_process.wait(timeout=30)
        except subprocess.TimeoutExpired:
            try:
                self.containerd_process.kill()
            except ProcessLookupError:
                pass
            try:
                self.containerd_process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                failures.append("containerd-stop-timeout")
        finally:
            self.containerd_log_handle.close()
        for target in _mount_targets(self.test_run.path):
            unmounted = _run([str(SUDO), "-n", str(UMOUNT), str(target)], check=False, timeout=300)
            if unmounted.returncode:
                failures.append(f"residual-unmount:{target}:{unmounted.stdout.strip()}")
        for interface in sorted(owned_interfaces):
            bridge_result = _run([str(SUDO), "-n", str(IP), "link", "delete", interface], check=False)
            if bridge_result.returncode and "Cannot find device" not in bridge_result.stdout:
                failures.append(f"bridge-delete:{interface}:{bridge_result.stdout.strip()}")
        failures.extend(
            _remove_added_iptables_rules(
                self.iptables_baseline,
                interface_names=owned_interfaces,
                networks=owned_networks,
            )
        )
        ownership_result = _run(
            [
                str(SUDO), "-n", "/usr/bin/chown", "-R",
                f"{os.getuid()}:{os.getgid()}", str(self.test_run.path),
            ],
            check=False,
            timeout=600,
        )
        if ownership_result.returncode:
            failures.append(f"ownership-restore:{ownership_result.stdout.strip()}")
        access_result = _run(
            [str(SUDO), "-n", "/usr/bin/chmod", "-R", "u+rwX", str(self.test_run.path)],
            check=False,
            timeout=600,
        )
        if access_result.returncode:
            failures.append(f"owner-access-restore:{access_result.stdout.strip()}")
        if failures:
            raise EngineFailure(";".join(failures))


@dataclass
class ProjectFilesystems:
    """Finite build backings whose sparse disks are owned by one marked test run."""

    test_run: containment.TestRun
    entries: list[tuple[Path, str]]

    def stop(self) -> None:
        failures: list[str] = []
        for mountpoint, loop in reversed(self.entries):
            result = _run([str(SUDO), "-n", str(UMOUNT), str(mountpoint)], check=False, timeout=300)
            if result.returncode:
                failures.append(f"unmount:{mountpoint}:{result.stdout.strip()}")
            result = _run([str(SUDO), "-n", str(LOSETUP), "--detach", loop], check=False)
            if result.returncode:
                failures.append(f"loop-detach:{loop}:{result.stdout.strip()}")
        _run(
            [
                str(SUDO), "-n", "/usr/bin/chown", "-R",
                f"{os.getuid()}:{os.getgid()}", str(self.test_run.path),
            ],
            check=False,
            timeout=600,
        )
        if failures:
            raise EngineFailure(";".join(failures))


def create_filesystems(
    test_run: containment.TestRun,
    provisions: Mapping[str, tuple[Path, int]],
) -> ProjectFilesystems:
    """Create distinct ext4 backings without placing a byte outside the checkout."""
    root = containment.require_state_path(test_run.path, "test", actor="test")
    marker = root / containment.MARKER
    if not marker.is_file():
        raise EngineFailure("test-root-marker-absent")
    for executable in (LOSETUP, MKFS_EXT4, MOUNT, UMOUNT):
        if not executable.is_file():
            raise EngineFailure(f"required-executable-absent:{executable}")
    disk_root = root / "disks"
    disk_root.mkdir(parents=True, exist_ok=True)
    entries: list[tuple[Path, str]] = []
    try:
        for name, (mountpoint, size_bytes) in provisions.items():
            containment.require_state_path(mountpoint, "build", actor="test")
            mountpoint.mkdir(parents=True, exist_ok=True)
            image = disk_root / f"{name}.ext4"
            with image.open("wb") as handle:
                handle.truncate(size_bytes)
            loop = _run(
                [str(SUDO), "-n", str(LOSETUP), "--find", "--show", str(image)],
                timeout=120,
            ).stdout.strip()
            if not loop.startswith("/dev/loop"):
                raise EngineFailure(f"loop-allocation:{name}:{loop}")
            try:
                _run([str(SUDO), "-n", str(MKFS_EXT4), "-F", "-m", "0", "-L", name, loop], timeout=300)
                _run(
                    [
                        str(SUDO), "-n", str(MOUNT),
                        "-o", "nosuid,nodev", loop, str(mountpoint),
                    ],
                    timeout=120,
                )
                _run(
                    [str(SUDO), "-n", "/usr/bin/chown", f"{os.getuid()}:{os.getgid()}", str(mountpoint)],
                )
                entries.append((mountpoint, loop))
            except Exception:
                _run([str(SUDO), "-n", str(LOSETUP), "--detach", loop], check=False)
                raise
        devices = {os.stat(path).st_dev for path, _loop in entries}
        if len(devices) != len(entries):
            raise EngineFailure("finite-build-backings-aliased")
        return ProjectFilesystems(test_run=test_run, entries=entries)
    except Exception:
        partial = ProjectFilesystems(test_run=test_run, entries=entries)
        try:
            partial.stop()
        except EngineFailure:
            pass
        raise


def start(
    test_run: containment.TestRun,
    *,
    log_path: Path,
    base_environment: Mapping[str, str] | None = None,
) -> ProjectContainerEngine:
    """Start the private daemon after validating the marker-owned destination."""
    root = containment.require_state_path(test_run.path, "test", actor="test")
    if root != test_run.path.resolve(strict=False):
        raise EngineFailure("test-root-resolution-changed")
    marker = root / containment.MARKER
    if not marker.is_file():
        raise EngineFailure("test-root-marker-absent")
    for executable in (DOCKER, DOCKERD, CONTAINERD, CTR, SUDO, IP):
        if not executable.is_file():
            raise EngineFailure(f"required-executable-absent:{executable}")

    iptables_baseline = _iptables_snapshot()
    data_root = root / "d"
    exec_root = root / "x"
    run_root = root / "r"
    client_config = root / "c"
    for path in (data_root, exec_root, run_root, client_config):
        path.mkdir(parents=True, exist_ok=True)

    containerd_root = root / "t"
    containerd_state = root / "s"
    containerd_socket = run_root / "containerd.sock"
    containerd_config = root / "containerd.toml"
    containerd_root.mkdir(parents=True, exist_ok=True)
    containerd_state.mkdir(parents=True, exist_ok=True)
    containerd_config.write_text(
        "\n".join(
            [
                "version = 4",
                "imports = []",
                "disabled_plugins = [",
                "  'io.containerd.cri.v1.images',",
                "  'io.containerd.cri.v1.runtime',",
                "  'io.containerd.grpc.v1.cri',",
                "  'io.containerd.nri.v1.nri',",
                "]",
                "",
            ]
        ),
        encoding="utf-8",
    )
    containerd_log_path = log_path.with_name("project-containerd.log")
    containerd_log_path.parent.mkdir(parents=True, exist_ok=True)
    containerd_log_handle = containerd_log_path.open("wb")
    containerd_process = subprocess.Popen(
        [
            str(SUDO), "-n", str(CONTAINERD),
            "--config", str(containerd_config),
            "--address", str(containerd_socket),
            "--root", str(containerd_root),
            "--state", str(containerd_state),
        ],
        cwd=ROOT,
        env=dict(base_environment or os.environ),
        stdin=subprocess.DEVNULL,
        stdout=containerd_log_handle,
        stderr=subprocess.STDOUT,
    )
    containerd_ready = False
    for _ in range(240):
        if containerd_process.poll() is not None:
            break
        if containerd_socket.exists():
            probe = _run(
                [str(SUDO), "-n", str(CTR), "--address", str(containerd_socket), "version"],
                check=False,
                timeout=5,
            )
            if probe.returncode == 0:
                containerd_ready = True
                break
        time.sleep(0.25)
    if not containerd_ready:
        if containerd_process.poll() is None:
            containerd_process.terminate()
        try:
            containerd_process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            containerd_process.kill()
            containerd_process.wait(timeout=10)
        containerd_log_handle.close()
        raise EngineFailure("containerd-start-timeout")

    token = hashlib.sha256(test_run.run_id.encode()).hexdigest()
    bridge = "ambr" + token[:8]
    third_octet = 160 + (int(token[:2], 16) % 70)
    subnet = f"172.30.{third_octet}.1/24"
    try:
        _run([str(SUDO), "-n", str(IP), "link", "add", bridge, "type", "bridge"])
        _run([str(SUDO), "-n", str(IP), "addr", "add", subnet, "dev", bridge])
        _run([str(SUDO), "-n", str(IP), "link", "set", bridge, "up"])
    except Exception:
        _run([str(SUDO), "-n", str(IP), "link", "delete", bridge], check=False)
        if containerd_process.poll() is None:
            containerd_process.terminate()
        try:
            containerd_process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            containerd_process.kill()
            containerd_process.wait(timeout=10)
        containerd_log_handle.close()
        _run(
            [
                str(SUDO), "-n", "/usr/bin/chown", "-R",
                f"{os.getuid()}:{os.getgid()}", str(root),
            ],
            check=False,
            timeout=600,
        )
        raise

    socket = run_root / "docker.sock"
    pidfile = run_root / "docker.pid"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_handle = log_path.open("wb")
    command = [
        str(SUDO), "-n", str(DOCKERD),
        "--host", f"unix://{socket}",
        "--data-root", str(data_root),
        "--exec-root", str(exec_root),
        "--pidfile", str(pidfile),
        "--bridge", bridge,
        "--iptables=true",
        "--ip-masq=true",
        "--userland-proxy=false",
        "--group", "docker",
        "--containerd-namespace", "moby-" + token[:12],
        "--containerd-plugins-namespace", "plugins-" + token[:12],
        "--containerd", str(containerd_socket),
        # Docker 29 enables the containerd image store by default for a fresh
        # daemon.  There ImageInspect.Id names a generated manifest descriptor,
        # while the classic store's Id is the OCI config digest.  The live image
        # gate deliberately compares Id with the byte-exact exported config, so
        # make that identity contract explicit instead of inheriting a host-version
        # default.  BuildKit remains the multi-platform builder either way.
        "--feature", "containerd-snapshotter=false",
        "--registry-mirror=https://mirror.gcr.io",
        "--default-address-pool", "base=10.240.0.0/16,size=24",
    ]
    environment = dict(base_environment or os.environ)
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=environment,
        stdin=subprocess.DEVNULL,
        stdout=log_handle,
        stderr=subprocess.STDOUT,
    )
    engine = ProjectContainerEngine(
        test_run=test_run,
        process=process,
        log_handle=log_handle,
        containerd_process=containerd_process,
        containerd_log_handle=containerd_log_handle,
        containerd_socket=containerd_socket,
        socket=socket,
        data_root=data_root,
        exec_root=exec_root,
        bridge=bridge,
        bridge_subnet=subnet,
        client_config=client_config,
        iptables_baseline=iptables_baseline,
    )
    last = "daemon did not answer"
    for _ in range(240):
        if process.poll() is not None:
            break
        result = engine.docker("info", "--format", "{{.DockerRootDir}}", check=False, timeout=5)
        if result.returncode == 0:
            engine.verify_boundary()
            return engine
        last = result.stdout.strip() or last
        time.sleep(0.25)
    try:
        engine.stop()
    except EngineFailure:
        pass
    raise EngineFailure(f"daemon-start:{last}")
