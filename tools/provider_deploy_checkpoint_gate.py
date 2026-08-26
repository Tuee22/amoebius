#!/usr/bin/env python3
"""Run and seal the locally dischargeable Phase-44 gate domains."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_44"
LIVE = EVIDENCE / "provider-checkpoint-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_44_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_44_ledger.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
MUTANTS = (
    ("M-static-key", "provider-deploy-checkpoint-static-key-mutant", "mut-44.1-static-key"),
    ("M-leak-path", "provider-deploy-checkpoint-leak-path-mutant", "mut-44.1-leak-path"),
    ("M-drop-parallel-executor", "provider-deploy-checkpoint-drop-parallel-executor-mutant", "mut-44.1-drop-parallel-executor"),
)
UNVERIFIED = {
    "aws-provider-account-observation", "eks-control-plane-materialization",
    "managed-node-group-materialization", "pulumi-up-from-control-plane",
    "aws-plugin-execve", "engine-pod-filesystem-observer",
    "direct-s3-outside-gateway-denial", "cloudtrail-empty-mutation-audit",
}


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


def contract_args(enabled: str | None = None) -> tuple[str, ...]:
    return (
        CABAL, "test", "amoebius-pulumi:provider-deploy-checkpoint-contract",
        "-w", GHC, *flags(enabled), "--test-show-details=direct", "-j1", "-v0",
    )


def live_reader_args() -> tuple[str, ...]:
    return (CABAL, "test", "provider-deploy-checkpoint-live", "-w", GHC, "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    result = subprocess.run(
        contract_args(flag), cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(contract_args(flag)), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("44\t")]
    require(len(rows) == 12, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 9, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 3, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read test/oracle/preimplementation_artifacts.tsv", "output": "9 oracles; 3 mutants", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    result = subprocess.run(
        (DHALL_TO_JSON, "--file", "test/fixture/dhall/provider_deploy_checkpoint/provider_provision.dhall"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(result.returncode == 0, f"provider-dhall:{result.stdout}")
    topology = json.loads(result.stdout)
    require(topology.get("substrate") == "linux-cpu" and topology.get("targetClass") == "provider:aws-eks", "provider-topology")
    require(topology.get("baseNodeClass", {}).get("accelerator") is None, "provider-cpu-only")
    require(topology.get("execution", {}).get("concurrency") == "BoundedParallel 2", "provider-executor-concurrency")
    require(topology.get("universalLinuxCpu", {}).get("availableOnEveryHardwareSubstrate") is True, "universal-linux-cpu")
    for path in (
        ROOT / "test/golden/checkpoint_envelope.json",
        ROOT / "test/fixture/provider_deploy_checkpoint/provider-sku-snapshot.json",
        ROOT / "test/fixture/provider_deploy_checkpoint/observed-provider-account.json",
        ROOT / "test/fixture/provider_deploy_checkpoint/expected-provider-demand.json",
        ROOT / "test/fixture/provider_deploy_checkpoint/live-observer-contract.json",
    ):
        require(isinstance(json.loads(path.read_text(encoding="utf-8")), dict), f"json-oracle:{path.name}")
    execve = (ROOT / "test/golden/engine_execve.txt").read_text(encoding="utf-8")
    require("environment=EMPTY" in execve and "argv[0]=/usr/local/bin/pulumi" in execve, "execve-oracle")
    matrix = list(csv.DictReader((ROOT / "test/fixture/provider_deploy_checkpoint/one-short-matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    require(len(matrix) == 8 and len({row["failure_tag"] for row in matrix}) == 8, "one-short-matrix")
    negative = subprocess.run(
        ("/bin/bash", "test/negative/host_shell_pulumi_up.sh"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60,
    )
    require(negative.returncode == 44 and negative.stdout.strip() == "NoControlPlaneDaemonContext", "host-shell-negative")
    return {"name": "independent-oracles", "command": "Dhall/JSON/TSV/process pin validation", "output": "topology, account, SKU, demand, envelope, execve, one-short, observer, negative valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schema") == "amoebius.phase44.provider-checkpoint-live.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable, newline=True), "live-evidence-digest")
    control_plane = live.get("controlPlane", {})
    require(control_plane.get("replicas") == control_plane.get("readyReplicas") == control_plane.get("availableReplicas") == 1, "control-plane-readback")
    require(control_plane.get("bespokeElection") is False, "control-plane-election")
    placement = live.get("executorPlacement", {})
    require(placement.get("boundedParallel") == 2 and len(placement.get("jobs", [])) == 2, "executor-placement")
    require(all(job.get("environmentEntries") == 0 and job.get("serviceLinks") is False for job in placement.get("jobs", [])), "executor-environment")
    checkpoint = live.get("checkpoint", {})
    require(checkpoint.get("exactObjectPeak") == 6 and len(checkpoint.get("objects", [])) == 6, "checkpoint-peak")
    require(checkpoint.get("directTransitDecrypt") is True and checkpoint.get("sealedVaultCheckpointInventoryUnchanged") is True, "transit-seal")
    require(checkpoint.get("sealedVaultRefusalStatus", 0) >= 400 and checkpoint.get("plaintextDataKeyWritten") is False, "sealed-refusal-data-key")
    require(all(row.get("ciphertextPrefix") == "vault:v1:" and row.get("plaintextAbsent") is True for row in checkpoint.get("objects", [])), "opaque-object-readback")
    engine = live.get("engineBoundary", {})
    require(engine.get("absolutePath") is True and engine.get("environmentEntries") == 0, "engine-execve")
    provider = live.get("providerMaterialization", {})
    require({provider.get(key) for key in ("eksControlPlane", "managedNodeGroup", "providerAccountObservation", "cloudTrailMutationAudit")} == {"UNVERIFIED"}, "provider-honesty")
    require(live.get("providerAuthority", {}).get("reason") == "InvalidClientTokenId", "provider-authority")
    require(live.get("cleanup") == {"checkpointBucketRemoved": True, "phase44NamespaceAbsent": True, "temporaryRootAbsent": True, "transitKeyRemoved": True}, "cleanup")
    require(live.get("universalLinuxCpu") == {
        "availableOnEveryHardwareSubstrate": True,
        "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
    }, "universal-linux-cpu-and-pristine-routing")
    require(not re.search(r"(?i)(secretAccessKey|root_token|privateKey|unseal_key|kubernetes\.jwt)", LIVE.read_text(encoding="utf-8")), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    namespace = subprocess.run(
        ("/usr/bin/kubectl", "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "namespace", "provider-deploy-checkpoint-system"),
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60,
    )
    require(namespace.returncode != 0, "provider-deploy-checkpoint-namespace-residue")
    require(not Path("/var/tmp/amoebius-provider-deploy-checkpoint-live").exists(), "provider-deploy-checkpoint-root-residue")
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-bootstrap-coordinator"], f"unexpected-kind-clusters:{clusters}")
    return {"name": "external-cleanup-readback", "command": "namespace/root/kind inventories", "output": "only retained amoebius-bootstrap-coordinator remains", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 44,
        "gate_command": "python3 tools/provider_deploy_checkpoint_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu → provider", "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
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
        rows = [invoke("source-build", (CABAL, "build", "amoebius:dsl-core", "amoebius-pulumi", "provider-deploy-checkpoint-live", "-w", GHC, *flags(), "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("pure-contract", contract_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "scoped-live-boundaries", "command": "sealed just-produced Phase-44 live receipt", "output": "fresh scoped evidence; AWS/EKS UNVERIFIED", "result": "PASS"})
        else:
            rows.append(invoke("scoped-live-boundaries", (sys.executable, "tools/provider_deploy_checkpoint_live.py"), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        rows.append(invoke("sealed-live-reader", live_reader_args(), extra_env={"PROVIDER_DEPLOY_CHECKPOINT_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored-contract", contract_args()))
        rows.append(invoke("baseline-restored-live-reader", live_reader_args(), extra_env={"PROVIDER_DEPLOY_CHECKPOINT_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase44.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "checkpointObjects": 6, "boundedParallel": 2, "sealedVaultRefused": True,
            "providerMaterialization": "UNVERIFIED", "phaseStatus": "PARTIAL_EXTERNAL_AUTHORITY",
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS_SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text(
            "\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows)
            + f"\nPHASE-44-SCOPED-GATE PASS {derived['ledger_hash']}\nPROVIDER-MATERIALIZATION UNVERIFIED\n",
            encoding="utf-8",
        )
        print(f"provider-deploy-checkpoint-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; AWS/EKS UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"provider-deploy-checkpoint-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
