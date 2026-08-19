"""Build `exe:amoebius`, put it at one stable path, and stop being the program.

This is the last thing `pb` does. Everything after the handoff belongs to the
binary, because the no-environment / no-`PATH` contract cannot begin until there is
a binary to enforce it
([`substrate_doctrine.md` section 6](../../documents/engineering/substrate_doctrine.md)).

Two decisions here are deliberate and are what the phase gate checks.

**The copy is content-conditional.** Cabal writes its output wherever its build
tree happens to be; `pb` publishes it at one stable absolute path so everything
downstream has a single name to use. The copy happens only when the bytes differ,
so a converged second run performs no mutation at all -- which is what makes the
idempotence claim observable in the ledger rather than argued.

**The handoff differs by platform, and the difference is stated.** On POSIX the
Python process is *replaced*, so there is no parent left to misreport the child's
result. Windows has no `execv` that replaces a process, so the child is run and
its exit code propagated. Papering over that with a uniform wrapper would mean
claiming on POSIX something only Windows actually does.
"""

from __future__ import annotations

import hashlib
import shutil
from collections.abc import Mapping, Sequence
from pathlib import Path

from pb import process
from pb.process import Kind, Ledger

DISTROS = ("kind", "rke2")
LAYOUTS = ("unified", "split-runtime", "split-image")
CABAL_TARGET = "./amoebius.cabal:exe:amoebius"


class BootstrapError(RuntimeError):
    """The build or the handoff could not be completed."""


def repository_root() -> Path:
    """The checkout this distribution was installed from, resolved from its own file."""
    return Path(__file__).resolve().parents[2]


def build_root(root: Path) -> Path:
    return root / ".build" / "dist-newstyle" / "pb"


def store_directory(root: Path) -> Path:
    return root / ".build" / "cabal-store"


def stable_binary(root: Path) -> Path:
    """The one published path. Absolute by construction, since `root` is."""
    return root / ".build" / "bin" / "amoebius"


def cabal_update_arguments(root: Path) -> list[str]:
    """Refresh only the package index, never resolve the checkout's project."""
    return [
        f"--store-dir={store_directory(root)}",
        "update",
        "--ignore-project",
        f"--builddir={build_root(root)}-update",
    ]


def cabal_build_arguments(root: Path, ghc: Path, jobs: int) -> list[str]:
    """Global flags before the command, command-scoped flags after it."""
    return [
        f"--store-dir={store_directory(root)}",
        "build",
        f"--builddir={build_root(root)}",
        f"-j{jobs}",
        f"--with-compiler={ghc}",
        CABAL_TARGET,
    ]


def cabal_list_bin_arguments(root: Path, ghc: Path) -> list[str]:
    return [
        f"--store-dir={store_directory(root)}",
        "list-bin",
        f"--builddir={build_root(root)}",
        f"--with-compiler={ghc}",
        CABAL_TARGET,
    ]


def digest(path: Path) -> str:
    """The content hash the copy decision is made on."""
    value = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            block = handle.read(1024 * 1024)
            if not block:
                break
            value.update(block)
    return value.hexdigest()


def build_binary(
    *,
    root: Path,
    cabal: Path,
    ghc: Path,
    jobs: int = 1,
    ledger: Ledger | None = None,
    overlay: Mapping[str, str] | None = None,
) -> Path:
    """Build the executable and return the absolute path cabal produced."""
    process.run_checked(
        cabal,
        cabal_build_arguments(root, ghc, jobs),
        kind=Kind.MUTATION,
        ledger=ledger,
        overlay=overlay,
        cwd=root,
    )
    located = process.run_checked(
        cabal,
        cabal_list_bin_arguments(root, ghc),
        kind=Kind.PROBE,
        ledger=ledger,
        overlay=overlay,
        cwd=root,
        mirror=False,
    ).strip()
    built = Path(located)
    if not built.is_absolute():
        raise BootstrapError(f"built-binary-not-absolute:{built}")
    if process.executable_problem(built) is not None:
        raise BootstrapError(f"built-binary-not-executable:{built}")
    return built


def install_binary(built: Path, stable: Path, *, ledger: Ledger | None = None) -> bool:
    """Publish `built` at `stable`, and report whether anything actually moved.

    The return value is the point: it is `False` on a converged re-run, and the
    replay check reads exactly that. A copy performed unconditionally would make
    every second run a mutation and the idempotence claim unfalsifiable.
    """
    if not stable.is_absolute():
        raise BootstrapError(f"stable-path-not-absolute:{stable}")
    if stable.is_file() and digest(stable) == digest(built):
        return False
    stable.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(built, stable)
    if ledger is not None:
        ledger.record(process.Invocation(Kind.MUTATION, str(stable), ("<-", str(built))))
    return True


def bootstrap_arguments(distro: str, replicas: int, layout: str = "unified") -> list[str]:
    """The argv the binary is handed. Each refusal names the field it refuses."""
    if distro not in DISTROS:
        raise BootstrapError(f"unsupported-distro:{distro}")
    if replicas < 1:
        raise BootstrapError(f"replicas-must-be-positive:{replicas}")
    if layout not in LAYOUTS:
        raise BootstrapError(f"unsupported-filesystem-layout:{layout}")
    return ["bootstrap", f"--distro={distro}", f"--replicas={replicas}", f"--layout={layout}"]


def handoff(binary: Path, arguments: Sequence[str]) -> int:
    """Hand the host over to the built binary. On POSIX this does not return."""
    if not binary.is_absolute():
        raise BootstrapError(f"handoff-binary-not-absolute:{binary}")
    if process.executable_problem(binary) is not None:
        raise BootstrapError(f"handoff-binary-invalid:{binary}")
    return process.become(binary, arguments)
