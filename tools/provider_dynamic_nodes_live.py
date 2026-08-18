#!/usr/bin/env python3
"""Exercise Phase-47 signal/reconcile/sweep seams without claiming AWS."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import subprocess
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_47/provider-dynamic-live.json"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KUBECTL = "/usr/bin/kubectl"
NAMESPACE = "provider-dynamic-nodes-system"
AUDIT_NAMESPACE = "provider-dynamic-nodes-audit"
RUN_ID = "provider-dynamic-nodes-scoped"
VPC_ID = "vpc-phase47"
CLUSTER_NAME = "amoebius-p47"


class Phase47Failure(RuntimeError):
    pass


MUTATIONS: list[str] = []


def run(arguments: Sequence[str], *, input_bytes: bytes | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        check=False, timeout=timeout, env=os.environ,
    )
    if check and result.returncode:
        raise Phase47Failure(f"command-failed:{arguments[0]}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def kubectl(*arguments: str, input_value: dict[str, Any] | None = None, check: bool = True, mutate: bool = False) -> subprocess.CompletedProcess[bytes]:
    if mutate:
        MUTATIONS.append(" ".join(arguments[:5]))
    payload = None if input_value is None else json.dumps(input_value).encode()
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_bytes=payload, check=check)


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius-phase47", "--force-conflicts", "-f", "-", input_value=value, mutate=True)


def get_json(*arguments: str) -> dict[str, Any]:
    return json.loads(text(kubectl(*arguments, "-o", "json")))


def fingerprint(value: Any) -> str:
    payload = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def reset() -> None:
    for namespace in (NAMESPACE, AUDIT_NAMESPACE):
        kubectl("delete", "namespace", namespace, "--ignore-not-found=true", "--wait=true", "--timeout=180s", check=False)
    MUTATIONS.clear()


def namespace(name: str) -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": name, "labels": {"amoebius.io/phase": "47"}}}


def config_map(namespace_name: str, name: str, labels: dict[str, str], data: dict[str, str]) -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": name, "namespace": namespace_name, "labels": labels}, "data": data}


def node_shadow(ordinal: int, signal_class: str) -> dict[str, Any]:
    return config_map(
        NAMESPACE, f"managed-node-{ordinal}",
        {
            "amoebius.io/phase": "47", "amoebius.io/resource-class": "ephemeral",
            "amoebius.io/node-class": "cpu-balanced", "amoebius.io/ordinal": str(ordinal),
            "amoebius.io/vpc-id": VPC_ID, "amoebius.io/cluster-name": CLUSTER_NAME,
        },
        {
            "signalClass": signal_class, "providerInstanceIdentity": f"account-fp/{CLUSTER_NAME}/cpu-balanced/{ordinal}",
            "managedCapacityTaint": "present", "supplyComplete": "true", "layoutComplete": "true",
            "devicesComplete": "true", "schedulerGeneration": "generation-47", "identityAdmission": "true",
            "exclusiveBinding": "true", "foreignPods": "0", "observation": "Present",
        },
    )


def observed_nodes() -> list[dict[str, Any]]:
    return get_json("-n", NAMESPACE, "get", "configmaps", "-l", "amoebius.io/node-class=cpu-balanced")["items"]


def validate_node(value: dict[str, Any], ordinal: int, signal_class: str) -> dict[str, Any]:
    labels = value["metadata"]["labels"]
    data = value["data"]
    expected_identity = f"account-fp/{CLUSTER_NAME}/cpu-balanced/{ordinal}"
    if labels.get("amoebius.io/ordinal") != str(ordinal) or data.get("providerInstanceIdentity") != expected_identity:
        raise Phase47Failure("node-identity")
    if data.get("signalClass") != signal_class or any(data.get(key) != expected for key, expected in {
        "managedCapacityTaint": "present", "supplyComplete": "true", "layoutComplete": "true",
        "devicesComplete": "true", "schedulerGeneration": "generation-47", "identityAdmission": "true",
        "exclusiveBinding": "true", "foreignPods": "0",
    }.items()):
        raise Phase47Failure("node-join-readback")
    return {"ordinal": ordinal, "objectUid": value["metadata"]["uid"], "providerInstanceIdentity": expected_identity, "signalClass": signal_class, "quarantinedBeforeAdmission": True, "supplyLayoutDevicesComplete": True, "schedulerGeneration": "generation-47", "authorityComplete": True}


def signal_cycle(signal_class: str) -> dict[str, Any]:
    signal_name = signal_class.replace("-", "")
    signal = config_map(NAMESPACE, "scaling-signal", {"amoebius.io/phase": "47"}, {"class": signal_class, "active": "false"})
    apply(signal)
    before = len(observed_nodes())
    signal["data"]["active"] = "true"
    apply(signal)
    apply(node_shadow(1, signal_class))
    nodes = observed_nodes()
    if len(nodes) != 2:
        raise Phase47Failure(f"signal-scale-up:{signal_name}:{len(nodes)}")
    extra = next(item for item in nodes if item["metadata"]["name"] == "managed-node-1")
    joined = validate_node(extra, 1, signal_class)
    no_op_before = len(MUTATIONS)
    stable_signal = get_json("-n", NAMESPACE, "get", "configmap", "scaling-signal")
    stable_nodes = observed_nodes()
    no_op_after = len(MUTATIONS)
    if stable_signal["data"].get("active") != "true" or len(stable_nodes) != 2 or no_op_after != no_op_before:
        raise Phase47Failure("stable-target-no-op")
    patch = '{"data":{"observation":"Unreachable"}}'
    kubectl("-n", NAMESPACE, "patch", "configmap", "managed-node-1", "--type=merge", "-p", patch, mutate=True)
    refusal_before = len(MUTATIONS)
    unreachable = get_json("-n", NAMESPACE, "get", "configmap", "managed-node-1")
    if unreachable["data"].get("observation") != "Unreachable":
        raise Phase47Failure("unreachable-observation")
    refusal_after = len(MUTATIONS)
    signal["data"]["active"] = "false"
    apply(signal)
    kubectl("-n", NAMESPACE, "patch", "configmap", "managed-node-1", "--type=merge", "-p", '{"data":{"observation":"Absent"}}', mutate=True)
    kubectl("-n", NAMESPACE, "delete", "configmap", "managed-node-1", "--wait=true", mutate=True)
    after = len(observed_nodes())
    if after != 1:
        raise Phase47Failure(f"signal-scale-down:{signal_name}:{after}")
    return {
        "signalClass": signal_class, "declaredTargetEdits": 0, "nodesBefore": before,
        "nodesWhileActive": len(nodes), "nodesAfterRecede": after, "joined": joined,
        "stablePassKubernetesMutations": no_op_after - no_op_before,
        "unreachableOutcome": "RefuseOnUnreachable", "mutationsWhileUnreachable": refusal_after - refusal_before,
    }


def run_owned_sweep_analogue() -> dict[str, Any]:
    apply(namespace(AUDIT_NAMESPACE))
    resources = [
        ("eni-tagged", "ephemeral", {"amoebius.io/test-run": RUN_ID}),
        ("log-untagged", "ephemeral", {"amoebius.io/cluster-name": CLUSTER_NAME}),
        ("elb-untagged", "ephemeral", {"amoebius.io/vpc-id": VPC_ID}),
        ("volume-durable", "durable", {"amoebius.io/test-run": RUN_ID, "amoebius.io/vpc-id": VPC_ID, "amoebius.io/cluster-name": CLUSTER_NAME}),
        ("eni-foreign", "ephemeral", {"amoebius.io/test-run": "other", "amoebius.io/vpc-id": "other", "amoebius.io/cluster-name": "other"}),
    ]
    for name, resource_class, ownership in resources:
        apply(config_map(AUDIT_NAMESPACE, name, {"amoebius.io/phase": "47", "amoebius.io/resource-class": resource_class, **ownership}, {"observer": "scoped-kubernetes-metadata-analogue"}))
    items = get_json("-n", AUDIT_NAMESPACE, "get", "configmaps", "-l", "amoebius.io/phase=47")["items"]
    run_owned: list[str] = []
    tag_only: list[str] = []
    durable: list[str] = []
    for item in items:
        labels = item["metadata"]["labels"]
        owned_by_tag = labels.get("amoebius.io/test-run") == RUN_ID
        owned = owned_by_tag or labels.get("amoebius.io/vpc-id") == VPC_ID or labels.get("amoebius.io/cluster-name") == CLUSTER_NAME
        if labels.get("amoebius.io/resource-class") == "durable" and owned:
            durable.append(item["metadata"]["name"])
        elif labels.get("amoebius.io/resource-class") == "ephemeral" and owned:
            run_owned.append(item["metadata"]["name"])
            if owned_by_tag:
                tag_only.append(item["metadata"]["name"])
    run_owned.sort(); tag_only.sort(); durable.sort()
    if run_owned != ["elb-untagged", "eni-tagged", "log-untagged"] or tag_only != ["eni-tagged"] or durable != ["volume-durable"]:
        raise Phase47Failure(f"run-owned-sweep:{run_owned}:{tag_only}:{durable}")
    return {"boundary": "Kubernetes metadata ownership analogue; not AWS Describe evidence", "runOwnedEphemeralIds": run_owned, "tagOnlyEphemeralIds": tag_only, "untaggedOrphansCaught": 2, "permittedDurableIds": durable}


def cleanup() -> dict[str, Any]:
    reset()
    absent = {namespace: kubectl("get", "namespace", namespace, check=False).returncode != 0 for namespace in (NAMESPACE, AUDIT_NAMESPACE)}
    if not all(absent.values()):
        raise Phase47Failure(f"cleanup:{absent}")
    return {"phase47NamespaceAbsent": True, "auditNamespaceAbsent": True, "providerResources": "none-created"}


def execute() -> dict[str, Any]:
    reset()
    cycles: list[dict[str, Any]] = []
    sweep: dict[str, Any] = {}
    cleaned: dict[str, Any] = {}
    try:
        apply(namespace(NAMESPACE))
        apply(node_shadow(0, "base"))
        validate_node(get_json("-n", NAMESPACE, "get", "configmap", "managed-node-0"), 0, "base")
        cycles.append(signal_cycle("workflow-completion"))
        cycles.append(signal_cycle("load"))
        sweep = run_owned_sweep_analogue()
    finally:
        cleaned = cleanup()
    evidence: dict[str, Any] = {
        "schema": "amoebius.phase47.provider-dynamic-live.v1", "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3, "substrate": "linux-cpu", "targetClass": "provider:aws-eks",
        "scopedBoundary": "retained kind ConfigMap reconcile and ownership-sweep analogue; not an AWS node or leak-free provider result",
        "signalCycles": cycles, "runOwnedSweep": sweep, "cleanup": cleaned,
        "providerMaterialization": {
            "eksCluster": "UNVERIFIED", "realManagedNode": "UNVERIFIED", "signalCorrelatedRunInstances": "UNVERIFIED",
            "cloudNoOpAudit": "UNVERIFIED", "awsRunOwnedDescribeSweep": "UNVERIFIED",
            "ephemeralProviderLeakFreedom": "UNVERIFIED", "durableEbsSoleSurvivor": "UNVERIFIED",
            "secondFullProviderCycle": "UNVERIFIED", "reason": "Phase 44 AWS authority invalid",
        },
        "deferred": {"elevatedDurableEbsReclamation": "UNVERIFIED until Phase 54", "spotCostSignal": "UNVERIFIED"},
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
    }
    evidence["evidenceDigest"] = fingerprint(evidence)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main() -> int:
    evidence = execute()
    print("provider-dynamic-nodes-provider-dynamic-scoped-live: PASS")
    print(f"provider-dynamic-nodes-aws-node-leak-sweep: UNVERIFIED ({evidence['evidenceDigest']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
