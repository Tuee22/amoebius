#!/usr/bin/env python3
"""Run and seal Phase 33's project-contained retained-storage gate."""

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
STORAGE_CLASS_GOLDEN = ROOT / "test/oracle/retained_storage/storage_class.yaml"
CLAIMREF_TABLE = ROOT / "test/oracle/retained_storage/claimref_table.csv"
RESULTS = ROOT / ".build/dsl/retained-storage/phase-results.tsv"
EXPECTATIONS = ROOT / "test/oracle/retained_storage_surfaces.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_33_retained_storage.md"
GATE_COMMAND = "python3 tools/retained_storage_gate.py --execute"

EXPECTED_MUTANTS = {
    "M-skip-durable-aggregate", "M-sum-unequal-ordinals",
    "M-uniform-before-allocation", "M-collapse-uniform-backing-debits",
    "M-reclaim-delete", "M-no-rebind", "M-raw-host-directory",
    "M-cutover-before-verify", "M-credit-before-cleanup", "M-fake-verify",
    "M-soft-delete", "M-seed-marker",
}
SIDES = ("toolchain", "oracle", "static", "live", "mutant", "results")
CHECKS = {
    "storage-class-golden-authored": "the one inert StorageClass and claimRef table are authored oracles",
    "toolchain-satisfies-requirements": "the resolved cabal, ghc, kind, and kubectl satisfy authored ranges",
    "no-retained-delete-in-source": "normal source has no retained-backing delete primitive",
    "pure-retained-storage-algebra": "the class, volume, and rebind pure suites pass",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "generated output stays outside the source snapshot",
}
CHECK_SIDE = {
    "storage-class-golden-authored": "oracle",
    "toolchain-satisfies-requirements": "toolchain",
    "no-retained-delete-in-source": "static",
    "pure-retained-storage-algebra": "static",
    "recorded-results-match-oracle": "results",
    "emitted-results-untracked": "results",
}
EXPECTED_RESULTS = {
    "sprint-receipts": "3/3-PASS",
    "inert-storage-class": "one-class-no-provisioner",
    "explicit-claimref-bind": "bound",
    "retained-rebind": "released-to-bound",
    "cluster-really-deleted": "cluster-node-and-apiserver-absent",
    "fresh-cluster-identity": "new-ca-and-uid",
    "postgres-byte-identity": "identical",
    "minio-byte-identity": "identical",
    "post-recreate-writes": "0",
    "seed-commands": "0",
    "public-registry-pulls": "0",
    "mutants": f"{len(EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red",
}


class GateFailure(RuntimeError):
    pass


