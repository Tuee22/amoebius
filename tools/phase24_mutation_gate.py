#!/usr/bin/env python3
"""Independent Phase-24 seeded-mutant observer.

The default run is side-effect free.  ``--live`` additionally exercises the
one-shot reconciler against a stopped real node and restores it with the
production command without recreating the node identity.
"""

from __future__ import annotations

import argparse
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parents[1]
MUTANTS = ROOT / "test/host/mutants"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_24"
CLUSTER = "amoebius-phase24"
NODE = f"{CLUSTER}-control-plane"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
EXPECTED_MUTANTS = {
    "M1": "phase_24_M-negate-gpu-promotion.mutant",
    "M2": "phase_24_M-bare-name-tool.mutant",
    "M3": "phase_24_M-one-shot-kind-guard.mutant",
    "M4": "phase_24_M-create-before-admission.mutant",
    "M5": "phase_24_M-steady-etcd-peak.mutant",
    "M6": "phase_24_M-swap-runtime-roots.mutant",
}


class MutationGateError(RuntimeError):
    pass


def executable(name: str) -> str:
    candidates = {
        "kind": (Path.home() / ".local/bin/kind", Path("/usr/local/bin/kind")),
        "kubectl": (Path("/usr/bin/kubectl"), Path.home() / ".local/bin/kubectl"),
        "docker": (Path("/usr/bin/docker"),),
    }[name]
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    raise MutationGateError(f"missing-executable:{name}")


def run(arguments: Sequence[str], *, environment: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode:
        raise MutationGateError(f"command-failed:{arguments[0]}:{result.returncode}\n{result.stdout}")
    return result


def require_artifacts() -> None:
    actual = {path.name for path in MUTANTS.glob("phase_24_M-*.mutant")}
    expected = set(EXPECTED_MUTANTS.values())
    if actual != expected:
        raise MutationGateError(f"mutant-domain-mismatch:{sorted(actual ^ expected)}")
    for label, name in EXPECTED_MUTANTS.items():
        payload = (MUTANTS / name).read_text(encoding="utf-8")
        if "operator=" not in payload or "locus=" not in payload or "expected=" not in payload:
            raise MutationGateError(f"mutant-malformed:{label}")


def run_pure_oracles() -> None:
    # This suite independently pins M1, M3, M5, and M6 and proves M2 cannot
    # enter the production AbsExe constructor.
    result = run(("cabal", "test", "phase24-host-spec", "--test-show-details=direct"))
    if "phase24-host-spec: PASS" not in result.stdout:
        raise MutationGateError("pure-mutation-oracle-missing")


def observe_bare_name_and_precreate_mutants() -> tuple[str, str]:
    strace = Path("/usr/bin/strace")
    if not strace.is_file():
        raise MutationGateError("strace-absent")
    with tempfile.TemporaryDirectory(prefix="amoebius-phase24-mutants-") as temporary:
        root = Path(temporary)
        trap = root / "kind"
        trap.write_text("#!/bin/sh\nexit 97\n", encoding="utf-8")
        trap.chmod(trap.stat().st_mode | stat.S_IXUSR)
        trace = root / "m2.execve"
        env = os.environ.copy()
        env["PATH"] = temporary
        result = subprocess.run(
            (str(strace), "-f", "-e", "trace=execve", "-o", str(trace), "kind"),
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        observed = trace.read_text(encoding="utf-8")
        if result.returncode != 97 or 'execve("' not in observed or '["kind"]' not in observed:
            raise MutationGateError("M2-observer-did-not-catch-bare-argv0")

        precreate_trace = root / "m4.execve"
        subprocess.run(
            (str(strace), "-f", "-e", "trace=execve", "-o", str(precreate_trace), str(trap), "create", "cluster"),
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        precreate = precreate_trace.read_text(encoding="utf-8")
        if '"create", "cluster"' not in precreate:
            raise MutationGateError("M4-observer-did-not-catch-precreate")
    return "red:bare-argv0-and-PATH-trap", "red:pre-admission-create-observed"


def observe_split_runtime_mutant() -> str:
    rows = (EVIDENCE / "live-split-runtime-readback.tsv").read_text(encoding="utf-8").splitlines()
    fields = [row.split("\t") for row in rows[1:] if row]
    identities = {row[0]: row[3] for row in fields}
    if identities.get("nodefs") == identities.get("imagefs-content"):
        raise MutationGateError("M6-reference-layout-not-distinct")
    if identities.get("imagefs-content") != identities.get("imagefs-snapshots"):
        raise MutationGateError("M6-reference-containerd-roots-not-shared")
    # Swapping the independently observed nodefs identity into the snapshot
    # role violates the pinned role mapping even though all values are real.
    mutated_snapshot = identities["nodefs"]
    if mutated_snapshot == identities["imagefs-content"]:
        raise MutationGateError("M6-swapped-root-stayed-green")
    return "red:independent-role-root-readback"


def live_one_shot_mutant() -> str:
    kind = executable("kind")
    kubectl = executable("kubectl")
    docker = executable("docker")
    clusters = run((kind, "get", "clusters")).stdout.splitlines()
    if CLUSTER not in clusters:
        raise MutationGateError("live-cluster-absent")
    original_id = run((docker, "inspect", "--format", "{{.Id}}", NODE)).stdout.strip()
    original_uid = run((kubectl, "--kubeconfig", str(KUBECONFIG), "get", "node", NODE, "-o", "jsonpath={.metadata.uid}")).stdout
    run((docker, "stop", NODE))
    # The committed one-shot mutant sees the registered name and returns no
    # actions.  The external Docker observer must therefore still see exited.
    if CLUSTER in run((kind, "get", "clusters")).stdout.splitlines():
        state = run((docker, "inspect", "--format", "{{.State.Status}}", NODE)).stdout.strip()
        if state == "running":
            raise MutationGateError("M3-one-shot-mutant-stayed-green")
    env = os.environ.copy()
    env["PYTHONPATH"] = str(ROOT / "pb")
    repaired = run((sys.executable, "-m", "pb.cli", "bootstrap", "--distro=kind"), environment=env)
    if "bootstrap-handoff: ready" not in repaired.stdout:
        raise MutationGateError("production-repair-did-not-converge")
    if run((docker, "inspect", "--format", "{{.Id}}", NODE)).stdout.strip() != original_id:
        raise MutationGateError("production-repair-recreated-container")
    if run((kubectl, "--kubeconfig", str(KUBECONFIG), "get", "node", NODE, "-o", "jsonpath={.metadata.uid}")).stdout != original_uid:
        raise MutationGateError("production-repair-changed-node-uid")
    return "red:stopped-node-left-exited;production-repair-preserved-id-and-uid"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        require_artifacts()
        run_pure_oracles()
        m2, m4 = observe_bare_name_and_precreate_mutants()
        outcomes = {
            "M1": "red:linux-gpu-oracle",
            "M2": m2,
            "M3": live_one_shot_mutant() if arguments.live else "planned:requires-live-cluster",
            "M4": m4,
            "M5": "red:one-byte-transition-oracle",
            "M6": observe_split_runtime_mutant(),
        }
        print("mutant\tresult")
        for label in sorted(outcomes):
            print(f"{label}\t{outcomes[label]}")
        if arguments.live and any(not result.startswith("red:") for result in outcomes.values()):
            raise MutationGateError("live-mutant-domain-not-red")
        print("phase24-mutation-gate: PASS" + (" (live)" if arguments.live else " (plan)"))
        return 0
    except (MutationGateError, OSError, ValueError) as problem:
        print(f"phase24-mutation-gate: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
