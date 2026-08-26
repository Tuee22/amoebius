#!/usr/bin/env python3
"""Run and seal the locally dischargeable Phase-47 gate domains."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_47"
LIVE = EVIDENCE / "provider-dynamic-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_47_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_47_ledger.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
RUNTIME_FLAGS = (
    "provider-dynamic-nodes-ignore-signal-mutant", "provider-dynamic-nodes-apply-over-quota-mutant",
    "provider-dynamic-nodes-unreachable-as-gone-mutant", "provider-dynamic-nodes-ignore-live-csinode-mutant",
    "provider-dynamic-nodes-dedup-distinct-pvcs-mutant", "provider-dynamic-nodes-template-id-as-physical-mutant",
)
PULUMI_FLAGS = ("provider-dynamic-nodes-skip-sweep-mutant", "provider-dynamic-nodes-untagged-orphan-mutant")
RUNTIME_MUTANTS = {
    "provider-dynamic-nodes-ignore-signal-mutant": "mut-47.1-ignore-signal",
    "provider-dynamic-nodes-apply-over-quota-mutant": "mut-47.1-apply-over-quota",
    "provider-dynamic-nodes-unreachable-as-gone-mutant": "mut-47.1-unreachable-as-gone",
    "provider-dynamic-nodes-ignore-live-csinode-mutant": "mut-47.1-ignore-live-csinode",
    "provider-dynamic-nodes-dedup-distinct-pvcs-mutant": "mut-47.1-dedup-distinct-pvcs",
    "provider-dynamic-nodes-template-id-as-physical-mutant": "mut-47.1-template-id-as-physical",
}
PULUMI_MUTANTS = {
    "provider-dynamic-nodes-skip-sweep-mutant": "mut-47.2-skip-sweep",
    "provider-dynamic-nodes-untagged-orphan-mutant": "mut-47-untagged-orphan",
}
UNVERIFIED = {
    "real-eks-cluster", "real-managed-node-provisioning", "workflow-signal-correlated-runinstances",
    "load-signal-correlated-runinstances", "real-node-first-state-managed-capacity-taint",
    "real-node-supply-layout-device-readback", "real-scheduler-generation-cas",
    "real-provider-quota-observation", "real-root-ebs-geometry", "real-two-node-physical-identity-readback",
    "real-cloud-noop-audit", "aws-run-owned-describe-sweep", "ephemeral-provider-leak-freedom",
    "durable-ebs-sole-survivor", "second-full-provider-cycle",
    "elevated-harness-durable-ebs-reclamation", "spot-cost-signal",
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


def flags(all_flags: Sequence[str], active: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'' if flag == active else '-'}{flag}" for flag in all_flags)


def runtime_args(active: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "amoebius-runtime:provider-dynamic-node-contract", "-w", GHC, *flags(RUNTIME_FLAGS, active), "--test-show-details=direct", "-j1", "-v0")


def pulumi_args(active: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "amoebius-pulumi:provider-teardown-contract", "-w", GHC, *flags(PULUMI_FLAGS, active), "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(arguments: Sequence[str], marker: str) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{marker}:green")
    require(marker in result.stdout, f"{marker}:wrong-red:{result.stdout}")
    return {"name": marker, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("47\t")]
    require(len(rows) == 15, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 7, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 8, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read Phase-47 manifest rows", "output": "7 oracles; 8 mutants", "result": "PASS"}


def load_dhall(path: str) -> Any:
    result = subprocess.run((DHALL_TO_JSON, "--file", path), cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120)
    require(result.returncode == 0, f"dhall:{path}:{result.stdout}")
    return json.loads(result.stdout)


def oracle_domain() -> dict[str, str]:
    legal = load_dhall("test/fixture/dhall/provider_dynamic_nodes/provider_provision.dhall")
    over = load_dhall("test/fixture/dhall/provider_dynamic_nodes/provider_over_quota.dhall")
    missing = load_dhall("test/fixture/dhall/provider_dynamic_nodes/provider_missing_capability.dhall")
    require(legal.get("substrate") == "linux-cpu" and legal.get("targetClass") == "provider:aws-eks", "topology")
    require(legal.get("signals") == ["workflow-completion", "load"], "signal-corpus")
    require(legal["selectedClass"]["maximumCount"] == 2 and over["selectedClass"]["maximumCount"] == 3 and legal["providerQuota"]["instances"] == 2, "over-quota-one-field")
    # dhall-to-json omits Optional/None fields, so absence is the canonical JSON
    # representation of the CPU-only class's accelerator capability.
    require(legal["demand"]["capability"] == "Cpu" and missing["demand"]["capability"] == "Cuda" and legal["selectedClass"].get("accelerator") is None, "missing-capability-one-field")
    require(legal.get("universalLinuxCpu", {}).get("availableOnEveryHardwareSubstrate") is True, "universal-linux-cpu")

    sweep_rows = list(csv.DictReader((ROOT / "test/golden/provider_ephemeral_sweep_expected.txt").open(encoding="utf-8"), delimiter="\t"))
    require(len(sweep_rows) == 3 and sweep_rows[0] == {"resource-class": "ephemeral", "expected-survivors": "0", "ownership-enumeration": "run-tag-or-vpc-id-or-cluster-ownership-tag"}, "sweep-oracle")
    identities = list(csv.DictReader((ROOT / "test/golden/provider_two_instance_identity_map.txt").open(encoding="utf-8"), delimiter="\t"))
    require(len(identities) == 4 and len({row["expected-physical-identity"] for row in identities}) == 4, "identity-map")
    refusals = list(csv.DictReader((ROOT / "test/fixture/provider_dynamic_nodes/node-refusal-matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    require(len(refusals) == 8 and len({row["expected_tag"] for row in refusals}) == 8, "refusal-matrix")
    corpus = json.loads((ROOT / "test/fixture/provider_dynamic_nodes/run-owned-sweep-corpus.json").read_text(encoding="utf-8"))
    require(corpus["expectedEphemeralLeakIds"] == ["eni-tagged", "log-untagged", "elb-untagged"] and corpus["permittedDurableIds"] == ["vol-durable"], "sweep-corpus")
    return {"name": "independent-oracles", "command": "Dhall/text/JSON/TSV oracle validation", "output": "topology, negatives, sweep, identities, refusals valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schema") == "amoebius.phase47.provider-dynamic-live.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable, newline=True), "live-evidence-digest")
    require(live.get("scopedBoundary") == "retained kind ConfigMap reconcile and ownership-sweep analogue; not an AWS node or leak-free provider result", "scoped-boundary")
    cycles = live.get("signalCycles", [])
    require([row.get("signalClass") for row in cycles] == ["workflow-completion", "load"], "signal-classes")
    for row in cycles:
        require({key: row.get(key) for key in ("declaredTargetEdits", "nodesBefore", "nodesWhileActive", "nodesAfterRecede", "stablePassKubernetesMutations", "unreachableOutcome", "mutationsWhileUnreachable")} == {"declaredTargetEdits": 0, "nodesBefore": 1, "nodesWhileActive": 2, "nodesAfterRecede": 1, "stablePassKubernetesMutations": 0, "unreachableOutcome": "RefuseOnUnreachable", "mutationsWhileUnreachable": 0}, f"signal-cycle:{row.get('signalClass')}")
        joined = row.get("joined", {})
        require(joined.get("ordinal") == 1 and joined.get("providerInstanceIdentity") == "account-fp/amoebius-p47/cpu-balanced/1" and joined.get("quarantinedBeforeAdmission") and joined.get("supplyLayoutDevicesComplete") and joined.get("schedulerGeneration") == "generation-47" and joined.get("authorityComplete"), "join-readback")
    sweep = live.get("runOwnedSweep", {})
    require(sweep == {"boundary": "Kubernetes metadata ownership analogue; not AWS Describe evidence", "runOwnedEphemeralIds": ["elb-untagged", "eni-tagged", "log-untagged"], "tagOnlyEphemeralIds": ["eni-tagged"], "untaggedOrphansCaught": 2, "permittedDurableIds": ["volume-durable"]}, "run-owned-sweep")
    provider = live.get("providerMaterialization", {})
    provider_keys = ("eksCluster", "realManagedNode", "signalCorrelatedRunInstances", "cloudNoOpAudit", "awsRunOwnedDescribeSweep", "ephemeralProviderLeakFreedom", "durableEbsSoleSurvivor", "secondFullProviderCycle")
    require({provider.get(key) for key in provider_keys} == {"UNVERIFIED"}, "provider-honesty")
    require(live.get("deferred") == {"elevatedDurableEbsReclamation": "UNVERIFIED until Phase 54", "spotCostSignal": "UNVERIFIED"}, "deferred")
    require(live.get("cleanup") == {"phase47NamespaceAbsent": True, "auditNamespaceAbsent": True, "providerResources": "none-created"}, "cleanup")
    require(live.get("universalLinuxCpu") == {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "universal-linux-cpu-and-pristine-routing")
    require(not re.search(r"(?i)(secretAccessKey|root_token|privateKey|unseal_key|kubernetes\.jwt)", LIVE.read_text(encoding="utf-8")), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    for namespace in ("provider-dynamic-nodes-system", "provider-dynamic-nodes-audit"):
        result = subprocess.run(("/usr/bin/kubectl", "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "namespace", namespace), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60)
        require(result.returncode != 0, f"namespace-residue:{namespace}")
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-bootstrap-coordinator"], f"unexpected-kind-clusters:{clusters}")
    return {"name": "external-cleanup-readback", "command": "namespace and kind inventories", "output": "no Phase-47 namespaces; only retained amoebius-bootstrap-coordinator remains", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 47,
        "gate_command": "python3 tools/provider_dynamic_nodes_gate.py --reuse-fresh-live",
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
        rows = [invoke("runtime-source-build", (CABAL, "build", "amoebius-runtime", "-w", GHC, *flags(RUNTIME_FLAGS), "-j1", "-v0"))]
        rows.append(invoke("pulumi-source-build", (CABAL, "build", "amoebius-pulumi", "-w", GHC, *flags(PULUMI_FLAGS), "-j1", "-v0")))
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("node-provisioner-contract", runtime_args()))
        rows.append(invoke("teardown-contract", pulumi_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "scoped-signal-sweep-analogue", "command": "sealed just-produced Phase-47 live receipt", "output": "fresh scoped evidence; AWS node/leak sweep UNVERIFIED", "result": "PASS"})
        else:
            rows.append(invoke("scoped-signal-sweep-analogue", (sys.executable, "tools/provider_dynamic_nodes_live.py"), timeout=1200))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        live_reader = (CABAL, "test", "provider-dynamic-nodes-live", "-w", GHC, "--test-show-details=direct", "-j1", "-v0")
        rows.append(invoke("sealed-live-reader", live_reader))
        for flag, marker in RUNTIME_MUTANTS.items():
            rows.append(reject_mutant(runtime_args(flag), marker))
        for flag, marker in PULUMI_MUTANTS.items():
            rows.append(reject_mutant(pulumi_args(flag), marker))
        rows.append(invoke("baseline-restored-node-contract", runtime_args()))
        rows.append(invoke("baseline-restored-teardown-contract", pulumi_args()))
        rows.append(invoke("baseline-restored-live-reader", live_reader))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase47.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "signalClasses": ["workflow-completion", "load"], "runOwnedAnalogueOrphans": 3,
            "tagOnlyAnalogueOrphans": 1, "awsNodeLeakSweep": "UNVERIFIED",
            "phaseStatus": "PARTIAL_EXTERNAL_AUTHORITY",
            "mutantsRed": [*RUNTIME_MUTANTS.values(), *PULUMI_MUTANTS.values()], "result": "PASS_SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-47-SCOPED-GATE PASS {derived['ledger_hash']}\nAWS-NODE-LEAK-SWEEP UNVERIFIED\n", encoding="utf-8")
        print(f"provider-dynamic-nodes-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; AWS node/leak sweep UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"provider-dynamic-nodes-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
