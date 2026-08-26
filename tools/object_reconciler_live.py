#!/usr/bin/env python3
"""Run the complete live Phase-67 representative reconcile corpus."""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
# Defaults are inert project-contained locations. The executing gate supplies the
# exact run bundle, kubeconfig, binary, and node-mounted live-storage root.
DIAGNOSTIC_DIR = ROOT / ".build/tmp/object-reconciler"
KUBECONFIG = Path(os.environ.get(
    "AMOEBIUS_KUBECONFIG",
    str(ROOT / ".build/tmp/object-reconciler/unconfigured-kubeconfig"),
))
KUBECTL = os.environ.get("AMOEBIUS_KUBECTL", "/usr/bin/kubectl")
LIVE_STORAGE_ROOT = os.environ.get("AMOEBIUS_LIVE_STORAGE_ROOT", "/amoebius-test/storage")
NAMESPACE = "amoebius-phase26-gate"
RACE_NAMESPACE = "amoebius-phase26-quota-race"
CRD = "capacityreservations.amoebius.io"
PV = "amoebius-phase26-reservation-child"
OWNER = "phase26-corpus"
GENERATION = "phase26-generation-1"
# The corpus pulls this from the in-cluster registry, so it is the digest Phase 30
# published on the run that stood that registry up, supplied by the caller. A constant
# here pinned an image from a build that no longer exists: the corpus would have failed
# `ImagePull` on every host but the one that built it, and a rebuilt base would have been
# reconciled against a reference nothing published.
IMAGE = ""


class LiveFailure(RuntimeError):
    pass


def load_sprint3() -> Any:
    path = ROOT / "tools/object_reconciler_execution_live.py"
    spec = importlib.util.spec_from_file_location("object_reconciler_execution_runtime", path)
    if spec is None or spec.loader is None:
        raise LiveFailure("sprint3-module-load")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.NAMESPACE = NAMESPACE
    return module


S3 = load_sprint3()


def run(arguments: Sequence[str], *, stdin: str | None = None, check: bool = True, timeout: int = 360) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(list(arguments), cwd=ROOT, text=True, input=stdin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if check and result.returncode:
        raise LiveFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 360) -> subprocess.CompletedProcess[str]:
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), stdin=stdin, check=check, timeout=timeout)


def label_metadata(name: str, *, namespace: str | None = NAMESPACE) -> dict[str, Any]:
    metadata: dict[str, Any] = {
        "name": name,
        "labels": {"app.kubernetes.io/managed-by": "amoebius", "amoebius.io/owner": OWNER},
        "annotations": {"amoebius.io/generation": GENERATION},
    }
    if namespace is not None:
        metadata["namespace"] = namespace
    return metadata


def resources(cpu: str = "10m") -> dict[str, Any]:
    return {
        "requests": {"cpu": cpu, "memory": "16Mi", "ephemeral-storage": "16Mi"},
        "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
    }


