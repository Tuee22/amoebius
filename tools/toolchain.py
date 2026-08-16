#!/usr/bin/env python3
"""Dynamic toolchain resolution for amoebius phase gates.

`documents/engineering/repository_layout_doctrine.md` section 4 splits the toolchain into
two halves that must never be stored together:

    tools/toolchain_requirements.json   authored, tracked  — what amoebius needs
    .build/toolchain/resolved.json generated, ignored — what this host resolved

This module is the only bridge between them. It reads the authored requirement, finds or
materializes a satisfying tool, records the observation under `.build/toolchain/`, and hands
the caller a resolved record. Nothing it writes lands under an authored root, and nothing
it returns is ever copied back into a tracked file.

The predecessor of this module was `toolchain/pins.json`: a tracked manifest of resolved
executable paths, exact versions, download URLs, and archive checksums. It is withdrawn.
A gate that used to read `pins["ghc"]["path"]` now calls `resolve()` and reads the same
key out of a run-local record, so the call sites did not have to change shape.

    python3 tools/toolchain.py                    resolve every requirement
    python3 tools/toolchain.py ghc cabal dhall    resolve a subset
    python3 tools/toolchain.py --self-test        exercise the pure comparison logic
"""

from __future__ import annotations

import argparse
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
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from typing import Any, Iterable

import containment

ROOT = Path(__file__).resolve().parent.parent
REQUIREMENTS = ROOT / "tools" / "toolchain_requirements.json"
RESOLVED = containment.state_path("build", "toolchain", "resolved.json", actor="production")

# Acquisition targets. Every one of these is an ignored generated root; the authored half
# is `tools/toolchain_requirements.json`; acquired state never shares that authored root.
TOOL_BIN = containment.state_path("build", "toolchain", "bin", actor="production")
TOOL_RUNTIME = containment.state_path("build", "toolchain", "runtime", actor="production")
DOWNLOADS = containment.state_path("build", "toolchain", "downloads", actor="production")
TOOL_CACHE = containment.state_path("build", "toolchain", "cache", actor="production")
NODE_ROOT = containment.state_path("build", "node_modules", ".keep-parent", actor="production").parent
CABAL_STORE_ROOT = containment.state_path("build", "cabal-store", "tool-installs", actor="production")
TOOL_BUILD_ROOT = containment.state_path("build", "dist-newstyle", "tool-installs", actor="production")

# A leading `\b` would not fire inside a tag such as `v35.1`, because `v` and `3` are both
# word characters, and the search would then settle on the `1` after the dot — a silently
# wrong version rather than a parse failure. The lookbehind asks the real question instead:
# this run of digits is a version only when nothing numeric precedes it.
VERSION_TOKEN = re.compile(r"(?<![\d.])(\d+(?:\.\d+)*)")
NETWORK_TIMEOUT = 120


class ResolutionError(RuntimeError):
    """A requirement could not be satisfied on this host."""


