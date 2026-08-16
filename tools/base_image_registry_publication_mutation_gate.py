#!/usr/bin/env python3
"""Run the committed Sprint-25.3 record-before-push mutant through the Haskell gate."""

from __future__ import annotations

import argparse
import functools
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
MUTANT = ROOT / "test/mutant/base_image_registry/record-before-push.mutant"
BASELINE_FLAGS = (
    "-f-base-image-registry-bootstrap-domain-expansion-mutant",
    "-f-base-image-registry-handoff-without-equality-mutant",
    "-f-base-image-registry-record-before-push-mutant",
)


class MutationFailure(RuntimeError):
    pass


def fixture() -> dict[str, str]:
    rows: dict[str, str] = {}
    for line in MUTANT.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator:
            rows[key] = value
    if not {"surface", "mutation", "expected_oracle"} <= rows.keys():
        raise MutationFailure("mutant-fixture-shape:record-before-push")
    return rows


@functools.cache
def build_tools() -> tuple[str, str]:
    """Resolve cabal and the compiler per run from the authored requirements.

    Passing the resolved compiler explicitly matters as much as resolving cabal: an
    invocation without it inherits whichever GHC the host's PATH happens to offer, which
    need not satisfy the authored range at all.
    """
    resolved = toolchain.resolve(["cabal", "ghc"])
    return resolved["cabal"]["path"], resolved["ghc"]["path"]


def run_test(*flags: str) -> subprocess.CompletedProcess[str]:
    cabal, compiler = build_tools()
    return subprocess.run(
        (
            cabal,
            f"--builddir={ROOT / '.build/dist-newstyle/base-image-registry'}",
            f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
            f"--with-compiler={compiler}",
            "test",
            "base-image-registry-spec",
            *flags,
            "--test-show-details=direct",
            "-j1",
        ),
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=900,
    )


def gate() -> dict[str, object]:
    description = fixture()
    try:
        mutant = run_test(*BASELINE_FLAGS, "-fbase-image-registry-record-before-push-mutant")
        if mutant.returncode == 0:
            raise MutationFailure("mutant-survived:record-before-push")
        marker = "publication failure unadvertised"
        if marker not in mutant.stdout:
            raise MutationFailure(f"mutant-wrong-locus:{marker}:{mutant.stdout[-3000:]}")
    finally:
        baseline = run_test(*BASELINE_FLAGS)
        if baseline.returncode:
            raise MutationFailure(f"baseline-not-restored:{baseline.stdout[-3000:]}")
    return {
        "schema": "amoebius.phase25.sprint25.3-mutants.v1",
        "baselineRestored": True,
        "results": [
            {
                "mutant": "record-before-push",
                "mutation": description["mutation"],
                "expectedOracle": description["expected_oracle"],
                "observedFailureMarker": marker,
                "result": "RED",
            }
        ],
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        result = gate()
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence is None:
            print(encoded, end="")
        else:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        print("phase25-sprint25.3-mutation-gate: PASS (1 seeded mutant RED)")
        return 0
    except (MutationFailure, OSError, subprocess.TimeoutExpired) as problem:
        print(f"phase25-sprint25.3-mutation-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
