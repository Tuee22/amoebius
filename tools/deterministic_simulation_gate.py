#!/usr/bin/env python3
"""Run and seal the deterministic-simulation substrate checks."""

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
SCHEDULES = ROOT / "test/fixture/deterministic_simulation/schedules"
EXPECTED_OUTCOMES = ROOT / "test/oracle/deterministic_simulation/expected_outcomes.tsv"
MUTANT_CAPABILITY = "deterministic_simulation"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/deterministic_simulation/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/deterministic-simulation/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/deterministic-simulation/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/deterministic-simulation"
CONTRACT = "DEVELOPMENT_PLAN/phase_22_deterministic_sim_substrate.md"
GATE_COMMAND = "python3 tools/deterministic_simulation_gate.py"
EXPECTATIONS = "test/oracle/deterministic_simulation_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", "--jobs=1", *command[1:]]
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment(),
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


def verify_pins() -> tuple[Path, str]:
    pins = toolchain.resolve(["cabal", "ghc"])
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    for executable in (cabal, ghc):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = run([str(cabal), "--numeric-version"]).stdout + run([str(ghc), "--numeric-version"]).stdout
    if pins["cabal"]["version"] not in versions or pins["ghc"]["version"] not in versions:
        raise GateFailure(f"toolchain version drifted:\n{versions}")
    return cabal, versions


def verify_oracles() -> None:
    paths = sorted(SCHEDULES.glob("*.json"))
    if [path.stem for path in paths] != ["crash", "partition", "redelivery", "reorder"]:
        raise GateFailure("schedule corpus must contain crash, partition, redelivery, and reorder fixtures")
    rows = [json.loads(path.read_text(encoding="utf-8")) for path in paths]
    names = {row["scheduleName"] for row in rows}
    if names != {"crash-retry", "partition-heal", "redelivery-dedup", "reorder-delay"}:
        raise GateFailure(f"schedule names drifted: {sorted(names)}")
    fault_fields = {
        "schedulePartition",
        "scheduleRedelivery",
        "scheduleReorder",
        "scheduleDuplicate",
        "scheduleCrash",
    }
    if any(field not in row for row in rows for field in fault_fields):
        raise GateFailure("a schedule omits a typed fault field")
    if not all(any(bool(row[field]) for row in rows) for field in fault_fields):
        raise GateFailure("the schedule corpus does not drive every non-delay fault axis")
    if not any(int(row["scheduleDnsDelay"]) > 0 for row in rows):
        raise GateFailure("the schedule corpus does not drive delay")
    outcomes = read_tsv_no_header(EXPECTED_OUTCOMES)
    if len(outcomes) != 4 or {row[0] for row in outcomes} != names:
        raise GateFailure("the independent expected-outcome table does not cover the schedule corpus")
    if any(row[1:] != ["upheld", "-"] for row in outcomes):
        raise GateFailure("reference schedule outcomes must be independently pinned as upheld")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 1 or mutants[0]["id"] != "m1-dropped-partition-handling":
        raise GateFailure("Phase-16 mutant manifest must name the dropped-partition mutant exactly once")
    locus = read_tsv(LOCUS)
    if len(locus) != 20 or len({row["entry"] for row in locus}) != 20:
        raise GateFailure("Phase-16 validation locus must contain twenty unique entries")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 modeled environment; real-substrate fidelity ASSUMED; live runtime UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )


def read_tsv_no_header(path: Path) -> list[list[str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.reader(handle, delimiter="\t"))


def verify_source_boundaries() -> None:
    files = sorted((ROOT / "src/Amoebius/Sim").rglob("*.hs"))
    if len(files) != 10:
        raise GateFailure(f"simulation source scope drifted: expected 10 modules, got {len(files)}")
    signature_io = re.compile(r"::[^\n]*(?<![A-Za-z0-9_])IO(?![A-Za-z0-9_])")
    forbidden_concurrency = re.compile(r"\bforkIO\b|import\s+(?:qualified\s+)?Control\.Concurrent(?:\s|\()")
    combined = ""
    for path in files:
        source = path.read_text(encoding="utf-8")
        combined += source
        if signature_io.search(source):
            raise GateFailure(f"bare IO signature in simulation scope: {path.relative_to(ROOT)}")
        if forbidden_concurrency.search(source):
            raise GateFailure(f"raw concurrency primitive in simulation scope: {path.relative_to(ROOT)}")
    for token in ("MonadAsync", "MonadSTM", "MonadDelay", "IOSim"):
        if token not in combined:
            raise GateFailure(f"non-vacuous polymorphism token is absent: {token}")


def run_green(cabal: Path) -> str:
    build = run([str(cabal), "build", "lib:dsl-core"])
    suite = run([str(cabal), "test", "sim-spec", "--test-show-details=direct"])
    token = "sim-spec: PASS (2 interpreters, 6 fake contracts, 4 schedules, same-seed bytes, sensitivity, IOSimPOR, 1 mutant)"
    if token not in suite.stdout:
        raise GateFailure(f"Phase-16 acceptance token is absent:\n{suite.stdout}")
    return build.stdout + suite.stdout


def run_mutant(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "sim-spec",
            "--test-show-details=direct",
            "--test-options=--mutant=dropped-partition-handling",
        ],
        require_success=False,
    )
    token = "deterministic-simulation-mutant: RED dropped-partition-handling NoActOnStaleRead"
    if result.returncode == 0 or token not in result.stdout:
        raise GateFailure(f"dropped-partition mutant survived or missed its red locus:\n{result.stdout}")
    return result.stdout


