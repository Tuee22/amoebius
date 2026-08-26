#!/usr/bin/env python3
"""Seal Sprint 31.4 live scheduler binding and bootstrap-to-managed cutover."""

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


def invoke(name: str, arguments: Sequence[str], *, timeout: int = 1800, expect_failure: str | None = None) -> dict[str, str]:
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


def cabal(suite: str, *extra: str) -> tuple[str, ...]:
    return (
        build_tools()[0],
        f"--builddir={ROOT / '.build/dist-newstyle/capacity-scheduler'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={build_tools()[1]}", "test", suite, *BASELINE_FLAGS, *extra,
        "--test-show-details=direct", "-j1",
    )


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate_live(live: Path) -> None:
    value = json.loads(live.read_text(encoding="utf-8"))
    if value.get("register") != 3 or value.get("substrate") != "linux-cpu":
        raise GateFailure("live-register-or-substrate")
    if [row.get("event") for row in value.get("sequence", [])] != [
        "BootstrapCapacitySchedulerReady", "BootstrapAddonCutover", "BootstrapReplacementBoundReady",
        "ManagedCapacityReady", "GeneralGuardedPodAdmitted", "GeneralGuardedPodBoundReady",
    ]:
        raise GateFailure("live-cutover-order")
    if not all(value.get("postflight", {}).values()):
        raise GateFailure("live-postflight-leak")
    if not value.get("rerun", {}).get("byteStable") or value.get("rerun", {}).get("newBindingRequests") != 0:
        raise GateFailure("live-rerun-not-noop")
    universal = value.get("universalLinuxCpu", {})
    if universal.get("availableOnEveryHardwareSubstrate") is not True or universal.get("pristineLinuxHost") != {
        "linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2",
    }:
        raise GateFailure("universal-linux-cpu-contract")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # The bundle this run writes into is supplied by the caller. There is deliberately no
    # default: a default names a location, and whatever a previous run left there would
    # decide this gate instead of the run in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    # The scheduled Pods pull the Phase-30 published digest from the in-cluster registry.
    parser.add_argument("--image", required=True, help="the Phase-30 published digest reference")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    live = evidence / "live-scheduler.json"
    try:
        python = sys.executable
        rows = [
            invoke("live-scheduler-cutover", (python, "tools/capacity_scheduler_live.py", "--output", str(live), "--image", arguments.image), timeout=7200),
            invoke("external-live-evidence-readers", cabal("scheduler-reservation", "scheduler-bootstrap-cutover", f"--test-options={live}")),
            invoke("collapsed-readiness-mutant", cabal("scheduler-readiness-spec", "-fcapacity-scheduler-collapsed-readiness-mutant"), expect_failure="config digest mismatch"),
            invoke("stage-drop-mutant", cabal("scheduler-readiness-spec", "-fcapacity-scheduler-stage-drop-mutant"), expect_failure="managed authority cannot install"),
            invoke("default-scheduler-bypass-mutant", cabal("scheduler-readiness-spec", "-fcapacity-scheduler-default-scheduler-bypass-mutant"), expect_failure="default-scheduler managed-node bypass"),
            invoke("bind-before-reservation-CAS-mutant", cabal("scheduler-reservation-spec", "-fcapacity-scheduler-bind-before-reservation-cas-mutant"), expect_failure="Binding requires BindingInFlight CAS"),
            invoke("numeric-add-mutant", cabal("scheduler-reservation-spec", "-fcapacity-scheduler-numeric-add-mutant"), expect_failure="whole-ledger refold did not reject overspend"),
            invoke("same-UID-double-debit-mutant", cabal("scheduler-reservation-spec", "-fcapacity-scheduler-same-uid-double-debit-mutant"), expect_failure="same UID retry does not debit or bump CAS"),
            invoke("bound-deleted-on-restart-mutant", cabal("scheduler-reservation-spec", "-fcapacity-scheduler-bound-deleted-restart-mutant"), expect_failure="Bound survives restart"),
            invoke("baseline-restored", cabal("scheduler-readiness-spec", "scheduler-reservation-spec", "scheduler-reservation", "scheduler-bootstrap-cutover", f"--test-options={live}")),
            invoke("documentation-lint", (python, "tools/doc_lint.py")),
        ]
        validate_live(live)
        stable = {
            "schema": "amoebius.phase27.sprint27.4-receipt.v1", "register": 3, "substrate": "linux-cpu",
            "readinessStages": ["BootstrapCapacitySchedulerReady", "ManagedCapacityReady"],
            "bindingProtocol": ["Reserved", "BindingInFlight", "Binding", "ConfirmedBound", "Bound"],
            "prematureAdmissionZeroWrites": True, "defaultSchedulerBypassRejected": True,
            "aggregateRaceOverAllocation": 0, "immediateRerunMutations": 0,
            "seededMutantsRed": 7, "postflightLeakFree": True, "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-27.4-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-27.4-phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
        )
        mutants = [
            ("collapsed-readiness", "config digest mismatch"),
            ("stage-drop-generic-SSA-before-cutover", "managed authority cannot install"),
            ("default-scheduler-managed-node-bypass", "default-scheduler managed-node bypass"),
            ("bind-before-reservation-CAS", "Binding requires BindingInFlight CAS"),
            ("numeric-add-instead-of-whole-ledger-refold", "whole-ledger refold did not reject overspend"),
            ("same-UID-double-debit", "same UID retry does not debit or bump CAS"),
            ("bound-deleted-on-restart", "Bound survives restart"),
        ]
        (evidence / "sprint-27.4-mutants.json").write_text(json.dumps({
            "schema": "amoebius.phase27.sprint27.4-mutants.v1", "baselineRestored": True,
            "results": [{"mutant": name, "result": "RED", "observedFailureMarker": marker} for name, marker in mutants],
        }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        message = f"phase27-sprint27.4-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-27.4-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-sprint27.4-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
