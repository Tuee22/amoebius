#!/usr/bin/env python3
"""Seal Sprint 26.3 staged transitions, terminal retention, and delete authority."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_26"
LIVE = EVIDENCE / "sprint-26.3-live.json"
BASELINE_FLAGS = (
    "-f-phase26-wait-for-ready-pure-mutant", "-f-phase26-generation-after-diff-mutant",
    "-f-phase26-label-only-delete-mutant", "-f-phase26-healthy-overbound-child-mutant",
)


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
    return ("/home/matthewnowak/.ghcup/bin/cabal", "test", "phase26-reconcile-spec", *BASELINE_FLAGS, *extra, "--test-show-details=direct", "-j1")


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate_live() -> dict[str, Any]:
    observed = json.loads(LIVE.read_text(encoding="utf-8"))
    transitions = observed["serial"]["transitions"]
    if observed["serial"]["policy"] != "OnDelete" or len(transitions) != 2:
        raise GateFailure("serial-domain")
    if any(row["oldUid"] == row["newUid"] or row["absenceObserved"] != "true" or row["boundReadyObserved"] != "true" for row in transitions):
        raise GateFailure("serial-stage-observation")
    job = observed["job"]
    if job["outcome"] != "Succeeded" or not job["retained"] or job["completionGatewayObjects"] != 0 or job["deleted"]:
        raise GateFailure("job-terminal-retention")
    deletion = observed["delete"]
    if deletion["wrongPreconditionExit"] == 0 or not deletion["exactPreconditionDeleted"]:
        raise GateFailure("authenticated-delete-precondition")
    if not observed["postflightNamespaceAbsent"]:
        raise GateFailure("namespace-leak")
    return {
        "serialTransitions": len(transitions), "terminalOutcome": job["outcome"],
        "terminalRetained": True, "completionGatewayObjects": 0,
        "wrongDeletePreconditionRejected": True, "exactDeletePreconditionAccepted": True,
        "postflightNamespaceAbsent": True,
    }


def main() -> int:
    try:
        rows = [
            invoke("haskell-transition-spec", cabal()),
            invoke("live-staged-transitions", (sys.executable, "tools/phase26_sprint26_3_live.py", "--output", str(LIVE))),
            invoke("label-only-delete-mutant", cabal("-fphase26-label-only-delete-mutant"), expect_failure="changed resourceVersion"),
            invoke("baseline-restored", cabal()),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        stable = {"schema": "amoebius.phase26.sprint26.3-receipt.v1", "register": 3, "substrate": "linux-cpu", **validate_live(), "seededMutantsRed": 1, "result": "PASS"}
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (EVIDENCE / "sprint-26.3-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "sprint-26.3-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "sprint-26.3-mutants.json").write_text(json.dumps({"schema": "amoebius.phase26.sprint26.3-mutants.v1", "baselineRestored": True, "results": [{"mutant": "delete-from-owner-label-alone", "result": "RED", "observedFailureMarker": "changed resourceVersion"}]}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"phase26-sprint26.3-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.3-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
