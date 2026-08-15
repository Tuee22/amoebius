#!/usr/bin/env python3
"""Seal Sprint 26.2's Lease, dispatcher, scoped-SSA, and token boundary."""

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


def invoke(name: str, arguments: Sequence[str], timeout: int = 1800) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate_live(live: Path) -> dict[str, Any]:
    observed = json.loads(live.read_text(encoding="utf-8"))
    if observed["coldStartOrder"] != ["Namespace/amoebius-phase26-sprint2", "Lease/amoebius-phase26-sprint2/amoebius-reconciler"]:
        raise GateFailure("cold-start-authority-order")
    if observed["lease"]["holder"] != "phase26-bootstrap-host" or observed["lease"]["staleCasExit"] == 0:
        raise GateFailure("lease-holder-or-stale-cas")
    ssa = observed["ssa"]
    if ssa["fieldManager"] != "amoebius" or not ssa["ownedFieldCorrected"] or not ssa["foreignFieldPreserved"] or not ssa["noOpResourceVersionStable"]:
        raise GateFailure("scoped-ssa-boundary")
    if not {"amoebius", "foreign-manager"} <= set(ssa["managedFieldManagers"]):
        raise GateFailure("managed-field-domain")
    if not observed["postflightNamespaceAbsent"]:
        raise GateFailure("namespace-leak")
    return {
        "coldStartActions": len(observed["coldStartOrder"]),
        "leaseStaleCasRejected": True,
        "scopedSsaManagers": sorted(ssa["managedFieldManagers"]),
        "noOpResourceVersionStable": True,
        "postflightNamespaceAbsent": True,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # The bundle this run writes into is supplied by the caller, so a previous run's
    # observation cannot decide this one.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    live = evidence / "sprint-26.2-live.json"
    try:
        cabal, compiler = build_tools()
        flags = (
            "-f-phase26-wait-for-ready-pure-mutant", "-f-phase26-generation-after-diff-mutant",
            "-f-phase26-label-only-delete-mutant", "-f-phase26-healthy-overbound-child-mutant",
        )
        rows = [
            invoke("haskell-reconcile-spec", (cabal, f"--with-compiler={compiler}", "test", "phase26-reconcile-spec", *flags, "--test-show-details=direct", "-j1")),
            invoke("live-lease-scoped-ssa", (sys.executable, "tools/phase26_sprint26_2_live.py", "--output", str(live))),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        stable = {"schema": "amoebius.phase26.sprint26.2-receipt.v1", "register": 3, "substrate": "linux-cpu", **validate_live(live), "result": "PASS"}
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-26.2-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-26.2-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\tPASS\n" for row in rows), encoding="utf-8")
        print(f"phase26-sprint26.2-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
