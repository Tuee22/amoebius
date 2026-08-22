#!/usr/bin/env python3
"""The Phase-14 gate — owned refinement checking over compiled Haskell source."""

from __future__ import annotations

import csv
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import refinement_checker  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
ORACLE = ROOT / "test/oracle/refinement_checker/functions.tsv"
INVARIANTS = ROOT / "test/oracle/refinement_checker/model_invariants.tsv"
MODEL_SOURCE = ROOT / "test/spec/formal/refinement/RefinementModelProjection.hs"
MODEL_BUILD = ROOT / ".build/tmp/refinement-model-projection"
MODEL_EXECUTABLE = MODEL_BUILD / "refinement-model-projection"
PROJECTED_INVARIANTS = ROOT / ".build/checkers/refinement/model_invariants.tsv"
SOURCE = ROOT / "tools/refinement_checker.py"
RESULTS = ROOT / ".build/checkers/refinement/results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_14_refinement_checker.md"
GATE_COMMAND = "python3 tools/refinement_checker_gate.py"
EXPECTATIONS = "test/oracle/refinement_checker_surfaces.tsv"
MUTANT_CAPABILITY = "refinement_checker"
ACCEPTANCE = "refinement-checker-spec: PASS (6 functions, 2 invariant correspondences, 3 specific negatives)"

SIDES = ("toolchain", "oracle", "boundary", "suite", "mutant", "results")

CHECKS = {
    "function-oracle-complete": "six unique compiled functions cover every refinement result class",
    "model-invariant-registry-complete": "every required invariant has a proved function correspondence",
    "compiled-model-projection": "the checker consumes predicates projected from safe Phase-11 Model values",
    "mutant-registry-complete": "three checker modes cover hypotheses, correspondence, and postconditions",
    "owned-parser-total": "the checker owns its bounded source grammar and rejects unsupported syntax",
    "solver-resolved-not-ambient": "GHC and Z3 are injected from absolute authored-requirement resolutions",
    "suite-acceptance-token": "compilation, annotations, proofs, mappings, and diagnostics complete",
    "mutants-red-at-own-locus": "each checker mutant fails at its declared function status",
    "recorded-results-match-oracle": "all eleven result metrics equal the authored result oracle",
    "emitted-results-untracked": "suite results remain generated beneath .build/checkers",
}

EXPECTED_RESULTS = {
    "fixture-count": "6",
    "proved-count": "3",
    "postcondition-counterexample-count": "1",
    "correspondence-mismatch-count": "1",
    "unknown-invariant-count": "1",
    "required-invariant-count": "2",
    "covered-invariant-count": "2",
    "ghc-compiled-count": "6",
    "diagnostic-count": "3",
    "source-digest-count": "6",
    "mutants-red": "3/3",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "refinement-api": ("source-digest-count", "6"),
    "proved-functions": ("proved-count", "3"),
    "postcondition-counterexample": ("postcondition-counterexample-count", "1"),
    "correspondence-mismatch": ("correspondence-mismatch-count", "1"),
    "unknown-invariant": ("unknown-invariant-count", "1"),
    "required-correspondence": ("covered-invariant-count", "2"),
    "ghc-compilation": ("ghc-compiled-count", "6"),
    "diagnostics": ("diagnostic-count", "3"),
    "function-oracle": ("fixture-count", "6"),
    "model-invariant-registry": ("required-invariant-count", "2"),
    "compiled-model-projection": ("covered-invariant-count", "2"),
    "mutant-registry": ("mutants-red", "3/3"),
    "owned-source-parser": ("fixture-count", "6"),
    "solver-boundary": ("proved-count", "3"),
    "suite-acceptance": ("fixture-count", "6"),
    "checker-mutants": ("mutants-red", "3/3"),
    "mutant-results": ("mutants-red", "3/3"),
    "mutant-locus": ("mutants-red", "3/3"),
    "result-oracle": ("diagnostic-count", "3"),
    "generated-output": ("fixture-count", "6"),
    "runtime-fidelity": None,
}


class GateFailure(RuntimeError):
    pass


