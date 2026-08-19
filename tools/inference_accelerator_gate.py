#!/usr/bin/env python3
"""Run and seal the inference accelerator-provision gate."""

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
CASES = ROOT / "test/oracle/inference_accelerator/provision_cases.tsv"
OFFERINGS = ROOT / "test/oracle/inference_accelerator/offering_lane.tsv"
FAMILIES = ROOT / "test/oracle/inference_accelerator/family_lane.tsv"
COEXISTENCE = ROOT / "test/oracle/inference_accelerator/coexistence.tsv"
MUTANT_CAPABILITY = "inference_accelerator"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/inference_accelerator/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/inference-accelerator/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/inference-accelerator/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/inference-accelerator"
CONTRACT = "DEVELOPMENT_PLAN/phase_19_inference_accelerator_provision.md"
GATE_COMMAND = "python3 tools/inference_accelerator_gate.py"
EXPECTATIONS = "test/oracle/inference_accelerator_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", "--jobs=1", *command[1:]]
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_pins() -> tuple[Path, Path, str]:
    pins = toolchain.resolve(["cabal", "dhall", "ghc"])
    executables = {name: Path(pins[name]["path"]) for name in ("cabal", "ghc", "dhall")}
    for executable in executables.values():
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(
        [
            run([str(executables["cabal"]), "--numeric-version"]).stdout,
            run([str(executables["ghc"]), "--numeric-version"]).stdout,
            run([str(executables["dhall"]), "--version"]).stdout,
        ]
    )
    for family in executables:
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return executables["cabal"], executables["dhall"], versions


