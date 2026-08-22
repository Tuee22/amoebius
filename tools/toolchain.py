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

**Discover, then ensure.** The predecessor of *this* revision had a `host` source kind
meaning "expected on the developer host", and four requirements declared it. That is the
one thing `substrate_doctrine.md` §3 forbids: a tool with a supported install plan is
probed, installed when absent, resolved to an absolute path, and invoked by it. The kind is
retired. What an operator must supply is the **floor** of §3.1 — a package-manager root, a
hardware or firmware fact, a credentialed account — which is authored data in the same
requirements manifest and is checked *before* resolution, so a host that cannot support the
run says so with a remedy instead of failing four requirements deep.

    python3 tools/toolchain.py                    resolve every requirement
    python3 tools/toolchain.py ghc cabal dhall    resolve a subset (and what they need)
    python3 tools/toolchain.py --floor            check the host floor and stop
    python3 tools/toolchain.py --self-test        exercise the pure comparison logic
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
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
import host_platform

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


class FloorError(ResolutionError):
    """A per-substrate floor prerequisite is absent. Carries the remedy that clears it."""


class NoCandidate(ResolutionError):
    """The supplier offers nothing at all for this requirement."""


class OutOfRange(ResolutionError):
    """The supplier offers versions, and none satisfies the authored requirement."""


class NoPlatformAsset(ResolutionError):
    """A satisfying version exists, and the publisher builds none for this architecture."""


# A refusal reason is a check id, so a seeded negative can be attributed to exactly one
# check ([`development_plan_standards.md` §M](../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 8).
REFUSAL_CHECKS = {
    NoCandidate: "resolution-absent",
    OutOfRange: "resolution-out-of-range",
    NoPlatformAsset: "resolution-architecture",
}


def refusal_check(error: BaseException) -> str:
    return REFUSAL_CHECKS.get(type(error), "")


def contained_env() -> dict[str, str]:
    """Subprocess state roots, all beneath the ignored build root.

    The caller's `PATH` is passed through for the *subprocesses* a provider spawns, and no
    requirement is discovered from it any more: every tool is either acquired from its
    publisher, supplied by a provider that says where it put it, or supplied by the floor
    and resolved through the floor's own query. Discovery by search path is what the retired
    `host` source kind was.
    """
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


def parse_reported_version(text: str, spec: dict[str, Any]) -> tuple[int, ...]:
    """Parse a tool report, honoring an authored capture when its product name has digits.

    The default first-number rule is right for reports such as ``cabal-install version
    3.18`` but not ``Z3 version 5.1``: the product's own name would otherwise become
    version 3.  A requirement may therefore supply one regular expression whose first
    capture is the version token.  The expression remains compatibility policy, not a
    resolved observation.
    """
    pattern = spec.get("version_pattern")
    if not pattern:
        return parse_version(text)
    match = re.search(pattern, text)
    if match is None or match.lastindex is None:
        raise ResolutionError(f"version report {text!r} does not match authored pattern {pattern!r}")
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


def canonical_platform() -> str:
    """The one `<os>-<arch>` token every authored platform key is spelled in.

    This used to be three functions in three modules that disagreed about how to spell an
    Apple silicon host, and the authored tables carried both spellings to compensate.
    `tools/host_platform.py` is now the only normalizer.
    """
    return host_platform.platform_token()


# --------------------------------------------------------------------------
# the floor — substrate_doctrine.md §3.1, authored data, checked before resolution
# --------------------------------------------------------------------------


def load_floor() -> dict[str, Any]:
    document = json.loads(REQUIREMENTS.read_text(encoding="utf-8"))
    floor = document.get("floor")
    if not isinstance(floor, dict):
        raise ResolutionError(f"{REQUIREMENTS.name} declares no floor")
    return {key: value for key, value in floor.items() if not key.startswith("_")}


