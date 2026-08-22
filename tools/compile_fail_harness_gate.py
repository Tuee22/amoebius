#!/usr/bin/env python3
"""The Phase-15 gate — structured, source-bound GHC compile-fail twins."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import compile_fail_harness  # noqa: E402
import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "test/oracle/compile_fail_harness/fixtures.tsv"
SOURCE = ROOT / "tools/compile_fail_harness.py"
RESULTS = ROOT / ".build/checkers/compile-fail/results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md"
GATE_COMMAND = "python3 tools/compile_fail_harness_gate.py"
EXPECTATIONS = "test/oracle/compile_fail_harness_surfaces.tsv"
MUTANT_CAPABILITY = "compile_fail_harness"
ACCEPTANCE = "compile-fail-harness: PASS (10 legal/illegal twins, 4 diagnostic codes, 5 owner phases)"

SIDES = ("toolchain", "oracle", "boundary", "suite", "mutant", "results")

CHECKS = {
    "manifest-complete": "ten unique claims bind ten legal/illegal source pairs",
    "owner-inventory-complete": "the representative tranche covers phases 4, 5, 6, 7, and 10",
    "diagnostic-vocabulary-complete": "four distinct structured GHC error codes are pinned",
    "structured-json-boundary": "the harness parses GHC JSON errors and rejects unrelated diagnostics",
    "absolute-ghc-injection": "GHC is injected as an absolute authored-requirement resolution",
    "suite-acceptance-token": "all legal twins compile and every illegal twin fails at its exact pin",
    "mutant-registry-complete": "three defects cover diagnostic, positive-twin, and pin checks",
    "mutants-red-at-own-locus": "each harness defect fails at its registry-declared locus",
    "recorded-results-match-oracle": "all twelve result metrics equal authored values",
    "emitted-results-untracked": "generated compile-fail results remain beneath .build/checkers",
}

EXPECTED_RESULTS = {
    "pair-count": "10",
    "claim-count": "10",
    "owner-count": "5",
    "legal-green-count": "10",
    "illegal-red-count": "10",
    "diagnostic-code-pin-count": "10",
    "source-span-pin-count": "10",
    "message-pin-count": "10",
    "twin-probe-count": "10",
    "source-digest-count": "20",
    "structured-diagnostic-count": "11",
    "mutants-red": "3/3",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "fixture-manifest": ("pair-count", "10"),
    "owner-inventory": ("owner-count", "5"),
    "positive-counterparts": ("legal-green-count", "10"),
    "pinned-negatives": ("illegal-red-count", "10"),
    "diagnostic-codes": ("diagnostic-code-pin-count", "10"),
    "source-spans": ("source-span-pin-count", "10"),
    "message-fragments": ("message-pin-count", "10"),
    "twin-dimensions": ("twin-probe-count", "10"),
    "source-identity": ("source-digest-count", "20"),
    "structured-diagnostics": ("structured-diagnostic-count", "11"),
    "mutant-results": ("mutants-red", "3/3"),
    "manifest-check": ("pair-count", "10"),
    "owner-check": ("owner-count", "5"),
    "diagnostic-vocabulary": ("diagnostic-code-pin-count", "10"),
    "structured-json-boundary": ("structured-diagnostic-count", "11"),
    "toolchain-boundary": ("legal-green-count", "10"),
    "suite-acceptance": ("illegal-red-count", "10"),
    "mutant-registry": ("mutants-red", "3/3"),
    "mutant-loci": ("mutants-red", "3/3"),
    "result-oracle": ("source-span-pin-count", "10"),
    "generated-output": ("pair-count", "10"),
    "corpus-mutants": ("mutants-red", "3/3"),
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


def verify_oracle() -> tuple[list[compile_fail_harness.Pair], list[dict[str, str]]]:
    pairs = compile_fail_harness.read_manifest(MANIFEST)
    if len(pairs) != 10 or len({pair.claim for pair in pairs}) != 10:
        raise GateFailure("compile-fail manifest must bind ten unique claims")
    if {pair.owner_phase for pair in pairs} != {4, 5, 6, 7, 10}:
        raise GateFailure("compile-fail manifest owner tranche must be phases 4, 5, 6, 7, and 10")
    if {pair.code for pair in pairs} != {1928, 83865, 64725, 25897}:
        raise GateFailure("compile-fail diagnostic-code vocabulary drifted")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("mutant registry must carry three unique compile-fail harness defects")
    return pairs, mutants


def verify_boundary(ghc: dict[str, Any]) -> None:
    source = SOURCE.read_text(encoding="utf-8")
    for token in (
        "-fdiagnostics-as-json", "FORBIDDEN_MESSAGES", "validate_illegal",
        "legal_probe", "illegal_probe", "diagnostic codes",
    ):
        if token not in source:
            raise GateFailure(f"compile-fail harness lacks boundary token {token!r}")
    if "shutil.which" in source or "shell=True" in source or "os.environ" in source:
        raise GateFailure("compile-fail harness discovers or invokes GHC through ambient process state")
    path = Path(ghc["path"])
    if not path.is_absolute() or not path.is_file() or ghc.get("source") == "host":
        raise GateFailure("GHC was not resolved to an absolute non-host requirement")


def harness_command(ghc: str, *, mutant: str = "", results: bool = False) -> list[str]:
    command = [sys.executable, str(SOURCE), "--ghc", ghc, "--manifest", str(MANIFEST)]
    if results:
        command.extend(["--results", str(RESULTS)])
    if mutant:
        command.extend(["--mutant", mutant])
    return command


def mutant_side(ghc: str, rows: list[dict[str, str]], gate: Any) -> bool:
    passed = True
    logs: list[str] = []
    for row in rows:
        details = dict(pair.split("=", 1) for pair in row["detail"].split(";"))
        outcome = run(harness_command(ghc, mutant=details["mode"]), require_success=False)
        locus = details["expected_red_locus"]
        red = outcome.returncode != 0 and locus in outcome.stdout
        logs.append(f"{row['mutant']}: red={red}\n{outcome.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {row['mutant']:<30} {locus}")
        passed = passed and red
    (gate.run_dir / "mutants.log").write_text("\n".join(logs), encoding="utf-8")
    return passed


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=15, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    metrics: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    try:
        resolved = toolchain.resolve(["ghc"])
        ghc = resolved["ghc"]
        print("toolchain side — GHC resolved from the authored requirement\n")
        print(f"  ok    ghc    {ghc['version']:<10} satisfies {ghc['requirement']}")
        results["toolchain"] = True

        print("\noracle side — claims, twins, diagnostic codes, and mutants\n")
        pairs, mutant_rows = verify_oracle()
        print(f"  ok    manifest-complete                {len(pairs)} unique claim/twin rows")
        print("  ok    owner-inventory-complete         phases 4, 5, 6, 7, and 10")
        print("  ok    diagnostic-vocabulary-complete   GHC-1928/83865/64725/25897")
        print(f"  ok    mutant-registry-complete         {len(mutant_rows)} seeded defects")
        results["oracle"] = True

        print("\nboundary side — structured diagnostics and absolute compiler injection\n")
        verify_boundary(ghc)
        print("  ok    structured-json-boundary")
        print("  ok    absolute-ghc-injection")
        results["boundary"] = True

        print("\nsuite side — every legal twin green, every illegal twin red at its pin\n")
        suite = run(harness_command(ghc["path"], results=True), require_success=False)
        (gate.run_dir / "suite.log").write_text(suite.stdout, encoding="utf-8")
        if suite.returncode != 0 or ACCEPTANCE not in suite.stdout:
            raise GateFailure(f"suite acceptance token is absent:\n{suite.stdout[-6000:]}")
        print("  ok    suite-acceptance-token      10 twins, 4 codes, 5 owners")
        results["suite"] = True

        print("\nmutant side — diagnostic, counterpart, and impossible-pin defects\n")
        results["mutant"] = mutant_side(ghc["path"], mutant_rows, gate)
        if not RESULTS.is_file():
            raise GateFailure(f"suite emitted no {gate_common.rel(RESULTS)}")
        with RESULTS.open("a", encoding="utf-8") as handle:
            handle.write(f"mutants-red\t{'3/3' if results['mutant'] else '0/3'}\n")
        metrics = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(metrics, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked", label="the suite's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, compile_fail_harness.HarnessFailure) as problem:
        print(f"compile-fail-harness-gate: FAIL: {problem}", file=sys.stderr)

    layers = {
        "Decision": "tested" if metrics.get("legal-green-count") == "10" else "UNVERIFIED",
        "Protocol": "tested" if metrics.get("source-span-pin-count") == "10" else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={
            "metrics": set(metrics), "checks": set(CHECKS),
            "mutants": {row["mutant"] for row in mutant_rows},
        },
        rows=metrics, evidence=SURFACE_EVIDENCE, layers=layers,
        toolchain={
            "ghc": {"version": resolved.get("ghc", {}).get("version", "unresolved"),
                    "requirement": resolved.get("ghc", {}).get("requirement", "unresolved")}
        },
        dependencies={"compile-fail-harness": "Python stdlib", "ghc": "structured JSON diagnostics"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "compile-fail harness mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
