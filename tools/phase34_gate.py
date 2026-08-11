#!/usr/bin/env python3
"""Run and seal the Phase-34 tenant/provider provisioning gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_34"
LIVE = EVIDENCE / "tenant-provider-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_34_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_34_ledger.json"
ORACLE = ROOT / "test/fixtures/phase_34/provider_projection_matrix.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"application-data-path-isolation", "real-user-credential-enforcement", "tenant-admin-scope-narrowing"}
MUTANTS = (
    ("M-drop-provider-arm", "phase34-drop-provider-arm-mutant", "provider-arm-incomplete:Pulsar"),
    ("M-collapse-tenant-key", "phase34-collapse-tenant-key-mutant", "tenant-key-collapse"),
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
    arguments = (CABAL, "test", "tenant-provider-provisioning-live", *flags, "--test-show-details=direct", "-j1")
    environment = os.environ.copy()
    environment["PHASE34_REUSE_FRESH_LIVE"] = "1"
    result = subprocess.run(arguments, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800)
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 34,
        "gate_command": "python3 tools/phase34_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-10",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"}, {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def require(value: bool, tag: str) -> None:
    if not value:
        raise GateFailure(tag)


def evidence_domain(*, fresh: bool) -> dict[str, Any]:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schemaVersion") == "amoebius.phase34.live-evidence.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    oracle_hash = "sha256:" + hashlib.sha256(ORACLE.read_bytes()).hexdigest()
    require(live.get("oracleSha256") == oracle_hash, "oracle-digest")
    providers = live.get("providers", [])
    expected_types = {
        "Keycloak": {"RealmRole", "GroupRoleMapping"}, "Vault": {"AclPolicy"},
        "Pulsar": {"NamespacePolicy"}, "Minio": {"BucketPolicy"},
        "KubernetesApi": {"Namespace", "NetworkPolicy"}, "Postgres": {"Role", "Schema"},
    }
    require(len(providers) == 12, "provider-observation-count")
    for provider, object_types in expected_types.items():
        rows = [row for row in providers if row.get("provider") == provider]
        require(len(rows) == 2 and len({row.get("tenant") for row in rows}) == 2, f"provider-tenants:{provider}")
        require(all(set(row.get("objectTypes", [])) == object_types for row in rows), f"provider-types:{provider}")
        require(all(row.get("challengeRecovered") and str(row.get("rawObservationSha256", "")).startswith("sha256:") for row in rows), f"provider-challenge:{provider}")
    observers = live.get("observers", [])
    require(len(observers) == 6 and len({row.get("identity") for row in observers}) == 6, "observer-cardinality")
    require({row.get("observerProvider") for row in observers} == set(expected_types), "observer-provider-set")
    require(all(row.get("authenticated") and not row.get("credentialReused") for row in observers), "observer-authority-separation")
    rejected = live.get("rejectedTwins", [])
    require({row.get("tag") for row in rejected} == {"hand-authored-provider-grant", "tenant-reference-mismatch"}, "rejected-twin-tags")
    require(all(row.get("providerEffects") == 0 and row.get("forbiddenNonceAbsentAllProviders") for row in rejected), "rejected-twin-effects")
    require([row.get("result") for row in live.get("bypassProbes", [])] == ["rejected-before-provision", "rejected-before-provision", "no-constructor"], "bypass-probes")
    cleanup = live.get("cleanup", {})
    require(cleanup.get("inventoriesEqual") and cleanup.get("residue") == [] and cleanup.get("preflightSha256") == cleanup.get("postflightSha256"), "cleanup")
    universal = live.get("universalLinuxCpu", {})
    require(universal.get("allHardwareSubstrates") is True, "universal-linux-cpu")
    require(universal.get("pristineLinux") == {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}, "pristine-linux-routing")
    require(live.get("applicationDataPath") == "UNVERIFIED (Phase 36)", "application-isolation-honesty")
    return live


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
        rows = [invoke("source-build", (CABAL, "build", "tenant-provider-provisioning-live", "-j1"))]
        if args.reuse_fresh_live:
            rows.append({"name": "provider-live", "command": "sealed just-produced Phase-34 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("provider-live", (python, "tools/phase34_tenant_provider_live.py"), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(invoke("sealed-live-reader", (CABAL, "test", "tenant-provider-provisioning-live", "--test-show-details=direct", "-j1"), extra_env={"PHASE34_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "tenant-provider-provisioning-live", *disabled, "--test-show-details=direct", "-j1"), extra_env={"PHASE34_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase34.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "twoTenantSixProviderProjection": True, "observerAuthoritiesSeparated": True,
            "illegalTwinsZeroEffect": True, "cleanupInventoriesEqual": True,
            "applicationDataPath": "UNVERIFIED (Phase 36)",
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-34-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"phase34-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase34-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
