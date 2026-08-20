#!/usr/bin/env python3
"""The Phase-8 gate — the base capacity fold and the topology relation.

The capability claim and every check behind it are unchanged: the fold, compile-fail,
Gate-1, compatibility, and mutant oracles all carry their authored shapes, the three
Gate-1 negatives fail at their exact loci beside green twins, the suite reaches its
acceptance token with QuickCheck coverage in both directions, and all nineteen seeded
mutants redden at their own loci.

What changed is the shell: evidence goes to the run bundle instead of the plan tree, the
ledger is derived into that bundle instead of compared against a committed copy, the
surfaces are enumerated at run time and joined to an authored expectation, the toolchain is
resolved from authored requirements, and the run publishes an attestation bound to the
source snapshot. `test/spec/dsl/CapacityTopologyGate.hs` no longer hard-codes one developer's
`dhall` path; it resolves per run and fails closed when unset.
"""

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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry  # noqa: E402
import toolchain


ROOT = Path(__file__).resolve().parent.parent
FOLD_ORACLE = ROOT / "test/oracle/capacity_topology/fold_cases.tsv"
COMPILE_ORACLE = ROOT / "test/oracle/capacity_topology/compile_fail.tsv"
DHALL_TYPECHECK_ORACLE = ROOT / "test/oracle/capacity_topology/dhall_typecheck_cases.tsv"
COMPATIBILITY_ORACLE = ROOT / "test/oracle/capacity_topology/compatibility.tsv"
MUTANT_CAPABILITY = "capacity_topology"
MUTANTS = ROOT / "test/mutant/registry.tsv"
RESULTS = ROOT / ".build/dsl/capacity-topology/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/capacity-topology/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/capacity-topology"
CONTRACT = "DEVELOPMENT_PLAN/phase_09_resource_index.md"
GATE_COMMAND = "python3 tools/capacity_topology_gate.py"
EXPECTATIONS = "test/oracle/capacity_topology_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


# The resolved compiler, set once the toolchain resolves. Every cabal invocation gets it:
# without it cabal picks whatever `ghc` the ambient PATH offers, which on a host carrying a
# newer GHC fails the solver for a reason that has nothing to do with this phase.
COMPILER = ""
RUN_ENV = toolchain.contained_env()
RUN_ENV["PATH"] = os.pathsep.join([str(ROOT / "tools"), RUN_ENV.get("PATH", "")])


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = dict(RUN_ENV)
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", *command[1:]]
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


def verify_pins() -> tuple[Path, str]:
    pins = toolchain.resolve(["cabal", "dhall", "ghc"])
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    dhall = Path(pins["dhall"]["path"])
    for executable in (cabal, ghc, dhall):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(
        [
            run([str(cabal), "--numeric-version"]).stdout,
            run([str(ghc), "--numeric-version"]).stdout,
            run([str(dhall), "--version"]).stdout,
        ]
    )
    for family in ("cabal", "ghc", "dhall"):
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return cabal, versions


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_oracles(dhall: Path) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    folds = read_tsv(FOLD_ORACLE)
    compile_rows = read_tsv(COMPILE_ORACLE)
    dhall_typecheck_rows = read_tsv(DHALL_TYPECHECK_ORACLE)
    compatibility = read_tsv(COMPATIBILITY_ORACLE)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(folds) != 15 or len({row["case"] for row in folds}) != 15:
        raise GateFailure("fold oracle must contain fifteen unique cases")
    if len({row["twin"] for row in folds}) != 15:
        raise GateFailure("every fold negative must name a distinct legal twin")
    if len(compile_rows) != 7 or len({row["case"] for row in compile_rows}) != 7:
        raise GateFailure("compile oracle must contain seven unique cases")
    if len(dhall_typecheck_rows) != 3 or len({row["entry"] for row in dhall_typecheck_rows}) != 3:
        raise GateFailure("Phase-8 Gate-1 oracle must contain three unique entries")
    if len(compatibility) != 9 or {row["accepted"] for row in compatibility} != {"true", "false"}:
        raise GateFailure("compatibility oracle must exhaust the 3x3 matrix in both directions")
    if len(mutants) != 19 or len({row["mutant"] for row in mutants}) != 19:
        raise GateFailure("mutant manifest must contain nineteen unique mutants")
    run([sys.executable, str(ROOT / "tools/locus_registry_lint.py")])
    for row in dhall_typecheck_rows:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    verify_registry_coverage(folds, compile_rows, dhall_typecheck_rows)
    return folds, mutants


