#!/usr/bin/env python3
"""The Phase-14 gate — amoebius-owned inductive safety checking through SMT.

Seven authored models separate inductive, base-red, step-red, conservatively
non-inductive, and explicitly unsupported results.  The checker owns its QF_LIA
translation and induction schema, while Z3 is dynamically resolved and injected by
absolute path.  Three real build mutants attack distinct proof obligations.
"""

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

import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
ORACLE = ROOT / "test/oracle/symbolic_checker/models.tsv"
SOURCE = ROOT / "src/symbolic-checker/Amoebius/Checker/Symbolic.hs"
RESULTS = ROOT / ".build/checkers/symbolic/results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/symbolic-checker-gate"
CONTRACT = "DEVELOPMENT_PLAN/phase_14_symbolic_checker.md"
GATE_COMMAND = "python3 tools/symbolic_checker_gate.py"
EXPECTATIONS = "test/oracle/symbolic_checker_surfaces.tsv"
MUTANT_CAPABILITY = "symbolic_checker"
SUITE = "symbolic-checker-spec"
ACCEPTANCE = "symbolic-checker-spec: PASS (7 fixtures, 5 explicit agreements, 3 induction witnesses)"

SIDES = ("toolchain", "oracle", "boundary", "suite", "mutant", "results")

CHECKS = {
    "model-oracle-complete": "seven unique models cover every symbolic result class and relation",
    "mutant-registry-complete": "three build mutants cover hypothesis, guard, and solver-verdict defects",
    "checker-does-not-import-other-checkers": "the symbolic implementation owns its translation and schema",
    "checker-source-total": "unsupported syntax is a result and the library has no partial or ambient read",
    "solver-resolved-not-ambient": "the solver is resolved from authored requirements and injected absolutely",
    "suite-acceptance-token": "fixture, agreement, witness, digest, and solver-boundary checks complete",
    "mutants-red-at-own-locus": "each build mutant fails at its declared observable",
    "recorded-results-match-oracle": "all eleven result metrics equal the authored result oracle",
    "emitted-results-untracked": "suite results remain generated beneath .build/checkers",
}

EXPECTED_RESULTS = {
    "fixture-count": "7",
    "inductive-count": "3",
    "base-counterexample-count": "1",
    "step-counterexample-count": "2",
    "unsupported-count": "1",
    "explicit-agreement-count": "5",
    "conservative-noninductive-count": "1",
    "shared-digest-count": "7",
    "proof-obligation-total": "14",
    "induction-witness-count": "3",
    "mutants-red": "3/3",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "symbolic-api": ("shared-digest-count", "7"),
    "inductive-proofs": ("inductive-count", "3"),
    "base-counterexample": ("base-counterexample-count", "1"),
    "step-counterexample": ("step-counterexample-count", "2"),
    "unsupported-fragment": ("unsupported-count", "1"),
    "explicit-agreement": ("explicit-agreement-count", "5"),
    "conservative-rejection": ("conservative-noninductive-count", "1"),
    "proof-obligations": ("proof-obligation-total", "14"),
    "induction-witnesses": ("induction-witness-count", "3"),
    "model-oracle": ("fixture-count", "7"),
    "mutant-registry": ("mutants-red", "3/3"),
    "independent-translation": ("fixture-count", "7"),
    "checker-totality": ("unsupported-count", "1"),
    "solver-boundary": ("induction-witness-count", "3"),
    "suite-acceptance": ("fixture-count", "7"),
    "checker-mutants": ("mutants-red", "3/3"),
    "mutant-results": ("mutants-red", "3/3"),
    "mutant-locus": ("mutants-red", "3/3"),
    "result-oracle": ("shared-digest-count", "7"),
    "generated-output": ("fixture-count", "7"),
    "runtime-fidelity": None,
}


class GateFailure(RuntimeError):
    pass


RUN_ENV = toolchain.contained_env()
RUN_ENV["PATH"] = os.pathsep.join([str(ROOT / "tools"), RUN_ENV.get("PATH", "")])
COMPILER = ""


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=RUN_ENV,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-6000:]}")
    return result


