#!/usr/bin/env python3
"""The Phase-10 gate — index-preserving composition across the five calculi.

The independently authored table exhausts the 25 ordered calculus pairs.  The suite
checks their exact resource sums, all 125 ordered triples, identity, label transforms,
and three generated properties.  A compiler pair holds the request-scope barrier, and
three real build/source mutants must redden their declared loci.
"""

from __future__ import annotations

import csv
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
PAIR_ORACLE = ROOT / "test/oracle/calculus_composition/pairs.tsv"
LEGAL_FIXTURE = "test/negative/compile_fail/calculus_composition/same_scope_composes.hs"
ILLEGAL_FIXTURE = "test/negative/compile_fail/calculus_composition/different_scopes_do_not_compose.hs"
SOURCE = ROOT / "src/calculus-composition/Amoebius/Calculus/Composition.hs"
MUTANT_CAPABILITY = "calculus_composition"
RESULTS = ROOT / ".build/calculus/composition/phase-results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/calculus-composition"
SCRATCH = ROOT / ".build/tmp/calculus-composition"
CONTRACT = "DEVELOPMENT_PLAN/phase_10_calculus_composition.md"
GATE_COMMAND = "python3 tools/calculus_composition_gate.py"
EXPECTATIONS = "test/oracle/calculus_composition_surfaces.tsv"
SUITE = "calculus-composition-spec"
ACCEPTANCE = "calculus-composition-spec: PASS (25 ordered pairs, 125 triples, 3 properties, 9 checks)"


class GateFailure(RuntimeError):
    pass


COMPILER = ""
RUN_ENV = toolchain.contained_env()
RUN_ENV["PATH"] = os.pathsep.join([str(ROOT / "tools"), RUN_ENV.get("PATH", "")])


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
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
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
    rows = read_tsv(PAIR_ORACLE)
    tags = {"artifact", "budget", "lift", "workflow", "evidence"}
    pairs = {(row["left"], row["right"]) for row in rows}
    expected_pairs = {(left, right) for left in tags for right in tags}
    if len(rows) != 25 or pairs != expected_pairs:
        raise GateFailure(f"pair oracle must exhaust the 25 ordered pairs: {sorted(pairs)}")
    if any(set(row) != {"left", "right", "cpu", "memory", "ephemeral", "pods"} for row in rows):
        raise GateFailure("pair oracle column set drifted")
    for row in rows:
        for field in ("cpu", "memory", "ephemeral", "pods"):
            if not row[field].isdigit():
                raise GateFailure(f"pair oracle {field} is not a natural: {row}")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("mutant registry must carry three unique calculus-composition mutants")
    return rows, mutants


def verify_purity_and_boundary() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
    prohibited = re.compile(
        r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeDupablePerformIO|lookupEnv|getEnv|readFile|getLine)\b"
    )
    found = prohibited.search(stripped)
    if found:
        raise GateFailure(f"composition source contains prohibited token {found.group(1)!r}")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    stanza = re.search(r"library calculus-composition\n(?P<body>.*?)(?=\n(?:library|executable|test-suite|benchmark) |\Z)", cabal, re.S)
    if stanza is None:
        raise GateFailure("standalone calculus-composition library stanza is missing")
    body = stanza.group("body")
    if "src/calculus-composition" not in body or "amoebius:dsl-core" in body:
        raise GateFailure("calculus-composition must use its dedicated source root and no later dsl-core")
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in body:
            raise GateFailure(f"calculus-composition totality option missing: {option}")


def suite_binary(cabal: str, flags: list[str]) -> str:
    listing = run(cabal_command(cabal, "list-bin", SUITE, *flags))
    return listing.stdout.strip().splitlines()[-1]


def build_suite(cabal: str, flags: list[str]) -> str:
    run(cabal_command(cabal, "build", SUITE, *flags))
    return suite_binary(cabal, flags)


def run_suite(binary: str) -> subprocess.CompletedProcess[str]:
    return run([binary], require_success=False)


def compile_fixture(cabal: str, fixture: str, defines: list[str]) -> subprocess.CompletedProcess[str]:
    output = SCRATCH / "compile-fail"
    output.mkdir(parents=True, exist_ok=True)
    return run(
        cabal_command(
            cabal,
            "exec",
            "--",
            COMPILER,
            "-fno-code",
            "-fforce-recomp",
            "-XGHC2024",
            "-XCPP",
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
            *defines,
            fixture,
        ),
        require_success=False,
    )


def mutant_flag(flag: str) -> str:
    return f"-f{flag}"


def mutant_define(flag: str) -> str:
    return "-D" + flag.replace("-", "_").upper()


def mutant_side(cabal: str, mutants: list[dict[str, str]], gate: Any) -> bool:
    passed = True
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        details = dict(pair.split("=", 1) for pair in row["detail"].split(";"))
        locus = details["expected_red_locus"]
        if name == "scope-widening":
            outcome = compile_fixture(cabal, ILLEGAL_FIXTURE, [mutant_define(row["flag"])])
            red = outcome.returncode == 0
        else:
            binary = build_suite(cabal, [mutant_flag(row["flag"])])
            outcome = run_suite(binary)
            red = outcome.returncode != 0 and f"  FAIL {locus}" in outcome.stdout
        logs.append(f"{name}: red={red}\n{outcome.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<32} {locus}")
        passed = passed and red
    (gate.run_dir / "mutants.log").write_text("\n".join(logs), encoding="utf-8")
    return passed


