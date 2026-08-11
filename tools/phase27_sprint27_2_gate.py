#!/usr/bin/env python3
"""Seal Sprint 27.2 scheduler-system authority and two-stage readiness."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_27"
BASELINE_FLAGS = (
    "-f-phase27-collapsed-readiness-mutant", "-f-phase27-stage-drop-mutant",
    "-f-phase27-default-scheduler-bypass-mutant",
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
    return ("/home/matthewnowak/.ghcup/bin/cabal", "test", "scheduler-readiness-spec", *BASELINE_FLAGS, *extra, "--test-show-details=direct", "-j1")


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def forbidden_symbols() -> dict[str, str]:
    paths = (
        ROOT / "src/Amoebius/Scheduler/Readiness.hs",
        ROOT / "src/Amoebius/Admission/ExecutionIdentity.hs",
        ROOT / "src/Amoebius/Manifest/Authority.hs",
    )
    pattern = re.compile(r"\b(threadDelay|registerDelay|getMonotonicTime|unsafePerformIO|usleep)\b")
    findings = [f"{path.relative_to(ROOT)}:{line_number}" for path in paths for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1) if pattern.search(line)]
    if findings:
        raise GateFailure(f"forbidden-readiness-symbols:{findings}")
    return {"name": "forbidden-readiness-symbol-lint", "command": "internal source scan", "output": "3 modules clean", "result": "PASS"}


def main() -> int:
    try:
        rows = [
            invoke("scheduler-readiness-spec", cabal()),
            invoke("collapsed-readiness-mutant", cabal("-fphase27-collapsed-readiness-mutant"), expect_failure="config digest mismatch"),
            invoke("stage-drop-mutant", cabal("-fphase27-stage-drop-mutant"), expect_failure="managed authority cannot install"),
            invoke("default-scheduler-bypass-mutant", cabal("-fphase27-default-scheduler-bypass-mutant"), expect_failure="default-scheduler managed-node bypass"),
            invoke("baseline-restored", cabal()),
            forbidden_symbols(),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        stable = {
            "schema": "amoebius.phase27.sprint27.2-receipt.v1", "register": 1, "substrate": "linux-cpu",
            "readinessStages": ["BootstrapCapacitySchedulerReady", "ManagedCapacityReady"],
            "schedulerSystemTokenSingleUse": True, "managedAuthorityIndependentReadback": True,
            "seededMutantsRed": 3, "forbiddenReadinessSymbols": 0, "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (EVIDENCE / "sprint-27.2-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "sprint-27.2-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "sprint-27.2-mutants.json").write_text(json.dumps({"schema": "amoebius.phase27.sprint27.2-mutants.v1", "baselineRestored": True, "results": [
            {"mutant": "collapsed-readiness", "result": "RED", "observedFailureMarker": "config digest mismatch"},
            {"mutant": "stage-drop-generic-SSA-before-cutover", "result": "RED", "observedFailureMarker": "managed authority cannot install"},
            {"mutant": "default-scheduler-managed-node-bypass", "result": "RED", "observedFailureMarker": "default-scheduler managed-node bypass"},
        ]}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        message = f"phase27-sprint27.2-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (EVIDENCE / "sprint-27.2-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-sprint27.2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