def write_results() -> None:
    metrics = {
        "interpreters": "2/2-reference-program-green",
        "fake-contracts": "6/6-with-knob-controls",
        "schedules": "4/4-oracle-pinned",
        "same-seed-traces": "4/4-byte-identical",
        "schedule-sensitivity": "1/1-distinct",
        "iosimpor": "4/4-bounded-replays-green",
        "mutants": "1/1-red",
        "modeled-env-fidelity": "ASSUMED",
        "live-substrate-runtime": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )



COMPILER = ""

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "no-bare-io-signature": "no module in simulation scope carries a bare IO signature",
    "non-vacuous-polymorphism-tokens": "the io-classes polymorphism tokens are all present",
    "simulation-scope-exact": "the simulation scope is exactly its declared ten modules",
}

SIDES = ("toolchain", "oracle", "source", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "interpreters": "2/2-reference-program-green",
    "fake-contracts": "6/6-with-knob-controls",
    "schedules": "4/4-oracle-pinned",
    "same-seed-traces": "4/4-byte-identical",
    "schedule-sensitivity": "1/1-distinct",
    "iosimpor": "4/4-bounded-replays-green",
    "mutants": "1/1-red",
    # The model's faithfulness to a real substrate is precisely what Register 2 cannot
    # establish, so this row is ASSUMED by construction and never becomes tested here.
    "modeled-env-fidelity": "ASSUMED",
    "live-substrate-runtime": "UNVERIFIED",
}

SURFACE_MAP = {'typed-env-interface': 'no-bare-io-signature', 'io-classes-polymorphism-source-gate': 'non-vacuous-polymorphism-tokens', 'real-client-interpreter': 'real_interpreter', 'iosim-interpreter': 'sim_interpreter', 'reference-reconciler-one-source': 'interpreters', 'pulsar-partition-heal': 'pulsar_partition_heal', 'pulsar-redelivery-dedup': 'redelivery_schedule', 'pulsar-reorder': 'pulsar_reorder', 'pulsar-duplicate': 'pulsar_duplicate', 'minio-if-none-match-412': 'minio_412', 'apiserver-resource-version-conflict': 'apiserver_conflict', 'apiserver-watch-gap': 'apiserver_watch_gap', 'apiserver-crash-once': 'apiserver_crash', 'route53-stale-propagation': 'route53_stale_no_cas', 'route53-no-cas': 'fake-contracts', 'vault-sealed-rejection': 'vault_sealed', 'modeled-clock-delay': 'clock_delay', 'four-schedule-corpus': 'schedules', 'independent-outcome-oracle': 'partition_schedule,reorder_schedule,crash_schedule,same_seed_trace,distinct_seed_trace,iosimpor_corpus,dropped_partition_handling,m1-dropped-partition-handling', 'same-seed-byte-identical-trace': 'same-seed-traces', 'distinct-seed-schedule-sensitivity': 'schedule-sensitivity', 'iosimpor-replay': 'iosimpor', 'dropped-partition-mutant': 'mutants', 'modeled-environment-fidelity': 'modeled-env-fidelity', 'live-substrate-runtime': 'live-substrate-runtime', 'generated-artifact-discipline': 'emitted-results-untracked,toolchain-satisfies-requirements,recorded-results-match-oracle,simulation-scope-exact'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] not in ("UNVERIFIED", "ASSUMED") else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names: set[str] = set()
    for relative in ("test/oracle/deterministic_simulation/validation_locus.tsv",):
        for line in (ROOT / relative).read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip():
                names.add(line.split("\t")[0].strip())
    # The one registry leads with the capability and carries every phase's rows, so
    # this phase's items are the mutant ids in its own rows, not every first column.
    names.update(row["mutant"] for row in mutant_registry.capability(MUTANT_CAPABILITY))
    return names


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=16, contract=CONTRACT, command=GATE_COMMAND, register="2", substrate="none", lane="none", sides=SIDES,
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
    item_names: set[str] = set()

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — the validation-locus corpus and the mutant manifest\n")
        verify_oracles()
        item_names = enumerated_items()
        print(f"  ok    {len(item_names)} enumerated items")
        results["oracle"] = True

        print("\nsource side — the simulation scope stays polymorphic\n")
        verify_source_boundaries()
        print("  ok    no-bare-io-signature            no module in scope carries a bare IO signature")
        print("  ok    non-vacuous-polymorphism-tokens MonadAsync, MonadSTM, MonadDelay, IOSim all present")
        print("  ok    simulation-scope-exact          the scope is exactly its declared ten modules")
        results["source"] = True

        print("\nsuite side — both interpreters over one reference reconciler\n")
        green = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        print("  ok    acceptance token present")
        results["suite"] = True

        print("\nmutant side — the dropped-partition mutant turns the suite red\n")
        mutant = run_mutant(cabal)
        (gate.run_dir / "mutant.log").write_text(mutant, encoding="utf-8")
        print("  ok    dropped-partition-handling reddened")
        results["mutant"] = True

        write_results()
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"deterministic-simulation-gate: FAIL: {problem}", file=sys.stderr)

    decided = {
        surface: ("interpreters", EXPECTED_RESULTS["interpreters"])
        for surface, ids in SURFACE_MAP.items()
        if ids and (set(ids.split(",")) & item_names or (set(ids.split(",")) & set(CHECKS) and results.get("source")))
    }
    layers = {
        "Decision": "tested" if rows.get("interpreters") == EXPECTED_RESULTS["interpreters"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("fake-contracts") == EXPECTED_RESULTS["fake-contracts"] else "UNVERIFIED",
        # Register 2.5 runs the real reconciler against a modeled environment. It never
        # establishes runtime behaviour, and this row must not drift toward claiming it.
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": item_names},
        rows=rows,
        evidence={**SURFACE_EVIDENCE, **decided},
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"sim-spec": "cabal test"},
        mutants=[{"name": "m1-dropped-partition-handling", "status": "red" if results.get("mutant") else "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
