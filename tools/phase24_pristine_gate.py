#!/usr/bin/env python3
"""Provider-aware pristine Linux guest harness for the Phase-24 live gate.

The harness owns the machine boundary, not amoebius's five-member HostTool
enum.  It always creates a Linux guest without GPU passthrough, proves the
Bootstrap-Coordinator-managed tools absent, installs only the declared Docker/strace gate
prerequisites, and then drives the same gate workflow through Incus, Lima, or
WSL2.  Plan mode is side-effect free and is the default.
"""

from __future__ import annotations

import argparse
import dataclasses
import enum
import gzip
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path
from typing import BinaryIO, Sequence


ROOT = Path(__file__).resolve().parents[1]
# Run-local by default. The phase gate always passes --evidence into its own run bundle;
# this fallback exists for a standalone harness run and must not name an authored root.
DEFAULT_EVIDENCE = ROOT / "gen" / "runs" / "phase_24" / "pristine-standalone"
GUEST_ROOT = Path("/root/amoebius")
KUBECONFIG = Path("/root/.amoebius/phase24/kubeconfig")
CLUSTER = "amoebius-phase24"
NODE = f"{CLUSTER}-control-plane"
MANAGED_TOOLS = ("ghc", "cabal", "ghcup", "kind", "kubectl")
INSTANCE_PATTERN = re.compile(r"^amoebius-phase24-[a-z0-9][a-z0-9-]*$")


class GateError(RuntimeError):
    pass


class Provider(enum.StrEnum):
    INCUS = "incus"
    LIMA = "lima"
    WSL2 = "wsl2"


@dataclasses.dataclass(frozen=True)
class GateConfig:
    provider: Provider
    instance: str = "amoebius-phase24-pristine"
    cpus: int = 4
    memory_gib: int = 8
    disk_gib: int = 80
    source: Path = ROOT
    evidence: Path = DEFAULT_EVIDENCE
    wsl_rootfs: str | None = None
    wsl_install_dir: str | None = None
    keep_guest: bool = False


@dataclasses.dataclass(frozen=True)
class CommandPlan:
    create: tuple[str, ...]
    destroy: tuple[tuple[str, ...], ...]
    guest_transport: str


def provider_for_system(system: str) -> Provider:
    normalized = system.lower()
    if normalized == "linux":
        return Provider.INCUS
    if normalized == "darwin":
        return Provider.LIMA
    if normalized == "windows":
        return Provider.WSL2
    raise GateError(f"phase24-pristine-provider-unknown-system:{system}")


def parent_hardware_for_system(system: str, nvidia_present: bool) -> str:
    """Render the detected parent hardware separately from the guest lane."""
    normalized = system.lower()
    if normalized == "linux":
        return "linux-cuda" if nvidia_present else "linux-cpu"
    if normalized == "darwin":
        return "apple"
    if normalized == "windows":
        return "windows"
    raise GateError(f"phase24-parent-hardware-unknown-system:{system}")


def detect_parent_hardware() -> str:
    return parent_hardware_for_system(
        platform.system(),
        Path("/dev/nvidiactl").exists(),
    )


def command_plan(config: GateConfig) -> CommandPlan:
    if config.provider is Provider.INCUS:
        return CommandPlan(
            create=(
                "incus", "launch", "images:ubuntu/24.04/cloud", config.instance,
                "--vm", "-c", f"limits.cpu={config.cpus}",
                "-c", f"limits.memory={config.memory_gib}GiB",
                "-d", f"root,size={config.disk_gib}GiB",
            ),
            destroy=(("incus", "delete", "--force", config.instance),),
            guest_transport="incus exec",
        )
    if config.provider is Provider.LIMA:
        return CommandPlan(
            create=(
                "limactl", "start", "--tty=false", f"--name={config.instance}",
                f"--cpus={config.cpus}", f"--memory={config.memory_gib}",
                f"--disk={config.disk_gib}", "--mount-none", "template:ubuntu-24.04",
            ),
            destroy=(
                ("limactl", "stop", config.instance),
                ("limactl", "delete", "--force", config.instance),
            ),
            guest_transport="limactl shell + sudo -H",
        )
    if config.wsl_rootfs is None or config.wsl_install_dir is None:
        raise GateError("phase24-wsl2-requires-rootfs-and-install-dir")
    return CommandPlan(
        create=(
            "wsl.exe", "--import", config.instance, str(config.wsl_install_dir),
            str(config.wsl_rootfs), "--version", "2",
        ),
        destroy=(
            ("wsl.exe", "--terminate", config.instance),
            ("wsl.exe", "--unregister", config.instance),
        ),
        guest_transport="wsl.exe --distribution NAME --user root",
    )


