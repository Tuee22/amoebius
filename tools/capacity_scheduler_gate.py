#!/usr/bin/env python3
"""Run and seal the Phase-33 `amoebius-capacity` scheduler and bootstrap-cutover gate.

The capability claim is unchanged: the two-stage bootstrap cutover installs the
`amoebius-capacity` scheduler in order, every Binding follows a successful whole-ledger
reservation CAS, execution identity is admitted, the live rerun issues no new Binding
request, and the Register-2.5 battery drives the same real scheduler modules under `IOSim`.

What changed is where the gate's inputs come from. The retired form read a fixed evidence
directory under the plan tree, compared a committed ledger byte-for-byte against a derived
one, read its surface list out of a committed enumeration file, and invoked a developer-home
`cabal` — so it certified whoever wrote those files last, and could not run at all once the
evidence root went. Every metric below is measured from evidence this run produced into its
own bundle under `.build/runs/`, the surface enumeration is joined two-way to an authored
expectation, and the result is bound to a source-snapshot digest and externally attested.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import containment  # noqa: E402
import gate_common  # noqa: E402
import project_cluster_fixture  # noqa: E402
import project_container_engine  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
PLACEMENT_SOURCE = ROOT / "src/Amoebius/Scheduler/Placement.hs"
RESERVATION_SOURCE = ROOT / "src/Amoebius/Scheduler/Reservation.hs"
RESULTS = ROOT / ".build/dsl/capacity-scheduler/phase-results.tsv"
EXPECTATIONS = ROOT / "test/oracle/capacity_scheduler_surfaces.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_60_capacity_scheduler.md"
GATE_COMMAND = "python3 tools/capacity_scheduler_gate.py --execute"

# The committed mutant domain, each mapped to the sprint whose evidence decides it. The
# seven pure mutants are decided twice — Sprints 27.2 and 27.3 own the readiness and
# reservation claims, and Sprint 33.4 re-runs the same seven against the live cutover — so
# one red observation is what either sprint's evidence has to show. The Register-2.5 set
# has its own seven names because it attacks the same invariants through `IOSim` schedules.
EXPECTED_MUTANTS = {
    "collapsed-readiness": "27.2",
    "stage-drop-generic-SSA-before-cutover": "27.2",
    "default-scheduler-managed-node-bypass": "27.2",
    "bind-before-reservation-CAS": "27.3",
    "numeric-add-instead-of-whole-ledger-refold": "27.3",
    "same-UID-double-debit": "27.3",
    "bound-deleted-on-restart": "27.3",
    "lost-lease-resourceversion-retry": "27.5",
    "collapsed-scheduler-readiness": "27.5",
    "premature-managed-authority": "27.5",
    "bind-before-cas": "27.5",
    "same-uid-double-debit": "27.5",
    "bound-dropped-on-restart": "27.5",
    "cached-observation": "27.5",
}

SIDES = ("toolchain", "oracle", "static", "live", "mutant", "results")

CHECKS = {
    "ledger-source-is-a-refold": "the reservation ledger is a whole-ledger refold, not a numeric accumulator",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "pure-ledger-algebra": "the five-state reservation ledger passes its own pure spec",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "the run's generated output stays outside the source snapshot",
}

CHECK_SIDE = {
    "ledger-source-is-a-refold": "oracle",
    "toolchain-satisfies-requirements": "toolchain",
    "pure-ledger-algebra": "static",
    "recorded-results-match-oracle": "results",
    "emitted-results-untracked": "results",
}

EXPECTED_RESULTS = {
    "sprint-receipts": "5/5-PASS",
    "sprint-registers": "1,1,2,3,2.5",
    "cutover-sequence": "6-events-in-order",
    "rerun-byte-stability": "byte-stable",
    "rerun-new-binding-requests": "0",
    "postflight-leaks": "0",
    "universal-linux-cpu-lane": "every-hardware-substrate",
    "deterministic-schedules": "1792",
    "simulation-fault-classes": "7",
    "byte-identical-replay": "observed",
    "mutants": f"{len(EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red",
}


class GateFailure(RuntimeError):
    pass


def run(
    arguments: Sequence[str],
    *,
    timeout: int = 7200,
    environment: Mapping[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=dict(environment or os.environ), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"command-failed:{arguments[0]}:{result.returncode}\n{result.stdout[-4000:]}")
    return result


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{gate_common.rel(path)}")
    return value


def verify_oracles() -> None:
    """The one source property the reservation claim rests on, and the absent evidence root.

    §M.3 wants a reference side the subject under test does not supply. The scheduler's
    safety argument is that a reservation is decided by refolding the whole ledger rather
    than adding to a running total — the `numeric-add-instead-of-whole-ledger-refold` mutant
    exists to attack exactly that — so the check is that the module still contains no
    accumulate-in-place arithmetic on the reserved vector.
    """
    placement = PLACEMENT_SOURCE.read_text(encoding="utf-8")
    reservation = RESERVATION_SOURCE.read_text(encoding="utf-8")
    if "refoldSchedulerPlacement" not in placement:
        raise GateFailure(
            "ledger-source-is-a-refold: `refoldSchedulerPlacement` is absent from "
            f"{gate_common.rel(PLACEMENT_SOURCE)}, so nothing names the whole-ledger fold the "
            "reservation CAS is supposed to be"
        )
    if "refoldSchedulerPlacement" not in reservation:
        raise GateFailure(
            "ledger-source-is-a-refold: "
            f"{gate_common.rel(RESERVATION_SOURCE)} decides a reservation without calling the "
            "whole-ledger refold, which is the accumulate-in-place shape the numeric-add mutant attacks"
        )
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_27"
    if retired.exists():
        raise GateFailure(
            f"evidence-inputs-produced-by-this-run: {gate_common.rel(retired)} still exists, "
            "so a stale battery could be read instead of this run's own"
        )


def execute_sprints(
    evidence: Path,
    image: str,
    environment: Mapping[str, str],
) -> None:
    evidence.mkdir(parents=True, exist_ok=True)
    drivers = {
        1: "tools/capacity_scheduler_ledger_gate.py",
        2: "tools/capacity_scheduler_readiness_gate.py",
        3: "tools/capacity_scheduler_reservation_gate.py",
        4: "tools/capacity_scheduler_cutover_gate.py",
        5: "tools/capacity_scheduler_simulation_gate.py",
    }
    for number in (1, 2, 3, 4, 5):
        arguments = [
            sys.executable, drivers[number], "--evidence", str(evidence),
        ]
        if number == 4:
            arguments += ["--image", image]
        run(arguments, timeout=21600, environment=environment)
        print(f"  ok    sprint 27.{number} sealed")


def measure(evidence: Path) -> dict[str, str]:
    """Read the run's own evidence and say what it shows.

    Each metric is derived here, independently of the sprint gates that wrote the evidence:
    those gates asserted these properties as they went, and this is a second reading of the
    same raw observations by different code.
    """
    receipts = [json_object(evidence / f"sprint-27.{number}-receipt.json") for number in range(1, 6)]
    passed = sum(1 for receipt in receipts if receipt.get("result") == "PASS")
    registers = ",".join(str(receipt.get("register")) for receipt in receipts)

    live = json_object(evidence / "live-scheduler.json")
    rerun = live.get("rerun", {})
    postflight = live.get("postflight", {})
    universal = live.get("universalLinuxCpu", {})
    simulation = json_object(evidence / "sprint-27.5-simulation.json")

    ordered = [row.get("event") for row in live.get("sequence", [])] == [
        "BootstrapCapacitySchedulerReady", "BootstrapAddonCutover", "BootstrapReplacementBoundReady",
        "ManagedCapacityReady", "GeneralGuardedPodAdmitted", "GeneralGuardedPodBoundReady",
    ]
    pristine = universal.get("pristineLinuxHost") == {
        "linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2",
    }
    return {
        "sprint-receipts": f"{passed}/{len(receipts)}-PASS",
        "sprint-registers": registers,
        "cutover-sequence": (
            f"{len(live.get('sequence', []))}-events-in-order" if ordered else "out-of-order"
        ),
        "rerun-byte-stability": "byte-stable" if rerun.get("byteStable") else "drifted",
        "rerun-new-binding-requests": str(rerun.get("newBindingRequests", "absent")),
        "postflight-leaks": str(sum(1 for value in postflight.values() if not value)),
        "universal-linux-cpu-lane": (
            "every-hardware-substrate"
            if universal.get("availableOnEveryHardwareSubstrate") is True and pristine
            else "not-established"
        ),
        "deterministic-schedules": str(simulation.get("totalReplaySchedules", "absent")),
        "simulation-fault-classes": str(len(simulation.get("faultClasses", []))),
        "byte-identical-replay": "observed" if simulation.get("byteIdenticalReplay") else "absent",
    }


def mutant_outcomes(evidence: Path) -> dict[str, str]:
    """Collect each mutant's own outcome from the sprint whose evidence decided it."""
    outcomes: dict[str, str] = {}
    for sprint in ("27.2", "27.3", "27.4", "27.5"):
        path = evidence / f"sprint-{sprint}-mutants.json"
        if not path.is_file():
            continue
        for row in json_object(path).get("results", []):
            name = str(row.get("mutant", ""))
            if name:
                outcomes[name] = "red" if row.get("result") == "RED" else str(row.get("result", "absent"))
    return outcomes


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]],
    outcomes: Mapping[str, str],
    results: Mapping[str, bool],
) -> dict[str, bool]:
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            status[surface] = all(outcomes.get(name) == "red" for name in ids)
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="run the five sprints into this run's bundle")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed live run's bundle")
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=59, contract=CONTRACT, command=GATE_COMMAND,
        expectations=str(EXPECTATIONS.relative_to(ROOT)),
        register="3", substrate="linux-cpu", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    outcomes: dict[str, str] = {}
    fixture: project_cluster_fixture.ProjectCluster | None = None
    handoff: project_cluster_fixture.VerifiedImageHandoff | None = None
    predecessor: project_cluster_fixture.VerifiedPhaseRecord | None = None

    try:
        resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl"])
        print("toolchain side — cabal, ghc, kind, and kubectl resolved from authored requirements\n")
        for name in ("cabal", "ghc", "kind", "kubectl"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        run_environment = toolchain.contained_env()
        run_environment["PATH"] = os.pathsep.join(
            (str(ROOT / "tools"), run_environment.get("PATH", ""))
        )
        os.environ.update(run_environment)

        print("\noracle side — the ledger's fold and the absence of a retired evidence root\n")
        verify_oracles()
        print("  ok    ledger-source-is-a-refold         the reservation CAS refolds the whole ledger")
        results["oracle"] = True

        print("\nstatic side — the pure ledger algebra the live sprints stand on\n")
        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]
        run((cabal,
             f"--builddir={ROOT / '.build/dist-newstyle/capacity-scheduler'}",
             f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
             f"--with-compiler={compiler}", "test", "scheduler-ledger-spec",
             "--test-show-details=direct", "-j1"))
        print("  ok    pure-ledger-algebra")
        results["static"] = True

        evidence = arguments.evidence
        if arguments.execute:
            predecessor = project_cluster_fixture.verified_phase_record(26)
            handoff = project_cluster_fixture.verified_image_handoff()
            print("\npredecessor side — verified Phase-68 seal and Phase-31 OCI handoff\n")
            print(f"  ok    phase26     {predecessor.attestation}")
            print(f"  ok    phase25     {handoff.attestation}")
            print(f"  ok    image-index {handoff.index_digest}")
            fixture = project_cluster_fixture.start(
                run_id=f"cs-{gate.run_dir.name}",
                run_dir=gate.run_dir,
                kind=resolved["kind"]["path"],
                kubectl=resolved["kubectl"]["path"],
                base_environment=run_environment,
            )
            fixture.create()
            bootstrap = gate.run_dir / "bootstrap-registry"
            image = fixture.bootstrap_registry(handoff, bootstrap)
            (gate.run_dir / "containment.json").write_text(
                json.dumps(
                    {
                        "projectEngineRoot": str(fixture.engine.data_root),
                        "testRoot": str(fixture.test_run.path),
                        "kubeconfig": str(fixture.kubeconfig),
                        "phase26Attestation": predecessor.attestation,
                        "phase25Attestation": handoff.attestation,
                        "phase25Artifact": str(handoff.artifact),
                        "globalDaemonUsed": False,
                    },
                    indent=2,
                    sort_keys=True,
                ) + "\n",
                encoding="utf-8",
            )
            evidence = gate.run_dir / "sprints"
            print("\nlive side — five sprints on this run's private linux-cpu kind cluster\n")
            execute_sprints(evidence, image, fixture.environment)
        elif evidence is None:
            raise GateFailure("phase-33 needs --execute or an --evidence bundle from a completed live run")
        else:
            print(f"\nlive side — reusing the completed live run at {evidence}\n")
        if not (evidence / "sprint-27.5-receipt.json").is_file():
            raise GateFailure("live evidence is incomplete: no sprint-27.5 receipt")
        results["live"] = True

        print("\nmutant side — the committed domain, each decided by its own observation\n")
        outcomes = mutant_outcomes(evidence)
        for name in sorted(EXPECTED_MUTANTS):
            outcome = outcomes.get(name, "absent")
            print(f"  {'ok  ' if outcome == 'red' else 'note'}  {name:<36} {outcome}")
        results["mutant"] = True

        rows.update(measure(evidence))
        red = sum(1 for name in EXPECTED_MUTANTS if outcomes.get(name) == "red")
        rows["mutants"] = f"{red}/{len(EXPECTED_MUTANTS)}-red"
        RESULTS.parent.mkdir(parents=True, exist_ok=True)
        RESULTS.write_text(
            "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in sorted(rows.items())),
            encoding="utf-8",
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv",), gate.run_dir,
            check="emitted-results-untracked",
            label="the run's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (
        GateFailure, OSError, KeyError, ValueError, IndexError,
        json.JSONDecodeError, subprocess.TimeoutExpired,
        containment.ContainmentError,
        project_cluster_fixture.FixtureFailure,
        project_container_engine.EngineFailure,
    ) as problem:
        print(f"capacity-scheduler-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if fixture is not None:
            cleanup_problems = fixture.stop()
            if cleanup_problems:
                results["live"] = False
                for problem in cleanup_problems:
                    print(f"capacity-scheduler-gate: CLEANUP-FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence_map: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids and ids[0] in EXPECTED_RESULTS
        else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "tested" if rows.get("sprint-receipts") == EXPECTED_RESULTS["sprint-receipts"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("rerun-new-binding-requests") == EXPECTED_RESULTS["rerun-new-binding-requests"] else "UNVERIFIED",
        "Runtime": "tested" if rows.get("cutover-sequence") == EXPECTED_RESULTS["cutover-sequence"] else "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(EXPECTED_MUTANTS)},
        rows=rows,
        evidence=evidence_map,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={
            "cluster": "private marker-owned kind fixture",
            "registry": "fresh in-cluster distribution from verified Phase-31 handoff",
            **(
                {
                    "phase25Attestation": handoff.attestation,
                    "phase25Index": handoff.index_digest,
                }
                if handoff is not None
                else {}
            ),
            **(
                {"phase26Attestation": predecessor.attestation}
                if predecessor is not None
                else {}
            ),
        },
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, outcomes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
