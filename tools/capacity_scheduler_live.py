#!/usr/bin/env python3
"""Exercise the Phase-32 scheduler cutover against the Phase-30 kind cluster."""

from __future__ import annotations

import argparse
import concurrent.futures
import copy
import hashlib
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path(os.environ.get(
    "AMOEBIUS_KUBECONFIG",
    str(ROOT / ".build/tmp/capacity-scheduler/unconfigured-kubeconfig"),
))
KUBECTL = os.environ.get("AMOEBIUS_KUBECTL", "/usr/bin/kubectl")
SYSTEM_NAMESPACE = "amoebius-capacity-scheduler"
NAMESPACE = "amoebius-phase27-gate"
RACE_NAMESPACE = "amoebius-phase27-race"
CRD = "capacityreservations.amoebius.io"
BOOTSTRAP_POLICY = "amoebius-phase27-bootstrap-guard"
BOOTSTRAP_POLICY_BINDING = "amoebius-phase27-bootstrap-guard"
POLICY = "amoebius-phase27-execution-identity"
POLICY_BINDING = "amoebius-phase27-execution-identity"
CLUSTER_ROLE = "amoebius-phase27-binding"
CLUSTER_ROLE_BINDING = "amoebius-phase27-binding"
OWNER = "phase27-live-gate"
GENERATION = "phase27-generation-1"
CONFIG_DIGEST = "sha256:fd5c9e99104e9baee88947825f0658d19ef43d62219fdfc692174fcaa71acc12"
# The digest Phase 31 published on the run that stood the in-cluster registry up,
# supplied by the caller: a constant here named a build that no longer exists, so every
# scheduled Pod would have failed `ImagePull` on any host but the one that produced it.
IMAGE = ""
TAINT_KEY = "amoebius.io/managed-capacity"
SCHEDULER_NAME = "amoebius-capacity"


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, stdin: str | None = None, check: bool = True, timeout: int = 360) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, input=stdin, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        raise LiveFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 360) -> subprocess.CompletedProcess[str]:
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), stdin=stdin, check=check, timeout=timeout)


def metadata(name: str, *, namespace: str | None = NAMESPACE, labels: dict[str, str] | None = None) -> dict[str, Any]:
    value: dict[str, Any] = {
        "name": name,
        "labels": {"app.kubernetes.io/managed-by": "amoebius", "amoebius.io/owner": OWNER, **(labels or {})},
        "annotations": {"amoebius.io/generation": GENERATION},
    }
    if namespace is not None:
        value["namespace"] = namespace
    return value


def apply(values: list[dict[str, Any]], manager: str = "amoebius-phase27-bootstrap") -> None:
    payload = {"apiVersion": "v1", "kind": "List", "items": values}
    kubectl("apply", "--server-side", f"--field-manager={manager}", "--force-conflicts", "-f", "-", stdin=json.dumps(payload))