RUN_ENV = toolchain.contained_env()
RUN_ENV["PATH"] = os.pathsep.join([str(ROOT / "tools"), RUN_ENV.get("PATH", "")])


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=RUN_ENV, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-6000:]}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_oracles() -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    rows = read_tsv(ORACLE)
    invariants = read_tsv(INVARIANTS)
    expected_functions = {
        "increment", "decrement", "sumNonNegative", "brokenDecrement",
        "negativeIdentity", "unknownMapping",
    }
    statuses = {row.get("expected", "") for row in rows}
    if len(rows) != 6 or {row.get("function", "") for row in rows} != expected_functions:
        raise GateFailure("function oracle must contain six unique refinement fixtures")
    if statuses != {"proved", "postcondition-counterexample", "correspondence-mismatch", "unknown-invariant"}:
        raise GateFailure(f"refinement result-class coverage drifted: {sorted(statuses)}")
    if any(row.get("required") not in {"yes", "no"} or not row.get("line", "").isdigit() for row in rows):
        raise GateFailure("function oracle required/line fields are malformed")
    if len(invariants) != 2 or len({(row.get("model"), row.get("invariant")) for row in invariants}) != 2:
        raise GateFailure("model-invariant registry must contain two unique required pairs")
    required = {(row["model"], row["invariant"]) for row in rows if row["required"] == "yes"}
    registered = {(row["model"], row["invariant"]) for row in invariants}
    if required != registered:
        raise GateFailure(f"required function mappings {sorted(required)} != registry {sorted(registered)}")
    for row in rows:
        if not (ROOT / row["source"]).is_file():
            raise GateFailure(f"refinement source is absent: {row['source']}")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("mutant registry must carry three unique refinement-checker mutants")
    return rows, invariants, mutants


def verify_boundary(z3: dict[str, Any], ghc: dict[str, Any]) -> None:
    source = SOURCE.read_text(encoding="utf-8")
    if "shutil.which" in source or "shell=True" in source or "os.environ" in source:
        raise GateFailure("refinement checker discovers or invokes a tool through ambient process state")
    for token in ("amoebius-refinement", "correspondence-mismatch", "postcondition-counterexample", "unknown-invariant"):
        if token not in source:
            raise GateFailure(f"refinement checker is missing total-boundary token {token!r}")
    if "class Parser:" not in source or "unsupported expression" not in source:
        raise GateFailure("owned bounded Haskell-expression parser/rejection is absent")
    for name, record in (("z3", z3), ("ghc", ghc)):
        path = Path(record["path"])
        if not path.is_absolute() or not path.is_file() or record.get("source") == "host":
            raise GateFailure(f"{name} was not resolved to an absolute non-host requirement")


def checker_command(z3: str, ghc: str, *, mutant: str = "", results: bool = False) -> list[str]:
    command = [
        sys.executable, str(SOURCE), "--z3", z3, "--ghc", ghc,
        "--oracle", str(ORACLE), "--invariants", str(PROJECTED_INVARIANTS),
    ]
    if mutant:
        command.extend(["--mutant", mutant])
    if results:
        command.extend(["--results", str(RESULTS)])
    return command


def project_model_invariants(ghc: str, authored: list[dict[str, str]], gate: Any) -> None:
    MODEL_BUILD.mkdir(parents=True, exist_ok=True)
    compile_result = run([
        ghc, "-XGHC2024", "-Wall", "-Wcompat", "-Werror", "-fforce-recomp", "-isrc",
        f"-outputdir={MODEL_BUILD}", str(MODEL_SOURCE), "-o", str(MODEL_EXECUTABLE),
    ], require_success=False)
    projection = run([str(MODEL_EXECUTABLE), str(PROJECTED_INVARIANTS)], require_success=False) \
        if compile_result.returncode == 0 else compile_result
    transcript = compile_result.stdout + "\n" + projection.stdout
    (gate.run_dir / "model-projection.log").write_text(transcript, encoding="utf-8")
    acceptance = "refinement-model-projection: PASS (2 models, 8 reachable states, 2 invariants)"
    if compile_result.returncode != 0 or projection.returncode != 0 or acceptance not in projection.stdout:
        raise GateFailure(f"compiled model projection failed:\n{transcript[-6000:]}")
    projected = read_tsv(PROJECTED_INVARIANTS)
    authored_by_key = {(row["model"], row["invariant"]): row for row in authored}
    projected_by_key = {(row.get("model", ""), row.get("invariant", "")): row for row in projected}
    if set(projected_by_key) != set(authored_by_key) or len(projected) != len(projected_by_key):
        raise GateFailure("compiled model projection identities differ from the authored semantic oracle")
    for key, expected in authored_by_key.items():
        expected_expr = refinement_checker.parse_expression(expected["post"])
        actual_expr = refinement_checker.parse_expression(projected_by_key[key].get("post", ""))
        if actual_expr != expected_expr:
            raise GateFailure(f"compiled invariant {key} differs from its authored semantic oracle")