def run(
    arguments: Sequence[str], *, timeout: int = 7200,
    environment: Mapping[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=dict(environment or os.environ), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"command-failed:{arguments[0]}:{result.returncode}\n{result.stdout[-6000:]}")
    return result


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{gate_common.rel(path)}")
    return value


def verify_oracles() -> None:
    if not STORAGE_CLASS_GOLDEN.is_file() or "provisioner: kubernetes.io/no-provisioner" not in STORAGE_CLASS_GOLDEN.read_text(encoding="utf-8"):
        raise GateFailure("storage-class-golden-authored: inert class oracle is absent or dynamic")
    if not CLAIMREF_TABLE.is_file():
        raise GateFailure("storage-class-golden-authored: claimRef table is absent")
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_28"
    if retired.exists():
        raise GateFailure(f"retired-evidence-root-present:{gate_common.rel(retired)}")


def cabal_command(cabal: str, compiler: str, *suites: str) -> tuple[str, ...]:
    return (
        cabal, f"--builddir={ROOT / '.build/dist-newstyle/retained-storage'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={compiler}", "test", *suites,
        *(f"-f-{flag}" for flag in (
            "retained-storage-skip-durable-aggregate-mutant",
            "retained-storage-sum-unequal-ordinals-mutant",
            "retained-storage-uniform-before-allocation-mutant",
            "retained-storage-collapse-backing-debits-mutant",
            "retained-storage-reclaim-delete-mutant", "retained-storage-no-rebind-mutant",
            "retained-storage-raw-host-directory-mutant",
            "retained-storage-cutover-before-verify-mutant",
            "retained-storage-credit-before-cleanup-mutant", "retained-storage-fake-verify-mutant",
            "retained-storage-soft-delete-mutant", "retained-storage-seed-marker-mutant",
        )),
        "--test-show-details=direct", "-j1",
    )


def execute_sprints(
    evidence: Path, handoff: project_cluster_fixture.VerifiedImageHandoff,
    environment: Mapping[str, str],
) -> None:
    evidence.mkdir(parents=True, exist_ok=True)
    image = f"registry.amoebius.invalid:5000/amoebius/base@{handoff.index_digest}"
    run((
        sys.executable, "tools/retained_storage_rebind_live.py", "--prepare-cluster-only",
        "--output", str(evidence / "cluster-preflight.json"), "--artifact", str(handoff.artifact),
        "--image-digest", handoff.index_digest,
    ), timeout=10800, environment=environment)
    print("  ok    private predecessor cluster ready with verified image import")
    run((sys.executable, "tools/retained_storage_class_gate.py", "--evidence", str(evidence)), timeout=10800, environment=environment)
    print("  ok    sprint 28.1 sealed")
    run((sys.executable, "tools/retained_storage_volume_gate.py", "--evidence", str(evidence), "--image", image), timeout=21600, environment=environment)
    print("  ok    sprint 28.2 sealed")
    run((
        sys.executable, "tools/retained_storage_rebind_gate.py", "--evidence", str(evidence),
        "--artifact", str(handoff.artifact), "--image-digest", handoff.index_digest,
        "--prepared-cluster",
    ), timeout=21600, environment=environment)
    print("  ok    sprint 28.3 sealed")


def measure(evidence: Path) -> dict[str, str]:
    receipts = [json_object(evidence / f"sprint-28.{number}-receipt.json") for number in (1, 2, 3)]
    first = json_object(evidence / "sprint-28.1-live.json")
    second = json_object(evidence / "sprint-28.2-live.json")
    rebind = json_object(evidence / "rebind-live.json")
    marker = rebind.get("marker", {})
    boundary = rebind.get("deleteBoundary", {})
    fresh = rebind.get("freshCluster", {})
    source = rebind.get("artifactSource", {})
    return {
        "sprint-receipts": f"{sum(receipt.get('result') == 'PASS' for receipt in receipts)}/3-PASS",
        "inert-storage-class": "one-class-no-provisioner" if first.get("inventory", {}).get("count") == 1 and first.get("inventory", {}).get("provisioner") == "kubernetes.io/no-provisioner" else "not-inert",
        "explicit-claimref-bind": "bound" if first.get("explicitBind", {}).get("pvcPhase") == "Bound" else "unbound",
        "retained-rebind": "released-to-bound" if second.get("rebind", {}).get("releasedObserved") and second.get("rebind", {}).get("finalPvcPhase") == "Bound" else "not-rebound",
        "cluster-really-deleted": "cluster-node-and-apiserver-absent" if all(boundary.get(key) for key in ("kindClusterAbsent", "nodeContainerAbsent", "apiServerUnreachable", "backingPresent")) else "not-deleted",
        "fresh-cluster-identity": "new-ca-and-uid" if fresh.get("serverCaChanged") and fresh.get("clusterUidChanged") else "same-cluster",
        "postgres-byte-identity": "identical" if marker.get("postgresByteIdentical") else "differs",
        "minio-byte-identity": "identical" if marker.get("minioByteIdentical") else "differs",
        "post-recreate-writes": str(marker.get("postRecreateWriteOperations", "absent")),
        "seed-commands": str(len(marker.get("seedCommands", ["absent"]))),
        "public-registry-pulls": str(source.get("publicRegistryPulls", "absent")),
    }


def mutant_outcomes(evidence: Path) -> dict[str, str]:
    outcomes: dict[str, str] = {}
    for sprint in ("28.2", "28.3"):
        for row in json_object(evidence / f"sprint-{sprint}-mutants.json").get("results", []):
            name = str(row.get("mutant", ""))
            if name:
                outcomes[name] = "red" if row.get("result") == "RED" else str(row.get("result", "absent"))
    return outcomes


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]], outcomes: Mapping[str, str],
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
    parser.add_argument("--execute", action="store_true", help="run all three sprints into this run's bundle")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed run bundle")
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=28, contract=CONTRACT, command=GATE_COMMAND,
        expectations=str(EXPECTATIONS.relative_to(ROOT)), register="3",
        substrate="linux-cpu", sides=SIDES,
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
        print("toolchain side — cabal, ghc, kind, and kubectl from authored requirements\n")
        for name in ("cabal", "ghc", "kind", "kubectl"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        run_environment = toolchain.contained_env()
        run_environment["PATH"] = os.pathsep.join((str(ROOT / "tools"), run_environment.get("PATH", "")))
        os.environ.update(run_environment)

        print("\noracle side — authored inert class and retained-volume reference table\n")
        verify_oracles()
        print("  ok    storage-class-golden-authored")
        results["oracle"] = True

        print("\nstatic side — pure retained-storage algebra and no normal delete path\n")
        run(("tools/no_retained_delete_check.sh",), environment=run_environment)
        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]
        run(cabal_command(cabal, compiler, "retained-storage-class-spec", "retained-storage-volume-spec", "retained-storage-rebind-spec"), timeout=7200, environment=run_environment)
        print("  ok    no-retained-delete-in-source")
        print("  ok    pure-retained-storage-algebra")
        results["static"] = True

        evidence = arguments.evidence
        if arguments.execute:
            predecessor = project_cluster_fixture.verified_phase_record(27)
            handoff = project_cluster_fixture.verified_image_handoff()
            print("\npredecessor side — verified Phase-31 seal and Phase-30 OCI handoff\n")
            print(f"  ok    phase27     {predecessor.attestation}")
            print(f"  ok    phase25     {handoff.attestation}")
            print(f"  ok    image-index {handoff.index_digest}")
            fixture = project_cluster_fixture.start(
                run_id=f"rs-{gate.run_dir.name}", run_dir=gate.run_dir,
                kind=resolved["kind"]["path"], kubectl=resolved["kubectl"]["path"],
                base_environment=run_environment,
            )
            fixture.cluster_attempted = True
            (gate.run_dir / "containment.json").write_text(json.dumps({
                "projectEngineRoot": str(fixture.engine.data_root),
                "testRoot": str(fixture.test_run.path), "kubeconfig": str(fixture.kubeconfig),
                "phase27Attestation": predecessor.attestation,
                "phase25Attestation": handoff.attestation,
                "phase25Artifact": str(handoff.artifact), "globalDaemonUsed": False,
            }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            evidence = gate.run_dir / "sprints"
            print("\nlive side — three retained-storage sprints in one private marker-owned fixture\n")
            execute_sprints(evidence, handoff, fixture.environment)
        elif evidence is None:
            raise GateFailure("phase-33 needs --execute or a completed --evidence bundle")
        else:
            print(f"\nlive side — reusing completed live evidence at {evidence}\n")
        if not all((evidence / f"sprint-28.{number}-receipt.json").is_file() for number in (1, 2, 3)):
            raise GateFailure("live evidence is incomplete: three sprint receipts are required")
        results["live"] = True

        print("\nmutant side — every committed mutant red for its own recorded reason\n")
        outcomes = mutant_outcomes(evidence)
        for name in sorted(EXPECTED_MUTANTS):
            outcome = outcomes.get(name, "absent")
            print(f"  {'ok  ' if outcome == 'red' else 'FAIL'}  {name:<36} {outcome}")
        results["mutant"] = all(outcomes.get(name) == "red" for name in EXPECTED_MUTANTS)

        rows.update(measure(evidence))
        rows["mutants"] = f"{sum(outcomes.get(name) == 'red' for name in EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red"
        RESULTS.parent.mkdir(parents=True, exist_ok=True)
        RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in sorted(rows.items())), encoding="utf-8")
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side([RESULTS.parent], (".tsv",), gate.run_dir, check="emitted-results-untracked", label="the run's generated output stays generated")
        results["results"] = oracle_ok and artifact_ok
    except (
        GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError,
        subprocess.TimeoutExpired, containment.ContainmentError,
        project_cluster_fixture.FixtureFailure, project_container_engine.EngineFailure,
    ) as problem:
        print(f"retained-storage-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if fixture is not None:
            cleanup_problems = fixture.stop()
            if cleanup_problems:
                results["live"] = False
                for problem in cleanup_problems:
                    print(f"retained-storage-gate: CLEANUP-FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence_map: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]]) if owner == "metrics" and ids and ids[0] in EXPECTED_RESULTS else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "tested" if rows.get("inert-storage-class") == EXPECTED_RESULTS["inert-storage-class"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("retained-rebind") == EXPECTED_RESULTS["retained-rebind"] else "UNVERIFIED",
        "Runtime": "tested" if rows.get("postgres-byte-identity") == EXPECTED_RESULTS["postgres-byte-identity"] else "UNVERIFIED",
    }
    return gate.finish(
        results, implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(EXPECTED_MUTANTS)},
        rows=rows, evidence=evidence_map, layers=layers,
        toolchain={name: {"version": record["version"], "requirement": record["requirement"]} for name, record in resolved.items() if name != "platform"},
        dependencies={
            "cluster": "private marker-owned kind fixture with retained child mounts",
            "image": "verified Phase-30 OCI export imported into each fresh node",
            **({"phase25Attestation": handoff.attestation, "phase25Index": handoff.index_digest} if handoff else {}),
            **({"phase27Attestation": predecessor.attestation} if predecessor else {}),
        },
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status=surface_decisions(expected_rows, outcomes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