def floor_wellformed() -> list[str]:
    """Every authored floor entry is decidable and carries a remedy, on every substrate.

    A floor that can only be read on the host it describes is not a floor: §3.1 requires an
    apple host to be able to check that its plan for windows is well formed. This is the
    check that makes that true, and it runs no host probe at all.
    """
    problems: list[str] = []
    floor = load_floor()
    for substrate in host_platform.SUBSTRATES:
        entries = floor.get(substrate)
        if not entries:
            problems.append(f"floor: substrate {substrate} declares no prerequisite")
            continue
        for index, entry in enumerate(entries):
            where = f"floor.{substrate}[{index}]"
            for field in ("id", "required_for", "probe", "remedy"):
                if not entry.get(field):
                    problems.append(f"{where}: no {field}")
            kind = (entry.get("probe") or {}).get("kind")
            if kind not in PROBES:
                problems.append(f"{where}: probe kind {kind!r} is not one of {sorted(PROBES)}")
    return problems


def _probe_executable(probe: dict[str, Any]) -> tuple[bool, str]:
    for candidate in probe.get("paths", []):
        path = Path(candidate)
        if path.is_file() and os.access(path, os.X_OK):
            return True, str(path)
    return False, "none of " + ", ".join(probe.get("paths", [])) + " is an executable file"


def _probe_present(probe: dict[str, Any]) -> tuple[bool, str]:
    """A file the kernel publishes, which is read rather than run — a driver's version node.

    Kept distinct from `executable` on purpose: folding the two would have made the
    package-manager-root probe pass on a package manager that is present and not runnable.
    """
    for candidate in probe.get("paths", []):
        path = Path(candidate)
        if path.exists():
            return True, str(path)
    return False, "none of " + ", ".join(probe.get("paths", [])) + " is present"


def _probe_command(probe: dict[str, Any]) -> tuple[bool, str]:
    argv = probe.get("argv", [])
    if not argv or not Path(argv[0]).exists():
        return False, f"{argv[0] if argv else '<no argv>'} does not exist"
    result = subprocess.run(argv, capture_output=True, text=True, check=False)
    detail = (result.stdout or result.stderr or "").strip().splitlines()
    return result.returncode == 0, (detail[0] if detail else f"exit {result.returncode}")


def _probe_architecture(probe: dict[str, Any]) -> tuple[bool, str]:
    observed = host_platform.host_architecture()
    return observed == probe.get("expect"), observed


def _probe_writable(probe: dict[str, Any]) -> tuple[bool, str]:
    for candidate in probe.get("paths", []):
        path = Path(candidate)
        if path.exists() and os.access(path, os.W_OK):
            return True, str(path)
    return False, "none of " + ", ".join(probe.get("paths", [])) + " is present and writable"


def _probe_manual(probe: dict[str, Any]) -> tuple[bool, str]:
    """A fact no read on this host settles. Declared so it is named, never assumed true."""
    return False, f"{probe.get('fact', 'unstated fact')} is not decidable from this host"


PROBES = {
    "executable": _probe_executable,
    "present": _probe_present,
    "command": _probe_command,
    "architecture": _probe_architecture,
    "writable": _probe_writable,
    "manual": _probe_manual,
}


def floor_results(substrate: str | None = None) -> list[dict[str, Any]]:
    """Run the floor probes for one substrate. A failure is a value carrying its remedy."""
    substrate = substrate or host_platform.host_substrate()
    entries = load_floor().get(substrate)
    if entries is None:
        raise ResolutionError(f"floor: no authored prerequisites for substrate {substrate}")
    results: list[dict[str, Any]] = []
    for entry in entries:
        satisfied, detail = PROBES[entry["probe"]["kind"]](entry["probe"])
        results.append(
            {
                "id": entry["id"],
                "substrate": substrate,
                "required_for": entry["required_for"],
                "satisfied": satisfied,
                "observation": detail,
                "remedy": entry["remedy"],
            }
        )
    return results


