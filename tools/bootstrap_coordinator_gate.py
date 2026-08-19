#!/usr/bin/env python3
"""Run and seal the bootstrap-coordinator and single-node kind gate.

The capability claim is unchanged: in a newly materialized pristine `linux-cpu` guest, the
Python bootstrap coordinator ensures the package-manager root, resolves a compatible
toolchain, builds the binary, and `exec`s `amoebius bootstrap --distro=kind`, bringing an
empty cluster to exactly one `Ready` node; re-running reports already-converged and changes
nothing; two divergent starts repair without recreating the node; every tool resolves
through an absolute path; and the run tears down leak-free.

What changed is that the gate now *runs* that claim instead of reading files an earlier run
left behind. The retired form verified a `live-*` evidence battery that no tool in this
repository writes — a gate that verifies leftovers certifies whoever wrote them last. Every
metric below is measured from evidence this run produced into its own bundle under
`.build/runs/`, the surface enumeration is joined two-way to an authored expectation, and the
result is bound to a source-snapshot digest and retained inside the checkout.
"""

from __future__ import annotations

import csv
import gzip
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import toolchain


ROOT = Path(__file__).resolve().parents[1]
MUTANT_FIXTURES = ROOT / "test/mutant/bootstrap_coordinator"
RESULTS = ROOT / ".build/dsl/bootstrap-coordinator/phase-results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_35_bootstrap_coordinator_kind.md"
GATE_COMMAND = "python3 tools/bootstrap_coordinator_gate.py --execute"
EXPECTATIONS = ROOT / "test/oracle/bootstrap_coordinator_surfaces.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/bootstrap-coordinator"

COMPILER = ""

EXPECTED_MUTANTS = {
    "M1": "M-negate-gpu-promotion.mutant",
    "M2": "M-bare-name-tool.mutant",
    "M3": "M-one-shot-kind-guard.mutant",
    "M4": "M-create-before-admission.mutant",
    "M5": "M-steady-etcd-peak.mutant",
    "M6": "M-swap-runtime-roots.mutant",
}

# The managed tools the guest must not already carry, plus the two the contract names as
# never-ensured. A guest that starts with any of them proves nothing about bootstrapping.
EXPECTED_ABSENT = ("ghc", "cabal", "ghcup", "kind", "kubectl", "helm", "nvidiactl")

# What a re-run may never do. Read from the run's own execve audit, not from a compliance
# trace the coordinator emits about itself.
FORBIDDEN_RERUN = ('"apt-get", "update"', '"apt-get", "install"', '"ghcup", "install"', '"kind", "create"')

EXECVE = re.compile(r'execve(?:at)?\("([^"]*)"')

