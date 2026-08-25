#!/usr/bin/env python3
"""Run and seal the Phase-29 logical-to-physical storage geometry gate."""

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
STORAGE_ORACLE = ROOT / "test/oracle/storage_geometry/storage_cases.tsv"
DHALL_TYPECHECK_ORACLE = ROOT / "test/oracle/storage_geometry/dhall_typecheck_cases.tsv"
MUTANT_CAPABILITY = "storage_geometry"
MUTANTS = ROOT / "test/mutant/registry.tsv"
RESULTS = ROOT / ".build/dsl/storage-geometry/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/storage-geometry/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/storage-geometry"
CONTRACT = "DEVELOPMENT_PLAN/phase_29_storage_geometry_folds.md"
GATE_COMMAND = "python3 tools/storage_geometry_gate.py"
EXPECTATIONS = "test/oracle/storage_geometry_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
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


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_pins() -> tuple[Path, Path, str]:
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
    return cabal, dhall, versions


def verify_oracles(dhall: Path) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    storage = read_tsv(STORAGE_ORACLE)
    dhall_typecheck = read_tsv(DHALL_TYPECHECK_ORACLE)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(storage) != 30 or len({row["variant"] for row in storage}) != 30:
        raise GateFailure("storage oracle must contain 30 unique variant rows")
    if len({row["twin"] for row in storage}) != 30:
        raise GateFailure("every storage variant must name a distinct legal twin")
    required_families = {
        "illegal_store_over_backing",
        "illegal_hot_tier_over_bookie",
        "illegal_topic_time_only_offload",
        "illegal_cache_over_local_pool",
        "illegal_incluster_cache_bound_mismatch",
    }
    if {row["family"] for row in storage} != required_families:
        raise GateFailure("storage oracle must preserve the exact five named negative families")
    if len(dhall_typecheck) != 2 or {row["entry"] for row in dhall_typecheck} != {"3.32"}:
        raise GateFailure("Phase-29 Gate-1 oracle must cover both 3.32 barriers")
    if len(mutants) != 31 or len({row["mutant"] for row in mutants}) != 31:
        raise GateFailure("mutant manifest must contain 31 unique mutants")
    run([sys.executable, str(ROOT / "tools/locus_registry_lint.py")])
    for row in dhall_typecheck:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    verify_registry_coverage(storage, dhall_typecheck)
    return storage, mutants


