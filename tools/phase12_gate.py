#!/usr/bin/env python3
"""Run and seal the Phase-12 inference accelerator-provision gate."""

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
CASES = ROOT / "tests/oracle/phase12/provision_cases.tsv"
OFFERINGS = ROOT / "tests/oracle/phase12/offering_lane.tsv"
FAMILIES = ROOT / "tests/oracle/phase12/family_lane.tsv"
COEXISTENCE = ROOT / "tests/oracle/phase12/coexistence.tsv"
MUTANTS = ROOT / "tests/mutants/phase12/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase12/validation_locus.tsv"
LEDGER = ROOT / "test/golden/phase_12_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_12_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase12/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase12/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_12"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_pins() -> tuple[Path, Path, str]:
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    executables = {name: Path(pins[name]["path"]) for name in ("cabal", "ghc", "dhall")}
    for executable in executables.values():
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(
        [
            run([str(executables["cabal"]), "--numeric-version"]).stdout,
            run([str(executables["ghc"]), "--numeric-version"]).stdout,
            run([str(executables["dhall"]), "--version"]).stdout,
        ]
    )
    for family in executables:
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return executables["cabal"], executables["dhall"], versions


def verify_oracles(dhall: Path) -> list[dict[str, str]]:
    cases = read_tsv(CASES)
    offerings = read_tsv(OFFERINGS)
    families = read_tsv(FAMILIES)
    coexistence = read_tsv(COEXISTENCE)
    mutants = read_tsv(MUTANTS)
    locus = read_tsv(LOCUS)
    if len(cases) != 9 or len({row["case"] for row in cases}) != 9:
        raise GateFailure("Phase-12 provision oracle must enumerate nine unique negatives")
    if len(offerings) != 4 or {row["offering"] for row in offerings} != {"apple", "linux-cpu", "linux-cuda", "windows"}:
        raise GateFailure("Phase-12 offering quotient oracle is incomplete")
    if len(families) != 12 or len({(row["family"], row["lane"]) for row in families}) != 12:
        raise GateFailure("Phase-12 family/lane relation must contain all twelve cells")
    if coexistence != [{"epoch": "all-classes", "device": "cuda-a", "bytes": "15"}]:
        raise GateFailure("Phase-12 hand-authored coexistence aggregation drifted")
    if len(mutants) != 5 or len({row["mutant"] for row in mutants}) != 5:
        raise GateFailure("Phase-12 mutant manifest must contain five unique mutants")
    expected_locus = {
        "legal_inference_singlenode",
        "legal_inference_distributed",
        "legal_inference_cuda",
        *(row["case"] for row in cases),
        *(row["mutant"] for row in mutants),
    }
    if len(locus) != len(expected_locus) or {row["entry"] for row in locus} != expected_locus:
        raise GateFailure("Phase-12 validation-locus ledger has incomplete or duplicate coverage")
    for fixture in (
        "dhall/examples/legal_inference_singlenode.dhall",
        "dhall/examples/legal_inference_distributed.dhall",
        "dhall/examples/legal_inference_cuda.dhall",
    ):
        checked = run([str(dhall), "type", "--file", fixture, "--quiet"], require_success=False)
        if checked.returncode != 0:
            raise GateFailure(f"Phase-12 positive is not Dhall-well-typed: {fixture}\n{checked.stdout}")
    url = run([str(dhall), "type", "--file", "dhall/examples/illegal_engine_by_url.dhall", "--quiet"], require_success=False)
    if url.returncode == 0 or "Url" not in url.stdout:
        raise GateFailure("engine-by-URL fixture missed its Gate-1 Url locus")
    for row in cases:
        if row["case"] == "illegal_engine_by_url":
            continue
        for stem in (row["case"], row["legal_twin"]):
            checked = run([str(dhall), "type", "--file", f"dhall/examples/{stem}.dhall", "--quiet"], require_success=False)
            if checked.returncode != 0:
                raise GateFailure(f"Phase-12 semantic fixture is not Dhall-well-typed: {stem}\n{checked.stdout}")
    for row in mutants:
        descriptor = ROOT / f"tests/mutants/phase12/{row['mutant']}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {row['mutant']}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; live engine resolution and runtime correspondence UNVERIFIED\n" + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [ROOT / "src/Amoebius/Capability/Engine.hs", ROOT / "src/Amoebius/Capacity/Provision.hs"]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail)\b")
    for path in paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial token {match.group(1)!r} in {path.relative_to(ROOT)}")
    suite = (ROOT / "amoebius.cabal").read_text(encoding="utf-8").split("test-suite capability-spec", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in suite:
            raise GateFailure(f"capability-spec totality option missing: {option}")
    engine = (ROOT / "src/Amoebius/Capability/Engine.hs").read_text(encoding="utf-8")
    header = engine.split(") where", 1)[0]
    if "ProvisionedEngineAccelerator (.." in header:
        raise GateFailure("ProvisionedEngineAccelerator constructor is exported")


def run_green_suite(cabal: Path) -> str:
    result = run([str(cabal), "test", "capability-spec", "--offline", "--test-show-details=direct"])
    token = "capability-spec: PASS (3 inference positives, 4 offering quotients, 12 family/lane cells, 1 Gate-1, 8 provision negatives, 5 mutants, 1 covered property)"
    if token not in result.stdout or "each >=9%" not in result.stdout:
        raise GateFailure(f"Phase-12 acceptance or property token is absent:\n{result.stdout}")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [str(cabal), "test", "capability-spec", "--offline", "--test-show-details=direct", f"--test-options=--mutant={name}"],
            require_success=False,
        )
        if result.returncode == 0 or f"phase12-mutant: RED {name}" not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "inference-positives": "3/3-green",
        "offering-quotient": "4/4-exact",
        "family-lane-relation": "12/12-exact",
        "coexistence-aggregation": "1/1-hand-authored-exact",
        "gate1-url-negative": "1/1-specific-locus-red",
        "provision-negatives": "8/8-specific-tag-red",
        "quickcheck-properties": "1/1-eight-branches-at-least-9-percent",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "acceptance-token": "accelerator-provision-composition-proven",
        "live-jit-engine-resolution": "UNVERIFIED",
        "cross-lane-runtime-weight-load": "UNVERIFIED",
        "runtime-correspondence": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    proven = {"phase12-compile-totality", "url-free-engine-runtime"}
    unverified = {"live-jit-engine-resolution", "cross-lane-runtime-weight-load", "runtime-model-correspondence"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 12,
        "gate_command": "python3 tools/phase12_gate.py",
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
        raise GateFailure("committed Phase-12 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
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
        cabal, dhall, versions = verify_pins()
        mutants = verify_oracles(dhall)
        verify_totality_sources()
        suite = run_green_suite(cabal)
        mutant_log = verify_mutants(cabal, mutants)
        write_results(mutants)
        ledger_hash = verify_ledger()
        retain_evidence(suite, mutant_log, versions)
        print(suite, end="", flush=True)
        print(f"phase12-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase12-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
