#!/usr/bin/env python3
"""Phase 22: mechanical L1-L5 predicates over one extension declaration."""

from __future__ import annotations

import csv
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / ".build/dsl/extension-laws/phase-results.tsv"
COMPILE_RESULTS = ROOT / ".build/checkers/extension-laws/compile-fail.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/extension-laws"
CONTRACT = "DEVELOPMENT_PLAN/phase_22_extension_laws_per_extension.md"
GATE_COMMAND = "python3 tools/extension_laws_per_extension_gate.py"
EXPECTATIONS = "test/oracle/extension_laws_per_extension_surfaces.tsv"
VERDICTS = ROOT / "test/oracle/extension_laws/law_verdicts.tsv"
OPERATIONS = ROOT / "test/oracle/extension_laws/operation_cases.tsv"
CATALOG = ROOT / "test/oracle/extension_laws/mutation_catalog.tsv"
MANIFEST = ROOT / "test/oracle/compile_fail_harness/fixtures.tsv"
CAPABILITY = "extension_laws_per_extension"
SUITE = "extension-laws-per-extension-spec"

SIDES = ("toolchain", "source", "suite", "compile-fail", "mutant", "oracle", "artifact")

CHECKS = {
    "totality-scan": "the pure law fixture has no partial token or wildcard dispatch arm",
    "ambient-scan": "the pure law fixture has no known ambient observation primitive",
    "verdict-oracle-independent": "seven authored subjects decide all 35 L1-L5 verdicts",
    "compile-harness-reused": "Phase 16 pins claim-without-fixture to its exact GHC reason",
    "results-untracked": "generated observations remain beneath .build/**",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC satisfy authored ranges",
    "recorded-results-match-oracle": "all twelve exact metrics match the contract",
}

EXPECTED_RESULTS = {
    "subjects": "7/7-exact",
    "law-verdicts": "35/35-authored",
    "lawful-verdicts": "10/10-green",
    "single-law-defects": "5/5-exact",
    "generated-operation-inputs": "6/6-total",
    "independent-process-renders": "2/2-byte-identical",
    "budget-protocols": "2/2-refuse-before-materialization-with-reaper",
    "evidence-values": "2/2-claim-fixture-bound",
    "source-scans": "pure-green/2-mutant-tokens-red",
    "compile-fixture": "claim-names-fixture-positive-green/negative-pinned-red",
    "mutants": "5/5-red-exactly",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "law-subject-corpus": ("subjects", EXPECTED_RESULTS["subjects"]),
    "five-law-verdict-grid": ("law-verdicts", EXPECTED_RESULTS["law-verdicts"]),
    "lawful-controls": ("lawful-verdicts", EXPECTED_RESULTS["lawful-verdicts"]),
    "single-law-negatives": ("single-law-defects", EXPECTED_RESULTS["single-law-defects"]),
    "generated-totality-inputs": ("generated-operation-inputs", EXPECTED_RESULTS["generated-operation-inputs"]),
    "independent-process-determinism": ("independent-process-renders", EXPECTED_RESULTS["independent-process-renders"]),
    "actual-budget-protocol": ("budget-protocols", EXPECTED_RESULTS["budget-protocols"]),
    "actual-evidence-values": ("evidence-values", EXPECTED_RESULTS["evidence-values"]),
    "pure-source-scans": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "l5-compile-fixture": ("compile-fixture", EXPECTED_RESULTS["compile-fixture"]),
    "exact-mutant-loci": ("mutants", EXPECTED_RESULTS["mutants"]),
    "runtime-correspondence": None,
    "totality-source-boundary": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "ambient-source-boundary": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "authored-verdict-oracle": ("law-verdicts", EXPECTED_RESULTS["law-verdicts"]),
    "phase15-harness-reuse": ("compile-fixture", EXPECTED_RESULTS["compile-fixture"]),
    "l1-partial-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "l2-ambient-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "l3-reaper-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "l4-scope-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "l5-fixture-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
}


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
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
        raise GateFailure(
            f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-12000:]}"
        )
    return result


def cabal_command(resolved: dict[str, Any], *arguments: str) -> list[str]:
    return [
        resolved["cabal"]["path"],
        f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
        "--jobs=1",
        *arguments,
    ]


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — compiler and build driver from authored requirements\n")
    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("ghc", "cabal"):
        record = resolved[name]
        print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
    return True, resolved