def create(value: dict[str, Any], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return kubectl("create", "-f", "-", stdin=json.dumps(value), check=check)


def replace(value: dict[str, Any], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return kubectl("replace", "-f", "-", stdin=json.dumps(value), check=check)


def get(kind: str, name: str, *, namespace: str | None = NAMESPACE, managed: bool = False) -> dict[str, Any]:
    prefix = ("-n", namespace) if namespace is not None else ()
    extra = ("--show-managed-fields",) if managed else ()
    return json.loads(kubectl(*prefix, "get", kind, name, "-o", "json", *extra).stdout)


def list_objects(kind: str, *, namespace: str = NAMESPACE, selector: str | None = None) -> list[dict[str, Any]]:
    arguments = ["-n", namespace, "get", kind]
    if selector is not None:
        arguments.extend(("-l", selector))
    arguments.extend(("-o", "json"))
    return list(json.loads(kubectl(*arguments).stdout).get("items", []))


def canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def resources() -> dict[str, Any]:
    return {
        "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "16Mi"},
        "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
    }


def toleration() -> dict[str, str]:
    return {"key": TAINT_KEY, "operator": "Equal", "value": "true", "effect": "NoSchedule"}


def protected_annotations(deployment: str) -> dict[str, str]:
    return {
        "amoebius.io/deployment": deployment,
        "amoebius.io/generation": GENERATION,
        "amoebius.io/source": "phase27-live-corpus",
        "amoebius.io/revision": "1",
        "amoebius.io/reservation-template": "sha256:phase27-live-template",
    }


def container(name: str, *, readiness_delay: int) -> dict[str, Any]:
    return {
        "name": name, "image": IMAGE, "imagePullPolicy": "IfNotPresent",
        "command": ["/bin/sh", "-c", "exec /usr/bin/sleep 3600"],
        "readinessProbe": {
            "exec": {"command": ["/usr/bin/redis-cli", "--version"]},
            "initialDelaySeconds": readiness_delay, "periodSeconds": 1,
        },
        "resources": resources(),
    }


def namespace(name: str) -> dict[str, Any]:
    labels = {"amoebius.io/phase27-gate": "true"} if name == NAMESPACE else {}
    return {"apiVersion": "v1", "kind": "Namespace", "metadata": metadata(name, namespace=None, labels=labels)}


def reservation_crd() -> dict[str, Any]:
    return {
        "apiVersion": "apiextensions.k8s.io/v1", "kind": "CustomResourceDefinition",
        "metadata": metadata(CRD, namespace=None),
        "spec": {
            "group": "amoebius.io", "scope": "Namespaced",
            "names": {"plural": "capacityreservations", "singular": "capacityreservation", "kind": "CapacityReservation"},
            "versions": [{
                "name": "v1", "served": True, "storage": True,
                "schema": {"openAPIV3Schema": {
                    "type": "object", "properties": {
                        "spec": {
                            "type": "object",
                            "properties": {
                                "podName": {"type": "string"}, "podUid": {"type": "string"},
                                "nodeName": {"type": "string"},
                                "state": {"type": "string", "enum": ["Reserved", "BindingInFlight", "Bound", "Terminating", "TerminalRetained"]},
                                "generation": {"type": "string"}, "templateDigest": {"type": "string"},
                                "debit": {
                                    "type": "object", "properties": {
                                        "cpuMilli": {"type": "integer"}, "memoryMi": {"type": "integer"},
                                        "ephemeralMi": {"type": "integer"}, "storageMi": {"type": "integer"},
                                        "pods": {"type": "integer"}, "etcdBytes": {"type": "integer"},
                                    },
                                    "required": ["cpuMilli", "memoryMi", "ephemeralMi", "storageMi", "pods", "etcdBytes"],
                                },
                            },
                            "required": ["podName", "podUid", "nodeName", "state", "generation", "templateDigest", "debit"],
                        },
                    }, "required": ["spec"],
                }},
            }],
        },
    }


def admission_policy() -> tuple[dict[str, Any], dict[str, Any]]:
    guarded = '"amoebius.io/guarded" in object.metadata.labels'
    bootstrap = '"amoebius.io/bootstrap-addon" in object.metadata.labels'
    namespace_ready = '("amoebius.io/managed-capacity-ready" in namespaceObject.metadata.labels && namespaceObject.metadata.labels["amoebius.io/managed-capacity-ready"] == "true")'
    identity = " && ".join(
        f'"{key}" in object.metadata.annotations' for key in (
            "amoebius.io/deployment", "amoebius.io/generation", "amoebius.io/source",
            "amoebius.io/revision", "amoebius.io/reservation-template",
        )
    )
    policy = {
        "apiVersion": "admissionregistration.k8s.io/v1", "kind": "ValidatingAdmissionPolicy",
        "metadata": metadata(BOOTSTRAP_POLICY, namespace=None),
        "spec": {
            "failurePolicy": "Fail", "matchConstraints": {"resourceRules": [{
                "apiGroups": [""], "apiVersions": ["v1"], "operations": ["CREATE", "UPDATE"],
                "resources": ["pods"], "scope": "Namespaced",
            }]},
            "validations": [
                {"expression": f"!({guarded}) || ({bootstrap}) || {namespace_ready}", "message": "ManagedCapacityReady is required for a general guarded workload", "reason": "Forbidden"},
                {"expression": f'!({guarded}) || object.spec.schedulerName == "{SCHEDULER_NAME}"', "message": "guarded workloads require amoebius-capacity", "reason": "Forbidden"},
                {"expression": f"!({guarded}) || ({identity})", "message": "guarded workload execution identity is incomplete", "reason": "Forbidden"},
            ],
        },
    }
    binding = {
        "apiVersion": "admissionregistration.k8s.io/v1", "kind": "ValidatingAdmissionPolicyBinding",
        "metadata": metadata(BOOTSTRAP_POLICY_BINDING, namespace=None),
        "spec": {
            "policyName": BOOTSTRAP_POLICY, "validationActions": ["Deny"],
            "matchResources": {"namespaceSelector": {"matchLabels": {"amoebius.io/phase27-gate": "true"}}},
        },
    }
    return policy, binding


def managed_identity_policy() -> tuple[dict[str, Any], dict[str, Any]]:
    guarded = '"amoebius.io/guarded" in object.metadata.labels'
    identity = " && ".join(
        f'"{key}" in object.metadata.annotations' for key in (
            "amoebius.io/deployment", "amoebius.io/generation", "amoebius.io/source",
            "amoebius.io/revision", "amoebius.io/reservation-template",
        )
    )
    policy = {
        "apiVersion": "admissionregistration.k8s.io/v1", "kind": "ValidatingAdmissionPolicy",
        "metadata": metadata(POLICY, namespace=None),
        "spec": {
            "failurePolicy": "Fail", "matchConstraints": {"resourceRules": [{
                "apiGroups": [""], "apiVersions": ["v1"], "operations": ["CREATE", "UPDATE"],
                "resources": ["pods"], "scope": "Namespaced",
            }]},
            "validations": [
                {"expression": f'!({guarded}) || object.spec.schedulerName == "{SCHEDULER_NAME}"', "message": "guarded workloads require amoebius-capacity", "reason": "Forbidden"},
                {"expression": f"!({guarded}) || ({identity})", "message": "guarded workload execution identity is incomplete", "reason": "Forbidden"},
            ],
        },
    }
    binding = {
        "apiVersion": "admissionregistration.k8s.io/v1", "kind": "ValidatingAdmissionPolicyBinding",
        "metadata": metadata(POLICY_BINDING, namespace=None),
        "spec": {
            "policyName": POLICY, "validationActions": ["Deny"],
            "matchResources": {"namespaceSelector": {"matchLabels": {"amoebius.io/phase27-gate": "true"}}},
        },
    }
    return policy, binding


def service_account() -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "ServiceAccount", "metadata": metadata("amoebius-capacity", namespace=SYSTEM_NAMESPACE)}


def restricted_cutover_role() -> tuple[dict[str, Any], dict[str, Any]]:
    role = {
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "Role", "metadata": metadata("bootstrap-cutover", namespace=NAMESPACE),
        "rules": [{"apiGroups": ["apps"], "resources": ["deployments"], "resourceNames": ["bootstrap-addon"], "verbs": ["get", "patch", "update"]}],
    }
    binding = {
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "RoleBinding", "metadata": metadata("bootstrap-cutover", namespace=NAMESPACE),
        "subjects": [{"kind": "ServiceAccount", "name": "amoebius-capacity", "namespace": SYSTEM_NAMESPACE}],
        "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "Role", "name": "bootstrap-cutover"},
    }
    return role, binding


def full_binding_authority() -> tuple[dict[str, Any], dict[str, Any]]:
    role = {
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole", "metadata": metadata(CLUSTER_ROLE, namespace=None),
        "rules": [
            {"apiGroups": [""], "resources": ["pods"], "verbs": ["get", "list", "watch"]},
            {"apiGroups": [""], "resources": ["bindings", "pods/binding"], "verbs": ["create"]},
            {"apiGroups": ["amoebius.io"], "resources": ["capacityreservations"], "verbs": ["get", "list", "watch", "create", "update", "patch"]},
        ],
    }
    binding = {
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding", "metadata": metadata(CLUSTER_ROLE_BINDING, namespace=None),
        "subjects": [{"kind": "ServiceAccount", "name": "amoebius-capacity", "namespace": SYSTEM_NAMESPACE}],
        "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": CLUSTER_ROLE},
    }
    return role, binding


