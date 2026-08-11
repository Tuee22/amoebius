#!/usr/bin/env python3
"""Run and seal the Phase-13 pure manifest-rendering gate."""

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
CORPUS = ROOT / "tests/oracle/phase13/corpus.tsv"
MUTANTS = ROOT / "tests/mutants/phase13/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase13/validation_locus.tsv"
LEDGER = ROOT / "test/golden/phase_13_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_13_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase13/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase13/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_13"


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


def verify_pins() -> tuple[Path, str]:
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    executables = {name: Path(pins[name]["path"]) for name in ("cabal", "ghc", "dhall")}
    for executable in executables.values():
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(run([str(executable), "--numeric-version"] if name != "dhall" else [str(executable), "--version"]).stdout for name, executable in executables.items())
    for family in executables:
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return executables["cabal"], versions


def verify_oracles() -> list[dict[str, str]]:
    corpus = read_tsv(CORPUS)
    mutants = read_tsv(MUTANTS)
    locus = read_tsv(LOCUS)
    if len(corpus) != 18 or len({row["deployment"] for row in corpus}) != 18:
        raise GateFailure("Phase-13 corpus must enumerate eighteen unique deployments")
    if {row["deployment"].rsplit("_", 1)[-1] for row in corpus} != {"singlenode", "distributed"}:
        raise GateFailure("Phase-13 corpus must cover both shapes")
    for row in corpus:
        golden = ROOT / row["golden"]
        try:
            summary = json.loads(golden.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as problem:
            raise GateFailure(f"invalid render golden {golden.relative_to(ROOT)}: {problem}") from problem
        if summary.get("objects") != int(row["objects"]) or not re.fullmatch(r"[0-9a-f]{64}", summary.get("sha256", "")):
            raise GateFailure(f"render golden metadata drifted: {golden.relative_to(ROOT)}")
        if not golden.read_bytes().endswith(b"\n"):
            raise GateFailure(f"render golden lacks its canonical trailing LF: {golden.relative_to(ROOT)}")
    if len(mutants) != 12 or len({row["mutant"] for row in mutants}) != 12:
        raise GateFailure("Phase-13 mutant manifest must contain twelve unique mutants")
    expected_locus = {
        *(row["deployment"] for row in corpus),
        "unsafe_workload",
        "backdoor_ingress",
        "underived_network_policy",
        *(row["mutant"] for row in mutants),
    }
    if len(locus) != len(expected_locus) or {row["entry"] for row in locus} != expected_locus:
        raise GateFailure("Phase-13 validation-locus ledger has incomplete or duplicate coverage")
    for row in mutants:
        descriptor = ROOT / f"tests/mutants/phase13/{row['mutant']}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {row['mutant']}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; live apiserver and runtime enforcement UNVERIFIED\n" + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Manifest.hs",
        ROOT / "src/Amoebius/Manifest/K8sObject.hs",
        ROOT / "src/Amoebius/Manifest/Types.hs",
        ROOT / "src/Amoebius/Manifest/Render.hs",
        ROOT / "src/Amoebius/Manifest/RenderAll.hs",
    ]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO)\b|!!")
    for path in paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial or unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")
    facade = paths[0].read_text(encoding="utf-8").split(") where", 1)[0]
    if "renderSourcePrivate" in facade or "K8sObject" in facade:
        raise GateFailure("manifest facade exports more than the whole-deployment render function")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8").split("test-suite render-golden", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in cabal:
            raise GateFailure(f"render-golden totality option missing: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run([str(cabal), "test", "render-golden", "--offline", "--test-show-details=direct"])
    token = "render-golden: PASS (18 byte-locked deployment goldens, 9 object variants, 3 non-vacuous safety predicates, 12 mutants, 1 covered property)"
    if token not in result.stdout or "each >=4%" not in result.stdout:
        raise GateFailure(f"Phase-13 acceptance or property token is absent:\n{result.stdout}")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [str(cabal), "test", "render-golden", "--offline", "--test-show-details=direct", f"--test-options=--mutant={name}"],
            require_success=False,
        )
        if result.returncode == 0 or f"phase13-mutant: RED {name}" not in result.stdout:
            raise GateFailure(f"mutant survived or missed its property locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "deployment-goldens": "18/18-byte-locked",
        "capability-shapes": "9/9-arms-times-2-shapes",
        "object-variant-coverage": "9/9-exact",
        "safety-predicates": "3/3-non-vacuous",
        "quickcheck-properties": "1/1-arms-and-shapes-at-least-4-percent",
        "mutants": f"{len(mutants)}/{len(mutants)}-red-at-property-locus",
        "acceptance-token": "rendered-output-proven-for-the-model",
        "live-apiserver-enforcement": "UNVERIFIED",
        "live-network-policy-enforcement": "UNVERIFIED",
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
    proven = {"pure-total-render-all", "sole-public-render-facade", "phase13-compile-totality"}
    unverified = {"live-apiserver-enforcement", "live-network-policy-enforcement", "runtime-model-correspondence"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 13,
        "gate_command": "python3 tools/phase13_gate.py",
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
        raise GateFailure("committed Phase-13 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
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
        mutants = verify_oracles()
        verify_totality_sources()
        suite = run_green_suite(cabal)
        mutant_log = verify_mutants(cabal, mutants)
        write_results(mutants)
        ledger_hash = verify_ledger()
        retain_evidence(suite, mutant_log, versions)
        print(suite, end="", flush=True)
        print(f"phase13-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase13-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
