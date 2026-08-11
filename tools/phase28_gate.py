#!/usr/bin/env python3
"""Run and seal the complete Phase-28 retained-storage acceptance gate."""

from __future__ import annotations

import argparse
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
ENUMERATION = ROOT / "test/enumeration/phase_28_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_28_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"phase33-control-plane-no-pvc"}
MUTANTS = (
    ("M-skip-durable-aggregate", "phase28-retained-pv-spec", "phase28-skip-durable-aggregate-mutant", "uniform_claim_skew_over_backing"),
    ("M-sum-unequal-ordinals", "phase28-retained-pv-spec", "phase28-sum-unequal-ordinals-mutant", "uniform max rounded x members"),
    ("M-uniform-before-allocation", "phase28-retained-pv-spec", "phase28-uniform-before-allocation-mutant", "uniform max rounded x members"),
    ("M-collapse-uniform-backing-debits", "phase28-retained-pv-spec", "phase28-collapse-backing-debits-mutant", "per-backing debit collapsed"),
    ("M-reclaim-delete", "phase28-retained-pv-spec", "phase28-reclaim-delete-mutant", "Retain policy"),
    ("M-no-rebind", "phase28-retained-pv-spec", "phase28-no-rebind-mutant", "claim UID cleared"),
    ("M-raw-host-directory", "phase28-retained-pv-spec", "phase28-raw-host-directory-mutant", "raw host directory"),
    ("M-cutover-before-verify", "phase28-retained-pv-spec", "phase28-cutover-before-verify-mutant", "migration completion order"),
    ("M-credit-before-cleanup", "phase28-retained-pv-spec", "phase28-credit-before-cleanup-mutant", "cleanup observation required"),
    ("M-fake-verify", "phase28-retained-pv-spec", "phase28-fake-verify-mutant", "byte verification mismatch"),
    ("M-soft-delete", "phase28-rebind-spec", "phase28-soft-delete-mutant", "soft delete rejected"),
    ("M-seed-marker", "phase28-rebind-spec", "phase28-seed-marker-mutant", "seed marker rejected"),
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 2400) -> dict[str, str]:
    environment = os.environ.copy()
    environment.pop("PHASE28_RESUME_CLEAN_RUN1", None)
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def reject_mutant(name: str, suite: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (CABAL, "test", suite, f"-f{flag}", "--test-show-details=direct", "-j1")
    result = subprocess.run(arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1200)
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    return "sha256:" + hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.lstrip().startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 28, "gate_command": "python3 tools/phase28_gate.py",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-10",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"}, {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def evidence_domain() -> dict[str, Any]:
    live = json.loads((EVIDENCE / "rebind-live.json").read_text(encoding="utf-8"))
    if "resumedAfterInterruptedBootstrap" in live.get("artifactSource", {}).get("run1", {}):
        raise GateFailure("rebind-live-used-resume-shortcut")
    if not all(live.get("marker", {}).get(key) for key in ("postgresAbsentBeforeWrite", "minioAbsentBeforeWrite", "postgresByteIdentical", "minioByteIdentical")):
        raise GateFailure("marker-domain")
    if live.get("marker", {}).get("postRecreateWriteOperations") != 0 or live.get("marker", {}).get("seedCommands") != []:
        raise GateFailure("marker-write-or-seed-domain")
    if not all(live.get("deleteBoundary", {}).get(key) for key in ("kindClusterAbsent", "nodeContainerAbsent", "apiServerUnreachable", "backingPresent")):
        raise GateFailure("delete-boundary-domain")
    if not live.get("freshCluster", {}).get("serverCaChanged") or not live.get("freshCluster", {}).get("clusterUidChanged"):
        raise GateFailure("fresh-cluster-domain")
    if live.get("artifactSource", {}).get("publicRegistryPulls") != 0:
        raise GateFailure("public-registry-pull")
    return live


def write_sprint_receipt(rows: list[dict[str, str]]) -> str:
    stable = {
        "schema": "amoebius.phase28.sprint28.3-receipt.v1", "register": 3, "substrate": "linux-cpu",
        "representativeWitnesses": ["Postgres row", "MinIO object"], "realClusterDelete": True,
        "freshCluster": True, "freshPvObjects": True, "byteIdentical": True, "postRecreateWrites": 0,
        "mutantsRed": ["M-soft-delete", "M-seed-marker"], "result": "PASS",
    }
    receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
    (EVIDENCE / "sprint-28.3-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (EVIDENCE / "sprint-28.3-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
    message = f"phase28-sprint28.3-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
    (EVIDENCE / "sprint-28.3-gate.log").write_text(message + "\n", encoding="utf-8")
    return receipt["receiptFingerprint"]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        python = sys.executable
        rows = [
            invoke("single-storageclass", (python, "tools/phase28_sprint28_1_gate.py")),
            invoke("retained-volume-live", (python, "tools/phase28_sprint28_2_live.py")),
            invoke("cluster-delete-recreate-live", (python, "tools/phase28_rebind_live.py")),
            invoke("baseline-and-external-readers", (CABAL, "test", "phase28-storageclass-spec", "phase28-storageclass-live", "phase28-retained-pv-spec", "phase28-retained-pv-live", "phase28-rebind-spec", "phase28-rebind-live", "--test-show-details=direct", "-j1")),
            invoke("no-retained-delete", ("test/ci/no_retained_delete.sh",)),
        ]
        evidence_domain()
        mutant_rows = [reject_mutant(*mutant) for mutant in MUTANTS]
        rows.extend(mutant_rows)
        disabled = tuple(f"-f-{flag}" for _, _, flag, _ in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "phase28-retained-pv-spec", "phase28-rebind-spec", *disabled, "--test-show-details=direct", "-j1")))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        sprint_hash = write_sprint_receipt(rows)
        derived = derive_ledger()
        committed = json.loads(LEDGER.read_text(encoding="utf-8"))
        if committed != derived:
            raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
        rows.append(invoke("ledger-lint", (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        log = [f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows]
        log.append(f"SPRINT-28.3 {sprint_hash}")
        log.append(f"PHASE-28-GATE PASS {derived['ledger_hash']}")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"phase28-gate: PASS ({len(rows)} checks; {derived['ledger_hash']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase28-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
