#!/usr/bin/env python3
"""Acceptance gate for Phase 60's Chrome-backed offline facilities."""

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_60"
ENUMERATION = ROOT / "test/enumeration/phase_60_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_60_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
FLAGS = (
    "encrypted-browser-runtime-store-plaintext-mutant",
    "encrypted-browser-runtime-retain-credentials-mutant",
    "encrypted-browser-runtime-two-replay-leaders-mutant",
    "encrypted-browser-runtime-omit-fencing-mutant",
    "encrypted-browser-runtime-silent-dependency-eviction-mutant",
    "encrypted-browser-runtime-reuse-partition-key-mutant",
)
UNVERIFIED = {"purescript-compiler", "production-generic-client-bundle", "server-replay"}


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


def configuration(enabled=None):
    return tuple(("-f" if flag == enabled else "-f-") + flag for flag in FLAGS)


def contract(enabled=None):
    return (
        CABAL, "test", "offline-runtime:offline-browser-runtime-spec", "-w", GHC,
        *configuration(enabled), "--test-show-details=direct", "-j1", "-v0",
    )


def run(arguments):
    return subprocess.run(
        arguments, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )


def derive_ledger():
    surfaces = [line for line in ENUMERATION.read_text().splitlines() if line]
    value = {
        "phase": 60,
        "gate_command": "python3 tools/encrypted_browser_runtime_gate.py",
        "register": "2",
        "substrate": "none",
        "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": [
            {"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"}
            for surface in surfaces
        ],
    }
    value["ledger_hash"] = fingerprint(value)
    return value


def main():
    if "--derive-ledger" in sys.argv:
        print(json.dumps(derive_ledger(), separators=(",", ":")))
        return 0
    rows = []
    result = run(contract())
    if result.returncode:
        print(result.stdout)
        return 1
    rows.append(("contract", "PASS"))
    result = run((sys.executable, "tools/encrypted_browser_runtime_live.py"))
    if result.returncode:
        print(result.stdout)
        return 1
    rows.append(("chrome-boundary", "PASS"))
    for flag in FLAGS:
        result = run(contract(flag))
        if result.returncode == 0:
            print(flag + " green", file=sys.stderr)
            return 1
        rows.append((flag, "RED"))
    result = run(contract())
    if result.returncode:
        print(result.stdout)
        return 1
    rows.append(("restored", "PASS"))
    result = run((sys.executable, "tools/doc_lint.py"))
    if result.returncode:
        print(result.stdout)
        return 1
    derived = derive_ledger()
    if not LEDGER.exists() or json.loads(LEDGER.read_text()) != derived:
        print("ledger diff", file=sys.stderr)
        return 1
    result = run((sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION)))
    if result.returncode:
        print(result.stdout)
        return 1
    rows.extend((("docs", "PASS"), ("ledger", "PASS")))
    stable = {
        "schema": "amoebius.phase60.receipt.v1",
        "register": 2,
        "substrate": "none",
        "result": "PASS-SCOPED",
        "chromeBoundary": "TESTED",
        "productionPureScriptBundle": "UNVERIFIED",
        "mutantsRed": list(FLAGS),
    }
    receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    (EVIDENCE / "phase-results.tsv").write_text(
        "check\tresult\n" + "".join(f"{check}\t{status}\n" for check, status in rows)
    )
    print(
        f"encrypted-browser-runtime-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; "
        f"{receipt['receiptFingerprint']}; production PureScript bundle/server replay UNVERIFIED)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
