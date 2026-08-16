#!/usr/bin/env python3
"""Run and seal the scoped Phase-49 infernix artifact-lift gate."""

from __future__ import annotations

import argparse
import csv
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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_49"
LIVE = EVIDENCE / "infernix-artifact-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_49_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_49_ledger.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
KUBECTL = "/usr/bin/kubectl"
FLAGS = (
    "phase49-drop-artifact-scope-mutant", "phase49-mint-ready-before-pointer-commit-mutant",
    "phase49-use-wallclock-seed-mutant", "phase49-regenerate-command-id-mutant",
)
MUTANTS = {
    "phase49-drop-artifact-scope-mutant": "mut-49-drop-artifact-scope",
    "phase49-mint-ready-before-pointer-commit-mutant": "mut-49-mint-ready-before-pointer-commit",
    "phase49-use-wallclock-seed-mutant": "mut-49-use-wallclock-seed",
    "phase49-regenerate-command-id-mutant": "mut-49-regenerate-command-id",
}
UNVERIFIED = {
    "production-tinyllama-weights-inference", "cross-substrate-bit-equality", "general-noninterference",
    "worker-direct-minio-linked-artifact-fetch", "full-sibling-inference-engine-core",
    "pulsar-command-to-worker-direct-causality", "vault-credential-used-by-worker",
}
MODEL = b"phase49-tiny-decoder-v1|vocab=amoebius,deterministic,artifact,ready|weights=3,1,4,1,5,9"
MODEL_SHA = "88dd6c952aba749884eb842494177646d0f77be0ae2d6998f5c69fe3d22551fa"
GOLDEN = "8d5690c448187e549b5d0eda0957d35e0a982f4660673665fefc6c897b92ba49\n"
LINKED_SIBLING_SHA = "4f8bfc257c80eedaf94a649d41db744b5221d9af60f6919be127ce02bda380db"


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
    stable = dict(value)
    stable.pop("ledger_hash", None)
    return fingerprint(stable)


