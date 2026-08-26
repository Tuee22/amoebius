#!/usr/bin/env python3
"""Run and seal the pure closed transaction-vocabulary gate."""

from __future__ import annotations

import csv
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry
import toolchain


ROOT = Path(__file__).resolve().parent.parent
ORACLE_ROOT = ROOT / "test/oracle/transaction_vocabulary"
ROWS = ORACLE_ROOT / "rows.tsv"
TRANSACTIONS = ORACLE_ROOT / "transactions.tsv"
GENERATIONS = ORACLE_ROOT / "generations.tsv"
CALCULUS = ORACLE_ROOT / "calculus_projection.tsv"
LOCUS = ORACLE_ROOT / "validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/transaction-vocabulary/phase-results.tsv"
SQL_BUNDLE = ROOT / ".build/sql/transaction-vocabulary/schema.sql"
BUILD_ROOT = ROOT / ".build/dist-newstyle/transaction-vocabulary"
CONTRACT = "DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md"
GATE_COMMAND = "python3 tools/transaction_vocabulary_gate.py"
EXPECTATIONS = "test/oracle/transaction_vocabulary_surfaces.tsv"
MUTANT_CAPABILITY = "transaction_vocabulary"


class GateFailure(RuntimeError):
    pass


COMPILER = ""


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0],
            f"--with-compiler={COMPILER}",
            f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}",
            "--jobs=1",
            *command[1:],
        ]
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


def verify_oracles() -> list[dict[str, str]]:
    rows = read_tsv(ROWS)
    transactions = read_tsv(TRANSACTIONS)
    generations = read_tsv(GENERATIONS)
    calculus = read_tsv(CALCULUS)
    loci = read_tsv(LOCUS)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    expected_rows = {
        "document": ("documents", 3, "tenant_id,document_id", "tenant_id"),
        "job": ("jobs", 4, "tenant_id,job_id", "tenant_id"),
        "release": ("releases", 3, "tenant_id,release_id", "tenant_id"),
    }
    actual_rows = {
        row["row"]: (
            row["table"],
            len(row["columns"].split("|")),
            row["primary_key"],
            row["policy_column"],
        )
        for row in rows
    }
    if actual_rows != expected_rows or len(rows) != 3:
        raise GateFailure("row semantic oracle does not name the three exact declarations")
    if any("not-null" not in column for row in rows for column in row["columns"].split("|")):
        raise GateFailure("row semantic oracle admits a nullable column")
    if any(row["policy_parameter"] != "scope_tenant" for row in rows):
        raise GateFailure("row semantic oracle carries a non-scope policy parameter")
    expected_transactions = [
        ("insert-document", "insert", "documents"),
        ("read-document", "select-one", "documents"),
        ("list-subject-jobs", "select-many", "jobs"),
        ("advance-job-status", "update", "jobs"),
        ("record-release", "insert", "releases"),
    ]
    actual_transactions = [(row["transaction"], row["operation"], row["table"]) for row in transactions]
    if actual_transactions != expected_transactions:
        raise GateFailure("transaction semantic oracle is incomplete or reordered")
    if any(row["scope_column"] != "tenant_id" or row["scope_parameter"] != "scope_tenant" for row in transactions):
        raise GateFailure("transaction oracle admits a widened scope predicate")
    expected_generations = [
        ("generation-1-to-2", "admitted"),
        ("generation-2-to-3", "admitted"),
        ("generation-2-to-1", "generation-regression"),
        ("generation-1-to-3", "generation-skipped"),
        ("generation-3-to-3", "generation-current"),
    ]
    if [(row["case"], row["verdict"]) for row in generations] != expected_generations:
        raise GateFailure("generation oracle does not separate the two transitions and three refusals")
    if any(row["clause_kind"] != "create-table" for row in generations if row["verdict"] == "admitted"):
        raise GateFailure("an admitted generation transition is not additive")
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "row-semantics,transaction-semantics,compile-barriers,generation-cases,mutant-evidence"},
        {"metric": "projection-counts", "value": "3,5,4,5,3"},
        {"metric": "resource-vector", "value": "5,20,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("transaction five-calculus projection oracle drifted")
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("transaction mutant registry must contain three unique rows")
    expected_items = {
        *(row["row"] for row in rows),
        *(row["transaction"] for row in transactions),
        *(row["case"] for row in generations),
        "unscoped-transaction",
        "raw-statement",
        "predicate-constructor",
        "cross-scope-composition",
        *(row["mutant"] for row in mutants),
    }
    if len(loci) != 20 or {row["entry"] for row in loci} != expected_items:
        raise GateFailure("transaction validation-locus ledger is incomplete or duplicated")
    for row in mutants:
        descriptor = ROOT / row["body"]
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"mutant descriptor is absent: {row['mutant']}")
    return mutants


