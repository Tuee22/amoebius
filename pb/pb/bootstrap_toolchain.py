"""Run-local toolchain resolution for the pre-binary host-assertion CLI.

`pb` runs on a host where nothing amoebius needs exists yet, so it cannot ask the
repository's own resolver -- that one *finds* tools, and here there are none to
find. What it does instead is the same thing for the same reason: read the
**authored requirements** in `tools/toolchain_requirements.json`, ask each
publisher what it currently offers, take the newest release that satisfies the
requirement, and verify the download against the publisher's own checksum.

Nothing this module learns is written back into a tracked file. Resolved versions,
URLs, and observed digests go to `.build/toolchain/bootstrap.json`, which is
ignored, and travel onward as run evidence
(`repository_layout_doctrine.md` section 4). A checksum computed here detects
corruption inside this run; it never becomes a package pin.

Every value crossing the JSON boundary is `object` narrowed through `pb.narrow`,
and every child process goes through `pb.process`. Standard library plus those two
only: this runs before any dependency is installed.
"""

from __future__ import annotations

import dataclasses
import importlib.util
import json
import re
import urllib.error
import urllib.request
from collections.abc import Mapping, Sequence
from pathlib import Path

from pb import narrow, process
from pb.process import Kind, Ledger

REQUIREMENTS = "tools/toolchain_requirements.json"
CANONICAL_PLATFORM = "tools/host_platform.py"
RESOLUTION = ".build/toolchain/bootstrap.json"
NETWORK_TIMEOUT = 120
VERSION_TOKEN = re.compile(r"(\d+(?:\.\d+)+)")
CLAUSE = re.compile(r"(>=|<=|==|>|<)(\d+(?:\.\d+)*)")
SHA256 = re.compile(r"[0-9a-f]{64}")
CHANNEL_URL = "https://dl.k8s.io/release/{channel}.txt"
RELEASE_URL = "https://dl.k8s.io/release/{version}/{path}"

# The tools `pb` acquires itself. Everything else it needs is `managed`: supplied by
# one of these, which is asked what it can offer.
ACQUIRED = ("ghcup", "kubectl", "kind")


class ResolutionError(RuntimeError):
    """An authored requirement could not be satisfied from what publishers offer."""


@dataclasses.dataclass(frozen=True)
class Resolved:
    """One tool as this run resolved it. Every field is an observation."""

    name: str
    source: str
    version: str
    requirement: str
    url: str = ""
    asset: str = ""
    publisher_sha256: str = ""
    project: str = ""
    channel: str = ""
    release: str = ""
    provider: str = ""

    def record(self) -> dict[str, str]:
        return {
            key: value for key, value in dataclasses.asdict(self).items() if key != "name" and value
        }


# --------------------------------------------------------------------------
# the version algebra
# --------------------------------------------------------------------------


def parse_version(text: str) -> tuple[int, ...]:
    match = VERSION_TOKEN.search(text)
    if match is None:
        raise ResolutionError(f"no version number in {text!r}")
    return tuple(int(part) for part in match.group(1).split("."))


def pad(left: tuple[int, ...], right: tuple[int, ...]) -> tuple[tuple[int, ...], tuple[int, ...]]:
    width = max(len(left), len(right))
    return left + (0,) * (width - len(left)), right + (0,) * (width - len(right))


def satisfies(version: tuple[int, ...], requirement: str) -> bool:
    """`requirement` is a space-separated conjunction such as `">=1.33 <2"`."""
    comparisons = {
        ">=": lambda a, b: a >= b,
        "<=": lambda a, b: a <= b,
        "==": lambda a, b: a == b,
        ">": lambda a, b: a > b,
        "<": lambda a, b: a < b,
    }
    for clause in requirement.split():
        match = CLAUSE.fullmatch(clause)
        if match is None:
            raise ResolutionError(f"malformed requirement clause {clause!r}")
        operator, bound = match.groups()
        left, right = pad(version, tuple(int(part) for part in bound.split(".")))
        if not comparisons[operator](left, right):
            return False
    return True


