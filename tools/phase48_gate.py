#!/usr/bin/env python3
"""Run and seal the Phase-48 determinism and JIT-cache gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_48"
LIVE = EVIDENCE / "determinism-jitcache-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_48_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_48_ledger.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
KUBECTL = "/usr/bin/kubectl"
FLAGS = (
    "phase48-content-order-leak-mutant", "phase48-const-fingerprint-mutant",
    "phase48-rng-workerid-mutant", "phase48-const-output-mutant",
    "phase48-fixed-marker-mutant", "phase48-prune-noop-mutant", "phase48-one-byte-short-mutant",
)
MUTANTS = {
    "phase48-content-order-leak-mutant": "mut-48-content-address-field-order-leak",
    "phase48-const-fingerprint-mutant": "mut-48-experiment-hash-const-fingerprint",
    "phase48-rng-workerid-mutant": "mut-48-rng-workerid-mixed",
    "phase48-const-output-mutant": "mut-48-determinism-const-output",
    "phase48-fixed-marker-mutant": "mut-48-cache-fixed-marker",
    "phase48-prune-noop-mutant": "mut-48-cache-prune-noop",
    "phase48-one-byte-short-mutant": "mut-48-cache-one-byte-short",
}
UNVERIFIED = {
    "cross-substrate-bit-equality", "cross-node-cache-reuse", "tier2-model-cache",
    "tier3-cuda-kernel-cache", "full-llama-cpp-production-payload",
}
ENGINE_DIGEST = "sha256:f0f27f013c07a69471b7b4603eb273f6be42e9ba39fe7a242fd1fd090cf28387"


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
    return (CABAL, "test", "determinism-jitcache-contract", "-w", GHC, *flags(enabled), "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(flag: str, marker: str) -> dict[str, str]:
    arguments = contract_args(flag)
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{marker}:green")
    return {"name": marker, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def load_dhall(path: str) -> Any:
    result = subprocess.run((DHALL_TO_JSON, "--file", path), cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120)
    require(result.returncode == 0, f"dhall:{path}:{result.stdout}")
    return json.loads(result.stdout)


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("48\t")]
    require(len(rows) == 42, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 23, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 19, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read Phase-48 manifest rows", "output": "23 oracles; 19 mutants", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    base = load_dhall("test/dhall/phase_48_determinism_repro.dhall")
    flipped = load_dhall("test/dhall/phase_48_determinism_repro_flipped_metric.dhall")
    alt_seed = load_dhall("test/dhall/phase_48_determinism_repro_alt_seed.dhall")
    alt_input = load_dhall("test/dhall/phase_48_determinism_repro_alt_input.dhall")
    cache = load_dhall("test/dhall/phase_48_engine_cache.dhall")
    require(base["substrate"] == "linux-cpu" and base["resolvedProgram"] != flipped["resolvedProgram"], "determinism-program-oracles")
    require(base["masterSeed"] != alt_seed["masterSeed"] and base["inputBytes"] != alt_input["inputBytes"], "determinism-negative-oracles")
    require(base["universalLinuxCpu"]["availableOnEveryHardwareSubstrate"] is True, "universal-linux-cpu")
    require(cache == {"cacheBudgetBytes": 160, "clientCount": 2, "emptyDirSizeLimitBytes": 192, "ephemeralRequestBytes": 224, "firstMissConcurrency": 2, "identity": "EngineRuntime.LlamaCppCpu@0.1.0", "ownerCount": 1, "resolveArms": ["build", "download"], "substrate": "linux-cpu", "writableAndLogHeadroomBytes": 32, "writableHostPath": False}, "cache-topology")

    engine = load_dhall("test/oracle/phase_48_oracle.dhall")
    recipe = subprocess.run((str(ROOT / "test/oracle/phase_48_engine_source.sh"),), cwd=ROOT, stdout=subprocess.PIPE, check=False, timeout=30).stdout
    require(engine["contentAddress"] == ENGINE_DIGEST and engine["residentBytes"] == len(recipe) == 41 and engine["content"].encode() == recipe, "engine-oracle")
    require("sha256:" + hashlib.sha256(recipe).hexdigest() == ENGINE_DIGEST, "engine-digest")
    seeds = json.loads((ROOT / "test/golden/phase_48_splitmix_seeds.json").read_text(encoding="utf-8"))
    require(seeds["streams"] == [{"index": 0, "seed": "0x157a3807a48faa9d"}, {"index": 1, "seed": "0xd573529b34a1d093"}, {"index": 37, "seed": "0x3dfafd29d7a4f68a"}], "splitmix-golden")
    schema = json.loads((ROOT / "test/golden/phase_48_substrate_fingerprint.schema.json").read_text(encoding="utf-8"))
    require(schema["requiredLane"] == "linux-cpu" and len(schema["requiredWitnesses"]) == 4 and all(row["absoluteProbe"].startswith("/") for row in schema["requiredWitnesses"]) and schema["environmentInputs"] == [] and schema["pathLookupAllowed"] is False, "fingerprint-schema")
    equivalence = list(csv.DictReader((ROOT / "test/oracle/phase_48_logical_equivalence.tsv").open(encoding="utf-8"), delimiter="\t"))
    require(len(equivalence) == 4 and sum(row["distinct_preimage"] == "true" for row in equivalence) / len(equivalence) >= 0.3 and all(row["expected"] == "equal-address" for row in equivalence), "logical-equivalence-cover")

    expected_negatives = {
        "test/negative/phase_48_cache_digest_size_conflict.dhall": "ResidentSizeConflict",
        "test/negative/phase_48_cache_deletion_credit.dhall": "DeletionNotObserved",
        "test/negative/phase_48_cache_concurrency_overflow.dhall": "CachePeakExceedsBudget",
        "test/negative/phase_48_ephemeral_under_reserved.dhall": "OwnerEphemeralUnderReserved",
    }
    for path, tag in expected_negatives.items():
        require(load_dhall(path)["expectedTag"] == tag, f"negative:{tag}")
    resource_mutants = sorted((ROOT / "test/mutants/phase_48_cache").glob("*.dhall")) + sorted((ROOT / "test/mutants/phase_48_determinism").glob("*.dhall"))
    require(len(resource_mutants) == 12 and all(load_dhall(str(path.relative_to(ROOT))).get("expectedTag") for path in resource_mutants), "resource-mutant-oracles")
    return {"name": "independent-oracles", "command": "Dhall/JSON/TSV/source oracle validation", "output": "identity, seeds, fingerprint, engine, capacity, negatives valid", "result": "PASS"}


def foreclosure_domain() -> list[dict[str, str]]:
    prefix = (CABAL, "exec", "-w", GHC, "--", GHC, "-XGHC2024", "-fno-code", "-isrc")
    rows = [invoke("content-address-positive", (*prefix, "test/compile-fail/phase_48_content_address_positive.hs"), timeout=300)]
    rows.append(invoke("catalog-identity-positive", (*prefix, "test/negative/phase_48_catalog_identity_positive.hs"), timeout=300))
    negatives = {
        "forge-content-address-red": ("test/compile-fail/phase_48_forge_blobsha.hs", "BlobSha"),
        "free-cache-key-red": ("test/negative/phase_48_freestring_key.hs", "CacheKey"),
        "free-url-arm-red": ("test/negative/phase_48_url_arm.hs", "Url"),
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
    require(live.get("schema") == "amoebius.phase48.determinism-jitcache-live.v1" and live.get("register") == 3 and live.get("substrate") == "linux-cpu", "live-schema-register-substrate")
    stable = dict(live)
    digest = stable.pop("evidenceDigest", None)
    require(digest == fingerprint(stable, newline=True), "live-evidence-digest")
    observed = live["substrateFingerprint"]
    require(observed["digest"] == observed["secondDigest"] != observed["fakeProbeDigest"] and observed["probeInputEnvironmentEntries"] == 0 and observed["pathLookups"] == 0 and len(observed["witnesses"]) == 4, "live-fingerprint")
    determinism = live["determinism"]
    runs = determinism["runs"]
    require(determinism["sameHashByteIdentical"] and determinism["altSeedDifferent"] and determinism["altInputDifferent"] and determinism["experimentHash"] not in {determinism["flippedMetricHash"], determinism["fakeFingerprintHash"]}, "live-determinism")
    require(len(runs) == 4 and len({row["podUid"] for row in runs}) == 4 and all(row["outputInitiallyAbsent"] and row["readOtherRunMounts"] == 0 for row in runs), "fresh-run-boundaries")
    require(determinism["comparisonBoundary"] == "out-of-band MinIO GET by harness; never HTTP 412" and determinism["crossSubstrateBitEquality"] == "UNVERIFIED", "comparison-honesty")
    cache = live["cache"]
    build = cache["buildArm"]
    download = cache["downloadArm"]
    for arm in (build, download):
        require(arm["firstMiss"] == arm["secondClientHit"] and arm["firstMiss"]["contentAddress"] == ENGINE_DIGEST and arm["firstMiss"]["bytes"] == 41 and arm["firstMiss"]["version"] == "llama.cpp-cpu 0.1.0", "cache-arm-readback")
    require(build["race"] == {"bothObservedMiss": True, "materializations": 1, "temporaryFiles": 0} and build["absoluteRecipeArgv0"] == "/usr/bin/sh", "build-race")
    require(build["ownerUid"] != download["ownerUid"] and download["registryDigest"] == ENGINE_DIGEST and download["registryGetEvents"] >= 1 and download["secondClientNewRegistryEvents"] == 0, "download-reuse")
    require(len(cache["clients"]) == 2 and len({row["uid"] for row in cache["clients"]}) == 2 and len({row["node"] for row in cache["clients"]}) == 1 and all(row["cacheMounts"] == 0 for row in cache["clients"]), "client-readback")
    require(cache["ownerManifest"]["strategy"] == "Recreate" and cache["ownerManifest"]["imagePullPolicy"] == "Never" and cache["ownerManifest"]["writableHostPaths"] == 0 and cache["ownerManifest"]["ephemeralRequest"] == "224Mi" and cache["ownerManifest"]["emptyDirSizeLimit"] == "192Mi", "owner-manifest")
    require(cache["provisionedShape"] == {"cacheBudgetUnits": 160, "emptyDirSizeLimitUnits": 192, "ephemeralRequestUnits": 224, "inequalitiesHold": True, "writableAndLogHeadroomUnits": 32}, "provision-shape")
    require(cache["pinAwarePrune"] == {"afterBytes": 105, "beforeBytes": 121, "incomingPresent": True, "measuredPeakBytes": 121, "pinnedPresent": True, "unpinnedPresent": False} and cache["publicRegistryEvents"] == 0, "prune-egress")
    require(live["deferred"] == {"crossNodeReuse": "UNVERIFIED", "crossSubstrateBitEquality": "UNVERIFIED", "tier2Model": "UNVERIFIED until Phase 49", "tier3CudaKernel": "UNVERIFIED until Phase 51"}, "deferred")
    require(live["universalLinuxCpu"] == {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "universal-linux-cpu-and-pristine-routing")
    require(live["cleanup"] == {"minioBucketAbsent": True, "namespaceAbsent": True, "registryAddedKeysAbsent": True, "remainingRegistryAddedKeys": []}, "cleanup")
    require(not re.search(r"(?i)(secretkey|root_token|privateKey|unseal_key|MINIO_ROOT|phase30-test-secret)", raw), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    namespace = subprocess.run((KUBECTL, "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "namespace", "phase48-system"), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60)
    require(namespace.returncode != 0, "phase48-namespace-residue")
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-phase24"], f"unexpected-kind-clusters:{clusters}")
    return {"name": "external-cleanup-readback", "command": "namespace and kind inventories", "output": "no Phase-48 namespace; only retained amoebius-phase24 remains", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 48, "gate_command": "python3 tools/phase48_gate.py --reuse-fresh-live",
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
        rows = [invoke("phase48-source-build", (CABAL, "build", "amoebius:dsl-core", "-w", GHC, *flags(), "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.extend(foreclosure_domain())
        rows.append(invoke("determinism-jitcache-contract", contract_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "determinism-jitcache-live", "command": "sealed just-produced Phase-48 live receipt", "output": "fresh retained-Kubernetes/MinIO/registry evidence", "result": "PASS"})
        else:
            rows.append(invoke("determinism-jitcache-live", (sys.executable, "tools/phase48_determinism_jitcache_live.py"), timeout=2400))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        live_reader = (CABAL, "test", "determinism-jitcache-live", "-w", GHC, "--test-show-details=direct", "-j1", "-v0")
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
            "schema": "amoebius.phase48.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "engineContentAddress": ENGINE_DIGEST, "sameSubstrateRecompute": "TESTED",
            "crossSubstrateBitEquality": "UNVERIFIED", "crossNodeReuse": "UNVERIFIED",
            "mutantsRed": list(MUTANTS.values()), "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-48-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"phase48-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; cross-substrate/cross-node/Tier-2/Tier-3 UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase48-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