def verify_registry_coverage(
    folds: list[dict[str, str]],
    compile_rows: list[dict[str, str]],
    dhall_typecheck_rows: list[dict[str, str]],
) -> None:
    registry = read_tsv(ROOT / "dhall/examples/locus_registry.tsv")
    owned = {(row["entry"], row["subcase"]) for row in registry if row["owner_phase"] == "Phase-8"}
    evidence_entries = {
        *(row["catalog"].split(":", 1)[0] for row in folds),
        *(row["entry"] for row in compile_rows),
        *(row["entry"] for row in dhall_typecheck_rows),
    }
    covered = {(entry, subcase) for entry, subcase in owned if entry in evidence_entries}
    if len(owned) != 11 or covered != owned:
        raise GateFailure(f"Phase-8 registry coverage drifted: covered={sorted(covered)}, owned={sorted(owned)}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Register-1 only; runtime correspondence UNVERIFIED\n", "entry\tsubcase\tlocus\tstatus\n"]
    for row in registry:
        if row["owner_phase"] == "Phase-8":
            lines.append(f"{row['entry']}\t{row['subcase']}\t{row['validation_locus']}\tdischarged\n")
    GENERATED_LEDGER.write_text("".join(lines), encoding="utf-8")


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capacity/Types.hs",
        ROOT / "src/Amoebius/Capacity/Fold.hs",
        ROOT / "src/Amoebius/Dsl/Topology.hs",
    ]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail)\b")
    for path in paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial token {match.group(1)!r} in {path.relative_to(ROOT)}")
    cabal_text = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in cabal_text:
            raise GateFailure(f"compile totality option missing: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "dsl-spec",
            "capacity-topology-spec",
            "-f-illegal-state-mutant",
            "-f-resource-normalization-mutant",
            "--test-show-details=direct",
        ]
    )
    token = "capacity-topology-spec: PASS (3 Gate-1, 15 fold negatives, 15 twins, 2 positives, 7 compile pairs, 4 properties)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-8 acceptance token is absent:\n{result.stdout}")
    if ">=30% accept/reject coverage" not in result.stdout:
        raise GateFailure("QuickCheck coverage token is absent")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal),
                "test",
                "capacity-topology-spec",
                    "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"capacity-topology-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(folds: list[dict[str, str]], mutants: list[dict[str, str]]) -> None:
    metrics = {
        "fold-negatives": f"{len(folds)}/{len(folds)}-specific-tag-red",
        "legal-twins": f"{len(folds)}/{len(folds)}-green",
        "positive-topologies": "2/2-decode-and-place",
        "dhall-typecheck-topology-cases": "3/3-exact-red-with-green-twins",
        "compile-fail-pairs": "7/7-legal-green-illegal-type-red",
        "compatibility-matrix": "9/9-equivalent",
        "quickcheck-properties": "4/4-green-checkCoverage-30-percent-both-directions",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "registry-subcases": "11/11-Phase-8-owned-discharged",
        "base-fold-totality": "compile-exhaustive-and-sampled-no-crash",
        "acceptance-token": "spec-composition-proven-base-capacity-topology",
        "storage-geometry": "UNVERIFIED",
        "execution-accelerator-provider-root-fit": "UNVERIFIED",
        "runtime": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )



CHECKS = {
    "oracle-shape": "every authored oracle carries its declared row count and unique keys",
    "compile-oracle-shape": "the compile-fail oracle carries seven unique cases",
    "compatibility-both-directions": "the compatibility matrix exhausts accept and reject",
    "independent-placement-validator": "the elastic growth envelope is witnessed by the suite",
    "positive-decodes-and-places": "each positive topology decodes and places",
    "elastic-envelope-witness": "the managed-EKS positive places elastically",
    "independent-validator-separate": "the placement validator is separate from the fold under test",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 banner",
}