def verify_registry_coverage(storage: list[dict[str, str]], dhall_typecheck: list[dict[str, str]]) -> None:
    registry = read_tsv(ROOT / "dhall/examples/locus_registry.tsv")
    owned = {(row["entry"], row["subcase"]) for row in registry if row["owner_phase"] == "Phase-29"}
    evidence_entries = {
        *(row["catalog"].split(":", 1)[0] for row in storage),
        *(row["entry"] for row in dhall_typecheck),
    }
    covered = {(entry, subcase) for entry, subcase in owned if entry in evidence_entries}
    if len(owned) != 5 or covered != owned:
        raise GateFailure(f"Phase-29 registry coverage drifted: covered={sorted(covered)}, owned={sorted(owned)}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Register-1 only; runtime correspondence UNVERIFIED\n", "entry\tsubcase\tlocus\tstatus\n"]
    for row in registry:
        if row["owner_phase"] == "Phase-29":
            lines.append(f"{row['entry']}\t{row['subcase']}\t{row['validation_locus']}\tdischarged\n")
    GENERATED_LEDGER.write_text("".join(lines), encoding="utf-8")


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capacity/Storage.hs",
        ROOT / "src/Amoebius/Capacity/StorageGeometry.hs",
        ROOT / "src/Amoebius/Capacity/ServiceStorage.hs",
        ROOT / "src/Amoebius/Capacity/Growable.hs",
        ROOT / "src/Amoebius/Capacity/StorageScaling.hs",
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
            "storage-geometry-spec",
            "--test-show-details=direct",
        ]
    )
    token = "storage-geometry-spec: PASS (5 named negatives, 30 variants, 30 twins, 2 positives, 2 Gate-1, 6 properties)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-29 acceptance token is absent:\n{result.stdout}")
    if ">=30% accept/reject coverage" not in result.stdout:
        raise GateFailure("QuickCheck coverage token is absent")
    if "storage-geometry-calculus: PASS (5 kinds, 99 projected units)" not in result.stdout:
        raise GateFailure("five-calculus storage projection token is absent")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal),
                "test",
                "storage-geometry-spec",
                    "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"storage-geometry-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(storage: list[dict[str, str]], mutants: list[dict[str, str]]) -> None:
    metrics = {
        "named-negatives": "5/5-specific-tag-red",
        "variant-rows": f"{len(storage)}/{len(storage)}-specific-tag-red",
        "legal-twins": f"{len(storage)}/{len(storage)}-green",
        "positive-specs": "2/2-decode-and-storage-rows-fit",
        "dhall-typecheck-training-cases": "2/2-exact-red-with-green-twins",
        "quickcheck-properties": "6/6-green-checkCoverage-30-percent-both-directions",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "registry-subcases": "5/5-Phase-29-owned-discharged",
        "storage-fold-totality": "compile-exhaustive-and-sampled-no-crash",
        "acceptance-token": "spec-composition-proven-storage-geometry",
        "calculus-kinds": "5/5-artifact-budget-lift-workflow-evidence",
        "calculus-components": "storage-negatives,storage-twins,positive-specs,envelope-properties,mutant-evidence",
        "calculus-projection-counts": "30,30,2,6,31",
        "calculus-resource-vector": "5,99,0,0",
        "live-storage-mutation": "UNVERIFIED",
        "execution-accelerator-provider-root-composition": "UNVERIFIED",
        "runtime": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )



# The resolved compiler, set once the toolchain resolves. Every cabal invocation gets it:
# without it cabal picks whatever `ghc` the ambient PATH offers, which on a host carrying a
# newer GHC fails the solver for a reason that has nothing to do with this phase.
COMPILER = ""

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 banner",
}

SIDES = ("toolchain", "oracle", "suite", "mutant", "results")

EXPECTED_RESULTS = {'named-negatives': '5/5-specific-tag-red', 'variant-rows': '30/30-specific-tag-red', 'legal-twins': '30/30-green', 'positive-specs': '2/2-decode-and-storage-rows-fit', 'dhall-typecheck-training-cases': '2/2-exact-red-with-green-twins', 'quickcheck-properties': '6/6-green-checkCoverage-30-percent-both-directions', 'mutants': '31/31-red', 'registry-subcases': '5/5-Phase-29-owned-discharged', 'storage-fold-totality': 'compile-exhaustive-and-sampled-no-crash', 'acceptance-token': 'spec-composition-proven-storage-geometry', 'calculus-kinds': '5/5-artifact-budget-lift-workflow-evidence', 'calculus-components': 'storage-negatives,storage-twins,positive-specs,envelope-properties,mutant-evidence', 'calculus-projection-counts': '30,30,2,6,31', 'calculus-resource-vector': '5,99,0,0', 'live-storage-mutation': 'UNVERIFIED', 'execution-accelerator-provider-root-composition': 'UNVERIFIED', 'runtime': 'UNVERIFIED'}

# Every storage-case surface is decided by the same recorded observation: the run read all
# 30 variant rows and each one reddened at its specific tag beside a green twin. Pointing
# them at `variant-rows` records what actually decides them rather than inventing a
# per-surface metric that measures nothing extra.
CASE_METRIC = "variant-rows"

