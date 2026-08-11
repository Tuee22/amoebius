#!/usr/bin/env python3
"""Join the live kindnet survivor with the committed Phase-25.4 CPP mutant."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parents[1]
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
MUTANT = ROOT / "mutants/phase25/noop-egress-policy.mutant"
LIVE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_25/sprint-25.4-no-public-pull.json"
BASELINE_FLAGS = (
    "-f-phase25-bootstrap-domain-expansion-mutant",
    "-f-phase25-handoff-without-equality-mutant",
    "-f-phase25-record-before-push-mutant",
    "-f-phase25-noop-egress-policy-mutant",
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


def run_test(*flags: str) -> subprocess.CompletedProcess[str]:
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


def gate() -> dict[str, object]:
    description = fixture()
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    live_mutant = live.get("mutant", {})
    if (
        live_mutant.get("mechanism") != "kindnet-NetworkPolicy"
        or live_mutant.get("podPhase") != "Succeeded"
        or live_mutant.get("result") != "RED"
    ):
        raise MutationFailure(f"live-mutant-not-red:{live_mutant}")
    try:
        mutant = run_test(*BASELINE_FLAGS, "-fphase25-noop-egress-policy-mutant")
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
    arguments = parser.parse_args(argv)
    try:
        result = gate()
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
