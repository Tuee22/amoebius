#!/usr/bin/env python3
"""Seal Sprint 27.2 scheduler-system authority and two-stage readiness."""

from __future__ import annotations

import argparse
import functools
import hashlib
import json
import os
import re
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
    "-f-capacity-scheduler-default-scheduler-bypass-mutant",
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
        f"--with-compiler={build_tools()[1]}", "test", "scheduler-readiness-spec",
        *BASELINE_FLAGS, *extra, "--test-show-details=direct", "-j1",
    )


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
            invoke("scheduler-readiness-spec", cabal()),
            invoke("collapsed-readiness-mutant", cabal("-fcapacity-scheduler-collapsed-readiness-mutant"), expect_failure="config digest mismatch"),
            invoke("stage-drop-mutant", cabal("-fcapacity-scheduler-stage-drop-mutant"), expect_failure="managed authority cannot install"),
            invoke("default-scheduler-bypass-mutant", cabal("-fcapacity-scheduler-default-scheduler-bypass-mutant"), expect_failure="default-scheduler managed-node bypass"),
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
        (evidence / "sprint-27.2-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-27.2-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (evidence / "sprint-27.2-mutants.json").write_text(json.dumps({"schema": "amoebius.phase27.sprint27.2-mutants.v1", "baselineRestored": True, "results": [
            {"mutant": "collapsed-readiness", "result": "RED", "observedFailureMarker": "config digest mismatch"},
            {"mutant": "stage-drop-generic-SSA-before-cutover", "result": "RED", "observedFailureMarker": "managed authority cannot install"},
            {"mutant": "default-scheduler-managed-node-bypass", "result": "RED", "observedFailureMarker": "default-scheduler managed-node bypass"},
        ]}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        message = f"phase27-sprint27.2-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-27.2-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-sprint27.2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