def scheduler_system_objects(node_name: str) -> list[dict[str, Any]]:
    quota = {
        "apiVersion": "v1", "kind": "ResourceQuota", "metadata": metadata("scheduler-pods", namespace=SYSTEM_NAMESPACE),
        "spec": {"hard": {"pods": "1"}},
    }
    config = {
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": metadata("scheduler-config", namespace=SYSTEM_NAMESPACE),
        "data": {"generation": GENERATION, "configDigest": CONFIG_DIGEST, "schedulerName": SCHEDULER_NAME},
    }
    root = {
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": metadata("aggregate-reservation-root", namespace=SYSTEM_NAMESPACE),
        "data": {"casVersion": "0", "generation": GENERATION, "capacityModel": "whole-ledger-refold"},
    }
    lease = {
        "apiVersion": "coordination.k8s.io/v1", "kind": "Lease", "metadata": metadata("amoebius-reconciler", namespace=SYSTEM_NAMESPACE),
        "spec": {"holderIdentity": "phase26-bootstrap-host", "leaseDurationSeconds": 300},
    }
    labels = {"app": "amoebius-capacity", "amoebius.io/bootstrap-scheduler": "true"}
    deployment = {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": metadata("amoebius-capacity", namespace=SYSTEM_NAMESPACE),
        "spec": {
            "replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": "amoebius-capacity"}},
            "template": {
                "metadata": {"labels": labels, "annotations": protected_annotations("amoebius-capacity")},
                "spec": {
                    "serviceAccountName": "amoebius-capacity", "schedulerName": "default-scheduler",
                    "affinity": {"nodeAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "kubernetes.io/hostname", "operator": "In", "values": [node_name]}]}]}}},
                    "containers": [container("scheduler", readiness_delay=1)],
                },
            },
        },
    }
    return [quota, config, root, lease, deployment]


def bootstrap_addon() -> dict[str, Any]:
    labels = {"app": "bootstrap-addon", "amoebius.io/bootstrap-addon": "true"}
    return {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": metadata("bootstrap-addon"),
        "spec": {
            "replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": "bootstrap-addon"}},
            "template": {
                "metadata": {"labels": labels, "annotations": protected_annotations("bootstrap-addon")},
                "spec": {"schedulerName": "default-scheduler", "containers": [container("addon", readiness_delay=1)]},
            },
        },
    }


def guarded_deployment() -> dict[str, Any]:
    labels = {"app": "guarded-workload", "amoebius.io/guarded": "true"}
    return {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": metadata("guarded-workload"),
        "spec": {
            "replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": "guarded-workload"}},
            "template": {
                "metadata": {"labels": labels, "annotations": protected_annotations("guarded-workload")},
                "spec": {
                    "schedulerName": SCHEDULER_NAME, "tolerations": [toleration()],
                    "containers": [container("guarded", readiness_delay=3)],
                },
            },
        },
    }


def direct_guarded_pod(name: str, *, scheduler_name: str = SCHEDULER_NAME) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Pod",
        "metadata": {**metadata(name), "labels": {"amoebius.io/phase27-gate": "true", "amoebius.io/guarded": "true"}, "annotations": protected_annotations(name)},
        "spec": {
            "schedulerName": scheduler_name, "tolerations": [toleration()],
            "restartPolicy": "Never", "containers": [container("guarded", readiness_delay=1)],
        },
    }


