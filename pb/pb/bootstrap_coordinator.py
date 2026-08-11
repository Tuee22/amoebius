"""Bare-host to amoebius-binary handoff without a shell or PATH lookup."""

from __future__ import annotations

import dataclasses
import hashlib
import json
import os
import platform
import pwd
import resource
import shutil
import stat
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from typing import Any, NoReturn, Sequence


class BootstrapCoordinatorError(RuntimeError):
    pass


EXPECTED_STEP_TOOLS = ("ghcup", "ghc", "cabal", "kubectl", "kind")
APT_BUILD_PACKAGES = (
    "ca-certificates", "curl", "gcc", "g++", "git", "libffi-dev", "libgmp-dev",
    "libncurses-dev", "libnuma-dev", "make", "pkg-config", "xz-utils", "zlib1g-dev",
)


@dataclasses.dataclass(frozen=True)
class HostObservation:
    cpu_count: int
    memory_available_bytes: int
    disk_available_bytes: int
    fingerprint: str


@dataclasses.dataclass
class ValidatedExecution:
    fingerprint: str
    consumed: bool = False

    def consume(self, current: HostObservation) -> None:
        if self.consumed:
            raise BootstrapCoordinatorError("validated-execution-already-consumed")
        if current.fingerprint != self.fingerprint:
            raise BootstrapCoordinatorError("host-fingerprint-changed")
        self.consumed = True


@dataclasses.dataclass(frozen=True)
class ToolPaths:
    apt_get: Path
    ghcup: Path
    ghc: Path
    cabal: Path
    kubectl: Path
    kind: Path


@dataclasses.dataclass(frozen=True)
class Preflight:
    ghc: bool
    cabal: bool
    ghcup: bool
    kind: bool
    kubectl: bool

    def render(self) -> str:
        values = dataclasses.asdict(self)
        return "\n".join(f"{name}\t{'present' if value else 'absent'}" for name, value in values.items())


def repository_root() -> Path:
    return Path(__file__).resolve().parents[2]


def home_directory() -> Path:
    return Path(pwd.getpwuid(os.getuid()).pw_dir)


def load_envelope(root: Path) -> dict[str, Any]:
    path = root / "pb/bootstrap_execution_envelope.json"
    with path.open(encoding="utf-8") as handle:
        envelope = json.load(handle)
    steps = tuple(step["tool"] for step in envelope["installer"]["steps"])
    if steps != EXPECTED_STEP_TOOLS or len(steps) != len(set(steps)):
        raise BootstrapCoordinatorError("install-plan-envelope-exact-join-failed")
    if envelope["toolchain"] != {
        "ghc": "9.12.4", "cabal": "3.16.1.0", "kind": "0.32.0", "kubectl": "1.35.6"
    }:
        raise BootstrapCoordinatorError("toolchain-pin-mismatch")
    return envelope


def _read_memory_available() -> int:
    for line in Path("/proc/meminfo").read_text(encoding="ascii").splitlines():
        if line.startswith("MemAvailable:"):
            return int(line.split()[1]) * 1024
    raise BootstrapCoordinatorError("memory-observation-unknown")


def _stable_fingerprint(path: Path) -> str:
    disk = os.statvfs(path)
    inputs = {
        "machine": platform.machine(),
        "system": platform.system(),
        "cpu_count": os.cpu_count(),
        "memory_total": next(
            line for line in Path("/proc/meminfo").read_text(encoding="ascii").splitlines()
            if line.startswith("MemTotal:")
        ),
        "cgroup": Path("/proc/self/cgroup").read_text(encoding="ascii"),
        "disk_device": os.stat(path).st_dev,
        "disk_blocks": disk.f_blocks,
        "disk_fragment": disk.f_frsize,
    }
    encoded = json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def observe_host(path: Path) -> HostObservation:
    disk = shutil.disk_usage(path)
    return HostObservation(
        cpu_count=os.cpu_count() or 0,
        memory_available_bytes=_read_memory_available(),
        disk_available_bytes=disk.free,
        fingerprint=_stable_fingerprint(path),
    )


