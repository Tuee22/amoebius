#!/usr/bin/env python3
"""Seal Sprint 28.1's single inert no-provisioner StorageClass."""

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


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 900) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main() -> int:
    try:
        python = sys.executable
        rows = [
            invoke("live-storageclass", (python, "tools/phase28_sprint28_1_live.py")),
            invoke("pure-and-external-readers", ("/home/matthewnowak/.ghcup/bin/cabal", "test", "phase28-storageclass-spec", "phase28-storageclass-live", "--test-show-details=direct", "-j1")),
            invoke("documentation-lint", (python, "tools/doc_lint.py")),
        ]
        live = json.loads((EVIDENCE / "sprint-28.1-live.json").read_text(encoding="utf-8"))
        if live.get("inventory", {}).get("count") != 1 or live.get("pendingClaim", {}).get("eventReason") != "WaitForFirstConsumer":
            raise GateFailure("live-evidence-domain")
        stable = {
            "schema": "amoebius.phase28.sprint28.1-receipt.v1", "register": 3, "substrate": "linux-cpu",
            "storageClassCount": 1, "provisioner": "kubernetes.io/no-provisioner", "reclaimPolicy": "Retain",
            "volumeBindingMode": "WaitForFirstConsumer", "defaultClassAnnotations": 0,
            "unmatchedClaimReason": "WaitForFirstConsumer", "explicitBind": True, "negativeRed": True, "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (EVIDENCE / "sprint-28.1-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "sprint-28.1-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        message = f"phase28-sprint28.1-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (EVIDENCE / "sprint-28.1-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase28-sprint28.1-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
