"""The resolver: the version algebra, the publisher boundary, and every refusal."""

from __future__ import annotations

import io
import json
from pathlib import Path

import pytest
from pb import bootstrap_toolchain as toolchain
from pb.bootstrap_toolchain import ResolutionError, Resolved
from pb.narrow import NarrowError

# --------------------------------------------------------------------------
# the version algebra
# --------------------------------------------------------------------------


def test_parse_version_reads_the_first_dotted_number() -> None:
    assert toolchain.parse_version("v1.33.2") == (1, 33, 2)
    with pytest.raises(ResolutionError, match="no version number"):
        toolchain.parse_version("latest")


def test_pad_aligns_widths() -> None:
    assert toolchain.pad((1,), (1, 2, 3)) == ((1, 0, 0), (1, 2, 3))


@pytest.mark.parametrize(
    ("version", "requirement", "expected"),
    [
        ((1, 33), ">=1.33 <2", True),
        ((2, 0), ">=1.33 <2", False),
        ((1, 0), ">=1.33", False),
        ((1, 2), "<=1.2", True),
        ((1, 3), "<=1.2", False),
        ((1, 2), "==1.2", True),
        ((1, 3), "==1.2", False),
        ((1, 3), ">1.2", True),
        ((1, 2), ">1.2", False),
        ((1, 1), "<1.2", True),
    ],
)
def test_satisfies_every_operator(
    version: tuple[int, ...], requirement: str, expected: bool
) -> None:
    assert toolchain.satisfies(version, requirement) is expected


def test_satisfies_refuses_a_malformed_clause() -> None:
    with pytest.raises(ResolutionError, match="malformed requirement clause"):
        toolchain.satisfies((1,), "~=1.2")


def test_admissible_treats_an_unparseable_candidate_as_not_admissible() -> None:
    assert toolchain.admissible("1.33.0", ">=1.33") is True
    assert toolchain.admissible("nightly", ">=1.33") is False


# --------------------------------------------------------------------------
# authored inputs
# --------------------------------------------------------------------------


def test_canonical_platform_is_the_repositorys_own_token() -> None:
    token = toolchain.canonical_platform(Path(__file__).resolve().parents[3])
    assert token.count("-") == 1
    assert token.split("-")[1] in {"amd64", "arm64"}


def test_canonical_platform_refuses_an_absent_normalizer(tmp_path: Path) -> None:
    with pytest.raises((ResolutionError, FileNotFoundError)):
        toolchain.canonical_platform(tmp_path)


def _requirements(tmp_path: Path, tools: dict[str, object]) -> Path:
    target = tmp_path / toolchain.REQUIREMENTS
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({"tools": tools}), encoding="utf-8")
    return tmp_path


def test_load_requirements_reads_the_tools_table(tmp_path: Path) -> None:
    root = _requirements(tmp_path, {"kind": {"source": "github-release"}})
    assert "kind" in toolchain.load_requirements(root)


def test_specification_names_the_absent_tool(tmp_path: Path) -> None:
    root = _requirements(tmp_path, {})
    with pytest.raises(ResolutionError, match="no authored requirement"):
        toolchain.specification(toolchain.load_requirements(root), "kind")


def test_platform_token_maps_or_refuses() -> None:
    spec: dict[str, object] = {"platform_map": {"linux-amd64": "linux_amd64"}}
    assert toolchain.platform_token("kind", spec, "linux-amd64") == "linux_amd64"
    with pytest.raises(ResolutionError, match="no platform mapping"):
        toolchain.platform_token("kind", spec, "darwin-arm64")


# --------------------------------------------------------------------------
# the publisher boundary
# --------------------------------------------------------------------------


def test_fetch_refuses_a_non_https_url() -> None:
    with pytest.raises(ResolutionError, match="non-https"):
        toolchain.fetch("file:///etc/passwd")


def test_fetch_wraps_a_transport_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    def refuse(*_args: object, **_kwargs: object) -> None:
        raise TimeoutError("slow")

    monkeypatch.setattr(toolchain.urllib.request, "urlopen", refuse)
    with pytest.raises(ResolutionError, match="could not reach"):
        toolchain.fetch("https://example.invalid/x")