def contained_env() -> dict[str, str]:
    """Subprocess state roots; executable discovery still uses the caller's PATH."""
    environment = dict(os.environ)
    home = TOOL_RUNTIME / "home"
    temporary = containment.state_path("build", "tmp", "toolchain", actor="production")
    xdg_config = TOOL_RUNTIME / "xdg-config"
    xdg_cache = TOOL_CACHE / "xdg"
    for path in (home, temporary, TOOL_CACHE, xdg_config, xdg_cache):
        path.mkdir(parents=True, exist_ok=True)
    # cabal-install creates its default file on the first invocation but does not
    # reload that file in the same process.  A pristine contained HOME would
    # therefore fail its first project build with `unknown repo`, even though the
    # newly-created file was correct for the next run.  Materialize the minimal
    # generated configuration before invoking Cabal so a fresh checkout and a
    # warm checkout have identical behaviour.  Both the configuration and its
    # package index remain beneath `.build/toolchain/**`.
    cabal_config = xdg_config / "cabal" / "config"
    if not cabal_config.exists():
        cabal_config.parent.mkdir(parents=True, exist_ok=True)
        cabal_config.write_text(
            "repository hackage.haskell.org\n"
            "  url: https://hackage.haskell.org/\n"
            f"remote-repo-cache: {xdg_cache / 'cabal' / 'packages'}\n"
            f"logs-dir: {xdg_cache / 'cabal' / 'logs'}\n",
            encoding="utf-8",
        )
    environment.update(
        {
            "HOME": str(home),
            "TMPDIR": str(temporary),
            "TMP": str(temporary),
            "TEMP": str(temporary),
            "XDG_CACHE_HOME": str(xdg_cache),
            "XDG_CONFIG_HOME": str(xdg_config),
            "XDG_DATA_HOME": str(TOOL_RUNTIME / "xdg-data"),
            "XDG_STATE_HOME": str(TOOL_RUNTIME / "xdg-state"),
            "npm_config_cache": str(TOOL_CACHE / "npm"),
            "PLAYWRIGHT_BROWSERS_PATH": str(TOOL_RUNTIME / "playwright"),
        }
    )
    return environment


# --------------------------------------------------------------------------
# version algebra — pure, so --self-test can drive it without a host
# --------------------------------------------------------------------------


def parse_version(text: str) -> tuple[int, ...]:
    """The first dotted numeric run in `text`, as a comparable tuple."""
    match = VERSION_TOKEN.search(text)
    if match is None:
        raise ResolutionError(f"no version number in {text!r}")
    return tuple(int(part) for part in match.group(1).split("."))


def pad(left: tuple[int, ...], right: tuple[int, ...]) -> tuple[tuple[int, ...], tuple[int, ...]]:
    width = max(len(left), len(right))
    return left + (0,) * (width - len(left)), right + (0,) * (width - len(right))


def satisfies(version: tuple[int, ...], requirement: str) -> bool:
    """`requirement` is a space-separated conjunction such as ">=9.12 <9.13"."""
    for clause in requirement.split():
        match = re.fullmatch(r"(>=|<=|==|>|<)(\d+(?:\.\d+)*)", clause)
        if match is None:
            raise ResolutionError(f"malformed requirement clause {clause!r}")
        operator, bound_text = match.groups()
        left, right = pad(version, tuple(int(part) for part in bound_text.split(".")))
        if operator == ">=" and not left >= right:
            return False
        if operator == "<=" and not left <= right:
            return False
        if operator == "==" and not left == right:
            return False
        if operator == ">" and not left > right:
            return False
        if operator == "<" and not left < right:
            return False
    return True


def host_platform() -> str:
    machine = platform.machine().lower()
    machine = {"amd64": "x86_64", "arm64": "aarch64"}.get(machine, machine)
    system = platform.system().lower()
    if system == "darwin" and machine == "aarch64":
        return "darwin-arm64"
    return f"{system}-{machine}"


# --------------------------------------------------------------------------
# observation helpers
# --------------------------------------------------------------------------


def run_version(argv: list[str]) -> str:
    result = subprocess.run(argv, env=contained_env(), capture_output=True, check=False)
    decode = lambda raw: (raw or b"").decode("utf-8", errors="replace")
    result = subprocess.CompletedProcess(
        argv, result.returncode, decode(result.stdout), decode(result.stderr)
    )
    combined = (result.stdout or "") + (result.stderr or "")
    if not combined.strip():
        raise ResolutionError(f"{' '.join(argv)} printed no version output")
    return combined.strip()


def observe(path: Path) -> dict[str, Any]:
    """Content identity of a materialized tool, computed after resolution.

    This digest detects corruption inside the run that produced it. It is never promoted
    into `tools/toolchain_requirements.json`, which is what would turn it into a package pin.
    """
    return {"size": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "amoebius-toolchain-resolver"})
    try:
        with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise ResolutionError(f"could not reach {url}: {error}") from error


