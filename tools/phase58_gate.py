#!/usr/bin/env python3
"""Acceptance gate for Phase 58's scoped HA kernel."""

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_58"
ENUMERATION = ROOT / "test/enumeration/phase_58_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_58_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
FLAGS = (
    "phase58-replicas-one-mutant",
    "phase58-sticky-session-required-mutant",
    "phase58-drop-pdb-mutant",
    "phase58-drop-topology-spread-mutant",
    "phase58-fault-one-node-only-mutant",
    "phase58-drop-tenant-cursor-key-mutant",
    "phase58-drop-keycloak-zone-spread-mutant",
    "phase58-redis-one-node-mutant",
    "phase58-redis-persistent-receipt-mutant",
    "phase58-skip-cursor-repair-mutant",
)
UNVERIFIED = {
    "provider-whole-zone-isolation",
    "managed-multizone-placement",
    "off-cluster-oidc-probe",
    "keycloak-envoy-continuity",
    "redis-sentinel-failover",
    "pulsar-sql-minio-observers",
    "kubernetes-cni-provider-observers",
}


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


def configuration(enabled=None):
    return tuple(("-f" if flag == enabled else "-f-") + flag for flag in FLAGS)


def contract(enabled=None):
    return (
        CABAL, "test", "ui-live:phase58-ui-ha-multizone", "-w", GHC,
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
        "phase": 58,
        "gate_command": "python3 tools/phase58_gate.py",
        "register": "3",
        "substrate": "linux-cpu → provider",
        "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
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
    result = run((sys.executable, "tools/phase58_ui_ha_live.py"))
    if result.returncode:
        print(result.stdout)
        return 1
    rows.append(("scoped-live", "PASS"))
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
        "schema": "amoebius.phase58.receipt.v1",
        "register": 3,
        "substrate": "linux-cpu → provider",
        "result": "PASS-SCOPED",
        "haKernel": "TESTED",
        "providerMultiZoneHa": "UNVERIFIED",
        "mutantsRed": list(FLAGS),
    }
    receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    (EVIDENCE / "phase-results.tsv").write_text(
        "check\tresult\n" + "".join(f"{check}\t{status}\n" for check, status in rows)
    )
    print(
        f"phase58-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; "
        f"{receipt['receiptFingerprint']}; provider multi-zone HA UNVERIFIED)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
