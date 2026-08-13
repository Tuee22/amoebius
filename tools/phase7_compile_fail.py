#!/usr/bin/env python3
"""Pinned GHC expect-fail harness for the Phase-7 topology indices."""

from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path

import toolchain


ROOT = Path(__file__).resolve().parent.parent
ORACLE = ROOT / "tests/oracle/phase7/compile_fail.tsv"


def compile_fixture(ghc: str, fixture: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [ghc, "-fno-code", "-fforce-recomp", "-isrc", "-XGHC2024", fixture],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def main() -> int:
    pins = toolchain.resolve(["ghc"])
    ghc = pins["ghc"]["path"]
    with ORACLE.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if len(rows) != 7:
        print("phase7-compile-fail: expected seven oracle rows", file=sys.stderr)
        return 1
    for row in rows:
        legal = compile_fixture(ghc, row["legal"])
        if legal.returncode != 0:
            print(f"phase7-compile-fail: legal fixture failed: {row['legal']}\n{legal.stdout}", file=sys.stderr)
            return 1
        illegal = compile_fixture(ghc, row["illegal"])
        if illegal.returncode == 0:
            print(f"phase7-compile-fail: illegal fixture compiled: {row['illegal']}", file=sys.stderr)
            return 1
        expected = (ROOT / row["expected"]).read_text(encoding="utf-8").strip()
        if expected not in illegal.stdout:
            print(f"phase7-compile-fail: wrong diagnostic for {row['illegal']}\n{illegal.stdout}", file=sys.stderr)
            return 1
        if any(token in illegal.stdout for token in ("Variable not in scope", "parse error", "Could not find module")):
            print(f"phase7-compile-fail: non-type diagnostic for {row['illegal']}\n{illegal.stdout}", file=sys.stderr)
            return 1
    print("phase7-compile-fail: PASS (7 legal/illegal minimal pairs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