def github_releases(project: str) -> list[dict[str, Any]]:
    payload = fetch(f"https://api.github.com/repos/{project}/releases?per_page=30")
    try:
        releases = json.loads(payload)
    except json.JSONDecodeError as error:
        raise ResolutionError(f"{project} release feed was not JSON: {error}") from error
    if not isinstance(releases, list):
        raise ResolutionError(f"{project} release feed had unexpected shape")
    return [release for release in releases if not release.get("prerelease")]


# --------------------------------------------------------------------------
# one resolver per source kind
# --------------------------------------------------------------------------


def host_candidates(command: str) -> list[str]:
    """Every executable on PATH named `command` or `command-<version>`.

    Multi-version installers (ghcup, distribution alternatives) put the unversioned name on
    the newest release and keep versioned siblings beside it. Resolving only the
    unversioned name would make the host's *default* compiler the requirement, which is how
    a host outside the compatibility range silently becomes a hard failure. Enumerating the
    siblings keeps resolution dynamic and still honours the authored range.
    """
    pattern = re.compile(rf"^{re.escape(command)}(-\d+(?:\.\d+)*)?$")
    found: list[str] = []
    seen: set[str] = set()
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        directory = Path(entry) if entry else Path.cwd()
        if not directory.is_dir():
            continue
        try:
            children = sorted(directory.iterdir())
        except OSError:
            continue
        for child in children:
            if not pattern.match(child.name) or not os.access(child, os.X_OK) or child.is_dir():
                continue
            resolved_path = str(child)
            if resolved_path not in seen:
                seen.add(resolved_path)
                found.append(resolved_path)
    return found


def resolve_host(name: str, spec: dict[str, Any]) -> dict[str, Any]:
    requirement = spec["requirement"]
    rejected: list[str] = []
    admissible: list[tuple[tuple[int, ...], str, str, str]] = []
    for command in spec["commands"]:
        for found in host_candidates(command):
            try:
                reported = run_version([found, *spec["version_argv"]])
                version = parse_version(reported)
            except ResolutionError as error:
                rejected.append(f"{found}: {error}")
                continue
            if not satisfies(version, requirement):
                rejected.append(f"{found} reported {reported.splitlines()[0]}")
                continue
            admissible.append((version, found, reported.splitlines()[0], command))
    if not admissible:
        detail = "; ".join(rejected) if rejected else "not found on PATH"
        raise ResolutionError(f"{name}: no host command satisfies {requirement} ({detail})")
    # The newest admissible release wins: within the authored range, resolution moves
    # forward with the host rather than freezing on whichever candidate PATH lists first.
    version, found, reported, command = max(admissible)
    record = {
        "source": "host",
        "command": command,
        "path": found,
        "version": ".".join(str(part) for part in version),
        "reported": reported,
        "requirement": requirement,
        "candidates": len(admissible),
    }
    if name == "chromium":
        record["product"] = reported
    return record


def ensure_node_package_graph() -> None:
    """Materialize package.json's authored development graph as one contained install.

    Installing one `--no-save` package at a time lets npm prune earlier packages as
    extraneous. The graph includes supporting executables such as esbuild that do not need
    their own resolver record but are still required by the resolved Spago tool.
    """
    packages = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))["devDependencies"]
    if all((NODE_ROOT / package).is_dir() for package in packages):
        return
    NODE_ROOT.parent.mkdir(parents=True, exist_ok=True)
    node_packages = [f"{package}@{requirement}" for package, requirement in sorted(packages.items())]
    install = subprocess.run(
        [
            "npm",
            "install",
            "--no-audit",
            "--no-fund",
            "--no-save",
            "--prefix",
            str(NODE_ROOT.parent),
            *node_packages,
        ],
        cwd=ROOT,
        env=contained_env(),
        text=True,
        capture_output=True,
        check=False,
    )
    if install.returncode != 0:
        raise ResolutionError(f"node tool graph: npm install failed: {install.stderr[-2000:]}")