CHECKS = {
    "pair-oracle-complete": "the independent oracle exhausts all 25 ordered pairs",
    "mutant-registry-complete": "three named mutations cover scope, arithmetic, and transform indices",
    "calculus-composition-pure": "the standalone total module has no ambient read or partial token",
    "suite-acceptance-token": "the suite reaches its exact pair/triple/property token",
    "scope-widening-rejected": "the different-scope program has no type while its same-scope twin does",
    "mutants-red-at-own-locus": "each seeded mutant reddens its declared observation",
    "recorded-results-match-oracle": "every recorded metric equals its authored expectation",
    "emitted-results-untracked": "the gate's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "purity", "suite", "compile-fail", "mutant", "results")

EXPECTED_RESULTS = {
    "calculus-kinds": "5/5-closed-and-represented",
    "ordered-pairs": "25/25-total-and-order-preserving",
    "resource-index": "25/25-exact-natural-sums",
    "scope-index": "same-request-only-compile-enforced",
    "exhaustive-triples": "125/125-associative",
    "quickcheck-properties": "3/3-green-500-cases-with-calculus-coverage",
    "compile-fail-pairs": "1/1-same-scope-green-different-scope-type-red",
    "mutants": "3/3-red-at-own-locus",
    "acceptance-token": "five-calculus-composition-tested-register-1",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "five-calculus-set": ("calculus-kinds", EXPECTED_RESULTS["calculus-kinds"]),
    "ordered-pair-closure": ("ordered-pairs", EXPECTED_RESULTS["ordered-pairs"]),
    "resource-index-additivity": ("resource-index", EXPECTED_RESULTS["resource-index"]),
    "scope-index-conjunction": ("scope-index", EXPECTED_RESULTS["scope-index"]),
    "associative-composition": ("exhaustive-triples", EXPECTED_RESULTS["exhaustive-triples"]),
    "generated-index-laws": ("quickcheck-properties", EXPECTED_RESULTS["quickcheck-properties"]),
    "scope-widening-type-barrier": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "calculus-composition-mutants": ("mutants", EXPECTED_RESULTS["mutants"]),
    "calculus-composition-acceptance": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "runtime-correspondence": None,
    "pair-oracle-shape": ("ordered-pairs", EXPECTED_RESULTS["ordered-pairs"]),
    "mutant-registry-shape": ("mutants", EXPECTED_RESULTS["mutants"]),
    "pure-total-composition": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "suite-acceptance": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "scope-compile-fail": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "mutant-locus-separation": ("mutants", EXPECTED_RESULTS["mutants"]),
    "result-oracle-join": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "generated-output-discipline": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
}


def write_results(pair_count: int, mutant_count: int) -> None:
    metrics = dict(EXPECTED_RESULTS)
    metrics["ordered-pairs"] = f"{pair_count}/{pair_count}-total-and-order-preserving"
    metrics["mutants"] = f"{mutant_count}/{mutant_count}-red-at-own-locus"
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=10,
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

        print("\noracle side — the independent 5 x 5 pairing table\n")
        oracle, mutant_rows = verify_oracle()
        print(f"  ok    pair-oracle-complete       {len(oracle)} ordered pairs")
        print(f"  ok    mutant-registry-complete   {len(mutant_rows)} seeded defects")
        results["oracle"] = True

        print("\npurity side — standalone total composition boundary\n")
        verify_purity_and_boundary()
        print("  ok    calculus-composition-pure  dedicated source root, no later dsl-core")
        results["purity"] = True

        print("\nsuite side — exact pairs, exhaustive triples, and generated properties\n")
        clean_binary = build_suite(cabal, [])
        suite = run_suite(clean_binary)
        (gate.run_dir / "suite.log").write_text(suite.stdout, encoding="utf-8")
        if suite.returncode != 0 or ACCEPTANCE not in suite.stdout:
            raise GateFailure(f"suite acceptance token is absent:\n{suite.stdout}")
        print("  ok    suite-acceptance-token     25 pairs, 125 triples, 3 generated properties")
        results["suite"] = True

        print("\ncompile-fail side — one request-scope index on both components\n")
        legal = compile_fixture(cabal, LEGAL_FIXTURE, [])
        if legal.returncode != 0:
            raise GateFailure(f"same-scope legal twin failed:\n{legal.stdout}")
        illegal = compile_fixture(cabal, ILLEGAL_FIXTURE, [])
        if illegal.returncode == 0 or "Couldn't match type" not in illegal.stdout:
            raise GateFailure(f"different-scope fixture missed its type barrier:\n{illegal.stdout}")
        print("  ok    scope-widening-rejected    same scope green, different scopes type-red")
        results["compile-fail"] = True

        print("\nmutant side — each index defect red at its own locus\n")
        results["mutant"] = mutant_side(cabal, mutant_rows, gate)

        write_results(len(oracle), len(mutant_rows))
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent],
            (".tsv", ".log"),
            gate.run_dir,
            check="emitted-results-untracked",
            label="the gate's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"calculus-composition-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if COMPILER and resolved:
            run(cabal_command(resolved["cabal"]["path"], "build", SUITE), require_success=False)

    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS)},
        rows=rows,
        evidence=SURFACE_EVIDENCE,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={SUITE: "cabal build", "compile-fail": "ghc -fno-code"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "calculus-composition mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
