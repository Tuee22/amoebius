#!/usr/bin/env python3
"""Verify and optionally re-execute the complete Register-3 Phase-24 gate."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_24"
ENUMERATION = ROOT / "test/enumeration/phase_24_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_24_ledger.json"


class GateFailure(RuntimeError):
    pass


def run(arguments: Sequence[str]) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if result.returncode:
        raise GateFailure(f"command-failed:{arguments[0]}:{result.returncode}\n{result.stdout}")
    return result


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [line for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line]
    ledger: dict[str, Any] = {
        "phase": 24,
        "gate_command": "python3 tools/phase24_gate.py --execute",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [{"surface": surface, "status": "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def verify_evidence() -> None:
    required = {
        "phase-results.tsv", "pristine-preflight.txt", "pristine-provider.txt",
        "pristine-bootstrap-coordinator-envelopes.tsv", "pristine-process-envelopes.tsv",
        "pristine-host-engine-throttle.tsv", "pristine-observed-inventory.json",
        "pristine-rerun-execve.log", "pristine-postflight.txt",
        "pristine-initial-execve.log.gz", "live-unified-boundary.tsv",
        "live-split-runtime-boundary.tsv", "live-split-runtime-readback.tsv",
        "live-split-image-rejection.txt", "live-etcd-transition-highwater.tsv",
        "live-audit-system-log-highwater.tsv", "live-complete-inventory.tsv",
        "live-process-envelopes.tsv", "live-process-throttle.tsv",
        "live-mutant-results.tsv",
    }
    missing = sorted(name for name in required if not (EVIDENCE / name).is_file())
    if missing:
        raise GateFailure(f"evidence-missing:{missing}")
    with (EVIDENCE / "phase-results.tsv").open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or any("UNVERIFIED" in row["result"] for row in rows):
        raise GateFailure("phase-results-contain-unverified")
    with gzip.open(EVIDENCE / "pristine-initial-execve.log.gz", "rb") as handle:
        if not handle.read(1):
            raise GateFailure("initial-execve-evidence-empty")
    inventory = json.loads((EVIDENCE / "pristine-observed-inventory.json").read_text(encoding="utf-8"))
    commitments = inventory.get("inventoryPodCommitments", [])
    if len(commitments) != 9:
        raise GateFailure(f"pristine-pod-commitment-count:{len(commitments)}")
    for pod in commitments:
        for container in pod.get("commitmentContainers", []):
            required_fields = (
                "commitmentImage", "commitmentCpuRequest", "commitmentCpuLimit",
                "commitmentMemoryRequest", "commitmentMemoryLimit",
                "commitmentEphemeralRequest", "commitmentEphemeralLimit",
            )
            if any(not container.get(field) for field in required_fields):
                raise GateFailure(f"unknown-pod-commitment:{pod.get('commitmentPodIdentity')}")
    if inventory.get("inventoryAcceleratorOffering") != "none":
        raise GateFailure("linux-cpu-accelerator-leak")
    provider = (EVIDENCE / "pristine-provider.txt").read_text(encoding="utf-8")
    if "provider\tincus" not in provider or "execution-lane\tlinux-cpu" not in provider:
        raise GateFailure("pristine-provider-or-lane-mismatch")
    postflight = (EVIDENCE / "pristine-postflight.txt").read_text(encoding="utf-8")
    if "leak-sweep\tpass" not in postflight:
        raise GateFailure("pristine-postflight-not-clean")
    mutants = (EVIDENCE / "live-mutant-results.tsv").read_text(encoding="utf-8")
    if sum(1 for row in mutants.splitlines() if "\tred:" in row) != 6:
        raise GateFailure("mutant-domain-not-six-red")


def verify_ledger() -> str:
    derived = derive_ledger()
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
    run((sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)))
    return str(derived["ledger_hash"])


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="repeat the pristine Incus live run before sealing")
    parser.add_argument("--derive-ledger", action="store_true")
    arguments = parser.parse_args(argv)
    if arguments.derive_ledger:
        print(json.dumps(derive_ledger(), indent=2))
        return 0
    try:
        run((sys.executable, str(ROOT / "test/host/test_phase24_bootstrap_coordinator.py"), "-v"))
        run((sys.executable, str(ROOT / "test/host/test_phase24_pristine_gate.py"), "-v"))
        run(("cabal", "test", "phase24-host-spec", "--test-show-details=direct"))
        run((sys.executable, str(ROOT / "tools/phase24_mutation_gate.py")))
        if arguments.execute:
            run((sys.executable, str(ROOT / "tools/phase24_pristine_gate.py"), "--execute", "--provider", "incus"))
        verify_evidence()
        ledger_hash = verify_ledger()
        print(f"phase24-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase24-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