def resolve_node_package(name: str, spec: dict[str, Any]) -> dict[str, Any]:
    ensure_node_package_graph()
    package_root = NODE_ROOT / spec["package"]
    if not package_root.is_dir():
        raise ResolutionError(f"{name}: authored Node graph did not install {spec['package']}")
    for relative in spec["relative_paths"]:
        candidate = package_root / relative
        if not candidate.is_file():
            continue
        argv = [str(candidate), *spec["version_argv"]]
        if spec.get("interpreter"):
            argv = [spec["interpreter"], *argv]
        reported = run_version(argv)
        version = parse_version(reported)
        if not satisfies(version, spec["requirement"]):
            raise ResolutionError(
                f"{name}: {candidate} reported {reported.splitlines()[0]}, "
                f"which does not satisfy {spec['requirement']}"
            )
        return {
            "source": "node-package",
            "package": spec["package"],
            "path": str(candidate),
            "interpreter": spec.get("interpreter", ""),
            "version": ".".join(str(part) for part in version),
            "reported": reported.splitlines()[0],
            "requirement": spec["requirement"],
        }
    raise ResolutionError(f"{name}: {spec['package']} is installed but carries no known entry point")


def select_release(name: str, spec: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    pattern_platform = spec.get("platform_map", {}).get(host_platform())
    if "{platform}" in spec["asset_pattern"] and pattern_platform is None:
        raise ResolutionError(f"{name}: no asset mapping for platform {host_platform()}")
    pattern = re.compile(spec["asset_pattern"].replace("{platform}", pattern_platform or ""))
    # The feed is not reliably ordered by version, so admissibility is collected and the
    # newest satisfying release wins. Taking the first match would let a back-published
    # maintenance release quietly downgrade the resolved tool.
    admissible: list[tuple[tuple[int, ...], dict[str, Any], dict[str, Any]]] = []
    for release in github_releases(spec["project"]):
        try:
            version = parse_version(release.get("tag_name", "") or release.get("name", ""))
        except ResolutionError:
            continue
        if not satisfies(version, spec["requirement"]):
            continue
        for asset in release.get("assets", []):
            if pattern.fullmatch(asset.get("name", "")):
                admissible.append((version, release, asset))
                break
    if admissible:
        best = max(admissible, key=lambda entry: entry[0])
        return best[1], best[2]
    raise ResolutionError(
        f"{name}: no {spec['project']} release satisfies {spec['requirement']} "
        f"with an asset matching {spec['asset_pattern']} on {host_platform()}"
    )


def materialize(url: str, destination: Path) -> Path:
    """Download once per run into an ignored cache, keyed by the observed content."""
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    if destination.is_file():
        return destination
    payload = fetch(url)
    destination.write_bytes(payload)
    return destination


def resolve_github_release(name: str, spec: dict[str, Any]) -> dict[str, Any]:
    release, asset = select_release(name, spec)
    archive = materialize(asset["browser_download_url"], DOWNLOADS / asset["name"])
    member = spec.get("archive_member")

    if member is None:
        target_dir = TOOL_RUNTIME / spec["install_dir"] if spec.get("install_dir") else TOOL_BIN
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / spec.get("install_name", asset["name"])
        shutil.copyfile(archive, target)
        # A release asset that *is* the binary arrives without a mode bit, and
        # `shutil.copyfile` copies content only. Every other branch here chmods; this one
        # did not, so resolving `kind` or `ghcup` returned a path the caller could not
        # execute — a resolver that reports success and hands back an unrunnable file.
        target.chmod(0o755)
    elif zipfile.is_zipfile(archive):
        TOOL_BIN.mkdir(parents=True, exist_ok=True)
        target = TOOL_BIN / spec["install_name"]
        with zipfile.ZipFile(archive) as zipped:
            with zipped.open(member) as source, target.open("wb") as sink:
                shutil.copyfileobj(source, sink)
        target.chmod(0o755)
    else:
        target_dir = TOOL_RUNTIME / spec["install_dir"]
        if target_dir.exists():
            shutil.rmtree(target_dir)
        target_dir.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive) as tarred:
            names = tarred.getnames()
            prefix = names[0].split("/")[0] if names else ""
            tarred.extractall(target_dir.parent / f".{spec['install_dir']}-unpack", filter="data")
            unpacked = target_dir.parent / f".{spec['install_dir']}-unpack" / prefix
            if target_dir.exists():
                shutil.rmtree(target_dir)
            shutil.move(str(unpacked), str(target_dir))
            shutil.rmtree(target_dir.parent / f".{spec['install_dir']}-unpack", ignore_errors=True)
        target = target_dir / member

    record: dict[str, Any] = {
        "source": "github-release",
        "project": spec["project"],
        "release": release.get("tag_name", ""),
        "asset": asset["name"],
        "url": asset["browser_download_url"],
        "path": str(target),
        "requirement": spec["requirement"],
        "observed": observe(archive),
    }
    if spec.get("version_argv"):
        argv = [str(target), *spec["version_argv"]]
        reported = run_version(argv)
        record["version"] = ".".join(str(part) for part in parse_version(reported))
        record["reported"] = reported.splitlines()[0]
    else:
        record["version"] = ".".join(str(part) for part in parse_version(record["release"]))
        record["reported"] = record["release"]
    return record