def require_floor(substrate: str | None = None) -> list[dict[str, Any]]:
    """The gate's precondition: refuse before resolving, naming the remedy."""
    results = floor_results(substrate)
    unsatisfied = [result for result in results if not result["satisfied"]]
    if unsatisfied:
        first = unsatisfied[0]
        raise FloorError(
            f"{first['id']} is not satisfied ({first['observation']}); "
            f"required for {first['required_for']}. Remedy: {first['remedy']}"
        )
    return results


def package_manager_root() -> Path:
    """The floor's own package-manager root, resolved from the authored floor entry."""
    substrate = host_platform.host_substrate()
    for entry in load_floor()[substrate]:
        if entry["id"].endswith("package-manager-root"):
            satisfied, detail = _probe_executable(entry["probe"])
            if not satisfied:
                raise FloorError(f"{entry['id']} is absent ({detail}). Remedy: {entry['remedy']}")
            return Path(detail)
    raise FloorError(f"floor: substrate {substrate} declares no package-manager root")


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
# one resolver per source kind, starting with `managed`
# --------------------------------------------------------------------------
#
# The four-step ensure contract of `substrate_doctrine.md` §3 is: probe the provider,
# install if absent, resolve the absolute path *from the provider itself*, invoke by that
# path. A provider adapter below implements exactly those steps for one provider, and
# nothing else in this module knows how any of them work.


def tool_directory(record: dict[str, Any]) -> str:
    return str(Path(record["path"]).parent)


def provider_env(resolved: dict[str, Any], *names: str) -> dict[str, str]:
    """A contained environment with the named resolved tools' directories in front.

    A provider is invoked by absolute path, but the *provider* may run its own helpers by
    bare name — `npm` execs `node`, `ghcup` execs the compiler it just laid down. Putting
    exactly the resolved directories in front is how those bare names resolve to what this
    run chose rather than to whatever the host happens to carry.
    """
    environment = contained_env()
    directories = [tool_directory(resolved[name]) for name in names if name in resolved]
    environment["PATH"] = os.pathsep.join(
        list(dict.fromkeys(directories)) + [environment.get("PATH", "")]
    )
    return environment


def _run(argv: list[str], *, env: dict[str, str] | None = None, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        argv, cwd=cwd, env=env or contained_env(), text=True, capture_output=True, check=False
    )


def ghcup_offers(ghcup: str, tool: str, env: dict[str, str]) -> list[str]:
    """Ask ghcup what it can supply — step 1, and the only source of candidate versions."""
    result = _run([ghcup, "list", "-t", tool, "-r"], env=env)
    if result.returncode != 0:
        raise ResolutionError(f"ghcup could not list {tool}: {(result.stderr or result.stdout).strip()[-500:]}")
    offers = [
        fields[1]
        for fields in (line.split() for line in result.stdout.splitlines())
        if len(fields) >= 2 and fields[0] == tool
    ]
    return offers


def choose_offer(name: str, offers: list[str], requirement: str) -> str:
    """The newest offered version satisfying `requirement`. Pure; the negatives drive it."""
    if not offers:
        raise NoCandidate(f"{name}: the provider offers no version at all")
    admissible = [
        (parse_version(offer), offer) for offer in offers if _satisfies_text(offer, requirement)
    ]
    if not admissible:
        raise OutOfRange(
            f"{name}: the provider offers {', '.join(offers[:6])} and none satisfies {requirement}"
        )
    return max(admissible)[1]


def ghcup_whereis(ghcup: str, tool: str, version: str, env: dict[str, str]) -> str | None:
    """Ask ghcup where it put the tool — step 3. `None` means it has not installed it."""
    result = _run([ghcup, "whereis", tool, version], env=env)
    candidate = result.stdout.strip()
    if result.returncode != 0 or not candidate or not Path(candidate).is_file():
        return None
    return candidate