def source_side() -> bool:
    print("\nsource side — total pure fixture and ambient-source boundary\n")
    production = (ROOT / "src/extension-laws/Amoebius/Extension/Laws/PerExtension.hs").read_text(encoding="utf-8")
    fixture = (ROOT / "test/harness/extension_laws/LawFixtures.hs").read_text(encoding="utf-8")
    mutant = (ROOT / "test/mutant/extension_laws/ExtensionLawMutants.hs").read_text(encoding="utf-8")
    partial_tokens = ("undefined", "error ", "fromJust", "unsafePerformIO")
    ambient_tokens = (
        "System.Environment", "lookupEnv", "getCurrentTime", "System.Random", "listDirectory", "getDirectoryContents"
    )
    partial = [token for token in partial_tokens if token in fixture]
    wildcards = re.findall(r"\b_\s*->", fixture)
    ambient = [token for token in ambient_tokens if token in fixture]
    required = ("evaluateLaws", "l1Failures", "l2Failures", "l3Failures", "l4Failures", "l5Failures")
    missing = [token for token in required if token not in production]
    mutant_controls = "error \"partial extension operation\"" in mutant and "lookupEnv" in mutant
    if partial or wildcards or ambient or missing or not mutant_controls:
        print(
            "  FAIL  totality/ambient scan "
            f"partial={partial} wildcards={len(wildcards)} ambient={ambient} missing={missing} mutant_controls={mutant_controls}"
        )
        return False
    print("  ok    totality-scan pure fixture has no partial token or wildcard dispatch")
    print("  ok    ambient-scan pure fixture has no known clock/random/env/directory observation")
    print("  ok    scanner controls contain the exact partial and ambient tokens")
    return True


def read_results() -> dict[str, str]:
    if not RESULTS.is_file():
        return {}
    rows: dict[str, str] = {}
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, separator, value = line.partition("\t")
        if separator:
            rows[key] = value
    return rows


def write_results(rows: dict[str, str]) -> None:
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n"
        + "".join(f"{key}\t{rows[key]}\n" for key in EXPECTED_RESULTS if key in rows),
        encoding="utf-8",
    )


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str], str]:
    print("\nsuite side — 35 L1-L5 verdicts over two declarations and five one-defect subjects\n")
    try:
        result = run(cabal_command(resolved, "test", SUITE, "--test-show-details=direct"))
        listing = run(cabal_command(resolved, "list-bin", SUITE))
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  per-extension law suite; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}, ""
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    token = "extension-laws-per-extension-spec: PASS (7 subjects, 35 verdicts, 6 generated inputs, 5 single-law defects)"
    if token not in result.stdout:
        print("  FAIL  per-extension law acceptance token absent")
        return False, {}, ""
    binary = listing.stdout.strip().splitlines()[-1]
    rows = read_results()
    print("  ok    seven subjects match all 35 authored law verdicts")
    print("  ok    actual budget/evidence values and independent process renders observed")
    return True, rows, binary


def compile_fail_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\ncompile-fail side — L5 reuses the Phase-16 pinned fixture harness\n")
    COMPILE_RESULTS.parent.mkdir(parents=True, exist_ok=True)
    result = run(
        [
            sys.executable,
            "tools/compile_fail_harness.py",
            "--ghc",
            resolved["ghc"]["path"],
            "--results",
            str(COMPILE_RESULTS),
        ],
        require_success=False,
    )
    (run_dir / "compile-fail.log").write_text(result.stdout, encoding="utf-8")
    with MANIFEST.open(encoding="utf-8", newline="") as handle:
        manifest = list(csv.DictReader(handle, delimiter="\t"))
    target = [row for row in manifest if row["claim"] == "claim-names-fixture"]
    green = (
        result.returncode == 0
        and "compile-fail-harness: PASS (10 legal/illegal twins" in result.stdout
        and len(target) == 1
        and target[0]["code"] == "83865"
        and target[0]["message_fragments"] == "claim;;applied to too few arguments"
    )
    print(f"  {'ok  ' if green else 'FAIL'}  claim-names-fixture positive green; negative pinned to GHC-83865 and fixture arity")
    return green


def mutation_catalog() -> list[dict[str, str]]:
    with CATALOG.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def mutant_side(binary: str, run_dir: Path) -> bool:
    print("\nmutant side — one independently observed defect per L-law\n")
    catalog = mutation_catalog()
    registry = mutant_registry.capability(CAPABILITY)
    expected = {row["mutant"]: row["red_property"] for row in catalog}
    if len(expected) != 5 or {row["mutant"] for row in registry} != set(expected):
        print("  FAIL  mutation catalogue and one registry do not name the same five mutants")
        return False
    ok = True
    for mutant, property_name in expected.items():
        result = run([binary, f"--mutant={mutant}"], require_success=False)
        (run_dir / f"mutant-{mutant}.log").write_text(result.stdout, encoding="utf-8")
        token = f"extension-laws-mutant: RED {mutant} {property_name}"
        red = result.returncode != 0 and token in result.stdout
        print(f"  {'ok  ' if red else 'FAIL'}  {mutant:<27} reddens {property_name}")
        ok = ok and red
    return ok


