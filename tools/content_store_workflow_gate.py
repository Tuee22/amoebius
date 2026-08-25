#!/usr/bin/env python3
"""Run and seal the Phase-38 content-store/workflow-runtime gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_37"
LIVE = EVIDENCE / "content-store-workflow-live.json"
SIMULATION = EVIDENCE / "workflow-failover-sim.json"
ENUMERATION = ROOT / "test/enumeration/phase_38_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_38_ledger.json"
MANIFEST_HEX = ROOT / "test/golden/content_store/manifest_canonical.cbor"
MANIFEST_SHA = ROOT / "test/golden/content_store/manifest_canonical.sha256"
NONCANONICAL_HEX = ROOT / "test/golden/content_store/manifest_noncanonical.cbor"
HEAD_GOLDEN = ROOT / "test/golden/workflow_runtime/head_nofault.bin"
FORBIDDEN_PACKAGES = ROOT / "test/golden/workflow_runtime/forbidden_coordination_packages.txt"
ORACLE_MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
EXPECTED_HEAD = "fd0049fa31facd012891d8ce294c218e606c191ba51126680e5903b67b2ab059"
UNVERIFIED = {
    "cross-cluster-content-replication",
    "derive-experiment-hash-and-splitmix-seed-kernel",
    "pulsar-consensus-internals",
}
MUTANTS = (
    ("M-ack-before-store", "content-store-workflow-ack-before-store-write-mutant", "worker-critical-window-order", None),
    ("M-cleanup-on-status", "content-store-workflow-cleanup-on-job-status-mutant", "terminal-persist", None),
    ("M-double-apply", "content-store-workflow-double-apply-on-redelivery-mutant", "double-application-on-redelivery", "workflow-sim-invariant:NoDoubleApplication"),
    ("M-insertion-order", "content-store-workflow-insertion-order-encoder-mutant", "canonical-manifest-writer-b", None),
    ("M-lease-election", "content-store-workflow-lease-election-mutant", "forbidden-coordination-surface", None),
    ("M-orphan-budget-omitted", "content-store-workflow-orphan-budget-omitted-mutant", "write-budget-peak-mismatch:exact-fit", None),
    ("M-orphan-consumer", "content-store-workflow-orphan-consumer-on-promotion-mutant", "standby-promotion-invariant", "workflow-sim-invariant:NoOrphanConsumerAfterPromotion"),
    ("M-orphan-free-conflict", "content-store-workflow-orphan-free-on-pointer-conflict-mutant", "write-budget-peak-mismatch:pre-horizon-orphan-exact", None),
    ("M-sweep-skips-pulsar", "content-store-workflow-sweep-skips-pulsar-mutant", "postflight-sweep-domain", None),
    ("M-trust-gateway-ack", "content-store-workflow-trust-gateway-ack-mutant", "terminal-retain-without-readback", None),
)


class GateFailure(RuntimeError):
    pass


def require(value: bool, tag: str) -> None:
    if not value:
        raise GateFailure(tag)


def invoke(name: str, arguments: Sequence[str], *, extra_env: dict[str, str] | None = None, timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(extra_env or {})
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def all_flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'-' if flag != enabled else ''}{flag}" for _, flag, _, _ in MUTANTS)


def reject_mutant(name: str, flag: str, marker: str, simulation_marker: str | None) -> dict[str, str]:
    arguments = (CABAL, "test", "content-store-workflow-live", *all_flags(flag), "--test-show-details=direct", "-j1")
    environment = os.environ.copy()
    environment["CONTENT_STORE_WORKFLOW_PURE_ONLY"] = "1"
    result = subprocess.run(arguments, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800)
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    outputs = [marker]
    commands = [shlex.join(arguments)]
    if simulation_marker is not None:
        simulation_arguments = (CABAL, "test", "workflow-failover-sim", *all_flags(flag), "--test-show-details=direct", "-j1")
        simulation = subprocess.run(simulation_arguments, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800)
        require(simulation.returncode != 0, f"{name}:simulation-green-mutant")
        require(simulation_marker in simulation.stdout, f"{name}:simulation-wrong-red-reason:{simulation.stdout}")
        commands.append(shlex.join(simulation_arguments))
        outputs.append(simulation_marker)
    return {"name": name, "command": " && ".join(commands), "output": "; ".join(outputs), "result": "RED"}


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
        "phase": 37,
        "gate_command": "python3 tools/content_store_workflow_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"}, {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def hex_custody(path: Path) -> bytes:
    payload = "".join(line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#"))
    require(bool(re.fullmatch(r"[0-9a-f]+", payload)) and len(payload) % 2 == 0, f"hex-custody:{path}")
    return bytes.fromhex(payload)


def oracle_domain() -> dict[str, str]:
    result = subprocess.run((sys.executable, "tools/content_store_workflow_oracle.py"), cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60)
    require(result.returncode == 0, f"oracle-exit:{result.stdout}")
    oracle = json.loads(result.stdout)
    canonical = hex_custody(MANIFEST_HEX)
    noncanonical = hex_custody(NONCANONICAL_HEX)
    expected_sha = MANIFEST_SHA.read_text(encoding="utf-8").strip()
    require(oracle.get("canonicalHex") == canonical.hex(), "oracle-canonical-bytes")
    require(oracle.get("canonicalSha256") == expected_sha == EXPECTED_HEAD, "oracle-canonical-sha")
    require(hashlib.sha256(canonical).hexdigest() == expected_sha, "custody-canonical-sha")
    require(oracle.get("noncanonicalHex") == noncanonical.hex(), "oracle-noncanonical-bytes")
    require(oracle.get("firstMismatchOffset") == 24, "oracle-first-mismatch")
    require(hex_custody(HEAD_GOLDEN) == bytes.fromhex(EXPECTED_HEAD), "head-golden")
    rows = [line for line in ORACLE_MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("37\t")]
    require(len(rows) == 17 and sum("\toracle\t" in row for row in rows) == 7 and sum("\tmutant\t" in row for row in rows) == 10, "phase0-oracle-custody-domain")
    return {"name": "independent-oracle", "command": f"{sys.executable} tools/content_store_workflow_oracle.py", "output": f"{expected_sha}; mismatch=24; custody=17", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schemaVersion") == "amoebius.phase37.content-store-workflow-live.v1", "live-schema")
    require(live.get("sealed") is True and live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate-seal")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable), "live-evidence-digest")
    store = live.get("contentStore", {})
    protocol = store.get("protocol", {})
    require(protocol.get("manifestCanonicalSha256") == EXPECTED_HEAD and protocol.get("manifestCanonicalCbor") is True, "manifest-protocol")
    require(protocol.get("immutableConditional") == "If-None-Match:*" and protocol.get("immutableDuplicateStatus") == 412, "immutable-protocol")
    pointer = protocol.get("pointer", {})
    require(pointer.get("winnerStatus") == 200 and pointer.get("loserStatus") == 412 and pointer.get("loserReReadHead") == EXPECTED_HEAD, "pointer-cas")
    require(pointer.get("tornReads") == 0 and pointer.get("readerHeads") == [EXPECTED_HEAD] * 4, "pointer-atomic-read")
    orphan = store.get("orphanGc", {})
    require(orphan.get("pointerConflictStatus") == 412 and orphan.get("pointerConflictLeftHeadUnchanged") is True, "orphan-pointer-conflict")
    require(orphan.get("overCapacityRequestedBytes") == orphan.get("overCapacitySupplyBytes") + 1 and orphan.get("overCapacityRefusedBeforeMutation") is True, "orphan-one-byte-over")
    require(orphan.get("creditGrantedBeforeObservedDeletion") is False and orphan.get("freshDeletionObservation") is True and orphan.get("postGcInventory") == [], "orphan-gc")
    require(store.get("sameDigestDifferentNamespacesChargedAsDistinctObjects") is True and set(store.get("namespaceInventories", {})) == {"run-a", "run-b"}, "namespace-accounting")
    workflow = live.get("workflow", {})
    require(workflow.get("nativeHaskellPulsarClient") is True and workflow.get("subscriptionType") == "Failover", "native-failover")
    require(workflow.get("workerRank") == ["worker-a", "worker-b", "worker-c"] and workflow.get("bespokeElection") is False, "ranked-no-election")
    require(workflow.get("coordinationApiCalls") == [] and workflow.get("leaseObjects") == [], "coordination-empty")
    rounds = live.get("rounds", [])
    require(len(rounds) == 2 and {row.get("experimentNamespace") for row in rounds} == {"run-a", "run-b"}, "two-experiment-namespaces")
    for row in rounds:
        before = row.get("activeBeforeKill", {})
        after = row.get("activeAfterKill", {})
        require(before.get("activeConsumerName") == "worker-a" and before.get("consumers") == ["worker-a", "worker-b", "worker-c"], "active-before-kill")
        require(max(int(before.get("unackedMessages", 0)), int(before.get("backlogMessages", 0))) >= 1, "critical-window-outstanding")
        require(after.get("activeConsumerName") == "worker-b" and after.get("consumers") == ["worker-b", "worker-c"], "active-after-kill")
        require(int(after.get("messageOutCounter", 0)) > int(before.get("messageOutCounter", 0)), "broker-redelivery")
        require(row.get("externalCommandCount") == 1 and row.get("externalDuplicateObserved") is False, "external-exactly-once")
        require(row.get("manifestSha") == row.get("pointerHead") == EXPECTED_HEAD and row.get("artifactByteEqual") is True, "content-confluence")
        require(row.get("criticalWindow") == "store-written/event-unacked" and row.get("computeExecuted") is True, "critical-window-compute")
    terminal = live.get("jobTerminal", {})
    require(terminal.get("statusOnlyCleanupRefused") is True and terminal.get("gatewayAckAloneInsufficient") is True, "terminal-refusal")
    variants = terminal.get("variants", [])
    require({row.get("outcome") for row in variants} == {"Succeeded", "FailedBackoffExhausted"}, "terminal-outcomes")
    require(all(all(row.get(key) is True for key in ("gatewayFailureRetained", "independentReadbackMatched", "cleanupDeadlineReached", "schedulerReleaseComplete", "deletedOnlyAfterReadback", "completedJobNoOp", "objectVersionUnchanged")) for row in variants), "terminal-proof")
    provision = live.get("provision", {})
    require(provision.get("exactFit") is True and provision.get("oneShortTerms") == 18 and provision.get("accelerator") == "None", "provision-boundaries")
    require(provision.get("runtimePodDomain") == ["content-gateway", "orchestrator", "worker-a", "worker-b", "worker-c"] and provision.get("gatewayAndCollectorProvisioned") is True, "provision-domain")
    require(provision.get("gatewayMinioReachable") is True and provision.get("workerDirectMinioReachable") is False, "content-gateway-network")
    sweep = live.get("postflightSweep", {})
    require(sweep.get("classes") == ["kubernetes", "minio", "pulsar"] and sweep.get("namedRetainedSet") == [], "sweep-domain")
    require(sweep.get("allRemaindersEmpty") is True and sweep.get("remainderAfter") == {"kubernetes": [], "minio": [], "pulsar": []}, "sweep-empty")
    require(set(sweep.get("fullInventoryBefore", {})) == {"kubernetes", "minio", "pulsar"}, "sweep-full-inventory")
    universal = live.get("universalLinuxCpu", {})
    require(universal.get("allHardwareSubstrates") is True, "universal-linux-cpu")
    require(universal.get("pristineLinux") == {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}, "pristine-linux-routing")
    require(set(live.get("unverified", [])) == {"cross-cluster content replication", "deriveExperimentHash and SplitMix seed kernel (Phase 49)", "Pulsar broker/BookKeeper/ZooKeeper consensus internals"}, "honesty-domain")


def simulation_domain(*, fresh: bool) -> None:
    require(SIMULATION.is_file(), "simulation-evidence-absent")
    if fresh:
        require(time.time() - SIMULATION.stat().st_mtime < 7200, "simulation-evidence-stale")
    simulation = json.loads(SIMULATION.read_text(encoding="utf-8"))
    require(simulation.get("schemaVersion") == "amoebius.phase37.workflow-failover-sim.v1", "simulation-schema")
    require(simulation.get("register") == 2.5 and simulation.get("substrate") == "none" and simulation.get("result") == "PASS", "simulation-register-result")
    require(simulation.get("deterministicSchedules") == 256 and simulation.get("porScheduleBound") == 32, "simulation-schedule-domain")
    require(set(simulation.get("properties", [])) == {"leak-free-standby-takeover", "no-double-application", "byte-identical-pointer-head"}, "simulation-properties")


def dependency_domain() -> dict[str, str]:
    result = subprocess.run((CABAL, "build", "amoebius-runtime", *all_flags(), "--dry-run", "-j1"), cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=900)
    require(result.returncode == 0, f"dependency-plan-exit:{result.stdout}")
    forbidden = [line.strip() for line in FORBIDDEN_PACKAGES.read_text(encoding="utf-8").splitlines() if line.strip()]
    lowered = result.stdout.lower()
    present = [package for package in forbidden if re.search(rf"(^|[^a-z0-9-]){re.escape(package)}([^a-z0-9-]|$)", lowered)]
    require(not present, f"forbidden-coordination-dependencies:{present}")
    return {"name": "dependency-plan", "command": shlex.join((CABAL, "build", "amoebius-runtime", *all_flags(), "--dry-run", "-j1")), "output": "forbidden coordination packages absent", "result": "PASS"}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        disabled = all_flags()
        rows = [invoke("source-build", (CABAL, "build", "content-store-workflow-live", "workflow-failover-sim", *disabled, "-j1"))]
        rows.append(oracle_domain())
        rows.append(dependency_domain())
        if args.reuse_fresh_live:
            rows.append({"name": "workflow-live", "command": "sealed just-produced Phase-38 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("workflow-live", (CABAL, "test", "content-store-workflow-live", *disabled, "--test-show-details=direct", "-j1"), timeout=5400))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(invoke("sealed-live-reader", (CABAL, "test", "content-store-workflow-live", *disabled, "--test-show-details=direct", "-j1"), extra_env={"CONTENT_STORE_WORKFLOW_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("workflow-simulation", (CABAL, "test", "workflow-failover-sim", *disabled, "--test-show-details=direct", "-j1")))
        simulation_domain(fresh=True)
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "content-store-workflow-live", "workflow-failover-sim", *disabled, "--test-show-details=direct", "-j1"), extra_env={"CONTENT_STORE_WORKFLOW_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase37.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "canonicalManifestSha256": EXPECTED_HEAD, "twoNamespaceFailover": True,
            "activeBeforeKill": "worker-a", "promotedAfterKill": "worker-b",
            "externalCommandCountPerRound": 1, "postflightClasses": ["kubernetes", "minio", "pulsar"],
            "iosimSchedules": 256, "mutantsRed": [name for name, _, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-37-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"content-store-workflow-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, StopIteration, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"content-store-workflow-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
