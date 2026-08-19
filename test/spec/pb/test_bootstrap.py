"""The build, the content-conditional publish, and the handoff."""

from __future__ import annotations

from pathlib import Path

import pytest
from pb import bootstrap, process
from pb.bootstrap import BootstrapError
from pb.process import Kind, Ledger


def test_repository_root_is_the_checkout() -> None:
    root = bootstrap.repository_root()
    assert (root / "amoebius.cabal").is_file()


def test_derived_paths_are_all_beneath_the_build_root(tmp_path: Path) -> None:
    for path in (
        bootstrap.build_root(tmp_path),
        bootstrap.store_directory(tmp_path),
        bootstrap.stable_binary(tmp_path),
    ):
        assert path.is_relative_to(tmp_path / ".build")


def test_cabal_arguments_place_global_flags_before_the_command(tmp_path: Path) -> None:
    build = bootstrap.cabal_build_arguments(tmp_path, Path("/usr/bin/ghc"), 4)
    assert build[0].startswith("--store-dir=")
    assert build[1] == "build"
    assert "-j4" in build
    assert build[-1] == bootstrap.CABAL_TARGET
    assert bootstrap.cabal_update_arguments(tmp_path)[1] == "update"
    assert (
        bootstrap.cabal_list_bin_arguments(tmp_path, Path("/usr/bin/ghc"))[1]
        == "list-bin"
    )


def test_digest_distinguishes_content(tmp_path: Path) -> None:
    first = tmp_path / "a"
    second = tmp_path / "b"
    first.write_bytes(b"x")
    second.write_bytes(b"y")
    assert bootstrap.digest(first) != bootstrap.digest(second)
    assert bootstrap.digest(first) == bootstrap.digest(first)


def _cabal_stub(directory: Path, printed: str) -> Path:
    path = directory / "cabal"
    path.write_text(f'#!/bin/sh\nif [ "$2" = "list-bin" ]; then echo "{printed}"; fi\n')
    path.chmod(0o755)
    return path


def test_build_binary_returns_the_located_path(tmp_path: Path, executable) -> None:
    produced = executable("amoebius")
    cabal = _cabal_stub(tmp_path, str(produced))
    ledger = Ledger()
    built = bootstrap.build_binary(
        root=tmp_path, cabal=cabal, ghc=Path("/usr/bin/ghc"), ledger=ledger
    )
    assert built == produced
    assert [entry.kind for entry in ledger.entries] == [Kind.MUTATION, Kind.PROBE]


def test_build_binary_refuses_a_relative_location(tmp_path: Path) -> None:
    cabal = _cabal_stub(tmp_path, "amoebius")
    with pytest.raises(BootstrapError, match="built-binary-not-absolute"):
        bootstrap.build_binary(root=tmp_path, cabal=cabal, ghc=Path("/usr/bin/ghc"))


def test_build_binary_refuses_a_location_that_is_not_executable(tmp_path: Path) -> None:
    cabal = _cabal_stub(tmp_path, str(tmp_path / "absent"))
    with pytest.raises(BootstrapError, match="built-binary-not-executable"):
        bootstrap.build_binary(root=tmp_path, cabal=cabal, ghc=Path("/usr/bin/ghc"))


def test_install_binary_copies_once_and_then_not_again(
    tmp_path: Path, executable
) -> None:
    built = executable("built", "#!/bin/sh\necho one\n")
    stable = tmp_path / "published" / "amoebius"
    ledger = Ledger()
    assert bootstrap.install_binary(built, stable, ledger=ledger) is True
    assert bootstrap.install_binary(built, stable, ledger=ledger) is False
    assert len(ledger.mutations) == 1
    built.write_text("#!/bin/sh\necho two\n", encoding="utf-8")
    assert bootstrap.install_binary(built, stable, ledger=ledger) is True


def test_install_binary_refuses_a_relative_destination(executable) -> None:
    with pytest.raises(BootstrapError, match="stable-path-not-absolute"):
        bootstrap.install_binary(executable("built"), Path("amoebius"))


@pytest.mark.parametrize(
    ("distro", "replicas", "layout", "expected"),
    [
        ("kind", 1, "unified", "unsupported-distro"),
        ("rke2", 0, "unified", "replicas-must-be-positive"),
        ("kind", 1, "sideways", "unsupported-filesystem-layout"),
    ],
)
def test_bootstrap_arguments_refuse_each_field(
    distro: str, replicas: int, layout: str, expected: str
) -> None:
    bad = {"unsupported-distro": ("nomad", replicas, layout)}.get(
        expected, (distro, replicas, layout)
    )
    with pytest.raises(BootstrapError, match=expected):
        bootstrap.bootstrap_arguments(*bad)


def test_bootstrap_arguments_render_the_handoff_argv() -> None:
    assert bootstrap.bootstrap_arguments("kind", 3, "split-runtime") == [
        "bootstrap",
        "--distro=kind",
        "--replicas=3",
        "--layout=split-runtime",
    ]


def test_handoff_refuses_a_relative_or_absent_binary(tmp_path: Path) -> None:
    with pytest.raises(BootstrapError, match="handoff-binary-not-absolute"):
        bootstrap.handoff(Path("amoebius"), [])
    with pytest.raises(BootstrapError, match="handoff-binary-invalid"):
        bootstrap.handoff(tmp_path / "absent", [])


def test_handoff_delegates_to_the_choke_point(
    executable, monkeypatch: pytest.MonkeyPatch
) -> None:
    seen: list[tuple[Path, tuple[str, ...]]] = []
    monkeypatch.setattr(
        process,
        "become",
        lambda binary, arguments: seen.append((binary, tuple(arguments))) or 0,
    )
    binary = executable("amoebius")
    assert bootstrap.handoff(binary, ["bootstrap"]) == 0
    assert seen == [(binary, ("bootstrap",))]


def test_install_binary_works_without_a_ledger(tmp_path: Path, executable) -> None:
    """The ledger is an observer, not a precondition."""
    assert (
        bootstrap.install_binary(executable("built"), tmp_path / "out" / "amoebius")
        is True
    )
