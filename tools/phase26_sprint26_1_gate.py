#!/usr/bin/env python3
"""Seal Sprint 26.1's desired/indexed/observed/preflight/action seam."""

from __future__ import annotations

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
CORPUS = ROOT / "test/live/fixtures/reconcile-corpus/corpus.json"
EXPECTED = ROOT / "test/live/fixtures/reconcile-corpus/expected-actions.json"
READ_ONLY_MODULES = (
    "src/Amoebius/Manifest/Preflight.hs",
    "src/Amoebius/Manifest/Diff.hs",
    "src/Amoebius/Manifest/Reconcile.hs",
    "src/Amoebius/Execution/Observe.hs",
    "src/Amoebius/Execution/Normalize.hs",
    "src/Amoebius/Execution/RuntimeStorage.hs",
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 1800) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "result": "PASS", "output": result.stdout.strip()}


def fingerprint(value: dict[str, Any]) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def validate_fixture() -> dict[str, Any]:
    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    expected = json.loads(EXPECTED.read_text(encoding="utf-8"))
    rows = corpus.get("objects", [])
    identities = [row.get("identity") for row in rows]
    if len(rows) != 12 or len(set(identities)) != 12:
        raise GateFailure("corpus-object-domain")
    expected_actions = expected.get("actions", [])
    if len(expected_actions) != len(rows):
        raise GateFailure("expected-action-domain")
    if [action.split(":", 1)[1] for action in expected_actions] != identities:
        raise GateFailure("expected-action-identity-order")
    required_prefixes = {"Namespace", "Lease", "Deployment", "StatefulSet", "Job", "CustomResourceDefinition", "CapacityReservation"}
    observed_prefixes = {str(identity).split("/", 1)[0] for identity in identities}
    if not required_prefixes <= observed_prefixes:
        raise GateFailure(f"corpus-kind-domain:{sorted(required_prefixes - observed_prefixes)}")
    if corpus.get("phase13GoldenIds") != ["registry_singlenode", "messagebus_singlenode"]:
        raise GateFailure("phase13-golden-id-domain")
    for golden in corpus["phase13GoldenIds"]:
        if not (ROOT / f"test/manifest/golden/{golden}.json.golden").is_file():
            raise GateFailure(f"phase13-golden-absent:{golden}")
    return {"objectCount": len(rows), "actionCount": len(expected_actions), "goldenIds": corpus["phase13GoldenIds"]}


def validate_read_only_boundary() -> None:
    forbidden = ("System.Process", "typed-process", "kubectl", "writeFile", "appendFile", "removeFile")
    for relative in READ_ONLY_MODULES:
        text = (ROOT / relative).read_text(encoding="utf-8")
        hits = [symbol for symbol in forbidden if symbol in text]
        if hits:
            raise GateFailure(f"preflight-writer-import:{relative}:{hits}")


def main() -> int:
    try:
        fixture = validate_fixture()
        validate_read_only_boundary()
        flags = (
            "-f-phase26-wait-for-ready-pure-mutant",
            "-f-phase26-generation-after-diff-mutant",
            "-f-phase26-label-only-delete-mutant",
            "-f-phase26-healthy-overbound-child-mutant",
        )
        rows = [
            invoke("phase13-render-gate", (sys.executable, "tools/phase13_gate.py")),
            invoke(
                "phase26-reconcile-spec",
                (
                    "/home/matthewnowak/.ghcup/bin/cabal", "test", "phase26-reconcile-spec", *flags,
                    "--test-show-details=direct", "-j1",
                ),
            ),
            invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")),
        ]
        stable = {
            "schema": "amoebius.phase26.sprint26.1-receipt.v1",
            "register": 3,
            "substrate": "linux-cpu",
            **fixture,
            "readOnlyPreflightModules": len(READ_ONLY_MODULES),
            "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "sprint-26.1-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "sprint-26.1-phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\tPASS\n" for row in rows), encoding="utf-8"
        )
        log: list[str] = []
        for row in rows:
            log.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
        log.append(f"SPRINT-26.1-GATE PASS {receipt['receiptFingerprint']}")
        (EVIDENCE / "sprint-26.1-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"phase26-sprint26.1-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.1-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