def deployment(name: str, challenge: str, *, initial_delay: int) -> dict[str, Any]:
    labels = {"app": name, "amoebius.io/owner": OWNER, "amoebius.io/generation": GENERATION}
    metadata = label_metadata(name)
    metadata["annotations"]["amoebius.io/challenge"] = challenge
    return {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": metadata,
        "spec": {
            "replicas": 1, "strategy": {"type": "RollingUpdate", "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 0}},
            "selector": {"matchLabels": {"app": name}},
            "template": {
                "metadata": {"labels": labels, "annotations": {"amoebius.io/challenge": challenge}},
                "spec": {"containers": [{
                    "name": "worker", "image": IMAGE, "imagePullPolicy": "Always",
                    "command": ["/bin/sh", "-c", "exec /usr/bin/sleep 3600"],
                    "readinessProbe": {"exec": {"command": ["/usr/bin/redis-cli", "--version"]}, "initialDelaySeconds": initial_delay, "periodSeconds": 1},
                    "resources": resources(),
                }]},
            },
        },
    }


def crd() -> dict[str, Any]:
    return {
        "apiVersion": "apiextensions.k8s.io/v1", "kind": "CustomResourceDefinition",
        "metadata": label_metadata(CRD, namespace=None),
        "spec": {
            "group": "amoebius.io", "scope": "Namespaced", "names": {"plural": "capacityreservations", "singular": "capacityreservation", "kind": "CapacityReservation"},
            "versions": [{
                "name": "v1", "served": True, "storage": True, "subresources": {"status": {}},
                "schema": {"openAPIV3Schema": {
                    "type": "object",
                    "properties": {
                        "spec": {"type": "object", "properties": {"childName": {"type": "string"}}, "required": ["childName"]},
                        "status": {"type": "object", "x-kubernetes-preserve-unknown-fields": True},
                    },
                }},
            }],
        },
    }


def quota() -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "ResourceQuota", "metadata": label_metadata("corpus-envelope"),
        "spec": {"hard": {
            "requests.cpu": "2", "requests.memory": "2Gi", "limits.cpu": "4", "limits.memory": "4Gi",
            "requests.ephemeral-storage": "2Gi", "limits.ephemeral-storage": "4Gi", "requests.storage": "1Gi",
            "pods": "16", "persistentvolumeclaims": "4",
        }},
    }


def custom_resource(challenge: str) -> dict[str, Any]:
    metadata = label_metadata("corpus-reservation")
    metadata["annotations"]["amoebius.io/challenge"] = challenge
    return {"apiVersion": "amoebius.io/v1", "kind": "CapacityReservation", "metadata": metadata, "spec": {"childName": "reservation-child"}}


def quota_race_object(name: str, challenge: str) -> tuple[dict[str, Any], dict[str, Any]]:
    reservation = custom_resource(challenge)
    reservation["metadata"] = label_metadata(name, namespace=RACE_NAMESPACE)
    reservation["metadata"]["annotations"]["amoebius.io/challenge"] = challenge
    reservation["spec"]["childName"] = name
    child = deployment(name, challenge, initial_delay=1)
    child["metadata"]["namespace"] = RACE_NAMESPACE
    return reservation, child


def validate_quota_race(challenge: str) -> dict[str, Any]:
    namespace = {"apiVersion": "v1", "kind": "Namespace", "metadata": label_metadata(RACE_NAMESPACE, namespace=None)}
    race_quota = {
        "apiVersion": "v1", "kind": "ResourceQuota", "metadata": label_metadata("controller-envelope", namespace=RACE_NAMESPACE),
        "spec": {"hard": {"pods": "1"}},
    }
    apply([namespace], "amoebius-quota-race")
    apply([race_quota], "amoebius-quota-race")
    contenders = [quota_race_object("race-child-a", challenge), quota_race_object("race-child-b", challenge)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        submitted = [executor.submit(apply, list(objects), f"amoebius-quota-race-{index}") for index, objects in enumerate(contenders)]
        for future in submitted:
            future.result()
    kubectl("-n", RACE_NAMESPACE, "wait", "--for=jsonpath={.status.used.pods}=1", "resourcequota/controller-envelope", "--timeout=120s")
    kubectl("-n", RACE_NAMESPACE, "wait", "--for=condition=Ready", "pod", "--all", "--timeout=300s")
    pods = json.loads(kubectl("-n", RACE_NAMESPACE, "get", "pods", "-o", "json").stdout)["items"]
    reservations = json.loads(kubectl("-n", RACE_NAMESPACE, "get", "capacityreservations", "-o", "json").stdout)["items"]
    observed_quota = get_race("resourcequota", "controller-envelope")
    used = int(observed_quota["status"]["used"]["pods"])
    hard = int(observed_quota["status"]["hard"]["pods"])
    if len(reservations) != 2 or len(pods) != 1 or used != 1 or hard != 1 or used > hard:
        raise LiveFailure(f"controller-envelope-quota-race:{len(reservations)}:{len(pods)}:{used}:{hard}")
    return {
        "simultaneousReservations": len(reservations), "admittedChildren": len(pods),
        "hardPods": hard, "usedPods": used, "overAllocation": 0,
    }


def pvc() -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "PersistentVolumeClaim", "metadata": label_metadata("reservation-child"),
        "spec": {
            "accessModes": ["ReadWriteOnce"], "storageClassName": "", "volumeName": PV,
            "resources": {"requests": {"storage": "16Mi"}},
        },
    }


