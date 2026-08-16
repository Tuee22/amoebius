#!/usr/bin/env python3
"""Seal Sprint 27.3 aggregate-CAS reservation, Binding, and recovery."""

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
BASELINE_FLAGS = (
    "-f-capacity-scheduler-collapsed-readiness-mutant", "-f-capacity-scheduler-stage-drop-mutant",
    "-f-capacity-scheduler-default-scheduler-bypass-mutant", "-f-capacity-scheduler-bind-before-reservation-cas-mutant",
    "-f-capacity-scheduler-numeric-add-mutant", "-f-capacity-scheduler-same-uid-double-debit-mutant",
    "-f-capacity-scheduler-bound-deleted-restart-mutant",
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


def invoke(name: str, arguments: Sequence[str], timeout: int = 1800, expect_failure: str | None = None) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if expect_failure is None and result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    if expect_failure is not None and (result.returncode == 0 or expect_failure not in result.stdout):
        raise GateFailure(f"{name}:mutant-wrong-verdict:{result.returncode}:{expect_failure}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "RED" if expect_failure else "PASS"}


def cabal(*extra: str) -> tuple[str, ...]:
    return (
        build_tools()[0],
        f"--builddir={ROOT / '.build/dist-newstyle/capacity-scheduler'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={build_tools()[1]}", "test", "scheduler-reservation-spec",
        *BASELINE_FLAGS, *extra, "--test-show-details=direct", "-j1",
    )


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def writer_boundary() -> dict[str, str]:
    paths = sorted((ROOT / "src/Amoebius/Scheduler").glob("*.hs"))
    forbidden = ("Amoebius.Manifest.Apply", "prepareScopedSsa", "fieldManager=amoebius")
    findings = [f"{path.relative_to(ROOT)}:{symbol}" for path in paths for symbol in forbidden if symbol in path.read_text(encoding="utf-8")]
    if findings:
        raise GateFailure(f"scheduler-entered-generic-ssa:{findings}")
    return {"name": "dedicated-writer-boundary", "command": "internal scheduler import scan", "output": f"{len(paths)} scheduler modules avoid generic SSA", "result": "PASS"}


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
        rows = [
            invoke("scheduler-reservation-spec", cabal()),
            invoke("bind-before-reservation-CAS-mutant", cabal("-fcapacity-scheduler-bind-before-reservation-cas-mutant"), expect_failure="Binding requires BindingInFlight CAS"),
            invoke("numeric-add-mutant", cabal("-fcapacity-scheduler-numeric-add-mutant"), expect_failure="whole-ledger refold did not reject overspend"),
            invoke("same-UID-double-debit-mutant", cabal("-fcapacity-scheduler-same-uid-double-debit-mutant"), expect_failure="same UID retry does not debit or bump CAS"),
            invoke("bound-deleted-on-restart-mutant", cabal("-fcapacity-scheduler-bound-deleted-restart-mutant"), expect_failure="Bound survives restart"),
            invoke("baseline-restored", cabal()),
            writer_boundary(),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        stable = {
            "schema": "amoebius.phase27.sprint27.3-receipt.v1", "register": 2, "substrate": "linux-cpu",
            "protocol": ["Reserved", "BindingInFlight", "Binding", "ConfirmedBound", "Bound"],
            "wholeLedgerRefold": True, "sameUidIdempotent": True, "unknownRecoveryCharged": True,
            "seededMutantsRed": 4, "genericSsaImports": 0, "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-27.3-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-27.3-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (evidence / "sprint-27.3-mutants.json").write_text(json.dumps({"schema": "amoebius.phase27.sprint27.3-mutants.v1", "baselineRestored": True, "results": [
            {"mutant": "bind-before-reservation-CAS", "result": "RED", "observedFailureMarker": "Binding requires BindingInFlight CAS"},
            {"mutant": "numeric-add-instead-of-whole-ledger-refold", "result": "RED", "observedFailureMarker": "whole-ledger refold did not reject overspend"},
            {"mutant": "same-UID-double-debit", "result": "RED", "observedFailureMarker": "same UID retry does not debit or bump CAS"},
            {"mutant": "bound-deleted-on-restart", "result": "RED", "observedFailureMarker": "Bound survives restart"},
        ]}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        message = f"phase27-sprint27.3-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-27.3-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-sprint27.3-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
