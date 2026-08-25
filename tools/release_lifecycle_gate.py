#!/usr/bin/env python3
"""Run and seal the Phase-40 immutable release-lifecycle gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_39"
LIVE = EVIDENCE / "release-lifecycle-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_40_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_40_ledger.json"
ORACLE_MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
UNVERIFIED = {
    "gateway-api-canary-weight-shift",
    "pulsar-consumer-group-cutover",
    "cross-cluster-and-geo-promotion",
}
MUTANTS = (
    ("M-hash-omits-substrate", "release-lifecycle-hash-omits-substrate-mutant", "release-lifecycle-hash-omits-substrate:"),
    ("M-blind-put", "release-lifecycle-blind-put-mutant", "release-lifecycle-blind-put:"),
    ("M-gate-admits-unverified", "release-lifecycle-gate-admits-unverified-mutant", "release-lifecycle-gate-admits-unverified:"),
    ("M-rollout-reorders-retire", "release-lifecycle-rollout-reorders-retire-mutant", "release-lifecycle-rollout-reorders-retire:"),
    ("M-phase-gate-selfreport", "release-lifecycle-phase-gate-selfreport-mutant", "release-lifecycle-phase-gate-selfreport:"),
    ("M-scalar-migration-peak", "release-lifecycle-scalar-migration-peak-mutant", "release-lifecycle-scalar-migration-peak:"),
    ("M-drop-old-schema-on-failure", "release-lifecycle-drop-old-schema-on-failure-mutant", "release-lifecycle-drop-old-schema-on-failure:"),
    ("M-drop-verification-wal", "release-lifecycle-drop-verification-wal-mutant", "release-lifecycle-drop-verification-wal:"),
)


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
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
        CABAL, "test", "release-lifecycle-live", *all_flags(flag),
        "--test-show-details=direct", "-j1", "-v0",
    )
    environment = os.environ.copy()
    environment["RELEASE_LIFECYCLE_PURE_ONLY"] = "1"
    result = subprocess.run(
        arguments, cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def compile_boundary() -> dict[str, str]:
    positive = subprocess.run(
        (CABAL, "exec", "-v0", "--", GHC, "-fno-code", "test/fixture/accept/release_lifecycle/environment.hs"),
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=300,
    )
    require(positive.returncode == 0, f"environment-positive-compile:{positive.stdout}")
    negative = subprocess.run(
        (CABAL, "exec", "-v0", "--", GHC, "-fno-code", "test/negative/reject/fourth_environment.hs"),
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=300,
    )
    require(negative.returncode != 0, "fourth-environment-compiled")
    require("Data constructor not in scope: Qa" in negative.stdout, f"fourth-environment-wrong-reason:{negative.stdout}")
    return {
        "name": "closed-environment-compile-boundary",
        "command": "cabal exec -- ghc -fno-code test/{accept,reject}/phase_40_environment",
        "output": "Prod compiles; Qa rejected at constructor site", "result": "PASS",
    }


def phase0_domain() -> dict[str, str]:
    rows = [line for line in ORACLE_MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("39\t")]
    require(len(rows) == 20, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 12, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 8, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file(), f"phase0-custody-missing:{path}")
    fixtures = {
        name: json.loads((ROOT / "test/fixture" / name).read_text(encoding="utf-8"))
        for name in ("release_unverified", "release_protocol_unverified", "release_verified")
    }
    require(fixtures["release_unverified"]["expected"] == "PromotionRefused:RuntimeEvidenceMissing", "runtime-refusal-fixture")
    require(fixtures["release_protocol_unverified"]["expected"] == "PromotionRefused:ProtocolEvidenceMissing", "protocol-refusal-fixture")
    require(fixtures["release_verified"]["expected"] == "advance", "verified-fixture")
    return {
        "name": "phase0-custody", "command": "read test/oracle/preimplementation_artifacts.tsv",
        "output": "12 oracles; 8 mutants", "result": "PASS",
    }


def derive_ledger() -> dict[str, Any]:
    surfaces = [
        line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]
    ledger: dict[str, Any] = {
        "phase": 39,
        "gate_command": "python3 tools/release_lifecycle_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
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


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schemaVersion") == "amoebius.phase39.release-lifecycle-live.v1", "live-schema")
    require(live.get("sealed") is True and live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate-seal")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable), "live-evidence-digest")
    require(live.get("releaseHash") == (ROOT / "test/golden/release_hash.txt").read_text(encoding="utf-8").strip(), "release-hash-golden")
    require(live.get("independentHashTool") == "python hashlib.sha256 over frozen newline-delimited preimage", "independent-hash-tool")

    rounds = live.get("rounds", [])
    require([row.get("logicalNamespace") for row in rounds] == ["run-a", "run-b"], "run-namespace-domain")
    require(all(row.get("cacheBypassedIndependentHashRecompute") is True for row in rounds), "cache-bypass-recompute")
    for row in rounds:
        store = row.get("store", {})
        require((store.get("firstPut"), store.get("duplicatePut"), store.get("alteredPut")) == (200, 412, 412), "release-immutability-protocol")
        require(store.get("unverifiedRefusal") == "PromotionRefused:RuntimeEvidenceMissing", "runtime-specific-refusal")
        require(store.get("unverifiedHeadUnchanged") is True, "unverified-pointer-effect")
        require(store.get("winnerStatus") == 200 and store.get("staleLoserStatus") == 412, "pointer-cas-protocol")
        require(store.get("staleLoserReReadWinner") is True and store.get("sameReleaseAcrossEnvironments") is True, "pointer-cas-state")
        rollout = row.get("rollout", {})
        apply_order = rollout.get("externalApplyOrder", [])
        require([entry.get("condition") for entry in apply_order] == [
            "deployment/release-lifecycle-base:Available",
            "job/release-lifecycle-migrate:Complete+sql-copy:verified",
            "deployment/release-lifecycle-final:Available+old-schema:retired",
        ], "external-apply-order")
        versions = [int(entry["resourceVersion"]) for entry in apply_order]
        require(versions == sorted(versions) and len(set(versions)) == 3, "external-resource-version-order")
        require(all(entry.get("fieldManager") == "amoebius-phase39" for entry in apply_order), "ssa-field-manager")
        require(rollout.get("migratedRowsEqualOracle") is True, "migration-row-oracle")
        require(rollout.get("retiredOldSchemaRowsRetained") is True, "old-schema-retained")
        require(rollout.get("retireDenotesDurableByteDeletion") is False, "retire-byte-destruction")

    provision = live.get("provision", {})
    require(provision.get("structuralTerms") == [
        "old-schema", "new-schema", "row-data", "copy-wal", "verification-wal",
        "workspace", "executor", "old-workload", "new-workload", "total",
    ], "migration-structural-domain")
    require(provision.get("exactFit") is True and provision.get("everyOneShortRefusedBeforeEffect") is True, "migration-fit-domain")
    require(provision.get("failureRetainedBytes") == 210 and provision.get("callerScalarPeakAccepted") is False, "migration-retention-scalar")

    cleanup = live.get("cleanup", {})
    require(cleanup.get("providers") == {"KubernetesApi": True, "Minio": True, "Postgres": True}, "cleanup-provider-domain")
    require(cleanup.get("residue") == [] and cleanup.get("inventoriesEqualRetainedSet") is True, "cleanup-residue")
    require(live.get("evidenceLedger") == [
        {"layer": "Decision", "status": "tested"},
        {"layer": "Protocol", "status": "tested"},
        {"layer": "Runtime", "status": "tested", "never": "proven"},
    ], "evidence-ledger-domain")
    require(live.get("typeForeclosure") == {"promoteUnverifiedToProd": "proven-in-types", "liveWiring": "tested"}, "type-foreclosure-honesty")
    require(set(live.get("unverified", [])) == {
        "Gateway API canary weight shift", "Pulsar consumer group cutover", "cross-cluster and geo promotion",
    }, "unverified-domain")
    require(live.get("universalLinuxCpu") == {
        "allHardwareSubstrates": True,
        "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
    }, "universal-linux-cpu-and-pristine-routing")
    serialized = LIVE.read_text(encoding="utf-8")
    require("resultChallenge" not in serialized and "stateFile" not in serialized and "clientSecret" not in serialized, "secret-challenge-custody")
    require(not re.search(r'"challenge"\s*:', serialized), "raw-challenge-custody")


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
            CABAL, "build", "amoebius-release:lib:amoebius-release", "release-lifecycle-live", *disabled, "-j1", "-v0",
        ))]
        rows.append(phase0_domain())
        rows.append(compile_boundary())
        if args.reuse_fresh_live:
            rows.append({
                "name": "release-lifecycle-live", "command": "sealed just-produced Phase-40 live receipt",
                "output": "fresh final live evidence", "result": "PASS",
            })
        else:
            rows.append(invoke("release-lifecycle-live", (
                CABAL, "test", "release-lifecycle-live", *disabled,
                "--test-show-details=direct", "-j1", "-v0",
            ), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(invoke("sealed-live-reader", (
            CABAL, "test", "release-lifecycle-live", *disabled,
            "--test-show-details=direct", "-j1", "-v0",
        ), extra_env={"RELEASE_LIFECYCLE_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", (
            CABAL, "test", "release-lifecycle-live", *disabled,
            "--test-show-details=direct", "-j1", "-v0",
        ), extra_env={"RELEASE_LIFECYCLE_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (
            sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION),
        )))
        stable = {
            "schema": "amoebius.phase39.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "releaseHash": json.loads(LIVE.read_text(encoding="utf-8"))["releaseHash"],
            "rounds": 2, "environmentPointers": ["Dev", "Staging", "Prod"],
            "rolloutPhases": ["base-apply", "schema-migration", "finalize"],
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
            ) + f"\nPHASE-39-GATE PASS {derived['ledger_hash']}\n",
            encoding="utf-8",
        )
        print(f"release-lifecycle-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"release-lifecycle-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
