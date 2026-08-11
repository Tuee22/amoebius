#!/usr/bin/env python3
"""Run and seal the complete Phase-30 platform-backbone acceptance gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_30"
LIVE_EVIDENCE = EVIDENCE / "backbone-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_30_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_30_ledger.json"
EXPECTED_DIGEST = ROOT / "test/fixtures/phase30/expected-base-digest.txt"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"keycloak-edge", "phase31-postgres-observability", "singleton-owned-reconcile", "amoebius-pulsar-full-native-client"}
MUTANTS = (
    ("M-registry-fs-driver", "phase30-registry-fs-driver-mutant", "registry uses MinIO S3 driver"),
    ("M-offload-time-only", "phase30-offload-time-only-mutant", "size-triggered-offload-required"),
    ("M-storage-logical-as-physical", "phase30-logical-as-physical-mutant", "MinIO physical geometry amplifies logical bytes"),
    ("M-storage-drop-fault-scenario", "phase30-drop-fault-scenario-mutant", "MinIO fault scenarios complete"),
    ("M-storage-sum-ordinals", "phase30-sum-ordinals-mutant", "uniform MinIO drive debit"),
    ("M-content-immediate-gc", "phase30-content-immediate-gc-mutant", "failed-write orphan horizon retained"),
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    environment.pop("PHASE30_DEV_OFFLOADERS", None)
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (CABAL, "test", "phase30-backbone-spec", f"-f{flag}", "--test-show-details=direct", "-j1")
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
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.lstrip().startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 30,
        "gate_command": "python3 tools/phase30_gate.py",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-10",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def evidence_domain(*, require_fresh: bool) -> dict[str, Any]:
    if not LIVE_EVIDENCE.is_file():
        raise GateFailure("backbone-live-evidence-absent")
    if require_fresh and time.time() - LIVE_EVIDENCE.stat().st_mtime > 3600:
        raise GateFailure("backbone-live-evidence-stale")
    live = json.loads(LIVE_EVIDENCE.read_text(encoding="utf-8"))
    expected_digest = EXPECTED_DIGEST.read_text(encoding="utf-8").strip()
    artifact = live.get("artifactSource", {})
    if artifact.get("digest") != expected_digest or artifact.get("publicPulls") != 0:
        raise GateFailure("base-image-domain")
    if artifact.get("pullEvents", {}).get("publicPullEventCount") != 0:
        raise GateFailure("public-pull-event-domain")
    if not live.get("loadBalancer", {}).get("externallyReachable") or live.get("loadBalancer", {}).get("stableReadyObservations", 0) < 5:
        raise GateFailure("loadbalancer-domain")
    if live.get("minio", {}).get("topology") != "distributed-erasure-four-drive" or len(live.get("minio", {}).get("volumes", [])) != 4:
        raise GateFailure("minio-topology-domain")
    if not live.get("minioRoundtrip", {}).get("byteIdentical"):
        raise GateFailure("minio-roundtrip-domain")
    registry = live.get("registryRehome", {})
    if registry.get("backend") != "s3" or not registry.get("migration", {}).get("verified") or not registry.get("sourceHashStable"):
        raise GateFailure("registry-rehome-domain")
    pulsar = live.get("pulsar", {})
    if pulsar.get("zookeeper", {}).get("readyPods") != 3 or pulsar.get("bookkeeper", {}).get("readyPods") != 3 or pulsar.get("broker", {}).get("readyPods") != 2:
        raise GateFailure("pulsar-ha-domain")
    if pulsar.get("broker", {}).get("developmentOffloaderMount") or pulsar.get("broker", {}).get("bakedOffloaderFileCount", 0) < 1:
        raise GateFailure("development-offloader-mount-forbidden")
    drill = pulsar.get("drill", {})
    offload = drill.get("offload", {})
    if not all(drill.get(key) for key in ("nativeRoundtrip", "deduplicationExercised", "cborByteIdentical", "producerExited")):
        raise GateFailure("pulsar-native-domain")
    if "phase30-dedup-probe: PASS" not in drill.get("dedupProbeOutput", ""):
        raise GateFailure("dedup-probe-marker-domain")
    if offload.get("timeOnly") or not offload.get("bounded") or offload.get("objectCount", 0) < 1 or offload.get("hotTierBytes", 1) > offload.get("hotTierCapBytes", 0):
        raise GateFailure("pulsar-offload-domain")
    provenance = live.get("provenance", {})
    if not provenance.get("allRuntimeImageIdsMatchBaseDigest") or provenance.get("publicImageReferences") or not provenance.get("completeResourceFields"):
        raise GateFailure("runtime-provenance-domain")
    ssa = provenance.get("ssaProjection", {})
    if ssa.get("fieldManager") != "amoebius" or not ssa.get("allOwnedFieldsByteIdentical") or ssa.get("objectCount", 0) < 1:
        raise GateFailure("ssa-render-byte-identity-domain")
    haskell = provenance.get("haskellRenderProjection", {})
    if haskell.get("renderer") != "Amoebius.Platform.Backbone.renderBackbone" or not haskell.get("freshGateProcessOutput") or not haskell.get("allAppliedProjectionsByteIdentical") or haskell.get("objectCount") != 11:
        raise GateFailure("haskell-render-provenance-domain")
    universal = live.get("universalLinuxCpu", {})
    if not universal.get("availableOnEveryHardwareSubstrate") or universal.get("pristineLinuxHost") != {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}:
        raise GateFailure("universal-linux-domain")
    return live


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


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
        rows = [invoke("pure-backbone-contract", (CABAL, "test", "phase30-backbone-spec", "--test-show-details=direct", "-j1"))]
        if not arguments.seal_existing_live:
            rows.append(invoke("backbone-live", (python, "tools/phase30_backbone_live.py"), timeout=3600))
        else:
            rows.append({"name": "backbone-live", "command": "sealed just-produced tools/phase30_backbone_live.py receipt", "output": "fresh final evidence", "result": "PASS"})
        evidence_domain(require_fresh=arguments.seal_existing_live)
        rows.append(invoke("external-live-reader", (CABAL, "test", "phase30-backbone-live", "--test-show-details=direct", "-j1")))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "phase30-backbone-spec", *disabled, "--test-show-details=direct", "-j1")))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        derived = derive_ledger()
        committed = json.loads(LEDGER.read_text(encoding="utf-8"))
        if committed != derived:
            raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
        rows.append(invoke("ledger-lint", (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase30.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "externalVip": True, "fourDriveMinio": True, "registryS3Rehome": True,
            "pulsarHaNativeDedupAndOffload": True, "developmentOffloaderMount": False,
            "haskellRenderAndSsaByteIdentity": True,
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        log = [f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows]
        log.append(f"PHASE-30-GATE PASS {derived['ledger_hash']}")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"phase30-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase30-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
