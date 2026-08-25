#!/usr/bin/env python3
"""Phase 20: pure reconcile core and bounded deterministic simulation."""

from __future__ import annotations

import csv
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / ".build/dsl/reconcile-core/phase-results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/reconcile-core-simulation"
CONTRACT = "DEVELOPMENT_PLAN/phase_20_reconcile_core_simulation.md"
GATE_COMMAND = "python3 tools/reconcile_core_simulation_gate.py"
EXPECTATIONS = "test/oracle/reconcile_core_simulation_surfaces.tsv"
CAPABILITY = "reconcile_core"

CHECKS = {
    "core-reference-independent": "the flat reference planner imports no production reconcile code",
    "core-source-boundary": "the pure core imports no effect, client, process, or network module",
    "results-untracked": "generated metrics remain beneath .build/** and outside the source snapshot",
    "toolchain-satisfies-requirements": "resolved cabal and GHC satisfy authored ranges",
    "recorded-results-match-oracle": "all thirteen exact metrics match the contract",
}

SIDES = ("toolchain", "source", "suite", "typed", "mutant", "oracle", "artifact")

EXPECTED_RESULTS = {
    "core-corpus": "9/9-actual-reference",
    "fixed-points": "2/2-green",
    "schedule-convergence": "4/4-green",
    "same-seed-traces": "4/4-byte-identical",
    "seed-sensitivity": "1/1-distinct",
    "iosimpor": "4/4-green",
    "snapshot-token": "1-accepted/1-reuse-rejected",
    "reservation-protocol": "1-debit/3-crash-cuts-bound",
    "formal-correspondence": "4/4-linked",
    "typed-delete-witness": "positive-green/negative-type-red",
    "mutants": "5/5-red-exactly",
    "modeled-environment-fidelity": "ASSUMED",
    "runtime-fidelity": "UNVERIFIED",
}

SURFACE_EVIDENCE = {
    "actual-core-corpus": ("core-corpus", "9/9-actual-reference"),
    "fixed-point": ("fixed-points", "2/2-green"),
    "bounded-convergence": ("schedule-convergence", "4/4-green"),
    "same-seed-determinism": ("same-seed-traces", "4/4-byte-identical"),
    "changed-seed-sensitivity": ("seed-sensitivity", "1/1-distinct"),
    "iosimpor-replay": ("iosimpor", "4/4-green"),
    "snapshot-token-protocol": ("snapshot-token", "1-accepted/1-reuse-rejected"),
    "reservation-protocol": ("reservation-protocol", "1-debit/3-crash-cuts-bound"),
    "phase18-formal-correspondence": ("formal-correspondence", "4/4-linked"),
    "typed-delete-witness": ("typed-delete-witness", "positive-green/negative-type-red"),
    "exact-mutant-loci": ("mutants", "5/5-red-exactly"),
    "modeled-environment-fidelity": None,
    "runtime-fidelity": None,
    "independent-reference-planner": ("core-corpus", "9/9-actual-reference"),
    "source-boundary": ("core-corpus", "9/9-actual-reference"),
    "fixed-point-mutant": ("mutants", "5/5-red-exactly"),
    "convergence-mutant": ("mutants", "5/5-red-exactly"),
    "token-mutant": ("mutants", "5/5-red-exactly"),
    "reservation-mutant": ("mutants", "5/5-red-exactly"),
    "delete-witness-mutant": ("typed-delete-witness", "positive-green/negative-type-red"),
}


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    return value


def run(
    command: list[str], *, require_success: bool = True
) -> subprocess.CompletedProcess[str]:
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
        raise GateFailure(
            f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-10000:]}"
        )
    return result


def cabal_command(resolved: dict[str, Any], *arguments: str) -> list[str]:
    return [
        resolved["cabal"]["path"],
        f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
        "--jobs=1",
        *arguments,
    ]


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — compiler and build driver from authored requirements\n")
    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("ghc", "cabal"):
        record = resolved[name]
        print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
    return True, resolved


