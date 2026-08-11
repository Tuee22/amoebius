#!/usr/bin/env python3
"""Re-run and verify the complete Phase-27 scheduler acceptance gate."""

from __future__ import annotations

import argparse
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
ENUMERATION = ROOT / "test/enumeration/phase_27_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_27_ledger.json"
UNVERIFIED = {"modeled-apiserver-fidelity", "completion-release-ledger", "rollback-ledger", "in-cluster-singleton-ownership"}
BASELINE_FLAGS = (
    "-f-phase27-collapsed-readiness-mutant", "-f-phase27-stage-drop-mutant",
    "-f-phase27-default-scheduler-bypass-mutant", "-f-phase27-bind-before-reservation-cas-mutant",
    "-f-phase27-numeric-add-mutant", "-f-phase27-same-uid-double-debit-mutant",
    "-f-phase27-bound-deleted-restart-mutant",
)


class GateFailure(RuntimeError):
    pass


def run(name: str, arguments: Sequence[str], *, timeout: int = 2400) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "result": "PASS", "output": result.stdout.strip()}


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    return "sha256:" + hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [
        line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    ledger: dict[str, Any] = {
        "phase": 27,
        "gate_command": "python3 tools/phase27_gate.py",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [
            {"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"}
            for surface in surfaces
        ],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{path}")
    return value


def validate_evidence() -> None:
    required = {
        *(f"sprint-27.{number}-receipt.json" for number in range(1, 6)),
        *(f"sprint-27.{number}-phase-results.tsv" for number in range(1, 6)),
        "sprint-27.2-mutants.json", "sprint-27.3-mutants.json", "sprint-27.4-mutants.json", "sprint-27.5-mutants.json",
        "sprint-27.5-simulation.json", "live-scheduler.json",
    }
    missing = sorted(name for name in required if not (EVIDENCE / name).is_file())
    if missing:
        raise GateFailure(f"evidence-missing:{missing}")
    receipts = [json_object(EVIDENCE / f"sprint-27.{number}-receipt.json") for number in range(1, 6)]
    if any(receipt.get("result") != "PASS" or receipt.get("substrate") != "linux-cpu" for receipt in receipts):
        raise GateFailure("sprint-receipt-not-pass")
    if [receipt.get("register") for receipt in receipts] != [1, 1, 2, 3, 2.5]:
        raise GateFailure("sprint-register-domain")
    for number, expected in ((2, 3), (3, 4), (4, 7), (5, 7)):
        mutants = json_object(EVIDENCE / f"sprint-27.{number}-mutants.json").get("results", [])
        if len(mutants) != expected or any(row.get("result") != "RED" for row in mutants):
            raise GateFailure(f"sprint-mutant-domain:27.{number}")
    live = json_object(EVIDENCE / "live-scheduler.json")
    if not live.get("rerun", {}).get("byteStable") or live.get("rerun", {}).get("newBindingRequests") != 0:
        raise GateFailure("live-rerun-not-noop")
    if not all(live.get("postflight", {}).values()):
        raise GateFailure("live-postflight-leak")
    simulation = json_object(EVIDENCE / "sprint-27.5-simulation.json")
    if simulation.get("totalReplaySchedules") != 1792 or simulation.get("mutantsRed") != 7:
        raise GateFailure("simulation-coverage-domain")


def verify_ledger() -> str:
    derived = derive_ledger()
    if json_object(LEDGER) != derived:
        raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
    run("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION)))
    return str(derived["ledger_hash"])


def execute() -> list[dict[str, str]]:
    python = sys.executable
    baseline = (
        "/home/matthewnowak/.ghcup/bin/cabal", "test",
        "scheduler-ledger-spec", "scheduler-readiness-spec", "scheduler-reservation-spec",
        "scheduler-reservation", "scheduler-bootstrap-cutover", "scheduler-sim",
        *BASELINE_FLAGS, "--test-show-details=direct", "-j1",
    )
    return [
        run("sprint-27.4-live-and-source-mutation-seal", (python, "tools/phase27_sprint27_4_gate.py")),
        run("sprint-27.5-simulation-seal", (python, "tools/phase27_sprint27_5_gate.py")),
        run("complete-baseline-restored", baseline),
        run("documentation-lint", (python, "tools/doc_lint.py")),
    ]


def write_results(rows: list[dict[str, str]], ledger_hash: str) -> None:
    (EVIDENCE / "phase-results.tsv").write_text(
        "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
    )
    lines: list[str] = []
    for row in rows:
        lines.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], f"RESULT {row['result']}"))
    lines.append(f"PHASE-27-GATE PASS {ledger_hash}")
    (EVIDENCE / "phase-gate.log").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        rows = execute()
        validate_evidence()
        ledger_hash = verify_ledger()
        write_results(rows, ledger_hash)
        print(f"phase27-gate: PASS ({len(rows)} checks; {ledger_hash})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