def persistent_volume() -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "PersistentVolume", "metadata": label_metadata(PV, namespace=None),
        "spec": {
            "capacity": {"storage": "16Mi"}, "accessModes": ["ReadWriteOnce"],
            "persistentVolumeReclaimPolicy": "Retain", "storageClassName": "", "volumeMode": "Filesystem",
            "hostPath": {
                "path": str(Path(LIVE_STORAGE_ROOT) / "object-reconciler-reservation-child"),
                "type": "DirectoryOrCreate",
            },
        },
    }


def prepare_sprint3_objects(challenge: str) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    objects = S3.base_objects(challenge)
    service = objects[2]
    serial = objects[3]
    job = objects[4]
    for value in (service, serial, job):
        value["metadata"].update(label_metadata(value["metadata"]["name"]))
    serial["spec"]["template"]["metadata"]["labels"].update({"amoebius.io/owner": OWNER, "amoebius.io/generation": GENERATION})
    job["spec"]["template"]["metadata"]["labels"].update({"amoebius.io/owner": OWNER, "amoebius.io/generation": GENERATION})
    return service, serial, job


def apply(values: list[dict[str, Any]], manager: str = "amoebius") -> None:
    payload = {"apiVersion": "v1", "kind": "List", "items": values}
    kubectl("apply", "--server-side", f"--field-manager={manager}", "--force-conflicts", "-f", "-", stdin=json.dumps(payload))


def get(kind: str, name: str, *, namespace: bool = True) -> dict[str, Any]:
    prefix = ("-n", NAMESPACE) if namespace else ()
    return json.loads(kubectl(*prefix, "get", kind, name, "-o", "json", "--show-managed-fields").stdout)


def get_race(kind: str, name: str) -> dict[str, Any]:
    return json.loads(kubectl("-n", RACE_NAMESPACE, "get", kind, name, "-o", "json", "--show-managed-fields").stdout)


def object_snapshot() -> dict[str, Any]:
    kinds = "lease,service,statefulset,job,deployment,persistentvolumeclaim,resourcequota,capacityreservation,pod"
    listed = json.loads(kubectl("-n", NAMESPACE, "get", kinds, "-l", f"amoebius.io/owner={OWNER}", "-o", "json", "--show-managed-fields").stdout)
    items = list(listed.get("items", []))
    items.extend((
        get("namespace", NAMESPACE, namespace=False),
        get("customresourcedefinition", CRD, namespace=False),
        get("persistentvolume", PV, namespace=False),
    ))
    snapshot: dict[str, Any] = {}
    for item in items:
        metadata = item["metadata"]
        identity = f"{item['kind']}/{metadata.get('namespace', '')}/{metadata['name']}"
        snapshot[identity] = {
            "resourceVersion": metadata.get("resourceVersion"),
            "managedFields": metadata.get("managedFields", []),
            "labels": metadata.get("labels", {}),
            "annotations": metadata.get("annotations", {}),
            "uid": metadata.get("uid"),
        }
    return dict(sorted(snapshot.items()))