def source_side() -> bool:
    print("\nsource side — pure decision core and independent textual observer\n")
    core = (ROOT / "src/reconcile-core/Amoebius/Reconcile/Core.hs").read_text(encoding="utf-8")
    simulation = (ROOT / "src/reconcile-core/Amoebius/Reconcile/Sim.hs").read_text(encoding="utf-8")
    reference = (ROOT / "test/harness/reconcile_core/ReferencePlanner.hs").read_text(encoding="utf-8")
    forbidden = ("Control.Concurrent", "System.Process", "Network.", "Amoebius.Sim.Interp.Real")
    problems = [token for token in forbidden if token in core]
    if ":: IO " in core or ":: IO\n" in core:
        problems.append("bare IO signature")
    if problems:
        print(f"  FAIL  core-source-boundary forbidden token(s): {', '.join(problems)}")
        return False
    required = ("MonadSTM", "MonadDelay", "SnapshotToken", "simulateReconcile")
    missing = [token for token in required if token not in simulation]
    if missing:
        print(f"  FAIL  core-source-boundary missing simulation seam(s): {', '.join(missing)}")
        return False
    if "Amoebius.Reconcile" in reference:
        print("  FAIL  core-reference-independent imports production reconcile code")
        return False
    if "DeleteObject" not in core or "Observation 'IsPresent" not in core:
        print("  FAIL  core-source-boundary Delete lacks its Present-indexed witness")
        return False
    print("  ok    core-source-boundary pure planner imports no effect/client/process/network surface")
    print("  ok    core-reference-independent flat reference observer imports no production core")
    print("  ok    simulation seam is polymorphic in MonadSTM/MonadDelay")
    return True


def read_results() -> dict[str, str]:
    rows: dict[str, str] = {}
    if not RESULTS.is_file():
        return rows
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, separator, value = line.partition("\t")
        if separator:
            rows[key] = value
    return rows


def write_results(rows: dict[str, str]) -> None:
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n"
        + "".join(f"{key}\t{rows[key]}\n" for key in EXPECTED_RESULTS if key in rows),
        encoding="utf-8",
    )


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nsuite side — actual core, authored corpus, IOSim/POR, and protocol schedules\n")
    try:
        result = run(
            cabal_command(
                resolved,
                "test",
                "reconcile-core-simulation-spec",
                "reconcile-core-delete-witness",
                "--test-show-details=direct",
            )
        )
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  reconcile suites; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    token = "reconcile-core-simulation-spec: PASS (9 core cases, 4 schedules, 4 IOSimPOR, 2 protocols, 4 formal links)"
    if token not in result.stdout:
        print("  FAIL  reconcile-core-simulation-spec acceptance token absent")
        return False, {}
    rows = read_results()
    print(f"  ok    reconcile-core-simulation-spec green; {len(rows)} suite metric(s) recorded")
    print("  ok    reconcile-core-delete-witness legal Present twin compiles and runs")
    return True, rows


def mutation_catalog() -> list[dict[str, str]]:
    path = ROOT / "test/oracle/reconcile_core/mutation_catalog.tsv"
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def typed_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\ntyped side — Delete requires a Present observation witness\n")
    result = run(
        cabal_command(
            resolved,
            "build",
            "test:reconcile-core-delete-witness",
            "--flags=reconcile-core-delete-unreachable-mutant",
        ),
        require_success=False,
    )
    (run_dir / "delete-unreachable.log").write_text(result.stdout, encoding="utf-8")
    required = (
        "Couldn't match type ‘IsUnreachable’ with ‘IsPresent’",
        "UnreachableObservation \"timeout\"",
    )
    if result.returncode == 0 or not all(token in result.stdout for token in required):
        print("  FAIL  unreachable Delete compiled or missed its exact type reason")
        return False
    print("  ok    delete-unreachable-witness red at IsUnreachable/IsPresent type mismatch")
    return True


def mutant_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\nmutant side — four behavioral defects and one type defect\n")
    catalog = mutation_catalog()
    registry = mutant_registry.capability(CAPABILITY)
    expected = {row["mutant"]: row["red_property"] for row in catalog}
    if len(expected) != 5 or {row["mutant"] for row in registry} != set(expected):
        print("  FAIL  mutation catalogue and one registry do not name the same five mutants")
        return False
    ok = True
    for mutant, property_name in expected.items():
        if mutant == "delete-unreachable-witness":
            continue
        result = run(
            cabal_command(
                resolved,
                "test",
                "reconcile-core-simulation-spec",
                "--test-show-details=direct",
                f"--test-options=--mutant={mutant}",
            ),
            require_success=False,
        )
        (run_dir / f"mutant-{mutant}.log").write_text(result.stdout, encoding="utf-8")
        token = f"reconcile-core-mutant: RED {mutant} {property_name}"
        if result.returncode == 0 or token not in result.stdout:
            print(f"  FAIL  {mutant:<28} survived or missed {property_name}")
            ok = False
        else:
            print(f"  ok    {mutant:<28} reddens {property_name}")
    if ok:
        print("  ok    delete-unreachable-witness   reddens DeleteRequiresPresentWitness")
    return ok


