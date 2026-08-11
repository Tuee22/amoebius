#!/usr/bin/env python3
"""Run and seal the Phase-43 gateway-migration correspondence gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_43"
LIVE = EVIDENCE / "gateway-migration-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_43_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_43_ledger.json"
MANIFEST = ROOT / "test/phase0_oracle_manifest.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
KIND = "/home/matthewnowak/.local/bin/kind"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
MUTANTS = (
    ("M-verify-caught-up-stub", "phase43-verify-caught-up-stub-mutant", "phase43-verify-caught-up:"),
    ("M-promote-before-fence", "phase43-promote-before-fence-mutant", "phase43-promote-before-fence:"),
)
MODEL_PROVEN = {"phase3-interpret-decision-core", "all-five-safety-invariants"}
ASSUMED = {"data-loss-bound-assumed-and-monitored"}
UNVERIFIED = {"route53-provider-api", "physically-independent-pulsar-broker-per-child", "real-wan-partition"}


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise GateFailure(tag)


def fingerprint(value: Any, *, newline: bool = False) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    if newline:
        payload += b"\n"
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    return fingerprint(payload)


def invoke(name: str, arguments: Sequence[str], *, extra_env: dict[str, str] | None = None, timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(extra_env or {})
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'-' if flag != enabled else ''}{flag}" for _, flag, _ in MUTANTS)


def sim_args(enabled: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "gateway-migration-sim", "-w", GHC, *flags(enabled), "--test-show-details=direct", "-j1", "-v0")


def live_reader_args(enabled: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "gateway-migration-drills-live", "-w", GHC, *flags(enabled), "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update({"PHASE43_PURE_ONLY": "1"})
    arguments = sim_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("43\t")]
    require(len(rows) == 9, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 7, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 2, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read test/phase0_oracle_manifest.tsv", "output": "7 oracles; 2 mutants", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    result = subprocess.run(
        (DHALL_TO_JSON, "--file", "test/dhall/phase_43_gateway_migration.dhall"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(result.returncode == 0, f"budget-dhall:{result.stdout}")
    budget = json.loads(result.stdout)
    require(budget.get("lagBoundSeconds") == 5 and budget.get("rtoSeconds") == 60, "numeric-budget")
    require(budget.get("minimumAckedUnreplicatedAtCut") == 8, "positive-lag-budget")
    require(budget.get("linuxCpuAvailableOnEveryHardwareSubstrate") is True, "universal-linux-cpu-budget")
    for path in (
        ROOT / "test/inject/journal/phase43-schema.json",
        *sorted((ROOT / "test/fixtures/phase43").glob("*.json")),
    ):
        json.loads(path.read_text(encoding="utf-8"))
    return {"name": "independent-oracles", "command": "dhall-to-json and parse Phase-43 JSON pins", "output": "numeric budget, journal, traces, invariants, demand, observer valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schema") == "amoebius.phase43.gateway-migration-live.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable, newline=True), "live-evidence-digest")
    forest = live.get("forest", {})
    require(forest.get("ready") is True and forest.get("created") == ["amoebius-p43-parent", "amoebius-p43-source", "amoebius-p43-target"], "forest")
    planned = live.get("planned", {})
    require(planned.get("acknowledged") == 24 and planned.get("unreplicatedAtCut", 0) >= 8, "planned-positive-lag")
    require(planned.get("recovered") == 24 and planned.get("permanentLoss") == 0 and planned.get("rpoZeroBySetEquality") is True, "planned-rpo")
    require(planned.get("sessionAlwaysRebindable") is True and planned.get("dnsObserved") == "127.0.0.12", "planned-rebind")
    failover = live.get("failover", {})
    require(failover.get("acknowledged") == 24 and failover.get("unreplicatedAtKill", 0) >= 8, "failover-positive-lag")
    require(failover.get("observedLagSeconds", 6) <= failover.get("declaredLagBoundSeconds", 5), "failover-lag")
    require(failover.get("measuredRtoSeconds", 61) <= failover.get("declaredRtoSeconds", 60), "failover-rto")
    require(failover.get("promotionGate") == {"freshnessWitness": False, "holdsFence": True, "lagBoundSeconds": 5, "observedLagSeconds": 1}, "promotion-gate")
    require(failover.get("boundedByBudget") is True and failover.get("sessionRebound") is True, "failover-rebind")
    require(failover.get("recoveredAfterHeal") == 24 and failover.get("permanentLoss") == 0, "failback-convergence")
    wireguard = live.get("wireGuardHubMove", {})
    require(wireguard == {"rawKernel": True, "sourceAfter": "", "sourceBefore": "wg0", "targetAfter": "wg0"}, "wireguard-hub")
    correspondence = live.get("modelCorrespondence", {})
    require(correspondence.get("decisionCore") == "Amoebius.Formal.Interpret.interpret", "decision-core")
    require(set(correspondence.get("modeledActionsCovered", [])) == {
        "StartPlanned", "StandUpReplica", "Quiesce", "VerifyCaughtUp", "PromotePlanned",
        "RepointPlannedDns", "Unfreeze", "DrainMonitor", "DecommissionSource", "ActiveCrash",
        "ColdSeed", "PromoteSurvivor", "RepointFailoverDns", "BoundedRebind", "Heal", "MergeConverge",
    }, "modeled-action-coverage")
    require(correspondence.get("allFiveSafetyInvariantsAsserted") is True, "invariant-coverage")
    teardown = live.get("teardown", {})
    require(teardown.get("exact") is True and teardown.get("survivingTestClusters") == 0 and teardown.get("survivingMigrationDnsRecords") == 0, "teardown")
    require(live.get("deferred") == {
        "route53ProviderApi": "UNVERIFIED (configured AWS token invalid; authoritative local DNS drilled)",
        "physicallyIndependentPulsarBrokerPerChild": "UNVERIFIED",
        "realWanPartition": "UNVERIFIED (single-host kind forest)",
    }, "deferred-honesty")
    require(live.get("honesty") == {
        "dataLossBound": "assumed-and-monitored",
        "modeledSafety": "proven-for-the-model at scope 2 (Phase 3)",
        "recoveryTime": "tested", "runtimeMigration": "tested",
    }, "honesty-ledger")
    require(live.get("universalLinuxCpu") == {
        "availableOnEveryHardwareSubstrate": True,
        "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
    }, "universal-linux-cpu-and-pristine-routing")
    serialized = LIVE.read_text(encoding="utf-8")
    require(not re.search(r"(?i)(secretAccessKey|root_token|privateKey|kubernetes\.jwt)", serialized), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(not any(name in clusters for name in ("amoebius-p43-parent", "amoebius-p43-source", "amoebius-p43-target")), "kind-residue")
    namespaces = subprocess.run(("/usr/bin/sudo", "-n", "/usr/sbin/ip", "netns", "list"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout
    require("a43-source" not in namespaces and "a43-target" not in namespaces, "netns-residue")
    require(not Path("/var/tmp/amoebius-phase43-live").exists(), "live-root-residue")
    require(not Path("/var/tmp/amoebius-phase43-journal").exists(), "journal-root-residue")
    return {"name": "external-cleanup-readback", "command": "kind/netns/exact-root inventories", "output": "empty", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    coverage = []
    for surface in surfaces:
        status = "UNVERIFIED" if surface in UNVERIFIED else "assumed" if surface in ASSUMED else "proven-for-the-model" if surface in MODEL_PROVEN else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger: dict[str, Any] = {
        "phase": 43,
        "gate_command": "python3 tools/phase43_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "proven-for-the-model"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": coverage,
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), separators=(",", ":")))
            return 0
        rows = [invoke("source-build", (CABAL, "build", "amoebius:formal-model", "amoebius:dsl-core", "gateway-migration-sim", "gateway-migration-drills-live", "-w", GHC, *flags(), "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("register-2.5-simulation", sim_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "gateway-migration-live", "command": "sealed just-produced Phase-43 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("gateway-migration-live", (sys.executable, "tools/phase43_gateway_migration_live.py"), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        rows.append(invoke("sealed-live-reader", live_reader_args(), extra_env={"PHASE43_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored-simulation", sim_args()))
        rows.append(invoke("baseline-restored-live-reader", live_reader_args(), extra_env={"PHASE43_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase43.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "plannedRpo": 0, "failoverWithinBudget": True, "modeledActionsCovered": 16,
            "route53ProviderApi": "UNVERIFIED", "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text(
            "\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows)
            + f"\nPHASE-43-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8",
        )
        print(f"phase43-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase43-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
