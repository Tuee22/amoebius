#!/usr/bin/env python3
"""Phase 23: bounded C1-C7 predicates over composed extension declarations."""

from __future__ import annotations

import csv
import hashlib
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
RESULTS = ROOT / ".build/dsl/extension-composition-laws/phase-results.tsv"
ADDRESSES = ROOT / ".build/dsl/extension-composition-laws/addresses.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/extension-laws-compositional"
CONTRACT = "DEVELOPMENT_PLAN/phase_23_extension_laws_compositional.md"
GATE_COMMAND = "python3 tools/extension_laws_compositional_gate.py"
EXPECTATIONS = "test/oracle/extension_laws_compositional_surfaces.tsv"
CASES = ROOT / "test/oracle/extension_laws/composition_cases.tsv"
VERDICTS = ROOT / "test/oracle/extension_laws/composition_law_verdicts.tsv"
CATALOG = ROOT / "test/oracle/extension_laws/composition_mutation_catalog.tsv"
CAPABILITY = "extension_laws_compositional"
SUITE = "extension-laws-compositional-spec"
COMPILE_SUITE = "extension-laws-compositional-compile"

SIDES = ("toolchain", "source", "suite", "typed", "mutant", "oracle", "artifact")

CHECKS = {
    "shared-authority-scan": "production and pure fixtures have no process-global mutable authority",
    "composition-table-independent": "seven authored pairs state normalized parts and exact resource sums",
    "verdict-grid-independent": "two controls and seven defects state all 63 C-law verdicts",
    "content-address-independent": "Python recomputes all four observed SHA-256 addresses",
    "typed-scope-barrier": "same-request composition runs and cross-request composition has no type",
    "results-untracked": "generated observations remain beneath .build/**",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC satisfy authored ranges",
    "recorded-results-match-oracle": "all thirteen exact metrics match the contract",
}

EXPECTED_RESULTS = {
    "composition-cases": "7/7-exact",
    "pair-law-verdicts": "49/49-green",
    "subject-verdicts": "63/63-authored",
    "lawful-controls": "14/14-green",
    "identity-equalities": "14/14-by-value",
    "associativity-equalities": "7/7-by-value",
    "budget-folds": "7/7-exact-additive",
    "address-controls": "distinct-and-shared-green/collision-red",
    "mutants": "7/7-red-exactly",
    "typed-scope": "same-request-green/cross-request-red",
    "source-scans": "pure-no-shared-authority/2-mutant-controls-red",
    "independent-addresses": "4/4-sha256",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "composition-case-corpus": ("composition-cases", EXPECTED_RESULTS["composition-cases"]),
    "pair-law-grid": ("pair-law-verdicts", EXPECTED_RESULTS["pair-law-verdicts"]),
    "authored-subject-grid": ("subject-verdicts", EXPECTED_RESULTS["subject-verdicts"]),
    "lawful-address-controls": ("lawful-controls", EXPECTED_RESULTS["lawful-controls"]),
    "identity-by-value": ("identity-equalities", EXPECTED_RESULTS["identity-equalities"]),
    "associativity-by-value": ("associativity-equalities", EXPECTED_RESULTS["associativity-equalities"]),
    "budget-additivity-folds": ("budget-folds", EXPECTED_RESULTS["budget-folds"]),
    "address-behavior": ("address-controls", EXPECTED_RESULTS["address-controls"]),
    "exact-mutant-loci": ("mutants", EXPECTED_RESULTS["mutants"]),
    "typed-request-scope": ("typed-scope", EXPECTED_RESULTS["typed-scope"]),
    "shared-authority-scans": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "independent-address-recomputation": ("independent-addresses", EXPECTED_RESULTS["independent-addresses"]),
    "runtime-correspondence": None,
    "pure-shared-authority-boundary": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "authored-composition-table": ("composition-cases", EXPECTED_RESULTS["composition-cases"]),
    "authored-verdict-grid": ("subject-verdicts", EXPECTED_RESULTS["subject-verdicts"]),
    "python-content-address": ("independent-addresses", EXPECTED_RESULTS["independent-addresses"]),
    "same-request-compiler-barrier": ("typed-scope", EXPECTED_RESULTS["typed-scope"]),
    "c1-closure-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "c2-identity-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "c3-associativity-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "c4-interference-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "c5-budget-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "c6-scope-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "c7-address-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
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
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-12000:]}")
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
    print("\nsource side — closed composite value and no shared authority in the pure core\n")
    production = (ROOT / "src/extension-laws-compositional/Amoebius/Extension/Laws/Compositional.hs").read_text(encoding="utf-8")
    fixture = (ROOT / "test/harness/extension_laws/CompositionFixtures.hs").read_text(encoding="utf-8")
    mutant = (ROOT / "test/mutant/extension_laws/ExtensionCompositionMutants.hs").read_text(encoding="utf-8")
    forbidden = ("IORef", "unsafePerformIO", "System.Environment", "setEnv", "getEnv", "getCurrentTime", "listDirectory")
    escaped = [token for token in forbidden if token in production or token in fixture]
    required = (
        "newtype CompositeDeclaration", "composeComposites", "sortOn declarationKey",
        "unionVocabulary", "addResources", "evaluateCompositionLaws", "contentAddress",
    )
    missing = [token for token in required if token not in production]
    controls = "IORef" in mutant and "unsafePerformIO" in mutant
    green = not escaped and not missing and controls
    print(f"  {'ok  ' if green else 'FAIL'}  shared-authority-scan forbidden={escaped} missing={missing} controls={controls}")
    return green


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
        "metric\tresult\n" + "".join(f"{key}\t{rows[key]}\n" for key in EXPECTED_RESULTS if key in rows),
        encoding="utf-8",
    )


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str], str]:
    print("\nsuite side — seven composition cases and 63 authored C-law verdicts\n")
    try:
        result = run(cabal_command(resolved, "test", SUITE, COMPILE_SUITE, "--test-show-details=direct"))
        listing = run(cabal_command(resolved, "list-bin", SUITE))
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  compositional-law suite; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}, ""
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    tokens = (
        "extension-laws-compositional-spec: PASS (7 composition cases, 63 authored verdicts, 7 exact mutants)",
        "extension-laws-compositional-compile: PASS same-request pair",
    )
    green = all(token in result.stdout for token in tokens)
    print(f"  {'ok  ' if green else 'FAIL'}  composition suite and same-request compile twin green")
    binary = listing.stdout.strip().splitlines()[-1] if green else ""
    return green, read_results() if green else {}, binary


