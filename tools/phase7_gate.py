#!/usr/bin/env python3
"""Run and seal the Phase-7 base capacity/topology fold gate."""

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
FOLD_ORACLE = ROOT / "tests/oracle/phase7/fold_cases.tsv"
COMPILE_ORACLE = ROOT / "tests/oracle/phase7/compile_fail.tsv"
GATE1_ORACLE = ROOT / "tests/oracle/phase7/gate1_cases.tsv"
COMPATIBILITY_ORACLE = ROOT / "tests/oracle/phase7/compatibility.tsv"
MUTANTS = ROOT / "tests/mutants/phase7/mutants.tsv"
LEDGER = ROOT / "test/golden/phase_07_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_07_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase7/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase7/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_07"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def verify_pins() -> tuple[Path, str]:
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    dhall = Path(pins["dhall"]["path"])
    for executable in (cabal, ghc, dhall):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(
        [
            run([str(cabal), "--numeric-version"]).stdout,
            run([str(ghc), "--numeric-version"]).stdout,
            run([str(dhall), "--version"]).stdout,
        ]
    )
    for family in ("cabal", "ghc", "dhall"):
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return cabal, versions


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_oracles(dhall: Path) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    folds = read_tsv(FOLD_ORACLE)
    compile_rows = read_tsv(COMPILE_ORACLE)
    gate1_rows = read_tsv(GATE1_ORACLE)
    compatibility = read_tsv(COMPATIBILITY_ORACLE)
    mutants = read_tsv(MUTANTS)
    if len(folds) != 15 or len({row["case"] for row in folds}) != 15:
        raise GateFailure("fold oracle must contain fifteen unique cases")
    if len({row["twin"] for row in folds}) != 15:
        raise GateFailure("every fold negative must name a distinct legal twin")
    if len(compile_rows) != 7 or len({row["case"] for row in compile_rows}) != 7:
        raise GateFailure("compile oracle must contain seven unique cases")
    if len(gate1_rows) != 3 or len({row["entry"] for row in gate1_rows}) != 3:
        raise GateFailure("Phase-7 Gate-1 oracle must contain three unique entries")
    if len(compatibility) != 9 or {row["accepted"] for row in compatibility} != {"true", "false"}:
        raise GateFailure("compatibility oracle must exhaust the 3x3 matrix in both directions")
    if len(mutants) != 19 or len({row["mutant"] for row in mutants}) != 19:
        raise GateFailure("mutant manifest must contain nineteen unique mutants")
    run([sys.executable, str(ROOT / "tools/locus_registry_lint.py")])
    for row in gate1_rows:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    verify_phase7_registry_coverage(folds, compile_rows, gate1_rows)
    return folds, mutants


def verify_phase7_registry_coverage(
    folds: list[dict[str, str]],
    compile_rows: list[dict[str, str]],
    gate1_rows: list[dict[str, str]],
) -> None:
    registry = read_tsv(ROOT / "dhall/examples/locus_registry.tsv")
    owned = {(row["entry"], row["subcase"]) for row in registry if row["owner_phase"] == "Phase-7"}
    evidence_entries = {
        *(row["catalog"].split(":", 1)[0] for row in folds),
        *(row["entry"] for row in compile_rows),
        *(row["entry"] for row in gate1_rows),
    }
    covered = {(entry, subcase) for entry, subcase in owned if entry in evidence_entries}
    if len(owned) != 11 or covered != owned:
        raise GateFailure(f"Phase-7 registry coverage drifted: covered={sorted(covered)}, owned={sorted(owned)}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Register-1 only; runtime correspondence UNVERIFIED\n", "entry\tsubcase\tlocus\tstatus\n"]
    for row in registry:
        if row["owner_phase"] == "Phase-7":
            lines.append(f"{row['entry']}\t{row['subcase']}\t{row['validation_locus']}\tdischarged\n")
    GENERATED_LEDGER.write_text("".join(lines), encoding="utf-8")


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capacity/Types.hs",
        ROOT / "src/Amoebius/Capacity/Fold.hs",
        ROOT / "src/Amoebius/Dsl/Topology.hs",
    ]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail)\b")
    for path in paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial token {match.group(1)!r} in {path.relative_to(ROOT)}")
    cabal_text = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in cabal_text:
            raise GateFailure(f"compile totality option missing: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "dsl-spec",
            "capacity-topology-spec",
            "-f-phase6-mutant",
            "-f-phase6-normalization-mutant",
            "--offline",
            "--test-show-details=direct",
        ]
    )
    token = "capacity-topology-spec: PASS (3 Gate-1, 15 fold negatives, 15 twins, 2 positives, 7 compile pairs, 4 properties)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-7 acceptance token is absent:\n{result.stdout}")
    if ">=30% accept/reject coverage" not in result.stdout:
        raise GateFailure("QuickCheck coverage token is absent")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal),
                "test",
                "capacity-topology-spec",
                "--offline",
                "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"phase7-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(folds: list[dict[str, str]], mutants: list[dict[str, str]]) -> None:
    metrics = {
        "fold-negatives": f"{len(folds)}/{len(folds)}-specific-tag-red",
        "legal-twins": f"{len(folds)}/{len(folds)}-green",
        "positive-topologies": "2/2-decode-and-place",
        "gate1-topology-cases": "3/3-exact-red-with-green-twins",
        "compile-fail-pairs": "7/7-legal-green-illegal-type-red",
        "compatibility-matrix": "9/9-equivalent",
        "quickcheck-properties": "4/4-green-checkCoverage-30-percent-both-directions",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "registry-subcases": "11/11-Phase-7-owned-discharged",
        "base-fold-totality": "compile-exhaustive-and-sampled-no-crash",
        "acceptance-token": "spec-composition-proven-base-capacity-topology",
        "storage-geometry": "UNVERIFIED",
        "execution-accelerator-provider-root-fit": "UNVERIFIED",
        "runtime": "UNVERIFIED",
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
    tested = {
        "base-capacity-types",
        "gate1-topology-foreclosures",
        "fits-equivalence",
        "carve-zero-capable-subtraction",
        "fixed-placement-witness",
        "elastic-growth-envelope",
        "elementwise-topology-compatibility",
        "rke2-host-distinctness",
        "linux-host-quorum-compile-barriers",
        "capacity-topology-negative-corpus",
        "legal-multisubstrate-fixed-placement",
        "legal-managed-eks-elastic-placement",
        "independent-placement-validator",
        "quickcheck-capacity-topology-properties",
        "phase7-mutant-battery",
        "phase7-validation-locus-ledger",
        "capacity-feasibility",
    }
    proven = {"base-fold-compile-totality"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        if surface in proven:
            status = "proven-for-the-model"
        elif surface in tested:
            status = "tested"
        else:
            status = "UNVERIFIED"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 7,
        "gate_command": "python3 tools/phase7_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "UNVERIFIED"},
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
        raise GateFailure("committed Phase-7 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(suite: str, mutant_log: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(suite, encoding="utf-8")
    (EVIDENCE / "mutants.log").write_text(mutant_log, encoding="utf-8")
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
        pins = json.loads(PINS.read_text(encoding="utf-8"))
        folds, mutants = verify_oracles(Path(pins["dhall"]["path"]))
        verify_totality_sources()
        suite = run_green_suite(cabal)
        mutant_log = verify_mutants(cabal, mutants)
        write_results(folds, mutants)
        ledger_hash = verify_ledger()
        retain_evidence(suite, mutant_log, versions)
        print(suite, end="", flush=True)
        print(f"phase7-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase7-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