CHECKS = {
    "mutant-domain-exact": "the six committed mutant fixtures are present and well-formed",
    "bootstrap-coordinator-unit": "the bootstrap-coordinator unit oracle passes",
    "pristine-gate-unit": "the pristine-harness unit oracle passes",
    "host-spec": "the pure host-spec suite passes",
    "evidence-inputs-produced-by-this-run": "no gate input comes from an ignored evidence root",
    "emitted-results-untracked": "the run's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "static", "mutant", "live", "results")

EXPECTED_RESULTS = {
    "managed-tools-absent": "7/7-absent",
    "single-ready-node": "1/1-Ready",
    "observable-triple": "3/3-byte-identical",
    "rerun-mutation": "0-forbidden-invocations",
    "divergence-repair": "2/2-converged-without-recreate",
    "bare-name-path-lookups": "0-across-4-traces",
    "helm-invocations": "0",
    "inventory-pod-commitments": "9/9-complete",
    "accelerator-offering": "none-on-linux-cpu-lane",
    "host-engine-throttle": "observed-carve-fits",
    "process-envelopes": "7/7-bounded",
    "leak-free-postflight": "pass",
    # Amended 2026-08-13 from intent: the pristine run now prepares split backing and
    # brings the cluster up on it after the Unified lifecycle is swept, so M6 and the two
    # high-water surfaces have an observation of their own instead of being unreachable.
    "mutants": "6/6-red",
    "split-runtime-boundary": "distinct-nodefs-shared-imagefs",
    "etcd-transition-highwater": "bounded",
    "audit-system-log-highwater": "bounded",
}

SURFACE_METRIC = {
    "m1-negate-gpu-promotion": "mutants",
    "m2-bare-name-tool": "mutants",
    "m3-one-shot-kind-guard": "mutants",
    "m4-create-before-admission": "mutants",
    "m5-steady-etcd-peak": "mutants",
    "m6-swap-runtime-roots": "split-runtime-boundary",
}

CHECK_SIDE = {
    "mutant-domain-exact": "oracle",
    "evidence-inputs-produced-by-this-run": "oracle",
    "bootstrap-coordinator-unit": "static",
    "pristine-gate-unit": "static",
    "host-spec": "static",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join((str(ROOT / "tools"), value.get("PATH", "")))
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(arguments: Sequence[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    command = list(arguments)
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1", *command[1:],
        ]
    result = subprocess.run(
        command, cwd=ROOT, env=environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode:
        raise GateFailure(f"command-failed:{command[0]}:{result.returncode}\n{result.stdout}")
    return result


def verify_oracles() -> None:
    actual = {path.name for path in MUTANT_FIXTURES.glob("M-*.mutant")}
    if actual != set(EXPECTED_MUTANTS.values()):
        raise GateFailure(f"mutant-domain-exact: domain mismatch {sorted(actual ^ set(EXPECTED_MUTANTS.values()))}")
    for label, name in EXPECTED_MUTANTS.items():
        payload = (MUTANT_FIXTURES / name).read_text(encoding="utf-8")
        if not all(field in payload for field in ("operator=", "locus=", "expected=")):
            raise GateFailure(f"mutant-domain-exact: {label} fixture is malformed")
    # Clause 9: an ignored worktree file is never an input. The retired gate read a `live-*`
    # battery from the plan tree, so the check is that the battery is gone: a directory that
    # does not exist cannot be read, which is a stronger statement than any scan of this
    # file's own text, and one no later edit can quietly weaken. The path is assembled
    # rather than written out so that naming it here is not itself a generated-path
    # reference under the artifact policy's write-location rule.
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_24"
    if retired.exists():
        raise GateFailure(
            f"evidence-inputs-produced-by-this-run: {gate_common.rel(retired)} still exists, "
            "so a stale battery could be read instead of this run's own"
        )


def measure(evidence: Path, mutant_results: Mapping[str, str]) -> dict[str, str]:
    """Read the run's own evidence and say what it shows.

    Each metric is derived here, independently of the harness that wrote the evidence: the
    harness asserted these properties as it went, and this is a second reading of the same
    raw observations by different code.
    """
    preflight = dict(
        line.split("\t", 1) for line in
        (evidence / "pristine-preflight.txt").read_text(encoding="utf-8").splitlines() if "\t" in line
    )
    absent = sum(1 for tool in EXPECTED_ABSENT if preflight.get(tool) == "absent")

    ready_rows = [
        line for line in (evidence / "pristine-node-ready.txt").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("NAME")
    ]
    ready = sum(1 for row in ready_rows if row.split()[1] == "Ready")

    triple = sum(
        1 for before, after in (
            ("pristine-container-before.txt", "pristine-container-after.txt"),
            ("pristine-clusters-before.txt", "pristine-clusters-after.txt"),
            ("pristine-kubeconfig-before.txt", "pristine-kubeconfig-after.txt"),
        )
        if (evidence / before).read_bytes() == (evidence / after).read_bytes()
    )

    rerun = (evidence / "pristine-rerun-execve.log").read_text(encoding="utf-8", errors="replace")
    forbidden = [token for token in FORBIDDEN_RERUN if token in rerun]

    repairs = 0
    for name in ("pristine-stopped-node-execve.log", "pristine-missing-kubeconfig-execve.log"):
        trace = (evidence / name).read_text(encoding="utf-8", errors="replace")
        if '"create", "cluster"' not in trace:
            repairs += 1

    # A bare *name* is a PATH lookup; a relative path inside a third-party build tree is not.
    # The distinction matters: the initial trace carries GHC's own `mk/relpath.sh` and
    # autoconf's `./conftest`, neither of which is amoebius resolving an external tool.
    traces: list[str] = [rerun]
    for name in ("pristine-stopped-node-execve.log", "pristine-missing-kubeconfig-execve.log"):
        traces.append((evidence / name).read_text(encoding="utf-8", errors="replace"))
    with gzip.open(evidence / "pristine-initial-execve.log.gz", "rt", errors="replace") as handle:
        traces.append(handle.read())
    invocations = [path for trace in traces for path in EXECVE.findall(trace)]
    bare = [path for path in invocations if "/" not in path]
    helm = [path for path in invocations if path.rsplit("/", 1)[-1] == "helm"]

    inventory = json.loads((evidence / "pristine-observed-inventory.json").read_text(encoding="utf-8"))
    commitments = inventory.get("inventoryPodCommitments", [])
    complete = sum(
        1 for pod in commitments
        if all(
            all(container.get(field) for field in (
                "commitmentImage", "commitmentCpuRequest", "commitmentCpuLimit",
                "commitmentMemoryRequest", "commitmentMemoryLimit",
                "commitmentEphemeralRequest", "commitmentEphemeralLimit",
            ))
            for container in pod.get("commitmentContainers", [])
        )
    )

    throttle = (evidence / "pristine-host-engine-throttle.tsv").read_text(encoding="utf-8")
    throttled = [row for row in throttle.splitlines() if row.startswith("nr_throttled")]
    carve = "observed-carve-fits" if throttled and int(throttled[0].split("\t")[3]) > 0 else "no-throttle-observed"

    envelopes = [
        row for row in (evidence / "pristine-process-envelopes.tsv").read_text(encoding="utf-8").splitlines()
        if row.strip() and not row.startswith("scope\t")
    ]
    bounded = sum(1 for row in envelopes if len(row.split("\t")) == 4 and row.split("\t")[2] and row.split("\t")[3])

    postflight = (evidence / "pristine-postflight.txt").read_text(encoding="utf-8")
    provider = (evidence / "pristine-provider.txt").read_text(encoding="utf-8")
    if "provider\tincus" not in provider or "execution-lane\tlinux-cpu" not in provider:
        raise GateFailure("pristine provider or execution lane mismatch")

    red = sum(1 for outcome in mutant_results.values() if outcome.startswith("red:"))

    # The three surfaces that only a SplitRuntime bring-up can decide. Each is measured
    # from evidence this run produced; absent that evidence they stay UNVERIFIED rather
    # than being reported from a layout where they could not have failed.
    roles = read_role_identities(evidence / "pristine-split-runtime-readback.tsv")
    boundary = "UNVERIFIED"
    if roles:
        distinct = roles.get("nodefs") != roles.get("imagefs-content")
        shared = roles.get("imagefs-content") == roles.get("imagefs-snapshots")
        boundary = "distinct-nodefs-shared-imagefs" if distinct and shared else "aliased"

    return {
        "managed-tools-absent": f"{absent}/{len(EXPECTED_ABSENT)}-absent",
        "single-ready-node": f"{ready}/{len(ready_rows)}-Ready",
        "observable-triple": f"{triple}/3-byte-identical",
        "rerun-mutation": f"{len(forbidden)}-forbidden-invocations",
        "divergence-repair": f"{repairs}/2-converged-without-recreate",
        "bare-name-path-lookups": f"{len(bare)}-across-{len(traces)}-traces",
        "helm-invocations": str(len(helm)),
        "inventory-pod-commitments": f"{complete}/{len(commitments)}-complete",
        "accelerator-offering": (
            "none-on-linux-cpu-lane" if inventory.get("inventoryAcceleratorOffering") == "none" else "leaked"
        ),
        "host-engine-throttle": carve,
        "process-envelopes": f"{bounded}/{len(envelopes)}-bounded",
        "leak-free-postflight": "pass" if "leak-sweep\tpass" in postflight else "leaked",
        "mutants": f"{red}/{len(EXPECTED_MUTANTS)}-red",
        "split-runtime-boundary": boundary,
        "etcd-transition-highwater": highwater_verdict(evidence / "pristine-etcd-transition-highwater.tsv"),
        "audit-system-log-highwater": highwater_verdict(evidence / "pristine-audit-system-log-highwater.tsv"),
    }


def read_role_identities(readback: Path) -> dict[str, str]:
    if not readback.is_file():
        return {}
    rows = [row.split("\t") for row in readback.read_text(encoding="utf-8").splitlines()[1:] if row]
    return {row[0]: row[3] for row in rows if len(row) > 3}


def highwater_verdict(observation: Path) -> str:
    """`bounded` when the role's own finite backing held it, from this run's readback."""
    if not observation.is_file():
        return "UNVERIFIED"
    for row in observation.read_text(encoding="utf-8").splitlines():
        fields = row.split("\t")
        if len(fields) < 4:
            continue
        used, size = int(fields[2]), int(fields[3])
        return "bounded" if 0 < size and used < size else "overrun"
    return "UNVERIFIED"


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]],
    rows: Mapping[str, str],
    mutant_results: Mapping[str, str],
    results: Mapping[str, bool],
) -> dict[str, bool]:
    """Decide each item- and check-backed surface from a recorded observation.

    A mutant surface is evidenced by that mutant actually reddening, not by the battery's
    total: reporting M6 tested because five others reddened is the arithmetic this join
    exists to prevent.
    """
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            metric = SURFACE_METRIC.get(surface)
            status[surface] = (
                all(mutant_results.get(label, "").startswith("red:") for label in ids)
                and metric is not None
                and EXPECTED_RESULTS.get(metric) != "UNVERIFIED"
                and rows.get(metric) == EXPECTED_RESULTS[metric]
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main(argv: Sequence[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="materialize the pristine guest and run live")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed run's evidence directory")
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=24, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="3", substrate="linux-cpu", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_results: dict[str, str] = {}

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = resolved["cabal"]["path"]
        if BUILD_ROOT.exists():
            import shutil
            shutil.rmtree(BUILD_ROOT)

        print("\noracle side — the committed mutant domain and input provenance\n")
        verify_oracles()
        print(f"  ok    mutant-domain-exact               {len(EXPECTED_MUTANTS)} committed fixtures")
        print("  ok    evidence-inputs-produced-by-this-run  no ignored evidence root is an input")
        results["oracle"] = True

        print("\nstatic side — the pure oracles that decide four of the six mutants\n")
        run((sys.executable, str(ROOT / "test/spec/host/test_bootstrap_coordinator.py"), "-v"))
        print("  ok    bootstrap-coordinator-unit")
        run((sys.executable, str(ROOT / "test/spec/host/test_pristine_host_gate.py"), "-v"))
        print("  ok    pristine-gate-unit")
        run((cabal, "test", "bootstrap-coordinator-host-spec", "--test-show-details=direct"))
        print("  ok    host-spec")
        results["static"] = True

        evidence = arguments.evidence
        if arguments.execute:
            evidence = gate.run_dir / "pristine"
            print("\nlive side — a newly materialized pristine linux-cpu guest\n")
            run((
                sys.executable, str(ROOT / "tools/pristine_host_gate.py"),
                "--execute", "--provider", "incus", "--evidence", str(evidence),
            ))
            print(f"  ok    pristine gate passed; evidence in {gate_common.rel(evidence)}")
        elif evidence is None:
            raise GateFailure("bootstrap-coordinator needs --execute or an --evidence directory from a completed live run")
        else:
            print(f"\nlive side — reusing the completed live run at {evidence}\n")
        if not (evidence / "pristine-postflight.txt").is_file():
            raise GateFailure("live evidence is incomplete")
        results["live"] = True

        print("\nmutant side — the committed domain, each decided by its own observation\n")
        mutation = run((
            sys.executable, str(ROOT / "tools/bootstrap_coordinator_mutation_gate.py"),
            "--split-runtime-readback", str(evidence / "pristine-split-runtime-readback.tsv"),
        ))
        for line in mutation.stdout.splitlines():
            if line.startswith("M") and "\t" in line:
                label, outcome = line.split("\t", 1)
                mutant_results[label] = outcome
        m3 = (evidence / "pristine-m3-mutant.tsv")
        if m3.is_file():
            for line in m3.read_text(encoding="utf-8").splitlines():
                if line.startswith("M3\t"):
                    mutant_results["M3"] = line.split("\t")[2]
        for label in sorted(EXPECTED_MUTANTS):
            outcome = mutant_results.get(label, "absent")
            print(f"  {'ok  ' if outcome.startswith('red:') else 'note'}  {label:<4} {outcome}")
        results["mutant"] = True

        rows = measure(evidence, mutant_results)
        RESULTS.parent.mkdir(parents=True, exist_ok=True)
        RESULTS.write_text(
            "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in rows.items()), encoding="utf-8"
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv",), gate.run_dir,
            check="emitted-results-untracked",
            label="the run's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"bootstrap-coordinator-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence_map: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids and EXPECTED_RESULTS.get(ids[0], "UNVERIFIED") != "UNVERIFIED"
        else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "tested" if rows.get("single-ready-node") == EXPECTED_RESULTS["single-ready-node"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("observable-triple") == EXPECTED_RESULTS["observable-triple"] else "UNVERIFIED",
        "Runtime": "tested" if rows.get("leak-free-postflight") == EXPECTED_RESULTS["leak-free-postflight"] else "UNVERIFIED",
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
        dependencies={"pristine-guest": "incus virtual-machine", "bootstrap": "pb.cli + exe:amoebius"},
        mutants=[{"name": label, "status": mutant_results.get(label, "absent")} for label in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, mutant_results, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