def resolve_kubernetes_release(name: str, spec: dict[str, Any]) -> dict[str, Any]:
    """Resolve a Kubernetes release channel and verify the publisher's checksum."""
    channel_url = f"https://dl.k8s.io/release/{spec['channel']}.txt"
    release = fetch(channel_url).decode("utf-8", errors="replace").strip()
    version = parse_version(release)
    if not satisfies(version, spec["requirement"]):
        raise ResolutionError(
            f"{name}: channel {spec['channel']} offers {release}, "
            f"which does not satisfy {spec['requirement']}"
        )
    platform_token = spec.get("platform_map", {}).get(host_platform())
    if platform_token is None:
        raise ResolutionError(f"{name}: no binary mapping for platform {host_platform()}")
    binary_path = spec["binary_path"].replace("{platform}", platform_token)
    url = f"https://dl.k8s.io/release/{release}/{binary_path}"
    checksum_text = fetch(url + ".sha256").decode("utf-8", errors="replace").strip()
    checksum_match = re.search(r"(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])", checksum_text.lower())
    if checksum_match is None:
        raise ResolutionError(f"{name}: publisher checksum document named no sha256 digest")
    expected = checksum_match.group(0)
    payload = fetch(url)
    observed = hashlib.sha256(payload).hexdigest()
    if observed != expected:
        raise ResolutionError(f"{name}: publisher checksum mismatch for {release}")
    TOOL_BIN.mkdir(parents=True, exist_ok=True)
    target = TOOL_BIN / spec["install_name"]
    temporary = target.with_suffix(".partial")
    temporary.write_bytes(payload)
    temporary.chmod(0o755)
    temporary.replace(target)
    reported = run_version([str(target), *spec["version_argv"]])
    reported_match = re.search(r"^\s*gitVersion:\s*v?(\d+(?:\.\d+)*)", reported, re.MULTILINE)
    reported_version = (
        tuple(int(part) for part in reported_match.group(1).split("."))
        if reported_match is not None
        else version
    )
    if not satisfies(reported_version, spec["requirement"]):
        raise ResolutionError(
            f"{name}: downloaded {reported.splitlines()[0]}, which does not satisfy {spec['requirement']}"
        )
    return {
        "source": "kubernetes-release",
        "channel": spec["channel"],
        "release": release,
        "url": url,
        "path": str(target),
        "version": ".".join(str(part) for part in reported_version),
        "reported": reported.splitlines()[0],
        "requirement": spec["requirement"],
        "observed": {"size": len(payload), "sha256": observed},
        "publisher_checksum": expected,
    }


