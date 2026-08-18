#!/usr/bin/env python3
"""Run and seal the execution/runtime/accelerator/provider-root gate."""

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
ORACLE = ROOT / "test/oracle/execution_accelerator/execution_accelerator_cases.tsv"
GATE1 = ROOT / "test/oracle/execution_accelerator/gate1_cases.tsv"
MUTANT_CAPABILITY = "execution_accelerator"
MUTANTS = ROOT / "test/mutant/registry.tsv"
RESULTS = ROOT / ".build/dsl/execution-accelerator/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/execution-accelerator/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/execution-accelerator"
CONTRACT = "DEVELOPMENT_PLAN/phase_10_execution_accelerator_folds.md"
GATE_COMMAND = "python3 tools/execution_accelerator_gate.py"
EXPECTATIONS = "test/oracle/execution_accelerator_surfaces.tsv"


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
    rows = read_tsv(ORACLE)
    gate1 = read_tsv(GATE1)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(rows) != 32 or len({row["variant"] for row in rows}) != 32:
        raise GateFailure("Phase-10 fold oracle must contain 32 unique variants")
    if len({row["twin"] for row in rows}) != 32:
        raise GateFailure("every Phase-10 variant must name a distinct legal twin")
    required_families = {
        "illegal_hard_ceiling_overcommit",
        "illegal_node_local_storage_over_backing",
        "illegal_disk_backing_alias_double_spend",
        "illegal_filesystem_layout_alias",
        "illegal_filesystem_layout_swapped",
        "illegal_image_content_join_missing",
        "illegal_image_snapshot_join_missing",
        "illegal_image_storage_model_missing",
        "illegal_split_image_unsupported",
        "illegal_provider_instance_store_root_underprovisioned",
        "illegal_provider_node_root_ebs_over_quota",
        "illegal_control_plane_storage_transition_overrun",
        "illegal_cuda_on_cpu_target",
        "illegal_accelerator_count_shortage",
        "illegal_accelerator_vram_fragmentation",
        "illegal_accelerator_vram_reserve_boundary",
        "illegal_apple_metal_profile_mismatch",
        "illegal_shared_accelerator_double_owner",
    }
    if {row["family"] for row in rows} != required_families:
        raise GateFailure("Phase-10 oracle must preserve the exact eighteen negative families")
    if len(gate1) != 1 or {row["entry"] for row in gate1} != {"3.28"}:
        raise GateFailure("Phase-10 Gate-1 oracle must contain the accelerator-owner barrier")
    if len(mutants) != 45 or len({row["mutant"] for row in mutants}) != 45:
        raise GateFailure("Phase-10 mutant manifest must contain 45 unique mutants")
    run([sys.executable, str(ROOT / "tools/locus_registry_lint.py")])
    for row in gate1:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    verify_registry_coverage(rows, gate1)
    return rows, mutants


