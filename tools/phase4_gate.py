#!/usr/bin/env python3
"""Run and seal the Phase-4 Dhall Gate-1 acceptance battery."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain" / "pins.json"
RESULTS = ROOT / "gen" / "dhall" / "gate1" / "phase-results.tsv"
LEDGER = ROOT / "test" / "golden" / "phase_04_ledger.json"
ENUMERATION = ROOT / "test" / "enumeration" / "phase_04_surfaces.txt"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN" / "evidence" / "phase_04"


class GateFailure(RuntimeError):
    pass


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def run(command: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def parse_results() -> dict[str, str]:
    if not RESULTS.is_file():
        raise GateFailure(f"Dhall battery did not emit {RESULTS}")
    rows: dict[str, str] = {}
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, value = line.split("\t", 1)
        rows[key] = value
    return rows


def require_results(rows: dict[str, str]) -> None:
    expected = {
        "schema-modules": "14",
        "positive-fixtures": "4/4-green",
        "gate1-negatives": "8/8-red-specific",
        "image-process-negatives": "3/3-red-specific",
        "import-policy-negatives": "2/2-red-ForbiddenImport",
        "constructor-rejections": "12/12-red",
        "arm-inventory": "equal",
        "surface-field-inventory": "equal",
        "resource-field-inventory": "equal",
        "resource-field-deletion-mutants": "525/525-red",
        "resource-type-substitution-mutants": "176/176-red",
        "special-resource-mutants": "4/4-red",
        "custom-arm-mutant": "red",
        "acceptance-token": "spec-composition-proven",
        "gate2-residue": "UNVERIFIED",
        "runtime": "UNVERIFIED",
    }
    for key, wanted in expected.items():
        actual = rows.get(key)
        if actual != wanted:
            raise GateFailure(f"recorded result {key!r}: {actual!r} != {wanted!r}")


def derive_ledger(rows: dict[str, str]) -> dict[str, Any]:
    all_green = (
        rows["positive-fixtures"] == "4/4-green"
        and rows["gate1-negatives"] == "8/8-red-specific"
        and rows["image-process-negatives"] == "3/3-red-specific"
        and rows["constructor-rejections"] == "12/12-red"
        and rows["arm-inventory"] == "equal"
        and rows["surface-field-inventory"] == "equal"
        and rows["resource-field-inventory"] == "equal"
        and rows["resource-field-deletion-mutants"] == "525/525-red"
        and rows["resource-type-substitution-mutants"] == "176/176-red"
        and rows["special-resource-mutants"] == "4/4-red"
        and rows["custom-arm-mutant"] == "red"
    )
    tested = {
        "dhall-schema-wellformed",
        "gate1-positive-corpus",
        "gate1-catalog-negatives",
        "image-process-negatives",
        "import-policy",
        "smart-constructor-rejections",
        "arm-inventory",
        "surface-field-inventory",
        "resource-field-inventory",
        "resource-field-deletion-mutants",
        "resource-type-substitution-mutants",
        "special-resource-mutants",
        "custom-arm-mutant",
    }
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip()]
    coverage = []
    for surface in surfaces:
        if surface == "spec-composition":
            status = "proven-for-the-model" if all_green else "UNVERIFIED"
        elif surface in tested:
            status = "tested"
        else:
            status = "UNVERIFIED"
        coverage.append({"surface": surface, "status": status})
    return {
        "phase": 4,
        "gate_command": "python3 tools/phase4_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested" if all_green else "UNVERIFIED"},
            {"name": "Protocol", "status": "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }


def verify_ledger(rows: dict[str, str]) -> str:
    derived = derive_ledger(rows)
    derived["ledger_hash"] = canonical_hash(derived)
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-4 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(output: str, version: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(output, encoding="utf-8")
    (EVIDENCE / "dhall-version.txt").write_text(version, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    shutil.copyfile(ROOT / "DEVELOPMENT_PLAN/ledgers/phase_04_gate1.md", EVIDENCE / "partial-foreclosure-ledger.txt")


def main() -> int:
    try:
        pins = json.loads(PINS.read_text(encoding="utf-8"))
        dhall = Path(pins["dhall"]["path"])
        if not dhall.is_file():
            raise GateFailure(f"pinned Dhall executable is absent: {dhall}")
        version = run([str(dhall), "--version"]).stdout
        if pins["dhall"]["version"] not in version:
            raise GateFailure(f"Dhall version drifted:\n{version}")
        environment = dict(os.environ)
        environment.update({"AMOEBIUS_DHALL": str(dhall)})
        gate = run([sys.executable, str(ROOT / "tools/dhall_gate1.py")], env=environment)
        print(gate.stdout, end="", flush=True)
        rows = parse_results()
        require_results(rows)
        ledger_hash = verify_ledger(rows)
        retain_evidence(gate.stdout, version)
        print(f"phase4-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError) as problem:
        print(f"phase4-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
