#!/usr/bin/env python3
"""Phase 21: the complete five-calculus extension declaration value."""

from __future__ import annotations

import csv
import hashlib
import os
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
RESULTS = ROOT / ".build/dsl/extension-declaration/phase-results.tsv"
ACTUAL = ROOT / ".build/dsl/extension-declaration/actual-declarations.tsv"
INVENTORY = ROOT / "test/oracle/extension_declaration/inventory.tsv"
CATALOG = ROOT / "test/oracle/extension_declaration/mutation_catalog.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/extension-declaration"
CONTRACT = "DEVELOPMENT_PLAN/phase_21_extension_declaration.md"
GATE_COMMAND = "python3 tools/extension_declaration_gate.py"
EXPECTATIONS = "test/oracle/extension_declaration_surfaces.tsv"
CAPABILITY = "extension_declaration"
SUITE = "extension-declaration-spec"
COMPILE_SUITE = "extension-declaration-compile"

SIDES = ("toolchain", "source", "suite", "typed", "mutant", "oracle", "artifact")

CHECKS = {
    "declaration-source-pure": "the declaration has no ambient or effectful observation",
    "constructor-private-and-total": "only the checked five-component constructor is public",
    "inventory-independent": "two authored five-row declarations match the actual readers",
    "digest-independently-recomputed": "Python recomputes both canonical SHA-256 identities",
    "results-untracked": "generated observations remain below .build/**",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC satisfy authored ranges",
    "recorded-results-match-oracle": "all ten exact metrics match the contract",
}

