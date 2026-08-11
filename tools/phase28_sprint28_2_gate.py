#!/usr/bin/env python3
"""Seal Sprint 28.2's deterministic retained-PV and explicit-rebind seam."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_28"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
MUTANTS = (
    ("M-skip-durable-aggregate", "phase28-skip-durable-aggregate-mutant", "uniform_claim_skew_over_backing"),
    ("M-sum-unequal-ordinals", "phase28-sum-unequal-ordinals-mutant", "uniform max rounded x members"),
    ("M-uniform-before-allocation", "phase28-uniform-before-allocation-mutant", "uniform max rounded x members"),
    ("M-collapse-uniform-backing-debits", "phase28-collapse-backing-debits-mutant", "per-backing debit collapsed"),
    ("M-reclaim-delete", "phase28-reclaim-delete-mutant", "Retain policy"),
    ("M-no-rebind", "phase28-no-rebind-mutant", "claim UID cleared"),
    ("M-raw-host-directory", "phase28-raw-host-directory-mutant", "raw host directory"),
    ("M-cutover-before-verify", "phase28-cutover-before-verify-mutant", "migration completion order"),
    ("M-credit-before-cleanup", "phase28-credit-before-cleanup-mutant", "cleanup observation required"),
    ("M-fake-verify", "phase28-fake-verify-mutant", "byte verification mismatch"),
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 1200) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (CABAL, "test", "phase28-retained-pv-spec", f"-f{flag}", "--test-show-details=direct", "-j1")
    result = subprocess.run(arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1200)
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main() -> int:
    try:
        python = sys.executable
        rows = [
            invoke("live-retained-rebind", (python, "tools/phase28_sprint28_2_live.py")),
            invoke("pure-and-external-readers", (CABAL, "test", "phase28-retained-pv-spec", "phase28-retained-pv-live", "--test-show-details=direct", "-j1")),
            invoke("no-retained-delete", ("test/ci/no_retained_delete.sh",)),
        ]
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "phase28-retained-pv-spec", *disabled, "--test-show-details=direct", "-j1")))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        live = json.loads((EVIDENCE / "sprint-28.2-live.json").read_text(encoding="utf-8"))
        if not live.get("rebind", {}).get("byteIdentical") or live.get("hardCeiling", {}).get("overflowErrno") != "ENOSPC":
            raise GateFailure("live-evidence-domain")
        stable = {
            "schema": "amoebius.phase28.sprint28.2-receipt.v1", "register": 3, "substrate": "linux-cpu",
            "durableBackingFold": True, "fixedRawImage": True, "hardCeiling": "ENOSPC",
            "statefulSetTemplateOnly": True, "releasedToBound": True, "nonceByteIdentical": True,
            "migrationCorpus": {"negative": 3, "positive": 1}, "storageScalingAuthority": "fresh-single-use",
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (EVIDENCE / "sprint-28.2-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "sprint-28.2-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        message = f"phase28-sprint28.2-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (EVIDENCE / "sprint-28.2-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase28-sprint28.2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