def test_github_releases_refuses_a_non_list_feed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(toolchain, "fetch", lambda _url: b'{"message":"rate limited"}')
    with pytest.raises(ResolutionError, match="not a list"):
        toolchain.github_releases("a/b")


def test_github_releases_refuses_invalid_json(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(toolchain, "fetch", lambda _url: b"{")
    with pytest.raises(ResolutionError, match="not valid JSON"):
        toolchain.github_releases("a/b")


DIGEST = "a" * 64

FEED = [
    {"tag_name": "not-a-version", "assets": []},
    {
        "tag_name": "v0.9.0",
        "assets": [{"name": "kind-linux_amd64", "browser_download_url": "u"}],
    },
    {
        "tag_name": "v1.2.0",
        "assets": [
            {"name": "unrelated.txt", "browser_download_url": "https://x/unrelated"},
            {"name": "kind-linux_amd64", "browser_download_url": "https://x/a"},
            {"name": "kind-linux_amd64.sha256", "browser_download_url": "https://x/s"},
        ],
    },
    {
        "tag_name": "v1.1.0",
        "assets": [{"name": "kind-linux_amd64", "browser_download_url": "https://x/b"}],
    },
]

SPEC: dict[str, object] = {
    "source": "github-release",
    "project": "kubernetes-sigs/kind",
    "requirement": ">=1.0 <2",
    "asset_pattern": "kind-{platform}",
    "checksum_asset": "{asset}.sha256",
    "platform_map": {"linux-amd64": "linux_amd64"},
}


def test_select_release_takes_the_newest_admissible(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(toolchain, "github_releases", lambda _project: FEED)
    version, release, asset = toolchain.select_release("kind", SPEC, "linux-amd64")
    assert version == (1, 2, 0)
    assert release["tag_name"] == "v1.2.0"
    assert asset["name"] == "kind-linux_amd64"


def test_select_release_reports_when_nothing_matches(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(toolchain, "github_releases", lambda _project: [])
    with pytest.raises(
        ResolutionError, match="no kubernetes-sigs/kind release satisfies"
    ):
        toolchain.select_release("kind", SPEC, "linux-amd64")


def test_select_release_falls_back_to_the_release_name(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    feed = [
        {
            "name": "v1.5.0",
            "assets": [{"name": "kind-linux_amd64", "browser_download_url": "u"}],
        }
    ]
    monkeypatch.setattr(toolchain, "github_releases", lambda _project: feed)
    version, _release, _asset = toolchain.select_release("kind", SPEC, "linux-amd64")
    assert version == (1, 5, 0)


@pytest.mark.parametrize(
    ("document", "expected"),
    [
        (f"{DIGEST}  kind-linux_amd64\n", DIGEST),
        (f"{DIGEST} *kind-linux_amd64\n", DIGEST),
        (f"{DIGEST}\n", DIGEST),
    ],
)
def test_extract_digest_reads_both_shapes(document: str, expected: str) -> None:
    assert toolchain.extract_digest(document, "kind-linux_amd64") == expected


def test_extract_digest_refuses_a_document_without_one() -> None:
    with pytest.raises(ResolutionError, match="no sha256 digest"):
        toolchain.extract_digest("nothing useful here\nand more\n", "kind-linux_amd64")
    with pytest.raises(ResolutionError, match="no sha256 digest"):
        toolchain.extract_digest("zz\n", "kind-linux_amd64")


def test_publisher_checksum_finds_the_sibling_asset(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        toolchain, "fetch_text", lambda _url: f"{DIGEST}  kind-linux_amd64\n"
    )
    _version, release, asset = FEED[2], FEED[2], FEED[2]["assets"][1]
    assert toolchain.publisher_checksum("kind", SPEC, release, asset) == DIGEST
    del _version


def test_publisher_checksum_reports_an_absent_manifest() -> None:
    release = {"tag_name": "v1.1.0", "assets": []}
    asset = {"name": "kind-linux_amd64"}
    with pytest.raises(ResolutionError, match="publishes no checksum asset"):
        toolchain.publisher_checksum("kind", SPEC, release, asset)


def test_publisher_checksum_names_an_untagged_release() -> None:
    with pytest.raises(ResolutionError, match="<untagged>"):
        toolchain.publisher_checksum(
            "kind", SPEC, {"assets": []}, {"name": "kind-linux_amd64"}
        )


def test_resolve_github_release_records_every_observation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(toolchain, "github_releases", lambda _project: FEED)
    monkeypatch.setattr(
        toolchain, "fetch_text", lambda _url: f"{DIGEST}  kind-linux_amd64\n"
    )
    resolved = toolchain.resolve_github_release("kind", SPEC, "linux-amd64")
    assert resolved.version == "1.2.0"
    assert resolved.publisher_sha256 == DIGEST
    assert resolved.url == "https://x/a"


KUBE_SPEC: dict[str, object] = {
    "source": "kubernetes-release",
    "channel": "stable-1.33",
    "requirement": ">=1.33 <2",
    "binary_path": "bin/{platform}/kubectl",
    "install_name": "kubectl",
    "platform_map": {"linux-amd64": "linux/amd64"},
}


def test_resolve_kubernetes_release_reads_the_channel(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        toolchain,
        "fetch_text",
        lambda url: "v1.33.2\n" if url.endswith(".txt") else f"{DIGEST}  kubectl\n",
    )
    resolved = toolchain.resolve_kubernetes_release("kubectl", KUBE_SPEC, "linux-amd64")
    assert resolved.version == "1.33.2"
    assert resolved.publisher_sha256 == DIGEST


def test_resolve_kubernetes_release_refuses_an_out_of_range_channel(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(toolchain, "fetch_text", lambda _url: "v2.0.0\n")
    with pytest.raises(ResolutionError, match="does not satisfy"):
        toolchain.resolve_kubernetes_release("kubectl", KUBE_SPEC, "linux-amd64")


def test_resolve_acquired_dispatches_on_source(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _requirements(tmp_path, {"ghcup": SPEC, "kind": SPEC, "kubectl": KUBE_SPEC})
    monkeypatch.setattr(toolchain, "canonical_platform", lambda _root: "linux-amd64")
    monkeypatch.setattr(toolchain, "github_releases", lambda _project: FEED)
    monkeypatch.setattr(
        toolchain,
        "fetch_text",
        lambda url: "v1.33.2\n" if url.endswith(".txt") else f"{DIGEST}  x\n",
    )
    monkeypatch.setattr(toolchain, "extract_digest", lambda _doc, _name: DIGEST)
    resolved = toolchain.resolve_acquired(root)
    assert set(resolved) == set(toolchain.ACQUIRED)


def test_resolve_acquired_refuses_an_unacquirable_source(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _requirements(
        tmp_path,
        {
            "ghcup": {"source": "managed", "provider": "package-manager"},
            "kind": SPEC,
            "kubectl": KUBE_SPEC,
        },
    )
    monkeypatch.setattr(toolchain, "canonical_platform", lambda _root: "linux-amd64")
    with pytest.raises(ResolutionError, match="is not acquirable pre-binary"):
        toolchain.resolve_acquired(root)


# --------------------------------------------------------------------------
# what ghcup supplies
# --------------------------------------------------------------------------


def test_ghcup_managed_reads_the_manifest(tmp_path: Path) -> None:
    root = _requirements(
        tmp_path,
        {
            "ghc": {"source": "managed", "provider": "ghcup", "requirement": ">=9"},
            "cabal": {"source": "managed", "provider": "ghcup", "requirement": ">=3"},
            "purs": {"source": "node-package"},
        },
    )
    assert toolchain.ghcup_managed(root) == ["cabal", "ghc"]


def test_ghcup_versions_parses_the_listing(executable, tmp_path: Path) -> None:
    ghcup = executable("ghcup", "#!/bin/sh\necho 'ghc 9.12.4 base-4.21'\necho noise\n")
    assert toolchain.ghcup_versions(ghcup, "ghc", tmp_path) == ["9.12.4"]


def test_ghcup_versions_reports_a_failing_provider(executable, tmp_path: Path) -> None:
    ghcup = executable("ghcup", "#!/bin/sh\necho broken\nexit 1\n")
    with pytest.raises(ResolutionError, match="could not list"):
        toolchain.ghcup_versions(ghcup, "ghc", tmp_path)


def test_ghcup_versions_reports_an_empty_listing(executable, tmp_path: Path) -> None:
    ghcup = executable("ghcup", "#!/bin/sh\necho ''\n")
    with pytest.raises(ResolutionError, match="listed no ghc versions"):
        toolchain.ghcup_versions(ghcup, "ghc", tmp_path)


def test_resolve_ghcup_managed_takes_the_newest_admissible(
    tmp_path: Path, executable
) -> None:
    root = _requirements(
        tmp_path,
        {
            "ghc": {
                "source": "managed",
                "provider": "ghcup",
                "requirement": ">=9.10 <10",
            }
        },
    )
    ghcup = executable(
        "ghcup", "#!/bin/sh\necho 'ghc 9.10.1'\necho 'ghc 9.12.4'\necho 'ghc 10.0.1'\n"
    )
    resolved = toolchain.resolve_ghcup_managed(root, ghcup, tmp_path)
    assert resolved["ghc"].version == "9.12.4"


def test_resolve_ghcup_managed_reports_nothing_admissible(
    tmp_path: Path, executable
) -> None:
    root = _requirements(
        tmp_path,
        {"ghc": {"source": "managed", "provider": "ghcup", "requirement": ">=99"}},
    )
    ghcup = executable("ghcup", "#!/bin/sh\necho 'ghc 9.12.4'\n")
    with pytest.raises(ResolutionError, match="offers nothing satisfying"):
        toolchain.resolve_ghcup_managed(root, ghcup, tmp_path)


def test_store_writes_beneath_the_build_root(tmp_path: Path) -> None:
    target = toolchain.store(
        tmp_path,
        {
            "kind": Resolved(
                name="kind", source="github-release", version="1.2.0", requirement=">=1"
            )
        },
    )
    assert target == tmp_path / toolchain.RESOLUTION
    written = json.loads(target.read_text(encoding="utf-8"))
    assert written["kind"]["version"] == "1.2.0"
    assert "name" not in written["kind"]


def test_load_requirements_refuses_a_document_without_tools(tmp_path: Path) -> None:
    (tmp_path / "tools").mkdir()
    (tmp_path / toolchain.REQUIREMENTS).write_text("{}", encoding="utf-8")
    with pytest.raises(NarrowError, match="no 'tools' field"):
        toolchain.load_requirements(tmp_path)


def test_canonical_platform_reports_an_unloadable_normalizer(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        toolchain.importlib.util, "spec_from_file_location", lambda *_a: None
    )
    with pytest.raises(ResolutionError, match="could not load the canonical platform"):
        toolchain.canonical_platform(tmp_path)


def test_fetch_returns_the_payload(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        toolchain.urllib.request, "urlopen", lambda *_a, **_k: io.BytesIO(b"payload")
    )
    assert toolchain.fetch("https://x/y") == b"payload"
    assert toolchain.fetch_text("https://x/y") == "payload"


def test_github_releases_returns_the_feed(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(toolchain, "fetch", lambda _url: json.dumps(FEED).encode())
    assert len(toolchain.github_releases("a/b")) == len(FEED)


def test_select_release_skips_a_release_whose_assets_do_not_match(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """An admissible version with no matching asset must not stop the search."""
    feed = [
        {"tag_name": "v1.9.0", "assets": [{"name": "kind-darwin_arm64"}]},
        {
            "tag_name": "v1.4.0",
            "assets": [
                {"name": "kind-linux_amd64", "browser_download_url": "https://x/c"}
            ],
        },
    ]
    monkeypatch.setattr(toolchain, "github_releases", lambda _project: feed)
    version, _release, _asset = toolchain.select_release("kind", SPEC, "linux-amd64")
    assert version == (1, 4, 0)