def oracle_side(rows: dict[str, str]) -> bool:
    print("\noracle side — complete results against exact authored metrics\n")
    ok = True
    for key, expected in EXPECTED_RESULTS.items():
        actual = rows.get(key)
        if actual != expected:
            print(f"  FAIL  recorded-results-match-oracle {key}: {actual!r} != {expected!r}")
            ok = False
    extras = sorted(set(rows) - set(EXPECTED_RESULTS))
    if extras:
        print(f"  FAIL  recorded-results-match-oracle unexpected metric(s): {', '.join(extras)}")
        ok = False
    if ok:
        print(f"  ok    recorded-results-match-oracle all {len(EXPECTED_RESULTS)} metrics match")
    return ok


def artifact_side() -> bool:
    print("\nartifact side — generated metrics remain project-contained\n")
    if not RESULTS.is_file():
        print("  FAIL  results-untracked phase-results.tsv is absent")
        return False
    relative = gate_common.rel(RESULTS)
    if relative in set(artifact_policy.snapshot_paths()):
        print(f"  FAIL  results-untracked {relative} entered the source snapshot")
        return False
    if not relative.startswith(".build/"):
        print(f"  FAIL  results-untracked {relative} escaped .build/**")
        return False
    print(f"  ok    results-untracked {relative} is generated and untracked")
    return True


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=19,
        contract=CONTRACT,
        command=GATE_COMMAND,
        expectations=EXPECTATIONS,
        register="2",
        substrate="none",
        lane="none",
        sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    results["toolchain"], resolved = toolchain_side()
    rows: dict[str, str] = {}
    if results["toolchain"]:
        results["source"] = source_side()
        results["suite"], rows = suite_side(resolved, gate.run_dir)
    if results["suite"]:
        results["typed"] = typed_side(resolved, gate.run_dir)
        results["mutant"] = mutant_side(resolved, gate.run_dir)
        if results["typed"]:
            rows["typed-delete-witness"] = "positive-green/negative-type-red"
        if results["typed"] and results["mutant"]:
            rows["mutants"] = "5/5-red-exactly"
        write_results(rows)
        results["oracle"] = oracle_side(rows)
        results["artifact"] = artifact_side()

    implemented = {
        "metrics": set(rows),
        "checks": set(CHECKS),
        "mutants": {row["mutant"] for row in mutant_registry.capability(CAPABILITY)},
    }
    results["surface"], surfaces = gate.surface_join(implemented)
    status: dict[str, bool] = {}
    for surface in surfaces:
        evidence = SURFACE_EVIDENCE.get(surface)
        status[surface] = bool(evidence) and rows.get(evidence[0]) == evidence[1]
    status["generated-artifact-discipline"] = results["artifact"]

    decision_green = all(
        rows.get(key) == expected
        for key, expected in {
            "core-corpus": "9/9-actual-reference",
            "fixed-points": "2/2-green",
            "schedule-convergence": "4/4-green",
        }.items()
    )
    protocol_green = all(
        rows.get(key) == expected
        for key, expected in {
            "snapshot-token": "1-accepted/1-reuse-rejected",
            "reservation-protocol": "1-debit/3-crash-cuts-bound",
            "formal-correspondence": "4/4-linked",
        }.items()
    )
    layers = {
        "Decision": "tested" if decision_green else "UNVERIFIED",
        "Protocol": "tested" if protocol_green else "UNVERIFIED",
        "Modeled environment fidelity": "ASSUMED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"reconcile-core-simulation-spec": "cabal test"},
        checks=results,
        mutants=[
            {"name": row["mutant"], "status": row["red_property"]}
            for row in mutation_catalog()
        ],
        observations={"results": "sha256:" + artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