def verify_registry_coverage(rows: list[dict[str, str]], gate1: list[dict[str, str]]) -> None:
    registry = read_tsv(ROOT / "dhall/examples/locus_registry.tsv")
    owned = {(row["entry"], row["subcase"]) for row in registry if row["owner_phase"] == "Phase-10"}
    evidence_entries = {
        *(row["catalog"].split(":", 1)[0] for row in rows),
        *(row["entry"] for row in gate1),
    }
    covered = {(entry, subcase) for entry, subcase in owned if entry in evidence_entries}
    if len(owned) != 2 or covered != owned:
        raise GateFailure(f"Phase-10 registry coverage drifted: covered={sorted(covered)}, owned={sorted(owned)}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Register-1 only; runtime correspondence UNVERIFIED\n", "entry\tsubcase\tlocus\tstatus\n"]
    for row in registry:
        if row["owner_phase"] == "Phase-10":
            lines.append(f"{row['entry']}\t{row['subcase']}\t{row['validation_locus']}\tdischarged\n")
    GENERATED_LEDGER.write_text("".join(lines), encoding="utf-8")


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capacity/Execution.hs",
        ROOT / "src/Amoebius/Capacity/Scheduler.hs",
        ROOT / "src/Amoebius/Capacity/HostReservation.hs",
        ROOT / "src/Amoebius/Capacity/NodeLocalStorage.hs",
        ROOT / "src/Amoebius/Capacity/RuntimeStorage.hs",
        ROOT / "src/Amoebius/Capacity/Accelerator.hs",
        ROOT / "src/Amoebius/Capacity/ProviderRoot.hs",
        ROOT / "src/Amoebius/Capacity/Etcd.hs",
        ROOT / "src/Amoebius/Capacity/PulumiExecution.hs",
        ROOT / "src/Amoebius/Capacity/Composed.hs",
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
            "execution-accelerator-spec",
            "-f-illegal-state-mutant",
            "-f-resource-normalization-mutant",
            "--test-show-details=direct",
        ]
    )
    token = "execution-accelerator-spec: PASS (18 named negatives, 32 variants, 32 twins, 2 positives, 1 Gate-1, 7 properties)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-10 acceptance token is absent:\n{result.stdout}")
    if ">=30% accept/reject coverage" not in result.stdout:
        raise GateFailure("Phase-10 property coverage token is absent")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal),
                "test",
                "execution-accelerator-spec",
                    "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"execution-accelerator-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(rows: list[dict[str, str]], mutants: list[dict[str, str]]) -> None:
    metrics = {
        "named-negatives": "18/18-specific-tag-red",
        "variant-rows": f"{len(rows)}/{len(rows)}-specific-tag-red",
        "legal-twins": f"{len(rows)}/{len(rows)}-green",
        "positive-specs": "2/2-decode-and-full-vector-place",
        "gate1-accelerator-owner": "1/1-exact-red-with-green-twin",
        "quickcheck-properties": "7/7-green-checkCoverage-30-percent-on-decision-folds",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "registry-subcases": "2/2-Phase-10-owned-discharged",
        "phase9-fold-totality": "compile-exhaustive-and-sampled-no-crash",
        "acceptance-token": "spec-composition-proven-full-resource-vector",
        "live-scheduler-and-storage": "UNVERIFIED",
        "live-accelerator-and-provider": "UNVERIFIED",
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

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 banner",
}

SIDES = ("toolchain", "oracle", "suite", "mutant", "results")

EXPECTED_RESULTS = {'named-negatives': '18/18-specific-tag-red', 'variant-rows': '32/32-specific-tag-red', 'legal-twins': '32/32-green', 'positive-specs': '2/2-decode-and-full-vector-place', 'gate1-accelerator-owner': '1/1-exact-red-with-green-twin', 'quickcheck-properties': '7/7-green-checkCoverage-30-percent-on-decision-folds', 'mutants': '45/45-red', 'registry-subcases': '2/2-Phase-10-owned-discharged', 'phase9-fold-totality': 'compile-exhaustive-and-sampled-no-crash', 'acceptance-token': 'spec-composition-proven-full-resource-vector', 'live-scheduler-and-storage': 'UNVERIFIED', 'live-accelerator-and-provider': 'UNVERIFIED', 'runtime-correspondence': 'UNVERIFIED'}

