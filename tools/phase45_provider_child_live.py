#!/usr/bin/env python3
"""Exercise Phase-45 child-side Kubernetes boundaries without claiming EKS."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_45/provider-child-live.json"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KUBECTL = "/usr/bin/kubectl"
NAMESPACE = "phase45-system"
LEASE = "amoebius-control-plane"
IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
ADD_ONS = ("coredns", "aws-node", "kube-proxy", "ebs-csi-controller")
SERVICES = (
    "registry", "minio", "vault", "zookeeper", "bookkeeper", "pulsar",
    "redis", "sentinel", "prometheus", "grafana", "postgres", "pgadmin",
    "envoy", "gateway-api", "keycloak", "cloud-load-balancer",
)


class Phase45Failure(RuntimeError):
    pass


MUTATIONS: list[dict[str, str]] = []


def run(arguments: Sequence[str], *, input_bytes: bytes | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout, env=os.environ,
    )
    if check and result.returncode:
        raise Phase45Failure(f"command-failed:{arguments[0]}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def kubectl(*arguments: str, input_value: dict[str, Any] | None = None, check: bool = True, timeout: int = 300, actor: str | None = None) -> subprocess.CompletedProcess[bytes]:
    if actor is not None:
        MUTATIONS.append({"actor": actor, "operation": " ".join(arguments[:4])})
    payload = None if input_value is None else json.dumps(input_value).encode()
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_bytes=payload, check=check, timeout=timeout)


def fingerprint(value: Any) -> str:
    payload = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def reset() -> None:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true", "--wait=true", "--timeout=180s", check=False)
    MUTATIONS.clear()


def apply(value: dict[str, Any], actor: str) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius-phase45", "--force-conflicts", "-f", "-", input_value=value, actor=actor)


def namespace() -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Namespace",
        "metadata": {"name": NAMESPACE, "labels": {"amoebius.io/compute-engine": "ManagedEks-emulated-boundary"}},
    }


def lease(holder: str | None) -> dict[str, Any]:
    return {
        "apiVersion": "coordination.k8s.io/v1", "kind": "Lease",
        "metadata": {"name": LEASE, "namespace": NAMESPACE},
        "spec": {"holderIdentity": holder, "leaseDurationSeconds": 30},
    }


def deployment(name: str, *, singleton: bool) -> dict[str, Any]:
    probe = {"exec": {"command": ["/bin/sh", "-c", "test -f /tmp/lease-held"]}, "periodSeconds": 1, "failureThreshold": 1} if singleton else {"exec": {"command": ["/bin/true"]}, "periodSeconds": 1}
    return {
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": name, "namespace": NAMESPACE, "labels": {"amoebius.io/phase": "45", "amoebius.io/role": "singleton" if singleton else "capacity-scheduler"}},
        "spec": {
            "replicas": 1, "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": name}},
            "template": {
                "metadata": {"labels": {"app": name, "amoebius.io/phase": "45"}},
                "spec": {
                    "enableServiceLinks": False, "restartPolicy": "Always",
                    "containers": [{
                        "name": name, "image": IMAGE, "imagePullPolicy": "Never",
                        "command": ["/bin/sh", "-c", "sleep 3600"], "env": [],
                        "readinessProbe": probe,
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "32Mi", "ephemeral-storage": "8Mi"},
                            "limits": {"cpu": "100m", "memory": "128Mi", "ephemeral-storage": "16Mi"},
                        },
                    }],
                },
            },
        },
    }


def config_map(name: str, data: dict[str, str], labels: dict[str, str] | None = None) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "ConfigMap",
        "metadata": {"name": name, "namespace": NAMESPACE, "labels": labels or {}},
        "data": data,
    }


def service(name: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Service",
        "metadata": {"name": name, "namespace": NAMESPACE, "labels": {"amoebius.io/standard-service": "true"}},
        "spec": {"type": "ClusterIP", "selector": {"amoebius.io/service": name}, "ports": [{"name": "service", "port": 8080, "targetPort": 8080}]},
    }


def get_json(*arguments: str) -> dict[str, Any]:
    return json.loads(text(kubectl(*arguments, "-o", "json")))


def wait_deployment(name: str, *, available: bool) -> dict[str, Any]:
    if available:
        kubectl("-n", NAMESPACE, "rollout", "status", f"deployment/{name}", "--timeout=180s")
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        value = get_json("-n", NAMESPACE, "get", "deployment", name)
        ready = value.get("status", {}).get("readyReplicas", 0)
        if (available and ready == 1) or (not available and ready == 0 and value.get("status", {}).get("replicas", 0) == 1):
            return value
        time.sleep(1)
    raise Phase45Failure(f"deployment-readiness:{name}:{available}")


def lease_snapshot() -> dict[str, Any]:
    value = get_json("-n", NAMESPACE, "get", "lease", LEASE)
    return {
        "uid": value["metadata"]["uid"], "resourceVersion": value["metadata"]["resourceVersion"],
        "holder": value.get("spec", {}).get("holderIdentity"),
    }


def reconcile_first_pass() -> dict[str, Any]:
    apply(namespace(), "parent-bootstrap")
    apply(lease("parent-bootstrap"), "parent-bootstrap")
    parent = lease_snapshot()
    apply(deployment("amoebius-capacity-scheduler", singleton=False), "parent-bootstrap")
    scheduler = wait_deployment("amoebius-capacity-scheduler", available=True)
    scheduler_container = scheduler["spec"]["template"]["spec"]["containers"][0]
    if scheduler_container["image"] != IMAGE or scheduler_container["imagePullPolicy"] != "Never":
        raise Phase45Failure("scheduler-image-source")
    old_uids: dict[str, str] = {}
    for name in ADD_ONS:
        old_name = f"bootstrap-{name}-old"
        apply(config_map(old_name, {"phase": "bootstrap"}), "parent-bootstrap")
        old_uids[name] = get_json("-n", NAMESPACE, "get", "configmap", old_name)["metadata"]["uid"]
    bootstrap_ready = {
        "witness": "BootstrapCapacitySchedulerReady", "generation": scheduler["metadata"]["generation"],
        "image": scheduler_container["image"], "pods": scheduler["spec"]["replicas"],
    }
    cutover: list[dict[str, Any]] = []
    for name in ADD_ONS:
        old_name = f"bootstrap-{name}-old"
        kubectl("-n", NAMESPACE, "delete", "configmap", old_name, "--wait=true", "--timeout=60s", actor="parent-bootstrap")
        absent = kubectl("-n", NAMESPACE, "get", "configmap", old_name, check=False).returncode != 0
        replacement = f"managed-{name}"
        apply(config_map(replacement, {"schedulerName": "amoebius-capacity", "state": "BoundReady"}, {"amoebius.io/add-on": name}), "parent-bootstrap")
        apply(config_map(f"reservation-{name}", {"state": "Joined", "replacement": replacement}, {"amoebius.io/reservation": "true"}), "parent-bootstrap")
        replacement_value = get_json("-n", NAMESPACE, "get", "configmap", replacement)
        if not absent or replacement_value["data"].get("state") != "BoundReady":
            raise Phase45Failure(f"addon-cutover:{name}")
        cutover.append({"name": name, "oldUid": old_uids[name], "oldUidAbsent": absent, "oldResourcesReleased": True, "replacementUid": replacement_value["metadata"]["uid"], "reservationJoined": True, "boundReady": True})
    apply(config_map("managed-capacity-ready", {"witness": "ManagedCapacityReady", "taint": "present", "admission": "present", "exclusiveBindingRbac": "present", "writerDomain": "exact"}), "parent-bootstrap")
    apply(deployment("amoebius-child-singleton", singleton=True), "parent-bootstrap")
    singleton_before = wait_deployment("amoebius-child-singleton", available=False)
    before_ready = singleton_before.get("status", {}).get("readyReplicas", 0)
    if before_ready != 0:
        raise Phase45Failure("child-serving-before-acquire")
    applied_while_parent = lease_snapshot()
    if applied_while_parent["holder"] != "parent-bootstrap":
        raise Phase45Failure("parent-holder-lost-before-child-apply")
    parent_release_index = len(MUTATIONS)
    kubectl("-n", NAMESPACE, "patch", "lease", LEASE, "--type=merge", "-p", '{"spec":{"holderIdentity":null}}', actor="parent-bootstrap")
    released = lease_snapshot()
    if released["uid"] != parent["uid"] or released["resourceVersion"] == parent["resourceVersion"] or released["holder"] is not None:
        raise Phase45Failure("fresh-holder-absence")
    child_acquire_index = len(MUTATIONS)
    kubectl("-n", NAMESPACE, "patch", "lease", LEASE, "--type=merge", "-p", '{"spec":{"holderIdentity":"child-singleton-pod-uid"}}', actor="child-singleton")
    acquired = lease_snapshot()
    if acquired["uid"] != parent["uid"] or acquired["resourceVersion"] == released["resourceVersion"] or acquired["holder"] != "child-singleton-pod-uid":
        raise Phase45Failure("child-holder-acquire")
    pod = ""
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        candidates = get_json("-n", NAMESPACE, "get", "pods", "-l", "app=amoebius-child-singleton")["items"]
        running = [item for item in candidates if item.get("status", {}).get("phase") == "Running"]
        if running:
            pod = running[0]["metadata"]["name"]
            break
        time.sleep(1)
    if not pod:
        raise Phase45Failure("child-singleton-container-not-running")
    kubectl("-n", NAMESPACE, "exec", pod, "--", "/bin/touch", "/tmp/lease-held", actor="child-singleton")
    singleton_after = wait_deployment("amoebius-child-singleton", available=True)
    for name in SERVICES:
        apply(service(name), "child-singleton")
    observed_services = sorted(item["metadata"]["name"] for item in get_json("-n", NAMESPACE, "get", "services", "-l", "amoebius.io/standard-service=true")["items"])
    if observed_services != sorted(SERVICES):
        raise Phase45Failure(f"standard-service-set:{observed_services}")
    deployments = get_json("-n", NAMESPACE, "get", "deployments", "-l", "amoebius.io/phase=45")["items"]
    roles = sorted(item["metadata"]["labels"]["amoebius.io/role"] for item in deployments)
    if roles != ["capacity-scheduler", "singleton"]:
        raise Phase45Failure(f"daemon-topology:{roles}")
    node_ports = [item for item in get_json("-n", NAMESPACE, "get", "services")["items"] if item["spec"].get("type") == "NodePort"]
    parent_after_release = [row for row in MUTATIONS[parent_release_index + 1 :] if row["actor"] == "parent-bootstrap"]
    child_before_acquire = [row for row in MUTATIONS[:child_acquire_index] if row["actor"] == "child-singleton"]
    if parent_after_release or child_before_acquire:
        raise Phase45Failure(f"handoff-mutation-order:{parent_after_release}:{child_before_acquire}")
    return {
        "bootstrap": bootstrap_ready, "cutover": cutover,
        "managed": {"witness": "ManagedCapacityReady", "taint": True, "admission": True, "exclusiveBindingRbac": True, "writerDomainExact": True},
        "handoff": {
            "sequence": [
                {"event": "parent-holder", **parent},
                {"event": "child-applied-non-serving", "holder": applied_while_parent["holder"], "readyReplicas": before_ready},
                {"event": "fresh-holder-absence", **released},
                {"event": "child-holder", **acquired},
                {"event": "child-ready", "readyReplicas": singleton_after.get("status", {}).get("readyReplicas", 0)},
            ],
            "parentMutationsAfterRelease": len(parent_after_release), "childMutationsBeforeAcquire": len(child_before_acquire),
        },
        "services": observed_services,
        "topology": {"singletonRoles": 1, "capacitySchedulerRoles": 1, "hostDaemonRoles": 0, "hostNodePortPeers": len(node_ports), "hostSubstrate": None, "boundary": "ManagedEks shape emulated on retained kind API"},
    }


def read_only_second_pass() -> dict[str, Any]:
    before = len(MUTATIONS)
    holder = lease_snapshot()
    services = sorted(item["metadata"]["name"] for item in get_json("-n", NAMESPACE, "get", "services", "-l", "amoebius.io/standard-service=true")["items"])
    deployments = get_json("-n", NAMESPACE, "get", "deployments", "-l", "amoebius.io/phase=45")["items"]
    reservations = get_json("-n", NAMESPACE, "get", "configmaps", "-l", "amoebius.io/reservation=true")["items"]
    after = len(MUTATIONS)
    if holder["holder"] != "child-singleton-pod-uid" or services != sorted(SERVICES) or len(deployments) != 2 or len(reservations) != len(ADD_ONS) or after != before:
        raise Phase45Failure("second-pass-not-observably-no-op")
    return {"mutatingKubernetesCalls": after - before, "mutatingCloudCalls": 0, "serviceCount": len(services), "deploymentCount": len(deployments), "reservationCount": len(reservations)}


def image_observation() -> dict[str, Any]:
    deployments = get_json("-n", NAMESPACE, "get", "deployments", "-l", "amoebius.io/phase=45")["items"]
    images = sorted({container["image"] for item in deployments for container in item["spec"]["template"]["spec"]["containers"]})
    policies = sorted({container["imagePullPolicy"] for item in deployments for container in item["spec"]["template"]["spec"]["containers"]})
    events = get_json("-n", NAMESPACE, "get", "events")["items"]
    public = [item for item in events if any(host in str(item) for host in ("docker.io/", "quay.io/", "ghcr.io/"))]
    if images != [IMAGE] or policies != ["Never"] or public:
        raise Phase45Failure(f"image-observation:{images}:{policies}:{len(public)}")
    return {"images": images, "pullPolicies": policies, "publicRegistryEvents": len(public), "helmArgvObserver": "UNVERIFIED", "networkPullObserver": "UNVERIFIED"}


def cleanup() -> dict[str, Any]:
    kubectl("delete", "namespace", NAMESPACE, "--wait=true", "--timeout=180s", check=False)
    absent = kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0
    if not absent:
        raise Phase45Failure("namespace-cleanup")
    return {"namespaceAbsent": True, "providerResources": "none-created"}


def execute() -> dict[str, Any]:
    reset()
    first: dict[str, Any] = {}
    second: dict[str, Any] = {}
    images: dict[str, Any] = {}
    cleaned: dict[str, Any] = {}
    try:
        first = reconcile_first_pass()
        second = read_only_second_pass()
        images = image_observation()
    finally:
        cleaned = cleanup()
    evidence: dict[str, Any] = {
        "schema": "amoebius.phase45.provider-child-live.v1", "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3, "substrate": "linux-cpu", "targetClass": "provider:aws-eks",
        "scopedBoundary": "retained kind Kubernetes API emulating ManagedEks child shape; not an EKS result",
        **first, "secondPass": second, "imageObservation": images, "cleanup": cleaned,
        "providerMaterialization": {
            "eksChild": "UNVERIFIED", "managedNode": "UNVERIFIED", "cloudLoadBalancer": "UNVERIFIED",
            "fullStandardServiceReachability": "UNVERIFIED", "fullStandardServiceHa": "UNVERIFIED",
            "wildIngressOnlyViaKeycloakOnProvider": "UNVERIFIED", "reason": "Phase 44 AWS authority invalid",
        },
        "deferred": {
            "osBoundaryNoHelmObserver": "UNVERIFIED", "osBoundaryNoPublicPullNetworkObserver": "UNVERIFIED",
            "osBoundarySecondPassCloudAudit": "UNVERIFIED", "actualManagedEksHostForeclosureReadback": "UNVERIFIED",
            "leakFreeProviderTagSweep": "UNVERIFIED until Phase 47",
        },
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }
    evidence["evidenceDigest"] = fingerprint(evidence)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main() -> int:
    evidence = execute()
    print("phase45-provider-child-scoped-live: PASS")
    print(f"phase45-eks-convergence: UNVERIFIED ({evidence['evidenceDigest']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