def provide_ghcup(name: str, spec: dict[str, Any], resolved: dict[str, Any]) -> dict[str, Any]:
    ghcup = resolved["ghcup"]["path"]
    tool = spec["supplies"]
    environment = provider_env(resolved, "ghcup")
    selected = choose_offer(name, ghcup_offers(ghcup, tool, environment), spec["requirement"])
    path = ghcup_whereis(ghcup, tool, selected, environment)
    installed = False
    if path is None:
        install = _run([ghcup, "install", tool, selected], env=environment)
        if install.returncode != 0:
            raise ResolutionError(
                f"{name}: ghcup install {tool} {selected} failed: "
                f"{(install.stderr or install.stdout)[-2000:]}"
            )
        installed = True
        path = ghcup_whereis(ghcup, tool, selected, environment)
    if path is None:
        raise ResolutionError(f"{name}: ghcup installed {tool} {selected} but cannot say where")
    return _managed_record(name, spec, "ghcup", path, installed, offered=selected)


def playwright_executable(resolved: dict[str, Any], browser: str, env: dict[str, str]) -> str | None:
    """Ask playwright-core itself where the browser is — the provider is the only oracle."""
    module = str(NODE_ROOT / "playwright-core")
    script = (
        f"const driver = require({json.dumps(module)});"
        f"try {{ console.log(driver[{json.dumps(browser)}].executablePath()); }} catch (error) {{ }}"
    )
    result = _run([resolved["node"]["path"], "-e", script], env=env)
    candidate = result.stdout.strip()
    if result.returncode != 0 or not candidate or not Path(candidate).exists():
        return None
    return candidate


def provide_playwright(name: str, spec: dict[str, Any], resolved: dict[str, Any]) -> dict[str, Any]:
    browser = spec["supplies"]
    environment = provider_env(resolved, "node")
    path = playwright_executable(resolved, browser, environment)
    installed = False
    if path is None:
        install = _run(
            [resolved["node"]["path"], resolved["playwright"]["path"], "install", browser],
            env=environment,
        )
        if install.returncode != 0:
            raise ResolutionError(
                f"{name}: playwright install {browser} failed: "
                f"{(install.stderr or install.stdout)[-2000:]}"
            )
        installed = True
        path = playwright_executable(resolved, browser, environment)
    if path is None:
        raise ResolutionError(f"{name}: playwright installed {browser} but reports no executable")
    return _managed_record(name, spec, "playwright", path, installed)


# One entry per package-manager root the floor admits. `prefix` answers "where would you
# put this formula", `install` supplies it. A manager with no prefix query lays its files
# down at a fixed root, which is the same answer expressed as a constant. `privileged`
# marks the managers that write to a system root, and the escalation they need is the
# `linux.privilege` floor entry — declared there, so it is verified before it is used.
SUDO = "/usr/bin/sudo"
PACKAGE_MANAGERS: dict[str, dict[str, Any]] = {
    "brew": {"prefix": ["--prefix", "{package}"], "install": ["install", "{package}"]},
    "apt-get": {"root": "/usr", "install": ["install", "-y", "{package}"], "privileged": True},
    "dnf": {"root": "/usr", "install": ["install", "-y", "{package}"], "privileged": True},
    "zypper": {"root": "/usr", "install": ["--non-interactive", "install", "{package}"], "privileged": True},
    "pacman": {"root": "/usr", "install": ["-S", "--noconfirm", "{package}"], "privileged": True},
}


def package_manager_prefix(root: Path, adapter: dict[str, Any], package: str) -> Path | None:
    if "root" in adapter:
        return Path(adapter["root"])
    argv = [str(root)] + [token.replace("{package}", package) for token in adapter["prefix"]]
    result = _run(argv)
    prefix = result.stdout.strip()
    return Path(prefix) if result.returncode == 0 and prefix else None


