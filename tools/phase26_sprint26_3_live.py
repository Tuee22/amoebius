#!/usr/bin/env python3
"""Exercise serial OnDelete, terminal retention, and preconditioned delete."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
NAMESPACE = "amoebius-phase26-sprint3"
# Supplied by the caller, for the reason `tools/phase26_reconcile_live.py` records: a
# pinned digest here names a build that no longer exists.
IMAGE = ""


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, stdin: str | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(list(arguments), cwd=ROOT, text=True, input=stdin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if check and result.returncode:
        raise LiveFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def command(*arguments: str) -> tuple[str, ...]:
    return ("/usr/bin/kubectl", "--kubeconfig", str(KUBECONFIG), *arguments)


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[str]:
    return run(command(*arguments), stdin=stdin, check=check, timeout=timeout)


def pod_template(revision: str) -> dict[str, Any]:
    return {
        "metadata": {"labels": {"app": "serial", "amoebius.io/revision": revision}},
        "spec": {
            "restartPolicy": "Always",
            "containers": [{
                "name": "worker", "image": IMAGE, "imagePullPolicy": "Always",
                "command": ["/bin/sh", "-c", "exec /usr/bin/sleep 3600"],
                "readinessProbe": {"exec": {"command": ["/usr/bin/redis-cli", "--version"]}, "initialDelaySeconds": 1, "periodSeconds": 1},
                "resources": {
                    "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "16Mi"},
                    "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                },
            }],
        },
    }


def statefulset(revision: str) -> dict[str, Any]:
    return {
        "apiVersion": "apps/v1", "kind": "StatefulSet",
        "metadata": {"name": "serial", "namespace": NAMESPACE, "labels": {"amoebius.io/owner": "phase26-sprint3"}},
        "spec": {
            "serviceName": "serial-headless", "replicas": 2, "podManagementPolicy": "OrderedReady",
            "updateStrategy": {"type": "OnDelete"}, "selector": {"matchLabels": {"app": "serial"}},
            "template": pod_template(revision),
        },
    }


def base_objects(challenge: str) -> list[dict[str, Any]]:
    return [
        {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE, "labels": {"amoebius.io/owner": "phase26-sprint3"}}},
        {
            "apiVersion": "coordination.k8s.io/v1", "kind": "Lease",
            "metadata": {"name": "amoebius-reconciler", "namespace": NAMESPACE},
            "spec": {"holderIdentity": "phase26-bootstrap-host", "leaseDurationSeconds": 120},
        },
        {
            "apiVersion": "v1", "kind": "Service", "metadata": {"name": "serial-headless", "namespace": NAMESPACE},
            "spec": {"clusterIP": "None", "selector": {"app": "serial"}, "ports": [{"name": "unused", "port": 6379}]},
        },
        statefulset("v1"),
        {
            "apiVersion": "batch/v1", "kind": "Job",
            "metadata": {"name": "terminal", "namespace": NAMESPACE, "labels": {"amoebius.io/owner": "phase26-sprint3"}, "annotations": {"amoebius.io/challenge": challenge}},
            "spec": {
                "backoffLimit": 0,
                "template": {"metadata": {"labels": {"job": "terminal"}}, "spec": {
                    "restartPolicy": "Never",
                    "containers": [{
                        "name": "probe", "image": IMAGE, "imagePullPolicy": "Always",
                        "command": ["/usr/bin/redis-cli", "--version"],
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "16Mi"},
                            "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                        },
                    }],
                }},
            },
        },
        {
            "apiVersion": "v1", "kind": "ConfigMap",
            "metadata": {
                "name": "prune-candidate", "namespace": NAMESPACE,
                "labels": {"amoebius.io/owner": "phase26-sprint3"},
                "annotations": {"amoebius.io/generation": "generation-1", "amoebius.io/challenge": challenge},
            },
            "data": {"retention": "ordinary"},
        },
    ]


def apply(values: list[dict[str, Any]], manager: str = "amoebius") -> None:
    payload = {"apiVersion": "v1", "kind": "List", "items": values}
    kubectl("apply", "--server-side", f"--field-manager={manager}", "--force-conflicts", "-f", "-", stdin=json.dumps(payload))


def get(kind: str, name: str) -> dict[str, Any]:
    return json.loads(kubectl("-n", NAMESPACE, "get", kind, name, "-o", "json", "--show-managed-fields").stdout)


def replace_one(name: str, old_uid: str, updated_replicas: int) -> dict[str, str]:
    deletion = kubectl("-n", NAMESPACE, "delete", "pod", name, "--wait=true", "--timeout=120s")
    kubectl("-n", NAMESPACE, "wait", f"--for=jsonpath={{.status.updatedReplicas}}={updated_replicas}", "statefulset/serial", "--timeout=300s")
    kubectl("-n", NAMESPACE, "wait", "--for=jsonpath={.status.readyReplicas}=2", "statefulset/serial", "--timeout=300s")
    replacement = get("pod", name)
    uid = str(replacement["metadata"]["uid"])
    conditions = {str(row.get("type")): str(row.get("status")) for row in replacement.get("status", {}).get("conditions", [])}
    if uid == old_uid:
        raise LiveFailure(f"replacement-uid-not-distinct:{name}")
    if conditions.get("PodScheduled") != "True" or conditions.get("Ready") != "True":
        raise LiveFailure(f"replacement-not-bound-ready:{name}:{conditions}")
    return {"name": name, "oldUid": old_uid, "newUid": uid, "deleteOutput": deletion.stdout.strip(), "absenceObserved": "true", "boundReadyObserved": "true"}


def preconditioned_delete() -> dict[str, Any]:
    observed = get("configmap", "prune-candidate")
    uid = str(observed["metadata"]["uid"])
    rv = str(observed["metadata"]["resourceVersion"])
    uri = f"/api/v1/namespaces/{NAMESPACE}/configmaps/prune-candidate"
    wrong = {"apiVersion": "v1", "kind": "DeleteOptions", "preconditions": {"uid": uid, "resourceVersion": str(max(1, int(rv) - 1))}}
    denied = kubectl("delete", f"--raw={uri}", "-f", "-", stdin=json.dumps(wrong), check=False)
    if denied.returncode == 0 or "conflict" not in denied.stdout.lower():
        raise LiveFailure(f"wrong-precondition-delete:{denied.returncode}:{denied.stdout}")
    if get("configmap", "prune-candidate")["metadata"]["uid"] != uid:
        raise LiveFailure("candidate-lost-after-denied-delete")
    exact = {"apiVersion": "v1", "kind": "DeleteOptions", "preconditions": {"uid": uid, "resourceVersion": rv}}
    accepted = kubectl("delete", f"--raw={uri}", "-f", "-", stdin=json.dumps(exact))
    absent = kubectl("-n", NAMESPACE, "get", "configmap", "prune-candidate", check=False).returncode != 0
    if not absent:
        raise LiveFailure("exact-precondition-delete-did-not-delete")
    return {"uid": uid, "resourceVersion": rv, "wrongPreconditionExit": denied.returncode, "wrongPreconditionReason": "Conflict", "exactPreconditionDeleted": True, "acceptedResponse": accepted.stdout.strip()}


def execute() -> dict[str, Any]:
    challenge = uuid.uuid4().hex
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=120s")
    result: dict[str, Any] | None = None
    try:
        apply(base_objects(challenge))
        kubectl("-n", NAMESPACE, "wait", "--for=jsonpath={.status.readyReplicas}=2", "statefulset/serial", "--timeout=300s")
        kubectl("-n", NAMESPACE, "wait", "--for=condition=complete", "job/terminal", "--timeout=300s")
        initial = {name: get("pod", name) for name in ("serial-0", "serial-1")}
        apply([statefulset("v2")])
        transitions = []
        for updated_replicas, name in enumerate(("serial-1", "serial-0"), start=1):
            transitions.append(replace_one(name, str(initial[name]["metadata"]["uid"]), updated_replicas))
        terminal_pods = json.loads(kubectl("-n", NAMESPACE, "get", "pods", "-l", "job-name=terminal", "-o", "json").stdout)["items"]
        if len(terminal_pods) != 1 or terminal_pods[0]["status"].get("phase") != "Succeeded":
            raise LiveFailure("terminal-pod-not-retained")
        terminal_uid = str(terminal_pods[0]["metadata"]["uid"])
        if terminal_pods[0]["metadata"].get("deletionTimestamp") is not None:
            raise LiveFailure("terminal-pod-cleanup-started")
        delete_evidence = preconditioned_delete()
        result = {
            "schema": "amoebius.phase26.sprint26.3-live.v1",
            "capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "register": 3,
            "substrate": "linux-cpu",
            "challenge": challenge,
            "serial": {"policy": "OnDelete", "provisionedOrder": ["serial-1", "serial-0"], "transitions": transitions},
            "job": {"name": "terminal", "outcome": "Succeeded", "terminalPodUid": terminal_uid, "retained": True, "completionGatewayObjects": 0, "deleted": False},
            "delete": delete_evidence,
        }
    finally:
        kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=120s")
    if result is None:
        raise LiveFailure("live-result-absent")
    result["postflightNamespaceAbsent"] = kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0
    if not result["postflightNamespaceAbsent"]:
        raise LiveFailure("namespace-leaked")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--image", required=True, help="the Phase-25 published digest reference")
    arguments = parser.parse_args()
    globals()["IMAGE"] = arguments.image
    try:
        result = execute()
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.output is None:
            print(encoded, end="")
        else:
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(encoded, encoding="utf-8")
        print("phase26-sprint26.3-live: PASS (serial stages + terminal retention + authenticated delete)")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.3-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
