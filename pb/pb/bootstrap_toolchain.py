"""Run-local toolchain resolution for the pre-binary Bootstrap Coordinator.

The coordinator runs on a host where nothing amoebius needs exists yet, so it cannot ask
the repository's own resolver — that one finds tools, and here there are none to find.
What it can do is the same thing for the same reason: read the **authored requirements**
in `toolchain/requirements.json`, ask each publisher what it currently offers, take the
newest release that satisfies the requirement, and verify the download against the
publisher's own checksum.

Nothing this module learns is written back into a tracked file. The resolved versions,
URLs, and observed digests go to `gen/toolchain/bootstrap.json`, which is ignored, and
travel onward as run evidence (`repository_layout_doctrine.md` section 4). A checksum
computed here detects corruption inside this run; it never becomes a package pin.

Python 3 standard library only: this runs before any dependency is installed.
"""

from __future__ import annotations

import hashlib
import json
import platform
import re
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

REQUIREMENTS = "toolchain/requirements.json"
RESOLUTION = "gen/toolchain/bootstrap.json"
NETWORK_TIMEOUT = 120
VERSION_TOKEN = re.compile(r"(\d+(?:\.\d+)+)")
CHANNEL_URL = "https://dl.k8s.io/release/{channel}.txt"
RELEASE_URL = "https://dl.k8s.io/release/{version}/{path}"

# The tools the coordinator acquires itself, and the tools it installs through ghcup.
ACQUIRED = ("ghcup", "kubectl", "kind")
GHCUP_MANAGED = ("ghc", "cabal")


class ResolutionError(RuntimeError):
    """An authored requirement could not be satisfied from what publishers offer."""


def parse_version(text: str) -> tuple[int, ...]:
    match = VERSION_TOKEN.search(text)
    if match is None:
        raise ResolutionError(f"no version number in {text!r}")
    return tuple(int(part) for part in match.group(1).split("."))


def pad(left: tuple[int, ...], right: tuple[int, ...]) -> tuple[tuple[int, ...], tuple[int, ...]]:
    width = max(len(left), len(right))
    return left + (0,) * (width - len(left)), right + (0,) * (width - len(right))


def satisfies(version: tuple[int, ...], requirement: str) -> bool:
    """`requirement` is a space-separated conjunction such as ">=1.33 <2"."""
    for clause in requirement.split():
        match = re.fullmatch(r"(>=|<=|==|>|<)(\d+(?:\.\d+)*)", clause)
        if match is None:
            raise ResolutionError(f"malformed requirement clause {clause!r}")
        operator, bound = match.groups()
        left, right = pad(version, tuple(int(part) for part in bound.split(".")))
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
    return f"{platform.system().lower()}-{machine}"


def platform_token(name: str, spec: dict[str, Any]) -> str:
    token = spec.get("platform_map", {}).get(host_platform())
    if token is None:
        raise ResolutionError(f"{name}: no platform mapping for {host_platform()}")
    return token


def fetch(url: str) -> bytes:
    request = urllib.request.Request(
        url, headers={"User-Agent": "amoebius-bootstrap-coordinator", "Accept": "*/*"}
    )
    try:
        with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError, OSError) as problem:
        raise ResolutionError(f"could not reach {url}: {problem}") from problem


def load_requirements(root: Path) -> dict[str, Any]:
    document = json.loads((root / REQUIREMENTS).read_text(encoding="utf-8"))
    return document["tools"]


def github_releases(project: str) -> list[dict[str, Any]]:
    payload = fetch(f"https://api.github.com/repos/{project}/releases?per_page=30")
    releases = json.loads(payload)
    if not isinstance(releases, list):
        raise ResolutionError(f"{project}: release feed is not a list")
    return releases


def select_release(name: str, spec: dict[str, Any]) -> tuple[tuple[int, ...], dict[str, Any], dict[str, Any]]:
    """The newest release satisfying the requirement, with its platform asset.

    The feed is not ordered by version, so every admissible release is collected and the
    newest wins; taking the first match would let a back-published maintenance release
    silently downgrade the tool.
    """
    pattern = re.compile(spec["asset_pattern"].replace("{platform}", platform_token(name, spec)))
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
    if not admissible:
        raise ResolutionError(
            f"{name}: no {spec['project']} release satisfies {spec['requirement']} "
            f"with an asset matching {spec['asset_pattern']} on {host_platform()}"
        )
    return max(admissible, key=lambda entry: entry[0])


def publisher_checksum(name: str, spec: dict[str, Any], release: dict[str, Any], asset: dict[str, Any]) -> str:
    """The digest the publisher states for this asset, fetched in this same run."""
    wanted = spec["checksum_asset"].replace("{asset}", asset["name"])
    for candidate in release.get("assets", []):
        if candidate.get("name") == wanted:
            return extract_digest(fetch(candidate["browser_download_url"]).decode("utf-8", "replace"), asset["name"])
    raise ResolutionError(f"{name}: {release.get('tag_name')} publishes no checksum asset {wanted}")


