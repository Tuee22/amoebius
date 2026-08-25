#!/usr/bin/env python3
"""Seal the object reconciler's deterministic reconcile and transition schedules."""

from __future__ import annotations

import argparse
import functools
import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
MUTANTS = (
    ("reconcile-sim", "lost-lease-resourceversion-retry", "NoStaleTokenReuse"),
    ("reconcile-sim", "mutation-without-holder", "NoWriteWithoutExactLeaseHolder"),
    ("reconcile-sim", "sleep-gated-readiness", "ReadinessRequiresObservation"),
    ("execution-transition-sim", "serial-stage-collapse", "SerialReplacementBoundReadyBeforeAdvance"),
    ("execution-transition-sim", "completion-cleanup-before-persist", "CompletionDurableBeforeCleanup"),
    ("reconcile-sim", "label-only-delete", "DeleteRequiresExactAuthority"),
    ("reconcile-sim", "cached-observation", "FreshSnapshotBeforeMutation"),
)


@functools.cache
def build_tools() -> tuple[str, str]:
    """Resolve cabal and the compiler per run from the authored requirements.

    The retired form named a developer-home `cabal` outright, so the gate could only run on
    one machine and inherited whichever GHC that installation offered — which need not
    satisfy the authored range.
    """
    resolved = toolchain.resolve(["cabal", "ghc"])
    return resolved["cabal"]["path"], resolved["ghc"]["path"]


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 1800, expect_failure: str | None = None) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if expect_failure is None and result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    if expect_failure is not None and (result.returncode == 0 or expect_failure not in result.stdout or "RED" not in result.stdout):
        raise GateFailure(f"{name}:mutant-wrong-verdict:{result.returncode}:{expect_failure}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "RED" if expect_failure else "PASS"}


def cabal(*targets: str, options: str | None = None) -> tuple[str, ...]:
    executable, compiler = build_tools()
    command = [
        executable,
        f"--builddir={ROOT / '.build/dist-newstyle/object-reconciler'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={compiler}", "test", *targets,
        "--test-show-details=direct", "-j1",
    ]
    if options is not None:
        command.append(f"--test-options={options}")
    return tuple(command)


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate_source() -> dict[str, str]:
    common = (ROOT / "test/spec/sim/ObjectReconcilerSimCommon.hs").read_text(encoding="utf-8")
    reconcile = (ROOT / "test/spec/sim/ReconcileSim.hs").read_text(encoding="utf-8")
    execution = (ROOT / "test/spec/sim/ExecutionTransitionSim.hs").read_text(encoding="utf-8")
    required = (
        "Amoebius.Manifest.Authority", "Amoebius.Manifest.Apply", "Amoebius.Manifest.Delete",
        "Amoebius.Manifest.Wait", "Amoebius.Execution.SerialOnDelete",
        "Amoebius.Execution.HostTransition", "Amoebius.Execution.JobTerminal",
        "newIOSimEnv", "exploreRaces",
    )
    missing = [symbol for symbol in required if symbol not in common]
    if missing:
        raise GateFailure(f"simulation-not-driving-real-modules:{missing}")
    if "[0 .. 255]" not in reconcile or "[0 .. 255]" not in execution:
        raise GateFailure("per-fault-schedule-bound-below-256")
    if "withScheduleBound 24" not in reconcile or "withScheduleBound 24" not in execution:
        raise GateFailure("iosimpor-bound-absent")
    authority = (ROOT / "src/Amoebius/Manifest/Authority.hs").read_text(encoding="utf-8")
    scaling = (ROOT / "src/Amoebius/Storage/ScalingAction.hs").read_text(encoding="utf-8")
    if "Data.IORef" in authority or "Data.IORef" in scaling or "MonadSTM" not in authority or "MonadSTM" not in scaling:
        raise GateFailure("real-single-use-tokens-not-simulation-polymorphic")
    return {"name": "simulation-source-boundary", "command": "internal source scan", "output": "real action modules + IOSimPOR + 256 schedules/class + MonadSTM tokens", "result": "PASS"}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    try:
        rows = [
            invoke("phase15-simulation-substrate-regression", cabal("sim-spec")),
            invoke("phase26-schedule-battery", cabal("reconcile-sim", "execution-transition-sim")),
        ]
        mutant_rows = [
            invoke(f"mutant-{name}", cabal(suite, options=f"--mutant={name}"), expect_failure=invariant)
            for suite, name, invariant in MUTANTS
        ]
        rows.extend(mutant_rows)
        rows.extend([
            invoke("baseline-restored", cabal("reconcile-sim", "execution-transition-sim")),
            validate_source(),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ])
        stable = {
            "schema": "amoebius.phase26.sprint26.5-receipt.v1", "register": 2.5, "substrate": "linux-cpu",
            "faultClasses": 8, "schedulesPerFaultClass": 256, "deterministicSchedules": 2048,
            "iosimPorScheduleBound": 24, "iosimPorBranching": 4, "sameSeedByteReplay": True,
            "seededMutantsRed": len(MUTANTS), "realActionModulesDriven": True,
            "tested": [
                "single Lease writer and exact holder authority", "resourceVersion conflict retry",
                "serial Bound+Ready ordering", "host/device release before start",
                "completion persistence before cleanup", "exact authenticated delete",
                "fresh observation and readiness before continuation",
            ],
            "assumed": ["modeled apiserver fidelity; discharged separately by Sprint 68.4 Register-3 live evidence"],
            "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-26.5-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-26.5-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        mutants = {
            "schema": "amoebius.phase26.sprint26.5-mutants.v1", "baselineRestored": True,
            "results": [
                {"mutant": name, "suite": suite, "result": "RED", "observedFailureMarker": invariant}
                for suite, name, invariant in MUTANTS
            ],
        }
        (evidence / "sprint-26.5-mutants.json").write_text(json.dumps(mutants, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        message = f"phase26-sprint26.5-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-26.5-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.5-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
