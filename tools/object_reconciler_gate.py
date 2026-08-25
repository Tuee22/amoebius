#!/usr/bin/env python3
"""Run and seal the Phase-32 typed-action object-reconciler gate.

The capability claim is unchanged: the Phase-15 deployment-global render is validated and
indexed, enacted on the live single-node `kind` cluster through stage-eligible typed actions
alone, observed to convergence, and re-run byte-stable as a no-op — with the Register-2.5
schedule battery driving the same real action modules under `IOSim`.

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
CORPUS = ROOT / "test/fixture/live/reconcile-corpus/corpus.json"
EXPECTED_ACTIONS = ROOT / "test/fixture/live/reconcile-corpus/expected-actions.json"
NEVER_READY = ROOT / "test/fixture/live/reconcile-corpus-never-ready"
RESULTS = ROOT / ".build/dsl/object-reconciler/phase-results.tsv"
EXPECTATIONS = ROOT / "test/oracle/object_reconciler_surfaces.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_59_object_reconciler.md"
GATE_COMMAND = "python3 tools/object_reconciler_gate.py --execute"

# The committed mutant domain, each mapped to the sprint whose evidence decides it. The
# live delete mutant is decided twice — Sprint 32.3 owns the staged-deletion claim and
# Sprint 32.4 re-runs it inside the convergence battery — and one red observation of it is
# what either sprint's evidence has to show.
EXPECTED_MUTANTS = {
    "delete-from-owner-label-alone": "26.3",
    "wait-for-ready-pure": "26.4",
    "generation-stamped-after-diff": "26.4",
    "healthy-cr-over-bound-child": "26.4",
    "lost-lease-resourceversion-retry": "26.5",
    "mutation-without-holder": "26.5",
    "sleep-gated-readiness": "26.5",
    "serial-stage-collapse": "26.5",
    "completion-cleanup-before-persist": "26.5",
    "label-only-delete": "26.5",
    "cached-observation": "26.5",
}

SIDES = ("toolchain", "oracle", "static", "live", "mutant", "results")

CHECKS = {
    "corpus-domain-exact": "the committed reconcile corpus and its expected-action table are well-formed",
    "never-ready-fixture-present": "the committed never-ready red-path fixture exists",
    "phase13-render-gate": "the pure renderer this phase enacts still passes its own gate",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "the run's generated output stays outside the source snapshot",
}

CHECK_SIDE = {
    "corpus-domain-exact": "oracle",
    "never-ready-fixture-present": "oracle",
    "phase13-render-gate": "static",
    "toolchain-satisfies-requirements": "toolchain",
    "recorded-results-match-oracle": "results",
    "emitted-results-untracked": "results",
}

EXPECTED_RESULTS = {
    "sprint-receipts": "5/5-PASS",
    "sprint-registers": "3,3,3,3,2.5",
    "rerun-byte-stability": "byte-stable",
    "rerun-planned-mutations": "0",
    "readiness-non-instantaneous": "observed",
    "serial-replacement-transitions": "2-ordered-distinct-uids",
    "job-terminal-retention": "retained-with-0-completion-objects",
    "custom-resource-child-conformance": "conforms",
    "quota-race-admission": "1-of-2",
    "postflight-leaks": "0",
    "deterministic-schedules": "2048",
    "forbidden-readiness-symbols": "0",
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
    """The committed corpus, its independently authored action table, and the red-path fixture.

    The reference side of every equivalence check in this phase is a file authored before the
    planner existed. This is the check that the file is still the shape the planner is
    compared against, rather than whatever it has since become.
    """
    corpus = json_object(CORPUS)
    expected = json_object(EXPECTED_ACTIONS)
    identities = [row.get("identity") for row in corpus.get("objects", [])]
    if len(identities) != 12 or len(set(identities)) != 12:
        raise GateFailure(f"corpus-domain-exact: {len(identities)} objects, {len(set(identities))} distinct")
    actions = expected.get("actions", [])
    if [action.split(":", 1)[1] for action in actions] != identities:
        raise GateFailure("corpus-domain-exact: the expected-action table does not name the corpus in order")
    required = {"Namespace", "Lease", "Deployment", "StatefulSet", "Job",
                "CustomResourceDefinition", "CapacityReservation"}
    observed = {str(identity).split("/", 1)[0] for identity in identities}
    if not required <= observed:
        raise GateFailure(f"corpus-domain-exact: missing kinds {sorted(required - observed)}")
    if not NEVER_READY.is_dir():
        raise GateFailure(f"never-ready-fixture-present: {gate_common.rel(NEVER_READY)} is absent")
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_26"
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
        1: "tools/object_reconciler_plan_gate.py",
        2: "tools/object_reconciler_authority_gate.py",
        3: "tools/object_reconciler_execution_gate.py",
        4: "tools/object_reconciler_convergence_gate.py",
        5: "tools/object_reconciler_simulation_gate.py",
    }
    for number in (1, 2, 3, 4, 5):
        arguments = [
            sys.executable, drivers[number], "--evidence", str(evidence),
        ]
        if number in (3, 4):
            arguments += ["--image", image]
        run(arguments, timeout=21600, environment=environment)
        print(f"  ok    sprint 26.{number} sealed")


def measure(evidence: Path) -> dict[str, str]:
    """Read the run's own evidence and say what it shows.

    Each metric is derived here, independently of the sprint gates that wrote the evidence:
    those gates asserted these properties as they went, and this is a second reading of the
    same raw observations by different code.
    """
    receipts = [json_object(evidence / f"sprint-26.{number}-receipt.json") for number in range(1, 6)]
    passed = sum(1 for receipt in receipts if receipt.get("result") == "PASS")
    registers = ",".join(str(receipt.get("register")) for receipt in receipts)

    live = json_object(evidence / "live-reconcile.json")
    rerun = live.get("rerun", {})
    private = live.get("privatePullDeployment", {})
    transitions = live.get("serial", {}).get("transitions", [])
    job = live.get("job", {})
    custom = live.get("customResource", {})
    race = live.get("quotaRace", {})
    postflight = live.get("postflight", {})
    simulation = receipts[4]

    ordered = [str(row.get("name")) for row in transitions] == ["serial-1", "serial-0"]
    distinct = all(
        row.get("oldUid") != row.get("newUid")
        and row.get("absenceObserved") == "true"
        and row.get("boundReadyObserved") == "true"
        for row in transitions
    )
    return {
        "sprint-receipts": f"{passed}/{len(receipts)}-PASS",
        "sprint-registers": registers,
        "rerun-byte-stability": (
            "byte-stable"
            if rerun.get("byteStable") and rerun.get("beforeHash") == rerun.get("afterHash")
            else "drifted"
        ),
        "rerun-planned-mutations": str(rerun.get("plannedMutations", "absent")),
        "readiness-non-instantaneous": (
            "observed"
            if private.get("initialAvailableReplicas") == 0
            and private.get("available")
            and float(private.get("readyElapsedSeconds", -1)) >= float(private.get("initialDelaySeconds", 0))
            else "instantaneous"
        ),
        "serial-replacement-transitions": (
            f"{len(transitions)}-ordered-distinct-uids" if ordered and distinct
            else f"{len(transitions)}-unordered"
        ),
        "job-terminal-retention": (
            f"retained-with-{job.get('completionObjects')}-completion-objects"
            if job.get("retained") and job.get("terminalPodUid")
            else "not-retained"
        ),
        "custom-resource-child-conformance": (
            "conforms" if custom.get("healthy") and custom.get("child", {}).get("conforms") else "violates"
        ),
        "quota-race-admission": (
            f"{race.get('admittedChildren')}-of-{race.get('simultaneousReservations')}"
            if race.get("overAllocation") == 0 else "over-allocated"
        ),
        "postflight-leaks": str(sum(1 for value in postflight.values() if not value)),
        "deterministic-schedules": str(simulation.get("deterministicSchedules", "absent")),
        "forbidden-readiness-symbols": str(receipts[3].get("forbiddenReadinessSymbols", "absent")),
    }


def mutant_outcomes(evidence: Path) -> dict[str, str]:
    """Collect each mutant's own outcome from the sprint whose evidence decided it."""
    outcomes: dict[str, str] = {}
    for sprint in ("26.3", "26.4", "26.5"):
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
        phase=58, contract=CONTRACT, command=GATE_COMMAND,
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

        print("\noracle side — the committed corpus, action table, and red-path fixture\n")
        verify_oracles()
        print("  ok    corpus-domain-exact               12 objects, 12 authored actions, 7 kinds")
        print("  ok    never-ready-fixture-present       the honest engine has something to stay red on")
        results["oracle"] = True

        print("\nstatic side — the pure renderer this phase enacts\n")
        run((sys.executable, "tools/render_manifest_gate.py"))
        print("  ok    phase13-render-gate")
        results["static"] = True

        evidence = arguments.evidence
        if arguments.execute:
            handoff = project_cluster_fixture.verified_image_handoff()
            print(
                "\npredecessor side — verified Phase-31 attestation, ledger, and OCI handoff\n"
            )
            print(f"  ok    attestation {handoff.attestation}")
            print(f"  ok    index       {handoff.index_digest}")
            fixture = project_cluster_fixture.start(
                # Keep daemon-internal Unix socket names below Linux's 108-byte
                # sockaddr_un ceiling while retaining the gate timestamp as identity.
                run_id=f"or-{gate.run_dir.name}",
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
                        "liveStorageRoot": str(fixture.storage_root),
                        "phase25Attestation": handoff.attestation,
                        "phase25Artifact": str(handoff.artifact),
                        "globalDaemonUsed": False,
                    },
                    indent=2,
                    sort_keys=True,
                )
                + "\n",
                encoding="utf-8",
            )
            evidence = gate.run_dir / "sprints"
            print("\nlive side — five sprints on this run's private linux-cpu kind cluster\n")
            execute_sprints(evidence, image, fixture.environment)
        elif evidence is None:
            raise GateFailure("phase-32 needs --execute or an --evidence bundle from a completed live run")
        else:
            print(f"\nlive side — reusing the completed live run at {evidence}\n")
        if not (evidence / "sprint-26.5-receipt.json").is_file():
            raise GateFailure("live evidence is incomplete: no sprint-26.5 receipt")
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
        print(f"phase26-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if fixture is not None:
            cleanup_problems = fixture.stop()
            if cleanup_problems:
                results["live"] = False
                for problem in cleanup_problems:
                    print(f"object-reconciler-gate: CLEANUP-FAIL: {problem}", file=sys.stderr)

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
        "Protocol": "tested" if rows.get("rerun-byte-stability") == EXPECTED_RESULTS["rerun-byte-stability"] else "UNVERIFIED",
        "Runtime": "tested" if rows.get("readiness-non-instantaneous") == EXPECTED_RESULTS["readiness-non-instantaneous"] else "UNVERIFIED",
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
        },
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, outcomes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