def mutant_side(z3: str, ghc: str, mutants: list[dict[str, str]], gate: Any) -> bool:
    expected_text = {
        "sum-status": "sumNonNegative status: expected 'proved', got 'postcondition-counterexample'",
        "negative-identity-status": "negativeIdentity status: expected 'correspondence-mismatch', got 'proved'",
        "broken-decrement-status": "brokenDecrement status: expected 'postcondition-counterexample', got 'proved'",
    }
    passed = True
    logs: list[str] = []
    for row in mutants:
        details = dict(pair.split("=", 1) for pair in row["detail"].split(";"))
        locus = details["expected_red_locus"]
        outcome = run(checker_command(z3, ghc, mutant=details["mode"]), require_success=False)
        red = outcome.returncode != 0 and expected_text[locus] in outcome.stdout
        logs.append(f"{row['mutant']}: red={red}\n{outcome.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {row['mutant']:<30} {locus}")
        passed = passed and red
    (gate.run_dir / "mutants.log").write_text("\n".join(logs), encoding="utf-8")
    return passed


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=14, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
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
        resolved = toolchain.resolve(["ghc", "z3"])
        z3, ghc = resolved["z3"]["path"], resolved["ghc"]["path"]
        print("toolchain side — GHC and Z3 resolved from authored requirements\n")
        for name in ("ghc", "z3"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<10} satisfies {record['requirement']}")
        results["toolchain"] = True

        print("\noracle side — compiled functions and required model-invariant mappings\n")
        oracle, invariants, mutant_rows = verify_oracles()
        project_model_invariants(ghc, invariants, gate)
        print(f"  ok    function-oracle-complete             {len(oracle)} functions, four result classes")
        print(f"  ok    model-invariant-registry-complete    {len(invariants)} required correspondences")
        print("  ok    compiled-model-projection            2 safe Model values, 8 reachable states")
        print(f"  ok    mutant-registry-complete             {len(mutant_rows)} seeded defects")
        results["oracle"] = True

        print("\nboundary side — owned bounded parser with absolute compiler/solver injection\n")
        verify_boundary(resolved["z3"], resolved["ghc"])
        print("  ok    owned-parser-total")
        print("  ok    solver-resolved-not-ambient")
        results["boundary"] = True

        print("\nsuite side — GHC compilation, preservation, correspondence, and diagnostics\n")
        suite = run(checker_command(z3, ghc, results=True), require_success=False)
        (gate.run_dir / "suite.log").write_text(suite.stdout, encoding="utf-8")
        if suite.returncode != 0 or ACCEPTANCE not in suite.stdout:
            raise GateFailure(f"suite acceptance token is absent:\n{suite.stdout}")
        print("  ok    suite-acceptance-token      6 functions, 2 mappings, 3 negatives")
        results["suite"] = True

        print("\nmutant side — precondition, correspondence, and postcondition defects\n")
        results["mutant"] = mutant_side(z3, ghc, mutant_rows, gate)
        if not RESULTS.is_file():
            raise GateFailure(f"suite emitted no {gate_common.rel(RESULTS)}")
        with RESULTS.open("a", encoding="utf-8") as handle:
            handle.write(f"mutants-red\t{'3/3' if results['mutant'] else '0/3'}\n")
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the suite's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, refinement_checker.RefinementFailure) as problem:
        print(f"refinement-checker-gate: FAIL: {problem}", file=sys.stderr)

    layers = {
        "Decision": "tested" if rows.get("ghc-compiled-count") == "6" else "UNVERIFIED",
        "Protocol": "proven-for-the-model" if rows.get("covered-invariant-count") == "2" else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={
            "metrics": set(rows), "checks": set(CHECKS),
            "mutants": {row["mutant"] for row in mutant_rows},
        },
        rows=rows, evidence=SURFACE_EVIDENCE, layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items() if name in {"ghc", "z3"}
        },
        dependencies={"refinement-checker": "Python stdlib", "ghc": "-fno-code", "z3": "SMT-LIB stdin"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "refinement checker mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
