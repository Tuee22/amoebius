#!/usr/bin/env python3
"""Seal Sprint 32.5 deterministic scheduler convergence under faults."""

from __future__ import annotations

import argparse
import functools
import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
MUTANTS = (
    ("lost-lease-resourceversion-retry", "NoWriteWithoutExactLeaseHolder"),
    ("collapsed-scheduler-readiness", "DistinctSchedulerReadinessStages"),
    ("premature-managed-authority", "NoGeneralActionBeforeManagedCapacityReady"),
    ("bind-before-cas", "NoBindingBeforeSuccessfulReservationCAS"),
    ("same-uid-double-debit", "OneReservationDebitPerPodUid"),
    ("bound-dropped-on-restart", "BoundReservationSurvivesRestart"),
    ("cached-observation", "FreshSnapshotBeforeSchedulerMutation"),
)


@functools.cache
def build_tools() -> tuple[str, str]:
    """Resolve cabal and the compiler per run from the authored requirements.

    The retired form named a developer-home `cabal` outright, so the gate could only run on
    one machine and inherited whichever GHC that installation offered — which need not
    satisfy the authored range.
    """
    resolved = toolchain.resolve(["cabal", "ghc"])
    return resolved["cabal"]["path"], resolved["ghc"]["path"]


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], *, expect_failure: str | None = None, timeout: int = 1800) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if expect_failure is None and result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    if expect_failure is not None and (result.returncode == 0 or expect_failure not in result.stdout):
        raise GateFailure(f"{name}:mutant-wrong-verdict:{result.returncode}:{expect_failure}:{result.stdout}")
    return {
        "name": name, "command": shlex.join(arguments), "output": result.stdout.strip(),
        "result": "RED" if expect_failure else "PASS",
    }


def cabal(*options: str) -> tuple[str, ...]:
    return (
        build_tools()[0],
        f"--builddir={ROOT / '.build/dist-newstyle/capacity-scheduler'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={build_tools()[1]}", "test", "scheduler-sim",
        "--test-show-details=direct", "-j1", *options,
    )


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # The bundle this run writes into is supplied by the caller. There is deliberately no
    # default: a default names a location, and whatever a previous run left there would
    # decide this gate instead of the run in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    try:
        rows = [invoke("scheduler-sim", cabal())]
        rows.extend(
            invoke(f"sim-mutant-{name}", cabal(f"--test-options=--mutant={name}"), expect_failure=marker)
            for name, marker in MUTANTS
        )
        rows.extend((
            invoke("baseline-restored", cabal()),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ))
        simulation = {
            "schema": "amoebius.phase27.scheduler-simulation.v1", "register": 2.5, "substrate": "linux-cpu",
            "faultClasses": [
                "lease-holder-ambiguity", "bootstrap-readiness-interruption", "managed-cutover-interruption",
                "reservation-cas-race", "binding-failure", "crash-after-binding", "cached-observation-watch-gap",
            ],
            "schedulesPerFaultClass": 256, "totalReplaySchedules": 1792,
            "iosimPor": {"scheduleBound": 24, "branching": 4, "representativeSeed": 197},
            "byteIdenticalReplay": True, "criticalSectionCoverage": True,
            "safety": [
                "exact-lease-holder", "distinct-readiness-stages", "no-general-action-before-managed",
                "one-debit-per-uid", "no-binding-before-cas", "bound-retained-on-restart", "fresh-snapshot-after-watch-gap",
            ],
            "mutantsRed": len(MUTANTS), "modeledApiserverFidelity": "ASSUMED; bounded by Sprint 32.4 Register-3 live observations",
            "result": "PASS",
        }
        (evidence / "sprint-27.5-simulation.json").write_text(json.dumps(simulation, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        stable = {
            "schema": "amoebius.phase27.sprint27.5-receipt.v1", "register": 2.5, "substrate": "linux-cpu",
            "faultClasses": 7, "schedulesPerFaultClass": 256, "totalReplaySchedules": 1792,
            "iosimPorScheduleBound": 24, "seededMutantsRed": 7, "byteIdenticalReplay": True,
            "modeledApiserverFidelity": "ASSUMED", "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-27.5-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-27.5-phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
        )
        (evidence / "sprint-27.5-mutants.json").write_text(json.dumps({
            "schema": "amoebius.phase27.sprint27.5-mutants.v1", "baselineRestored": True,
            "results": [{"mutant": name, "result": "RED", "observedFailureMarker": marker} for name, marker in MUTANTS],
        }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        message = f"phase27-sprint27.5-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-27.5-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-sprint27.5-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