def verify_oracles(dhall: Path) -> list[dict[str, str]]:
    cases = read_tsv(CASES)
    offerings = read_tsv(OFFERINGS)
    families = read_tsv(FAMILIES)
    coexistence = read_tsv(COEXISTENCE)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    locus = read_tsv(LOCUS)
    if len(cases) != 9 or len({row["case"] for row in cases}) != 9:
        raise GateFailure("Phase-13 provision oracle must enumerate nine unique negatives")
    if len(offerings) != 4 or {row["offering"] for row in offerings} != {"apple", "linux-cpu", "linux-cuda", "windows"}:
        raise GateFailure("Phase-13 offering quotient oracle is incomplete")
    if len(families) != 12 or len({(row["family"], row["lane"]) for row in families}) != 12:
        raise GateFailure("Phase-13 family/lane relation must contain all twelve cells")
    if coexistence != [{"epoch": "all-classes", "device": "cuda-a", "bytes": "15"}]:
        raise GateFailure("Phase-13 hand-authored coexistence aggregation drifted")
    if len(mutants) != 5 or len({row["mutant"] for row in mutants}) != 5:
        raise GateFailure("Phase-13 mutant manifest must contain five unique mutants")
    expected_locus = {
        "legal_inference_singlenode",
        "legal_inference_distributed",
        "legal_inference_cuda",
        *(row["case"] for row in cases),
        *(row["mutant"] for row in mutants),
    }
    if len(locus) != len(expected_locus) or {row["entry"] for row in locus} != expected_locus:
        raise GateFailure("Phase-13 validation-locus ledger has incomplete or duplicate coverage")
    for fixture in (
        "dhall/examples/legal_inference_singlenode.dhall",
        "dhall/examples/legal_inference_distributed.dhall",
        "dhall/examples/legal_inference_cuda.dhall",
    ):
        checked = run([str(dhall), "type", "--file", fixture, "--quiet"], require_success=False)
        if checked.returncode != 0:
            raise GateFailure(f"Phase-13 positive is not Dhall-well-typed: {fixture}\n{checked.stdout}")
    url = run([str(dhall), "type", "--file", "dhall/examples/illegal_engine_by_url.dhall", "--quiet"], require_success=False)
    if url.returncode == 0 or "Url" not in url.stdout:
        raise GateFailure("engine-by-URL fixture missed its Gate-1 Url locus")
    for row in cases:
        if row["case"] == "illegal_engine_by_url":
            continue
        for stem in (row["case"], row["legal_twin"]):
            checked = run([str(dhall), "type", "--file", f"dhall/examples/{stem}.dhall", "--quiet"], require_success=False)
            if checked.returncode != 0:
                raise GateFailure(f"Phase-13 semantic fixture is not Dhall-well-typed: {stem}\n{checked.stdout}")
    for row in mutants:
        descriptor = ROOT / f"test/mutant/inference_accelerator/{row['mutant']}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {row['mutant']}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; live engine resolution and runtime correspondence UNVERIFIED\n" + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [ROOT / "src/Amoebius/Capability/Engine.hs", ROOT / "src/Amoebius/Capacity/Provision.hs"]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail)\b")
    for path in paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial token {match.group(1)!r} in {path.relative_to(ROOT)}")
    suite = (ROOT / "amoebius.cabal").read_text(encoding="utf-8").split("test-suite capability-spec", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in suite:
            raise GateFailure(f"capability-spec totality option missing: {option}")
    engine = (ROOT / "src/Amoebius/Capability/Engine.hs").read_text(encoding="utf-8")
    header = engine.split(") where", 1)[0]
    if "ProvisionedEngineAccelerator (.." in header:
        raise GateFailure("ProvisionedEngineAccelerator constructor is exported")


def run_green_suite(cabal: Path) -> str:
    result = run([str(cabal), "test", "capability-spec", "--test-show-details=direct"])
    token = "capability-spec: PASS (3 inference positives, 4 offering quotients, 12 family/lane cells, 1 Gate-1, 8 provision negatives, 5 mutants, 1 covered property)"
    if token not in result.stdout or "each >=9%" not in result.stdout:
        raise GateFailure(f"Phase-13 acceptance or property token is absent:\n{result.stdout}")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [str(cabal), "test", "capability-spec", "--test-show-details=direct", f"--test-options=--mutant={name}"],
            require_success=False,
        )
        if result.returncode == 0 or f"inference-accelerator-mutant: RED {name}" not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "inference-positives": "3/3-green",
        "offering-quotient": "4/4-exact",
        "family-lane-relation": "12/12-exact",
        "coexistence-aggregation": "1/1-hand-authored-exact",
        "dhall-typecheck-url-negative": "1/1-specific-locus-red",
        "provision-negatives": "8/8-specific-tag-red",
        "quickcheck-properties": "1/1-eight-branches-at-least-9-percent",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "acceptance-token": "accelerator-provision-composition-proven",
        "live-jit-engine-resolution": "UNVERIFIED",
        "cross-lane-runtime-weight-load": "UNVERIFIED",
        "runtime-correspondence": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")



# The resolved compiler, set once the toolchain resolves. Every cabal invocation gets it:
# without it cabal picks whatever `ghc` the ambient PATH offers, which on a host carrying a
# newer GHC fails the solver for a reason that has nothing to do with this phase.
COMPILER = ""

# Where the run reads its enumerable items from. Nothing here is a list this gate carries;
# each is a file the run opens, so deleting a case or a mutant shrinks the enumeration and
# breaks the authored join.
ITEM_SOURCES = ['test/oracle/inference_accelerator/coexistence.tsv', 'test/oracle/inference_accelerator/family_lane.tsv', 'test/oracle/inference_accelerator/offering_lane.tsv', 'test/oracle/inference_accelerator/provision_cases.tsv', 'test/mutant/registry.tsv']

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 banner",
}

SIDES = ("toolchain", "oracle", "suite", "mutant", "results")

EXPECTED_RESULTS = {'inference-positives': '3/3-green', 'offering-quotient': '4/4-exact', 'family-lane-relation': '12/12-exact', 'coexistence-aggregation': '1/1-hand-authored-exact', 'dhall-typecheck-url-negative': '1/1-specific-locus-red', 'provision-negatives': '8/8-specific-tag-red', 'quickcheck-properties': '1/1-eight-branches-at-least-9-percent', 'mutants': '5/5-red', 'acceptance-token': 'accelerator-provision-composition-proven', 'live-jit-engine-resolution': 'UNVERIFIED', 'cross-lane-runtime-weight-load': 'UNVERIFIED', 'runtime-correspondence': 'UNVERIFIED'}