def resolve_executable(name: str) -> str:
    found = shutil.which(name)
    if found is None:
        raise GateError(f"phase24-provider-executable-absent:{name}")
    return str(Path(found).resolve())


def run(
    arguments: Sequence[str],
    *,
    check: bool = True,
    input_stream: BinaryIO | None = None,
    capture: bool = True,
) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments),
        stdin=input_stream,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if check and result.returncode:
        output = (result.stdout or b"").decode("utf-8", errors="replace")
        raise GateError(f"command-failed:{arguments[0]}:{result.returncode}\n{output}")
    return result


class Guest:
    def __init__(self, config: GateConfig) -> None:
        self.config = config
        self.created = False
        self.bootstrap_coordinator_envelope_rows: list[str] = []

    def assert_absent(self) -> None:
        raise NotImplementedError

    def create(self) -> None:
        raise NotImplementedError

    def execute(
        self,
        arguments: Sequence[str],
        *,
        environment: dict[str, str] | None = None,
        check: bool = True,
        input_stream: BinaryIO | None = None,
    ) -> subprocess.CompletedProcess[bytes]:
        raise NotImplementedError

    def destroy(self) -> None:
        raise NotImplementedError

    def wait_ready(self) -> None:
        for _ in range(60):
            if self.execute(("/usr/bin/true",), check=False).returncode == 0:
                return
            time.sleep(2)
        raise GateError("phase24-pristine-guest-agent-timeout")

    def shell(self, source: str, *, check: bool = True) -> subprocess.CompletedProcess[bytes]:
        return self.execute(("/bin/sh", "-c", source), check=check)


