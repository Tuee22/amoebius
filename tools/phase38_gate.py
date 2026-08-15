#!/usr/bin/env python3
"""Run and seal the Phase-38 owner-scoped UI projection gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_38"
LIVE = EVIDENCE / "ui-projection-runtime-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_38_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_38_ledger.json"
ORACLE_MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {
    "browser-presentation-and-reconnect",
    "ui-release-compatibility-and-rollout",
    "ml-artifact-lift",
    "ha-and-cross-cluster-projection-replication",
}
MUTANTS = (
    ("M-drop-owner-key", "phase38-drop-owner-key-mutant", "phase38-drop-owner-key:"),
    ("M-drop-owner-subscription", "phase38-drop-owner-subscription-mutant", "phase38-drop-owner-subscription:"),
    ("M-drop-receipt-command-id", "phase38-drop-receipt-command-id-mutant", "phase38-drop-receipt-command-id:"),
)


class GateFailure(RuntimeError):
    pass


def require(value: bool, tag: str) -> None:
    if not value:
        raise GateFailure(tag)


def fingerprint(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    return fingerprint(payload)


def invoke(
    name: str,
    arguments: Sequence[str],
    *,
    extra_env: dict[str, str] | None = None,
    timeout: int = 3600,
) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(extra_env or {})
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def all_flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'-' if flag != enabled else ''}{flag}" for _, flag, _ in MUTANTS)


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (
        CABAL, "test", "ui-projection-runtime-live", *all_flags(flag),
        "--test-show-details=direct", "-j1", "-v0",
    )
    environment = os.environ.copy()
    environment["PHASE38_PURE_ONLY"] = "1"
    result = subprocess.run(
        arguments, cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [
        line.strip()
        for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]
    ledger: dict[str, Any] = {
        "phase": 38,
        "gate_command": "python3 tools/phase38_gate.py --reuse-fresh-live",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [
            {"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"}
            for surface in surfaces
        ],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def phase0_domain() -> dict[str, str]:
    rows = [line for line in ORACLE_MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("38\t")]
    require(len(rows) == 7, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 4, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 3, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file(), f"phase0-custody-missing:{path}")
    return {
        "name": "phase0-custody", "command": "read test/oracle/preimplementation_artifacts.tsv",
        "output": "4 oracles; 3 mutants", "result": "PASS",
    }


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schemaVersion") == "amoebius.phase38.ui-projection-runtime-live.v1", "live-schema")
    require(live.get("sealed") is True and live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate-seal")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable), "live-evidence-digest")

    fixtures = live.get("fixtureDigests", {})
    require(set(fixtures) == {
        "projection_matrix.tsv", "expected_latest_values.tsv",
        "expected_receipts.tsv", "expected_watermarks.tsv",
    }, "fixture-domain")
    require(all(re.fullmatch(r"sha256:[0-9a-f]{64}", str(value)) for value in fixtures.values()), "fixture-digests")

    authority = live.get("authority", {})
    require(authority.get("sessionsMintedAfterGateStart") == 3, "fresh-session-count")
    introspections = authority.get("activeIntrospections", {})
    require(set(introspections) == {"alice-a", "bob-a", "carol-b"}, "authority-identity-domain")
    require(all(row.get("active") is True for row in introspections.values()), "authority-active")
    require({row.get("tenant") for row in introspections.values()} == {"t-a", "t-b"}, "authority-tenant-domain")
    require(all("issuerDigest" in row and "issuer" not in row for row in introspections.values()), "authority-issuer-custody")

    projection = live.get("projection", {})
    require(all(projection.get(key) is True for key in (
        "ownerQualifiedCompactionKeys", "ownerQualifiedSubscriptions",
        "updateTombstoneRecreateObserved", "exactCommandRedeliveryCollapsed",
    )), "projection-invariants")
    require(projection.get("watermarks") == {"alice-a": 3, "bob-a": 0, "carol-b": 0}, "watermark-domain")

    receipts = live.get("receipts", {})
    require(receipts.get("originalScopedCommandRetained") is True and receipts.get("effectOwnerOnly") is True, "receipt-identity-owner")
    require(receipts.get("conflictingInput") == "IdempotencyConflict", "receipt-conflict")
    require(receipts.get("effectCounts") == {
        "cmd-a1": 1, "cmd-a4": 1, "cmd-a4/changed-input": 0, "cmd-b1": 1, "cmd-c1": 1,
    }, "receipt-effect-counts")

    observers = live.get("externalObservers", {})
    require(observers.get("nativeHaskellConsumer") is True, "native-observer")
    broker = observers.get("brokerAdmin", {})
    topics = broker.get("topics", [])
    require([
        (row.get("logicalName"), row.get("messageInCounter"), row.get("messageOutCounter"))
        for row in topics
    ] == [
        ("workflow.events.linux-cpu", 8, 32),
        ("ui.projection.linux-cpu", 7, 7),
        ("ui.receipts.linux-cpu", 5, 5),
    ], "broker-topic-counters")
    require(all("topicIdentityDigest" in row and "topic" not in row for row in topics), "broker-topic-custody")
    compaction = broker.get("compaction", {})
    require(set(compaction) == {"ui.projection.linux-cpu", "ui.receipts.linux-cpu"}, "compaction-domain")
    require(all(row.get("status") == "SUCCESS" for row in compaction.values()), "compaction-success")

    bypass = live.get("bypass", {})
    require(bypass.get("sameTenantForeignOwner") == bypass.get("foreignTenant") == "resource-unavailable", "paired-public-denial")
    require(all(bypass.get(key) is True for key in (
        "forgedTenantOwnerHeadersIgnored", "swappedOpaqueHandleDenied",
        "guessedLocalEntityCannotCrossScope", "staleEpochDenied",
    )), "bypass-denials")
    require(bypass.get("foreignSubscriptionEffects") == 0, "foreign-subscription-effect")
    require(bypass.get("keycloakUserDirectPulsar") == {
        "keycloakCredentialConveysBrokerAuthority": False,
        "keycloakUserBrokerReachable": False,
        "policyEnforced": True,
        "workerBrokerReachable": True,
    }, "direct-pulsar-refusal")

    cleanup = live.get("cleanup", {})
    require(cleanup.get("inventoriesEqual") is True and cleanup.get("residue") == [], "cleanup-inventory")
    require(cleanup.get("providers") == {"Keycloak": True, "Pulsar": True, "KubernetesApi": True}, "cleanup-providers")
    universal = live.get("universalLinuxCpu", {})
    require(universal.get("allHardwareSubstrates") is True, "universal-linux-cpu")
    require(universal.get("pristineLinux") == {
        "linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2",
    }, "pristine-linux-routing")
    require(set(live.get("unverified", [])) == {
        "browser presentation and reconnect behavior", "UI release compatibility and rollout",
        "ML artifact lift", "high availability and cross-cluster projection replication",
    }, "honesty-domain")
    serialized = LIVE.read_text(encoding="utf-8")
    require("resultChallenge" not in serialized and "clientSecret" not in serialized and '"admin"' not in serialized, "secret-challenge-custody")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), separators=(",", ":")))
            return 0
        disabled = all_flags()
        rows = [invoke("source-build", (
            CABAL, "build", "ui-projection-runtime-live", "amoebius-pulsar", *disabled, "-j1", "-v0",
        ))]
        rows.append(phase0_domain())
        if args.reuse_fresh_live:
            rows.append({
                "name": "projection-live", "command": "sealed just-produced Phase-38 live receipt",
                "output": "fresh final live evidence", "result": "PASS",
            })
        else:
            rows.append(invoke("projection-live", (
                CABAL, "test", "ui-projection-runtime-live", *disabled,
                "--test-show-details=direct", "-j1", "-v0",
            ), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(invoke("sealed-live-reader", (
            CABAL, "test", "ui-projection-runtime-live", *disabled,
            "--test-show-details=direct", "-j1", "-v0",
        ), extra_env={"PHASE38_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", (
            CABAL, "test", "ui-projection-runtime-live", *disabled,
            "--test-show-details=direct", "-j1", "-v0",
        ), extra_env={"PHASE38_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (
            sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION),
        )))
        stable = {
            "schema": "amoebius.phase38.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "authoritySessions": 3, "workflowEvents": 8, "projectionMessages": 7, "receiptMessages": 5,
            "projectionCompaction": "SUCCESS", "receiptCompaction": "SUCCESS",
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
        )
        (EVIDENCE / "phase-gate.log").write_text(
            "\n".join(
                f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}"
                for row in rows
            ) + f"\nPHASE-38-GATE PASS {derived['ledger_hash']}\n",
            encoding="utf-8",
        )
        print(f"phase38-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase38-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
