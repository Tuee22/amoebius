#!/usr/bin/env python3
"""Validate the single inert retained StorageClass on this run's cluster."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence

import yaml


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path(os.environ.get("AMOEBIUS_KUBECONFIG", ROOT / ".build/tmp/retained-storage/unconfigured-kubeconfig"))
KUBECTL = os.environ.get("AMOEBIUS_KUBECTL", "/usr/bin/kubectl")
ORACLE = ROOT / "test/oracle/retained_storage/storage_class.yaml"
NAMESPACE = "amoebius-retained-storage-class-test"
STORAGE_CLASS = "amoebius-retained"
PV = "amoebius-retained-storage-class-bind"


class LiveFailure(RuntimeError):
    pass


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 240) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), cwd=ROOT,
        text=True, input=stdin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        raise LiveFailure(f"kubectl:{arguments}:exit-{result.returncode}:{result.stdout}")
    return result


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius", "--force-conflicts", "-f", "-", stdin=json.dumps(value))


def get(kind: str, name: str, *, namespace: bool = True) -> dict[str, Any]:
    prefix = ("-n", NAMESPACE) if namespace else ()
    return json.loads(kubectl(*prefix, "get", kind, name, "-o", "json").stdout)


def selected_storage_class(value: dict[str, Any]) -> dict[str, Any]:
    return {
        "apiVersion": value["apiVersion"], "kind": value["kind"],
        "metadata": {"name": value["metadata"]["name"]}, "provisioner": value["provisioner"],
        "reclaimPolicy": value["reclaimPolicy"], "volumeBindingMode": value["volumeBindingMode"],
    }


def cleanup_test_resources() -> dict[str, bool]:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=120s")
    kubectl("delete", "persistentvolume", PV, "--ignore-not-found", "--wait=true", "--timeout=120s")
    return {
        "namespaceAbsent": kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0,
        "testPvAbsent": kubectl("get", "persistentvolume", PV, check=False).returncode != 0,
        "retainedClassPresent": kubectl("get", "storageclass", STORAGE_CLASS, check=False).returncode == 0,
    }


def execute() -> dict[str, Any]:
    cleanup_test_resources()
    classes = json.loads(kubectl("get", "storageclass", "-o", "json").stdout).get("items", [])
    for row in classes:
        if row["metadata"]["name"] != STORAGE_CLASS:
            kubectl("delete", "storageclass", row["metadata"]["name"], "--wait=true")
    expected = yaml.safe_load(ORACLE.read_text(encoding="utf-8"))
    apply(expected)
    observed_rows = json.loads(kubectl("get", "storageclass", "-o", "json").stdout).get("items", [])
    if len(observed_rows) != 1:
        raise LiveFailure(f"count != 1:{len(observed_rows)}")
    observed = observed_rows[0]
    annotations = observed["metadata"].get("annotations", {})
    default_absent = not any(key in annotations for key in ("storageclass.kubernetes.io/is-default-class", "storageclass.beta.kubernetes.io/is-default-class"))
    oracle_equal = selected_storage_class(observed) == expected
    if not default_absent or not oracle_equal:
        raise LiveFailure(f"storageclass-oracle:{default_absent}:{selected_storage_class(observed)}:{expected}")

    namespace = {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE}}
    pending = {
        "apiVersion": "v1", "kind": "PersistentVolumeClaim", "metadata": {"name": "unmatched", "namespace": NAMESPACE},
        "spec": {"storageClassName": STORAGE_CLASS, "accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": "8Mi"}}},
    }
    apply(namespace)
    apply(pending)
    kubectl("-n", NAMESPACE, "wait", "--for=create", "event", "--field-selector=involvedObject.name=unmatched", "--timeout=120s")
    events = json.loads(kubectl("-n", NAMESPACE, "get", "events", "--field-selector=involvedObject.name=unmatched", "-o", "json").stdout).get("items", [])
    reasons = [row.get("reason") for row in events]
    if "WaitForFirstConsumer" not in reasons:
        raise LiveFailure(f"unmatched-event-reasons:{reasons}")
    unmatched = get("pvc", "unmatched")

    positive_pvc = {
        "apiVersion": "v1", "kind": "PersistentVolumeClaim", "metadata": {"name": "matched", "namespace": NAMESPACE},
        "spec": {"storageClassName": STORAGE_CLASS, "volumeName": PV, "accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": "8Mi"}}},
    }
    positive_pv = {
        "apiVersion": "v1", "kind": "PersistentVolume", "metadata": {"name": PV},
        "spec": {
            "capacity": {"storage": "8Mi"}, "accessModes": ["ReadWriteOnce"], "storageClassName": STORAGE_CLASS,
            "persistentVolumeReclaimPolicy": "Retain", "volumeMode": "Filesystem",
            "claimRef": {"namespace": NAMESPACE, "name": "matched"},
            "hostPath": {"path": "/amoebius-test/retained-storage-class-bind", "type": "DirectoryOrCreate"},
        },
    }
    apply(positive_pv)
    apply(positive_pvc)
    kubectl("-n", NAMESPACE, "wait", "--for=jsonpath={.status.phase}=Bound", "pvc/matched", "--timeout=120s")
    kubectl("wait", "--for=jsonpath={.status.phase}=Bound", f"pv/{PV}", "--timeout=120s")
    bound_pvc = get("pvc", "matched")
    bound_pv = get("pv", PV, namespace=False)

    mutant = {
        "apiVersion": "storage.k8s.io/v1", "kind": "StorageClass", "metadata": {
            "name": "amoebius-mutant-dynamic", "annotations": {"storageclass.kubernetes.io/is-default-class": "true"},
        },
        "provisioner": "rancher.io/local-path", "reclaimPolicy": "Delete", "volumeBindingMode": "WaitForFirstConsumer",
    }
    apply(mutant)
    mutant_rows = json.loads(kubectl("get", "storageclass", "-o", "json").stdout).get("items", [])
    mutant_default = any("storageclass.kubernetes.io/is-default-class" in row["metadata"].get("annotations", {}) for row in mutant_rows)
    negative_red = len(mutant_rows) != 1 and mutant_default
    kubectl("delete", "storageclass", "amoebius-mutant-dynamic", "--wait=true")
    if not negative_red:
        raise LiveFailure("two-storageclasses-negative-survived")

    cleanup = cleanup_test_resources()
    if not all(cleanup.values()):
        raise LiveFailure(f"cleanup:{cleanup}")
    return {
        "schema": "amoebius.retained-storage.class-live.v1", "register": 3, "substrate": "linux-cpu",
        "inventory": {
            "count": 1, "name": STORAGE_CLASS, "provisioner": observed["provisioner"],
            "reclaimPolicy": observed["reclaimPolicy"], "volumeBindingMode": observed["volumeBindingMode"],
            "defaultAnnotationAbsent": default_absent, "oracleEqual": oracle_equal,
        },
        "pendingClaim": {"phase": unmatched.get("status", {}).get("phase", "Pending"), "eventReason": "WaitForFirstConsumer", "noProvisionerAttempted": True},
        "explicitBind": {"pvcPhase": bound_pvc["status"]["phase"], "pvPhase": bound_pv["status"]["phase"], "sameStorageClass": bound_pvc["spec"]["storageClassName"] == bound_pv["spec"]["storageClassName"]},
        "negative": {"red": True, "countReason": "count != 1", "defaultReason": "default-class annotation present"},
        "cleanup": cleanup,
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # No default: a default names a location, and whatever a previous run left there
    # would be audited as this run's observation.
    parser.add_argument("--output", type=Path, required=True, help="this run's observation")
    arguments = parser.parse_args(argv)
    try:
        value = execute()
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("retained-storage-class-live: PASS (one inert class, wait reason, explicit bind, negative, cleanup)")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired, yaml.YAMLError) as problem:
        cleanup_test_resources()
        print(f"retained-storage-class-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