def wait_created(kind: str, selector: str, *, namespace_name: str = NAMESPACE, timeout: str = "120s") -> None:
    kubectl("-n", namespace_name, "wait", "--for=create", kind, "-l", selector, f"--timeout={timeout}")


def single_pod(selector: str, *, namespace_name: str = NAMESPACE) -> dict[str, Any]:
    pods = list_objects("pods", namespace=namespace_name, selector=selector)
    if len(pods) != 1:
        raise LiveFailure(f"expected-one-pod:{namespace_name}:{selector}:{len(pods)}")
    return pods[0]


def reservation(name: str, pod: dict[str, Any], node_name: str) -> dict[str, Any]:
    return {
        "apiVersion": "amoebius.io/v1", "kind": "CapacityReservation", "metadata": metadata(name),
        "spec": {
            "podName": pod["metadata"]["name"], "podUid": pod["metadata"]["uid"], "nodeName": node_name,
            "state": "Reserved", "generation": GENERATION,
            "templateDigest": protected_annotations(name)["amoebius.io/reservation-template"],
            "debit": {"cpuMilli": 10, "memoryMi": 16, "ephemeralMi": 16, "storageMi": 0, "pods": 1, "etcdBytes": 4096},
        },
    }


def observe_binding_precondition(reservation_name: str, pod_name: str) -> dict[str, Any]:
    observed = get("capacityreservation", reservation_name)
    pod = get("pod", pod_name)
    if observed["spec"]["state"] != "BindingInFlight" or pod.get("spec", {}).get("nodeName"):
        raise LiveFailure("binding-precondition-not-observed")
    return {
        "state": observed["spec"]["state"], "reservationResourceVersion": observed["metadata"]["resourceVersion"],
        "podUid": pod["metadata"]["uid"], "podNodeBeforeBinding": pod.get("spec", {}).get("nodeName", ""),
    }


def bind_protocol(reservation_name: str, pod: dict[str, Any], node_name: str, events: list[dict[str, Any]], *, crash_after_reserve: bool = False, crash_after_binding: bool = False) -> dict[str, Any]:
    pod_name = pod["metadata"]["name"]
    if pod.get("spec", {}).get("nodeName"):
        raise LiveFailure(f"pod-already-bound:{pod_name}")
    created = create(reservation(reservation_name, pod, node_name))
    if created.returncode:
        raise LiveFailure(f"reservation-create:{created.stdout}")
    reserved = get("capacityreservation", reservation_name)
    if reserved["spec"]["state"] != "Reserved":
        raise LiveFailure("reservation-not-reserved")
    events.append({"event": "ReservedCAS", "reservation": reservation_name, "resourceVersion": reserved["metadata"]["resourceVersion"]})
    restart_observed = False
    if crash_after_reserve:
        restart_readback = get("capacityreservation", reservation_name)
        restart_observed = restart_readback["metadata"]["resourceVersion"] == reserved["metadata"]["resourceVersion"] and restart_readback["spec"]["state"] == "Reserved"
        if not restart_observed:
            raise LiveFailure("crash-after-reserve-recovery-lost-debit")
    in_flight = copy.deepcopy(reserved)
    in_flight["spec"]["state"] = "BindingInFlight"
    replace(in_flight)
    precondition = observe_binding_precondition(reservation_name, pod_name)
    events.append({"event": "BindingInFlightCAS", "reservation": reservation_name, "resourceVersion": precondition["reservationResourceVersion"]})
    binding = {
        "apiVersion": "v1", "kind": "Binding", "metadata": {"name": pod_name, "namespace": NAMESPACE},
        "target": {"apiVersion": "v1", "kind": "Node", "name": node_name},
    }
    create(binding)
    bound_pod = get("pod", pod_name)
    if bound_pod.get("spec", {}).get("nodeName") != node_name or bound_pod["metadata"]["uid"] != pod["metadata"]["uid"]:
        raise LiveFailure("binding-confirmation-mismatch")
    if int(bound_pod["metadata"]["resourceVersion"]) <= int(precondition["reservationResourceVersion"]):
        raise LiveFailure("binding-resourceversion-did-not-follow-inflight-cas")
    events.append({"event": "KubernetesBinding", "reservation": reservation_name, "podResourceVersion": bound_pod["metadata"]["resourceVersion"]})
    recovery_observed = False
    if crash_after_binding:
        still_in_flight = get("capacityreservation", reservation_name)
        recovery_observed = still_in_flight["spec"]["state"] == "BindingInFlight" and get("pod", pod_name)["spec"].get("nodeName") == node_name
        if not recovery_observed:
            raise LiveFailure("crash-after-binding-recovery-not-observed")
    confirmed = get("capacityreservation", reservation_name)
    confirmed["spec"]["state"] = "Bound"
    replace(confirmed)
    final = get("capacityreservation", reservation_name)
    if final["spec"]["state"] != "Bound":
        raise LiveFailure("reservation-not-bound")
    events.append({"event": "BoundCAS", "reservation": reservation_name, "resourceVersion": final["metadata"]["resourceVersion"]})
    kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", f"pod/{pod_name}", "--timeout=300s")
    return {
        "reservation": reservation_name, "podName": pod_name, "podUid": pod["metadata"]["uid"], "nodeName": node_name,
        "reservedResourceVersion": reserved["metadata"]["resourceVersion"],
        "bindingInFlightResourceVersion": precondition["reservationResourceVersion"],
        "boundPodResourceVersion": bound_pod["metadata"]["resourceVersion"],
        "boundResourceVersion": final["metadata"]["resourceVersion"],
        "bindingAfterCas": True, "debitCount": 1, "restartAfterReserveObserved": restart_observed,
        "restartAfterBindingObserved": recovery_observed,
    }