def validate_envelope(envelope: dict[str, Any], observation: HostObservation, stage: str) -> ValidatedExecution:
    demand = envelope[stage]
    if observation.cpu_count < int(demand["cpu_count"]):
        raise BootstrapCoordinatorError(f"{stage}-cpu-overdraw")
    if observation.memory_available_bytes < int(demand["memory_bytes"]):
        raise BootstrapCoordinatorError(f"{stage}-memory-overdraw")
    if stage == "installer":
        ordered_peak = max(
            sum(int(prior["installed_bytes"]) for prior in demand["steps"][:index])
            + int(step["installed_bytes"]) + int(step["workspace_bytes"])
            for index, step in enumerate(demand["steps"])
        )
        required_disk = max(int(demand["tool_install_backing_bytes"]), ordered_peak)
    else:
        required_disk = int(demand["scratch_bytes"]) + int(demand["cache_write_bytes"])
    if observation.disk_available_bytes < required_disk:
        raise BootstrapCoordinatorError(f"{stage}-disk-overdraw")
    return ValidatedExecution(observation.fingerprint)


def _executable(path: Path) -> bool:
    return path.is_file() and os.access(path, os.X_OK)


def _first_executable(paths: Sequence[Path]) -> Path | None:
    return next((path for path in paths if path.is_absolute() and _executable(path)), None)


def candidate_paths(home: Path) -> dict[str, tuple[Path, ...]]:
    return {
        "apt_get": (Path("/usr/bin/apt-get"),),
        "ghcup": (home / ".ghcup/bin/ghcup", Path("/usr/local/bin/ghcup")),
        "ghc": (home / ".ghcup/bin/ghc-9.12.4", home / ".ghcup/bin/ghc"),
        "cabal": (home / ".ghcup/bin/cabal-3.16.1.0", home / ".ghcup/bin/cabal"),
        "kubectl": (home / ".local/bin/kubectl", Path("/usr/local/bin/kubectl"), Path("/usr/bin/kubectl")),
        "kind": (Path("/usr/local/bin/kind"), home / ".local/bin/kind"),
    }


def preflight(home: Path) -> Preflight:
    candidates = candidate_paths(home)
    return Preflight(**{
        name: _first_executable(candidates[name]) is not None
        for name in ("ghc", "cabal", "ghcup", "kind", "kubectl")
    })


