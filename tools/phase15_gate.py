#!/usr/bin/env python3
"""Run and seal the Phase-15 deterministic-simulation substrate checks."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain/pins.json"
SCHEDULES = ROOT / "test/sim/schedules"
MUTANTS = ROOT / "tests/mutants/phase15/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase15/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_15_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_15_ledger.json"
RESULTS = ROOT / "gen/dsl/phase15/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase15/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_15"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = dict(os.environ)
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_pins() -> tuple[Path, str]:
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    for executable in (cabal, ghc):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = run([str(cabal), "--numeric-version"]).stdout + run([str(ghc), "--numeric-version"]).stdout
    if pins["cabal"]["version"] not in versions or pins["ghc"]["version"] not in versions:
        raise GateFailure(f"toolchain version drifted:\n{versions}")
    freeze = (ROOT / "cabal.project.freeze").read_text(encoding="utf-8")
    for pin in ("any.io-classes ==1.10.1.0", "any.io-sim ==1.10.1.0"):
        if pin not in freeze:
            raise GateFailure(f"simulation dependency pin is absent: {pin}")
    return cabal, versions


def verify_oracles() -> None:
    paths = sorted(SCHEDULES.glob("*.json"))
    if [path.stem for path in paths] != ["crash", "partition", "redelivery", "reorder"]:
        raise GateFailure("schedule corpus must contain crash, partition, redelivery, and reorder fixtures")
    rows = [json.loads(path.read_text(encoding="utf-8")) for path in paths]
    names = {row["scheduleName"] for row in rows}
    if names != {"crash-retry", "partition-heal", "redelivery-dedup", "reorder-delay"}:
        raise GateFailure(f"schedule names drifted: {sorted(names)}")
    fault_fields = {
        "schedulePartition",
        "scheduleRedelivery",
        "scheduleReorder",
        "scheduleDuplicate",
        "scheduleCrash",
    }
    if any(field not in row for row in rows for field in fault_fields):
        raise GateFailure("a schedule omits a typed fault field")
    if not all(any(bool(row[field]) for row in rows) for field in fault_fields):
        raise GateFailure("the schedule corpus does not drive every non-delay fault axis")
    if not any(int(row["scheduleDnsDelay"]) > 0 for row in rows):
        raise GateFailure("the schedule corpus does not drive delay")
    outcomes = read_tsv_no_header(SCHEDULES / "expected_outcomes.tsv")
    if len(outcomes) != 4 or {row[0] for row in outcomes} != names:
        raise GateFailure("the independent expected-outcome table does not cover the schedule corpus")
    if any(row[1:] != ["upheld", "-"] for row in outcomes):
        raise GateFailure("reference schedule outcomes must be independently pinned as upheld")
    mutants = read_tsv(MUTANTS)
    if len(mutants) != 1 or mutants[0]["id"] != "m1-dropped-partition-handling":
        raise GateFailure("Phase-15 mutant manifest must name the dropped-partition mutant exactly once")
    locus = read_tsv(LOCUS)
    if len(locus) != 20 or len({row["entry"] for row in locus}) != 20:
        raise GateFailure("Phase-15 validation locus must contain twenty unique entries")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 modeled environment; real-substrate fidelity ASSUMED; live runtime UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )


def read_tsv_no_header(path: Path) -> list[list[str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.reader(handle, delimiter="\t"))


def verify_source_boundaries() -> None:
    files = sorted((ROOT / "src/Amoebius/Sim").rglob("*.hs"))
    if len(files) != 10:
        raise GateFailure(f"simulation source scope drifted: expected 10 modules, got {len(files)}")
    signature_io = re.compile(r"::[^\n]*(?<![A-Za-z0-9_])IO(?![A-Za-z0-9_])")
    forbidden_concurrency = re.compile(r"\bforkIO\b|import\s+(?:qualified\s+)?Control\.Concurrent(?:\s|\()")
    combined = ""
    for path in files:
        source = path.read_text(encoding="utf-8")
        combined += source
        if signature_io.search(source):
            raise GateFailure(f"bare IO signature in simulation scope: {path.relative_to(ROOT)}")
        if forbidden_concurrency.search(source):
            raise GateFailure(f"raw concurrency primitive in simulation scope: {path.relative_to(ROOT)}")
    for token in ("MonadAsync", "MonadSTM", "MonadDelay", "IOSim"):
        if token not in combined:
            raise GateFailure(f"non-vacuous polymorphism token is absent: {token}")


def run_green(cabal: Path) -> str:
    build = run([str(cabal), "build", "lib:dsl-core", "--offline"])
    suite = run([str(cabal), "test", "sim-spec", "--offline", "--test-show-details=direct"])
    token = "sim-spec: PASS (2 interpreters, 6 fake contracts, 4 schedules, same-seed bytes, sensitivity, IOSimPOR, 1 mutant)"
    if token not in suite.stdout:
        raise GateFailure(f"Phase-15 acceptance token is absent:\n{suite.stdout}")
    return build.stdout + suite.stdout


def run_mutant(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "sim-spec",
            "--offline",
            "--test-show-details=direct",
            "--test-options=--mutant=dropped-partition-handling",
        ],
        require_success=False,
    )
    token = "phase15-sim-mutant: RED dropped-partition-handling NoActOnStaleRead"
    if result.returncode == 0 or token not in result.stdout:
        raise GateFailure(f"dropped-partition mutant survived or missed its red locus:\n{result.stdout}")
    return result.stdout


def write_results() -> None:
    metrics = {
        "interpreters": "2/2-reference-program-green",
        "fake-contracts": "6/6-with-knob-controls",
        "schedules": "4/4-oracle-pinned",
        "same-seed-traces": "4/4-byte-identical",
        "schedule-sensitivity": "1/1-distinct",
        "iosimpor": "4/4-bounded-replays-green",
        "mutants": "1/1-red",
        "modeled-env-fidelity": "ASSUMED",
        "live-substrate-runtime": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    assumed = {"modeled-environment-fidelity"}
    unverified = {"live-substrate-runtime"}
    model_proven = {"typed-env-interface", "io-classes-polymorphism-source-gate", "reference-reconciler-one-source"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "assumed" if surface in assumed else "UNVERIFIED" if surface in unverified else "proven-for-the-model" if surface in model_proven else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 15,
        "gate_command": "python3 tools/phase15_gate.py",
        "register": "2",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "assumed"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def verify_ledger() -> str:
    derived = derive_ledger()
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-15 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, mutant: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
    (EVIDENCE / "mutant.log").write_text(mutant, encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(versions, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    shutil.copyfile(GENERATED_LEDGER, EVIDENCE / "validation-locus-ledger.tsv")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--derive-ledger", action="store_true")
    args = parser.parse_args(argv)
    if args.derive_ledger:
        print(json.dumps(derive_ledger(), indent=2))
        return 0
    try:
        cabal, versions = verify_pins()
        verify_oracles()
        verify_source_boundaries()
        green = run_green(cabal)
        mutant = run_mutant(cabal)
        write_results()
        ledger_hash = verify_ledger()
        retain_evidence(green, mutant, versions)
        print(green, end="", flush=True)
        print(f"phase15-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase15-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