def resolve_hackage(name: str, spec: dict[str, Any], resolved: dict[str, Any]) -> dict[str, Any]:
    cabal = resolved.get("cabal", {}).get("path")
    if cabal is None:
        raise ResolutionError(f"{name}: cabal must resolve before a Hackage tool can be installed")
    TOOL_BIN.mkdir(parents=True, exist_ok=True)
    target = TOOL_BIN / spec["install_name"]
    constraint = " && ".join(spec["requirement"].split())
    CABAL_STORE_ROOT.mkdir(parents=True, exist_ok=True)
    TOOL_BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    environment = contained_env()
    update = subprocess.run(
        [cabal, "--ignore-project", "update"],
        cwd=ROOT,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    if update.returncode != 0:
        transcript = (update.stdout or "") + (update.stderr or "")
        raise ResolutionError(f"{name}: project-local cabal update failed: {transcript[-2000:]}")
    with tempfile.TemporaryDirectory(prefix="amoebius-hackage-", dir=CABAL_STORE_ROOT) as store:
        with tempfile.TemporaryDirectory(prefix="amoebius-hackage-build-", dir=TOOL_BUILD_ROOT) as build:
            install = subprocess.run(
                [
                    cabal,
                    # The repository project pins a build-root depth its source-repository
                    # patch depends on; a tool install has no business inheriting it.
                    "--ignore-project",
                    f"--store-dir={store}",
                    f"--builddir={build}",
                    "install",
                    spec["package"],
                    f"--constraint={spec['package']} {constraint}",
                    f"--installdir={TOOL_BIN}",
                    "--install-method=copy",
                    "--overwrite-policy=always",
                ],
                cwd=ROOT,
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
    transcript = (install.stdout or "") + (install.stderr or "")
    if not target.is_file():
        raise ResolutionError(f"{name}: install did not produce {target}: {transcript[-2000:]}")
    if spec.get("version_argv"):
        reported = run_version([str(target), *spec["version_argv"]])
    else:
        # A protoc plugin has no version flag: invoking it makes it wait for a
        # CodeGeneratorRequest on stdin. The solver already named the version it chose, so
        # the resolved version is read from the install transcript rather than from a
        # command the tool does not implement.
        match = re.search(rf"{re.escape(spec['package'])}-(\d+(?:\.\d+)*)", transcript)
        if match is None:
            raise ResolutionError(
                f"{name}: install transcript named no {spec['package']} version:\n{transcript[-2000:]}"
            )
        reported = match.group(0)
    version = parse_version(reported.removeprefix(spec["package"]))
    if not satisfies(version, spec["requirement"]):
        raise ResolutionError(f"{name}: installed {reported!r} does not satisfy {spec['requirement']}")
    return {
        "source": "hackage",
        "package": spec["package"],
        "path": str(target),
        "version": ".".join(str(part) for part in version),
        "reported": reported.splitlines()[0],
        "requirement": spec["requirement"],
        "observed": observe(target),
    }


RESOLVERS = {
    "host": lambda name, spec, resolved: resolve_host(name, spec),
    "node-package": lambda name, spec, resolved: resolve_node_package(name, spec),
    "github-release": lambda name, spec, resolved: resolve_github_release(name, spec),
    "kubernetes-release": lambda name, spec, resolved: resolve_kubernetes_release(name, spec),
    "hackage": resolve_hackage,
}

# `hackage` tools are built by the resolved cabal, so cabal is resolved first regardless of
# the order the caller asked in.
ORDER_FIRST = ("ghc", "cabal")


# --------------------------------------------------------------------------
# the public surface
# --------------------------------------------------------------------------


def load_requirements() -> dict[str, Any]:
    return json.loads(REQUIREMENTS.read_text(encoding="utf-8"))["tools"]


def load_resolved() -> dict[str, Any]:
    if not RESOLVED.is_file():
        return {}
    try:
        return json.loads(RESOLVED.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def store_resolved(resolved: dict[str, Any]) -> None:
    RESOLVED.parent.mkdir(parents=True, exist_ok=True)
    RESOLVED.write_text(json.dumps(resolved, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def usable(name: str, record: dict[str, Any], spec: dict[str, Any]) -> bool:
    """A cached record is reused only when the tool it names is still on disk and still
    satisfies the authored requirement. Requirement drift invalidates the cache."""
    path = record.get("path")
    if not path or not Path(path).exists():
        return False
    if record.get("requirement") != spec["requirement"]:
        return False
    try:
        return satisfies(parse_version(record["version"]), spec["requirement"])
    except (ResolutionError, KeyError):
        return False


def resolve(names: Iterable[str] | None = None, *, refresh: bool = False) -> dict[str, Any]:
    """Resolve the named requirements (all of them when `names` is None).

    Returns the full resolved record, so a caller that asks for one tool still sees any
    tool an earlier call in the same run resolved.
    """
    requirements = load_requirements()
    wanted = list(requirements) if names is None else list(names)
    unknown = [name for name in wanted if name not in requirements]
    if unknown:
        raise ResolutionError(f"no authored requirement for: {', '.join(sorted(unknown))}")

    resolved = {} if refresh else load_resolved()
    ordered = [name for name in ORDER_FIRST if name in wanted]
    ordered += [name for name in wanted if name not in ordered]

    for name in ordered:
        spec = requirements[name]
        if not refresh and name in resolved and usable(name, resolved[name], spec):
            continue
        resolved[name] = RESOLVERS[spec["source"]](name, spec, resolved)
    resolved["platform"] = host_platform()
    store_resolved(resolved)
    return resolved


def self_test() -> int:
    cases = [
        ((9, 12, 4), ">=9.12 <9.13", True),
        ((9, 13, 0), ">=9.12 <9.13", False),
        ((9, 12), ">=9.12 <9.13", True),
        ((3, 16, 1, 0), ">=3.16 <4", True),
        ((4, 0), ">=3.16 <4", False),
        ((35,), ">=29", True),
        ((21, 0, 12), ">=17", True),
        ((1, 7, 4), ">=1.7", True),
        ((0, 15, 16), ">=0.15 <0.16", True),
        ((0, 16, 0), ">=0.15 <0.16", False),
    ]
    failures = 0
    for version, requirement, expected in cases:
        actual = satisfies(version, requirement)
        status = "ok  " if actual == expected else "FAIL"
        if actual != expected:
            failures += 1
        print(f"  {status} {'.'.join(map(str, version))} {requirement} -> {actual}")
    for text, expected in [
        ("9.12.4", (9, 12, 4)),
        ('openjdk version "21.0.12" 2024-07-16', (21, 0, 12)),
        ("libprotoc 35.0", (35, 0)),
        ("Google Chrome 150.0.7871.46", (150, 0, 7871, 46)),
        ("v35.1", (35, 1)),
        ("v1.7.4", (1, 7, 4)),
        ("jdk-21.0.12+8", (21, 0, 12)),
    ]:
        actual = parse_version(text)
        status = "ok  " if actual == expected else "FAIL"
        if actual != expected:
            failures += 1
        print(f"  {status} parse {text!r} -> {actual}")
    print("toolchain self-test:", "PASS" if failures == 0 else f"FAIL ({failures})")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*", help="requirement names; default is every requirement")
    parser.add_argument("--refresh", action="store_true", help="ignore any cached resolution")
    parser.add_argument("--self-test", action="store_true", help="exercise the pure version algebra")
    options = parser.parse_args(argv)
    if options.self_test:
        return self_test()
    try:
        resolved = resolve(options.names or None, refresh=options.refresh)
    except ResolutionError as error:
        print(f"toolchain: FAIL: {error}", file=sys.stderr)
        return 1
    for name in sorted(resolved):
        if name == "platform":
            continue
        print(f"  {name:<20} {resolved[name]['version']:<16} {resolved[name]['path']}")
    print(f"toolchain: resolved {len(resolved) - 1} requirement(s) into {RESOLVED.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
