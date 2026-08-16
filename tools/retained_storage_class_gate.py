#!/usr/bin/env python3
"""Seal Sprint 28.1's single inert retained StorageClass."""

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


class GateFailure(RuntimeError):
    pass


@functools.cache
def build_tools() -> tuple[str, str]:
    resolved = toolchain.resolve(["cabal", "ghc"])
    return resolved["cabal"]["path"], resolved["ghc"]["path"]


def invoke(name: str, arguments: Sequence[str], timeout: int = 1800) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ.copy(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout[-6000:]}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def cabal(suite: str, *extra: str) -> tuple[str, ...]:
    return (
        build_tools()[0], f"--builddir={ROOT / '.build/dist-newstyle/retained-storage'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={build_tools()[1]}", "test", suite, *extra,
        "--test-show-details=direct", "-j1",
    )


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    live_path = evidence / "sprint-28.1-live.json"
    try:
        rows = [
            invoke("live-storage-class", (sys.executable, "tools/retained_storage_class_live.py", "--output", str(live_path)), timeout=3600),
            invoke("pure-storage-class", cabal("retained-storage-class-spec")),
            invoke("external-live-evidence-reader", cabal("retained-storage-class-live", f"--test-options={live_path}")),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        live = json.loads(live_path.read_text(encoding="utf-8"))
        if live.get("inventory", {}).get("count") != 1 or live.get("pendingClaim", {}).get("eventReason") != "WaitForFirstConsumer":
            raise GateFailure("live-evidence-domain")
        stable = {
            "schema": "amoebius.retained-storage.sprint-28.1-receipt.v1", "register": 3,
            "substrate": "linux-cpu", "storageClassCount": 1,
            "provisioner": "kubernetes.io/no-provisioner", "reclaimPolicy": "Retain",
            "volumeBindingMode": "WaitForFirstConsumer", "defaultClassAnnotations": 0,
            "unmatchedClaimReason": "WaitForFirstConsumer", "explicitBind": True,
            "negativeRed": True, "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-28.1-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-28.1-phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
        )
        message = f"retained-storage-sprint-28.1-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-28.1-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"retained-storage-sprint-28.1-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