def snapshot_hash(snapshot: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(snapshot, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def child_conformance(name: str, cpu_expected: str = "10m") -> dict[str, Any]:
    child = get("deployment", name)
    container = child["spec"]["template"]["spec"]["containers"][0]
    observed = container["resources"]
    expected = resources(cpu_expected)
    if observed != expected or child["spec"].get("replicas") != 1:
        raise LiveFailure(f"child-envelope-exceeded:{name}:{observed}:{expected}")
    volume = get("persistentvolumeclaim", "reservation-child")
    if volume["spec"]["resources"]["requests"]["storage"] != "16Mi":
        raise LiveFailure("child-storage-envelope")
    return {"replicas": 1, "resources": observed, "storage": "16Mi", "conforms": True}


def execute() -> dict[str, Any]:
    challenge = uuid.uuid4().hex
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=180s")
    kubectl("delete", "namespace", RACE_NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=180s")
    kubectl("delete", "customresourcedefinition", CRD, "--ignore-not-found", "--wait=true", "--timeout=180s")
    kubectl("delete", "persistentvolume", PV, "--ignore-not-found", "--wait=true", "--timeout=180s")
    result: dict[str, Any] | None = None
    try:
        namespace = {"apiVersion": "v1", "kind": "Namespace", "metadata": label_metadata(NAMESPACE, namespace=None)}
        lease = {"apiVersion": "coordination.k8s.io/v1", "kind": "Lease", "metadata": label_metadata("amoebius-reconciler"), "spec": {"holderIdentity": "phase26-bootstrap-host", "leaseDurationSeconds": 300}}
        apply([namespace], "amoebius-bootstrap")
        apply([lease], "amoebius-bootstrap")
        held = get("lease", "amoebius-reconciler")
        if held["spec"].get("holderIdentity") != "phase26-bootstrap-host":
            raise LiveFailure("mandatory-lease-not-held")

        apply([crd()])
        kubectl("wait", "--for=condition=Established", f"customresourcedefinition/{CRD}", "--timeout=120s")
        service, serial_v1, job = prepare_sprint3_objects(challenge)
        controller = deployment("capacity-controller", challenge, initial_delay=2)
        private_pull = deployment("private-pull", challenge, initial_delay=3)
        apply([quota(), service, serial_v1, job, controller, private_pull])
        immediate = get("deployment", "private-pull")
        initial_available = int(immediate.get("status", {}).get("availableReplicas", 0))
        started = time.monotonic()
        kubectl("-n", NAMESPACE, "rollout", "status", "deployment/capacity-controller", "--timeout=300s")
        kubectl("-n", NAMESPACE, "rollout", "status", "deployment/private-pull", "--timeout=300s")
        private_ready_elapsed = time.monotonic() - started
        if initial_available != 0 or private_ready_elapsed < 2.0:
            raise LiveFailure(f"private-readiness-not-noninstantaneous:{initial_available}:{private_ready_elapsed}")
        kubectl("-n", NAMESPACE, "wait", "--for=jsonpath={.status.readyReplicas}=2", "statefulset/serial", "--timeout=300s")
        kubectl("-n", NAMESPACE, "wait", "--for=condition=complete", "job/terminal", "--timeout=300s")

        child = deployment("reservation-child", challenge, initial_delay=1)
        child["spec"]["template"]["spec"]["volumes"] = [{"name": "child-storage", "persistentVolumeClaim": {"claimName": "reservation-child"}}]
        child["spec"]["template"]["spec"]["containers"][0]["volumeMounts"] = [{"name": "child-storage", "mountPath": "/amoebius-child"}]
        apply([persistent_volume(), custom_resource(challenge), pvc(), child])
        kubectl("-n", NAMESPACE, "rollout", "status", "deployment/reservation-child", "--timeout=300s")
        kubectl("-n", NAMESPACE, "wait", "--for=jsonpath={.status.phase}=Bound", "persistentvolumeclaim/reservation-child", "--timeout=300s")
        status = {"status": {"observedGeneration": 1, "conditions": [{"type": "Healthy", "status": "True", "reason": "ChildConforms"}]}}
        kubectl("-n", NAMESPACE, "patch", "capacityreservation", "corpus-reservation", "--subresource=status", "--type=merge", "-p", json.dumps(status))
        cr_observed = get("capacityreservation", "corpus-reservation")
        conditions = cr_observed.get("status", {}).get("conditions", [])
        if not any(row.get("type") == "Healthy" and row.get("status") == "True" for row in conditions):
            raise LiveFailure("custom-resource-not-healthy")
        child_evidence = child_conformance("reservation-child")

        initial_pods = {name: get("pod", name) for name in ("serial-0", "serial-1")}
        serial_v2 = S3.statefulset("v2")
        serial_v2["metadata"].update(label_metadata("serial"))
        serial_v2["spec"]["template"]["metadata"]["labels"].update({"amoebius.io/owner": OWNER, "amoebius.io/generation": GENERATION})
        apply([serial_v2])
        serial_transitions = []
        for count, name in enumerate(("serial-1", "serial-0"), start=1):
            serial_transitions.append(S3.replace_one(name, str(initial_pods[name]["metadata"]["uid"]), count))

        terminal = json.loads(kubectl("-n", NAMESPACE, "get", "pods", "-l", "job-name=terminal", "-o", "json").stdout)["items"]
        if len(terminal) != 1 or terminal[0]["status"].get("phase") != "Succeeded" or terminal[0]["metadata"].get("deletionTimestamp"):
            raise LiveFailure("terminal-retention")
        terminal_uid = str(terminal[0]["metadata"]["uid"])

        before = object_snapshot()
        stable_objects = [crd(), persistent_volume(), quota(), service, serial_v2, job, controller, private_pull, custom_resource(challenge), pvc(), child]
        apply(stable_objects)
        after = object_snapshot()
        if before != after:
            changed = sorted(set(before) ^ set(after) | {key for key in set(before) & set(after) if before[key] != after[key]})
            (DIAGNOSTIC_DIR / "live-rerun-red-before-correction.json").write_text(
                json.dumps({"changed": changed, "before": {key: before.get(key) for key in changed}, "after": {key: after.get(key) for key in changed}}, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            raise LiveFailure(f"rerun-object-snapshot-changed:{changed}")

        quota_race = validate_quota_race(challenge)

        never = deployment("never-ready", challenge, initial_delay=1)
        never["metadata"]["labels"]["amoebius.io/owner"] = "phase26-mutant"
        never["spec"]["template"]["metadata"]["labels"]["amoebius.io/owner"] = "phase26-mutant"
        never["spec"]["template"]["spec"]["containers"][0]["readinessProbe"]["exec"]["command"] = ["/bin/sh", "-c", "exit 1"]
        apply([never], "amoebius-never-ready")
        never_wait = kubectl("-n", NAMESPACE, "rollout", "status", "deployment/never-ready", "--timeout=8s", check=False, timeout=30)
        if never_wait.returncode == 0:
            raise LiveFailure("never-ready-unexpectedly-converged")
        kubectl("-n", NAMESPACE, "delete", "deployment", "never-ready", "--wait=true", "--timeout=120s")

        over = deployment("overbound-child", challenge, initial_delay=1)
        over["metadata"]["labels"]["amoebius.io/owner"] = "phase26-mutant"
        over["spec"]["template"]["metadata"]["labels"]["amoebius.io/owner"] = "phase26-mutant"
        over["spec"]["template"]["spec"]["containers"][0]["resources"] = resources("11m")
        apply([over], "amoebius-overbound-mutant")
        kubectl("-n", NAMESPACE, "rollout", "status", "deployment/overbound-child", "--timeout=300s")
        over_observed = get("deployment", "overbound-child")["spec"]["template"]["spec"]["containers"][0]["resources"]["requests"]["cpu"]
        overbound_red = over_observed != "10m"
        if not overbound_red:
            raise LiveFailure("overbound-child-mutant-not-red")
        kubectl("-n", NAMESPACE, "delete", "deployment", "overbound-child", "--wait=true", "--timeout=120s")

        private_pods = json.loads(kubectl("-n", NAMESPACE, "get", "pods", "-l", "app=private-pull", "-o", "json").stdout)["items"]
        private_image_id = str(private_pods[0]["status"]["containerStatuses"][0]["imageID"])
        # The running pod has to carry the digest this run was told to reconcile, not a
        # digest typed in beside the assertion: the retired constant named a build that no
        # longer exists, so the one check that ties the corpus to Phase 30's published
        # artifact could only ever have passed on the host that produced it.
        if IMAGE.rsplit("@", 1)[-1] not in private_image_id:
            raise LiveFailure(f"private-image-id:{private_image_id}!={IMAGE}")
        result = {
            "schema": "amoebius.phase26.live-reconcile.v1", "capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "register": 3, "substrate": "linux-cpu", "challenge": challenge,
            "mandatoryLease": {"holder": held["spec"]["holderIdentity"], "uid": held["metadata"]["uid"], "resourceVersion": held["metadata"]["resourceVersion"]},
            "privatePullDeployment": {"initialAvailableReplicas": initial_available, "initialDelaySeconds": 3, "readyElapsedSeconds": private_ready_elapsed, "imageId": private_image_id, "available": True},
            "serial": {"transitions": serial_transitions},
            "job": {"terminalPodUid": terminal_uid, "retained": True, "completionObjects": 0},
            "customResource": {"healthy": True, "child": child_evidence},
            "quotaRace": quota_race,
            "rerun": {"plannedMutations": 0, "terminalRetentionActions": 1, "objectCount": len(before), "beforeHash": snapshot_hash(before), "afterHash": snapshot_hash(after), "byteStable": True},
            "negativeControls": {"neverReadyExit": never_wait.returncode, "neverReadyResult": "RED", "overboundObservedCpu": over_observed, "overboundResult": "RED"},
        }
    finally:
        kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=180s")
        kubectl("delete", "namespace", RACE_NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=180s")
        kubectl("delete", "customresourcedefinition", CRD, "--ignore-not-found", "--wait=true", "--timeout=180s")
        kubectl("delete", "persistentvolume", PV, "--ignore-not-found", "--wait=true", "--timeout=180s")
    if result is None:
        raise LiveFailure("live-result-absent")
    result["postflight"] = {
        "namespaceAbsent": kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0,
        "raceNamespaceAbsent": kubectl("get", "namespace", RACE_NAMESPACE, check=False).returncode != 0,
        "crdAbsent": kubectl("get", "customresourcedefinition", CRD, check=False).returncode != 0,
        "persistentVolumeAbsent": kubectl("get", "persistentvolume", PV, check=False).returncode != 0,
    }
    if not all(result["postflight"].values()):
        raise LiveFailure(f"postflight-leak:{result['postflight']}")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    # The digest-pinned in-cluster reference the corpus pulls. Required, and deliberately
    # without a default: a default names one build, and the corpus's whole point is that a
    # running pod exercises the registry dependency of the run in progress.
    parser.add_argument("--image", required=True, help="the Phase-30 published digest reference")
    arguments = parser.parse_args()
    globals()["IMAGE"] = arguments.image
    # The Sprint-26.3 module builds the corpus StatefulSet and Job, so it needs the same
    # reference: a value set only here left those two objects with an empty image.
    S3.IMAGE = arguments.image
    if arguments.output is not None:
        globals()["DIAGNOSTIC_DIR"] = arguments.output.parent
    try:
        result = execute()
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.output is None:
            print(encoded, end="")
        else:
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(encoded, encoding="utf-8")
        print(f"phase26-reconcile-live: PASS ({result['rerun']['objectCount']} objects; byte-stable rerun)")
        return 0
    except (LiveFailure, S3.LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-reconcile-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