SURFACE_MAP = {'url-free-engine-runtime': 'illegal_engine_by_url', 'closed-engine-family-union': 'LlamaFamily,VllmFamily,DiffusionFamily,OnnxFamily,illegal_engine_family_unavailable_on_lane', 'target-offering-lane-quotient': 'offering-quotient', 'cuda-os-quotient': 'apple,linux-cpu,linux-cuda,windows,illegal_cuda_on_cpu_target', 'partial-family-lane-relation': 'family-lane-relation', 'identity-complete-cuda-owner-demand': 'illegal_accelerator_count_shortage', 'identity-complete-metal-owner-demand': 'mutant_accept_accelerator_domain_mismatch', 'source-workload-key-equality': 'illegal_accelerator_source_workload_mismatch', 'class-complete-coexistence-policy': 'coexistence-aggregation', 'all-policy-permitted-epochs': 'mutant_select_favorable_accelerator_epoch', 'unsharded-residency-validation': 'illegal_accelerator_residency_placement', 'replicated-per-device-validation': 'mutant_drop_accelerator_overlap_debit', 'sharded-residency-validation': 'mutant_skip_accelerator_shard_validation', 'net-allocatable-vram': 'illegal_accelerator_vram_shortage', 'device-count-boundary': 'illegal_accelerator_policy_domain_mismatch', 'per-device-coexistence-aggregation': 'all-classes,illegal_accelerator_coexistence_overcommit,mutant_drop_accelerator_work_item', 'engine-accelerator-provision-seal': 'acceptance-token', 'opaque-provisioned-engine-accelerator': '', 'phase12-dhall-typecheck-url-negative': 'dhall-typecheck-url-negative', 'phase12-provision-negative-corpus': 'provision-negatives', 'phase12-property-coverage': 'quickcheck-properties', 'phase12-mutant-battery': 'mutants', 'phase12-validation-locus-ledger': '', 'phase12-compile-totality': 'inference-positives', 'live-jit-engine-resolution': 'live-jit-engine-resolution', 'cross-lane-runtime-weight-load': 'cross-lane-runtime-weight-load', 'runtime-model-correspondence': 'runtime-correspondence'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] != "UNVERIFIED" else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names: set[str] = set()
    for relative in ITEM_SOURCES:
        path = ROOT / relative
        if not path.is_file():
            continue
        if relative == "test/mutant/registry.tsv":
            # The one registry leads with the capability and carries every phase's rows, so
            # this phase's items are the mutant ids in its own rows, not every first column.
            names.update(row["mutant"] for row in mutant_registry.capability(MUTANT_CAPABILITY))
            continue
        for line in path.read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip():
                names.add(line.split("\t")[0].strip())
    return names


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=13, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
        expectations=EXPECTATIONS,
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
    item_names: set[str] = set()

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
        mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        verify_totality_sources()
        item_names = enumerated_items()
        print(f"  ok    {len(item_names)} enumerated items, {len(mutant_rows)} mutants, loci exact")
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

        write_results(mutant_rows)
        rows = gate_common.metric_rows(RESULTS)
        banner_ok = not GENERATED_LEDGER.is_file() or GENERATED_LEDGER.read_text(encoding="utf-8").startswith(
            "# Register-1 only;"
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        print(f"  {'ok  ' if banner_ok else 'FAIL'}  locus-ledger-honesty-banner")
        results["results"] = oracle_ok and artifact_ok and banner_ok
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"inference-accelerator-gate: FAIL: {problem}", file=sys.stderr)

    item_evidence = {
        surface: ("acceptance-token", EXPECTED_RESULTS["acceptance-token"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
    }
    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
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
        dependencies={"battery": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "phase-13 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
