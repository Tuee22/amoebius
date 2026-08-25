#!/usr/bin/env python3
"""Run and seal the Phase-36 native Pulsar client gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_35"
LIVE = EVIDENCE / "pulsar-client-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_36_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_36_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {
    "content-store-workflow-workflow-content-store",
    "cross-cluster-pulsar-correspondence",
    "broker-consensus-internals",
}
MUTANTS = (
    ("M-topic-literal", "pulsar-client-topic-literal-mutant", "independent derived-topic oracle"),
    ("M-drop-one-sided", "pulsar-client-drop-one-sided-mutant", "one-sided-link-not-rejected"),
    ("M-produce-raw", "pulsar-client-produce-raw-mutant", "CBOR-only API surface"),
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], *, extra_env: dict[str, str] | None = None, timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(extra_env or {})
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    flags = [f"-f{'-' if candidate != flag else ''}{candidate}" for _, candidate, _ in MUTANTS]
    arguments = (CABAL, "test", "pulsar-client-live", *flags, "--test-show-details=direct", "-j1")
    environment = os.environ.copy()
    environment["PULSAR_CLIENT_REUSE_FRESH_LIVE"] = "1"
    result = subprocess.run(arguments, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800)
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def require(value: bool, tag: str) -> None:
    if not value:
        raise GateFailure(tag)


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 35,
        "gate_command": "python3 tools/pulsar_client_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-10",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"}, {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def evidence_domain(*, fresh: bool) -> dict[str, Any]:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schemaVersion") == "amoebius.phase35.pulsar-client-live.v1", "live-schema")
    require(live.get("sealed") is True and live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate-seal")
    wire = live.get("nativeWire", {})
    require(wire.get("transport") == "Pulsar TCP binary protocol" and wire.get("webSocketUsed") is False, "native-wire")
    require(wire.get("generatedProtocolTypes") is True and wire.get("mandatoryPayloadCrc32c") is True, "generated-crc-wire")
    require(wire.get("secondLanguageRuntimeUsedForClient") is False, "single-language-client")
    required_frames = {"CONNECT", "CONNECTED", "LOOKUP", "PRODUCER", "SEND", "SEND_RECEIPT", "SUBSCRIBE", "FLOW", "MESSAGE", "ACK", "SEEK"}
    require(required_frames <= set(wire.get("framesExercised", [])), "native-frame-coverage")
    rounds = live.get("rounds", [])
    require(len(rounds) == 2 and len({row.get("resultNamespace") for row in rounds}) == 2, "two-namespace-runs")
    for row in rounds:
        require(all(row.get(key) is True for key in ("resultNativeProtocol", "resultCborRoundTrip", "resultDuplicateCollapsed", "resultRedelivery", "resultSeekReplay")), "round-result")
        require(row.get("resultSubscriptionTypes") == 4 and len(row.get("resultTopics", [])) == 2, "round-surface")
        require(all(topic.endswith(".linux-cpu") for topic in row.get("resultTopics", [])), "derived-linux-cpu-topics")
    observations = live.get("externalBrokerObservation", {})
    require(set(observations) == {"run-a", "run-b"}, "external-observation-domain")
    for namespace in observations.values():
        require(namespace.get("deduplication") is True and len(namespace.get("topics", [])) == 2, "broker-readback")
        command = next((row for row in namespace["topics"] if ".command.linux-cpu" in row.get("topic", "")), None)
        require(command is not None and command.get("messageInCounter") == 2 and command.get("persistedEntries") == 1, "broker-dedup-proof")
    cleanup = live.get("cleanup", {})
    require(live.get("cleanupInventoriesEqual") is True and cleanup.get("preRunTargetInventory") == cleanup.get("postRunTargetInventory") == [], "cleanup-inventory")
    require(cleanup.get("tenantAbsent") is True and cleanup.get("standingPolicyByteIdentical") is True, "cleanup-policy")
    require(live.get("observer", {}).get("distinctFromClientSocket") is True, "independent-observer")
    universal = live.get("universalLinuxCpu", {})
    require(universal.get("availableOnEveryHardwareSubstrate") is True, "universal-linux-cpu")
    require(universal.get("pristineLinuxVm") == {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}, "pristine-linux-routing")
    return live


def compile_refusal(name: str, fixture: str, marker: str) -> dict[str, str]:
    script = f":load test/negative/pulsar_client/{fixture}\n:quit\n"
    arguments = (CABAL, "repl", "amoebius-pulsar:test:pulsar-client-live")
    result = subprocess.run(arguments, cwd=ROOT, input=script, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=900)
    require(marker in result.stdout and "Failed, unloaded all modules." in result.stdout, f"{name}:wrong-compile-refusal:{result.stdout}")
    return {"name": name, "command": f"printf <fixture> | {shlex.join(arguments)}", "output": marker, "result": "PASS"}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        python = sys.executable
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows = [invoke("source-build", (CABAL, "build", "amoebius-pulsar", *disabled, "-j1"))]
        if args.reuse_fresh_live:
            rows.append({"name": "native-live", "command": "sealed just-produced Phase-36 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("native-live", (CABAL, "test", "pulsar-client-live", *disabled, "--test-show-details=direct", "-j1"), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(invoke("sealed-live-reader", (CABAL, "test", "pulsar-client-live", *disabled, "--test-show-details=direct", "-j1"), extra_env={"PULSAR_CLIENT_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("dedup-simulation", (CABAL, "test", "pulsar-dedup-sim", *disabled, "--test-show-details=direct", "-j1")))
        rows.append(compile_refusal("raw-payload-compile-refusal", "RawPayload.hs", "does not export ‘produceRaw’"))
        rows.append(compile_refusal("literal-topic-compile-refusal", "LiteralTopic.hs", "Illegal term-level use of the type constructor ‘Topic’"))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "pulsar-client-live", "pulsar-dedup-sim", *disabled, "--test-show-details=direct", "-j1"), extra_env={"PULSAR_CLIENT_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase35.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "nativePulsarTcp": True, "typedCborOnly": True, "twoNamespaceDedup": True,
            "redeliveryAndSeek": True, "subscriptionTypes": 4,
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-35-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"pulsar-client-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, StopIteration, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"pulsar-client-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
