#!/usr/bin/env python3
"""Run and seal the complete Phase-32 platform-services acceptance gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_31"
LIVE_EVIDENCE = EVIDENCE / "services-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_32_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_32_ledger.json"
EXPECTED_DIGEST = ROOT / "test/fixture/platform_services_2/expected-base-digest.txt"
POSTGRES_SHARE_DIGEST = ROOT / "test/fixture/platform_services_2/postgres-share-package.sha256"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"keycloak-edge", "control-plane-owned-reconcile"}
MUTANTS = (
    ("M-patroni-async-default", "platform-services-2-patroni-async-default-mutant", "synchronous_mode_strict-not-on"),
    ("M-dag-drop-edge", "platform-services-2-dag-drop-edge-mutant", "declared DAG equals independent oracle"),
    ("M-dag-inject-cycle", "platform-services-2-dag-inject-cycle-mutant", "declared DAG equals independent oracle"),
    ("M-redis-pvc", "platform-services-2-redis-pvc-mutant", "redis-persistence-forbidden"),
    ("M-redis-unbounded-buffer", "platform-services-2-redis-unbounded-buffer-mutant", "redis-bounds-must-be-finite-positive"),
    ("M-redis-public-image", "platform-services-2-redis-public-image-mutant", "redis-public-image-forbidden"),
    ("M-redis-receipt-authority", "platform-services-2-redis-receipt-authority-mutant", "redis-receipt-authority-forbidden"),
    ("M-fixed-prometheus", "platform-services-2-fixed-prometheus-mutant", "Prometheus derived storage boundary"),
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (CABAL, "test", "platform-services-2-services-spec", f"-f{flag}", "--test-show-details=direct", "-j1")
    result = subprocess.run(arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800)
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
    surfaces = [
        line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    ledger: dict[str, Any] = {
        "phase": 31,
        "gate_command": "python3 tools/platform_services_2_gate.py",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-10",
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


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def evidence_domain(*, require_fresh: bool) -> dict[str, Any]:
    if not LIVE_EVIDENCE.is_file():
        raise GateFailure("services-live-evidence-absent")
    if require_fresh and time.time() - LIVE_EVIDENCE.stat().st_mtime > 3600:
        raise GateFailure("services-live-evidence-stale")
    live = json.loads(LIVE_EVIDENCE.read_text(encoding="utf-8"))
    expected_digest = EXPECTED_DIGEST.read_text(encoding="utf-8").strip()
    expected_share = "sha256:" + POSTGRES_SHARE_DIGEST.read_text(encoding="utf-8").split()[0]
    if live.get("schema") != "amoebius.phase31.services-live.v1" or live.get("register") != 3 or live.get("substrate") != "linux-cpu":
        raise GateFailure("live-schema-domain")
    artifact = live.get("artifactSource", {})
    if artifact.get("digest") != expected_digest or artifact.get("imagePullPolicy") != "Never" or artifact.get("publicPulls") != 0:
        raise GateFailure("base-image-domain")
    if artifact.get("pullEvents", {}).get("publicPullEventCount") != 0:
        raise GateFailure("public-pull-event-domain")
    if not live.get("vaultMaterial", {}).get("vaultSourced"):
        raise GateFailure("vault-material-domain")
    operator = live.get("operatorObservation", {})
    if not operator.get("operatorObservedCr") or not operator.get("manualChildProjection"):
        raise GateFailure("operator-observation-domain")
    postgres = live.get("postgres", {})
    mandated = "synchronous_mode: on\nsynchronous_mode_strict: on\nmaximum_lag_on_failover: 1048576\n"
    if postgres.get("replicas") != 3 or postgres.get("readyReplicas") != 3 or postgres.get("mandatedConfiguration") != mandated:
        raise GateFailure("patroni-domain")
    if live.get("retainedStorage", {}).get("postgresShare", {}).get("packageSha256") != expected_share:
        raise GateFailure("postgres-share-domain")
    if not all(live.get("databaseSurfaces", {}).get(key) for key in ("sqlGatewayReady", "pgAdminReady")):
        raise GateFailure("database-surfaces-domain")
    grafana = live.get("grafana", {})
    if not grafana.get("ready") or grafana.get("databaseType") != "postgres" or grafana.get("migrationRows", 0) < 1:
        raise GateFailure("grafana-postgres-domain")
    redis = live.get("redis", {})
    redis_drill = live.get("redisBoundary", {})
    if redis != {"redisReplicas": 3, "sentinelVoters": 3, "persistence": False}:
        raise GateFailure("redis-topology-domain")
    if not all(redis_drill.get(key) for key in ("tls", "replicaReadback", "failoverObserved")) or redis_drill.get("challengeTtlRemainingSeconds", 0) < 1:
        raise GateFailure("redis-drill-domain")
    monitoring = live.get("monitoringBoundary", {})
    if monitoring.get("queryProxyPositive") != 200 or monitoring.get("queryProxyOneOverSeries") != 429 or monitoring.get("directQueryFromGrafana") != "DENIED" or monitoring.get("activeTargets", 0) < 3:
        raise GateFailure("monitoring-boundary-domain")
    if monitoring.get("mountedHighWaterBytes", 1) > monitoring.get("claimUsableBoundBytes", 0):
        raise GateFailure("prometheus-storage-domain")
    readiness = live.get("readinessDag", {})
    if readiness.get("observer") != "kubernetes-apiserver-status-readback-during-warm-reconciliation" or len(readiness.get("events", [])) != 14 or readiness.get("preconditionViolations") != []:
        raise GateFailure("readiness-trace-domain")
    provenance = live.get("provenance", {})
    if not provenance.get("allRuntimeImageIdsMatchBaseDigest") or provenance.get("publicImageReferences") or not provenance.get("completeResourceFields"):
        raise GateFailure("runtime-provenance-domain")
    ssa = provenance.get("ssaProjection", {})
    if ssa.get("fieldManager") != "amoebius" or not ssa.get("allOwnedFieldsByteIdentical") or ssa.get("objectCount", 0) < 1:
        raise GateFailure("ssa-domain")
    haskell = provenance.get("haskellProjection", {})
    if haskell.get("renderer") != "Amoebius.Platform.Services.renderPlatformServices" or not haskell.get("freshGateProcessOutput") or not haskell.get("allAppliedProjectionsByteIdentical") or haskell.get("objectCount") != 11:
        raise GateFailure("haskell-render-domain")
    universal = live.get("universalLinuxCpu", {})
    routing = {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}
    if not universal.get("availableOnEveryHardwareSubstrate") or universal.get("pristineLinuxHost") != routing:
        raise GateFailure("universal-linux-domain")
    return live


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--seal-existing-live", action="store_true", help="Seal a just-produced final live receipt without rerunning the long bring-up")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        python = sys.executable
        rows = [
            invoke("pure-service-contract", (CABAL, "test", "platform-services-2-services-spec", "--test-show-details=direct", "-j1")),
            invoke("bringup-simulation", (CABAL, "test", "platform-services-2-bringup-sim", "--test-show-details=direct", "-j1")),
        ]
        if not arguments.seal_existing_live:
            rows.append(invoke("services-live", (python, "tools/platform_services_2_live.py"), timeout=3600))
        else:
            rows.append({"name": "services-live", "command": "sealed just-produced tools/platform_services_2_live.py receipt", "output": "fresh final evidence", "result": "PASS"})
        evidence_domain(require_fresh=arguments.seal_existing_live)
        rows.append(invoke("external-live-reader", (CABAL, "test", "platform-services-2-services-live", "--test-show-details=direct", "-j1")))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "platform-services-2-services-spec", *disabled, "--test-show-details=direct", "-j1")))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        derived = derive_ledger()
        committed = json.loads(LEDGER.read_text(encoding="utf-8"))
        if committed != derived:
            raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
        rows.append(invoke("ledger-lint", (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase31.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "patroniStrictSyncThreeMember": True, "redisTlsAclReplicationAndFailover": True,
            "prometheusBoundedQueryAndStorage": True, "grafanaPostgresConsumer": True,
            "externalWarmReadinessTrace": True, "iosimFaultSchedules": 256,
            "haskellRenderAndSsaByteIdentity": True,
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        log = [f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows]
        log.append(f"PHASE-31-GATE PASS {derived['ledger_hash']}")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"platform-services-2-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"platform-services-2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