class IncusGuest(Guest):
    def __init__(self, config: GateConfig) -> None:
        super().__init__(config)
        incus = resolve_executable("incus")
        direct = run((incus, "info"), check=False)
        self.prefix = (incus,) if direct.returncode == 0 else (resolve_executable("sudo"), "-n", incus)

    def incus(self, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
        return run((*self.prefix, *arguments), check=check)

    def assert_absent(self) -> None:
        result = self.incus("list", self.config.instance, "--format", "csv", "-c", "n")
        if result.stdout.strip():
            raise GateError(f"phase24-refuses-preexisting-instance:{self.config.instance}")

    def create(self) -> None:
        plan = command_plan(self.config).create
        self.incus(*plan[1:])
        self.created = True

    def execute(
        self,
        arguments: Sequence[str],
        *,
        environment: dict[str, str] | None = None,
        check: bool = True,
        input_stream: BinaryIO | None = None,
    ) -> subprocess.CompletedProcess[bytes]:
        options: list[str] = ["exec", self.config.instance]
        for key, value in sorted((environment or {}).items()):
            options.extend(("--env", f"{key}={value}"))
        options.extend(("--mode", "non-interactive", "--"))
        return run((*self.prefix, *options, *arguments), check=check, input_stream=input_stream)

    def destroy(self) -> None:
        if self.created:
            self.incus("delete", "--force", self.config.instance)
            self.created = False


class LimaGuest(Guest):
    def __init__(self, config: GateConfig) -> None:
        super().__init__(config)
        self.limactl = resolve_executable("limactl")

    def assert_absent(self) -> None:
        result = run((self.limactl, "info", self.config.instance), check=False)
        if result.returncode == 0:
            raise GateError(f"phase24-refuses-preexisting-instance:{self.config.instance}")

    def create(self) -> None:
        plan = command_plan(self.config).create
        run((self.limactl, *plan[1:]))
        self.created = True

    def execute(
        self,
        arguments: Sequence[str],
        *,
        environment: dict[str, str] | None = None,
        check: bool = True,
        input_stream: BinaryIO | None = None,
    ) -> subprocess.CompletedProcess[bytes]:
        env = tuple(f"{key}={value}" for key, value in sorted((environment or {}).items()))
        command = (
            self.limactl, "shell", self.config.instance,
            "sudo", "-H", "/usr/bin/env", *env, *arguments,
        )
        return run(command, check=check, input_stream=input_stream)

    def destroy(self) -> None:
        if self.created:
            run((self.limactl, "stop", self.config.instance), check=False)
            run((self.limactl, "delete", "--force", self.config.instance))
            self.created = False


class Wsl2Guest(Guest):
    def __init__(self, config: GateConfig) -> None:
        super().__init__(config)
        self.wsl = resolve_executable("wsl.exe")

    def assert_absent(self) -> None:
        result = run((self.wsl, "--list", "--quiet"))
        names = result.stdout.decode("utf-8", errors="replace").replace("\x00", "").splitlines()
        if self.config.instance.casefold() in {name.strip().casefold() for name in names}:
            raise GateError(f"phase24-refuses-preexisting-instance:{self.config.instance}")

    def create(self) -> None:
        plan = command_plan(self.config).create
        run((self.wsl, *plan[1:]))
        self.created = True

    def execute(
        self,
        arguments: Sequence[str],
        *,
        environment: dict[str, str] | None = None,
        check: bool = True,
        input_stream: BinaryIO | None = None,
    ) -> subprocess.CompletedProcess[bytes]:
        env = tuple(f"{key}={value}" for key, value in sorted((environment or {}).items()))
        command = (
            self.wsl, "--distribution", self.config.instance, "--user", "root", "--",
            "/usr/bin/env", *env, *arguments,
        )
        return run(command, check=check, input_stream=input_stream)

    def destroy(self) -> None:
        if self.created:
            run((self.wsl, "--terminate", self.config.instance), check=False)
            run((self.wsl, "--unregister", self.config.instance))
            self.created = False


def make_guest(config: GateConfig) -> Guest:
    if config.provider is Provider.INCUS:
        return IncusGuest(config)
    if config.provider is Provider.LIMA:
        return LimaGuest(config)
    return Wsl2Guest(config)


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode("utf-8", errors="replace")


def require_clean_preflight(guest: Guest) -> str:
    command = """
for tool in ghc cabal ghcup kind kubectl helm; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s\\tpresent\\n' "$tool"
  else
    printf '%s\\tabsent\\n' "$tool"
  fi
done
if [ -e /dev/nvidiactl ]; then
  printf 'nvidiactl\\tpresent\\n'
else
  printf 'nvidiactl\\tabsent\\n'
fi
""".strip()
    observed = text(guest.shell(command))
    rows = dict(line.split("\t", 1) for line in observed.splitlines())
    expected_absent = (*MANAGED_TOOLS, "helm", "nvidiactl")
    failures = [name for name in expected_absent if rows.get(name) != "absent"]
    if failures:
        raise GateError("phase24-pristine-preflight-not-clean:" + ",".join(failures))
    return observed


def prepare_prerequisites(guest: Guest) -> str:
    outputs = []
    for arguments in (
        ("/usr/bin/apt-get", "update"),
        ("/usr/bin/env", "DEBIAN_FRONTEND=noninteractive", "/usr/bin/apt-get", "install", "-y", "docker.io", "strace"),
    ):
        outputs.append(text(guest.execute(arguments)))
    service = guest.execute(("/usr/bin/systemctl", "enable", "--now", "docker"), check=False)
    if service.returncode:
        guest.execute(("/usr/sbin/service", "docker", "start"))
    # The node container has its own nested envelope.  These are the distinct
    # host-engine daemon envelopes and are intentionally configured only in
    # the disposable pristine guest, never on the developer's shared host.
    guest.execute((
        "/usr/bin/systemctl", "set-property", "docker.service",
        "CPUQuota=100%", "MemoryMax=2147483648",
    ))
    guest.execute((
        "/usr/bin/systemctl", "set-property", "containerd.service",
        "CPUQuota=50%", "MemoryMax=1073741824",
    ))
    outputs.append(text(guest.execute(("/usr/bin/docker", "info", "--format", "{{.ServerVersion}} {{.Driver}}"))))
    outputs.append(text(guest.execute((
        "/usr/bin/systemctl", "show", "docker.service", "containerd.service",
        "--property=Id", "--property=CPUQuotaPerSecUSec", "--property=MemoryMax",
        "--property=ControlGroup",
    ))))
    return "".join(outputs)


def observe_process_envelopes(guest: Guest) -> str:
    """Read configured limits at the kernel boundary, not from amoebius."""
    command = f"""
set -eu
printf 'scope\\tidentity\\tcpu.max\\tmemory.max\\n'
for unit in docker.service containerd.service; do
  group=$(/usr/bin/systemctl show "$unit" --value --property=ControlGroup)
  cpu=$(/usr/bin/cat "/sys/fs/cgroup${{group}}/cpu.max")
  memory=$(/usr/bin/cat "/sys/fs/cgroup${{group}}/memory.max")
  printf 'host-engine\\t%s\\t%s\\t%s\\n' "$unit" "$cpu" "$memory"
done
node_cpu=$(/usr/bin/docker inspect --format '{{{{.HostConfig.NanoCpus}}}}' {NODE})
node_memory=$(/usr/bin/docker inspect --format '{{{{.HostConfig.Memory}}}}' {NODE})
printf 'node-container\\t{NODE}\\t%s/1000000000 cpus\\t%s\\n' "$node_cpu" "$node_memory"
for component in etcd kube-apiserver kube-controller-manager kube-scheduler; do
  id=$(/usr/bin/docker exec {NODE} /usr/local/bin/crictl ps --name "$component" -q | /usr/bin/head -1)
  pid=$(/usr/bin/docker exec {NODE} /usr/local/bin/crictl inspect --output go-template --template '{{{{.info.pid}}}}' "$id")
  group=$(/usr/bin/docker exec {NODE} /bin/sh -c "awk -F: '\\$1==\\\"0\\\"{{print \\$3}}' /proc/$pid/cgroup")
  cpu=$(/usr/bin/docker exec {NODE} /usr/bin/cat "/sys/fs/cgroup${{group}}/cpu.max")
  memory=$(/usr/bin/docker exec {NODE} /usr/bin/cat "/sys/fs/cgroup${{group}}/memory.max")
  printf 'static-pod\\t%s\\t%s\\t%s\\n' "$component" "$cpu" "$memory"
done
""".strip()
    return text(guest.shell(command))


def drive_host_engine_cpu(guest: Guest) -> str:
    """Lower Docker's ceiling for a negative control, throttle, then restore."""
    command = f"""
set -eu
/usr/bin/systemctl set-property docker.service CPUQuota=10%
restore() {{ /usr/bin/systemctl set-property docker.service CPUQuota=100%; }}
trap restore EXIT
group=$(/usr/bin/systemctl show docker.service --value --property=ControlGroup)
negative_cpu_max=$(/usr/bin/cat "/sys/fs/cgroup${{group}}/cpu.max")
before=$(/usr/bin/awk '$1=="nr_periods"{{periods=$2}} $1=="nr_throttled"{{throttled=$2}} $1=="throttled_usec"{{usec=$2}} END{{print periods,throttled,usec}}' "/sys/fs/cgroup${{group}}/cpu.stat")
/usr/bin/seq 1 1000 | /usr/bin/xargs -P32 -I{{}} /usr/bin/docker inspect {NODE} >/dev/null
after=$(/usr/bin/awk '$1=="nr_periods"{{periods=$2}} $1=="nr_throttled"{{throttled=$2}} $1=="throttled_usec"{{usec=$2}} END{{print periods,throttled,usec}}' "/sys/fs/cgroup${{group}}/cpu.stat")
set -- $before; bp=$1; bt=$2; bu=$3
set -- $after; ap=$1; at=$2; au=$3
printf 'negative-control-cpu.max\\t%s\\n' "$negative_cpu_max"
printf 'counter\\tbefore\\tafter\\tdelta\\n'
printf 'nr_periods\\t%s\\t%s\\t%s\\n' "$bp" "$ap" "$((ap-bp))"
printf 'nr_throttled\\t%s\\t%s\\t%s\\n' "$bt" "$at" "$((at-bt))"
printf 'throttled_usec\\t%s\\t%s\\t%s\\n' "$bu" "$au" "$((au-bu))"
test "$at" -gt "$bt"
restore
trap - EXIT
restored_cpu_max=$(/usr/bin/cat "/sys/fs/cgroup${{group}}/cpu.max")
printf 'restored-cpu.max\\t%s\\n' "$restored_cpu_max"
test "$restored_cpu_max" = "100000 100000"
""".strip()
    return text(guest.shell(command))


def prepare_unified_backing(guest: Guest) -> str:
    """Create the finite filesystem consumed by the default Unified layout."""
    image = "/var/lib/amoebius/phase24/unified.img"
    mountpoint = "/var/lib/amoebius/phase24/unified"
    guest.execute(("/usr/bin/mkdir", "-p", mountpoint))
    guest.execute(("/usr/bin/truncate", "-s", "24G", image))
    guest.execute(("/usr/sbin/mkfs.ext4", "-F", "-m", "0", "-L", "amoebius-unified", image))
    guest.execute(("/usr/bin/mount", "-o", "loop", image, mountpoint))
    guest.execute((
        "/usr/bin/mkdir", "-p",
        f"{mountpoint}/kubelet", f"{mountpoint}/containerd",
        f"{mountpoint}/system/etcd", f"{mountpoint}/system/audit",
        f"{mountpoint}/system/pods",
        "/var/lib/amoebius/phase24/patches",
    ))
    guest.execute((
        "/usr/bin/chmod", "0777",
        f"{mountpoint}/kubelet", f"{mountpoint}/containerd",
        f"{mountpoint}/system/etcd", f"{mountpoint}/system/audit",
        f"{mountpoint}/system/pods",
        "/var/lib/amoebius/phase24/patches",
    ))
    return text(guest.execute((
        "/usr/bin/findmnt", "-bno", "SOURCE,FSTYPE,SIZE,AVAIL,TARGET", mountpoint,
    )))


def source_filter(info: tarfile.TarInfo) -> tarfile.TarInfo | None:
    parts = Path(info.name).parts
    excluded = {".git", "dist-newstyle", "node_modules", "__pycache__"}
    pairs = set(zip(parts, parts[1:]))
    if any(part in excluded for part in parts) or ("toolchain", "runtime") in pairs:
        return None
    return info


def transfer_source(guest: Guest, source: Path) -> None:
    guest.execute(("/usr/bin/mkdir", "-p", str(GUEST_ROOT)))
    with tempfile.NamedTemporaryFile(prefix="amoebius-phase24-", suffix=".tar") as archive:
        with tarfile.open(fileobj=archive, mode="w") as bundle:
            bundle.add(source, arcname=".", filter=source_filter)
        archive.flush()
        archive.seek(0)
        guest.execute(("/usr/bin/tar", "-C", str(GUEST_ROOT), "-xf", "-"), input_stream=archive)
    size = guest.execute(("/usr/bin/wc", "-c", str(GUEST_ROOT / "pb/pb/cli.py")))
    if int(text(size).split()[0]) == 0:
        raise GateError("phase24-source-transfer-incomplete")


def pb_trace(guest: Guest, trace_path: str) -> subprocess.CompletedProcess[bytes]:
    unit = "amoebius-" + Path(trace_path).stem.replace("_", "-").replace(".", "-") + ".service"
    output_path = trace_path + ".stdout"
    service_command = (
        f"/usr/bin/strace -f -e trace=execve,execveat -o {trace_path} "
        "/usr/bin/python3 -m pb.cli bootstrap --distro=kind "
        f"> {output_path} 2>&1; status=$?; /usr/bin/sleep 2; exit $status"
    )
    launch = (
        "/usr/bin/systemd-run", "--quiet", "--service-type=exec", f"--unit={unit}",
        "--property=CPUQuota=350%", "--property=MemoryMax=7516192768",
        "--property=RemainAfterExit=yes",
        f"--setenv=PYTHONPATH={GUEST_ROOT / 'pb'}",
        "/bin/sh", "-c", service_command,
    )
    guest.execute(launch)
    readback = text(guest.shell(f"""
set -eu
group=$(/usr/bin/systemctl show {unit} --value --property=ControlGroup)
configured_cpu=$(/usr/bin/systemctl show {unit} --value --property=CPUQuotaPerSecUSec)
configured_memory=$(/usr/bin/systemctl show {unit} --value --property=MemoryMax)
cpu=$(/usr/bin/cat "/sys/fs/cgroup${{group}}/cpu.max")
memory=$(/usr/bin/cat "/sys/fs/cgroup${{group}}/memory.max")
printf '{unit}\t%s\t%s\t%s\t%s\t%s\n' "$configured_cpu" "$configured_memory" "$group" "$cpu" "$memory"
test "$configured_cpu" = "3.500000s"
test "$configured_memory" = "7516192768"
test "$cpu" = "350000 100000"
test "$memory" = "7516192768"
""".strip())).strip()
    guest.bootstrap_coordinator_envelope_rows.append(readback)
    try:
        for _ in range(3600):
            substate = text(guest.execute((
                "/usr/bin/systemctl", "show", unit, "--value", "--property=SubState",
            ))).strip()
            if substate == "exited":
                break
            if substate in {"dead", "failed"}:
                raise GateError(f"phase24-bootstrap-coordinator-unit-failed:{unit}:{substate}")
            time.sleep(2)
        else:
            raise GateError(f"phase24-bootstrap-coordinator-unit-timeout:{unit}")
        status = int(text(guest.execute((
            "/usr/bin/systemctl", "show", unit, "--value", "--property=ExecMainStatus",
        ))).strip())
        output = guest.execute(("/usr/bin/cat", output_path)).stdout
        return subprocess.CompletedProcess(launch, status, output, b"")
    finally:
        guest.execute(("/usr/bin/systemctl", "stop", unit), check=False)


def observation_triple(guest: Guest) -> tuple[bytes, bytes, bytes]:
    container = guest.execute((
        "/usr/bin/docker", "inspect", "--format",
        "{{.Id}}\\t{{.Name}}\\t{{.Config.Image}}\\t{{.State.Status}}", NODE,
    )).stdout
    clusters = guest.execute(("/root/.local/bin/kind", "get", "clusters")).stdout
    kubeconfig = guest.execute(("/usr/bin/cat", str(KUBECONFIG))).stdout
    return container, clusters, kubeconfig


def node_uid(guest: Guest) -> bytes:
    return guest.execute((
        "/root/.local/bin/kubectl", "--kubeconfig", str(KUBECONFIG),
        "get", "node", NODE, "-o", "jsonpath={.metadata.uid}",
    )).stdout


def assert_no_create(trace: bytes, label: str) -> None:
    if b'"create", "cluster"' in trace:
        raise GateError(f"phase24-{label}-recreated-cluster")


def observe_one_shot_guard_mutant(guest: Guest) -> tuple[str, bytes]:
    """Run the committed M3 mutant inside the guest and require it to stay broken.

    Divergence repair is only evidence if something could fail it. The production planner
    repairs a stopped node because it plans from the node's observed state; the mutant
    treats registration alone as convergence. Building it here, against the same source and
    the same cluster the production run just repaired, is what separates "the planner works"
    from "nothing ever diverged".

    It runs last, immediately before teardown, so overwriting the production binary in the
    shared build directory costs nothing.
    """
    build = guest.shell(f"""
set -eu
cd {GUEST_ROOT}
/root/.ghcup/bin/cabal-3.16.1.0 build exe:amoebius -j2 \
  --with-compiler=/root/.ghcup/bin/ghc-9.12.4 \
  --flags=+phase24-one-shot-kind-guard-mutant >/root/phase24-m3-build.log 2>&1
/root/.ghcup/bin/cabal-3.16.1.0 list-bin exe:amoebius \
  --with-compiler=/root/.ghcup/bin/ghc-9.12.4 \
  --flags=+phase24-one-shot-kind-guard-mutant
""")
    mutant_binary = text(build).strip().splitlines()[-1]
    if not mutant_binary.startswith("/"):
        raise GateError("phase24-m3-mutant-binary-not-absolute")

    original_id = guest.execute(("/usr/bin/docker", "inspect", "--format", "{{.Id}}", NODE)).stdout
    guest.execute(("/usr/bin/docker", "stop", NODE))
    attempt = guest.execute((
        "/usr/bin/strace", "-f", "-e", "trace=execve,execveat", "-o", "/root/phase24-m3-execve.log",
        mutant_binary, "bootstrap", "--distro=kind", "--replicas=1", "--layout=unified",
    ), check=False)
    state = text(guest.execute((
        "/usr/bin/docker", "inspect", "--format", "{{.State.Status}}", NODE,
    ))).strip()
    if state == "running":
        raise GateError("phase24-m3-one-shot-mutant-stayed-green")
    trace = guest.execute(("/usr/bin/cat", "/root/phase24-m3-execve.log")).stdout
    assert_no_create(trace, "m3-mutant")

    # The production path, against the same divergent start, must still repair it without
    # recreating the node. Without this the mutant result would only show that *something*
    # left the node stopped.
    repair = pb_trace(guest, "/root/phase24-m3-repair-execve.log")
    if b"bootstrap-handoff: ready" not in repair.stdout and b"bootstrap-reconcile" not in repair.stdout:
        raise GateError("phase24-m3-production-repair-did-not-converge")
    if guest.execute(("/usr/bin/docker", "inspect", "--format", "{{.Id}}", NODE)).stdout != original_id:
        raise GateError("phase24-m3-production-repair-recreated-container")
    report = "\n".join((
        "mutant\tlocus\tobserved",
        f"M3\tAmoebius.Cluster.Kind.planActions\tred:stopped-node-left-{state}",
        f"M3-production-repair\tpb.cli bootstrap\tconverged-without-recreate",
        f"M3-mutant-exit\tstrace-observed\t{attempt.returncode}",
        "",
    ))
    return report, trace


def write_evidence(path: Path, payload: bytes | str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(payload, str):
        path.write_text(payload, encoding="utf-8")
    else:
        path.write_bytes(payload)


def run_gate(config: GateConfig) -> None:
    if not INSTANCE_PATTERN.fullmatch(config.instance):
        raise GateError("phase24-unsafe-instance-name")
    guest = make_guest(config)
    parent_hardware = detect_parent_hardware()
    guest.assert_absent()
    try:
        guest.create()
        guest.wait_ready()
        preflight = require_clean_preflight(guest)
        prerequisite_log = prepare_prerequisites(guest)
        layout_prerequisite = prepare_unified_backing(guest)
        transfer_source(guest, config.source)

        first = pb_trace(guest, "/root/phase24-initial-execve.log")
        if b"bootstrap-handoff: ready" not in first.stdout:
            raise GateError("phase24-initial-bootstrap-not-ready")
        before = observation_triple(guest)

        rerun = pb_trace(guest, "/root/phase24-rerun-execve.log")
        if b"bootstrap-reconcile: already-converged" not in rerun.stdout:
            raise GateError("phase24-rerun-not-empty-diff")
        after = observation_triple(guest)
        if before != after:
            raise GateError("phase24-idempotence-triple-changed")
        rerun_trace = guest.execute(("/usr/bin/cat", "/root/phase24-rerun-execve.log")).stdout
        forbidden = (b"apt-get\", \"update", b"apt-get\", \"install", b"ghcup\", \"install", b"kind\", \"create", b"helm")
        if any(token in rerun_trace for token in forbidden):
            raise GateError("phase24-rerun-forbidden-mutation")

        process_envelopes = observe_process_envelopes(guest)
        host_engine_throttle = drive_host_engine_cpu(guest)

        original_id = guest.execute(("/usr/bin/docker", "inspect", "--format", "{{.Id}}", NODE)).stdout
        original_uid = node_uid(guest)
        guest.execute(("/usr/bin/docker", "stop", NODE))
        stopped = pb_trace(guest, "/root/phase24-stopped-node-execve.log")
        stopped_trace = guest.execute(("/usr/bin/cat", "/root/phase24-stopped-node-execve.log")).stdout
        assert_no_create(stopped_trace, "stopped-node")
        if guest.execute(("/usr/bin/docker", "inspect", "--format", "{{.Id}}", NODE)).stdout != original_id or node_uid(guest) != original_uid:
            raise GateError("phase24-stopped-node-identity-changed")

        guest.execute(("/usr/bin/rm", str(KUBECONFIG)))
        missing = pb_trace(guest, "/root/phase24-missing-kubeconfig-execve.log")
        missing_trace = guest.execute(("/usr/bin/cat", "/root/phase24-missing-kubeconfig-execve.log")).stdout
        assert_no_create(missing_trace, "missing-kubeconfig")
        if guest.execute(("/usr/bin/docker", "inspect", "--format", "{{.Id}}", NODE)).stdout != original_id or node_uid(guest) != original_uid:
            raise GateError("phase24-missing-kubeconfig-identity-changed")

        bootstrap_coordinator_envelopes = (
            "unit\tCPUQuotaPerSecUSec\tMemoryMax\tControlGroup\tcpu.max\tmemory.max\n"
            + "\n".join(guest.bootstrap_coordinator_envelope_rows)
            + "\n"
        )

        inventory = guest.execute(("/usr/bin/cat", "/root/.amoebius/phase24/observed-inventory.json")).stdout
        ready = guest.execute((
            "/root/.local/bin/kubectl", "--kubeconfig", str(KUBECONFIG), "get", "nodes", "-o", "wide",
        )).stdout
        initial_trace = guest.execute(("/usr/bin/cat", "/root/phase24-initial-execve.log")).stdout

        m3_report, m3_trace = observe_one_shot_guard_mutant(guest)

        teardown = guest.execute((
            "/root/.local/bin/kind", "delete", "cluster", "--name", CLUSTER,
            "--kubeconfig", str(KUBECONFIG),
        ))
        clusters = guest.execute(("/root/.local/bin/kind", "get", "clusters")).stdout
        containers = guest.execute((
            "/usr/bin/docker", "ps", "-a", "--filter", f"name={NODE}", "--format", "{{.ID}}",
        )).stdout
        if CLUSTER.encode() in clusters.splitlines() or containers.strip():
            raise GateError("phase24-postflight-leak")

        evidence = config.evidence
        evidence.mkdir(parents=True, exist_ok=True)
        with gzip.open(evidence / "pristine-initial-execve.log.gz", "wb") as handle:
            handle.write(initial_trace)
        write_evidence(evidence / "pristine-preflight.txt", preflight)
        write_evidence(evidence / "pristine-prerequisite.log", prerequisite_log)
        write_evidence(evidence / "pristine-layout-prerequisite.txt", layout_prerequisite)
        write_evidence(evidence / "pristine-initial.log", first.stdout)
        write_evidence(evidence / "pristine-rerun.log", rerun.stdout)
        write_evidence(evidence / "pristine-rerun-execve.log", rerun_trace)
        write_evidence(evidence / "pristine-process-envelopes.tsv", process_envelopes)
        write_evidence(evidence / "pristine-host-engine-throttle.tsv", host_engine_throttle)
        write_evidence(evidence / "pristine-stopped-node-repair.log", stopped.stdout)
        write_evidence(evidence / "pristine-stopped-node-execve.log", stopped_trace)
        write_evidence(evidence / "pristine-missing-kubeconfig-repair.log", missing.stdout)
        write_evidence(evidence / "pristine-missing-kubeconfig-execve.log", missing_trace)
        write_evidence(
            evidence / "pristine-bootstrap-coordinator-envelopes.tsv",
            bootstrap_coordinator_envelopes,
        )
        write_evidence(evidence / "pristine-observed-inventory.json", inventory)
        write_evidence(evidence / "pristine-node-ready.txt", ready)
        write_evidence(evidence / "pristine-container-before.txt", before[0])
        write_evidence(evidence / "pristine-container-after.txt", after[0])
        write_evidence(evidence / "pristine-clusters-before.txt", before[1])
        write_evidence(evidence / "pristine-clusters-after.txt", after[1])
        write_evidence(evidence / "pristine-kubeconfig-before.txt", hashlib.sha256(before[2]).hexdigest() + "\n")
        write_evidence(evidence / "pristine-kubeconfig-after.txt", hashlib.sha256(after[2]).hexdigest() + "\n")
        write_evidence(evidence / "pristine-m3-mutant.tsv", m3_report)
        write_evidence(evidence / "pristine-m3-execve.log", m3_trace)
        write_evidence(evidence / "pristine-teardown.log", teardown.stdout)
        contexts = guest.execute((
            "/root/.local/bin/kubectl", "--kubeconfig", str(KUBECONFIG),
            "config", "get-contexts", "-o", "name",
        ), check=False).stdout
        if CLUSTER.encode() in contexts:
            raise GateError("phase24-postflight-kubeconfig-context-leak")
        write_evidence(
            evidence / "pristine-provider.txt",
            "\n".join((
                f"provider\t{config.provider.value}",
                f"parent-hardware\t{parent_hardware}",
                f"instance\t{config.instance}",
                f"guest-cpu\t{config.cpus}",
                f"guest-memory\t{config.memory_gib}GiB",
                f"guest-root\t{config.disk_gib}GiB",
                "gpu-passthrough\tabsent",
                "execution-lane\tlinux-cpu",
                "",
            )),
        )
        write_evidence(
            evidence / "pristine-postflight.txt",
            "clusters=\ncontainers=\ncontexts=\nleak-sweep\tpass\n",
        )
        print(f"phase24-pristine-gate: PASS ({config.provider.value})")
    finally:
        if not config.keep_guest:
            guest.destroy()


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--execute", action="store_true", help="materialize and run; default prints the plan")
    value.add_argument("--provider", choices=("auto", *[item.value for item in Provider]), default="auto")
    value.add_argument("--instance", default="amoebius-phase24-pristine")
    value.add_argument("--cpus", type=int, default=4)
    value.add_argument("--memory-gib", type=int, default=8)
    value.add_argument("--disk-gib", type=int, default=80)
    value.add_argument("--source", type=Path, default=ROOT)
    value.add_argument("--evidence", type=Path, default=DEFAULT_EVIDENCE)
    value.add_argument("--wsl-rootfs")
    value.add_argument("--wsl-install-dir")
    value.add_argument("--keep-guest", action="store_true")
    return value


def main(argv: Sequence[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    try:
        provider = provider_for_system(platform.system()) if arguments.provider == "auto" else Provider(arguments.provider)
        config = GateConfig(
            provider=provider,
            instance=arguments.instance,
            cpus=arguments.cpus,
            memory_gib=arguments.memory_gib,
            disk_gib=arguments.disk_gib,
            source=arguments.source.resolve(),
            evidence=arguments.evidence.resolve(),
            wsl_rootfs=arguments.wsl_rootfs,
            wsl_install_dir=arguments.wsl_install_dir,
            keep_guest=arguments.keep_guest,
        )
        if arguments.execute:
            run_gate(config)
        else:
            plan = command_plan(config)
            print(json.dumps(dataclasses.asdict(plan), indent=2))
        return 0
    except (GateError, OSError, ValueError) as problem:
        print(f"phase24-pristine-gate: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