def compile_negative(resolved: dict[str, Any]) -> subprocess.CompletedProcess[str]:
    output = BUILD_ROOT / "compile-negative"
    output.mkdir(parents=True, exist_ok=True)
    return run(
        cabal_command(
            resolved,
            "exec", "--", resolved["ghc"]["path"], "-fno-code", "-fforce-recomp",
            "-XGHC2024", "-XCPP", "-isrc/extension-laws-compositional", "-isrc/extension-laws",
            "-isrc/extension-declaration", "-isrc/calculus-composition", "-isrc",
            f"-outputdir={output}", "-package", "base", "-package", "bytestring", "-package", "containers",
            "-package", "text",
            "-DEXTENSION_LAWS_COMPOSITIONAL_TEST_CROSS_SCOPE",
            "test/negative/compile_fail/extension_laws_compositional/CompositionScopeCompile.hs",
        ),
        require_success=False,
    )


def typed_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\ntyped side — declarations from different requests cannot compose\n")
    result = compile_negative(resolved)
    (run_dir / "cross-request.log").write_text(result.stdout, encoding="utf-8")
    tokens = ("GHC-25897", "Couldn't match type", "CompositeDeclaration", "singletonComposite right")
    green = result.returncode != 0 and all(token in result.stdout for token in tokens)
    print(f"  {'ok  ' if green else 'FAIL'}  typed-scope-barrier cross-request pair rejected at scope equality")
    return green


def mutation_catalog() -> list[dict[str, str]]:
    with CATALOG.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def mutant_side(binary: str, run_dir: Path) -> bool:
    print("\nmutant side — seven defects redden their exact C-law loci\n")
    catalog = mutation_catalog()
    registry = mutant_registry.capability(CAPABILITY)
    expected = {row["mutant"]: row["red_property"] for row in catalog}
    if len(expected) != 7 or {row["mutant"] for row in registry} != set(expected):
        print("  FAIL  mutation catalogue and registry do not name the same seven mutants")
        return False
    ok = True
    for mutant, property_name in expected.items():
        result = run([binary, f"--mutant={mutant}"], require_success=False)
        (run_dir / f"mutant-{mutant}.log").write_text(result.stdout, encoding="utf-8")
        token = f"extension-composition-mutant: RED {mutant} {property_name}"
        red = result.returncode != 0 and token in result.stdout
        print(f"  {'ok  ' if red else 'FAIL'}  {mutant:<29} reddens {property_name}")
        ok = ok and red
    return ok