def cabal_command(cabal: str, verb: str, *rest: str) -> list[str]:
    return [
        cabal,
        f"--store-dir={ROOT / '.build' / 'cabal-store'}",
        verb,
        f"--with-compiler={COMPILER}",
        f"--builddir={BUILD_ROOT}",
        *rest,
    ]


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_oracle() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    rows = read_tsv(ORACLE)
    expected_names = {
        "inductive-counter", "base-failure", "step-failure", "safe-noninductive",
        "coupled-invariants", "guarded-boolean", "unsupported-set",
    }
    names = {row.get("model", "") for row in rows}
    statuses = {row.get("symbolic_status", "") for row in rows}
    relations = {row.get("relation", "") for row in rows}
    columns = {
        "model", "bound", "symbolic_status", "failing_invariant", "failing_action",
        "explicit_status", "relation", "obligations",
    }
    if len(rows) != 7 or names != expected_names:
        raise GateFailure(f"symbolic oracle must contain seven unique fixtures: {sorted(names)}")
    if statuses != {"inductive", "base-failure", "step-failure", "unsupported"}:
        raise GateFailure(f"symbolic result-class coverage drifted: {sorted(statuses)}")
    if relations != {"agree", "conservative", "unsupported"}:
        raise GateFailure(f"symbolic relation coverage drifted: {sorted(relations)}")
    if any(set(row) != columns for row in rows):
        raise GateFailure("symbolic oracle column set drifted")
    for row in rows:
        if not row["bound"].isdigit() or not row["obligations"].isdigit():
            raise GateFailure(f"symbolic oracle integer is malformed: {row}")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("mutant registry must carry three unique symbolic-checker mutants")
    return rows, mutants


def verify_boundary(solver: dict[str, Any]) -> None:
    source = SOURCE.read_text(encoding="utf-8")
    uncommented = re.sub(r"--[^\n]*", "", source)
    if re.search(
        r"^\s*import\s+(?:qualified\s+)?Amoebius\.Checker\.(?:ExplicitState|Symbolic)|"
        r"^\s*import\s+(?:qualified\s+)?Amoebius\.Formal\.Explore\b",
        uncommented,
        re.M,
    ):
        raise GateFailure("symbolic checker delegates to another checker or explorer")
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', uncommented)
    prohibited = re.compile(
        r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeDupablePerformIO|lookupEnv|getEnv|readFile|getLine)\b"
    )
    found = prohibited.search(stripped)
    if found:
        raise GateFailure(f"symbolic checker source contains prohibited token {found.group(1)!r}")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    stanza = re.search(
        r"library symbolic-checker\n(?P<body>.*?)(?=\n(?:library|executable|test-suite|benchmark) |\Z)",
        cabal,
        re.S,
    )
    if stanza is None:
        raise GateFailure("standalone symbolic-checker library stanza is missing")
    body = stanza.group("body")
    if "src/symbolic-checker" not in body or "amoebius:formal-model" not in body:
        raise GateFailure("symbolic checker must use its dedicated root and consume formal-model")
    if "-Werror=incomplete-patterns" not in body:
        raise GateFailure("symbolic checker incomplete-pattern totality option is missing")
    solver_path = Path(solver["path"])
    if not solver_path.is_absolute() or not solver_path.is_file() or solver.get("source") == "host":
        raise GateFailure("solver was not resolved to an absolute non-host requirement")


def suite_binary(cabal: str, flags: list[str]) -> str:
    listing = run(cabal_command(cabal, "list-bin", SUITE, *flags))
    return listing.stdout.strip().splitlines()[-1]


def build_suite(cabal: str, flags: list[str]) -> str:
    run(cabal_command(cabal, "build", SUITE, *flags))
    return suite_binary(cabal, flags)


def run_suite(binary: str) -> subprocess.CompletedProcess[str]:
    return run([binary], require_success=False)


