#!/usr/bin/env python3
"""Pinned GHC expect-fail harness for Phase 6."""

from __future__ import annotations

import csv
import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def compile_fixture(ghc: str, fixture: str, mutant: bool) -> subprocess.CompletedProcess[str]:
    mutant_flags = ["-DPHASE6_GADT_MUTANT"] if mutant else []
    return subprocess.run(
        [ghc, "-fno-code", "-fforce-recomp", "-isrc", "-XGHC2024", *mutant_flags, fixture],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mutant", action="store_true")
    args = parser.parse_args(argv)
    pins = json.loads((ROOT / "toolchain/pins.json").read_text(encoding="utf-8"))
    ghc = pins["ghc"]["path"]
    with (ROOT / "tests/oracle/phase6/compile_fail.tsv").open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if len(rows) != 5:
        print("compile-fail: expected five oracle rows", file=sys.stderr)
        return 1
    for row in rows:
        legal = compile_fixture(ghc, row["legal"], args.mutant)
        if legal.returncode != 0:
            print(f"compile-fail: legal fixture failed: {row['legal']}\n{legal.stdout}", file=sys.stderr)
            return 1
        illegal = compile_fixture(ghc, row["illegal"], args.mutant)
        if illegal.returncode == 0:
            print(f"compile-fail: illegal fixture compiled: {row['illegal']}", file=sys.stderr)
            return 1
        expected_rows = dict(
            line.split("\t", 1)
            for line in (ROOT / row["expected"]).read_text(encoding="utf-8").splitlines()
            if line
        )
        if expected_rows != {"diagnostic-class": "type-error", "locus": expected_rows.get("locus", "")}:
            print(f"compile-fail: malformed expected oracle: {row['expected']}", file=sys.stderr)
            return 1
        output = illegal.stdout
        if "Couldn't match" not in output or expected_rows["locus"] not in output:
            print(f"compile-fail: wrong diagnostic for {row['illegal']}\n{output}", file=sys.stderr)
            return 1
        if any(token in output for token in ("Variable not in scope", "parse error", "Could not find module")):
            print(f"compile-fail: non-type diagnostic for {row['illegal']}\n{output}", file=sys.stderr)
            return 1
    print("compile-fail: PASS (5 legal/illegal one-token pairs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
