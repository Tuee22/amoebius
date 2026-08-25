#!/usr/bin/env python3
"""Seal the object reconciler's live convergence, no-op, readiness, and red controls."""

from __future__ import annotations

import argparse
import functools
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
BASELINE_FLAGS = (
    "-f-object-reconciler-wait-for-ready-pure-mutant", "-f-object-reconciler-generation-after-diff-mutant",
    "-f-object-reconciler-label-only-delete-mutant", "-f-object-reconciler-healthy-overbound-child-mutant",
)
FORBIDDEN_SOURCES = (
    *sorted((ROOT / "src/Amoebius/Manifest").glob("*.hs")),
    *sorted((ROOT / "src/Amoebius/Execution").glob("*.hs")),
)
FORBIDDEN = re.compile(r"\b(threadDelay|registerDelay|getMonotonicTime|unsafePerformIO|usleep)\b")


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
    if expect_failure is not None and (result.returncode == 0 or expect_failure not in result.stdout):
        raise GateFailure(f"{name}:mutant-wrong-verdict:{result.returncode}:{expect_failure}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "RED" if expect_failure else "PASS"}


def cabal_reconcile(*extra: str) -> tuple[str, ...]:
    executable, compiler = build_tools()
    return (
        executable,
        f"--builddir={ROOT / '.build/dist-newstyle/object-reconciler'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={compiler}", "test", "object-reconciler-spec",
        *BASELINE_FLAGS, *extra, "--test-show-details=direct", "-j1",
    )


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate_forbidden_symbols() -> dict[str, str]:
    findings: list[str] = []
    for path in FORBIDDEN_SOURCES:
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if FORBIDDEN.search(line):
                findings.append(f"{path.relative_to(ROOT)}:{line_number}:{line.strip()}")
    if findings:
        raise GateFailure("forbidden-readiness-symbols:" + "|".join(findings))
    return {"name": "forbidden-readiness-symbol-lint", "command": "internal source scan", "output": f"{len(FORBIDDEN_SOURCES)} modules clean", "result": "PASS"}


def validate_live(live: Path) -> dict[str, Any]:
    observed = json.loads(live.read_text(encoding="utf-8"))
    rerun = observed["rerun"]
    if not rerun["byteStable"] or rerun["beforeHash"] != rerun["afterHash"] or rerun["plannedMutations"] != 0:
        raise GateFailure("rerun-not-byte-stable-no-op")
    private = observed["privatePullDeployment"]
    if private["initialAvailableReplicas"] != 0 or private["readyElapsedSeconds"] < private["initialDelaySeconds"] or not private["available"]:
        raise GateFailure("readiness-not-live-noninstantaneous")
    transitions = observed["serial"]["transitions"]
    if [row["name"] for row in transitions] != ["serial-1", "serial-0"]:
        raise GateFailure("serial-order")
    if any(row["oldUid"] == row["newUid"] or row["absenceObserved"] != "true" or row["boundReadyObserved"] != "true" for row in transitions):
        raise GateFailure("serial-postcondition")
    job = observed["job"]
    if not job["retained"] or job["completionObjects"] != 0 or not job["terminalPodUid"]:
        raise GateFailure("job-terminal-retention")
    custom = observed["customResource"]
    if not custom["healthy"] or not custom["child"]["conforms"]:
        raise GateFailure("custom-resource-child-conformance")
    race = observed["quotaRace"]
    if race != {"simultaneousReservations": 2, "admittedChildren": 1, "hardPods": 1, "usedPods": 1, "overAllocation": 0}:
        raise GateFailure(f"controller-envelope-quota-race:{race}")
    negative = observed["negativeControls"]
    if negative["neverReadyExit"] == 0 or negative["neverReadyResult"] != "RED" or negative["overboundResult"] != "RED":
        raise GateFailure("live-negative-control")
    if not all(observed["postflight"].values()):
        raise GateFailure(f"postflight-leak:{observed['postflight']}")
    return {
        "liveObjectCount": rerun["objectCount"], "rerunByteStable": True,
        "rerunFingerprint": rerun["beforeHash"], "serialTransitions": len(transitions),
        "terminalRetained": True, "completionObjects": 0, "customResourceChildConforms": True,
        "simultaneousReservations": 2, "admittedChildren": 1, "quotaOverAllocation": 0,
        "postflightClean": True,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    # The corpus Deployment pulls the Phase-31 published digest from the in-cluster
    # registry, which is what makes item (i) of the corpus exercise that dependency.
    parser.add_argument("--image", required=True, help="the Phase-31 published digest reference")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    live = evidence / "live-reconcile.json"
    try:
        rows = [
            invoke("live-complete-reconcile", (sys.executable, "tools/object_reconciler_live.py", "--output", str(live), "--image", arguments.image), timeout=7200),
            invoke("live-evidence-specs", (
                                   build_tools()[0],
                                   f"--builddir={ROOT / '.build/dist-newstyle/object-reconciler'}",
                                   f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
                                   f"--with-compiler={build_tools()[1]}", "test",
                                   "reconcile-converge", "serial-on-delete", "job-terminal-retention",
                                   *BASELINE_FLAGS, f"--test-options={live}",
                                   "--test-show-details=direct", "-j1")),
            invoke("haskell-readiness-and-envelope-spec", cabal_reconcile()),
            invoke("wait-for-ready-pure-mutant", cabal_reconcile("-fobject-reconciler-wait-for-ready-pure-mutant"), expect_failure="never-ready red path"),
            invoke("generation-after-diff-mutant", cabal_reconcile("-fobject-reconciler-generation-after-diff-mutant"), expect_failure="stable no-op"),
            invoke("healthy-overbound-child-mutant", cabal_reconcile("-fobject-reconciler-healthy-overbound-child-mutant"), expect_failure="healthy CR over-bound child"),
            invoke("label-only-delete-mutant", cabal_reconcile("-fobject-reconciler-label-only-delete-mutant"), expect_failure="changed resourceVersion"),
            invoke("baseline-restored", cabal_reconcile()),
            validate_forbidden_symbols(),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        stable = {
            "schema": "amoebius.phase26.sprint26.4-receipt.v1", "register": 3, "substrate": "linux-cpu",
            **validate_live(live), "seededMutantsRed": 4, "forbiddenReadinessSymbols": 0,
            "deferred": ["content-addressed completion gateway", "rollback and release ledger"], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-26.4-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-26.4-phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        mutants = {
            "schema": "amoebius.phase26.sprint26.4-mutants.v1", "baselineRestored": True,
            "results": [
                {"mutant": "wait-for-ready-pure", "result": "RED", "observedFailureMarker": "never-ready red path"},
                {"mutant": "generation-stamped-after-diff", "result": "RED", "observedFailureMarker": "stable no-op"},
                {"mutant": "healthy-cr-over-bound-child", "result": "RED", "observedFailureMarker": "healthy CR over-bound child"},
                {"mutant": "delete-from-owner-label-alone", "result": "RED", "observedFailureMarker": "changed resourceVersion"},
            ],
        }
        (evidence / "sprint-26.4-mutants.json").write_text(json.dumps(mutants, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        message = f"phase26-sprint26.4-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-26.4-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.4-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
