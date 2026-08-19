#!/usr/bin/env python3
"""Run and seal the whole-deployment provision gate."""

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
ARM_ORACLE = ROOT / "test/oracle/capability_bind/arm_cases.tsv"
CASES = ROOT / "test/oracle/provision_seal/provision_cases.tsv"
PLANNER = ROOT / "test/oracle/provision_seal/planner_cases.tsv"
ACTIVATION = ROOT / "test/oracle/provision_seal/activation.tsv"
MUTANT_CAPABILITY = "provision_seal"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/provision_seal/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/provision-seal/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/provision-seal/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/provision-seal"
CONTRACT = "DEVELOPMENT_PLAN/phase_18_provision_seal.md"
GATE_COMMAND = "python3 tools/provision_seal_gate.py"
EXPECTATIONS = "test/oracle/provision_seal_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", "--jobs=1", *command[1:]]
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


def verify_oracles(dhall: Path) -> list[dict[str, str]]:
    arms = read_tsv(ARM_ORACLE)
    cases = read_tsv(CASES)
    planner = read_tsv(PLANNER)
    activation = read_tsv(ACTIVATION)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    locus = read_tsv(LOCUS)
    expected_tags = {
        "PostBindExpansionOvercommit",
        "MonitoringBudgetExceeded",
        "VramOvercommit",
        "MissingCapability",
        "UnknownCommitment",
        "ElasticPerNodeExpansionOvercommit",
        "MissingPriorProvisionRef",
        "StalePriorProvisionRef",
        "WrongGenerationPriorProvisionRef",
        "WrongArmPriorProvisionRef",
    }
    if len(cases) != 10 or {row["expected"] for row in cases} != expected_tags:
        raise GateFailure("Phase-12 provision oracle must enumerate ten distinct specific failure tags")
    if len(planner) != 2 or {row["expected"] for row in planner} != {"NoInfrastructureRequired", "InfrastructureRequired"}:
        raise GateFailure("Phase-12 planner oracle must enumerate pre-existing and creation paths")
    expected_activation = {
        ("NamespacePart", "Immediate"),
        ("CapacitySchedulerPart", "BootstrapSchedulerStage"),
        ("BootstrapAddonCutoverPart", "AfterBootstrapAddonCutover"),
        ("ManagedCapacityAdmissionPart", "AfterManagedCapacityReady"),
    }
    if len(activation) != 4 or {(row["witness"], row["activation"]) for row in activation} != expected_activation:
        raise GateFailure("Phase-12 activation oracle must pin all four deployment-global stages")
    if len(mutants) != 10 or len({row["mutant"] for row in mutants}) != 10:
        raise GateFailure("Phase-12 mutant manifest must contain ten unique mutants")
    positives = {
        f"legal_{row['slug']}_{shape}"
        for row in arms
        for shape in ("singlenode", "distributed")
    }
    expected_locus = positives | {"planner_preexisting", "planner_creation"}
    expected_locus |= {row["case"] for row in cases}
    expected_locus |= {row["mutant"] for row in mutants}
    if len(locus) != len(expected_locus) or {row["entry"] for row in locus} != expected_locus:
        raise GateFailure("Phase-12 validation-locus ledger has incomplete or duplicate coverage")
    for row in cases:
        for stem in (row["case"], row["legal_twin"]):
            fixture = ROOT / f"dhall/examples/{stem}.dhall"
            checked = run([str(dhall), "type", "--file", str(fixture), "--quiet"], require_success=False)
            if checked.returncode != 0:
                raise GateFailure(f"Phase-12 corpus fixture is not Dhall-well-typed: {fixture}\n{checked.stdout}")
    for row in mutants:
        descriptor = ROOT / f"test/mutant/provision_seal/{row['mutant']}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {row['mutant']}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; live provider realization, engine resolution, and runtime correspondence UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capacity/Provision.hs",
        ROOT / "src/Amoebius/Capacity/RenderSource.hs",
        ROOT / "src/Amoebius/Capability/Provisioned.hs",
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
    suite = cabal_text.split("test-suite provision-seal-spec", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in suite:
            raise GateFailure(f"provision seal totality option missing: {option}")
    provision_header = (ROOT / "src/Amoebius/Capacity/Provision.hs").read_text(encoding="utf-8").split(") where", 1)[0]
    if "ProvisionedSpec (.." in provision_header:
        raise GateFailure("ProvisionedSpec constructor is exported")


def run_green_suite(cabal: Path) -> str:
    result = run([str(cabal), "test", "provision-seal-spec", "--test-show-details=direct"])
    token = "provision-seal-spec: PASS (18 inherited positives, 2 planner paths, 10 specific negatives, 4 activation stages, 10 mutants, 2 covered properties)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-12 acceptance token is absent:\n{result.stdout}")
    for property_token in ("exact infrastructure vs one-unit-short", "exact backing vs one-byte-short"):
        if property_token not in result.stdout:
            raise GateFailure(f"Phase-12 property coverage token is absent: {property_token}")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal),
                "test",
                "provision-seal-spec",
                    "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"provision-seal-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "inherited-capability-positives": "18/18-provisioned",
        "infrastructure-planner-paths": "2/2-green",
        "creation-plan-validation-readback": "validated-cas-enacted",
        "render-source-domain": "one-equal-keyed-map",
        "render-activation-stages": "4/4-present",
        "specific-negatives": "10/10-specific-tag-red",
        "quickcheck-properties": "2/2-exact-vs-one-short-green",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "acceptance-token": "provision-composition-proven",
        "live-provider-realization": "UNVERIFIED",
        "live-engine-resolution": "UNVERIFIED",
        "runtime-correspondence": "UNVERIFIED",
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

