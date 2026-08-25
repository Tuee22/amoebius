#!/usr/bin/env python3
"""Join the live kindnet survivor with the committed Phase-31.4 CPP mutant."""

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
MUTANT = ROOT / "test/mutant/base_image_registry/noop-egress-policy.mutant"
BASELINE_FLAGS = (
    "-f-base-image-registry-bootstrap-domain-expansion-mutant",
    "-f-base-image-registry-handoff-without-equality-mutant",
    "-f-base-image-registry-record-before-push-mutant",
    "-f-base-image-registry-noop-egress-policy-mutant",
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
        raise MutationFailure("mutant-fixture-shape:noop-egress-policy")
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


def gate(live_path: Path) -> dict[str, object]:
    description = fixture()
    live = json.loads(live_path.read_text(encoding="utf-8"))
    live_mutant = live.get("mutant", {})
    if (
        live_mutant.get("mechanism") != "kindnet-NetworkPolicy"
        or live_mutant.get("podPhase") != "Succeeded"
        or live_mutant.get("result") != "RED"
    ):
        raise MutationFailure(f"live-mutant-not-red:{live_mutant}")
    try:
        mutant = run_test(*BASELINE_FLAGS, "-fbase-image-registry-noop-egress-policy-mutant")
        if mutant.returncode == 0:
            raise MutationFailure("mutant-survived:noop-egress-policy")
        marker = "noop egress policy"
        if marker not in mutant.stdout:
            raise MutationFailure(f"mutant-wrong-locus:{marker}:{mutant.stdout[-3000:]}")
    finally:
        baseline = run_test(*BASELINE_FLAGS)
        if baseline.returncode:
            raise MutationFailure(f"baseline-not-restored:{baseline.stdout[-3000:]}")
    return {
        "schema": "amoebius.phase25.sprint25.4-mutants.v1",
        "baselineRestored": True,
        "results": [
            {
                "mutant": "noop-egress-policy",
                "mutation": description["mutation"],
                "expectedOracle": description["expected_oracle"],
                "observedFailureMarker": marker,
                "liveKindnetCanaryPhase": live_mutant["podPhase"],
                "result": "RED",
            }
        ],
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path)
    # The live observation is supplied by the caller from this run's own bundle. It has no
    # default on purpose: a default would name a location, and the last run to write there
    # would decide this gate instead of the run in progress.
    parser.add_argument("--live", type=Path, required=True, help="this run's no-public-pull observation")
    arguments = parser.parse_args(argv)
    try:
        result = gate(arguments.live)
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence is None:
            print(encoded, end="")
        else:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        print("phase25-sprint25.4-mutation-gate: PASS (1 seeded mutant RED in pure and live gates)")
        return 0
    except (MutationFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase25-sprint25.4-mutation-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