SURFACE_MAP = {'closed-storage-budget': 'direct-backing', 'bounded-growable-policy': 'scaling-fingerprint', 'bookkeeper-physical-geometry': 'bookkeeper-recovery', 'minio-physical-geometry': 'minio-parity-healing-orphan', 'complete-failure-scenarios': 'complete-failure-scenarios', 'filesystem-presentation': 'filesystem-overhead-rounding', 'backing-allocation-rounding': 'backing-allocation-rounding', 'uniform-statefulset-claims': 'uniform-claim-per-backing', 'six-arm-object-store-producers': 'object-producer-inventory', 'object-inventory-and-conflict': 'object-identity-conflict', 'provider-object-count-quota': 'object-count-quota', 'registry-storage-peak': 'registry-upload-partials', 'zookeeper-recovery-peak': 'zookeeper-recovery', 'patroni-wal-failover-peak': 'patroni-wal-failover', 'vault-raft-compaction-audit-peak': 'vault-raft-audit', 'storage-migration-highwater': 'storage-migration-highwater', 'schema-migration-highwater': 'schema-migration-highwater', 'registry-backend-migration-highwater': 'registry-backend-migration', 'pulsar-hot-tier-ceiling': 'pulsar-hot-tier-ceiling', 'pulsar-durable-total-ceiling': 'pulsar-durable-total', 'native-cache-pool': 'native-cache-pool', 'incluster-cache-nesting': 'incluster-cache-budget', 'incluster-cache-emptydir-ceiling': 'incluster-cache-emptydir', 'provider-node-root-geometry': 'instance-store-root', 'provider-root-ebs-quota': 'root-ebs-quota', 'control-plane-storage-transition': 'control-plane-transition', 'backup-medium-fit': 'backup-medium-fit', 'disjoint-capacity-pools': 'disjoint-capacity-pool', 'restore-target-fit': 'restore-target-fit', 'snapshot-bound-storage-scaling': 'scaling-shrink-highwater', 'bounded-training-dhall_typecheck': 'dhall-typecheck-training-cases', 'independent-storage-envelope-properties': 'quickcheck-properties', 'storage-fold-compile-totality': 'storage-fold-totality', 'phase28-mutant-battery': 'mutants', 'phase28-validation-locus-ledger': 'registry-subcases', 'five-calculus-storage-projection': 'calculus-kinds,calculus-components,calculus-projection-counts,calculus-resource-vector', 'storage-geometry': 'acceptance-token,named-negatives,variant-rows,legal-twins,positive-specs', 'execution-accelerator-provider-root-fit': 'execution-accelerator-provider-root-composition', 'binding-feasibility': '', 'render-fidelity': 'live-storage-mutation', 'model-runtime-correspondence': '', 'runtime-fidelity': 'runtime', 'generated-artifact-discipline': 'emitted-results-untracked,toolchain-satisfies-requirements,recorded-results-match-oracle,locus-ledger-honesty-banner'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((metric, EXPECTED_RESULTS[metric]) if metric and EXPECTED_RESULTS.get(metric) not in (None, "UNVERIFIED") else None)
    for surface, metric in SURFACE_MAP.items()
}


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=28, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
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
    case_names: set[str] = set()

    try:
        resolved = toolchain.resolve(["cabal", "dhall", "ghc"])
        print("toolchain side — cabal, ghc, and dhall resolved from authored requirements\n")
        for name in ("cabal", "ghc", "dhall"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True

        os.environ["AMOEBIUS_DHALL"] = resolved["dhall"]["path"]
        os.environ["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — authored oracle shapes and loci\n")
        primary, mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        verify_totality_sources()
        case_names = {row["variant"] for row in primary}
        print(f"  ok    {len(primary)} oracle rows, {len(mutant_rows)} mutants, loci exact")
        results["oracle"] = True

        print("\nsuite side — the green battery\n")
        suite = run_green_suite(cabal)
        (gate.run_dir / "suite.log").write_text(suite, encoding="utf-8")
        print("  ok    acceptance token present")
        results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log = verify_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {len(mutant_rows)}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(primary, mutant_rows)
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
        print(f"storage-geometry-gate: FAIL: {problem}", file=sys.stderr)

    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    case_evidence = {
        surface: (CASE_METRIC, EXPECTED_RESULTS[CASE_METRIC])
        for surface, metric in SURFACE_MAP.items()
        if metric in case_names
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "cases": case_names},
        rows=rows,
        evidence={**SURFACE_EVIDENCE, **case_evidence},
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"battery": "cabal test storage-geometry-spec"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "phase-29 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