def reservation_snapshot() -> dict[str, Any]:
    rows = list_objects("capacityreservations")
    return {
        row["metadata"]["name"]: {
            "resourceVersion": row["metadata"]["resourceVersion"], "uid": row["metadata"]["uid"], "spec": row["spec"],
        }
        for row in sorted(rows, key=lambda item: item["metadata"]["name"])
    }


def rejection_snapshot() -> dict[str, Any]:
    root = get("configmap", "aggregate-reservation-root", namespace=SYSTEM_NAMESPACE)
    lease = get("lease", "amoebius-reconciler", namespace=SYSTEM_NAMESPACE)
    return {
        "reservations": reservation_snapshot(), "rootResourceVersion": root["metadata"]["resourceVersion"],
        "leaseHolder": lease["spec"].get("holderIdentity"), "leaseResourceVersion": lease["metadata"]["resourceVersion"],
    }


def aggregate_race() -> dict[str, Any]:
    apply([namespace(RACE_NAMESPACE)])
    root = {
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": metadata("aggregate-root", namespace=RACE_NAMESPACE),
        "data": {"casVersion": "0", "availableSlots": "1", "committedCandidate": ""},
    }
    apply([root], "amoebius-phase27-race")
    observed = get("configmap", "aggregate-root", namespace=RACE_NAMESPACE)

    def contender(name: str) -> tuple[str, subprocess.CompletedProcess[str]]:
        candidate = copy.deepcopy(observed)
        candidate["data"] = {"casVersion": "1", "availableSlots": "0", "committedCandidate": name}
        return name, replace(candidate, check=False)

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        outcomes = list(executor.map(contender, ("candidate-a", "candidate-b")))
    winners = [name for name, result in outcomes if result.returncode == 0]
    conflicts = [name for name, result in outcomes if result.returncode != 0 and "the object has been modified" in result.stdout.lower()]
    final = get("configmap", "aggregate-root", namespace=RACE_NAMESPACE)
    if len(winners) != 1 or len(conflicts) != 1 or final["data"]["availableSlots"] != "0" or final["data"]["committedCandidate"] != winners[0]:
        raise LiveFailure(f"aggregate-cas-race:{winners}:{conflicts}:{final['data']}")
    return {
        "simultaneousCandidates": 2, "successfulCas": 1, "resourceVersionConflicts": 1,
        "winner": winners[0], "residualSlots": 0, "overAllocation": 0, "loserRefusedAfterRefold": True,
    }


def bootstrap_readiness(node_name: str) -> dict[str, Any]:
    scheduler = get("deployment", "amoebius-capacity", namespace=SYSTEM_NAMESPACE)
    config = get("configmap", "scheduler-config", namespace=SYSTEM_NAMESPACE)
    root = get("configmap", "aggregate-reservation-root", namespace=SYSTEM_NAMESPACE)
    lease = get("lease", "amoebius-reconciler", namespace=SYSTEM_NAMESPACE)
    quota = get("resourcequota", "scheduler-pods", namespace=SYSTEM_NAMESPACE)
    node = get("node", node_name, namespace=None)
    taint_absent = all(row.get("key") != TAINT_KEY for row in node.get("spec", {}).get("taints", []))
    full_rbac = kubectl(
        "auth", "can-i", "create", "bindings",
        "--as", f"system:serviceaccount:{SYSTEM_NAMESPACE}:amoebius-capacity", "-n", NAMESPACE,
        check=False,
    ).stdout.strip() == "yes"
    general_admission_absent = kubectl("get", "validatingadmissionpolicy", POLICY, check=False).returncode != 0
    if scheduler.get("status", {}).get("availableReplicas") != 1 or config["data"].get("configDigest") != CONFIG_DIGEST:
        raise LiveFailure("bootstrap-scheduler-readback-mismatch")
    if lease["spec"].get("holderIdentity") != "phase26-bootstrap-host" or not taint_absent or full_rbac or not general_admission_absent:
        raise LiveFailure("bootstrap-authority-ordering-mismatch")
    if quota.get("status", {}).get("hard", {}).get("pods") != "1" or quota.get("status", {}).get("used", {}).get("pods") != "1":
        raise LiveFailure("scheduler-system-quota-mismatch")
    return {
        "witness": "BootstrapCapacitySchedulerReady", "schedulerAvailable": True,
        "generation": config["data"]["generation"], "configDigest": config["data"]["configDigest"],
        "rootResourceVersion": root["metadata"]["resourceVersion"], "managedTaintAbsent": True,
        "bootstrapAdmissionGuardPresent": True, "generalAdmissionAbsent": True, "fullBindingAuthorityAbsent": True,
        "leaseHolder": lease["spec"]["holderIdentity"], "quotaHardPods": 1, "quotaUsedPods": 1,
    }