def admissible(candidate: str, requirement: str) -> bool:
    """`satisfies`, treating an unparseable candidate as simply not admissible."""
    try:
        return satisfies(parse_version(candidate), requirement)
    except ResolutionError:
        return False


# --------------------------------------------------------------------------
# authored inputs
# --------------------------------------------------------------------------


def canonical_platform(root: Path) -> str:
    """The repository's own `<os>-<arch>` token, loaded rather than re-derived.

    This module used to derive the token itself, with a normalizer that disagreed
    with the resolver's on exactly one host: Apple silicon came out
    `darwin-aarch64` here and `darwin-arm64` there, so `pb` asked the authored
    requirements for a key no requirement has. `tools/host_platform.py` is the one
    normalizer, and it is standard library only for precisely this reason -- it can
    be read on a host where nothing is installed yet.
    """
    source = root / CANONICAL_PLATFORM
    specification = importlib.util.spec_from_file_location("amoebius_host_platform", source)
    if specification is None or specification.loader is None:
        raise ResolutionError(f"could not load the canonical platform vocabulary from {source}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    token = module.platform_token()
    return narrow.as_text(token, "host_platform.platform_token()")


def load_requirements(root: Path) -> Mapping[str, object]:
    document = narrow.as_mapping(narrow.load(root / REQUIREMENTS), REQUIREMENTS)
    return narrow.mapping_field(document, "tools", REQUIREMENTS)


def specification(specs: Mapping[str, object], name: str) -> Mapping[str, object]:
    node = specs.get(name)
    if node is None:
        raise ResolutionError(f"{name}: no authored requirement in {REQUIREMENTS}")
    return narrow.as_mapping(node, f"{REQUIREMENTS}.tools.{name}")


def platform_token(name: str, spec: Mapping[str, object], host: str) -> str:
    mapping = narrow.mapping_field(spec, "platform_map", name)
    token = mapping.get(host)
    if token is None:
        raise ResolutionError(f"{name}: no platform mapping for {host}")
    return narrow.as_text(token, f"{name}.platform_map.{host}")


# --------------------------------------------------------------------------
# publishers
# --------------------------------------------------------------------------


def fetch(url: str) -> bytes:
    """Read one publisher URL over TLS.

    The scheme is checked rather than assumed. `urlopen` will happily open
    `file:` and every other scheme its handlers know, so a URL that reached here
    from a manifest could otherwise read the local disk and be reported as a
    publisher's answer.
    """
    if not url.startswith("https://"):
        raise ResolutionError(f"refusing a non-https publisher URL: {url}")
    request = urllib.request.Request(  # noqa: S310 -- the scheme is checked above
        url, headers={"User-Agent": "amoebius-pb", "Accept": "*/*"}
    )
    try:
        with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT) as response:  # noqa: S310
            payload: bytes = response.read()
            return payload
    except (urllib.error.URLError, TimeoutError, OSError) as problem:
        raise ResolutionError(f"could not reach {url}: {problem}") from problem


def fetch_text(url: str) -> str:
    return fetch(url).decode("utf-8", "replace")


def github_releases(project: str) -> Sequence[object]:
    payload = fetch(f"https://api.github.com/repos/{project}/releases?per_page=30")
    try:
        parsed: object = json.loads(payload)
    except json.JSONDecodeError as problem:
        raise ResolutionError(f"{project}: release feed is not valid JSON") from problem
    if not isinstance(parsed, list):
        raise ResolutionError(f"{project}: release feed is not a list")
    return parsed