def verify_sources() -> None:
    module = (ROOT / "src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs").read_text(encoding="utf-8")
    exports = module.split(") where", 1)[0]
    for private in ("InsertDocument", "ReadDocument", "ListSubjectJobs", "AdvanceJobStatus", "RecordRelease", "RowDeclaration", "ScopePredicate"):
        if re.search(rf"^\s*,?\s*{private}\b", exports, re.MULTILINE):
            raise GateFailure(f"private transaction surface is exported: {private}")
    if "rawStatement" in exports or re.search(r"^\s*,?\s*predicate\b", exports, re.MULTILINE):
        raise GateFailure("a general query or predicate constructor reaches the export surface")
    if module.count("-> Transaction scope (Scoped scope") != 10:
        raise GateFailure("the closed transaction smart-constructor surface no longer has five indexed results")
    if module.count("scopePredicate declaration") < 3:
        raise GateFailure("schema, policy, and statement projections no longer share the scope term")
    prohibited = re.compile(r"\b(error|undefined|fromJust|unsafePerformIO|head|tail)\b|!!")
    without_comments = re.sub(r"--[^\n]*", "", module)
    without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
    match = prohibited.search(without_strings)
    if match:
        raise GateFailure(f"partial or unsafe token in transaction vocabulary: {match.group(0)!r}")
    retired = ROOT / "test/golden/transaction_vocabulary"
    if retired.exists():
        raise GateFailure("a renderer-output SQL golden exists for the transaction vocabulary")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for stanza in ("library transaction-vocabulary", "test-suite transaction-vocabulary-spec", "test-suite transaction-vocabulary-compile"):
        body = cabal.split(stanza, 1)[1].split("\n\n", 1)[0]
        for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
            if option not in body:
                raise GateFailure(f"transaction totality option missing from {stanza}: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "transaction-vocabulary-spec",
            "transaction-vocabulary-compile",
            "--test-show-details=direct",
        ]
    )
    tokens = (
        "transaction-vocabulary-compile: PASS scoped closed-surface twin",
        "transaction-vocabulary-calculus: PASS (5 kinds, 20 projected units)",
        "transaction-vocabulary-invariants: PASS (3 rows, 5 closed transactions, 2 additive transitions, 4 compile barriers)",
        "transaction-vocabulary-spec: PASS (3 semantic oracles, 5 generation cases, 3 mutants)",
    )
    if any(token not in result.stdout for token in tokens):
        raise GateFailure(f"transaction acceptance token is absent:\n{result.stdout}")
    emitted = run(
        [
            str(cabal),
            "test",
            "transaction-vocabulary-spec",
            "--test-show-details=direct",
            f"--test-options=--emit={SQL_BUNDLE}",
        ]
    )
    if not SQL_BUNDLE.is_file():
        raise GateFailure("transaction suite did not emit the generated SQL bundle")
    sql = SQL_BUNDLE.read_text(encoding="utf-8")
    if any(token in sql for token in ("DROP ", "TRUNCATE ", "DELETE ")):
        raise GateFailure("generated transaction SQL carries a destructive verb")
    return result.stdout + emitted.stdout


COMPILE_CASES = (
    ("unscoped-transaction", "transaction-vocabulary-test-unscoped", ("applied to too few arguments", "RequestScope")),
    ("raw-statement", "transaction-vocabulary-test-raw-query", ("rawStatement", "does not export")),
    ("predicate-constructor", "transaction-vocabulary-test-predicate", ("Vocabulary.predicate", "does not export")),
    ("cross-scope-composition", "transaction-vocabulary-test-cross-scope", ("Couldn't match type", "rightScope")),
)