def _fixed_environment(home: Path) -> dict[str, str]:
    return {"HOME": str(home), "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "PATH": "/usr/bin:/bin"}


def _limits(memory_bytes: int) -> None:
    resource.setrlimit(resource.RLIMIT_AS, (memory_bytes, memory_bytes))


def run_absolute(
    executable: Path,
    arguments: Sequence[str],
    *,
    home: Path,
    memory_bytes: int,
    cwd: Path | None = None,
) -> str:
    if not executable.is_absolute() or not _executable(executable):
        raise BootstrapCoordinatorError(f"non-absolute-or-missing-executable:{executable}")
    result = subprocess.run(
        [str(executable), *arguments], cwd=cwd, env=_fixed_environment(home), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
        preexec_fn=lambda: _limits(memory_bytes),
    )
    if result.returncode:
        raise BootstrapCoordinatorError(f"command-failed:{executable}:{result.returncode}\n{result.stdout}")
    return result.stdout


def _download(download: dict[str, str], target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(prefix=target.name + ".", dir=target.parent, delete=False) as handle:
        temporary = Path(handle.name)
        digest = hashlib.sha256()
        try:
            with urllib.request.urlopen(download["url"], timeout=120) as response:
                while block := response.read(1024 * 1024):
                    handle.write(block)
                    digest.update(block)
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    if digest.hexdigest() != download["sha256"]:
        temporary.unlink(missing_ok=True)
        raise BootstrapCoordinatorError(f"download-digest-mismatch:{target.name}")
    temporary.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR | stat.S_IRGRP | stat.S_IXGRP)
    os.replace(temporary, target)


def _validated_mutation(envelope: dict[str, Any], root: Path, stage: str) -> ValidatedExecution:
    observed = observe_host(root)
    token = validate_envelope(envelope, observed, stage)
    token.consume(observe_host(root))
    return token


def ensure_tools(envelope: dict[str, Any], root: Path, home: Path) -> ToolPaths:
    if platform.system().lower() != "linux" or platform.machine().lower() not in {"x86_64", "amd64"}:
        raise BootstrapCoordinatorError("phase24-bootstrap-coordinator-requires-linux-amd64")
    candidates = candidate_paths(home)
    apt_get = _first_executable(candidates["apt_get"])
    if apt_get is None:
        raise BootstrapCoordinatorError("package-manager-root-absent")
    memory = int(envelope["installer"]["memory_bytes"])
    ghcup = _first_executable(candidates["ghcup"])
    prerequisite_executables = (Path("/usr/bin/git"), Path("/usr/bin/gcc"), Path("/usr/bin/make"), Path("/usr/bin/xz"))
    if any(not _executable(path) for path in prerequisite_executables):
        _validated_mutation(envelope, root, "installer")
        run_absolute(apt_get, ["update"], home=home, memory_bytes=memory)
        _validated_mutation(envelope, root, "installer")
        run_absolute(apt_get, ["install", "-y", *APT_BUILD_PACKAGES], home=home, memory_bytes=memory)
    if ghcup is None:
        ghcup = candidates["ghcup"][0]
        _validated_mutation(envelope, root, "installer")
        _download(envelope["downloads"]["ghcup-linux-amd64"], ghcup)
    ghc = _first_executable(candidates["ghc"])
    if ghc is None:
        _validated_mutation(envelope, root, "installer")
        run_absolute(ghcup, ["install", "ghc", "9.12.4", "--set"], home=home, memory_bytes=memory)
        ghc = _first_executable(candidates["ghc"])
    cabal = _first_executable(candidates["cabal"])
    if cabal is None:
        _validated_mutation(envelope, root, "installer")
        run_absolute(ghcup, ["install", "cabal", "3.16.1.0", "--set"], home=home, memory_bytes=memory)
        cabal = _first_executable(candidates["cabal"])
    kubectl = _first_executable(candidates["kubectl"])
    if kubectl is None:
        kubectl = candidates["kubectl"][0]
        _validated_mutation(envelope, root, "installer")
        _download(envelope["downloads"]["kubectl-linux-amd64"], kubectl)
    kind = _first_executable(candidates["kind"])
    if kind is None:
        kind = candidates["kind"][1]
        _validated_mutation(envelope, root, "installer")
        _download(envelope["downloads"]["kind-linux-amd64"], kind)
    resolved = (ghcup, ghc, cabal, kubectl, kind)
    if any(path is None or not _executable(path) for path in resolved):
        raise BootstrapCoordinatorError("tool-install-did-not-converge")
    return ToolPaths(apt_get, ghcup, ghc, cabal, kubectl, kind)  # type: ignore[arg-type]


def build_binary(envelope: dict[str, Any], root: Path, home: Path, tools: ToolPaths) -> Path:
    build = envelope["build"]
    memory = int(build["memory_bytes"])
    jobs = str(int(build["concurrency"]))
    package_indexes = (
        home / ".cache/cabal/packages/hackage.haskell.org/01-index.tar",
        home / ".cabal/packages/hackage.haskell.org/01-index.tar",
    )
    if not any(path.is_file() for path in package_indexes):
        _validated_mutation(envelope, root, "build")
        run_absolute(tools.cabal, ["update"], home=home, memory_bytes=memory, cwd=root)
    _validated_mutation(envelope, root, "build")
    run_absolute(
        tools.cabal, ["build", "exe:amoebius", f"-j{jobs}", f"--with-compiler={tools.ghc}"],
        home=home, memory_bytes=memory, cwd=root,
    )
    output = run_absolute(
        tools.cabal, ["list-bin", "exe:amoebius", f"--with-compiler={tools.ghc}"],
        home=home, memory_bytes=memory, cwd=root,
    )
    binary = Path(output.strip())
    if not binary.is_absolute() or not _executable(binary):
        raise BootstrapCoordinatorError("built-binary-not-absolute-or-executable")
    return binary


def bootstrap_arguments(distro: str, replicas: int, layout: str = "unified") -> list[str]:
    if distro not in {"kind", "rke2"}:
        raise BootstrapCoordinatorError("unsupported-distro")
    if replicas < 1:
        raise BootstrapCoordinatorError("replicas-must-be-positive")
    if layout not in {"unified", "split-runtime", "split-image"}:
        raise BootstrapCoordinatorError("unsupported-filesystem-layout")
    return ["bootstrap", f"--distro={distro}", f"--replicas={replicas}", f"--layout={layout}"]


def handoff(binary: Path, arguments: Sequence[str]) -> NoReturn:
    if not binary.is_absolute() or not _executable(binary):
        raise BootstrapCoordinatorError("handoff-binary-invalid")
    os.execv(binary, [str(binary), *arguments])
    raise AssertionError("os.execv returned")
