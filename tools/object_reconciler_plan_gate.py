#!/usr/bin/env python3
"""Seal the object reconciler's desired/indexed/observed/preflight/action seam."""

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


def invoke(
    name: str,
    arguments: Sequence[str],
    timeout: int = 1800,
    *,
    global_inventory: bool = False,
) -> dict[str, str]:
    environment = os.environ.copy()
    if global_inventory:
        # This is a nested regression gate. Its containment baseline is the host,
        # not the marker-owned live fixture belonging to the Phase-67 parent.
        for environment_key in ("DOCKER_HOST", "DOCKER_CONFIG", "KUBECONFIG"):
            environment.pop(environment_key, None)
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
        if not (ROOT / f"test/golden/manifest/{golden}.json.golden").is_file():
            raise GateFailure(f"phase13-golden-absent:{golden}")
    return {"objectCount": len(rows), "actionCount": len(expected_actions), "goldenIds": corpus["phase13GoldenIds"]}


def validate_read_only_boundary() -> None:
    forbidden = ("System.Process", "typed-process", "kubectl", "writeFile", "appendFile", "removeFile")
    for relative in READ_ONLY_MODULES:
        text = (ROOT / relative).read_text(encoding="utf-8")
        hits = [symbol for symbol in forbidden if symbol in text]
        if hits:
            raise GateFailure(f"preflight-writer-import:{relative}:{hits}")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # The bundle this run writes into is supplied by the caller. There is deliberately no
    # default: a default names a location, and whatever a previous run left there would
    # decide this gate instead of the run in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    arguments = parser.parse_args(argv)
    evidence = arguments.evidence
    try:
        cabal, compiler = build_tools()
        fixture = validate_fixture()
        validate_read_only_boundary()
        flags = (
            "-f-object-reconciler-wait-for-ready-pure-mutant",
            "-f-object-reconciler-generation-after-diff-mutant",
            "-f-object-reconciler-label-only-delete-mutant",
            "-f-object-reconciler-healthy-overbound-child-mutant",
        )
        rows = [
            invoke(
                "phase13-render-gate",
                (sys.executable, "tools/render_manifest_gate.py"),
                global_inventory=True,
            ),
            invoke(
                "object-reconciler-spec",
                (
                    cabal,
                    f"--builddir={ROOT / '.build/dist-newstyle/object-reconciler'}",
                    f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
                    f"--with-compiler={compiler}", "test", "object-reconciler-spec", *flags,
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
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "sprint-26.1-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (evidence / "sprint-26.1-phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\tPASS\n" for row in rows), encoding="utf-8"
        )
        log: list[str] = []
        for row in rows:
            log.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
        log.append(f"SPRINT-26.1-GATE PASS {receipt['receiptFingerprint']}")
        (evidence / "sprint-26.1-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"phase26-sprint26.1-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.1-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
