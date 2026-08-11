#!/usr/bin/env python3
"""Run and seal the Phase-8 logical-to-physical storage geometry gate."""

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
STORAGE_ORACLE = ROOT / "tests/oracle/phase8/storage_cases.tsv"
GATE1_ORACLE = ROOT / "tests/oracle/phase8/gate1_cases.tsv"
MUTANTS = ROOT / "tests/mutants/phase8/mutants.tsv"
LEDGER = ROOT / "test/golden/phase_08_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_08_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase8/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase8/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_08"


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
    storage = read_tsv(STORAGE_ORACLE)
    gate1 = read_tsv(GATE1_ORACLE)
    mutants = read_tsv(MUTANTS)
    if len(storage) != 27 or len({row["variant"] for row in storage}) != 27:
        raise GateFailure("storage oracle must contain 27 unique variant rows")
    if len({row["twin"] for row in storage}) != 27:
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
    if len(gate1) != 2 or {row["entry"] for row in gate1} != {"3.32"}:
        raise GateFailure("Phase-8 Gate-1 oracle must cover both 3.32 barriers")
    if len(mutants) != 31 or len({row["mutant"] for row in mutants}) != 31:
        raise GateFailure("mutant manifest must contain 31 unique mutants")
    run([sys.executable, str(ROOT / "tools/locus_registry_lint.py")])
    for row in gate1:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    verify_registry_coverage(storage, gate1)
    return storage, mutants


def verify_registry_coverage(storage: list[dict[str, str]], gate1: list[dict[str, str]]) -> None:
    registry = read_tsv(ROOT / "dhall/examples/locus_registry.tsv")
    owned = {(row["entry"], row["subcase"]) for row in registry if row["owner_phase"] == "Phase-8"}
    evidence_entries = {
        *(row["catalog"].split(":", 1)[0] for row in storage),
        *(row["entry"] for row in gate1),
    }
    covered = {(entry, subcase) for entry, subcase in owned if entry in evidence_entries}
    if len(owned) != 5 or covered != owned:
        raise GateFailure(f"Phase-8 registry coverage drifted: covered={sorted(covered)}, owned={sorted(owned)}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Register-1 only; runtime correspondence UNVERIFIED\n", "entry\tsubcase\tlocus\tstatus\n"]
    for row in registry:
        if row["owner_phase"] == "Phase-8":
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
            "dsl-spec",
            "storage-geometry-spec",
            "-f-phase6-mutant",
            "-f-phase6-normalization-mutant",
            "--offline",
            "--test-show-details=direct",
        ]
    )
    token = "storage-geometry-spec: PASS (5 named negatives, 27 variants, 27 twins, 2 positives, 2 Gate-1, 6 properties)"
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
                "storage-geometry-spec",
                "--offline",
                "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"phase8-mutant: RED {name}"
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
        "gate1-training-cases": "2/2-exact-red-with-green-twins",
        "quickcheck-properties": "6/6-green-checkCoverage-30-percent-both-directions",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "registry-subcases": "5/5-Phase-8-owned-discharged",
        "storage-fold-totality": "compile-exhaustive-and-sampled-no-crash",
        "acceptance-token": "spec-composition-proven-storage-geometry",
        "live-storage-mutation": "UNVERIFIED",
        "execution-accelerator-provider-root-composition": "UNVERIFIED",
        "runtime": "UNVERIFIED",
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
        "closed-storage-budget",
        "bounded-growable-policy",
        "bookkeeper-physical-geometry",
        "minio-physical-geometry",
        "complete-failure-scenarios",
        "filesystem-presentation",
        "backing-allocation-rounding",
        "uniform-statefulset-claims",
        "six-arm-object-store-producers",
        "object-inventory-and-conflict",
        "registry-storage-peak",
        "zookeeper-recovery-peak",
        "patroni-wal-failover-peak",
        "vault-raft-compaction-audit-peak",
        "storage-migration-highwater",
        "schema-migration-highwater",
        "registry-backend-migration-highwater",
        "pulsar-hot-tier-ceiling",
        "pulsar-durable-total-ceiling",
        "native-cache-pool",
        "incluster-cache-nesting",
        "provider-node-root-geometry",
        "control-plane-storage-transition",
        "backup-medium-fit",
        "disjoint-capacity-pools",
        "restore-target-fit",
        "bounded-training-gate1",
        "snapshot-bound-storage-scaling",
        "independent-storage-envelope-properties",
        "phase8-mutant-battery",
        "phase8-validation-locus-ledger",
        "storage-geometry",
    }
    proven = {"storage-fold-compile-totality"}
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
        "phase": 8,
        "gate_command": "python3 tools/phase8_gate.py",
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
        raise GateFailure("committed Phase-8 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
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
        storage, mutants = verify_oracles(dhall)
        verify_totality_sources()
        suite = run_green_suite(cabal)
        mutant_log = verify_mutants(cabal, mutants)
        write_results(storage, mutants)
        ledger_hash = verify_ledger()
        retain_evidence(suite, mutant_log, versions)
        print(suite, end="", flush=True)
        print(f"phase8-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase8-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