SURFACE_MAP = {'execution-transition-source': 'copy-new-execution-as-old,drop-removed-execution', 'exact-prior-generation-resolution': 'execution-prior-old-revision,drop-execution-old-revision', 'kind-indexed-controller-expansion': 'execution-rollout-surge,drop-execution-surge', 'empty-capable-execution-epochs': 'invent-first-deploy-old,resolve-latest-execution', 'componentwise-execution-peak': 'execution-replica-peak,drop-execution-replica', 'scheduler-reservation-projection': 'scheduler-projection,scheduler-drop-pad', 'aggregate-root-ledger-cas': 'scheduler-aggregate-root,scheduler-per-record-cas', 'binding-inflight-retained-debit': 'scheduler-snapshot-cas,scheduler-timeout-release', 'ledger-only-absent-recovery': 'scheduler-binding-crash-release', 'zero-capable-host-release-partitions': 'partition-parent,partition-drop-system-reserve', 'kubelet-runtime-metadata-model': 'runtime-model,runtime-missing-model', 'planned-slot-observed-uid-separation': 'runtime-scope-domain,runtime-scope-confusion', 'runtime-component-role-routing': 'runtime-nodefs,runtime-swap-role', 'runtime-accounting-domain-equality': 'runtime-imagefs,runtime-drop-largest-metadata', 'node-image-content-join': 'image-content-join,image-manifest-join,image-drop-index', 'node-image-snapshot-join': 'image-snapshot-join,image-drop-snapshot', 'node-image-model-version': 'image-storage-model,image-ignore-model', 'node-image-pull-workspace': 'node-image-workspace,image-drop-workspace,image-drop-manifest', 'filesystem-layout-routing': 'split-image-containerd-v1,layout-enable-v1-split-image', 'alias-aware-backing-grouping': 'filesystem-layout-alias,layout-allow-alias,partition-carve-alias', 'physical-disk-parent-accounting': 'filesystem-layout-swapped,layout-ignore-observation,partition-double-debit-child', 'vm-usable-raw-unit-separation': 'partition-unit-mismatch,partition-mix-vm-usable,partition-use-vm-usable-as-raw', 'provider-instance-store-root': 'instance-store-root,provider-under-size-instance-store', 'provider-root-ebs-rounding': 'root-ebs-bytes-quota,provider-skip-allocation-rounding,provider-skip-presentation', 'provider-node-root-quota': 'root-ebs-volume-quota,provider-debit-durable', 'provider-cover-slot-identities': 'provider-reuse-template-id', 'accelerator-family-and-profile': 'cuda-family-absent,accelerator-treat-none-as-cuda', 'whole-accelerator-device-count': 'cuda-device-count,accelerator-drop-device-count', 'accelerator-source-workload-domains': 'accelerator-drop-source-domain', 'accelerator-coexistence-epochs': 'accelerator-favorable-epoch', 'accelerator-unsharded-residency': 'cuda-unsharded-fragmentation,accelerator-split-unsharded', 'accelerator-replicated-residency': 'metal-profile,accelerator-ignore-metal-profile', 'accelerator-sharded-residency': 'cuda-shard-byte-sum,accelerator-ignore-shard-sum', 'accelerator-interconnect': '', 'accelerator-net-allocatable-vram': 'cuda-vram-reserve,accelerator-spend-raw-vram', 'accelerator-exclusive-ownership': 'accelerator-shared-owner,accelerator-share-device', 'etcd-logical-transition': 'etcd-drop-preallocated-next,etcd-drop-wal', 'etcd-physical-transition': 'etcd-transition-physical,etcd-drop-snapshot-save,etcd-drop-defrag', 'build-execution-envelope': '', 'engine-system-reserve': '', 'monitoring-work-budget': '', 'pulumi-execution-envelope': '', 'composed-full-resource-vector': 'acceptance-token', 'independent-composed-validator': 'positive-specs', 'phase9-negative-corpus': 'named-negatives', 'phase9-gate1-accelerator-owner': 'gate1-accelerator-owner', 'phase9-property-battery': 'quickcheck-properties', 'phase9-mutant-battery': 'mutants', 'phase9-validation-locus-ledger': 'registry-subcases', 'phase9-fold-compile-totality': 'phase9-fold-totality', 'live-scheduler-binding': 'live-scheduler-and-storage', 'live-runtime-storage-observation': '', 'live-accelerator-observation': 'live-accelerator-and-provider', 'live-provider-root-materialization': '', 'runtime-model-correspondence': 'runtime-correspondence'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((metric, EXPECTED_RESULTS[metric]) if metric and EXPECTED_RESULTS.get(metric) not in (None, "UNVERIFIED") else None)
    for surface, metric in SURFACE_MAP.items()
}


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=10, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
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
        primary, mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        verify_totality_sources()
        item_names = {row["variant"] for row in primary} | {row["mutant"] for row in mutant_rows}
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
        print(f"execution-accelerator-gate: FAIL: {problem}", file=sys.stderr)

    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    item_evidence = {
        surface: ("mutants", EXPECTED_RESULTS["mutants"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
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
        or [{"name": "phase-10 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
