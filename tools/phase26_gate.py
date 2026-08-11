#!/usr/bin/env python3
"""Re-run and verify the complete Phase-26 Register-3/2.5 acceptance gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_26"
ENUMERATION = ROOT / "test/enumeration/phase_26_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_26_ledger.json"
UNVERIFIED = {"modeled-apiserver-fidelity", "completion-release-ledger", "rollback-ledger"}
BASELINE_FLAGS = (
    "-f-phase26-wait-for-ready-pure-mutant", "-f-phase26-generation-after-diff-mutant",
    "-f-phase26-label-only-delete-mutant", "-f-phase26-healthy-overbound-child-mutant",
)


class GateFailure(RuntimeError):
    pass


def run(name: str, arguments: Sequence[str], timeout: int = 1800, expect_failure: str | None = None) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if expect_failure is None and result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    if expect_failure is not None and (result.returncode == 0 or expect_failure not in result.stdout):
        raise GateFailure(f"{name}:mutant-wrong-verdict:{result.returncode}:{expect_failure}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "result": "RED" if expect_failure else "PASS", "output": result.stdout.strip()}


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.lstrip().startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 26,
        "gate_command": "python3 tools/phase26_gate.py",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{path}")
    return value


def validate_evidence() -> None:
    required = {
        *(f"sprint-26.{number}-receipt.json" for number in range(1, 6)),
        *(f"sprint-26.{number}-phase-results.tsv" for number in range(1, 6)),
        "sprint-26.3-mutants.json", "sprint-26.4-mutants.json", "sprint-26.5-mutants.json",
        "sprint-26.2-live.json", "sprint-26.3-live.json", "live-reconcile.json",
    }
    missing = sorted(name for name in required if not (EVIDENCE / name).is_file())
    if missing:
        raise GateFailure(f"evidence-missing:{missing}")
    receipts = [json_object(EVIDENCE / f"sprint-26.{number}-receipt.json") for number in range(1, 6)]
    if any(receipt.get("result") != "PASS" or receipt.get("substrate") != "linux-cpu" for receipt in receipts):
        raise GateFailure("sprint-receipt-not-pass")
    if [receipt.get("register") for receipt in receipts] != [3, 3, 3, 3, 2.5]:
        raise GateFailure("sprint-register-domain")
    for number, expected in ((3, 1), (4, 4), (5, 7)):
        mutants = json_object(EVIDENCE / f"sprint-26.{number}-mutants.json").get("results", [])
        if len(mutants) != expected or any(row.get("result") != "RED" for row in mutants):
            raise GateFailure(f"sprint-mutant-domain:26.{number}")
    live = json_object(EVIDENCE / "live-reconcile.json")
    rerun = live.get("rerun", {})
    if not rerun.get("byteStable") or rerun.get("beforeHash") != rerun.get("afterHash") or rerun.get("plannedMutations") != 0:
        raise GateFailure("live-rerun-not-noop")
    if not all(live.get("postflight", {}).values()):
        raise GateFailure("live-postflight-leak")


def verify_ledger() -> str:
    derived = derive_ledger()
    if json_object(LEDGER) != derived:
        raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
    run("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION)))
    return str(derived["ledger_hash"])


def cabal_reconcile(*extra: str) -> tuple[str, ...]:
    return ("/home/matthewnowak/.ghcup/bin/cabal", "test", "phase26-reconcile-spec", *BASELINE_FLAGS, *extra, "--test-show-details=direct", "-j1")


def cabal_mutant(suite: str, mutant: str) -> tuple[str, ...]:
    return ("/home/matthewnowak/.ghcup/bin/cabal", "test", suite, "--test-show-details=direct", "-j1", f"--test-options=--mutant={mutant}")


def execute() -> list[dict[str, str]]:
    python = sys.executable
    rows = [
        run("live-complete-reconcile", (python, "tools/phase26_reconcile_live.py", "--output", str(EVIDENCE / "live-reconcile.json"))),
        run("pure-and-live-evidence-specs", ("/home/matthewnowak/.ghcup/bin/cabal", "test", "phase26-reconcile-spec", "reconcile-converge", "serial-on-delete", "job-terminal-retention", *BASELINE_FLAGS, "--test-show-details=direct", "-j1")),
        run("deterministic-schedule-battery", ("/home/matthewnowak/.ghcup/bin/cabal", "test", "reconcile-sim", "execution-transition-sim", "--test-show-details=direct", "-j1")),
        run("wait-mutant", cabal_reconcile("-fphase26-wait-for-ready-pure-mutant"), expect_failure="never-ready red path"),
        run("generation-mutant", cabal_reconcile("-fphase26-generation-after-diff-mutant"), expect_failure="stable no-op"),
        run("child-envelope-mutant", cabal_reconcile("-fphase26-healthy-overbound-child-mutant"), expect_failure="healthy CR over-bound child"),
        run("delete-mutant", cabal_reconcile("-fphase26-label-only-delete-mutant"), expect_failure="changed resourceVersion"),
    ]
    sim_mutants = (
        ("reconcile-sim", "lost-lease-resourceversion-retry", "NoStaleTokenReuse"),
        ("reconcile-sim", "mutation-without-holder", "NoWriteWithoutExactLeaseHolder"),
        ("reconcile-sim", "sleep-gated-readiness", "ReadinessRequiresObservation"),
        ("execution-transition-sim", "serial-stage-collapse", "SerialReplacementBoundReadyBeforeAdvance"),
        ("execution-transition-sim", "completion-cleanup-before-persist", "CompletionDurableBeforeCleanup"),
        ("reconcile-sim", "label-only-delete", "DeleteRequiresExactAuthority"),
        ("reconcile-sim", "cached-observation", "FreshSnapshotBeforeMutation"),
    )
    rows.extend(run(f"sim-mutant-{mutant}", cabal_mutant(suite, mutant), expect_failure=marker) for suite, mutant, marker in sim_mutants)
    rows.extend([
        run("baseline-restored", ("/home/matthewnowak/.ghcup/bin/cabal", "test", "phase26-reconcile-spec", "reconcile-sim", "execution-transition-sim", *BASELINE_FLAGS, "--test-show-details=direct", "-j1")),
        run("documentation-lint", (python, "tools/doc_lint.py")),
    ])
    return rows


def write_results(rows: list[dict[str, str]], ledger_hash: str) -> None:
    (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
    lines: list[str] = []
    for row in rows:
        lines.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], f"RESULT {row['result']}"))
    lines.append(f"PHASE-26-GATE PASS {ledger_hash}")
    (EVIDENCE / "phase-gate.log").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        rows = execute()
        validate_evidence()
        ledger_hash = verify_ledger()
        write_results(rows, ledger_hash)
        print(f"phase26-gate: PASS ({len(rows)} checks; {ledger_hash})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