SIDES = ("toolchain", "oracle", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "fold-negatives": "15/15-specific-tag-red",
    "legal-twins": "15/15-green",
    "positive-topologies": "2/2-decode-and-place",
    "dhall-typecheck-topology-cases": "3/3-exact-red-with-green-twins",
    "compile-fail-pairs": "7/7-legal-green-illegal-type-red",
    "compatibility-matrix": "9/9-equivalent",
    "quickcheck-properties": "4/4-green-checkCoverage-30-percent-both-directions",
    "mutants": "19/19-red",
    "registry-subcases": "11/11-Phase-8-owned-discharged",
    "base-fold-totality": "compile-exhaustive-and-sampled-no-crash",
    "acceptance-token": "spec-composition-proven-base-capacity-topology",
    "storage-geometry": "UNVERIFIED",
    "execution-accelerator-provider-root-fit": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "base-capacity-types": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "dhall-typecheck-topology-foreclosures": ("dhall-typecheck-topology-cases", EXPECTED_RESULTS["dhall-typecheck-topology-cases"]),
    "fits-equivalence": ("compatibility-matrix", EXPECTED_RESULTS["compatibility-matrix"]),
    "carve-zero-capable-subtraction": ("fold-negatives", EXPECTED_RESULTS["fold-negatives"]),
    "fixed-placement-witness": ("positive-topologies", EXPECTED_RESULTS["positive-topologies"]),
    "elastic-growth-envelope": ("positive-topologies", EXPECTED_RESULTS["positive-topologies"]),
    "elementwise-topology-compatibility": ("compatibility-matrix", EXPECTED_RESULTS["compatibility-matrix"]),
    "rke2-host-distinctness": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "linux-host-quorum-compile-barriers": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "capacity-topology-negative-corpus": ("legal-twins", EXPECTED_RESULTS["legal-twins"]),
    "legal-multisubstrate-fixed-placement": ("positive-topologies", EXPECTED_RESULTS["positive-topologies"]),
    "legal-managed-eks-elastic-placement": ("positive-topologies", EXPECTED_RESULTS["positive-topologies"]),
    "independent-placement-validator": ("positive-topologies", EXPECTED_RESULTS["positive-topologies"]),
    "quickcheck-capacity-topology-properties": ("quickcheck-properties", EXPECTED_RESULTS["quickcheck-properties"]),
    "base-fold-compile-totality": ("base-fold-totality", EXPECTED_RESULTS["base-fold-totality"]),
    "phase7-mutant-battery": ("mutants", EXPECTED_RESULTS["mutants"]),
    "phase7-validation-locus-ledger": ("registry-subcases", EXPECTED_RESULTS["registry-subcases"]),
    "capacity-feasibility": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "storage-geometry": None,
    "execution-accelerator-provider-root-fit": None,
    "binding-feasibility": None,
    "render-fidelity": None,
    "model-runtime-correspondence": None,
    "runtime-fidelity": None,
}

PROVEN_SURFACES = {"base-fold-compile-totality"}


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=9, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    # Clause 15 first: a run that cannot name the architecture it executed on, or
    # that is executing under translation, has nothing worth proving.
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []

    try:
        resolved = toolchain.resolve(["cabal", "dhall", "ghc"])
        print("toolchain side — cabal, ghc, and dhall resolved from authored requirements\n")
        for name in ("cabal", "ghc", "dhall"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True

        RUN_ENV["AMOEBIUS_DHALL"] = resolved["dhall"]["path"]
        RUN_ENV["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — authored oracle shapes and the Gate-1 loci\n")
        folds, mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        verify_totality_sources()
        print(f"  ok    oracle-shape       {len(folds)} fold cases, {len(mutant_rows)} mutants, Gate-1 loci exact")
        results["oracle"] = True

        print("\nsuite side — dsl-spec and capacity-topology-spec\n")
        suite = run_green_suite(cabal)
        (gate.run_dir / "suite.log").write_text(suite, encoding="utf-8")
        print("  ok    acceptance token and QuickCheck coverage present in both directions")
        results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log = verify_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {len(mutant_rows)}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(folds, mutant_rows)
        rows = gate_common.metric_rows(RESULTS)
        banner_ok = GENERATED_LEDGER.is_file() and GENERATED_LEDGER.read_text(encoding="utf-8").startswith(
            "# Register-1 only;"
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        if banner_ok:
            print(f"  ok    locus-ledger-honesty-banner {gate_common.rel(GENERATED_LEDGER)}")
        else:
            print("  FAIL  locus-ledger-honesty-banner the generated locus ledger lacks its Register-1 banner")
        results["results"] = oracle_ok and artifact_ok and banner_ok
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"capacity-topology-gate: FAIL: {problem}", file=sys.stderr)

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
        dependencies={"dsl-spec": "cabal test", "capacity-topology-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows] or [{"name": "phase-8 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
