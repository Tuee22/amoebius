#!/usr/bin/env python3
"""Seal Sprint 33.3's real cluster delete/recreate retained-byte proof."""

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
    ("M-soft-delete", "retained-storage-soft-delete-mutant", "soft delete rejected"),
    ("M-seed-marker", "retained-storage-seed-marker-mutant", "seed marker rejected"),
)
BASELINE_FLAGS = tuple(f"-f-{flag}" for _name, flag, _marker in MUTANTS)


class GateFailure(RuntimeError):
    pass


@functools.cache
def build_tools() -> tuple[str, str]:
    resolved = toolchain.resolve(["cabal", "ghc"])
    return resolved["cabal"]["path"], resolved["ghc"]["path"]


def invoke(
    name: str, arguments: Sequence[str], *, timeout: int = 1800,
    expect_failure: str | None = None,
) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ.copy(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if expect_failure is None and result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout[-6000:]}")
    if expect_failure is not None and (result.returncode == 0 or expect_failure not in result.stdout):
        raise GateFailure(f"{name}:mutant-wrong-verdict:{result.returncode}:{expect_failure}:{result.stdout[-6000:]}")
    return {
        "name": name, "command": shlex.join(arguments), "output": result.stdout.strip(),
        "result": "RED" if expect_failure else "PASS",
    }


def cabal(suite: str, *extra: str) -> tuple[str, ...]:
    return (
        build_tools()[0], f"--builddir={ROOT / '.build/dist-newstyle/retained-storage'}",
        f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
        f"--with-compiler={build_tools()[1]}", "test", suite, *BASELINE_FLAGS, *extra,
        "--test-show-details=direct", "-j1",
    )


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    parser.add_argument("--artifact", type=Path, required=True, help="the verified Phase-31 OCI export")
    parser.add_argument("--image-digest", required=True, help="the verified Phase-31 image-index digest")
    parser.add_argument("--prepared-cluster", action="store_true", help="consume the clean cluster prepared by the phase gate")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    evidence.mkdir(parents=True, exist_ok=True)
    live_path = evidence / "rebind-live.json"
    try:
        live_command = [
            sys.executable, "tools/retained_storage_rebind_live.py", "--output", str(live_path),
            "--artifact", str(arguments.artifact), "--image-digest", arguments.image_digest,
        ]
        if arguments.prepared_cluster:
            live_command.append("--prepared-cluster")
        rows = [
            invoke("live-delete-recreate", live_command, timeout=14400),
            invoke("pure-rebind", cabal("retained-storage-rebind-spec")),
            invoke("external-live-evidence-reader", cabal("retained-storage-rebind-live", f"--test-options={live_path}")),
        ]
        for name, flag, marker in MUTANTS:
            rows.append(invoke(name, cabal("retained-storage-rebind-spec", f"-f{flag}"), expect_failure=marker))
        rows.extend((
            invoke("baseline-restored", cabal("retained-storage-rebind-spec")),
            invoke("no-retained-delete", ("tools/no_retained_delete_check.sh",)),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ))
        live = json.loads(live_path.read_text(encoding="utf-8"))
        marker = live.get("marker", {})
        boundary = live.get("deleteBoundary", {})
        fresh = live.get("freshCluster", {})
        if not all(marker.get(key) for key in ("postgresByteIdentical", "minioByteIdentical")):
            raise GateFailure("marker-readback-domain")
        if not all(boundary.get(key) for key in ("kindClusterAbsent", "nodeContainerAbsent", "apiServerUnreachable", "backingPresent")):
            raise GateFailure("delete-boundary-domain")
        if not fresh.get("serverCaChanged") or not fresh.get("clusterUidChanged"):
            raise GateFailure("fresh-cluster-domain")
        stable = {
            "schema": "amoebius.retained-storage.sprint-28.3-receipt.v1", "register": 3,
            "substrate": "linux-cpu", "realClusterDelete": True, "freshCluster": True,
            "postgresByteIdentical": True, "minioByteIdentical": True,
            "postRecreateWrites": 0, "seedCommands": 0, "publicRegistryPulls": 0,
            "mutantsRed": [name for name, _flag, _marker in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        (evidence / "sprint-28.3-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-28.3-mutants.json").write_text(json.dumps({
            "schema": "amoebius.retained-storage.sprint-28.3-mutants.v1", "baselineRestored": True,
            "results": [{"mutant": name, "result": "RED", "observedFailureMarker": marker} for name, _flag, marker in MUTANTS],
        }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-28.3-phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
        )
        message = f"retained-storage-sprint-28.3-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})"
        (evidence / "sprint-28.3-gate.log").write_text(message + "\n", encoding="utf-8")
        print(message)
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"retained-storage-sprint-28.3-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
