#!/usr/bin/env python3
"""Run and seal the scoped Phase-51 jitML CUDA artifact-lift gate."""

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

import phase34_tenant_provider_live as phase34
import phase37_workflow_live as phase37


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_DIR = ROOT / "DEVELOPMENT_PLAN/evidence/phase_51"
LIVE = EVIDENCE_DIR / "jitml-cuda-live.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_51_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_51_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL = "/home/matthewnowak/.local/bin/dhall"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
KUBECTL = "/usr/bin/kubectl"
FLAGS = (
    "phase51-silent-cpu-fallback-mutant", "phase51-spend-raw-vram-mutant",
    "phase51-mint-artifact-before-cas-mutant", "phase51-regenerate-command-id-mutant",
)
MUTANTS = {
    "phase51-silent-cpu-fallback-mutant": "mut-51-silent-cpu-fallback",
    "phase51-spend-raw-vram-mutant": "mut-51-spend-raw-vram",
    "phase51-mint-artifact-before-cas-mutant": "mut-51-mint-artifact-before-cas",
    "phase51-regenerate-command-id-mutant": "mut-51-regenerate-command-id",
}
UNVERIFIED = {
    "kubernetes-device-plugin-allocation", "kubernetes-accelerator-owner-pod",
    "kubernetes-owner-resource-request-limit", "kubernetes-owner-node-affinity",
    "kubernetes-owner-pod-uid-cgroup-correlation", "kubernetes-audit-observer",
    "native-cbor-command-event-chain", "pulsar-command-offset-observer",
    "vault-one-use-training-credential", "full-sibling-jitml-trainer",
    "sibling-multilayer-10m-model", "sibling-checkpoint-format-module-linkage",
    "canonical-cbor-jitml-manifest", "mutable-latest-etag-cas",
    "jit-build-first-miss-containerd-cache", "live-net-one-short-zero-effect",
    "live-current-free-one-short-zero-effect", "live-changed-input-zero-effect",
    "live-exact-resend-zero-cuda-launch", "direct-kubernetes-launch-bypass-denial",
    "trainer-failover", "general-numerical-correctness", "general-tenant-noninterference",
}


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise GateFailure(tag)