def verdict_oracle_side() -> bool:
    print("\nindependent oracle — authored law matrix shape and single-defect separation\n")
    try:
        with VERDICTS.open(encoding="utf-8", newline="") as handle:
            verdicts = list(csv.DictReader(handle, delimiter="\t"))
        with OPERATIONS.open(encoding="utf-8", newline="") as handle:
            operations = list(csv.DictReader(handle, delimiter="\t"))
    except OSError as error:
        print(f"  FAIL  verdict-oracle-independent {error}")
        return False
    laws = ["L1", "L2", "L3", "L4", "L5"]
    lawful = [row for row in verdicts if all(row[law] == "PASS" for law in laws)]
    defective = [row for row in verdicts if sum(row[law] != "PASS" for law in laws) == 1]
    operation_domain = {(row["extension"], row["input"]) for row in operations}
    green = (
        len(verdicts) == 7
        and len(lawful) == 2
        and len(defective) == 5
        and {next(law for law in laws if row[law] != "PASS") for row in defective} == set(laws)
        and len(operations) == 6
        and len(operation_domain) == 6
        and {row["extension"] for row in operations} == {"infernix", "jitml"}
    )
    print(f"  {'ok  ' if green else 'FAIL'}  verdict-oracle-independent 2 lawful + five one-law defects; six distinct inputs")
    return green


def oracle_side(rows: dict[str, str]) -> bool:
    print("\noracle side — complete results against twelve exact metrics\n")
    ok = True
    for key, expected in EXPECTED_RESULTS.items():
        actual = rows.get(key)
        if actual != expected:
            print(f"  FAIL  recorded-results-match-oracle {key}: {actual!r} != {expected!r}")
            ok = False
    extras = sorted(set(rows) - set(EXPECTED_RESULTS))
    if extras:
        print(f"  FAIL  recorded-results-match-oracle unexpected metric(s): {', '.join(extras)}")
        ok = False
    if ok:
        print(f"  ok    recorded-results-match-oracle all {len(EXPECTED_RESULTS)} metrics match")
    return ok


def artifact_side() -> bool:
    print("\nartifact side — generated observations remain project-contained\n")
    snapshot = set(artifact_policy.snapshot_paths())
    ok = True
    for path in (RESULTS, COMPILE_RESULTS):
        relative = gate_common.rel(path)
        clean = path.is_file() and relative.startswith(".build/") and relative not in snapshot
        print(f"  {'ok  ' if clean else 'FAIL'}  results-untracked {relative}")
        ok = ok and clean
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=21,
        contract=CONTRACT,
        command=GATE_COMMAND,
        expectations=EXPECTATIONS,
        register="1",
        substrate="none",
        lane="none",
        sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    results["toolchain"], resolved = toolchain_side()
    rows: dict[str, str] = {}
    binary = ""
    if results["toolchain"]:
        results["source"] = source_side()
        results["suite"], rows, binary = suite_side(resolved, gate.run_dir)
    if results["suite"]:
        results["compile-fail"] = compile_fail_side(resolved, gate.run_dir)
        results["mutant"] = mutant_side(binary, gate.run_dir)
        independent = verdict_oracle_side()
        if results["source"]:
            rows["source-scans"] = "pure-green/2-mutant-tokens-red"
        if results["compile-fail"]:
            rows["compile-fixture"] = "claim-names-fixture-positive-green/negative-pinned-red"
        if results["mutant"]:
            rows["mutants"] = "5/5-red-exactly"
        write_results(rows)
        results["oracle"] = independent and oracle_side(rows)
        results["artifact"] = artifact_side()

    implemented = {
        "metrics": set(rows),
        "checks": set(CHECKS),
        "mutants": {row["mutant"] for row in mutant_registry.capability(CAPABILITY)},
    }
    results["surface"], surfaces = gate.surface_join(implemented)
    status: dict[str, bool] = {}
    for surface in surfaces:
        evidence = SURFACE_EVIDENCE.get(surface)
        status[surface] = bool(evidence) and rows.get(evidence[0]) == evidence[1]
    status["generated-artifact-discipline"] = results["artifact"]

    laws_green = all(
        rows.get(key) == EXPECTED_RESULTS[key]
        for key in ("subjects", "law-verdicts", "lawful-verdicts", "single-law-defects", "source-scans", "compile-fixture")
    )
    layers = {
        "Decision": "tested" if laws_green else "UNVERIFIED",
        "Protocol": "tested" if rows.get("budget-protocols") == EXPECTED_RESULTS["budget-protocols"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={SUITE: "cabal test", "compile-fail-harness": "GHC structured diagnostics"},
        checks=results,
        mutants=[
            {"name": row["mutant"], "status": row["red_property"]}
            for row in mutation_catalog()
        ],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "compile-fail": "sha256:" + artifact_policy.digest(str(COMPILE_RESULTS)),
        }
        if RESULTS.is_file() and COMPILE_RESULTS.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