def mutant_side(cabal: str, mutants: list[dict[str, str]], gate: Any) -> bool:
    passed = True
    logs: list[str] = []
    expected_text = {
        "coupled-invariants-status": 'coupled-invariants symbolic status: expected "inductive", got "step-failure"',
        "inductive-counter-status": 'inductive-counter symbolic status: expected "inductive", got "step-failure"',
        "step-failure-status": 'step-failure symbolic status: expected "step-failure", got "inductive"',
    }
    for row in mutants:
        details = dict(pair.split("=", 1) for pair in row["detail"].split(";"))
        locus = details["expected_red_locus"]
        binary = build_suite(cabal, [f"-f{row['flag']}"])
        outcome = run_suite(binary)
        red = outcome.returncode != 0 and expected_text[locus] in outcome.stdout
        logs.append(f"{row['mutant']}: red={red}\n{outcome.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {row['mutant']:<28} {locus}")
        passed = passed and red
    (gate.run_dir / "mutants.log").write_text("\n".join(logs), encoding="utf-8")
    return passed


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=13,
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

    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    try:
        resolved = toolchain.resolve(["cabal", "ghc", "z3"])
        globals()["COMPILER"] = resolved["ghc"]["path"]
        RUN_ENV["AMOEBIUS_Z3"] = resolved["z3"]["path"]
        cabal = resolved["cabal"]["path"]
        print("toolchain side — cabal, ghc, and Z3 resolved from authored requirements\n")
        for name in ("cabal", "ghc", "z3"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<10} satisfies {record['requirement']}")
        results["toolchain"] = True
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)

        print("\noracle side — seven induction and explicit-state relationships\n")
        oracle, mutant_rows = verify_oracle()
        print(f"  ok    model-oracle-complete       {len(oracle)} fixtures, four symbolic classes")
        print(f"  ok    mutant-registry-complete    {len(mutant_rows)} seeded defects")
        results["oracle"] = True

        print("\nboundary side — independent dedicated-root translation and injected solver\n")
        verify_boundary(resolved["z3"])
        print("  ok    checker-does-not-import-other-checkers")
        print("  ok    checker-source-total")
        print(f"  ok    solver-resolved-not-ambient {resolved['z3']['path']}")
        results["boundary"] = True

        print("\nsuite side — induction, counterexamples, conservative rejection, and digest parity\n")
        clean_binary = build_suite(cabal, [])
        suite = run_suite(clean_binary)
        (gate.run_dir / "suite.log").write_text(suite.stdout, encoding="utf-8")
        if suite.returncode != 0 or ACCEPTANCE not in suite.stdout:
            raise GateFailure(f"suite acceptance token is absent:\n{suite.stdout}")
        print("  ok    suite-acceptance-token      7 fixtures, 5 agreements, 3 witnesses")
        results["suite"] = True

        print("\nmutant side — induction hypothesis, guard polarity, and solver verdict\n")
        results["mutant"] = mutant_side(cabal, mutant_rows, gate)

        if not RESULTS.is_file():
            raise GateFailure(f"suite emitted no {gate_common.rel(RESULTS)}")
        with RESULTS.open("a", encoding="utf-8") as handle:
            handle.write(f"mutants-red\t{'3/3' if results['mutant'] else '0/3'}\n")
        rows = gate_common.metric_rows(RESULTS)

        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent],
            (".tsv", ".log"),
            gate.run_dir,
            check="emitted-results-untracked",
            label="the suite's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError) as problem:
        print(f"symbolic-checker-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if COMPILER and resolved:
            run(cabal_command(resolved["cabal"]["path"], "build", SUITE), require_success=False)

    layers = {
        "Decision": "tested" if rows.get("explicit-agreement-count") == "5" else "UNVERIFIED",
        "Protocol": "proven-for-the-model" if rows.get("inductive-count") == "3" else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={
            "metrics": set(rows),
            "checks": set(CHECKS),
            "mutants": {row["mutant"] for row in mutant_rows},
        },
        rows=rows,
        evidence=SURFACE_EVIDENCE,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name in {"cabal", "ghc", "z3"}
        },
        dependencies={SUITE: "cabal build", "formal-model": "Phase-12 Model semantics", "z3": "SMT-LIB stdin"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "symbolic checker mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