def fingerprint(value: Any, *, newline: bool = False) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(payload + (b"\n" if newline else b"")).hexdigest()


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
    return (CABAL, "test", "jitml-cuda-artifact-lift-contract", "-w", GHC, *flags(enabled),
            "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(flag: str, marker: str) -> dict[str, str]:
    arguments = contract_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0 and marker in result.stdout,
            f"{marker}:green-or-wrong-locus:{result.stdout}")
    return {"name": marker, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("51\t")]
    require(len(rows) == 9, "phase0-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 5 and
            sum("\tmutant\t" in row for row in rows) == 4, "phase0-kind-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-missing:{path}")
    patches = "\n".join((ROOT / row.split("\t")[2]).read_text(encoding="utf-8")
                         for row in rows if "\tmutant\t" in row)
    require("src/Amoebius/JitML/CudaArtifactLift.hs" in patches and all(locus in patches for locus in
            ("CpuTarget", "capacityForAdmission", "PointerCasSucceeded", "workIdentity")),
            "phase0-mutant-loci")
    return {"name": "phase0-custody", "command": "read Phase-51 manifest rows",
            "output": "5 oracles; 4 mutants", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    decoded = subprocess.run(
        (DHALL_TO_JSON, "--file", "test/dhall/phase_51/jitml_cuda_artifact.dhall"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(decoded.returncode == 0, f"phase51-dhall-oracle:{decoded.stdout}")
    value = json.loads(decoded.stdout)
    require(value["substrate"] == "linux-cuda" and value["register"] == 3 and
            value["trainer"] == {"optimizerSteps": 200, "parameterCount": 10000000,
            "batchAddress": "sha256:103902cddc61b7b8638c265aabf695c0945452b244ae5161750124b6a2c36845"} and
            value["requiredCapabilities"] == ["JitBuild", "Coordination", "InferenceEngine"] and
            not value["cpuFallback"], "dhall-domain")
    require(value["universalLinuxCpu"] == {"availableOnEveryHardwareSubstrate": True,
            "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
            "universal-linux-cpu")
    capacity = list(csv.DictReader((ROOT / "test/fixtures/phase_51/cuda_capacity_matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["expected"] for row in capacity] == ["ProvisionedCudaTraining", "CudaNetAllocatableShort", "CudaCurrentFreeShort", "CudaRequired"] and
            [int(row["effects"]) for row in capacity] == [1, 0, 0, 0], "capacity-matrix")
    artifact = list(csv.DictReader((ROOT / "test/fixtures/phase_51/committed_artifact_contract.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["constructor_available"] for row in artifact] == ["false", "false", "false", "true", "false"], "artifact-matrix")
    commands = list(csv.DictReader((ROOT / "test/fixtures/phase_51/command_identity_matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["expected"] for row in commands] == ["new-committed-artifact", "original-committed-artifact", "IdempotencyConflict", "ArtifactUnavailable"], "command-matrix")
    resource = json.loads((ROOT / "test/fixtures/phase_51/resource_shape.json").read_text(encoding="utf-8"))
    require(resource["requests"] == resource["limits"] == {"nvidia.com/gpu": 1} and resource["wholeDeviceOffering"], "resource-shape")
    return {"name": "independent-oracles", "command": "Dhall/TSV/JSON validation",
            "output": "CUDA floor, capacity, artifact, identity, resource oracles valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    raw = LIVE.read_text(encoding="utf-8")
    live = json.loads(raw)
    stable = dict(live)
    actual = stable.pop("evidenceDigest", None)
    require(actual == fingerprint(stable, newline=True), "live-evidence-digest")
    require(live["schema"] == "amoebius.phase51.jitml-cuda-live.v1" and live["register"] == 3 and
            live["substrate"] == "linux-cuda" and live["result"] == "PASS-SCOPED", "live-schema")
    challenge = live["challenge"]
    require(challenge["commandId"] == challenge["workId"] and len(challenge["nonce"]) == 48 and
            challenge["unpredictableBytes"] == 24, "live-challenge")
    cuda = live["cuda"]
    require(cuda["physicalDevice"] and not cuda["cpuFallback"] and cuda["driverApi"] == "libcuda.so.1" and
            cuda["ptxTarget"] == "sm_52" and cuda["computeCapability"] == "5.2" and
            cuda["parameters"] == 10000000 and cuda["optimizerSteps"] == cuda["kernelLaunches"] == 200 and
            cuda["checkpointBytes"] == 40000000 and cuda["independentCheckpointOracle"] and
            cuda["firstParameter"] == cuda["lastParameter"] == cuda["expectedParameter"] and
            cuda["nvidiaSmiObservedPid"] > 0 and cuda["requiredVramBytes"] <= cuda["netAllocatableBytes"] and
            cuda["requiredVramBytes"] <= cuda["currentFreeBytesAtAdmission"], "live-cuda")
    artifact = live["artifact"]
    require(artifact["checkpointDigest"] == cuda["checkpointDigest"] and len(artifact["writeOrder"]) == 4 and
            artifact["pointerWrittenLast"] and artifact["pointerConflictStatus"] == 412 and
            artifact["pointerUnchangedAfterConflict"] and artifact["exactResendObjectDelta"] == 0 and
            artifact["readbackEtagsPresent"] and artifact["unauthenticatedReadStatus"] == 403, "live-artifact")
    linked = live["linkedSibling"]
    sibling = ROOT.parent / "jitML/src/JitML/Codegen/RuntimeOperationsCuda.hs"
    require(linked == {"module": "JitML.Codegen.RuntimeOperationsCuda",
            "sourceDigest": "sha256:" + hashlib.sha256(sibling.read_bytes()).hexdigest(),
            "compiledByContractPackage": True}, "linked-sibling")
    require(live["kubernetes"] == {"retainedNodeGpuAllocatable": "", "acceleratorOwnerPod": "UNVERIFIED", "devicePlugin": "UNVERIFIED"}, "kubernetes-honesty")
    require(all(live["cleanup"].values()), "live-cleanup")
    require(live["universalLinuxCpu"] == {"availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "live-universal")
    honesty = live["honesty"]
    require({key for key, value in honesty.items() if value == "TESTED"} ==
            {"linkedSiblingCudaCodegen", "hostCudaKernelTraining", "retainedMinioCommit"} and
            all(value in {"TESTED", "UNVERIFIED"} for value in honesty.values()), "live-honesty")
    require(not re.search(r'(?i)(access_key|secret_key|authorization"\s*:|token"\s*:|password"\s*:)', raw),
            "secret-in-evidence")


def external_cleanup() -> dict[str, str]:
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE,
                              check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-phase24"], f"kind-clusters:{clusters}")
    namespaces = subprocess.run(
        (KUBECTL, "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"),
         "get", "namespace", "-o", "name"), text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=60,
    )
    require(namespaces.returncode == 0 and not any("phase51" in row for row in namespaces.stdout.splitlines()),
            "phase51-namespace-residue")
    with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
        status, payload, _ = phase37.s3_request("GET", "")
        require(status == 200 and b"<Name>p51-" not in payload, "phase51-minio-residue")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    process = subprocess.run(("/bin/ps", "-p", str(live["cuda"]["nvidiaSmiObservedPid"])),
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=30)
    require(process.returncode != 0, "phase51-live-process-still-running")
    return {"name": "external-cleanup-readback", "command": "kind/Kubernetes/MinIO/process inventories",
            "output": "no Phase-51 bucket/namespace/process; retained kind only", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
                if line.strip() and not line.startswith("#")]
    require(len(surfaces) == len(set(surfaces)), "duplicate-enumeration-surface")
    require(UNVERIFIED <= set(surfaces), "unverified-surface-not-enumerated")
    ledger: dict[str, Any] = {
        "phase": 51,
        "gate_command": "python3 tools/phase51_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cuda", "date": "2026-08-11",
        "layers": [{"name": "Decision", "status": "tested"},
                   {"name": "Protocol", "status": "tested"},
                   {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"}
                     for surface in surfaces],
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
        disabled = flags()
        rows = [invoke("phase51-source-build", (CABAL, "build", "jitml-lift:lib:jitml-lift",
            "jitml-cuda-artifact-lift-contract", "jitml-cuda-artifact-lift-live-gate",
            "-w", GHC, *disabled, "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("production-dhall-package", (DHALL, "type", "--file", "dhall/jitml/package.dhall", "--quiet")))
        rows.append(invoke("jitml-cuda-artifact-lift-contract", contract_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "jitml-cuda-live", "command": "sealed just-produced Phase-51 live receipt",
                         "output": "fresh host-CUDA/MinIO evidence", "result": "PASS"})
        else:
            rows.append(invoke("jitml-cuda-live", (sys.executable, "tools/phase51_jitml_cuda_live.py"), timeout=2400))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(external_cleanup())
        reader = (CABAL, "test", "jitml-cuda-artifact-lift-live-gate", "-w", GHC,
                  "--test-show-details=direct", "-j1", "-v0")
        rows.append(invoke("sealed-live-reader", reader))
        for flag, marker in MUTANTS.items():
            rows.append(reject_mutant(flag, marker))
        rows.append(invoke("baseline-restored-contract", contract_args()))
        rows.append(invoke("baseline-restored-live-reader", reader))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived,
                "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER),
                                           "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase51.receipt.v1", "register": 3, "substrate": "linux-cuda",
            "physicalCudaKernel": "TESTED", "optimizerSteps": 200, "parameterCount": 10000000,
            "retainedMinioCommit": "TESTED", "kubernetesAcceleratorOwner": "UNVERIFIED",
            "nativeCborChain": "UNVERIFIED", "fullSiblingTrainer": "UNVERIFIED",
            "mutantsRed": list(MUTANTS.values()), "result": "PASS-SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
        (EVIDENCE_DIR / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE_DIR / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE_DIR / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-51-GATE PASS-SCOPED {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"phase51-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; Kubernetes accelerator-owner/native-CBOR/full sibling trainer UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase51-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
