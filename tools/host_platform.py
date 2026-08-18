#!/usr/bin/env python3
"""The one canonical `<os>-<arch>` platform token, and the host class it belongs to.

Three normalizers used to answer this same question and disagreed about the answer.
`tools/gate_common.py` mapped a kernel machine name onto the lane vocabulary
(`amd64`/`arm64`) for section S clause 15; `tools/toolchain.py` mapped it onto
`x86_64`/`aarch64` and then carried a hand-written special case so that Apple silicon came
out `darwin-arm64` rather than `darwin-aarch64`; `pb/pb/bootstrap_toolchain.py` did the same
mapping *without* that special case, so the pre-binary coordinator asked the authored
requirements for `darwin-aarch64` — a key no requirement has. The authored `platform_map`
tables then compensated for the disagreement by mixing both spellings in one file.

One vocabulary removes all of it. The architecture half is the lane vocabulary, because a
lane name and an architecture observation have to be comparable without translation
([`substrate_doctrine.md` §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule)).
The system half is the kernel's own lowercase name. The token is their join, and it is the
only spelling any authored `platform_map` key, asset pattern, or resolved record uses.

This module is standard-library only and imports nothing from the repository, because both
the gate toolchain and the pre-binary Bootstrap Coordinator have to be able to read it.
"""

from __future__ import annotations

import os
import platform
from pathlib import Path

# The closed lane vocabulary of section S clause 15. An architecture outside it is a
# refusal, never a guess: a run that cannot name what it executed on proves nothing.
ARCHITECTURES = ("amd64", "arm64")
ARCHITECTURE_ALIASES = {
    "x86_64": "amd64",
    "x64": "amd64",
    "amd64": "amd64",
    "aarch64": "arm64",
    "arm64": "arm64",
}

# The three host operating systems `substrate_doctrine.md` §2 classifies over.
SYSTEMS = ("darwin", "linux", "windows")
SYSTEM_ALIASES = {
    "darwin": "darwin",
    "linux": "linux",
    "windows": "windows",
    "win32": "windows",
}

# The substrate catalogue of `DEVELOPMENT_PLAN/substrates.md`, minus `none`: `none` is a
# phase's declaration that it stands up no host, not a classification of one.
SUBSTRATES = ("apple", "linux-cpu", "linux-cuda", "windows")


class PlatformError(RuntimeError):
    """The host cannot be named in the closed vocabulary."""


def normalize_architecture(name: str) -> str:
    """Map a kernel's machine name onto the closed lane vocabulary."""
    resolved = ARCHITECTURE_ALIASES.get(name.strip().lower())
    if resolved is None:
        raise PlatformError(f"unknown machine architecture {name!r}; the vocabulary is {ARCHITECTURES}")
    return resolved


def normalize_system(name: str) -> str:
    """Map a kernel's system name onto the closed host-system vocabulary."""
    resolved = SYSTEM_ALIASES.get(name.strip().lower())
    if resolved is None:
        raise PlatformError(f"unknown host system {name!r}; the vocabulary is {SYSTEMS}")
    return resolved


def host_architecture() -> str:
    return normalize_architecture(platform.machine())


def host_system() -> str:
    return normalize_system(platform.system())


def platform_token(system: str | None = None, architecture: str | None = None) -> str:
    """`<os>-<arch>`, the only spelling an authored platform key ever uses."""
    return f"{system or host_system()}-{architecture or host_architecture()}"


def all_platform_tokens() -> tuple[str, ...]:
    """Every token the closed vocabulary admits, so an authored map can be checked whole."""
    return tuple(f"{system}-{architecture}" for system in SYSTEMS for architecture in ARCHITECTURES)


def _nvidia_driver_present() -> bool:
    """The accelerator read of `substrate_doctrine.md` §2 — the kernel driver, not a binary.

    A missing driver is not a refusal. It classifies the host as `linux-cpu`, so the CUDA
    lane is simply never offered ([§3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply)).
    """
    if Path("/proc/driver/nvidia/version").is_file():
        return True
    return any(Path("/dev").glob("nvidia[0-9]*")) if os.path.isdir("/dev") else False


def host_substrate() -> str:
    """The host's substrate, by the three reads of `substrate_doctrine.md` §2.

    Detection is a classification, not a knob: it reads the system, the architecture, and
    the accelerator driver, and returns one member of the closed catalogue.
    """
    system = host_system()
    if system == "darwin":
        # Apple is `arm64`, always. The floor's `apple.silicon` entry is what turns an
        # Intel Mac into a refusal carrying a remedy rather than a mis-classification.
        return "apple"
    if system == "windows":
        return "windows"
    return "linux-cuda" if _nvidia_driver_present() else "linux-cpu"


def main() -> int:
    print(f"system       {host_system()}")
    print(f"architecture {host_architecture()}")
    print(f"platform     {platform_token()}")
    print(f"substrate    {host_substrate()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
