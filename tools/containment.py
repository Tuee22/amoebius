#!/usr/bin/env python3
"""Closed project-state roots, safe test ownership, and host-delta observation.

The physical checkout owns every amoebius byte.  Callers select one of the closed
state classes instead of constructing paths themselves; tests may never select the
production class, and production may never read the cleartext test-secrets seam.

This module has no import-time filesystem effects.  Its host observer is read-only.
"""

from __future__ import annotations

import ast
import hashlib
import json
import os
import pwd
import re
import shutil
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent.resolve()
STATE_ROOTS = {
    "build": ROOT / ".build",
    "production": ROOT / ".data",
    "test": ROOT / ".test_data",
}
TEST_SECRETS = ROOT / ("test-" + "secrets.dhall")
MARKER = ".amoebius-test-owner.json"
MARKER_SCHEMA = 1


class ContainmentError(ValueError):
    """A proposed path, resource, secret access, or deletion is outside policy."""


def _beneath(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return path != root


def state_path(state_class: str, *parts: str, actor: str = "production") -> Path:
    """Resolve one state path from the physical checkout and reject every alias.

    Existing symlink components are resolved before the boundary check, so a link
    beneath a state root cannot redirect a mutation out of the checkout.
    """
    if state_class not in STATE_ROOTS:
        raise ContainmentError(f"unknown state class {state_class!r}")
    if actor == "test" and state_class == "production":
        raise ContainmentError("test actor may not select .data production state")
    if actor == "production" and state_class == "test":
        raise ContainmentError("production actor may not select .test_data test state")
    root = STATE_ROOTS[state_class].resolve(strict=False)
    candidate = root.joinpath(*parts).resolve(strict=False)
    if not _beneath(candidate, root):
        raise ContainmentError(
            f"{state_class} state path escapes {root.relative_to(ROOT)}: {candidate}"
        )
    return candidate


def require_state_path(path: Path | str, state_class: str, *, actor: str) -> Path:
    """Validate an already-resolved destination against its one declared class."""
    if state_class not in STATE_ROOTS:
        raise ContainmentError(f"unknown state class {state_class!r}")
    if actor == "test" and state_class == "production":
        raise ContainmentError("test actor may not select .data production state")
    if actor == "production" and state_class == "test":
        raise ContainmentError("production actor may not select .test_data test state")
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    candidate = candidate.resolve(strict=False)
    root = STATE_ROOTS[state_class].resolve(strict=False)
    if not _beneath(candidate, root):
        raise ContainmentError(
            f"{state_class} state must be beneath {root.relative_to(ROOT)}, got {candidate}"
        )
    return candidate


def require_project_resource(kind: str, storage: Path | str, *, scope: str) -> Path:
    """Reject host-global project resources before a launcher creates them."""
    if scope != "project":
        raise ContainmentError(f"{kind} uses forbidden {scope} resource scope")
    candidate = Path(storage)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    candidate = candidate.resolve(strict=False)
    allowed = tuple(root.resolve(strict=False) for root in STATE_ROOTS.values())
    if not any(_beneath(candidate, root) for root in allowed):
        raise ContainmentError(f"{kind} storage escapes the closed state roots: {candidate}")
    return candidate


def require_secret_access(actor: str, path: Path | str = TEST_SECRETS) -> Path:
    """The ignored cleartext seam is test-only and has exactly one pathname."""
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    candidate = candidate.resolve(strict=False)
    if candidate != TEST_SECRETS.resolve(strict=False):
        raise ContainmentError(f"unknown cleartext secret path: {candidate}")
    if actor != "elevated-test-harness":
        raise ContainmentError("production and ordinary tools reject test-secrets.dhall")
    return candidate


def require_secret_sink(sink: str) -> None:
    """Secret values may go only to the ordinary interactive prompt, never storage."""
    if sink != "operator-prompt-stdin":
        raise ContainmentError(f"test secret copy is forbidden at sink {sink!r}")


@dataclass(frozen=True)
class TestRun:
    path: Path
    run_id: str
    marker_digest: str


def _marker_bytes(run_id: str) -> bytes:
    value = {"schema": MARKER_SCHEMA, "run_id": run_id, "repository": str(ROOT)}
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def create_test_run(run_id: str) -> TestRun:
    """Create one uniquely owned test descendant and its marker before mutation."""
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", run_id):
        raise ContainmentError("test run id is not a safe single path component")
    path = state_path("test", "runs", run_id, actor="test")
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        path.mkdir()
    except FileExistsError as exc:
        raise ContainmentError(f"test run already exists: {path}") from exc
    payload = _marker_bytes(run_id)
    marker = path / MARKER
    try:
        with marker.open("xb") as handle:
            handle.write(payload)
    except Exception:
        path.rmdir()
        raise
    return TestRun(path, run_id, hashlib.sha256(payload).hexdigest())


def cleanup_test_run(run: TestRun) -> None:
    """Delete only the exact descendant whose unchanged marker proves ownership."""
    expected = state_path("test", "runs", run.run_id, actor="test")
    actual = run.path.resolve(strict=False)
    if actual != expected:
        raise ContainmentError("test run path changed after ownership was recorded")
    marker = actual / MARKER
    try:
        payload = marker.read_bytes()
    except OSError as exc:
        raise ContainmentError("test run ownership marker is missing") from exc
    if hashlib.sha256(payload).hexdigest() != run.marker_digest:
        raise ContainmentError("test run ownership marker changed")
    if payload != _marker_bytes(run.run_id):
        raise ContainmentError("test run ownership marker does not name this run")
    # Keep the marker until every owned child has been removed. If a restrictive
    # daemon-created directory makes cleanup fail, the same TestRun can be retried
    # without losing the proof that authorizes deletion of this exact descendant.
    for child in actual.iterdir():
        if child == marker:
            continue
        if child.is_symlink() or child.is_file():
            child.unlink()
        else:
            shutil.rmtree(child)
    marker.unlink()
    actual.rmdir()


@dataclass(frozen=True)
class HostInventory:
    external_paths: tuple[str, ...] = ()
    mounts: tuple[str, ...] = ()
    loop_devices: tuple[str, ...] = ()
    test_mounts: tuple[str, ...] = ()
    test_loop_devices: tuple[str, ...] = ()
    network_links: tuple[str, ...] = ()
    amoebius_firewall_rules: tuple[str, ...] = ()
    docker_containers: tuple[str, ...] = ()
    docker_volumes: tuple[str, ...] = ()
    docker_build_cache: tuple[str, ...] = ()
    docker_daemon_roots: tuple[str, ...] = ()
    observation_errors: tuple[str, ...] = ()

    def canonical_bytes(self) -> bytes:
        return (json.dumps(asdict(self), sort_keys=True, separators=(",", ":")) + "\n").encode()


def _outside_checkout(path: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(ROOT)
    except ValueError:
        return True
    return False


def _external_paths() -> tuple[str, ...]:
    user_home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    candidates = [
        Path("/var/lib") / "amoebius",
        user_home / ".amoebius",
        user_home / ".local" / "share" / "amoebius",
    ]
    for parent in (Path("/tmp"), Path("/var/tmp")):
        try:
            candidates.extend(parent.glob("amoebius*"))
        except OSError:
            pass
    return tuple(sorted(str(path) for path in candidates if path.exists() and _outside_checkout(path)))


def _mounts() -> tuple[str, ...]:
    rows: list[str] = []
    try:
        lines = Path("/proc/self/mountinfo").read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ()
    for line in lines:
        left, separator, right = line.partition(" - ")
        fields = left.split()
        if not separator or len(fields) < 5:
            continue
        mountpoint = Path(fields[4].replace("\\040", " "))
        if "amoebius" in line.lower() and _outside_checkout(mountpoint):
            rows.append(line)
    return tuple(sorted(rows))


def _loop_devices() -> tuple[str, ...]:
    rows: list[str] = []
    for backing in Path("/sys/block").glob("loop*/loop/backing_file"):
        try:
            value = backing.read_text(encoding="utf-8", errors="replace").strip()
        except OSError:
            continue
        if "amoebius" in value.lower() and _outside_checkout(Path(value)):
            rows.append(f"{backing}:{value}")
    return tuple(sorted(rows))


def _contained_test_mounts() -> tuple[str, ...]:
    root = (ROOT / ".test_data").resolve(strict=False)
    rows: list[str] = []
    try:
        lines = Path("/proc/self/mountinfo").read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ()
    for line in lines:
        fields = line.split()
        if len(fields) < 5:
            continue
        target = Path(fields[4].replace("\\040", " ")).resolve(strict=False)
        try:
            target.relative_to(root)
        except ValueError:
            continue
        rows.append(line)
    return tuple(sorted(rows))


def _contained_test_loops() -> tuple[str, ...]:
    root = (ROOT / ".test_data").resolve(strict=False)
    rows: list[str] = []
    for backing in Path("/sys/block").glob("loop*/loop/backing_file"):
        try:
            value = backing.read_text(encoding="utf-8", errors="replace").strip()
            Path(value).resolve(strict=False).relative_to(root)
        except (OSError, ValueError):
            continue
        rows.append(f"{backing}:{value}")
    return tuple(sorted(rows))


def _network_links() -> tuple[str, ...]:
    try:
        result = subprocess.run(
            ["/usr/sbin/ip", "-o", "link", "show"], cwd=ROOT, text=True,
            capture_output=True, timeout=10, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ()
    if result.returncode:
        return ()
    rows = []
    for line in result.stdout.splitlines():
        fields = line.split(":", 2)
        name = fields[1].strip().split("@", 1)[0] if len(fields) > 1 else ""
        if re.fullmatch(r"(?:ambr[0-9a-f]{8}|br-[0-9a-f]{12})", name):
            rows.append(line)
    return tuple(sorted(rows))


def _amoebius_firewall_rules() -> tuple[tuple[str, ...], str]:
    try:
        result = subprocess.run(
            ["/usr/bin/sudo", "-n", "/usr/sbin/iptables-save"], cwd=ROOT, text=True,
            capture_output=True, timeout=10, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return (), f"firewall observation failed: {type(exc).__name__}"
    if result.returncode:
        first = (result.stderr or result.stdout).strip().splitlines()
        detail = first[0] if first else f"exit {result.returncode}"
        return (), f"firewall observation unavailable: {detail}"
    return tuple(sorted(line for line in result.stdout.splitlines() if re.search(r"ambr[0-9a-f]{8}", line))), ""


def _docker(command: list[str]) -> tuple[tuple[str, ...], str]:
    executable = Path("/usr/bin/docker")
    if not executable.is_file():
        return (), "docker executable unavailable"
    try:
        result = subprocess.run(
            [str(executable), *command],
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return (), f"docker observation failed: {type(exc).__name__}"
    if result.returncode != 0:
        first = (result.stderr or result.stdout).strip().splitlines()
        detail = first[0] if first else f"exit {result.returncode}"
        return (), f"docker observation unavailable: {detail}"
    return tuple(sorted(line for line in result.stdout.splitlines() if line.strip())), ""


def host_inventory() -> HostInventory:
    """Capture the declared outside-host surfaces without mutating any of them."""
    containers, container_error = _docker(["ps", "-a", "--format", "{{json .}}"])
    volumes, volume_error = _docker(["volume", "ls", "--format", "{{json .}}"])
    cache, cache_error = _docker(["builder", "du"])
    daemon, daemon_error = _docker(["info", "--format", "{{json .DockerRootDir}}"])
    firewall, firewall_error = _amoebius_firewall_rules()
    errors = tuple(sorted({e for e in (container_error, volume_error, cache_error, daemon_error, firewall_error) if e}))
    return HostInventory(
        external_paths=_external_paths(),
        mounts=_mounts(),
        loop_devices=_loop_devices(),
        test_mounts=_contained_test_mounts(),
        test_loop_devices=_contained_test_loops(),
        network_links=_network_links(),
        amoebius_firewall_rules=firewall,
        docker_containers=tuple(row for row in containers if "amoebius" in row.lower()),
        docker_volumes=tuple(row for row in volumes if "amoebius" in row.lower()),
        docker_build_cache=cache,
        docker_daemon_roots=daemon,
        observation_errors=errors,
    )


def host_inventory_problems(before: HostInventory, after: HostInventory) -> list[str]:
    problems: list[str] = []
    if before.canonical_bytes() != after.canonical_bytes():
        problems.append("outside-host inventory changed during the gate")
    for field in (
        "external_paths", "mounts", "loop_devices", "test_mounts", "test_loop_devices",
        "amoebius_firewall_rules", "docker_containers", "docker_volumes",
    ):
        values = getattr(after, field)
        if values:
            problems.append(f"outside-host inventory contains amoebius {field.replace('_', ' ')}")
    return problems


TEMP_CALLS = {"TemporaryDirectory", "NamedTemporaryFile", "mkdtemp", "mkstemp"}
BANNED_PATH_PARTS = (
    "/" + "tmp/amoebius",
    "/var/" + "tmp/amoebius",
    "/var/lib/" + "amoebius",
    ".local/share/" + "amoebius",
    "." + "amoebius/",
)


def scan_source(relative: str, text: str) -> list[str]:
    """Find evident host escapes in executable source; diagnostics are line-stable."""
    findings: list[str] = []
    if relative.endswith(".py"):
        try:
            tree = ast.parse(text)
        except SyntaxError:
            tree = None
        if tree is not None:
            for node in ast.walk(tree):
                if isinstance(node, ast.Call):
                    name = ""
                    if isinstance(node.func, ast.Name):
                        name = node.func.id
                    elif isinstance(node.func, ast.Attribute):
                        name = node.func.attr
                    if name in TEMP_CALLS and not any(word.arg == "dir" for word in node.keywords):
                        findings.append(f"line {node.lineno}: temporary state uses the host default directory")
                if isinstance(node, ast.Constant) and isinstance(node.value, str):
                    for fragment in BANNED_PATH_PARTS:
                        if fragment in node.value:
                            findings.append(
                                f"line {node.lineno}: path literal names forbidden outside-host state {fragment!r}"
                            )
    return sorted(set(findings))


def production_secret_references(relative: str, text: str) -> list[str]:
    """Reject the cleartext seam from authored production entry-point source."""
    production = relative.startswith(("app/", "src/", "pb/", "pulumi/"))
    if production and ("test-" + "secrets.dhall") in text:
        return ["production source names test-secrets.dhall"]
    return []
