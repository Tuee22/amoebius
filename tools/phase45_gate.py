#!/usr/bin/env python3
"""Run and seal the locally dischargeable Phase-45 gate domains."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_45"
LIVE = EVIDENCE / "provider-child-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_45_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_45_ledger.json"
MANIFEST = ROOT / "test/phase0_oracle_manifest.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
MUTANT_FLAG = "phase45-public-pull-mutant"
MUTANT_MARKER = "mut-45.1-public-pull"
UNVERIFIED = {
    "real-eks-child", "real-managed-node", "provider-cloud-loadbalancer",
    "full-standard-service-reachability", "full-standard-service-ha",
    "provider-wild-ingress-only-via-keycloak", "os-boundary-no-helm-observer",
    "os-boundary-no-public-pull-network-observer", "os-boundary-second-pass-cloud-audit",
    "actual-managed-eks-host-foreclosure-readback", "leak-free-provider-tag-sweep",
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
    environment = {**os.environ, **(extra_env or {})}
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def flags(enabled: bool = False) -> tuple[str, str]:
    return (f"-f{'-' if not enabled else ''}{MUTANT_FLAG}",)


def contract_args(enabled: bool = False) -> tuple[str, ...]:
    return (
        CABAL, "test", "amoebius-runtime:provider-child-bringup-contract", "-w", GHC,
        *flags(enabled), "--test-show-details=direct", "-j1", "-v0",
    )


def live_reader_args() -> tuple[str, ...]:
    return (CABAL, "test", "amoebius-runtime:provider-child-bringup-live", "-w", GHC, *flags(False), "--test-show-details=direct", "-j1", "-v0")


def reject_mutant() -> dict[str, str]:
    arguments = contract_args(True)
    result = subprocess.run(
        arguments, cwd=ROOT, env=os.environ, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, "public-pull-mutant-green")
    require(MUTANT_MARKER in result.stdout, f"public-pull-mutant-wrong-red:{result.stdout}")
    return {"name": "M-public-pull", "command": shlex.join(arguments), "output": MUTANT_MARKER, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("45\t")]
    require(len(rows) == 7, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 6, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 1, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read test/phase0_oracle_manifest.tsv", "output": "6 oracles; 1 mutant", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    result = subprocess.run(
        (DHALL_TO_JSON, "--file", "test/dhall/phase_45_provider_provision.dhall"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(result.returncode == 0, f"provider-child-dhall:{result.stdout}")
    topology = json.loads(result.stdout)
    child = topology.get("child", {})
    require(topology.get("substrate") == "linux-cpu" and topology.get("targetClass") == "provider:aws-eks", "topology")
    require(child.get("hostSubstrate") is None and child.get("singletonPods") == child.get("capacitySchedulerPods") == 1, "hostless-topology")
    require(child.get("hostDaemonPods") == child.get("hostNodePortPeers") == 0, "hostless-counts")
    expected_services = sorted(line.strip() for line in (ROOT / "test/goldens/standard_service_set.txt").read_text(encoding="utf-8").splitlines() if line.strip())
    require(sorted(topology.get("standardServices", [])) == expected_services and len(expected_services) == 16, "service-oracle")
    convergence = (ROOT / "test/goldens/convergence_argv.txt").read_text(encoding="utf-8")
    require("forbidden-tool=helm" in convergence and "forbidden-image-source=docker.io/" in convergence, "convergence-oracle")
    sequence = (ROOT / "test/goldens/lease_handoff_sequence.txt").read_text(encoding="utf-8").splitlines()
    require(len(sequence) == 6 and "freshly observed holder absent" in sequence[3], "lease-sequence-oracle")
    pairs = json.loads((ROOT / "test/fixtures/phase45/hostless-topology-pairs.json").read_text(encoding="utf-8"))
    require(pairs["managedEks"]["expectedTag"] == "NoHostSubstrateOnManagedEks" and pairs["selfManaged"]["hostWitness"] == "linux-cpu", "topology-pairs")
    rows = list(csv.DictReader((ROOT / "test/fixtures/phase45/bootstrap-negative-tags.tsv").open(encoding="utf-8"), delimiter="\t"))
    require(len(rows) == 8 and len({row["expected_tag"] for row in rows}) == 8, "negative-tag-matrix")
    require(topology.get("universalLinuxCpu", {}).get("availableOnEveryHardwareSubstrate") is True, "universal-linux-cpu")
    return {"name": "independent-oracles", "command": "Dhall/text/JSON/TSV pin validation", "output": "topology, services, argv, Lease sequence, host pair, refusal tags valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schema") == "amoebius.phase45.provider-child-live.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable, newline=True), "live-evidence-digest")
    require(live.get("scopedBoundary") == "retained kind Kubernetes API emulating ManagedEks child shape; not an EKS result", "scoped-boundary")
    bootstrap = live.get("bootstrap", {})
    require(bootstrap.get("witness") == "BootstrapCapacitySchedulerReady" and bootstrap.get("pods") == 1, "bootstrap")
    cutover = live.get("cutover", [])
    require(len(cutover) == 4 and {row.get("name") for row in cutover} == {"coredns", "aws-node", "kube-proxy", "ebs-csi-controller"}, "cutover-domain")
    require(all(row.get("oldUidAbsent") and row.get("oldResourcesReleased") and row.get("reservationJoined") and row.get("boundReady") for row in cutover), "cutover-readback")
    managed = live.get("managed", {})
    require(managed == {"admission": True, "exclusiveBindingRbac": True, "taint": True, "witness": "ManagedCapacityReady", "writerDomainExact": True}, "managed-ready")
    handoff = live.get("handoff", {})
    sequence = handoff.get("sequence", [])
    require([row.get("event") for row in sequence] == ["parent-holder", "child-applied-non-serving", "fresh-holder-absence", "child-holder", "child-ready"], "handoff-sequence")
    require(sequence[0].get("uid") == sequence[2].get("uid") == sequence[3].get("uid"), "lease-uid-stability")
    require(len({sequence[0].get("resourceVersion"), sequence[2].get("resourceVersion"), sequence[3].get("resourceVersion")}) == 3, "lease-resource-versions")
    require(sequence[1].get("readyReplicas") == 0 and sequence[4].get("readyReplicas") == 1, "singleton-serving-order")
    require(handoff.get("parentMutationsAfterRelease") == handoff.get("childMutationsBeforeAcquire") == 0, "mutation-order")
    expected_services = sorted(line.strip() for line in (ROOT / "test/goldens/standard_service_set.txt").read_text(encoding="utf-8").splitlines() if line.strip())
    require(live.get("services") == expected_services, "service-set")
    second = live.get("secondPass", {})
    require(second == {"deploymentCount": 2, "mutatingCloudCalls": 0, "mutatingKubernetesCalls": 0, "reservationCount": 4, "serviceCount": 16}, "second-pass")
    topology = live.get("topology", {})
    require({key: topology.get(key) for key in ("singletonRoles", "capacitySchedulerRoles", "hostDaemonRoles", "hostNodePortPeers", "hostSubstrate")} == {"singletonRoles": 1, "capacitySchedulerRoles": 1, "hostDaemonRoles": 0, "hostNodePortPeers": 0, "hostSubstrate": None}, "hostless-object-topology")
    image = live.get("imageObservation", {})
    require(image.get("pullPolicies") == ["Never"] and image.get("publicRegistryEvents") == 0, "image-observation")
    provider = live.get("providerMaterialization", {})
    require({provider.get(key) for key in ("eksChild", "managedNode", "cloudLoadBalancer", "fullStandardServiceReachability", "fullStandardServiceHa", "wildIngressOnlyViaKeycloakOnProvider")} == {"UNVERIFIED"}, "provider-honesty")
    require(live.get("cleanup") == {"namespaceAbsent": True, "providerResources": "none-created"}, "cleanup")
    require(live.get("universalLinuxCpu") == {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "universal-linux-cpu-and-pristine-routing")
    require(not re.search(r"(?i)(secretAccessKey|root_token|privateKey|unseal_key|kubernetes\.jwt)", LIVE.read_text(encoding="utf-8")), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    namespace = subprocess.run(("/usr/bin/kubectl", "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "namespace", "phase45-system"), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60)
    require(namespace.returncode != 0, "phase45-namespace-residue")
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-phase24"], f"unexpected-kind-clusters:{clusters}")
    return {"name": "external-cleanup-readback", "command": "namespace and kind inventories", "output": "only retained amoebius-phase24 remains", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 45, "gate_command": "python3 tools/phase45_gate.py --reuse-fresh-live",
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
        rows = [invoke("source-build", (CABAL, "build", "amoebius:dsl-core", "amoebius-runtime", "-w", GHC, *flags(False), "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("pure-contract", contract_args(False)))
        if args.reuse_fresh_live:
            rows.append({"name": "scoped-kubernetes-child", "command": "sealed just-produced Phase-45 live receipt", "output": "fresh scoped evidence; EKS convergence UNVERIFIED", "result": "PASS"})
        else:
            rows.append(invoke("scoped-kubernetes-child", (sys.executable, "tools/phase45_provider_child_live.py"), timeout=1800))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        rows.append(invoke("sealed-live-reader", live_reader_args()))
        rows.append(reject_mutant())
        rows.append(invoke("baseline-restored-contract", contract_args(False)))
        rows.append(invoke("baseline-restored-live-reader", live_reader_args()))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase45.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "addOnCutovers": 4, "standardServiceObjects": 16, "secondPassKubernetesMutations": 0,
            "eksConvergence": "UNVERIFIED", "phaseStatus": "PARTIAL_EXTERNAL_AUTHORITY",
            "mutantsRed": ["M-public-pull"], "result": "PASS_SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-45-SCOPED-GATE PASS {derived['ledger_hash']}\nEKS-CONVERGENCE UNVERIFIED\n", encoding="utf-8")
        print(f"phase45-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; EKS convergence UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase45-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