def floor_supplied(command: str) -> str | None:
    """The floor's own toolchain, asked canonically rather than through the host's PATH.

    On apple the command-line-tools floor entry is a real supplier — `git` is one of the
    things it lays down — and `xcrun --find` is that toolchain's own resolution query. On
    linux the package-manager root's install prefix already covers the same ground.
    """
    if host_platform.host_system() != "darwin":
        return None
    result = _run(["/usr/bin/xcrun", "--find", command])
    candidate = result.stdout.strip()
    return candidate if result.returncode == 0 and candidate and Path(candidate).is_file() else None


def provide_package_manager(name: str, spec: dict[str, Any], resolved: dict[str, Any]) -> dict[str, Any]:
    root = package_manager_root()
    adapter = PACKAGE_MANAGERS.get(root.name)
    if adapter is None:
        raise FloorError(
            f"{name}: the floor's package-manager root {root} is not one this resolver drives "
            f"({', '.join(sorted(PACKAGE_MANAGERS))})"
        )
    substrate = host_platform.host_substrate()
    package = spec["package_map"].get(substrate)
    if package is None:
        raise ResolutionError(f"{name}: no package named for substrate {substrate}")

    def candidate() -> str | None:
        prefix = package_manager_prefix(root, adapter, package)
        found = prefix / spec["relative_path"] if prefix else None
        return str(found) if found and found.is_file() else None

    path, installed = candidate(), False
    if path is None and spec.get("floor_supplies"):
        path = floor_supplied(spec["supplies"])
    if path is None:
        escalation = [SUDO, "-n"] if adapter.get("privileged") else []
        argv = escalation + [str(root)] + [
            token.replace("{package}", package) for token in adapter["install"]
        ]
        install = _run(argv)
        if install.returncode != 0:
            raise ResolutionError(
                f"{name}: {root.name} install {package} failed: "
                f"{(install.stderr or install.stdout)[-2000:]}"
            )
        installed = True
        path = candidate()
    if path is None:
        raise ResolutionError(f"{name}: {root.name} supplies no {spec['relative_path']} for {package}")
    return _managed_record(name, spec, f"package-manager:{root.name}", path, installed, package=package)


PROVIDERS = {
    "ghcup": provide_ghcup,
    "playwright": provide_playwright,
    "package-manager": provide_package_manager,
}


def _satisfies_text(text: str, requirement: str) -> bool:
    try:
        return satisfies(parse_version(text), requirement)
    except ResolutionError:
        return False


def _managed_record(
    name: str,
    spec: dict[str, Any],
    provider: str,
    path: str,
    installed: bool,
    **extra: Any,
) -> dict[str, Any]:
    reported = run_version([path, *spec["version_argv"]])
    version = parse_reported_version(reported, spec)
    if not satisfies(version, spec["requirement"]):
        raise ResolutionError(
            f"{name}: {provider} supplied {reported.splitlines()[0]!r}, "
            f"which does not satisfy {spec['requirement']}"
        )
    return {
        "source": "managed",
        "provider": provider,
        "supplies": spec["supplies"],
        "path": path,
        "version": ".".join(str(part) for part in version),
        "reported": reported.splitlines()[0],
        "requirement": spec["requirement"],
        # A resolution that had to install is a different observation from one that did
        # not, and the sprint's "a second run is a verified no-op" reads this field.
        "installed": installed,
        **extra,
    }


def resolve_managed(name: str, spec: dict[str, Any], resolved: dict[str, Any]) -> dict[str, Any]:
    provider = PROVIDERS.get(spec["provider"])
    if provider is None:
        raise ResolutionError(f"{name}: no adapter for provider {spec['provider']!r}")
    return provider(name, spec, resolved)


def ensure_node_package_graph(resolved: dict[str, Any]) -> None:
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
            resolved["npm"]["path"],
            "install",
            "--no-audit",
            "--no-fund",
            "--no-save",
            "--prefix",
            str(NODE_ROOT.parent),
            *node_packages,
        ],
        cwd=ROOT,
        env=provider_env(resolved, "node"),
        text=True,
        capture_output=True,
        check=False,
    )
    if install.returncode != 0:
        raise ResolutionError(f"node tool graph: npm install failed: {install.stderr[-2000:]}")


