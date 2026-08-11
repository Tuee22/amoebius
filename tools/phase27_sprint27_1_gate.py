#!/usr/bin/env python3
"""Seal Sprint 27.1 state-indexed scheduler-ledger normalization."""

from __future__ import annotations

import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_27"
LEDGER_SOURCE = ROOT / "src/Amoebius/Scheduler/Ledger.hs"
FIXTURE = ROOT / "test/scheduler/fixtures/ledger-corpus.json"


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 1800) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate_fixture() -> dict[str, str]:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    states = fixture.get("absentPodStates", [])
    negatives = fixture.get("negativeClasses", [])
    if states != ["Reserved", "BindingInFlight", "Bound", "Terminating", "TerminalRetained"]:
        raise GateFailure(f"absent-state-domain:{states}")
    if len(negatives) != 9 or len(set(negatives)) != 9:
        raise GateFailure(f"negative-domain:{negatives}")
    actions = json.loads((ROOT / "test/live/fixtures/reconcile-corpus/expected-actions.json").read_text(encoding="utf-8"))["schedulerActions"]
    if len(actions) != 9:
        raise GateFailure("scheduler-action-oracle-domain")
    return {"name": "pinned-ledger-oracle", "command": "internal independent fixture read", "output": "5 absent states; 9 negative classes; 9 scheduler actions", "result": "PASS"}


def validate_read_only() -> dict[str, str]:
    source = LEDGER_SOURCE.read_text(encoding="utf-8")
    forbidden = ("Amoebius.Manifest.Apply", "Amoebius.Manifest.Enact", "System.Process", "typed-process", "kubectl", "envApplyObject")
    present = [symbol for symbol in forbidden if symbol in source]
    if present:
        raise GateFailure(f"ledger-writer-import:{present}")
    if "normalizeReservationLedger" not in source or "LedgerOnlyAbsentRecovery" not in source:
        raise GateFailure("ledger-normalizer-surface")
    return {"name": "read-only-ledger-source", "command": "internal import/symbol scan", "output": "no writer capability in Scheduler/Ledger.hs", "result": "PASS"}


def main() -> int:
    try:
        rows = [
            validate_fixture(),
            invoke("scheduler-ledger-spec", ("/home/matthewnowak/.ghcup/bin/cabal", "test", "scheduler-ledger-spec", "--test-show-details=direct", "-j1")),
            validate_read_only(),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        stable = {
            "schema": "amoebius.phase27.sprint27.1-receipt.v1", "register": 1, "substrate": "linux-cpu",
            "reservationStates": 5, "absentRecoveryStates": 5, "negativeClasses": 9,
            "schedulerActionsPinned": 9, "writerImports": 0, "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "sprint-27.1-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "sprint-27.1-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\tPASS\n" for row in rows), encoding="utf-8")
        message = f"phase27-sprint27.1-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (EVIDENCE / "sprint-27.1-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-sprint27.1-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