def select_release(
    name: str, spec: Mapping[str, object], host: str
) -> tuple[tuple[int, ...], Mapping[str, object], Mapping[str, object]]:
    """The newest release satisfying the requirement, with its platform asset.

    The feed is not ordered by version, so every admissible release is collected
    and the newest wins. Taking the first match would let a back-published
    maintenance release silently downgrade the tool.
    """
    asset_pattern = narrow.text_field(spec, "asset_pattern", name)
    requirement = narrow.text_field(spec, "requirement", name)
    project = narrow.text_field(spec, "project", name)
    pattern = re.compile(asset_pattern.replace("{platform}", platform_token(name, spec, host)))
    found: list[tuple[tuple[int, ...], Mapping[str, object], Mapping[str, object]]] = []
    for entry in github_releases(project):
        release = narrow.as_mapping(entry, f"{project}.release")
        tag = (
            narrow.optional_text(release, "tag_name") or narrow.optional_text(release, "name") or ""
        )
        try:
            version = parse_version(tag)
        except ResolutionError:
            continue
        if not satisfies(version, requirement):
            continue
        for candidate in narrow.as_sequence(release.get("assets", []), "assets"):
            asset = narrow.as_mapping(candidate, "asset")
            if pattern.fullmatch(narrow.optional_text(asset, "name") or ""):
                found.append((version, release, asset))
                break
    if not found:
        raise ResolutionError(
            f"{name}: no {project} release satisfies {requirement} "
            f"with an asset matching {asset_pattern} on {host}"
        )
    return max(found, key=lambda entry: entry[0])


def extract_digest(document: str, asset_name: str) -> str:
    """Read one digest out of a bare digest file or a `SHA256SUMS`-style listing."""
    lines = [line.strip() for line in document.splitlines() if line.strip()]
    for line in lines:
        fields = line.split()
        if len(fields) >= 2 and Path(fields[-1].lstrip("*")).name == asset_name:
            return fields[0].lower()
    if len(lines) == 1:
        candidate = lines[0].split()[0].lower()
        if SHA256.fullmatch(candidate):
            return candidate
    raise ResolutionError(f"no sha256 digest for {asset_name} in the publisher's checksum document")


def publisher_checksum(
    name: str,
    spec: Mapping[str, object],
    release: Mapping[str, object],
    asset: Mapping[str, object],
) -> str:
    """The digest the publisher states for this asset, fetched in this same run."""
    asset_name = narrow.text_field(asset, "name", "asset")
    wanted = narrow.text_field(spec, "checksum_asset", name).replace("{asset}", asset_name)
    for entry in narrow.as_sequence(release.get("assets", []), "assets"):
        candidate = narrow.as_mapping(entry, "asset")
        if narrow.optional_text(candidate, "name") == wanted:
            url = narrow.text_field(candidate, "browser_download_url", "asset")
            return extract_digest(fetch_text(url), asset_name)
    tag = narrow.optional_text(release, "tag_name") or "<untagged>"
    raise ResolutionError(f"{name}: {tag} publishes no checksum asset {wanted}")


def resolve_github_release(name: str, spec: Mapping[str, object], host: str) -> Resolved:
    version, release, asset = select_release(name, spec, host)
    return Resolved(
        name=name,
        source="github-release",
        project=narrow.text_field(spec, "project", name),
        release=narrow.optional_text(release, "tag_name") or "",
        version=".".join(str(part) for part in version),
        requirement=narrow.text_field(spec, "requirement", name),
        url=narrow.text_field(asset, "browser_download_url", "asset"),
        asset=narrow.text_field(asset, "name", "asset"),
        publisher_sha256=publisher_checksum(name, spec, release, asset),
    )


