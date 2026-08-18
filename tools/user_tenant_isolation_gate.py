#!/usr/bin/env python3
"""Run and seal the Phase-36 subject/tenant isolation gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_36"
LIVE = EVIDENCE / "user-tenant-isolation-live.json"
MATRIX = ROOT / "test/fixture/live_isolation/user_tenant_access_matrix.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_36_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_36_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"browser-tenant-switching", "cross-cluster-isolation", "complete-provider-audit-log-correspondence"}
MUTANTS = (
    ("M-drop-user-predicate", "user-tenant-isolation-drop-user-predicate-mutant", "matrix-mismatch:deny-same-tenant-foreign-subject"),
    ("M-accept-body-tenant", "user-tenant-isolation-accept-body-tenant-mutant", "matrix-mismatch:allow-body-tenant-ignored"),
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


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    flags = [f"-f{'-' if candidate != flag else ''}{candidate}" for _, candidate, _ in MUTANTS]
    arguments = (CABAL, "test", "user-tenant-isolation-live", *flags, "--test-show-details=direct", "-j1")
    environment = os.environ.copy()
    environment["USER_TENANT_ISOLATION_REUSE_FRESH_LIVE"] = "1"
    result = subprocess.run(arguments, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800)
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    return "sha256:" + hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 36,
        "gate_command": "python3 tools/user_tenant_isolation_gate.py --reuse-fresh-live",
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
    require(live.get("schemaVersion") == "amoebius.phase36.user-tenant-isolation.v1" and live.get("sealed") is True, "live-schema-seal")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    require(live.get("matrixDigest") == "sha256:" + hashlib.sha256(MATRIX.read_bytes()).hexdigest(), "matrix-digest")
    authority = live.get("authority", {})
    require(authority.get("realCredentialCount") == 3 and authority.get("source") == "Keycloak token endpoint plus authenticated introspection", "real-authority")
    introspections = authority.get("observer", {}).get("activeIntrospections", {})
    require(set(introspections) == {"alice-a", "bob-a", "carol-b"} and all(value.get("active") for value in introspections.values()), "introspection-domain")
    require({value.get("tenant") for value in introspections.values()} == {"t-a", "t-b"}, "introspection-tenants")
    providers = live.get("providers", {})
    postgres = providers.get("Postgres", {})
    require(postgres.get("rls") is True and len(postgres.get("observerRows", [])) == 2 and postgres.get("forbiddenVersions") == 0, "postgres-rls-observer")
    require(all("forbidden" not in row for row in postgres.get("observerRows", [])), "postgres-forbidden-nonce")
    minio = providers.get("Minio", {})
    require(len(minio.get("derivedKeys", [])) == 2 and minio.get("forbiddenKeys") == 0 and minio.get("directBearerStatus") == 403, "minio-isolation")
    pulsar = providers.get("Pulsar", {})
    require(pulsar.get("forbiddenEntries") == 0 and pulsar.get("forbiddenCursorAdvances") == 0, "pulsar-forbidden-effect")
    require(len(pulsar.get("rows", [])) == 2 and all(row.get("messageInCounter") == row.get("messageOutCounter") == row.get("persistedEntries") == 1 for row in pulsar.get("rows", [])), "pulsar-native-rounds")
    bypass = live.get("bypass", {})
    network = bypass.get("foreignPodCni", {})
    require(bypass.get("forgedTenantHeaderIgnored") and bypass.get("swappedHandleDenied") and bypass.get("directKeycloakCredentialProviderAuthority") is False, "request-bypass")
    require(network.get("policyEnforced") is True and all(network.get("sutReachability", {}).values()) and not any(network.get("foreignReachability", {}).values()), "cni-bypass")
    public = live.get("publicDenial", {})
    require(public == {"status": 404, "body": "resource-unavailable", "foreignChallengeDisclosed": False}, "public-denial")
    cleanup = live.get("cleanup", {})
    require(cleanup.get("inventoriesEqual") is True and cleanup.get("residue") == [] and all(cleanup.get("providers", {}).values()), "cleanup")
    provision = live.get("provision", {})
    require(provision.get("exactFit") is True and provision.get("oneShortTerms") == 10 and provision.get("livePodResourcesNormalized") is True, "provision")
    universal = live.get("universalLinuxCpu", {})
    require(universal.get("allHardwareSubstrates") is True, "universal-linux-cpu")
    require(universal.get("pristineLinux") == {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}, "pristine-linux-routing")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable), "evidence-digest")
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
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows = [invoke("source-build", (CABAL, "build", "user-tenant-isolation-live", *disabled, "-j1"))]
        if args.reuse_fresh_live:
            rows.append({"name": "isolation-live", "command": "sealed just-produced Phase-36 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("isolation-live", (CABAL, "test", "user-tenant-isolation-live", *disabled, "--test-show-details=direct", "-j1"), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(invoke("sealed-live-reader", (CABAL, "test", "user-tenant-isolation-live", *disabled, "--test-show-details=direct", "-j1"), extra_env={"USER_TENANT_ISOLATION_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "user-tenant-isolation-live", *disabled, "--test-show-details=direct", "-j1"), extra_env={"USER_TENANT_ISOLATION_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {"schema": "amoebius.phase36.receipt.v1", "register": 3, "substrate": "linux-cpu", "realKeycloakCredentials": 3, "providers": ["Postgres", "Minio", "Pulsar"], "forbiddenEffects": 0, "cniBypassBlocked": True, "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS"}
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-36-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"user-tenant-isolation-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"user-tenant-isolation-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