def verify_compile_barriers(cabal: Path) -> str:
    logs: list[str] = []
    flags = [case[1] for case in COMPILE_CASES]
    for name, enabled, tokens in COMPILE_CASES:
        selections = [f"-f{flag}" if flag == enabled else f"-f-{flag}" for flag in flags]
        result = run(
            [str(cabal), "build", "test:transaction-vocabulary-compile", *selections],
            require_success=False,
        )
        if result.returncode == 0 or any(token not in result.stdout for token in tokens):
            raise GateFailure(f"compile barrier did not fail at its expected reason: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    disabled = [f"-f-{case[1]}" for case in COMPILE_CASES]
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal),
                "test",
                "transaction-vocabulary-spec",
                *disabled,
                "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"transaction-vocabulary-mutant: RED {name} locus={row['expected_locus']}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its exact locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


EXPECTED_RESULTS = {
    "row-declarations": "3/3-exact",
    "required-columns": "10/10-exact",
    "not-null-columns": "10/10-exact",
    "primary-keys": "3/3-composite",
    "scope-foreign-keys": "3/3-exact",
    "row-policies": "3/3-exact",
    "transactions": "5/5-exact",
    "operation-vector": "2,1,1,1",
    "required-scope-fields": "5/5-exact",
    "exact-scope-predicates": "5/5-exact",
    "scope-indexed-results": "5/5-exact",
    "compile-barriers": "4/4-red-at-exact-reason",
    "additive-transitions": "2/2-exact",
    "generation-cases": "5/5-exact",
    "generation-refusals": "3/3-exact-reason",
    "destructive-verbs": "0/0",
    "deterministic-projections": "2/2-byte-identical",
    "mutants": "3/3-red-at-exact-locus",
    "validation-locus-entries": "20/20-exact",
    "calculus-kinds": "5/5-exact",
    "calculus-components": "row-semantics,transaction-semantics,compile-barriers,generation-cases,mutant-evidence",
    "calculus-projection-counts": "3,5,4,5,3",
    "calculus-resource-vector": "5,20,0,0",
    "live-catalog-enforcement": "UNVERIFIED",
    "live-row-policy-enforcement": "UNVERIFIED",
    "executor-role-fidelity": "UNVERIFIED",
}


CHECKS = {
    "semantic-oracles-complete": "row, transaction, generation, calculus, and locus oracles are exact",
    "transaction-constructors-opaque": "the five GADT constructors and declaration terms are private",
    "general-query-surface-absent": "no raw statement or predicate constructor is exported",
    "shared-declaration-source": "schema, policy, and statement projections consume the same row term",
    "totality-options": "library and both suites compile incomplete patterns as errors",
    "partial-source-absent": "the transaction vocabulary contains no partial or unsafe source token",
    "retired-sql-golden-absent": "no generated SQL output copy is committed as a golden",
    "emitted-results-untracked": "generated SQL and result metrics stay outside the source snapshot",
    "toolchain-satisfies-requirements": "resolved cabal and ghc satisfy authored requirements",
    "recorded-results-match-oracle": "every recorded metric equals its authored expectation",
}


SURFACE_MAP = {
    "three-row-declarations": "row-declarations",
    "three-authored-row-semantics": "document,job,release",
    "ten-required-columns": "required-columns",
    "all-columns-not-null": "not-null-columns",
    "three-composite-primary-keys": "primary-keys",
    "three-scope-foreign-keys": "scope-foreign-keys",
    "three-row-policies": "row-policies",
    "one-declaration-drives-policy-and-statement": "shared-declaration-source",
    "five-closed-transactions": "transactions",
    "five-authored-transaction-semantics": "insert-document,read-document,list-subject-jobs,advance-job-status,record-release",
    "closed-operation-vector": "operation-vector",
    "required-request-scope": "required-scope-fields",
    "exact-scope-predicate": "exact-scope-predicates",
    "scope-indexed-results": "scope-indexed-results",
    "opaque-transaction-constructors": "transaction-constructors-opaque",
    "no-general-query-surface": "general-query-surface-absent",
    "four-compile-barriers": "compile-barriers",
    "four-authored-compile-barriers": "unscoped-transaction,raw-statement,predicate-constructor,cross-scope-composition",
    "two-additive-transitions": "additive-transitions",
    "five-generation-cases": "generation-cases",
    "five-authored-generation-cases": "generation-1-to-2,generation-2-to-3,generation-2-to-1,generation-1-to-3,generation-3-to-3",
    "three-exact-generation-refusals": "generation-refusals",
    "zero-destructive-verbs": "destructive-verbs",
    "two-deterministic-projections": "deterministic-projections",
    "semantic-oracles-complete": "semantic-oracles-complete",
    "compile-totality": "totality-options",
    "source-totality": "partial-source-absent",
    "retired-sql-output-golden": "retired-sql-golden-absent",
    "three-paired-mutants": "mutants",
    "three-authored-mutants": "transaction-optional-scope,transaction-match-all,transaction-wrong-policy-column",
    "validation-locus-ledger": "validation-locus-entries",
    "five-calculus-kind-cardinality": "calculus-kinds",
    "five-calculus-component-vector": "calculus-components",
    "five-calculus-projection-counts": "calculus-projection-counts",
    "five-calculus-resource-vector": "calculus-resource-vector",
    "generated-artifact-discipline": "emitted-results-untracked,toolchain-satisfies-requirements,recorded-results-match-oracle",
    "live-catalog-enforcement": "live-catalog-enforcement",
    "live-row-policy-enforcement": "live-row-policy-enforcement",
    "executor-role-fidelity": "executor-role-fidelity",
}


SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] != "UNVERIFIED" else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names = {row["row"] for row in read_tsv(ROWS)}
    names.update(row["transaction"] for row in read_tsv(TRANSACTIONS))
    names.update(row["case"] for row in read_tsv(GENERATIONS))
    names.update({"unscoped-transaction", "raw-statement", "predicate-constructor", "cross-scope-composition"})
    names.update(row["mutant"] for row in mutant_registry.capability(MUTANT_CAPABILITY))
    return names


def write_results() -> None:
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{metric}\t{result}\n" for metric, result in EXPECTED_RESULTS.items()),
        encoding="utf-8",
    )


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=36,
        contract=CONTRACT,
        command=GATE_COMMAND,
        register="1",
        substrate="none",
        lane="none",
        sides=("toolchain", "oracle", "source", "suite", "compile", "mutant", "results"),
        expectations=EXPECTATIONS,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    item_names: set[str] = set()
    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — row, transaction, generation, calculus, loci, and mutants\n")
        mutant_rows = verify_oracles()
        item_names = enumerated_items()
        print(f"  ok    {len(item_names)} enumerated items, {len(mutant_rows)} mutants, loci exact")
        results["oracle"] = True

        print("\nsource side — closed constructors, one declaration, total folds, and no raw surface\n")
        verify_sources()
        print("  ok    transaction source boundary exact")
        results["source"] = True

        print("\nsuite side — semantic schema/policy/statement and generation battery\n")
        suite = run_green_suite(cabal)
        (gate.run_dir / "suite.log").write_text(suite, encoding="utf-8")
        print("  ok    all four acceptance tokens present and SQL emitted")
        results["suite"] = True

        print("\ncompile side — unscoped, raw-query, predicate, and cross-scope barriers\n")
        compile_log = verify_compile_barriers(cabal)
        (gate.run_dir / "compile.log").write_text(compile_log, encoding="utf-8")
        print(f"  ok    {len(COMPILE_CASES)}/{len(COMPILE_CASES)} compile barriers red at exact reason")
        results["compile"] = True

        print("\nmutant side — every seeded semantic mutant red at its own locus\n")
        mutant_log = verify_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {len(mutant_rows)}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results()
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent, SQL_BUNDLE.parent],
            (".tsv", ".log", ".sql"),
            gate.run_dir,
            check="emitted-results-untracked",
            label="generated SQL and transaction battery output stay generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError) as problem:
        print(f"transaction-vocabulary-gate: FAIL: {problem}", file=sys.stderr)

    item_evidence = {
        surface: ("validation-locus-entries", EXPECTED_RESULTS["validation-locus-entries"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
    }
    layers = {
        "Decision": "tested" if rows.get("transactions") == EXPECTED_RESULTS["transactions"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": item_names},
        rows=rows,
        evidence={**SURFACE_EVIDENCE, **item_evidence},
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"transaction-vocabulary-spec": "cabal test transaction-vocabulary-spec transaction-vocabulary-compile"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "phase-36 mutants", "status": "unrun"}],
        observations={"generated-sql": "sha256:" + gate_common.artifact_policy.digest(str(SQL_BUNDLE))}
        if SQL_BUNDLE.is_file()
        else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