def resolve_kubernetes_release(name: str, spec: Mapping[str, object], host: str) -> Resolved:
    channel_name = narrow.text_field(spec, "channel", name)
    requirement = narrow.text_field(spec, "requirement", name)
    channel = fetch_text(CHANNEL_URL.format(channel=channel_name)).strip()
    version = parse_version(channel)
    if not satisfies(version, requirement):
        raise ResolutionError(
            f"{name}: channel {channel_name} offers {channel}, which does not satisfy {requirement}"
        )
    install_name = narrow.text_field(spec, "install_name", name)
    path = narrow.text_field(spec, "binary_path", name).replace(
        "{platform}", platform_token(name, spec, host)
    )
    url = RELEASE_URL.format(version=channel, path=path)
    return Resolved(
        name=name,
        source="kubernetes-release",
        channel=channel_name,
        release=channel,
        version=".".join(str(part) for part in version),
        requirement=requirement,
        url=url,
        asset=install_name,
        publisher_sha256=extract_digest(fetch_text(url + ".sha256"), install_name),
    )


def resolve_acquired(root: Path) -> dict[str, Resolved]:
    """Resolve every tool `pb` downloads itself, from the authored requirements."""
    specs = load_requirements(root)
    host = canonical_platform(root)
    resolved: dict[str, Resolved] = {}
    for name in ACQUIRED:
        spec = specification(specs, name)
        source = narrow.text_field(spec, "source", name)
        if source == "github-release":
            resolved[name] = resolve_github_release(name, spec, host)
        elif source == "kubernetes-release":
            resolved[name] = resolve_kubernetes_release(name, spec, host)
        else:
            raise ResolutionError(f"{name}: source {source!r} is not acquirable pre-binary")
    return resolved


# --------------------------------------------------------------------------
# what ghcup supplies
# --------------------------------------------------------------------------


def ghcup_managed(root: Path) -> list[str]:
    """The requirements ghcup supplies, read off the manifest rather than hard-coded.

    A hard-coded pair was a second place the authored manifest had to be kept in
    sync with, and the two disagreed the moment a `managed` requirement was added.
    The manifest is the only statement of who supplies what.
    """
    specs = load_requirements(root)
    names: list[str] = []
    for name, node in specs.items():
        spec = narrow.as_mapping(node, name)
        if spec.get("source") == "managed" and spec.get("provider") == "ghcup":
            names.append(name)
    return sorted(names)


def ghcup_versions(
    ghcup: Path, tool: str, home: Path, *, ledger: Ledger | None = None
) -> list[str]:
    """Ask the installed ghcup what it can supply, by absolute path."""
    completed = process.run(
        ghcup,
        ["list", "-t", tool, "-r"],
        kind=Kind.PROBE,
        ledger=ledger,
        overlay={"HOME": str(home)},
        mirror=False,
    )
    if not completed.ok:
        raise ResolutionError(f"ghcup could not list {tool}: {completed.output.strip()}")
    versions = [
        fields[1]
        for fields in (line.split() for line in completed.output.splitlines())
        if len(fields) >= 2 and fields[0] == tool
    ]
    if not versions:
        raise ResolutionError(f"ghcup listed no {tool} versions")
    return versions


def resolve_ghcup_managed(
    root: Path, ghcup: Path, home: Path, *, ledger: Ledger | None = None
) -> dict[str, Resolved]:
    """Take the newest ghcup-offered version admissible under each requirement."""
    specs = load_requirements(root)
    resolved: dict[str, Resolved] = {}
    for name in ghcup_managed(root):
        requirement = narrow.text_field(specification(specs, name), "requirement", name)
        offers = [
            (parse_version(candidate), candidate)
            for candidate in ghcup_versions(ghcup, name, home, ledger=ledger)
            if admissible(candidate, requirement)
        ]
        if not offers:
            raise ResolutionError(f"{name}: ghcup offers nothing satisfying {requirement}")
        _, selected = max(offers)
        resolved[name] = Resolved(
            name=name,
            source="managed",
            provider="ghcup",
            version=selected,
            requirement=requirement,
        )
    return resolved


def store(root: Path, resolved: Mapping[str, Resolved]) -> Path:
    """Write the run-local resolution beneath the ignored build root."""
    target = root / RESOLUTION
    target.parent.mkdir(parents=True, exist_ok=True)
    body = {name: entry.record() for name, entry in resolved.items()}
    target.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return target
