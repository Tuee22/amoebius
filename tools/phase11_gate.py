#!/usr/bin/env python3
"""Run and seal the Phase-11 whole-deployment provision gate."""

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
ARM_ORACLE = ROOT / "tests/oracle/phase10/arm_cases.tsv"
CASES = ROOT / "tests/oracle/phase11/provision_cases.tsv"
PLANNER = ROOT / "tests/oracle/phase11/planner_cases.tsv"
ACTIVATION = ROOT / "tests/oracle/phase11/activation.tsv"
MUTANTS = ROOT / "tests/mutants/phase11/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase11/validation_locus.tsv"
LEDGER = ROOT / "test/golden/phase_11_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_11_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase11/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase11/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_11"


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


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_pins() -> tuple[Path, Path, str]:
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
    return cabal, dhall, versions


def verify_oracles(dhall: Path) -> list[dict[str, str]]:
    arms = read_tsv(ARM_ORACLE)
    cases = read_tsv(CASES)
    planner = read_tsv(PLANNER)
    activation = read_tsv(ACTIVATION)
    mutants = read_tsv(MUTANTS)
    locus = read_tsv(LOCUS)
    expected_tags = {
        "PostBindExpansionOvercommit",
        "MonitoringBudgetExceeded",
        "VramOvercommit",
        "MissingCapability",
        "UnknownCommitment",
        "ElasticPerNodeExpansionOvercommit",
        "MissingPriorProvisionRef",
        "StalePriorProvisionRef",
        "WrongGenerationPriorProvisionRef",
        "WrongArmPriorProvisionRef",
    }
    if len(cases) != 10 or {row["expected"] for row in cases} != expected_tags:
        raise GateFailure("Phase-11 provision oracle must enumerate ten distinct specific failure tags")
    if len(planner) != 2 or {row["expected"] for row in planner} != {"NoInfrastructureRequired", "InfrastructureRequired"}:
        raise GateFailure("Phase-11 planner oracle must enumerate pre-existing and creation paths")
    expected_activation = {
        ("NamespacePart", "Immediate"),
        ("CapacitySchedulerPart", "BootstrapSchedulerStage"),
        ("BootstrapAddonCutoverPart", "AfterBootstrapAddonCutover"),
        ("ManagedCapacityAdmissionPart", "AfterManagedCapacityReady"),
    }
    if len(activation) != 4 or {(row["witness"], row["activation"]) for row in activation} != expected_activation:
        raise GateFailure("Phase-11 activation oracle must pin all four deployment-global stages")
    if len(mutants) != 10 or len({row["mutant"] for row in mutants}) != 10:
        raise GateFailure("Phase-11 mutant manifest must contain ten unique mutants")
    positives = {
        f"legal_{row['slug']}_{shape}"
        for row in arms
        for shape in ("singlenode", "distributed")
    }
    expected_locus = positives | {"planner_preexisting", "planner_creation"}
    expected_locus |= {row["case"] for row in cases}
    expected_locus |= {row["mutant"] for row in mutants}
    if len(locus) != len(expected_locus) or {row["entry"] for row in locus} != expected_locus:
        raise GateFailure("Phase-11 validation-locus ledger has incomplete or duplicate coverage")
    for row in cases:
        for stem in (row["case"], row["legal_twin"]):
            fixture = ROOT / f"dhall/examples/{stem}.dhall"
            checked = run([str(dhall), "type", "--file", str(fixture), "--quiet"], require_success=False)
            if checked.returncode != 0:
                raise GateFailure(f"Phase-11 corpus fixture is not Dhall-well-typed: {fixture}\n{checked.stdout}")
    for row in mutants:
        descriptor = ROOT / f"tests/mutants/phase11/{row['mutant']}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {row['mutant']}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; live provider realization, engine resolution, and runtime correspondence UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capacity/Provision.hs",
        ROOT / "src/Amoebius/Capacity/RenderSource.hs",
        ROOT / "src/Amoebius/Capability/Provisioned.hs",
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
    suite = cabal_text.split("test-suite provision-seal-spec", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in suite:
            raise GateFailure(f"provision seal totality option missing: {option}")
    provision_header = (ROOT / "src/Amoebius/Capacity/Provision.hs").read_text(encoding="utf-8").split(") where", 1)[0]
    if "ProvisionedSpec (.." in provision_header:
        raise GateFailure("ProvisionedSpec constructor is exported")


def run_green_suite(cabal: Path) -> str:
    result = run([str(cabal), "test", "provision-seal-spec", "--offline", "--test-show-details=direct"])
    token = "provision-seal-spec: PASS (18 inherited positives, 2 planner paths, 10 specific negatives, 4 activation stages, 10 mutants, 2 covered properties)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-11 acceptance token is absent:\n{result.stdout}")
    for property_token in ("exact infrastructure vs one-unit-short", "exact backing vs one-byte-short"):
        if property_token not in result.stdout:
            raise GateFailure(f"Phase-11 property coverage token is absent: {property_token}")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal),
                "test",
                "provision-seal-spec",
                "--offline",
                "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"phase11-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "inherited-capability-positives": "18/18-provisioned",
        "infrastructure-planner-paths": "2/2-green",
        "creation-plan-validation-readback": "validated-cas-enacted",
        "render-source-domain": "one-equal-keyed-map",
        "render-activation-stages": "4/4-present",
        "specific-negatives": "10/10-specific-tag-red",
        "quickcheck-properties": "2/2-exact-vs-one-short-green",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "acceptance-token": "provision-composition-proven",
        "live-provider-realization": "UNVERIFIED",
        "live-engine-resolution": "UNVERIFIED",
        "runtime-correspondence": "UNVERIFIED",
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
    proven = {"provision-seal-compile-totality"}
    unverified = {"live-provider-realization", "live-engine-resolution", "runtime-model-correspondence"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        if surface in proven:
            status = "proven-for-the-model"
        elif surface in unverified:
            status = "UNVERIFIED"
        else:
            status = "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 11,
        "gate_command": "python3 tools/phase11_gate.py",
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
        raise GateFailure("committed Phase-11 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
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
        print(f"phase11-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase11-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
