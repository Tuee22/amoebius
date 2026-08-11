#!/usr/bin/env python3
"""Run and seal the complete Phase-3 gateway-migration acceptance gate."""

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
RESULTS = ROOT / "gen" / "tla" / "gateway-migration-model-spec" / "phase-results.tsv"
LEDGER = ROOT / "test" / "golden" / "phase_03_ledger.json"
ENUMERATION = ROOT / "test" / "enumeration" / "phase_03_surfaces.txt"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN" / "evidence" / "phase_03"


class GateFailure(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


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


def verify_toolchain(pins: dict[str, Any]) -> tuple[Path, Path, str]:
    java = Path(pins["java"]["path"])
    jar = Path(pins["tla2tools"]["path"])
    if not java.is_file() or not jar.is_file():
        raise GateFailure("Phase-2 Java/TLC runtime is absent; run python3 tools/phase2_gate.py first")
    expected = pins["tla2tools"]["sha256"]
    actual = sha256(jar)
    if actual != expected:
        raise GateFailure(f"TLC checksum drifted: {actual} != {expected}")
    java_output = run([str(java), "-version"]).stdout
    if 'version "21.0.12"' not in java_output:
        raise GateFailure(f"unexpected Java runtime:\n{java_output}")
    help_result = subprocess.run(
        [str(java), "-jar", str(jar), "-help"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    expected_tlc = "Version 2.19 of 08 August 2024"
    if expected_tlc not in help_result.stdout:
        raise GateFailure(f"unexpected TLC runtime:\n{help_result.stdout}")
    return java, jar, java_output + next(
        line for line in help_result.stdout.splitlines() if expected_tlc in line
    ) + "\n"


def parse_results() -> dict[str, str]:
    if not RESULTS.is_file():
        raise GateFailure(f"test did not emit {RESULTS}")
    rows: dict[str, str] = {}
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, value = line.split("\t", 1)
        rows[key] = value
    return rows


def require_results(rows: dict[str, str]) -> None:
    expected = {
        "gateway-distinct-state-count": "53",
        "explorer-tlc-fingerprints": "equal",
        "safety-invariants": "5/5-green",
        "liveness-properties": "3/3-green-under-fairness",
        "fairness-drop-mutants": "3/3-red",
        "per-invariant-mutants": "5/5-red-exactly",
        "mechanical-safety-mutants": "5/5-red",
        "iosimpor-schedule-bound": "20",
        "iosimpor-agreement": "green",
        "cutoff-clause-delete-mutants": "8/8-red",
        "scope3-shared-resource-mutant": "red",
        "decomposition-lemma": "OPEN",
    }
    for key, wanted in expected.items():
        actual = rows.get(key)
        if actual != wanted:
            raise GateFailure(f"recorded result {key!r}: {actual!r} != {wanted!r}")


def derive_ledger(rows: dict[str, str]) -> dict[str, Any]:
    safety = rows["safety-invariants"] == "5/5-green"
    liveness = rows["liveness-properties"] == "3/3-green-under-fairness"
    tested = {
        "gateway-model-structure",
        "explorer-tlc-agreement",
        "vacuity-action-antecedent",
        "fairness-sensitivity",
        "per-invariant-mutants",
        "mechanical-mutation-family",
        "iosimpor-bounded-schedules",
        "structural-fit-cutoff",
        "cutoff-clause-mutants",
        "scope3-shared-resource-stress",
    }
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip()]
    coverage = []
    for surface in surfaces:
        if surface == "gateway-safety":
            status = "proven-for-the-model" if safety else "UNVERIFIED"
        elif surface == "gateway-liveness":
            status = "proven-for-the-model" if liveness else "UNVERIFIED"
        elif surface in tested:
            status = "tested"
        else:
            status = "UNVERIFIED"
        coverage.append({"surface": surface, "status": status})
    return {
        "phase": 3,
        "gate_command": "python3 tools/phase3_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "proven-for-the-model" if safety and liveness else "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }


def verify_ledger(rows: dict[str, str]) -> str:
    derived = derive_ledger(rows)
    derived["ledger_hash"] = canonical_hash(derived)
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-3 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools" / "ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(gate_output: str, toolchain_output: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(gate_output, encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(toolchain_output, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    generated = RESULTS.parent
    for source, destination in [
        (generated / "safety" / "GatewayMigration.tlc.log", "GatewayMigration-safety.tlc.log"),
        (generated / "liveness" / "GatewayMigration.tlc.log", "GatewayMigration-liveness.tlc.log"),
        (generated / "scope3-shared-resource" / "SharedResourceStress.tlc.log", "SharedResourceStress.tlc.log"),
        (generated / "scope3-shared-resource-mutant" / "SharedResourceStress.tlc.log", "SharedResourceStress-mutant.tlc.log"),
    ]:
        shutil.copyfile(source, EVIDENCE / destination)


def main() -> int:
    try:
        pins = json.loads(PINS.read_text(encoding="utf-8"))
        java, jar, toolchain_output = verify_toolchain(pins)
        environment = dict(os.environ)
        environment.update({
            "AMOEBIUS_JAVA": str(java),
            "AMOEBIUS_TLA2TOOLS": str(jar),
            })
        gate = run([
            str(pins["cabal"]["path"]), "test", "gateway-migration-model-spec",
            "--offline", "--test-show-details=direct",
        ], env=environment)
        print(gate.stdout, end="", flush=True)
        rows = parse_results()
        require_results(rows)
        ledger_hash = verify_ledger(rows)
        retain_evidence(gate.stdout, toolchain_output)
        print(f"phase3-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError) as problem:
        print(f"phase3-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