EXPECTED_RESULTS = {
    "declarations": "2/2-concrete",
    "components": "10/10-mandatory",
    "calculus-slots": "2x5-exact-and-ordered",
    "reader-sets": "10/10-match-independent-inventory",
    "resource-folds": "2/2-exact-natural-sums",
    "digests": "2/2-independent-sha256",
    "semantic-refusals": "2/2-exact",
    "compile-barriers": "2/2-positive-green-negative-type-red",
    "mutants": "3/3-red-exactly",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "two-concrete-declarations": ("declarations", EXPECTED_RESULTS["declarations"]),
    "five-mandatory-components": ("components", EXPECTED_RESULTS["components"]),
    "closed-calculus-slots": ("calculus-slots", EXPECTED_RESULTS["calculus-slots"]),
    "calculus-specific-readers": ("reader-sets", EXPECTED_RESULTS["reader-sets"]),
    "exact-resource-folds": ("resource-folds", EXPECTED_RESULTS["resource-folds"]),
    "content-derived-identity": ("digests", EXPECTED_RESULTS["digests"]),
    "semantic-refusals": ("semantic-refusals", EXPECTED_RESULTS["semantic-refusals"]),
    "compile-time-barriers": ("compile-barriers", EXPECTED_RESULTS["compile-barriers"]),
    "exact-mutant-loci": ("mutants", EXPECTED_RESULTS["mutants"]),
    "runtime-correspondence": None,
    "pure-declaration-boundary": ("declarations", EXPECTED_RESULTS["declarations"]),
    "private-total-constructor": ("components", EXPECTED_RESULTS["components"]),
    "independent-inventory": ("reader-sets", EXPECTED_RESULTS["reader-sets"]),
    "independent-digest": ("digests", EXPECTED_RESULTS["digests"]),
    "optional-component-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "scope-index-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "recipe-omission-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
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


def cabal_command(
    resolved: dict[str, Any], *arguments: str, build_root: Path = BUILD_ROOT
) -> list[str]:
    return [
        resolved["cabal"]["path"],
        f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={build_root}",
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
    print("\nsource side — private, pure, index-preserving declaration boundary\n")
    source = (ROOT / "src/extension-declaration/Amoebius/Extension/Declaration.hs").read_text(encoding="utf-8")
    required = (
        "data ExtensionDeclaration scope",
        "UnexpectedCalculus",
        "declarationArtifactSet",
        "declarationBudgetSet",
        "declarationLiftSet",
        "declarationWorkflowSet",
        "declarationEvidenceSet",
        "SHA256.hash",
        "Builder.word64BE",
    )
    missing = [token for token in required if token not in source]
    forbidden = [token for token in ("System.Environment", "System.Directory", ":: IO ") if token in source]
    header = source.split(") where", 1)[0]
    if missing or forbidden:
        print(f"  FAIL  declaration-source-pure missing={missing} forbidden={forbidden}")
        return False
    if "ExtensionDeclaration (..)" in header or "ExtensionDeclaration(..)" in header:
        print("  FAIL  constructor-private-and-total exports ExtensionDeclaration's constructor")
        return False
    if source.count("-> Component scope") < 5:
        print("  FAIL  constructor-private-and-total normal constructor does not require five indexed components")
        return False
    print("  ok    declaration-source-pure no ambient/effectful observation surface")
    print("  ok    constructor-private-and-total constructor private; five checked slots explicit")
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


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nsuite side — two declarations against the authored ten-row inventory\n")
    try:
        result = run(
            cabal_command(
                resolved,
                "test",
                SUITE,
                COMPILE_SUITE,
                "--test-show-details=direct",
            )
        )
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  declaration suites; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    token = "extension-declaration-spec: PASS (2 declarations, 10 components, 5 readers, 2 exact refusals)"
    legal = "extension-declaration-compile: PASS legal five-component same-scope twin"
    if token not in result.stdout or legal not in result.stdout:
        print("  FAIL  declaration suite or legal compile-twin acceptance token absent")
        return False, {}
    rows = read_results()
    print("  ok    extension-declaration-spec green; authored inventory matched")
    print("  ok    legal five-component same-scope compile twin green")
    return True, rows


def compile_negative(
    resolved: dict[str, Any], define: str
) -> subprocess.CompletedProcess[str]:
    output = BUILD_ROOT / "compile-negative"
    output.mkdir(parents=True, exist_ok=True)
    return run(
        cabal_command(
            resolved,
            "exec",
            "--",
            resolved["ghc"]["path"],
            "-fno-code",
            "-fforce-recomp",
            "-XGHC2024",
            "-XCPP",
            "-isrc/extension-declaration",
            "-isrc/calculus-composition",
            "-isrc",
            f"-outputdir={output}",
            "-package",
            "base",
            "-package",
            "bytestring",
            "-package",
            "containers",
            "-package",
            "deepseq",
            "-package",
            "text",
            f"-D{define}",
            "test/negative/compile_fail/extension_declaration/DeclarationCompile.hs",
        ),
        require_success=False,
    )


def typed_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\ntyped side — missing component and cross-request declarations have no type\n")
    optional = compile_negative(resolved, "EXTENSION_DECLARATION_TEST_OPTIONAL_COMPONENT")
    cross = compile_negative(resolved, "EXTENSION_DECLARATION_TEST_CROSS_SCOPE")
    (run_dir / "missing-component.log").write_text(optional.stdout, encoding="utf-8")
    (run_dir / "cross-scope.log").write_text(cross.stdout, encoding="utf-8")
    optional_tokens = ("applied to too few arguments", "ExtensionDeclaration scope", "declareExtension")
    cross_tokens = ("Couldn't match type", "budgetComponent", "RequestScope")
    optional_red = optional.returncode != 0 and all(token in optional.stdout for token in optional_tokens)
    cross_red = cross.returncode != 0 and all(token in cross.stdout for token in cross_tokens)
    print(f"  {'ok  ' if optional_red else 'FAIL'}  missing component rejected at constructor arity")
    print(f"  {'ok  ' if cross_red else 'FAIL'}  cross-request components rejected at scope equality")
    return optional_red and cross_red


def mutation_catalog() -> list[dict[str, str]]:
    with CATALOG.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def mutant_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\nmutant side — optional field, scope erasure, and artifact omission\n")
    catalog = mutation_catalog()
    registry = mutant_registry.capability(CAPABILITY)
    expected = {row["mutant"]: row["red_property"] for row in catalog}
    if len(expected) != 3 or {row["mutant"] for row in registry} != set(expected):
        print("  FAIL  mutation catalogue and one registry do not name the same three mutants")
        return False
    outcomes: dict[str, subprocess.CompletedProcess[str]] = {}
    for mutant, flag in (
        ("optional-component", "extension-declaration-optional-component-mutant"),
        ("drop-scope-index", "extension-declaration-drops-scope-index-mutant"),
    ):
        outcomes[mutant] = run(
            cabal_command(
                resolved,
                "test",
                COMPILE_SUITE,
                f"--flags={flag}",
                "--test-show-details=direct",
                build_root=ROOT / f".build/dist-newstyle/extension-declaration-{mutant}",
            ),
            require_success=False,
        )
    outcomes["omit-declared-recipe"] = run(
        cabal_command(
            resolved,
            "test",
            SUITE,
            "--test-show-details=direct",
            "--test-options=--mutant=omit-declared-recipe",
        ),
        require_success=False,
    )
    ok = True
    for mutant, property_name in expected.items():
        outcome = outcomes[mutant]
        (run_dir / f"mutant-{mutant}.log").write_text(outcome.stdout, encoding="utf-8")
        token = f"extension-declaration-mutant: RED {mutant} {property_name}"
        if mutant == "omit-declared-recipe":
            red = outcome.returncode != 0 and token in outcome.stdout
        else:
            red = outcome.returncode == 0 and token in outcome.stdout
        print(f"  {'ok  ' if red else 'FAIL'}  {mutant:<24} reddens {property_name}")
        ok = ok and red
    return ok


def inventory_rows(path: Path, *, actual: bool) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    expected_fields = {
        "extension", "calculus", "component", "cpu", "memory", "ephemeral", "pods", "descriptor", "identity"
    }
    if not rows or not expected_fields.issubset(rows[0]):
        raise GateFailure(f"{gate_common.rel(path)} has the wrong inventory schema")
    if actual and "digest" not in rows[0]:
        raise GateFailure("actual declaration observation has no digest")
    return rows


def framed(parts: list[bytes]) -> bytes:
    return b"".join(len(part).to_bytes(8, "big") + part for part in parts)


def independent_digest(name: str, rows: list[dict[str, str]]) -> str:
    order = {name: index for index, name in enumerate(("artifact", "budget", "lift", "workflow", "evidence"))}
    parts = [b"amoebius-extension-declaration-v1", name.encode()]
    for row in sorted(rows, key=lambda value: order[value["calculus"]]):
        parts.extend(
            row[field].encode()
            for field in ("calculus", "component", "cpu", "memory", "ephemeral", "pods")
        )
        parts.extend(field.encode() for field in row["identity"].split("|"))
    return hashlib.sha256(framed(parts)).hexdigest()


def independent_side(rows: dict[str, str]) -> bool:
    print("\nindependent oracle — authored inventory and separately recomputed digest\n")
    try:
        expected = inventory_rows(INVENTORY, actual=False)
        actual = inventory_rows(ACTUAL, actual=True)
    except (OSError, GateFailure) as error:
        print(f"  FAIL  inventory-independent {error}")
        return False
    semantic_fields = ("extension", "calculus", "component", "cpu", "memory", "ephemeral", "pods", "descriptor", "identity")
    expected_semantics = sorted(tuple(row[field] for field in semantic_fields) for row in expected)
    actual_semantics = sorted(tuple(row[field] for field in semantic_fields) for row in actual)
    if expected_semantics != actual_semantics:
        print("  FAIL  inventory-independent actual reader inventory differs from authored rows")
        return False
    ok = True
    for name in sorted({row["extension"] for row in expected}):
        expected_rows = [row for row in expected if row["extension"] == name]
        actual_rows = [row for row in actual if row["extension"] == name]
        digests = {row["digest"] for row in actual_rows}
        wanted = independent_digest(name, expected_rows)
        if digests != {wanted}:
            print(f"  FAIL  digest-independently-recomputed {name}: {digests} != {wanted}")
            ok = False
        else:
            print(f"  ok    {name:<10} {wanted[:16]}… from authored semantic rows")
    if ok:
        rows["digests"] = "2/2-independent-sha256"
        print("  ok    inventory-independent all ten semantic rows match")
    return ok


def oracle_side(rows: dict[str, str]) -> bool:
    print("\noracle side — complete results against ten exact metrics\n")
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
    for path in (RESULTS, ACTUAL):
        relative = gate_common.rel(path)
        clean = path.is_file() and relative.startswith(".build/") and relative not in snapshot
        print(f"  {'ok  ' if clean else 'FAIL'}  results-untracked {relative}")
        ok = ok and clean
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=20,
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
    if results["toolchain"]:
        results["source"] = source_side()
        results["suite"], rows = suite_side(resolved, gate.run_dir)
    if results["suite"]:
        results["typed"] = typed_side(resolved, gate.run_dir)
        results["mutant"] = mutant_side(resolved, gate.run_dir)
        digest_green = independent_side(rows)
        if results["typed"]:
            rows["compile-barriers"] = "2/2-positive-green-negative-type-red"
        if results["mutant"]:
            rows["mutants"] = "3/3-red-exactly"
        write_results(rows)
        results["oracle"] = digest_green and oracle_side(rows)
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

    declaration_green = all(
        rows.get(key) == EXPECTED_RESULTS[key]
        for key in ("declarations", "components", "calculus-slots", "reader-sets", "resource-folds", "semantic-refusals", "compile-barriers")
    )
    layers = {
        "Decision": "tested" if declaration_green else "UNVERIFIED",
        "Protocol": "tested" if rows.get("digests") == EXPECTED_RESULTS["digests"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={SUITE: "cabal test", "compile-negatives": "ghc -fno-code"},
        checks=results,
        mutants=[
            {"name": row["mutant"], "status": row["red_property"]}
            for row in mutation_catalog()
        ],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "declarations": "sha256:" + artifact_policy.digest(str(ACTUAL)),
        }
        if RESULTS.is_file() and ACTUAL.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