def invoke(name: str, arguments: Sequence[str], *, timeout: int = 1800) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    require(result.returncode == 0, f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(("-f" if flag == enabled else "-f-") + flag for flag in FLAGS)


def contract_args(enabled: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "infernix-core-artifact-lift-contract", "-w", GHC, *flags(enabled), "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(flag: str, marker: str) -> dict[str, str]:
    arguments = contract_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0 and marker in result.stdout, f"{marker}:green-or-wrong-locus:{result.stdout}")
    return {"name": marker, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def load_dhall(path: str) -> Any:
    result = subprocess.run((DHALL_TO_JSON, "--file", path), cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120)
    require(result.returncode == 0, f"dhall:{path}:{result.stdout}")
    return json.loads(result.stdout)


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("49\t")]
    require(len(rows) == 12, "phase0-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 8 and sum("\tmutant\t" in row for row in rows) == 4, "phase0-kind-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-missing:{path}")
    return {"name": "phase0-custody", "command": "read Phase-49 manifest rows", "output": "8 oracles; 4 mutants", "result": "PASS"}


def decode_cbor_text(path: Path) -> str:
    payload = path.read_bytes()
    require(len(payload) >= 2 and payload[0] == 0x78 and payload[1] == len(payload) - 2, f"cbor-text-shape:{path}")
    return payload[2:].decode()


def oracle_domain() -> dict[str, str]:
    base = load_dhall("test/dhall/phase_49/infernix_core_artifact_lift.dhall")
    short = load_dhall("test/dhall/phase_49/cpu_budget_one_short.dhall")
    config = load_dhall("infernix/dhall/infernix.dhall")
    require(base["substrate"] == "linux-cpu" and base["register"] == 3 and base["seed"] == 1 and base["modelBytes"] == len(MODEL) == 87, "dhall-base")
    require(base["modelDigest"] == "sha256:" + MODEL_SHA and hashlib.sha256(MODEL).hexdigest() == MODEL_SHA, "model-digest")
    require(short["expectedTag"] == "CpuInferenceMemoryUnderReserved" and short["provided"]["memoryMiB"] + 1 == short["required"]["memoryMiB"] and short["effectsBeforeRefusal"] == 0, "one-short")
    # dhall-to-json omits Optional/None fields, so custody the Dhall source as well as the decoded absence.
    base_source = (ROOT / "test/dhall/phase_49/infernix_core_artifact_lift.dhall").read_text(encoding="utf-8")
    config_source = (ROOT / "infernix/dhall/infernix.dhall").read_text(encoding="utf-8")
    require("accelerator" not in base["cpuBudget"] and "accelerator" not in config["cpuBudget"] and "accelerator = None Text" in base_source and "accelerator = None Text" in config_source, "accelerator-none")
    routes = base["universalLinuxCpu"]
    require(routes["availableOnEveryHardwareSubstrate"] and routes["pristineLinux"] == {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}, "universal-linux-cpu")
    request = decode_cbor_text(ROOT / "test/fixtures/phase_49/request.cbor")
    golden = decode_cbor_text(ROOT / "test/fixtures/phase_49/sibling_golden.cbor")
    require("phase0-command-49" in request and golden == GOLDEN, "cbor-fixtures")
    expected = dict(csv.reader((ROOT / "test/fixtures/phase_49/expected_hashes.tsv").open(encoding="utf-8"), delimiter="\t"))
    expected.pop("name", None)
    require(expected["model"] == MODEL_SHA, "expected-model-hash")
    request_preimage = b"phase49-request-v1|tenant=tenant-a|command=phase0-command-49|nonce=phase0-nonce-49|seed=0000000000000001|input=explain content addressing"
    decode_preimage = MODEL + b"|explain content addressing|0000000000000001"
    require(expected["request-preimage"] == hashlib.sha256(request_preimage).hexdigest() and expected["decode-preimage"] == hashlib.sha256(decode_preimage).hexdigest() == GOLDEN.strip(), "preimage-hashes")
    frozen = []
    for line in (ROOT / "test/fixtures/phase_49/frozen_sources.txt").read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            relative, digest = line.split("\t")
            require(hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == digest, f"frozen-source:{relative}")
            frozen.append(relative)
    require(len(frozen) == 4, "frozen-cardinality")
    linked = ROOT / "../infernix/src/Infernix/Topic/Metadata.hs"
    require(hashlib.sha256(linked.read_bytes()).hexdigest() == LINKED_SIBLING_SHA and "Infernix.Topic.Metadata" in (ROOT / "infernix/infernix-lift.cabal").read_text(encoding="utf-8"), "linked-sibling-module")
    commands = list(csv.DictReader((ROOT / "test/fixtures/phase_49/command_identity_matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    artifacts = list(csv.DictReader((ROOT / "test/fixtures/phase_49/artifact_scope_readiness_matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["expected"] for row in commands] == ["new-ready-handle", "original-ready-handle", "IdempotencyConflict", "ArtifactUnavailable"], "command-matrix")
    require([row["expected"] for row in artifacts] == ["ReadyArtifactHandle", "ArtifactUnavailable", "ArtifactNotReady", "ArtifactNotReady"], "artifact-matrix")
    return {"name": "independent-oracles", "command": "Dhall/CBOR/TSV/source oracle validation", "output": "catalog, budget, identities, scopes, sources valid", "result": "PASS"}


def foreclosure_domain() -> list[dict[str, str]]:
    prefix = (CABAL, "exec", "-w", GHC, "--", GHC, "-XGHC2024", "-fno-code", "-iinfernix/src")
    rows = [invoke("catalog-positive", (*prefix, "test/compile-fail/phase_49_catalog_positive.hs"), timeout=300)]
    negatives = {
        "forge-ready-handle-red": ("test/compile-fail/phase_49_forge_ready_handle.hs", "ReadyArtifactHandle"),
        "free-url-engine-red": ("test/compile-fail/phase_49_url_engine_arm.hs", "Url"),
    }
    for name, (path, locus) in negatives.items():
        arguments = (*prefix, path)
        result = subprocess.run(arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=300)
        require(result.returncode != 0 and locus in result.stdout, f"{name}:wrong-locus:{result.stdout}")
        rows.append({"name": name, "command": shlex.join(arguments), "output": locus, "result": "RED"})
    return rows


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    raw = LIVE.read_text(encoding="utf-8")
    live = json.loads(raw)
    stable = dict(live)
    digest = stable.pop("evidenceDigest", None)
    require(digest == fingerprint(stable, newline=True), "live-evidence-digest")
    require(live["schema"] == "amoebius.phase49.infernix-artifact-live.v1" and live["register"] == 3 and live["substrate"] == "linux-cpu" and live["result"] == "PASS-SCOPED", "live-schema")
    artifact = live["artifact"]
    require(artifact["catalogIdentity"] == "catalog/tinyllama-1.1b-cpu@sha256:" + MODEL_SHA and artifact["scope"] == "tenant-a" and artifact["readyPointerWrittenLast"] and artifact["precommitPointerAbsent"], "live-artifact")
    transport = live["transport"]
    require(transport["nativeTcp"] and transport["cbor"] and not transport["webSocket"] and transport["duplicateCommandCollapsed"] and transport["brokerIncomingCommandAttempts"] == 2 and transport["consumerCommandDeliveries"] == 1, "live-transport")
    require(transport["commandIdPreserved"] and transport["workIdEqualsCommandId"] and transport["noncePreserved"] and "PASS" in transport["driverReceipt"], "live-identity")
    inference = live["inference"]
    runs = inference["runs"]
    require(len(runs) == 2 and inference["distinctRunIds"] and inference["distinctPodUids"] and inference["byteIdentical"] and inference["matchesPhase0Golden"], "live-inference")
    require(len({row["podUid"] for row in runs}) == 2 and all(row["commandId"] == row["workId"] and row["nonce"] == live["challenge"]["nonce"] and row["experimentHash"] == inference["experimentHash"] and row["output"] == GOLDEN.strip() and row["resultKeyInitiallyAbsent"] for row in runs), "live-run-correspondence")
    require([row["cacheStatus"] for row in runs] == ["MISS", "HIT"] and live["engineCache"]["materializations"] == 1 and live["engineCache"]["publicRegistryEvents"] == 0, "live-cache")
    authorization = live["authorization"]
    require(authorization["vaultSecretRefsOnly"] and authorization["oneUseTokensIssued"] == 2 and authorization["tenantBReadTenantAStatus"] == 403 and authorization["vaultAuditDelta"] > 0 and authorization["directMinioStatus"] == 403 and authorization["directPulsarStatus"] in {404, 405, 500} and not authorization["credentialProviderAuthority"], "live-authorization")
    denials = live["denials"]
    require({key: value["tag"] for key, value in denials.items()} == {"foreignScope": "ArtifactUnavailable", "precommit": "ArtifactNotReady", "oneShortBudget": "CpuInferenceMemoryUnderReserved", "changedInput": "IdempotencyConflict"}, "live-denials")
    require(all(value == 0 for row in denials.values() for key, value in row.items() if key.endswith("Delta")), "live-denial-zero-effects")
    budget = live["resources"]["budget"]
    require(budget == {"threads": 2, "concurrency": 1, "maxInputTokens": 64, "maxOutputTokens": 16, "retries": 1, "bufferBytes": 4096, "cpuMilli": 500, "memoryMiB": 256, "ephemeralMiB": 64, "cacheMiB": 96, "accelerator": None}, "live-budget")
    require(live["frozenSources"]["count"] == 4 and live["frozenSources"]["unchanged"], "live-frozen")
    require(live["universalLinuxCpu"] == {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "live-universal")
    require(live["honesty"] == {"linkedHaskellAdapterContract": "TESTED", "retainedServiceIntegration": "TESTED", "productionTinyLlamaInference": "UNVERIFIED", "crossSubstrateBitEquality": "UNVERIFIED", "generalNoninterference": "UNVERIFIED"}, "live-honesty")
    require(all(live["cleanup"].values()), "live-cleanup")
    require(not re.search(r"(?i)(root_token|client_token|secretAccessKey|privateKey|unseal_key|X-Vault-Token)", raw), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    namespace = subprocess.run((KUBECTL, "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "namespace", "phase49-system"), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60)
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(namespace.returncode != 0 and clusters == ["amoebius-bootstrap-coordinator"], f"external-residue:{namespace.stdout}:{clusters}")
    return {"name": "external-cleanup-readback", "command": "namespace and kind inventories", "output": "no Phase-49 namespace; only retained amoebius-bootstrap-coordinator remains", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 49, "gate_command": "python3 tools/phase49_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"}, {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
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
        rows = [invoke("phase49-source-build", (CABAL, "build", "infernix-lift:lib:infernix-lift", "phase49-native-driver", "-w", GHC, *flags(), "-j1", "-v0"))]
        rows.append({"name": "linked-sibling-source", "command": "sha256 sibling Infernix.Topic.Metadata", "output": LINKED_SIBLING_SHA, "result": "PASS"})
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.extend(foreclosure_domain())
        rows.append(invoke("infernix-core-artifact-lift-contract", contract_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "infernix-artifact-live", "command": "sealed just-produced Phase-49 live receipt", "output": "fresh retained Kubernetes/MinIO/Pulsar/Vault/cache evidence", "result": "PASS"})
        else:
            rows.append(invoke("infernix-artifact-live", (sys.executable, "tools/phase49_infernix_artifact_live.py"), timeout=2400))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        live_reader = (CABAL, "test", "infernix-core-artifact-lift-live-gate", "-w", GHC, "--test-show-details=direct", "-j1", "-v0")
        rows.append(invoke("sealed-live-reader", live_reader))
        for flag, marker in MUTANTS.items():
            rows.append(reject_mutant(flag, marker))
        rows.append(invoke("baseline-restored-contract", contract_args()))
        rows.append(invoke("baseline-restored-live-reader", live_reader))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase49.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "modelFixtureDigest": "sha256:" + MODEL_SHA, "nativeCbor": "TESTED", "scopedReadyArtifact": "TESTED",
            "productionTinyLlamaInference": "UNVERIFIED", "crossSubstrateBitEquality": "UNVERIFIED",
            "mutantsRed": list(MUTANTS.values()), "result": "PASS-SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-49-GATE PASS-SCOPED {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"phase49-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; production TinyLlama/cross-substrate/full causal chain UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase49-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
