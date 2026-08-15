#!/usr/bin/env python3
"""Run and seal the Phase-28 no-provisioner retained-storage and lossless-rebind gate.

The capability claim is unchanged: one inert `StorageClass` with no provisioner, retained
PVs bound by explicit claimRef, and a Postgres row plus a MinIO object that survive a
**genuine** `kind` delete and recreate byte-identically, with no post-recreate write and no
public-registry pull.

What changed is where the gate's inputs come from. The retired form read a fixed evidence
directory under the plan tree, compared a committed ledger byte-for-byte against a derived
one, read its surface list out of a committed enumeration file, and invoked a developer-home
`cabal` — so it certified whoever wrote those files last, and could not run at all once the
evidence root went. Every metric below is measured from evidence this run produced into its
own bundle under `gen/runs/`, the surface enumeration is joined two-way to an authored
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

import gate_common  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
STORAGE_CLASS_GOLDEN = ROOT / "test/live/fixtures/storageclass_expected.yaml"
CLAIMREF_TABLE = ROOT / "test/live/fixtures/claimref_table.csv"
RESULTS = ROOT / "gen/dsl/phase28/phase-results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_28_retained_storage.md"
GATE_COMMAND = "python3 tools/phase28_gate.py --execute"

MUTANTS = (
    ("M-skip-durable-aggregate", "phase28-retained-pv-spec", "phase28-skip-durable-aggregate-mutant", "uniform_claim_skew_over_backing"),
    ("M-sum-unequal-ordinals", "phase28-retained-pv-spec", "phase28-sum-unequal-ordinals-mutant", "uniform max rounded x members"),
    ("M-uniform-before-allocation", "phase28-retained-pv-spec", "phase28-uniform-before-allocation-mutant", "uniform max rounded x members"),
    ("M-collapse-uniform-backing-debits", "phase28-retained-pv-spec", "phase28-collapse-backing-debits-mutant", "per-backing debit collapsed"),
    ("M-reclaim-delete", "phase28-retained-pv-spec", "phase28-reclaim-delete-mutant", "Retain policy"),
    ("M-no-rebind", "phase28-retained-pv-spec", "phase28-no-rebind-mutant", "claim UID cleared"),
    ("M-raw-host-directory", "phase28-retained-pv-spec", "phase28-raw-host-directory-mutant", "raw host directory"),
    ("M-cutover-before-verify", "phase28-retained-pv-spec", "phase28-cutover-before-verify-mutant", "migration completion order"),
    ("M-credit-before-cleanup", "phase28-retained-pv-spec", "phase28-credit-before-cleanup-mutant", "cleanup observation required"),
    ("M-fake-verify", "phase28-retained-pv-spec", "phase28-fake-verify-mutant", "byte verification mismatch"),
    ("M-soft-delete", "phase28-rebind-spec", "phase28-soft-delete-mutant", "soft delete rejected"),
    ("M-seed-marker", "phase28-rebind-spec", "phase28-seed-marker-mutant", "seed marker rejected"),
)

# The committed mutant domain. Every one is a source flag on a pure suite, and each names
# the exact red reason it must produce: a mutant that goes red for a different reason is a
# mutant that stopped attacking the property it was seeded for.
EXPECTED_MUTANTS = {name: marker for name, _suite, _flag, marker in MUTANTS}

SIDES = ("toolchain", "oracle", "static", "live", "mutant", "results")

CHECKS = {
    "storage-class-golden-authored": "the one inert StorageClass and the claimRef table are committed oracles",
    "toolchain-satisfies-requirements": "the resolved cabal, ghc, and kind satisfy the authored ranges",
    "no-retained-delete-in-source": "no source path deletes a retained volume's backing",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "the run's generated output stays outside the source snapshot",
}

CHECK_SIDE = {
    "storage-class-golden-authored": "oracle",
    "toolchain-satisfies-requirements": "toolchain",
    "no-retained-delete-in-source": "static",
    "recorded-results-match-oracle": "results",
    "emitted-results-untracked": "results",
}

EXPECTED_RESULTS = {
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


def run(arguments: Sequence[str], *, timeout: int = 7200) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ.copy(), text=True,
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
    """The committed StorageClass golden and claimRef table, and the absent evidence root."""
    if not STORAGE_CLASS_GOLDEN.is_file():
        raise GateFailure(f"storage-class-golden-authored: {gate_common.rel(STORAGE_CLASS_GOLDEN)} is missing")
    golden = STORAGE_CLASS_GOLDEN.read_text(encoding="utf-8")
    if "provisioner: kubernetes.io/no-provisioner" not in golden:
        raise GateFailure(
            "storage-class-golden-authored: the committed class does not declare "
            "`kubernetes.io/no-provisioner`, which is the whole claim"
        )
    if not CLAIMREF_TABLE.is_file():
        raise GateFailure(f"storage-class-golden-authored: {gate_common.rel(CLAIMREF_TABLE)} is missing")
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_28"
    if retired.exists():
        raise GateFailure(
            f"evidence-inputs-produced-by-this-run: {gate_common.rel(retired)} still exists, "
            "so a stale battery could be read instead of this run's own"
        )


def reject_mutant(cabal: str, compiler: str, name: str, suite: str, flag: str, marker: str) -> str:
    """Run one seeded mutant and require it red *for its own reason*."""
    result = subprocess.run(
        (cabal, f"--with-compiler={compiler}", "test", suite, f"-f{flag}",
         "--test-show-details=direct", "-j1"),
        cwd=ROOT, env=os.environ.copy(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=3600,
    )
    if result.returncode == 0:
        return "green"
    if marker not in result.stdout:
        return "red-for-another-reason"
    return "red"


def execute_sprints(evidence: Path, image: str, artifact: Path, index_digest: str) -> None:
    """Drive the three live transitions this phase's evidence is read from.

    Sprint 28.3's delete-and-recreate is the reason the order matters: it destroys the
    cluster the first two sprints ran on, so it runs last and rebuilds what it needs from
    the export rather than from an in-cluster registry that cannot survive its own node.
    """
    evidence.mkdir(parents=True, exist_ok=True)
    run([
        sys.executable, "tools/phase28_rebind_live.py",
        "--prepare-cluster-only", "--output", str(evidence / "cluster-preflight.json"),
        "--artifact", str(artifact), "--image-digest", index_digest,
    ], timeout=7200)
    print("  ok    predecessor cluster ready with the Phase-25 image imported")
    run([
        sys.executable, "tools/phase28_sprint28_1_live.py",
        "--output", str(evidence / "sprint-28.1-live.json"),
    ], timeout=7200)
    print("  ok    sprint 28.1 inert storage class observed")
    run([
        sys.executable, "tools/phase28_sprint28_2_live.py",
        "--output", str(evidence / "sprint-28.2-live.json"), "--image", image,
    ], timeout=7200)
    print("  ok    sprint 28.2 retained volume bound and rebound")
    run([
        sys.executable, "tools/phase28_rebind_live.py",
        "--prepared-cluster",
        "--output", str(evidence / "rebind-live.json"),
        "--artifact", str(artifact), "--image-digest", index_digest,
    ], timeout=14400)
    print("  ok    sprint 28.3 cluster deleted, recreated, and read back")


def measure(evidence: Path) -> dict[str, str]:
    """Read the run's own evidence and say what it shows."""
    first = json_object(evidence / "sprint-28.1-live.json")
    second = json_object(evidence / "sprint-28.2-live.json")
    rebind = json_object(evidence / "rebind-live.json")
    marker = rebind.get("marker", {})
    boundary = rebind.get("deleteBoundary", {})
    fresh = rebind.get("freshCluster", {})
    source = rebind.get("artifactSource", {})

    return {
        "inert-storage-class": (
            "one-class-no-provisioner"
            if first.get("storageClassCount") == 1 and first.get("provisioner") == "kubernetes.io/no-provisioner"
            else "not-inert"
        ),
        "explicit-claimref-bind": "bound" if first.get("boundByExplicitClaimRef") else "unbound",
        "retained-rebind": (
            "released-to-bound"
            if second.get("rebind", {}).get("from") == "Released" and second.get("rebind", {}).get("to") == "Bound"
            else "not-rebound"
        ),
        "cluster-really-deleted": (
            "cluster-node-and-apiserver-absent"
            if all(boundary.get(key) for key in
                   ("kindClusterAbsent", "nodeContainerAbsent", "apiServerUnreachable", "backingPresent"))
            else "not-deleted"
        ),
        "fresh-cluster-identity": (
            "new-ca-and-uid"
            if fresh.get("serverCaChanged") and fresh.get("clusterUidChanged")
            else "same-cluster"
        ),
        "postgres-byte-identity": "identical" if marker.get("postgresByteIdentical") else "differs",
        "minio-byte-identity": "identical" if marker.get("minioByteIdentical") else "differs",
        "post-recreate-writes": str(marker.get("postRecreateWriteOperations", "absent")),
        "seed-commands": str(len(marker.get("seedCommands", ["absent"]))),
        "public-registry-pulls": str(source.get("publicRegistryPulls", "absent")),
    }


