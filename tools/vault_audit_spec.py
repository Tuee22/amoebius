#!/usr/bin/env python3
"""Run native audit filesystem regressions inside one marker-owned test root."""

from __future__ import annotations

import argparse
import os
import subprocess
import uuid
from pathlib import Path

import containment
import toolchain


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cabal", required=True)
    parser.add_argument("--ghc", required=True)
    parser.add_argument("--mutant-flag", choices=("vault-pki-audit-ceiling-mutant",))
    arguments = parser.parse_args()
    owned = containment.create_test_run("vault-audit-spec-" + uuid.uuid4().hex)
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join((str(ROOT / "tools"), environment.get("PATH", "")))
    environment["AMOEBIUS_VAULT_AUDIT_TEST_ROOT"] = str(owned.path)
    try:
        return subprocess.run(
            (arguments.cabal, f"--builddir={ROOT / '.build/dist-newstyle/vault-pki'}",
             f"--store-dir={ROOT / '.build/cabal-store'}", f"--with-compiler={arguments.ghc}",
             "--jobs=1", "test", "vault-audit-spec",
             "-f" + (arguments.mutant_flag or "-vault-pki-audit-ceiling-mutant"),
             "--test-show-details=direct", "-j1"),
            cwd=ROOT, env=dict(os.environ, **environment), check=False, timeout=7200,
        ).returncode
    finally:
        containment.cleanup_test_run(owned)


if __name__ == "__main__":
    raise SystemExit(main())
