#!/usr/bin/env python3
"""Run the two committed Sprint-25.2 mutants through the real Haskell gate."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parents[1]
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
MUTANTS = ROOT / "mutants/phase25"
MUTANT_CASES = (
    (
        "bootstrap-domain-expansion",
        "phase25-bootstrap-domain-expansion-mutant",
        "bootstrap domain oracle",
    ),
    (
        "handoff-without-equality",
        "phase25-handoff-without-equality-mutant",
        "handoff mismatch",
    ),
)


class MutationFailure(RuntimeError):
    pass


def fixture(name: str) -> dict[str, str]:
    rows: dict[str, str] = {}
    for line in (MUTANTS / f"{name}.mutant").read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator:
            rows[key] = value
    if not {"surface", "mutation", "expected_oracle"} <= rows.keys():
        raise MutationFailure(f"mutant-fixture-shape:{name}")
    return rows


def cabal_test(*flags: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        (
            CABAL,
            "test",
            "phase25-image-spec",
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


def run_gate() -> dict[str, object]:
    results: list[dict[str, str]] = []
    try:
        for name, enabled_flag, failure_marker in MUTANT_CASES:
            description = fixture(name)
            flags = [
                "-f-phase25-bootstrap-domain-expansion-mutant",
                "-f-phase25-handoff-without-equality-mutant",
                "-f-phase25-record-before-push-mutant",
                f"-f{enabled_flag}",
            ]
            result = cabal_test(*flags)
            if result.returncode == 0:
                raise MutationFailure(f"mutant-survived:{name}")
            if failure_marker not in result.stdout:
                raise MutationFailure(
                    f"mutant-wrong-locus:{name}:{failure_marker}:{result.stdout[-2000:]}"
                )
            results.append(
                {
                    "mutant": name,
                    "mutation": description["mutation"],
                    "expectedOracle": description["expected_oracle"],
                    "observedFailureMarker": failure_marker,
                    "result": "RED",
                }
            )
    finally:
        baseline = cabal_test(
            "-f-phase25-bootstrap-domain-expansion-mutant",
            "-f-phase25-handoff-without-equality-mutant",
            "-f-phase25-record-before-push-mutant",
        )
        if baseline.returncode:
            raise MutationFailure(f"baseline-not-restored:{baseline.stdout[-3000:]}")
    return {
        "schema": "amoebius.phase25.sprint25.2-mutants.v1",
        "baselineRestored": True,
        "results": results,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        result = run_gate()
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence is None:
            print(encoded, end="")
        else:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        print(f"phase25-sprint25.2-mutation-gate: PASS ({len(result['results'])} seeded mutants RED)")
        return 0
    except (MutationFailure, OSError, subprocess.TimeoutExpired) as problem:
        print(f"phase25-sprint25.2-mutation-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