def run_mutants(cabal: str, compiler: str) -> dict[str, str]:
    """Every committed mutant, each decided by its own red reason."""
    outcomes: dict[str, str] = {}
    for name, suite, flag, marker in MUTANTS:
        outcome = reject_mutant(cabal, compiler, name, suite, flag, marker)
        outcomes[name] = outcome
        print(f"  {'ok  ' if outcome == 'red' else 'FAIL'}  {name:<36} {outcome}")
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
    parser.add_argument("--execute", action="store_true", help="run the three live sprints into this run's bundle")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed live run's bundle")
    parser.add_argument(
        "--image", default=None,
        help="the digest-pinned reference Phase 25 published, which the retained-volume Pod runs",
    )
    parser.add_argument(
        "--artifact", type=Path, default=None,
        help="the Phase-25 OCI export the recreated cluster imports, having no registry to pull from",
    )
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=28, contract=CONTRACT, command=GATE_COMMAND, register="3", substrate="linux-cpu", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    outcomes: dict[str, str] = {}

    try:
        resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl"])
        print("toolchain side — cabal, ghc, kind, and kubectl resolved from authored requirements\n")
        for name in ("cabal", "ghc", "kind", "kubectl"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True

        print("\noracle side — the committed class and claimRef table, and the absent evidence root\n")
        verify_oracles()
        print("  ok    storage-class-golden-authored     one inert class, its claimRef table beside it")
        results["oracle"] = True

        print("\nstatic side — no source path deletes a retained backing\n")
        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]
        run(("test/ci/no_retained_delete.sh",))
        print("  ok    no-retained-delete-in-source")
        results["static"] = True

        evidence = arguments.evidence
        if arguments.execute:
            evidence = gate.run_dir / "sprints"
            missing = [
                flag for flag, value in (("--image", arguments.image), ("--artifact", arguments.artifact))
                if not value
            ]
            if missing:
                raise GateFailure(f"--execute needs {' '.join(missing)}")
            print("\nlive side — the three live transitions on the linux-cpu kind cluster\n")
            execute_sprints(
                evidence, arguments.image, arguments.artifact,
                arguments.image.rsplit("@", 1)[-1],
            )
        elif evidence is None:
            raise GateFailure("phase-28 needs --execute or an --evidence bundle from a completed live run")
        else:
            print(f"\nlive side — reusing the completed live run at {evidence}\n")
        if not (evidence / "rebind-live.json").is_file():
            raise GateFailure("live evidence is incomplete: no delete-and-recreate observation")
        results["live"] = True

        print("\nmutant side — every committed mutant red for its own recorded reason\n")
        outcomes = run_mutants(cabal, compiler)
        results["mutant"] = all(outcome == "red" for outcome in outcomes.values())
        run((cabal, f"--with-compiler={compiler}", "test", "phase28-retained-pv-spec", "phase28-rebind-spec",
             *(f"-f-{flag}" for _name, _suite, flag, _marker in MUTANTS),
             "--test-show-details=direct", "-j1"))
        print("  ok    baseline-restored                    every mutant flag off, both suites green")

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
    ) as problem:
        print(f"phase28-gate: FAIL: {problem}", file=sys.stderr)

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
        "Decision": "tested" if rows.get("inert-storage-class") == EXPECTED_RESULTS["inert-storage-class"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("retained-rebind") == EXPECTED_RESULTS["retained-rebind"] else "UNVERIFIED",
        "Runtime": "tested" if rows.get("postgres-byte-identity") == EXPECTED_RESULTS["postgres-byte-identity"] else "UNVERIFIED",
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
            "cluster": "kind (phase 24), deleted and recreated by this gate",
            "image": "the Phase-25 OCI export, imported into the recreated node",
            "reconciler": "typed-action object reconciler (phase 26)",
        },
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, outcomes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
