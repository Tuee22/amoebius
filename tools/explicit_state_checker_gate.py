#!/usr/bin/env python3
"""The Phase-13 gate — amoebius-owned bounded explicit-state checking.

Seven hand-enumerated models cover safe, invariant-red, deadlock-red, constraint,
branching, exact-bound, and exhausted-bound results.  The independent checker may
consume Phase 12's Model/interpreter semantics but may not call its explorer.  Three
real build mutants weaken a guard, skip invariants, or truncate the frontier.
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
ORACLE = ROOT / "test/oracle/explicit_state_checker/models.tsv"
SOURCE = ROOT / "src/explicit-state-checker/Amoebius/Checker/ExplicitState.hs"
RESULTS = ROOT / ".build/checkers/explicit-state/results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/explicit-state-checker"
CONTRACT = "DEVELOPMENT_PLAN/phase_13_explicit_state_checker.md"
GATE_COMMAND = "python3 tools/explicit_state_checker_gate.py"
EXPECTATIONS = "test/oracle/explicit_state_checker_surfaces.tsv"
MUTANT_CAPABILITY = "explicit_state_checker"
SUITE = "explicit-state-checker-spec"
ACCEPTANCE = "explicit-state-checker-spec: PASS (7 fixtures, 5 explorer parity rows, 2 replayed counterexamples)"

SIDES = ("toolchain", "oracle", "boundary", "suite", "mutant", "results")

CHECKS = {
    "model-oracle-complete": "seven unique models cover every explicit-check result class",
    "mutant-registry-complete": "three build mutants cover guard, invariant, and frontier defects",
    "checker-does-not-import-explorer": "the checker owns its frontier rather than delegating to Phase 12",
    "checker-source-total": "the dedicated checker source has no partial or ambient-read token",
    "suite-acceptance-token": "all fixture, parity, replay, bound, and digest checks complete",
    "mutants-red-at-own-locus": "each build mutant fails at its declared observable",
    "recorded-results-match-oracle": "all ten result metrics equal the authored result oracle",
    "emitted-results-untracked": "suite results remain generated beneath .build",
}

EXPECTED_RESULTS = {
    "fixture-count": "7",
    "safe-count": "4",
    "invariant-counterexample-count": "1",
    "deadlock-counterexample-count": "1",
    "bound-exceeded-count": "1",
    "explorer-parity-count": "5",
    "replayed-counterexample-count": "2",
    "distinct-state-total": "27",
    "digest-binding": "yes",
    "mutants-red": "3/3",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "checker-api": ("fixture-count", "7"),
    "safe-verdicts": ("safe-count", "4"),
    "invariant-counterexample": ("invariant-counterexample-count", "1"),
    "deadlock-counterexample": ("deadlock-counterexample-count", "1"),
    "counterexample-replay": ("replayed-counterexample-count", "2"),
    "bound-exhaustion": ("bound-exceeded-count", "1"),
    "explorer-parity": ("explorer-parity-count", "5"),
    "model-oracle": ("fixture-count", "7"),
    "mutant-registry": ("mutants-red", "3/3"),
    "independent-frontier": ("explorer-parity-count", "5"),
    "checker-totality": ("fixture-count", "7"),
    "suite-acceptance": ("fixture-count", "7"),
    "checker-mutants": ("mutants-red", "3/3"),
    "mutant-results": ("mutants-red", "3/3"),
    "mutant-locus": ("mutants-red", "3/3"),
    "result-oracle": ("digest-binding", "yes"),
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
        "toy-safe", "toy-too-small", "safe-counter", "unsafe-counter",
        "deadlock", "constraint", "branching",
    }
    names = {row.get("model", "") for row in rows}
    statuses = {row.get("status", "") for row in rows}
    if len(rows) != 7 or names != expected_names:
        raise GateFailure(f"model oracle must contain seven unique fixtures: {sorted(names)}")
    if statuses != {"safe", "unsafe-invariant", "unsafe-deadlock", "bound-exceeded"}:
        raise GateFailure(f"model oracle result-class coverage drifted: {sorted(statuses)}")
    if any(set(row) != {"model", "bound", "status", "distinct_states", "violation", "trace_length"} for row in rows):
        raise GateFailure("model oracle column set drifted")
    for row in rows:
        for field in ("bound", "distinct_states", "trace_length"):
            if not row[field].isdigit():
                raise GateFailure(f"oracle integer is malformed: {row}")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("mutant registry must carry three unique explicit-state mutants")
    return rows, mutants


def verify_boundary() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    uncommented = re.sub(r"--[^\n]*", "", source)
    if re.search(r"^\s*import\s+(?:qualified\s+)?Amoebius\.Formal\.Explore\b", uncommented, re.M):
        raise GateFailure("explicit-state checker delegates to the Phase-12 explorer")
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', uncommented)
    prohibited = re.compile(
        r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeDupablePerformIO|lookupEnv|getEnv|readFile|getLine)\b"
    )
    found = prohibited.search(stripped)
    if found:
        raise GateFailure(f"checker source contains prohibited token {found.group(1)!r}")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    stanza = re.search(
        r"library explicit-state-checker\n(?P<body>.*?)(?=\n(?:library|executable|test-suite|benchmark) |\Z)",
        cabal,
        re.S,
    )
    if stanza is None:
        raise GateFailure("standalone explicit-state-checker library stanza is missing")
    body = stanza.group("body")
    if "src/explicit-state-checker" not in body or "amoebius:formal-model" not in body:
        raise GateFailure("checker must use its dedicated root and consume formal-model")
    if "-Werror=incomplete-patterns" not in body:
        raise GateFailure("checker incomplete-pattern totality option is missing")


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
        "toy-safe-status": 'toy-safe status: expected "safe"',
        "unsafe-counter-status": 'unsafe-counter status: expected "unsafe-invariant"',
        "toy-safe-distinct-states": "toy-safe distinct states: expected 8",
    }
    for row in mutants:
        details = dict(pair.split("=", 1) for pair in row["detail"].split(";"))
        locus = details["expected_red_locus"]
        binary = build_suite(cabal, [f"-f{row['flag']}"])
        outcome = run_suite(binary)
        red = outcome.returncode != 0 and expected_text[locus] in outcome.stdout
        logs.append(f"{row['mutant']}: red={red}\n{outcome.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {row['mutant']:<24} {locus}")
        passed = passed and red
    (gate.run_dir / "mutants.log").write_text("\n".join(logs), encoding="utf-8")
    return passed


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=12,
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
        resolved = toolchain.resolve(["cabal", "ghc"])
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = resolved["cabal"]["path"]
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<10} satisfies {record['requirement']}")
        results["toolchain"] = True
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)

        print("\noracle side — seven independently enumerated models\n")
        oracle, mutant_rows = verify_oracle()
        print(f"  ok    model-oracle-complete       {len(oracle)} fixtures, four result classes")
        print(f"  ok    mutant-registry-complete    {len(mutant_rows)} seeded defects")
        results["oracle"] = True

        print("\nboundary side — independent dedicated-root checker\n")
        verify_boundary()
        print("  ok    checker-does-not-import-explorer")
        print("  ok    checker-source-total")
        results["boundary"] = True

        print("\nsuite side — verdicts, bounds, parity, traces, and digest binding\n")
        clean_binary = build_suite(cabal, [])
        suite = run_suite(clean_binary)
        (gate.run_dir / "suite.log").write_text(suite.stdout, encoding="utf-8")
        if suite.returncode != 0 or ACCEPTANCE not in suite.stdout:
            raise GateFailure(f"suite acceptance token is absent:\n{suite.stdout}")
        print("  ok    suite-acceptance-token      7 fixtures, 5 parity rows, 2 trace replays")
        results["suite"] = True

        print("\nmutant side — guard, invariant, and frontier defects\n")
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
        print(f"explicit-state-checker-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if COMPILER and resolved:
            build = cabal_command(resolved["cabal"]["path"], "build", SUITE)
            run(build, require_success=False)

    layers = {
        "Decision": "tested" if rows.get("explorer-parity-count") == "5" else "UNVERIFIED",
        "Protocol": "proven-for-the-model" if rows.get("safe-count") == "4" else "UNVERIFIED",
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
            if name != "platform"
        },
        dependencies={SUITE: "cabal build", "formal-model": "Phase-12 interpreter semantics"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "explicit-state mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