def managed_readiness(node_name: str, old_name: str, old_uid: str, replacement: dict[str, Any]) -> dict[str, Any]:
    node = get("node", node_name, namespace=None)
    taint_present = any(
        row.get("key") == TAINT_KEY and row.get("value") == "true" and row.get("effect") == "NoSchedule"
        for row in node.get("spec", {}).get("taints", [])
    )
    policy = get("validatingadmissionpolicy", POLICY, namespace=None)
    policy_binding = get("validatingadmissionpolicybinding", POLICY_BINDING, namespace=None)
    role = get("clusterrole", CLUSTER_ROLE, namespace=None)
    can_bind = kubectl("auth", "can-i", "create", "bindings", "--as", f"system:serviceaccount:{SYSTEM_NAMESPACE}:amoebius-capacity", "-n", NAMESPACE).stdout.strip() == "yes"
    old_absent = kubectl("-n", NAMESPACE, "get", f"pod/{old_name}", check=False).returncode != 0
    replacement_live = get("pod", replacement["metadata"]["name"])
    replacement_reservation = get("capacityreservation", "bootstrap-addon")
    if not taint_present or not can_bind or not old_absent or replacement_live.get("status", {}).get("phase") != "Running":
        raise LiveFailure("managed-authority-readback-mismatch")
    if replacement_reservation["spec"]["state"] != "Bound" or replacement_reservation["spec"]["podUid"] != replacement_live["metadata"]["uid"]:
        raise LiveFailure("bootstrap-replacement-not-reservation-joined")
    role_resources = [resource for rule in role.get("rules", []) for resource in rule.get("resources", [])]
    if "pods/binding" not in role_resources and "bindings" not in role_resources:
        raise LiveFailure("exclusive-binding-rbac-missing")
    return {
        "witness": "ManagedCapacityReady", "managedTaintPresent": True,
        "identityAdmissionPresent": policy["metadata"]["name"] == POLICY,
        "policyBindingPresent": policy_binding["spec"]["policyName"] == POLICY,
        "exclusiveBindingRbacPresent": can_bind, "cutoverAuthorityRevoked": True, "writerDomainExact": True,
        "oldDefaultScheduledPod": old_name, "oldDefaultScheduledUid": old_uid, "oldUidAbsent": True, "oldResourcesReleased": True,
        "replacementUid": replacement_live["metadata"]["uid"], "replacementReservationJoined": True,
        "replacementBound": bool(replacement_live["spec"].get("nodeName")), "replacementReady": True,
    }


def cleanup(node_name: str | None) -> dict[str, bool]:
    for name in (POLICY_BINDING, BOOTSTRAP_POLICY_BINDING):
        kubectl("delete", "validatingadmissionpolicybinding", name, "--ignore-not-found", "--wait=true", "--timeout=120s")
    for name in (POLICY, BOOTSTRAP_POLICY):
        kubectl("delete", "validatingadmissionpolicy", name, "--ignore-not-found", "--wait=true", "--timeout=120s")
    kubectl("delete", "clusterrolebinding", CLUSTER_ROLE_BINDING, "--ignore-not-found", "--wait=true", "--timeout=120s")
    kubectl("delete", "clusterrole", CLUSTER_ROLE, "--ignore-not-found", "--wait=true", "--timeout=120s")
    if node_name:
        kubectl("taint", "node", node_name, f"{TAINT_KEY}:NoSchedule-", check=False)
    for name in (NAMESPACE, RACE_NAMESPACE, SYSTEM_NAMESPACE):
        kubectl("delete", "namespace", name, "--ignore-not-found", "--wait=true", "--timeout=180s")
    kubectl("delete", "customresourcedefinition", CRD, "--ignore-not-found", "--wait=true", "--timeout=180s")
    checks = {
        "namespaceAbsent": kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0,
        "raceNamespaceAbsent": kubectl("get", "namespace", RACE_NAMESPACE, check=False).returncode != 0,
        "systemNamespaceAbsent": kubectl("get", "namespace", SYSTEM_NAMESPACE, check=False).returncode != 0,
        "crdAbsent": kubectl("get", "customresourcedefinition", CRD, check=False).returncode != 0,
        "policyAbsent": kubectl("get", "validatingadmissionpolicy", POLICY, check=False).returncode != 0,
        "policyBindingAbsent": kubectl("get", "validatingadmissionpolicybinding", POLICY_BINDING, check=False).returncode != 0,
        "bootstrapPolicyAbsent": kubectl("get", "validatingadmissionpolicy", BOOTSTRAP_POLICY, check=False).returncode != 0,
        "bootstrapPolicyBindingAbsent": kubectl("get", "validatingadmissionpolicybinding", BOOTSTRAP_POLICY_BINDING, check=False).returncode != 0,
        "bindingRbacAbsent": kubectl("get", "clusterrole", CLUSTER_ROLE, check=False).returncode != 0,
    }
    if node_name:
        node = get("node", node_name, namespace=None)
        checks["managedTaintAbsent"] = all(row.get("key") != TAINT_KEY for row in node.get("spec", {}).get("taints", []))
    return checks


