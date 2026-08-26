#!/usr/bin/env python3
"""Run and seal the locally dischargeable Phase-46 gate domains."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_46"
LIVE = EVIDENCE / "provider-ebs-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_46_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_46_ledger.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
FLAGS = (
    "provider-ebs-credential-allow-delete-mutant",
    "provider-ebs-credential-dynamic-provisioner-mutant",
    "provider-ebs-credential-credit-old-mutant",
    "provider-ebs-credential-drop-copy-executor-mutant",
    "provider-ebs-credential-bypass-validated-batch-mutant",
)
MUTANTS = {
    "provider-ebs-credential-allow-delete-mutant": "mut-46.1-allow-delete",
    "provider-ebs-credential-dynamic-provisioner-mutant": "mut-46.1-enable-dynamic-provisioner",
    "provider-ebs-credential-credit-old-mutant": "mut-46.1-credit-old-before-observed-delete",
    "provider-ebs-credential-drop-copy-executor-mutant": "mut-46.1-drop-copy-executor",
    "provider-ebs-credential-bypass-validated-batch-mutant": "mut-46.1-bypass-validated-batch",
}
UNVERIFIED = {
    "real-aws-ebs-volume", "real-operational-ec2-create-volume",
    "real-operational-ec2-delete-volume-denial", "real-csi-runtime-cloud-audit",
    "real-aws-ebs-csi-readiness", "baked-csi-amd64-binary-execution",
    "baked-csi-arm64-binary-execution", "real-provider-static-attach-mount",
    "real-provider-raw-usable-geometry", "real-cluster-destroy-ebs-retention",
    "real-same-ebs-handle-reattach", "real-provider-volume-migration",
    "real-create-provider-capacity-cloud-mutation", "receipt-bound-ebs-checkpoint-readback",
    "elevated-harness-durable-ebs-reclamation",
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


def invoke(name: str, arguments: Sequence[str], *, timeout: int = 3600) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def flag_arguments(active: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'' if flag == active else '-'}{flag}" for flag in FLAGS)


def contract_args(active: str | None = None) -> tuple[str, ...]:
    return (
        CABAL, "test", "amoebius-pulumi:provider-ebs-credential-contract", "-w", GHC,
        *flag_arguments(active), "--test-show-details=direct", "-j1", "-v0",
    )


def reject_mutant(flag: str, marker: str) -> dict[str, str]:
    arguments = contract_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{marker}:green")
    require(marker in result.stdout, f"{marker}:wrong-red:{result.stdout}")
    return {"name": marker, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("46\t")]
    require(len(rows) == 11, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 6, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 5, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read Phase-46 manifest rows", "output": "6 oracles; 5 mutants", "result": "PASS"}


def load_dhall(path: str) -> Any:
    result = subprocess.run(
        (DHALL_TO_JSON, "--file", path), cwd=ROOT, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(result.returncode == 0, f"dhall:{path}:{result.stdout}")
    return json.loads(result.stdout)


def oracle_domain() -> dict[str, str]:
    topology = load_dhall("test/fixture/dhall/provider_ebs_credential/provider_provision.dhall")
    require(topology.get("substrate") == "linux-cpu" and topology.get("targetClass") == "provider:aws-eks", "topology")
    universal = topology.get("universalLinuxCpu", {})
    require(universal.get("availableOnEveryHardwareSubstrate") is True, "universal-linux-cpu")
    volume = topology.get("volume", {})
    require(volume.get("sizeGiB") == 6 and volume.get("provisionedBytes") == 6442450944 and volume.get("protect") and volume.get("retain"), "volume-topology")
    csi = topology.get("staticCsi", {})
    require(csi == {"attachSlots": 2, "driver": "ebs.csi.aws.com", "externalProvisionerContainers": 0, "provisioner": "kubernetes.io/no-provisioner", "storageClass": "amoebius-retained"}, "static-csi-topology")

    credential_rows = list(csv.DictReader((ROOT / "test/golden/ebs_credential_matrix.txt").open(encoding="utf-8"), delimiter="\t"))
    require(len(credential_rows) == 10, "credential-matrix-cardinality")
    expected_decisions = {(row["principal"], row["action"]): (row["expected"], row["scope"]) for row in credential_rows}
    require(expected_decisions[("operational", "ec2:DeleteVolume")] == ("deny", "durable-retained"), "delete-deny-oracle")
    require(expected_decisions[("csi-runtime", "ec2:CreateVolume")] == ("deny", "all"), "csi-create-deny-oracle")

    binaries = load_dhall("test/fixture/provider_ebs_credential/ebs_csi_bake_expected.dhall")
    require(len(binaries) == 5 and all(row["path"].startswith("/") and row["architectures"] == ["amd64", "arm64"] for row in binaries), "bake-oracle")
    require(not any("provisioner" in row["name"] for row in binaries), "external-provisioner-in-bake-oracle")

    rounding = list(csv.DictReader((ROOT / "test/fixture/provider_ebs_credential/provider-volume-rounding.tsv").open(encoding="utf-8"), delimiter="\t"))
    require(len(rounding) == 4, "rounding-cardinality")
    gib = 1073741824
    for row in rounding:
        required = int(row["required_usable_bytes"])
        minimum = int(row["minimum_bytes"])
        quantum = math.lcm(gib, int(row["quantum_bytes"]))
        expected_bytes = ((max(required, minimum) + quantum - 1) // quantum) * quantum
        require(expected_bytes == int(row["expected_provisioned_bytes"]) and expected_bytes // gib == int(row["expected_size_gib"]), f"rounding:{row['case']}")

    one_short = list(csv.DictReader((ROOT / "test/fixture/provider_ebs_credential/migration-one-short.tsv").open(encoding="utf-8"), delimiter="\t"))
    require(len(one_short) == 8 and all(int(row["available"]) + 1 == int(row["required"]) for row in one_short), "migration-one-short")
    static = json.loads((ROOT / "test/fixture/provider_ebs_credential/static-pv-oracle.json").read_text(encoding="utf-8"))
    require(static == {"apiVersion": "v1", "kind": "PersistentVolume", "reclaimPolicy": "Retain", "storageClass": "amoebius-retained", "driver": "ebs.csi.aws.com", "volumeHandleSource": "materialized-provider-volume-id", "zoneKey": "topology.ebs.csi.aws.com/zone", "dynamicProvisionerContainers": 0, "soleStorageClassProvisioner": "kubernetes.io/no-provisioner"}, "static-pv-oracle")
    return {"name": "independent-oracles", "command": "Dhall/text/JSON/TSV oracle validation", "output": "topology, credentials, bake, rounding, migration, static PV valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schema") == "amoebius.phase46.provider-ebs-live.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable, newline=True), "live-evidence-digest")
    require(live.get("scopedBoundary") == "retained kind storage and checkpoint-class analogue; not an AWS EBS or IAM result", "scoped-boundary")
    storage_class = live.get("storageClass", {})
    require(storage_class == {"name": "amoebius-retained", "provisioner": "kubernetes.io/no-provisioner", "reclaimPolicy": "Retain", "dynamicEbsStorageClasses": []}, "storage-class")
    static = live.get("staticEbsPvObject", {})
    require({key: static.get(key) for key in ("apiKind", "reclaimPolicy", "storageClass", "driver", "volumeHandle", "zoneKey", "zones", "bindingAttempted", "providerVolumeExists")} == {"apiKind": "PersistentVolume", "reclaimPolicy": "Retain", "storageClass": "amoebius-retained", "driver": "ebs.csi.aws.com", "volumeHandle": "vol-provider-ebs-credential-object-only", "zoneKey": "topology.ebs.csi.aws.com/zone", "zones": ["us-east-1a"], "bindingAttempted": False, "providerVolumeExists": "UNVERIFIED"}, "static-pv-object")
    marker = live.get("retainedMarker", {})
    require(marker.get("backing") == "retained hostPath scoped analogue; not EBS" and marker.get("backingPathStable") and marker.get("byteExact") and marker.get("pvIdentityChanged") and marker.get("ebsVolumeHandleStable") == "UNVERIFIED", "retained-marker")
    checkpoint = live.get("checkpointClasses", {})
    require(checkpoint == {"objectKeys": ["ephemeral/cluster/checkpoint.json", "durable/pv/data-sts0-pv_0/checkpoint.json"], "distinctLogicalNamespaces": True, "objectsOpaque": True, "directTransitRecovery": True, "durableProtectRetainMetadataRecovered": True}, "checkpoint-classes")
    provider = live.get("providerMaterialization", {})
    provider_keys = ("realEbsVolume", "operationalEc2CreateVolume", "operationalEc2DeleteVolumeDenied", "awsEbsCsiReady", "providerAttachMount", "sameEbsHandleReattach", "providerRawAndUsableGeometry", "cloudAudit")
    require({provider.get(key) for key in provider_keys} == {"UNVERIFIED"}, "provider-honesty")
    require(live.get("bakedCsiBinaryExecution") == {"amd64": "UNVERIFIED", "arm64": "UNVERIFIED"}, "bake-execution-honesty")
    require(live.get("cleanup") == {"namespaceAbsent": True, "phase46PersistentVolumes": [], "hostPathRemoved": True, "checkpointBucketRemoved": True, "transitKeyRemoved": True, "providerResources": "none-created"}, "cleanup")
    require(live.get("universalLinuxCpu") == {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "universal-linux-cpu-and-pristine-routing")
    require(not re.search(r"(?i)(secretAccessKey|root_token|privateKey|unseal_key|kubernetes\.jwt)", LIVE.read_text(encoding="utf-8")), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    namespace = subprocess.run(("/usr/bin/kubectl", "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "namespace", "provider-ebs-credential-system"), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60)
    require(namespace.returncode != 0, "provider-ebs-credential-namespace-residue")
    pvs_result = subprocess.run(("/usr/bin/kubectl", "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "persistentvolume", "-o", "json"), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60)
    require(pvs_result.returncode == 0, "persistent-volume-inventory-unavailable")
    pvs = [item["metadata"]["name"] for item in json.loads(pvs_result.stdout)["items"] if item["metadata"]["name"].startswith("provider-ebs-credential-")]
    require(not pvs, f"provider-ebs-credential-pv-residue:{pvs}")
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-bootstrap-coordinator"], f"unexpected-kind-clusters:{clusters}")
    return {"name": "external-cleanup-readback", "command": "namespace, PV, and kind inventories", "output": "no Phase-46 objects; only retained amoebius-bootstrap-coordinator remains", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 46,
        "gate_command": "python3 tools/provider_ebs_credential_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu → provider", "date": "2026-08-11",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"}, {"name": "Runtime", "status": "UNVERIFIED"}],
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
        rows = [invoke("source-build", (CABAL, "build", "amoebius-pulumi", "-w", GHC, *flag_arguments(), "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("pure-contract", contract_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "scoped-retained-storage-checkpoint", "command": "sealed just-produced Phase-46 live receipt", "output": "fresh scoped evidence; AWS EBS/IAM UNVERIFIED", "result": "PASS"})
        else:
            rows.append(invoke("scoped-retained-storage-checkpoint", (sys.executable, "tools/provider_ebs_credential_live.py"), timeout=2400))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        rows.append(invoke("sealed-live-reader", (CABAL, "test", "provider-ebs-credential-live", "-w", GHC, "--test-show-details=direct", "-j1", "-v0")))
        for flag, marker in MUTANTS.items():
            rows.append(reject_mutant(flag, marker))
        rows.append(invoke("baseline-restored-contract", contract_args()))
        rows.append(invoke("baseline-restored-live-reader", (CABAL, "test", "provider-ebs-credential-live", "-w", GHC, "--test-show-details=direct", "-j1", "-v0")))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase46.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "roundedProviderBytes": 6442450944, "migrationOneShortRefusals": 8,
            "checkpointClasses": 2, "retainedMarkerByteExact": True,
            "awsEbsIam": "UNVERIFIED", "phaseStatus": "PARTIAL_EXTERNAL_AUTHORITY",
            "mutantsRed": list(MUTANTS.values()), "result": "PASS_SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-46-SCOPED-GATE PASS {derived['ledger_hash']}\nAWS-EBS-IAM UNVERIFIED\n", encoding="utf-8")
        print(f"provider-ebs-credential-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; AWS EBS/IAM UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"provider-ebs-credential-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