def extract_digest(document: str, asset_name: str) -> str:
    """Read one digest out of a bare digest file or a `SHA256SUMS`-style listing."""
    lines = [line.strip() for line in document.splitlines() if line.strip()]
    for line in lines:
        fields = line.split()
        if len(fields) >= 2 and Path(fields[-1].lstrip("*")).name == asset_name:
            return fields[0].lower()
    if len(lines) == 1:
        candidate = lines[0].split()[0].lower()
        if re.fullmatch(r"[0-9a-f]{64}", candidate):
            return candidate
    raise ResolutionError(f"no sha256 digest for {asset_name} in the publisher's checksum document")


def download_verified(url: str, expected: str, target: Path) -> str:
    """Download to `target`, refusing anything whose digest is not the publisher's."""
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = fetch(url)
    observed = hashlib.sha256(payload).hexdigest()
    if observed != expected:
        raise ResolutionError(f"download-digest-mismatch:{target.name}")
    with tempfile.NamedTemporaryFile(prefix=target.name + ".", dir=target.parent, delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(payload)
    temporary.chmod(0o755)
    temporary.replace(target)
    return observed


def resolve_github_release(name: str, spec: dict[str, Any]) -> dict[str, Any]:
    version, release, asset = select_release(name, spec)
    return {
        "source": "github-release",
        "project": spec["project"],
        "release": release.get("tag_name", ""),
        "version": ".".join(str(part) for part in version),
        "requirement": spec["requirement"],
        "url": asset["browser_download_url"],
        "asset": asset["name"],
        "publisher_sha256": publisher_checksum(name, spec, release, asset),
    }


def resolve_kubernetes_release(name: str, spec: dict[str, Any]) -> dict[str, Any]:
    channel = fetch(CHANNEL_URL.format(channel=spec["channel"])).decode("utf-8", "replace").strip()
    version = parse_version(channel)
    if not satisfies(version, spec["requirement"]):
        raise ResolutionError(
            f"{name}: channel {spec['channel']} offers {channel}, which does not satisfy {spec['requirement']}"
        )
    path = spec["binary_path"].replace("{platform}", platform_token(name, spec))
    url = RELEASE_URL.format(version=channel, path=path)
    digest = extract_digest(fetch(url + ".sha256").decode("utf-8", "replace"), spec["install_name"])
    return {
        "source": "kubernetes-release",
        "channel": spec["channel"],
        "release": channel,
        "version": ".".join(str(part) for part in version),
        "requirement": spec["requirement"],
        "url": url,
        "asset": spec["install_name"],
        "publisher_sha256": digest,
    }


def resolve_acquired(root: Path) -> dict[str, dict[str, Any]]:
    """Resolve every tool the coordinator downloads itself, from authored requirements."""
    specs = load_requirements(root)
    resolved: dict[str, dict[str, Any]] = {}
    for name in ACQUIRED:
        spec = specs.get(name)
        if spec is None:
            raise ResolutionError(f"{name}: no authored requirement in {REQUIREMENTS}")
        if spec["source"] == "github-release":
            resolved[name] = resolve_github_release(name, spec)
        elif spec["source"] == "kubernetes-release":
            resolved[name] = resolve_kubernetes_release(name, spec)
        else:
            raise ResolutionError(f"{name}: source {spec['source']!r} is not acquirable pre-binary")
    return resolved


def ghcup_versions(ghcup: Path, tool: str, home: Path) -> list[str]:
    result = subprocess.run(
        [str(ghcup), "list", "-t", tool, "-r"],
        capture_output=True, text=True, check=False, env={"HOME": str(home), "PATH": "/usr/bin:/bin"},
    )
    if result.returncode != 0:
        raise ResolutionError(f"ghcup could not list {tool}: {result.stderr.strip()}")
    versions: list[str] = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0] == tool:
            versions.append(fields[1])
    if not versions:
        raise ResolutionError(f"ghcup listed no {tool} versions")
    return versions


def resolve_ghcup_managed(root: Path, ghcup: Path, home: Path) -> dict[str, dict[str, Any]]:
    """Ask the installed ghcup which ghc/cabal it can supply, and take the newest admissible."""
    specs = load_requirements(root)
    resolved: dict[str, dict[str, Any]] = {}
    for name in GHCUP_MANAGED:
        requirement = specs[name]["requirement"]
        admissible = [
            (parse_version(candidate), candidate)
            for candidate in ghcup_versions(ghcup, name, home)
            if _admissible(candidate, requirement)
        ]
        if not admissible:
            raise ResolutionError(f"{name}: ghcup offers nothing satisfying {requirement}")
        _, selected = max(admissible)
        resolved[name] = {
            "source": "ghcup-managed",
            "version": selected,
            "requirement": requirement,
        }
    return resolved


def _admissible(candidate: str, requirement: str) -> bool:
    try:
        return satisfies(parse_version(candidate), requirement)
    except ResolutionError:
        return False


def store(root: Path, resolved: dict[str, Any]) -> Path:
    target = root / RESOLUTION
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(resolved, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return target