def execute() -> dict[str, Any]:
    node_name: str | None = None
    result: dict[str, Any] | None = None
    cleanup(None)
    try:
        nodes = list(json.loads(kubectl("get", "nodes", "-o", "json").stdout).get("items", []))
        if len(nodes) != 1:
            raise LiveFailure(f"single-node-kind-required:{len(nodes)}")
        node_name = nodes[0]["metadata"]["name"]
        apply([namespace(SYSTEM_NAMESPACE), namespace(NAMESPACE)])
        apply([reservation_crd()])
        kubectl("wait", "--for=condition=Established", f"customresourcedefinition/{CRD}", "--timeout=120s")
        policy, policy_binding = admission_policy()
        apply([policy, policy_binding])
        kubectl("wait", "--for=jsonpath={.status.observedGeneration}=1", f"validatingadmissionpolicy/{BOOTSTRAP_POLICY}", "--timeout=120s")
        role, role_binding = restricted_cutover_role()
        apply([service_account(), role, role_binding])
        apply(scheduler_system_objects(node_name))
        kubectl("-n", SYSTEM_NAMESPACE, "rollout", "status", "deployment/amoebius-capacity", "--timeout=300s")
        sequence: list[dict[str, Any]] = []
        bootstrap = bootstrap_readiness(node_name)
        sequence.append({"ordinal": 1, "event": bootstrap["witness"]})

        before_reject = rejection_snapshot()
        dry_run = kubectl("create", "--dry-run=server", "-f", "-", stdin=json.dumps(direct_guarded_pod("premature-guarded")), check=False)
        rejected = create(direct_guarded_pod("premature-guarded"), check=False)
        after_reject = rejection_snapshot()
        premature_absent = kubectl("-n", NAMESPACE, "get", "pod/premature-guarded", check=False).returncode != 0
        rejection_marker = "ManagedCapacityReady is required"
        if dry_run.returncode == 0 or rejected.returncode == 0 or rejection_marker not in rejected.stdout or before_reject != after_reject or not premature_absent:
            raise LiveFailure(f"premature-admission-boundary:{dry_run.returncode}:{rejected.returncode}:{rejected.stdout}")

        apply([bootstrap_addon()])
        kubectl("-n", NAMESPACE, "rollout", "status", "deployment/bootstrap-addon", "--timeout=300s")
        old_pod = single_pod("app=bootstrap-addon")
        old_name = old_pod["metadata"]["name"]
        old_uid = old_pod["metadata"]["uid"]
        patch = {
            "spec": {"template": {
                "metadata": {"labels": {"amoebius.io/guarded": "true", "amoebius.io/bootstrap-addon": "true"}, "annotations": protected_annotations("bootstrap-addon")},
                "spec": {"schedulerName": SCHEDULER_NAME, "tolerations": [toleration()]},
            }}
        }
        kubectl("-n", NAMESPACE, "patch", "deployment/bootstrap-addon", "--type=merge", "-p", json.dumps(patch))
        kubectl("-n", NAMESPACE, "wait", "--for=delete", f"pod/{old_name}", "--timeout=180s")
        wait_created("pod", "app=bootstrap-addon")
        replacement = single_pod("app=bootstrap-addon")
        if replacement["metadata"]["uid"] == old_uid or replacement["spec"].get("schedulerName") != SCHEDULER_NAME or replacement["spec"].get("nodeName"):
            raise LiveFailure("bootstrap-controller-cutover-did-not-produce-pending-replacement")
        sequence.append({"ordinal": 2, "event": "BootstrapAddonCutover", "oldUid": old_uid, "replacementUid": replacement["metadata"]["uid"]})
        protocol_events: list[dict[str, Any]] = []
        addon_binding = bind_protocol("bootstrap-addon", replacement, node_name, protocol_events, crash_after_reserve=True, crash_after_binding=True)
        sequence.append({"ordinal": 3, "event": "BootstrapReplacementBoundReady", "podUid": addon_binding["podUid"]})

        full_role, full_binding = full_binding_authority()
        identity_policy, identity_binding = managed_identity_policy()
        apply([full_role, full_binding, identity_policy, identity_binding], "amoebius-phase27-managed-authority")
        kubectl("wait", "--for=jsonpath={.status.observedGeneration}=1", f"validatingadmissionpolicy/{POLICY}", "--timeout=120s")
        kubectl("taint", "node", node_name, f"{TAINT_KEY}=true:NoSchedule", "--overwrite")
        kubectl("label", "namespace", NAMESPACE, "amoebius.io/managed-capacity-ready=true", "--overwrite")
        managed = managed_readiness(node_name, old_name, old_uid, replacement)
        sequence.append({"ordinal": 4, "event": managed["witness"]})

        bypass_before = rejection_snapshot()
        bypass = create(direct_guarded_pod("default-scheduler-bypass", scheduler_name="default-scheduler"), check=False)
        bypass_after = rejection_snapshot()
        bypass_absent = kubectl("-n", NAMESPACE, "get", "pod/default-scheduler-bypass", check=False).returncode != 0
        if bypass.returncode == 0 or "guarded workloads require amoebius-capacity" not in bypass.stdout or bypass_before != bypass_after or not bypass_absent:
            raise LiveFailure(f"default-scheduler-bypass:{bypass.returncode}:{bypass.stdout}")

        guarded_start = time.monotonic()
        apply([guarded_deployment()], "amoebius-phase27-general-guarded")
        wait_created("pod", "app=guarded-workload")
        guarded = single_pod("app=guarded-workload")
        if guarded["spec"].get("nodeName") or guarded["spec"].get("schedulerName") != SCHEDULER_NAME:
            raise LiveFailure("guarded-pod-not-pending-for-amoebius-capacity")
        sequence.append({"ordinal": 5, "event": "GeneralGuardedPodAdmitted", "podUid": guarded["metadata"]["uid"]})
        guarded_binding = bind_protocol("guarded-workload", guarded, node_name, protocol_events, crash_after_binding=True)
        ready_elapsed = time.monotonic() - guarded_start
        if ready_elapsed < 3.0:
            raise LiveFailure(f"guarded-readiness-was-not-observed:{ready_elapsed}")
        sequence.append({"ordinal": 6, "event": "GeneralGuardedPodBoundReady", "podUid": guarded_binding["podUid"]})

        race = aggregate_race()
        before_rerun = {
            "reservations": reservation_snapshot(), "root": rejection_snapshot(),
            "pods": {
                row["metadata"]["uid"]: {"name": row["metadata"]["name"], "nodeName": row["spec"].get("nodeName"), "resourceVersion": row["metadata"]["resourceVersion"]}
                for row in (get("pod", addon_binding["podName"]), get("pod", guarded_binding["podName"]))
            },
            "bindingRequests": 2,
        }
        after_rerun = {
            "reservations": reservation_snapshot(), "root": rejection_snapshot(),
            "pods": {
                row["metadata"]["uid"]: {"name": row["metadata"]["name"], "nodeName": row["spec"].get("nodeName"), "resourceVersion": row["metadata"]["resourceVersion"]}
                for row in (get("pod", addon_binding["podName"]), get("pod", guarded_binding["podName"]))
            },
            "bindingRequests": 2,
        }
        if before_rerun != after_rerun:
            raise LiveFailure("immediate-rerun-not-byte-stable")
        reservation_rows = list(before_rerun["reservations"].values())
        pod_uids = [row["spec"]["podUid"] for row in reservation_rows]
        if len(reservation_rows) != 2 or len(set(pod_uids)) != 2 or any(row["spec"]["state"] != "Bound" for row in reservation_rows):
            raise LiveFailure("reservation-uid-domain-not-exact")
        if [row["event"] for row in sequence] != [
            "BootstrapCapacitySchedulerReady", "BootstrapAddonCutover", "BootstrapReplacementBoundReady",
            "ManagedCapacityReady", "GeneralGuardedPodAdmitted", "GeneralGuardedPodBoundReady",
        ]:
            raise LiveFailure("scheduler-event-order")

        result = {
            "schema": "amoebius.phase27.live-scheduler.v1", "register": 3, "substrate": "linux-cpu",
            "universalLinuxCpu": {
                "availableOnEveryHardwareSubstrate": True,
                "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
            },
            "node": node_name, "sequence": sequence, "bootstrap": bootstrap, "managed": managed,
            "admission": {
                "prematureGuardedRejected": True, "prematureDryRunRejected": True, "prematureZeroWrites": True,
                "prematureReason": rejection_marker, "defaultSchedulerBypassRejected": True,
                "defaultSchedulerBypassZeroWrites": True, "positiveAdmittedAfterManaged": True,
            },
            "bindings": {
                "protocol": ["Reserved", "BindingInFlight", "Binding", "ConfirmedBound", "Bound"],
                "requests": 2, "everyBindingAfterCas": True, "everyUidDebitedOnce": True,
                "noDoubleBind": True, "records": [addon_binding, guarded_binding], "events": protocol_events,
                "guardedReadinessInitialDelaySeconds": 3, "guardedReadyElapsedSeconds": ready_elapsed,
            },
            "aggregateRace": race,
            "rerun": {
                "beforeHash": digest(before_rerun), "afterHash": digest(after_rerun), "byteStable": True,
                "plannedMutations": 0, "newBindingRequests": 0, "sameLeaseHolder": True,
                "sameLeaseResourceVersion": True, "reservationCount": len(reservation_rows),
            },
            "proven": [
                "two-stage-readiness-order", "premature-admission-zero-write", "default-scheduler-bypass-rejected",
                "reservation-cas-before-binding", "same-uid-single-debit", "bound-restart-recovery",
                "aggregate-residual-race", "byte-stable-rerun", "live-ready-after-bind",
            ],
            "tested": ["single-node-kind", "private-digest-image", "resourcequota-pods-1", "managed-node-taint", "exclusive-binding-rbac"],
            "assumed": ["modeled-apiserver-fidelity", "completion-release-ledger", "rollback-ledger", "in-cluster-control-plane-ownership"],
        }
    finally:
        postflight = cleanup(node_name)
    if result is None:
        raise LiveFailure("live-result-not-produced")
    if not all(postflight.values()):
        raise LiveFailure(f"postflight-leak:{postflight}")
    result["postflight"] = postflight
    return result


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="this run's observation")
    parser.add_argument("--image", required=True, help="the Phase-31 published digest reference")
    arguments = parser.parse_args(argv)
    globals()["IMAGE"] = arguments.image
    try:
        value = execute()
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("phase27-scheduler-live: PASS (two-stage cutover, CAS-before-Binding, admission, race, rerun, cleanup)")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase27-scheduler-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