def resolve_node_package(name: str, spec: dict[str, Any], resolved: dict[str, Any]) -> dict[str, Any]:
    ensure_node_package_graph(resolved)
    package_root = NODE_ROOT / spec["package"]
    if not package_root.is_dir():
        raise ResolutionError(f"{name}: authored Node graph did not install {spec['package']}")
    for relative in spec["relative_paths"]:
        candidate = package_root / relative
        if not candidate.is_file():
            continue
        argv = [str(candidate), *spec["version_argv"]]
        if spec.get("interpreter"):
            # The interpreter is a resolved requirement of its own, so it is invoked by the
            # absolute path this run chose rather than by the bare name the host would find.
            argv = [resolved[spec["interpreter"]]["path"], *argv]
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


def choose_release(
    name: str, spec: dict[str, Any], releases: list[dict[str, Any]], token: str
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Pick a release and its asset from a feed. Pure, so the seeded negatives drive it.

    The three ways this can refuse are three *different* facts about the publisher, and
    collapsing them into one message is how "not available" hides "available, for another
    machine". Each raises its own class, and a negative in the corpus reddens exactly one.
    """
    mapped = spec.get("platform_map", {}).get(token)
    if "{platform}" in spec["asset_pattern"] and mapped is None:
        raise NoPlatformAsset(
            f"{name}: {spec.get('project', 'the publisher')} offers no asset for {token}; "
            f"resolution refuses rather than selecting another architecture's binary"
        )
    pattern = re.compile(spec["asset_pattern"].replace("{platform}", mapped or ""))
    if not releases:
        raise NoCandidate(f"{name}: {spec.get('project', 'the publisher')} publishes no release at all")
    # The feed is not reliably ordered by version, so admissibility is collected and the
    # newest satisfying release wins. Taking the first match would let a back-published
    # maintenance release quietly downgrade the resolved tool.
    in_range: list[tuple[tuple[int, ...], dict[str, Any]]] = []
    for release in releases:
        try:
            version = parse_version(release.get("tag_name", "") or release.get("name", ""))
        except ResolutionError:
            continue
        if satisfies(version, spec["requirement"]):
            in_range.append((version, release))
    if not in_range:
        raise OutOfRange(
            f"{name}: no {spec.get('project', 'published')} release satisfies {spec['requirement']}"
        )
    admissible: list[tuple[tuple[int, ...], dict[str, Any], dict[str, Any]]] = []
    for version, release in in_range:
        for asset in release.get("assets", []):
            if pattern.fullmatch(asset.get("name", "")):
                admissible.append((version, release, asset))
                break
    if not admissible:
        raise NoPlatformAsset(
            f"{name}: a release satisfies {spec['requirement']} but publishes no asset "
            f"matching {spec['asset_pattern']} on {token}"
        )
    best = max(admissible, key=lambda entry: entry[0])
    return best[1], best[2]


def select_release(name: str, spec: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    return choose_release(name, spec, github_releases(spec["project"]), canonical_platform())


def materialize(url: str, destination: Path) -> Path:
    """Download once per run into an ignored cache, keyed by the observed content."""
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    if destination.is_file():
        return destination
    payload = fetch(url)
    destination.write_bytes(payload)
    return destination


def extractall(tarred: tarfile.TarFile, destination: Path) -> None:
    """Extract with the data filter where the interpreter has one.

    `filter=` landed in 3.12 and is the safe default from 3.14 on. The gate's declared
    command is `python3`, which on a stock macOS host is still 3.9, so asking for the
    filter unconditionally turned a resolvable tool into a `TypeError`. Ask for it when it
    exists and take the interpreter's own default when it does not.
    """
    try:
        tarred.extractall(destination, filter="data")
    except TypeError:
        tarred.extractall(destination)


def archive_member(spec: dict[str, Any]) -> str | None:
    """The member to extract, which some publishers lay out per platform.

    Temurin's macOS JRE is an application bundle — the launcher is at
    `Contents/Home/bin/java`, not at `bin/java` — so a single authored member name resolves
    a path that is not there on exactly one platform. The override map is keyed by the same
    canonical token as every other platform table in the manifest.
    """
    override = spec.get("archive_member_map", {}).get(canonical_platform())
    return override or spec.get("archive_member")


def unpack_prefix(names: list[str]) -> str:
    """The single top-level directory every member shares, or `""` when there is none.

    A release tarball that unpacks into one versioned directory has to have that directory
    stripped, or the resolved path carries a version this run has no business hard-coding.
    A tarball that unpacks straight into `bin/` and `share/` has no such directory, and
    taking the first member's first segment would have stripped `bin` and lost the binary.
    """
    tops = {name.split("/")[0] for name in names if name not in (".", "./")}
    return next(iter(tops)) if len(tops) == 1 else ""


def resolve_github_release(name: str, spec: dict[str, Any]) -> dict[str, Any]:
    release, asset = select_release(name, spec)
    archive = materialize(asset["browser_download_url"], DOWNLOADS / asset["name"])
    member = archive_member(spec)

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
        unpack_root = target_dir.parent / f".{spec['install_dir']}-unpack"
        shutil.rmtree(unpack_root, ignore_errors=True)
        with tarfile.open(archive) as tarred:
            prefix = unpack_prefix(tarred.getnames())
            extractall(tarred, unpack_root)
        unpacked = unpack_root / prefix if prefix else unpack_root
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.move(str(unpacked), str(target_dir))
        shutil.rmtree(unpack_root, ignore_errors=True)
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
    platform_token = spec.get("platform_map", {}).get(canonical_platform())
    if platform_token is None:
        raise ResolutionError(f"{name}: no binary mapping for platform {canonical_platform()}")
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
    "managed": resolve_managed,
    "node-package": resolve_node_package,
    "github-release": lambda name, spec, resolved: resolve_github_release(name, spec),
    "kubernetes-release": lambda name, spec, resolved: resolve_kubernetes_release(name, spec),
    "hackage": resolve_hackage,
}


# What each provider must have resolved before it can supply anything. `package-manager`
# names nothing, because it is the floor's own root: verified before resolution begins,
# never resolved by it.
PROVIDER_NEEDS = {
    "ghcup": ("ghcup",),
    "playwright": ("node", "playwright"),
    "package-manager": (),
}


def needs(spec: dict[str, Any]) -> tuple[str, ...]:
    """The requirements this one cannot be resolved without.

    Order used to be a hand-written pair of names that happened to cover the one case there
    was. With a `managed` kind every requirement names a supplier, so the order is read off
    the manifest instead: ask for `chromium` and the run resolves the driver that supplies
    it and the interpreter that driver runs under, in that order, without the caller
    listing either of them.
    """
    source = spec["source"]
    if source == "managed":
        return PROVIDER_NEEDS.get(spec["provider"], ())
    if source == "node-package":
        interpreter = (spec["interpreter"],) if spec.get("interpreter") else ()
        return ("node", "npm") + interpreter
    if source == "hackage":
        return ("cabal",)
    return ()


def resolution_order(wanted: Iterable[str], requirements: dict[str, Any]) -> list[str]:
    """`wanted` closed under `needs`, in an order where a supplier precedes what it supplies."""
    ordered: list[str] = []
    visiting: set[str] = set()

    def visit(name: str, trail: tuple[str, ...]) -> None:
        if name in ordered:
            return
        if name in visiting:
            raise ResolutionError(f"requirement cycle: {' -> '.join(trail + (name,))}")
        if name not in requirements:
            raise ResolutionError(f"no authored requirement for: {name}")
        visiting.add(name)
        for dependency in needs(requirements[name]):
            visit(dependency, trail + (name,))
        visiting.discard(name)
        ordered.append(name)

    for name in wanted:
        visit(name, ())
    return ordered


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

    # The floor is checked once, before anything is resolved. A host that cannot support
    # the run should say which prerequisite is missing and how to clear it, not fail four
    # requirements deep on a symptom (`substrate_doctrine.md` §3.1).
    require_floor()

    # `refresh` re-resolves what was asked for; it does not discard what a sibling gate in
    # the same checkout already resolved. Dropping those would make one gate's refresh the
    # next gate's cache miss, and re-acquire a tool nobody asked about.
    resolved = load_resolved()
    for name in resolution_order(wanted, requirements):
        spec = requirements[name]
        if not refresh and name in resolved and usable(name, resolved[name], spec):
            continue
        resolved[name] = RESOLVERS[spec["source"]](name, spec, resolved)
    resolved["platform"] = canonical_platform()
    store_resolved(resolved)
    return resolved


def manifest_problems() -> list[str]:
    """Everything wrong with the authored manifest that no host is needed to see.

    Three properties, all pure: the retired `host` source kind is gone, the floor is
    decidable and remedied on every substrate — including the one this host is not — and
    every authored platform key is spelled in the one canonical `<os>-<arch>` vocabulary.
    The third is what makes a `darwin-aarch64` key a failure on a Linux host.
    """
    requirements = load_requirements()
    admitted = set(host_platform.all_platform_tokens())
    problems = [
        f"{name} declares the retired `host` source kind"
        for name, spec in sorted(requirements.items())
        if spec["source"] == "host"
    ]
    problems += [
        f"{name} declares source {spec['source']!r}, which no resolver implements"
        for name, spec in sorted(requirements.items())
        if spec["source"] not in RESOLVERS
    ]
    problems += floor_wellformed()
    for name, spec in sorted(requirements.items()):
        stray = sorted((set(spec.get("platform_map", {})) | set(spec.get("archive_member_map", {}))) - admitted)
        if stray:
            problems.append(f"{name} names non-canonical platform key(s) {', '.join(stray)}")
    return problems


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

    z3_report = "Z3 version 5.1.0 - 64 bit"
    z3_spec = {"version_pattern": r"\bversion\s+([0-9]+(?:\.[0-9]+)*)"}
    z3_actual = parse_reported_version(z3_report, z3_spec)
    z3_expected = (5, 1, 0)
    z3_status = "ok  " if z3_actual == z3_expected else "FAIL"
    if z3_actual != z3_expected:
        failures += 1
    print(f"  {z3_status} authored-pattern parse {z3_report!r} -> {z3_actual}")

    for problem in manifest_problems():
        print(f"  FAIL {problem}")
        failures += 1
    if not manifest_problems():
        print(f"  ok   no `host` source kind; floor well formed for all "
              f"{len(host_platform.SUBSTRATES)} substrates; every platform key canonical")

    print("toolchain self-test:", "PASS" if failures == 0 else f"FAIL ({failures})")
    return 1 if failures else 0


def floor_report(substrate: str | None = None) -> int:
    substrate = substrate or host_platform.host_substrate()
    print(f"floor — {substrate} on {canonical_platform()}\n")
    failures = 0
    for result in floor_results(substrate):
        if result["satisfied"]:
            print(f"  ok    {result['id']:<32} {result['observation']}")
        else:
            failures += 1
            print(f"  FAIL  {result['id']:<32} {result['observation']}")
            print(f"        required for {result['required_for']}")
            print(f"        remedy: {result['remedy']}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*", help="requirement names; default is every requirement")
    parser.add_argument("--refresh", action="store_true", help="ignore any cached resolution")
    parser.add_argument("--self-test", action="store_true", help="exercise the pure version algebra")
    parser.add_argument("--floor", nargs="?", const="", help="check a substrate's floor and stop")
    options = parser.parse_args(argv)
    if options.self_test:
        return self_test()
    if options.floor is not None:
        return floor_report(options.floor or None)
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
