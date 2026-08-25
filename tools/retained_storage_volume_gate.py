#!/usr/bin/env python3
"""Seal Sprint 33.2's retained-volume ceiling and explicit rebind."""

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
MUTANTS = (
    ("M-skip-durable-aggregate", "retained-storage-skip-durable-aggregate-mutant", "uniform_claim_skew_over_backing"),
    ("M-sum-unequal-ordinals", "retained-storage-sum-unequal-ordinals-mutant", "uniform max rounded x members"),
    ("M-uniform-before-allocation", "retained-storage-uniform-before-allocation-mutant", "uniform max rounded x members"),
    ("M-collapse-uniform-backing-debits", "retained-storage-collapse-backing-debits-mutant", "per-backing debit collapsed"),
    ("M-reclaim-delete", "retained-storage-reclaim-delete-mutant", "Retain policy"),
    ("M-no-rebind", "retained-storage-no-rebind-mutant", "claim UID cleared"),
    ("M-raw-host-directory", "retained-storage-raw-host-directory-mutant", "raw host directory"),
    ("M-cutover-before-verify", "retained-storage-cutover-before-verify-mutant", "migration completion order"),
    ("M-credit-before-cleanup", "retained-storage-credit-before-cleanup-mutant", "cleanup observation required"),
    ("M-fake-verify", "retained-storage-fake-verify-mutant", "byte verification mismatch"),
)
BASELINE_FLAGS = tuple(f"-f-{flag}" for _name, flag, _marker in MUTANTS)


class GateFailure(RuntimeError):
    pass


@functools.cache
def build_tools() -> tuple[str, str]:
    resolved = toolchain.resolve(["cabal", "ghc"])
    return resolved["cabal"]["path"], resolved["ghc"]["path"]


def invoke(
    name: str, arguments: Sequence[str], *, timeout: int = 1800,
    expect_failure: str | None = None,
) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ.copy(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if expect_failure is None and result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout[-6000:]}")
    if expect_failure is not None and (result.returncode == 0 or expect_failure not in result.stdout):
        raise GateFailure(f"{name}:mutant-wrong-verdict:{result.returncode}:{expect_failure}:{result.stdout[-6000:]}")
    return {
        "name": name, "command": shlex.join(arguments), "output": result.stdout.strip(),
        "result": "RED" if expect_failure else "PASS",
    }


def cabal(suite: str, *extra: str) -> tuple[str, ...]:
    return (
        build_tools()[0], f"--builddir={ROOT / '.build/dist-newstyle/retained-storage'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={build_tools()[1]}", "test", suite, *BASELINE_FLAGS, *extra,
        "--test-show-details=direct", "-j1",
    )


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    parser.add_argument("--image", required=True, help="the Phase-31 digest reference imported into this run's node")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    live_path = evidence / "sprint-28.2-live.json"
    try:
        rows = [
            invoke("live-retained-volume", (sys.executable, "tools/retained_storage_volume_live.py", "--output", str(live_path), "--image", arguments.image), timeout=7200),
            invoke("pure-retained-volume", cabal("retained-storage-volume-spec")),
            invoke("external-live-evidence-reader", cabal("retained-storage-volume-live", f"--test-options={live_path}")),
            invoke("no-retained-delete", ("tools/no_retained_delete_check.sh",)),
        ]
        for name, flag, marker in MUTANTS:
            rows.append(invoke(name, cabal("retained-storage-volume-spec", f"-f{flag}"), expect_failure=marker))
        rows.extend((
            invoke("baseline-restored", cabal("retained-storage-volume-spec")),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ))
        live = json.loads(live_path.read_text(encoding="utf-8"))
        if not live.get("rebind", {}).get("byteIdentical") or live.get("hardCeiling", {}).get("overflowErrno") != "ENOSPC":
            raise GateFailure("live-evidence-domain")
        stable = {
            "schema": "amoebius.retained-storage.sprint-28.2-receipt.v1", "register": 3,
            "substrate": "linux-cpu", "durableBackingFold": True, "fixedRawImage": True,
            "hardCeiling": "ENOSPC", "statefulSetTemplateOnly": True,
            "releasedToBound": True, "nonceByteIdentical": True,
            "migrationCorpus": {"negative": 3, "positive": 1},
            "storageScalingAuthority": "fresh-single-use",
            "mutantsRed": [name for name, _flag, _marker in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-28.2-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-28.2-mutants.json").write_text(json.dumps({
            "schema": "amoebius.retained-storage.sprint-28.2-mutants.v1", "baselineRestored": True,
            "results": [{"mutant": name, "result": "RED", "observedFailureMarker": marker} for name, _flag, marker in MUTANTS],
        }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-28.2-phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
        )
        message = f"retained-storage-sprint-28.2-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-28.2-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"retained-storage-sprint-28.2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