def table_oracle() -> bool:
    with CASES.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    resources = {
        "none": (0, 0, 0, 0),
        "infernix": (4, 1792, 26, 3),
        "jitml": (7, 3584, 52, 3),
    }
    names = {"none": [], "infernix": ["infernix"], "jitml": ["jitml"]}
    green = len(rows) == 7
    for row in rows:
        left = resources.get(row["left"])
        right = resources.get(row["right"])
        if left is None or right is None or row["third"] not in resources:
            green = False
            continue
        expected_resource = tuple(a + b for a, b in zip(left, right))
        actual_resource = tuple(int(row[key]) for key in ("cpu", "memory", "ephemeral", "pods"))
        expected_parts = sorted(names[row["left"]] + names[row["right"]])
        actual_parts = [] if row["parts"] == "-" else row["parts"].split(",")
        green = green and actual_resource == expected_resource and actual_parts == expected_parts
    return green


def verdict_oracle() -> bool:
    with VERDICTS.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    catalog = mutation_catalog()
    indexed = {row["subject"]: row for row in rows}
    laws = [f"C{number}" for number in range(1, 8)]
    lawful = [row for row in rows if all(row[law] == "PASS" for law in laws)]
    green = len(rows) == 9 and len(lawful) == 2
    for mutant in catalog:
        row = indexed.get(mutant["subject"])
        actual = [law for law in laws if row is not None and row[law] != "PASS"]
        green = green and actual == mutant["red_laws"].split(",")
    return green and set(laws) <= {law for row in rows for law in laws if row[law] != "PASS"}


def address_oracle() -> bool:
    if not ADDRESSES.is_file():
        return False
    with ADDRESSES.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    green = len(rows) == 4
    for row in rows:
        green = green and hashlib.sha256(row["content"].encode()).hexdigest() == row["address"]
    variants = {name: [row for row in rows if row["variant"] == name] for name in ("distinct", "shared")}
    green = green and all(len(values) == 2 for values in variants.values())
    if green:
        green = (
            variants["distinct"][0]["address"] != variants["distinct"][1]["address"]
            and variants["shared"][0]["address"] == variants["shared"][1]["address"]
            and variants["shared"][0]["content"] == variants["shared"][1]["content"]
        )
    return green


def independent_side() -> bool:
    print("\nindependent oracle — authored pair/verdict shapes and Python SHA-256\n")
    try:
        table = table_oracle()
        verdicts = verdict_oracle()
        addresses = address_oracle()
    except (OSError, KeyError, ValueError) as error:
        print(f"  FAIL  independent oracle {error}")
        return False
    print(f"  {'ok  ' if table else 'FAIL'}  composition-table-independent seven exact additive pairs")
    print(f"  {'ok  ' if verdicts else 'FAIL'}  verdict-grid-independent two controls plus seven exact defects")
    print(f"  {'ok  ' if addresses else 'FAIL'}  content-address-independent four SHA-256 recomputations")
    return table and verdicts and addresses


def oracle_side(rows: dict[str, str]) -> bool:
    print("\noracle side — complete results against thirteen exact metrics\n")
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
    for path in (RESULTS, ADDRESSES):
        relative = gate_common.rel(path)
        clean = path.is_file() and relative.startswith(".build/") and relative not in snapshot
        print(f"  {'ok  ' if clean else 'FAIL'}  results-untracked {relative}")
        ok = ok and clean
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=22,
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
        results["typed"] = typed_side(resolved, gate.run_dir)
        results["mutant"] = mutant_side(binary, gate.run_dir)
        independent = independent_side()
        if results["source"]:
            rows["source-scans"] = EXPECTED_RESULTS["source-scans"]
        if results["typed"]:
            rows["typed-scope"] = EXPECTED_RESULTS["typed-scope"]
        if results["mutant"]:
            rows["mutants"] = EXPECTED_RESULTS["mutants"]
        if independent and address_oracle():
            rows["independent-addresses"] = EXPECTED_RESULTS["independent-addresses"]
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
        for key in ("pair-law-verdicts", "subject-verdicts", "mutants", "typed-scope", "source-scans")
    )
    layers = {
        "Decision": "tested" if laws_green else "UNVERIFIED",
        "Protocol": "tested" if rows.get("budget-folds") == EXPECTED_RESULTS["budget-folds"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={SUITE: "cabal test", COMPILE_SUITE: "GHC same/cross-request twins"},
        checks=results,
        mutants=[{"name": row["mutant"], "status": row["red_property"]} for row in mutation_catalog()],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "addresses": "sha256:" + artifact_policy.digest(str(ADDRESSES)),
        }
        if RESULTS.is_file() and ADDRESSES.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