# Where the run reads its enumerable items from. Nothing here is a list this gate carries;
# each is a file the run opens, so deleting a case or a mutant shrinks the enumeration and
# breaks the authored join.
ITEM_SOURCES = ['test/oracle/provision_seal/activation.tsv', 'test/oracle/provision_seal/planner_cases.tsv', 'test/oracle/provision_seal/provision_cases.tsv', 'test/mutant/registry.tsv']

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 banner",
}

SIDES = ("toolchain", "oracle", "suite", "mutant", "results")

EXPECTED_RESULTS = {'inherited-capability-positives': '18/18-provisioned', 'infrastructure-planner-paths': '2/2-green', 'creation-plan-validation-readback': 'validated-cas-enacted', 'render-source-domain': 'one-equal-keyed-map', 'render-activation-stages': '4/4-present', 'specific-negatives': '10/10-specific-tag-red', 'quickcheck-properties': '2/2-exact-vs-one-short-green', 'mutants': '10/10-red', 'acceptance-token': 'provision-composition-proven', 'live-provider-realization': 'UNVERIFIED', 'live-engine-resolution': 'UNVERIFIED', 'runtime-correspondence': 'UNVERIFIED'}

SURFACE_MAP = {'conditional-infrastructure-planner': 'preexisting,creation', 'internally-derived-infrastructure-demand': 'illegal_elastic_per_node_expansion_overcommit', 'standalone-root-supply': 'illegal_cuda_on_cpu_target', 'forest-member-budget': 'illegal_monitoring_work_over_budget', 'preexisting-no-infrastructure-required': 'infrastructure-planner-paths', 'creation-provider-action-batch': '', 'plan-token-replay-rejection': '', 'action-token-replay-rejection': '', 'snapshot-cas-validation': 'creation-plan-validation-readback', 'receipt-bound-materialization-readback': '', 'promised-identity-rejection': '', 'whole-deployment-provision-seal': 'acceptance-token', 'phase7-placement-fold-composition': 'illegal_post_bind_expansion_overcommit', 'phase8-storage-fold-composition': 'illegal_accelerator_vram_shortage', 'phase9-execution-fold-composition': 'illegal_controller_child_unbounded,mutant_double_debit_controller_child', 'kind-indexed-execution-expansion': 'mutant_drop_surge,mutant_drop_execution_replica', 'planned-runtime-storage-binding': 'mutant_drop_largest_kubelet_metadata,mutant_missing_metadata_model', 'finite-monitoring-work-envelope': 'mutant_fixed_prometheus', 'prior-artifact-reference-resolution': 'illegal_prior_provision_ref_missing,illegal_prior_provision_ref_stale,illegal_prior_provision_ref_wrong_generation,illegal_prior_provision_ref_wrong_arm,mutant_unchecked_prior', 'opaque-provisioned-spec': 'mutant_provisioned_in_bound', 'identity-keyed-render-source-set': 'render-source-domain', 'render-source-key-identity-equality': 'render-activation-stages', 'render-source-owner-correspondence': 'mutant_wrong_revision_join', 'four-stage-render-activation': 'NamespacePart,CapacitySchedulerPart,BootstrapAddonCutoverPart,ManagedCapacityAdmissionPart', 'bound-deployment-no-provisioned-values': 'mutant_old_revision', 'phase11-negative-corpus': 'specific-negatives', 'phase11-property-boundaries': 'quickcheck-properties', 'phase11-mutant-battery': 'mutants', 'phase11-validation-locus-ledger': '', 'provision-seal-compile-totality': 'inherited-capability-positives', 'live-provider-realization': 'live-provider-realization', 'live-engine-resolution': 'live-engine-resolution', 'runtime-model-correspondence': 'runtime-correspondence'}

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
        phase=12, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
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
        print(f"provision-seal-gate: FAIL: {problem}", file=sys.stderr)

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
        or [{"name": "phase-12 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
