#!/usr/bin/env python3
"""Run and seal the Phase-9 execution/runtime/accelerator/provider-root gate."""

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


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain/pins.json"
ORACLE = ROOT / "tests/oracle/phase9/execution_accelerator_cases.tsv"
GATE1 = ROOT / "tests/oracle/phase9/gate1_cases.tsv"
MUTANTS = ROOT / "tests/mutants/phase9/mutants.tsv"
LEDGER = ROOT / "test/golden/phase_09_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_09_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase9/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase9/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_09"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
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
    pins = json.loads(PINS.read_text(encoding="utf-8"))
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
    mutants = read_tsv(MUTANTS)
    if len(rows) != 32 or len({row["variant"] for row in rows}) != 32:
        raise GateFailure("Phase-9 fold oracle must contain 32 unique variants")
    if len({row["twin"] for row in rows}) != 32:
        raise GateFailure("every Phase-9 variant must name a distinct legal twin")
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
        raise GateFailure("Phase-9 oracle must preserve the exact eighteen negative families")
    if len(gate1) != 1 or {row["entry"] for row in gate1} != {"3.28"}:
        raise GateFailure("Phase-9 Gate-1 oracle must contain the accelerator-owner barrier")
    if len(mutants) != 45 or len({row["mutant"] for row in mutants}) != 45:
        raise GateFailure("Phase-9 mutant manifest must contain 45 unique mutants")
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
    owned = {(row["entry"], row["subcase"]) for row in registry if row["owner_phase"] == "Phase-9"}
    evidence_entries = {
        *(row["catalog"].split(":", 1)[0] for row in rows),
        *(row["entry"] for row in gate1),
    }
    covered = {(entry, subcase) for entry, subcase in owned if entry in evidence_entries}
    if len(owned) != 2 or covered != owned:
        raise GateFailure(f"Phase-9 registry coverage drifted: covered={sorted(covered)}, owned={sorted(owned)}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Register-1 only; runtime correspondence UNVERIFIED\n", "entry\tsubcase\tlocus\tstatus\n"]
    for row in registry:
        if row["owner_phase"] == "Phase-9":
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
            "-f-phase6-mutant",
            "-f-phase6-normalization-mutant",
            "--offline",
            "--test-show-details=direct",
        ]
    )
    token = "execution-accelerator-spec: PASS (18 named negatives, 32 variants, 32 twins, 2 positives, 1 Gate-1, 7 properties)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-9 acceptance token is absent:\n{result.stdout}")
    if ">=30% accept/reject coverage" not in result.stdout:
        raise GateFailure("Phase-9 property coverage token is absent")
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
                "--offline",
                "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"phase9-mutant: RED {name}"
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
        "registry-subcases": "2/2-Phase-9-owned-discharged",
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


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    tested = {
        "execution-transition-source",
        "exact-prior-generation-resolution",
        "kind-indexed-controller-expansion",
        "empty-capable-execution-epochs",
        "componentwise-execution-peak",
        "scheduler-reservation-projection",
        "aggregate-root-ledger-cas",
        "binding-inflight-retained-debit",
        "ledger-only-absent-recovery",
        "zero-capable-host-release-partitions",
        "kubelet-runtime-metadata-model",
        "planned-slot-observed-uid-separation",
        "runtime-component-role-routing",
        "runtime-accounting-domain-equality",
        "node-image-content-join",
        "node-image-snapshot-join",
        "node-image-model-version",
        "node-image-pull-workspace",
        "filesystem-layout-routing",
        "alias-aware-backing-grouping",
        "physical-disk-parent-accounting",
        "vm-usable-raw-unit-separation",
        "provider-instance-store-root",
        "provider-root-ebs-rounding",
        "provider-node-root-quota",
        "provider-cover-slot-identities",
        "accelerator-family-and-profile",
        "whole-accelerator-device-count",
        "accelerator-source-workload-domains",
        "accelerator-coexistence-epochs",
        "accelerator-unsharded-residency",
        "accelerator-replicated-residency",
        "accelerator-sharded-residency",
        "accelerator-interconnect",
        "accelerator-net-allocatable-vram",
        "accelerator-exclusive-ownership",
        "etcd-logical-transition",
        "etcd-physical-transition",
        "build-execution-envelope",
        "engine-system-reserve",
        "monitoring-work-budget",
        "pulumi-execution-envelope",
        "composed-full-resource-vector",
        "independent-composed-validator",
        "phase9-negative-corpus",
        "phase9-gate1-accelerator-owner",
        "phase9-property-battery",
        "phase9-mutant-battery",
        "phase9-validation-locus-ledger",
    }
    proven = {"phase9-fold-compile-totality"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        if surface in proven:
            status = "proven-for-the-model"
        elif surface in tested:
            status = "tested"
        else:
            status = "UNVERIFIED"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 9,
        "gate_command": "python3 tools/phase9_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def verify_ledger() -> str:
    derived = derive_ledger()
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-9 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(suite: str, mutant_log: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(suite, encoding="utf-8")
    (EVIDENCE / "mutants.log").write_text(mutant_log, encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(versions, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    shutil.copyfile(GENERATED_LEDGER, EVIDENCE / "validation-locus-ledger.tsv")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--derive-ledger", action="store_true")
    args = parser.parse_args(argv)
    if args.derive_ledger:
        print(json.dumps(derive_ledger(), indent=2))
        return 0
    try:
        cabal, dhall, versions = verify_pins()
        rows, mutants = verify_oracles(dhall)
        verify_totality_sources()
        suite = run_green_suite(cabal)
        mutant_log = verify_mutants(cabal, mutants)
        write_results(rows, mutants)
        ledger_hash = verify_ledger()
        retain_evidence(suite, mutant_log, versions)
        print(suite, end="", flush=True)
        print(f"phase9-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase9-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
