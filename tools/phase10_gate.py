#!/usr/bin/env python3
"""Run and seal the Phase-10 capability binding gate."""

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
GATE1 = ROOT / "tests/oracle/phase10/gate1_cases.tsv"
GATE2 = ROOT / "tests/oracle/phase10/gate2_cases.tsv"
MUTANTS = ROOT / "tests/mutants/phase10/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase10/validation_locus.tsv"
LEDGER = ROOT / "test/golden/phase_10_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_10_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase10/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase10/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_10"


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
    gate1 = read_tsv(GATE1)
    gate2 = read_tsv(GATE2)
    mutants = read_tsv(MUTANTS)
    locus = read_tsv(LOCUS)
    required_arms = {
        "ObjectStore",
        "SecretStore",
        "MessageBus",
        "Sql",
        "Identity",
        "Observability",
        "Registry",
        "Edge",
        "InferenceEngine",
    }
    if len(arms) != 9 or {row["arm"] for row in arms} != required_arms:
        raise GateFailure("Phase-10 arm oracle must enumerate the exact closed nine-arm union")
    if len({row["slug"] for row in arms}) != 9 or len({row["resource"] for row in arms}) != 9:
        raise GateFailure("Phase-10 arm oracle slugs and resource names must be unique")
    if len(gate1) != 3 or {row["case"] for row in gate1} != {"product-in-app", "engine-by-url", "shape-in-app"}:
        raise GateFailure("Phase-10 Gate-1 oracle must contain the three required negatives")
    expected_gate2 = {"UnbuiltProviderArm", "UnboundCapability", "CyclicExtension", "ShadowingExtension"}
    if len(gate2) != 4 or {row["expected"] for row in gate2} != expected_gate2:
        raise GateFailure("Phase-10 Gate-2 oracle must preserve all four specific error tags")
    if len(mutants) != 4 or len({row["mutant"] for row in mutants}) != 4:
        raise GateFailure("Phase-10 mutant manifest must contain four unique mutants")
    positive_names = {
        f"legal_{row['slug']}_{shape}"
        for row in arms
        for shape in ("singlenode", "distributed")
    }
    expected_locus = positive_names | {
        "illegal_product_in_app",
        "illegal_engine_by_url",
        "illegal_shape_in_app",
        "illegal_unbuilt_provider",
        "illegal_unbound_capability",
        "illegal_cyclic_extension",
        "illegal_shadowing_extension",
        *(row["mutant"] for row in mutants),
    }
    if {row["entry"] for row in locus} != expected_locus or len(locus) != len(expected_locus):
        raise GateFailure("Phase-10 validation-locus ledger has incomplete or duplicate coverage")
    for row in arms:
        for shape in ("singlenode", "distributed"):
            fixture = ROOT / f"dhall/examples/legal_{row['slug']}_{shape}.dhall"
            golden = ROOT / f"test/capability/goldens/golden_servicespec_{row['slug']}_{shape}.golden"
            if not fixture.is_file() or not golden.is_file():
                raise GateFailure(f"missing per-arm fixture or golden for {row['slug']} {shape}")
    for row in gate1:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    for row in gate2:
        for fixture in (row["negative"], row["legal"]):
            checked = run([str(dhall), "type", "--file", fixture, "--quiet"], require_success=False)
            if checked.returncode != 0:
                raise GateFailure(f"Gate-2 fixture must be Dhall-well-typed before refinement: {fixture}\n{checked.stdout}")
    run([sys.executable, str(ROOT / "tools/locus_registry_lint.py")])
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; provider realization and engine resolution UNVERIFIED\n" + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capability/Types.hs",
        ROOT / "src/Amoebius/Capability/Binding.hs",
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
    suite = cabal_text.split("test-suite capability-bind-spec", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in suite:
            raise GateFailure(f"capability bind totality option missing: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "capability-bind-spec",
            "--offline",
            "--test-show-details=direct",
        ]
    )
    token = "capability-bind-spec: PASS (9 arms, 18 shape goldens, 3 Gate-1, 4 Gate-2, 4 mutants, 1 covered property)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-10 acceptance token is absent:\n{result.stdout}")
    if "each of nine constructors >=8%" not in result.stdout:
        raise GateFailure("Phase-10 property coverage token is absent")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        descriptor = ROOT / f"tests/mutants/phase10/{name}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {name}")
        result = run(
            [
                str(cabal),
                "test",
                "capability-bind-spec",
                "--offline",
                "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"phase10-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "capability-arms": "9/9-two-shape-green",
        "shape-goldens": "18/18-exact",
        "app-byte-invariance": "9/9-distinct-composed-files-equal-normal-form",
        "structural-shape-oracle": "9/9-object-node-multiset-different",
        "gate1-negatives": "3/3-specific-locus-red",
        "gate2-negatives": "4/4-specific-tag-red",
        "quickcheck-properties": "1/1-green-nine-arms-at-least-8-percent",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "acceptance-token": "binding-composition-proven",
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
    proven = {"capability-bind-compile-totality"}
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
        "phase": 10,
        "gate_command": "python3 tools/phase10_gate.py",
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
        raise GateFailure("committed Phase-10 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
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
        print(f"phase10-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase10-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
