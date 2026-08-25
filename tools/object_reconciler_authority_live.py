#!/usr/bin/env python3
"""Exercise bootstrap Lease authority and scoped SSA on the Phase-30 cluster."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
KUBECONFIG = Path(os.environ.get(
    "AMOEBIUS_KUBECONFIG",
    str(ROOT / ".build/tmp/object-reconciler/unconfigured-kubeconfig"),
))
KUBECTL = os.environ.get("AMOEBIUS_KUBECTL", "/usr/bin/kubectl")
NAMESPACE = "amoebius-phase26-sprint2"
LEASE = "amoebius-reconciler"
HOLDER = "phase26-bootstrap-host"


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, stdin: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, input=stdin,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=180,
    )
    if check and result.returncode:
        raise LiveFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), stdin=stdin, check=check)


def apply_object(value: dict[str, Any], manager: str, *, force: bool = False) -> None:
    arguments = ["apply", "--server-side", f"--field-manager={manager}"]
    if force:
        arguments.append("--force-conflicts")
    arguments.extend(("-f", "-"))
    kubectl(*arguments, stdin=json.dumps(value))


def get(kind: str, name: str) -> dict[str, Any]:
    return json.loads(kubectl("-n", NAMESPACE, "get", kind, name, "-o", "json", "--show-managed-fields").stdout)


def desired_config(challenge: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": "scoped-ssa",
            "namespace": NAMESPACE,
            "labels": {
                "app.kubernetes.io/managed-by": "amoebius",
                "amoebius.io/owner": "phase26-sprint2",
            },
            "annotations": {"amoebius.io/challenge": challenge},
        },
        "data": {"owned": "v1"},
    }


def execute() -> dict[str, Any]:
    challenge = uuid.uuid4().hex
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found", "--wait=true", "--timeout=120s")
    cold_order: list[str] = []
    namespace = {
        "apiVersion": "v1",
        "kind": "Namespace",
        "metadata": {"name": NAMESPACE, "labels": {"amoebius.io/owner": "phase26-sprint2"}},
    }
    apply_object(namespace, "amoebius-bootstrap")
    cold_order.append(f"Namespace/{NAMESPACE}")
    lease = {
        "apiVersion": "coordination.k8s.io/v1",
        "kind": "Lease",
        "metadata": {"name": LEASE, "namespace": NAMESPACE},
        "spec": {"holderIdentity": HOLDER, "leaseDurationSeconds": 60},
    }
    apply_object(lease, "amoebius-bootstrap")
    cold_order.append(f"Lease/{NAMESPACE}/{LEASE}")
    observed_lease = get("lease", LEASE)
    if observed_lease["spec"].get("holderIdentity") != HOLDER:
        raise LiveFailure("lease-holder-readback")
    lease_uid = str(observed_lease["metadata"]["uid"])
    lease_rv = str(observed_lease["metadata"]["resourceVersion"])

    stale = dict(observed_lease)
    stale["metadata"] = dict(stale["metadata"])
    stale["metadata"]["resourceVersion"] = str(max(1, int(lease_rv) - 1))
    stale["spec"] = dict(stale["spec"])
    stale["spec"]["holderIdentity"] = "foreign-holder"
    stale_result = kubectl("replace", "-f", "-", stdin=json.dumps(stale), check=False)
    if stale_result.returncode == 0 or "the object has been modified" not in stale_result.stdout.lower():
        raise LiveFailure(f"stale-lease-cas-not-rejected:{stale_result.returncode}:{stale_result.stdout}")
    after_stale = get("lease", LEASE)
    if after_stale["spec"].get("holderIdentity") != HOLDER:
        raise LiveFailure("stale-lease-changed-holder")

    desired = desired_config(challenge)
    apply_object(desired, "amoebius")
    foreign = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": "scoped-ssa",
            "namespace": NAMESPACE,
            "annotations": {"foreign.example/owned": "preserve-me"},
        },
    }
    apply_object(foreign, "foreign-manager")
    kubectl("-n", NAMESPACE, "patch", "configmap", "scoped-ssa", "--type=merge", "-p", '{"data":{"owned":"drift"}}')
    drifted = get("configmap", "scoped-ssa")
    if drifted.get("data", {}).get("owned") != "drift":
        raise LiveFailure("drift-not-induced")
    apply_object(desired, "amoebius", force=True)
    corrected = get("configmap", "scoped-ssa")
    if corrected.get("data", {}).get("owned") != "v1":
        raise LiveFailure("owned-field-not-corrected")
    if corrected["metadata"].get("annotations", {}).get("foreign.example/owned") != "preserve-me":
        raise LiveFailure("foreign-field-overwritten")
    if corrected["metadata"].get("annotations", {}).get("amoebius.io/challenge") != challenge:
        raise LiveFailure("fresh-challenge-not-read-back")
    managers = sorted({str(row.get("manager", "")) for row in corrected["metadata"].get("managedFields", [])})
    if "amoebius" not in managers or "foreign-manager" not in managers:
        raise LiveFailure(f"managed-field-domain:{managers}")

    before_noop = get("configmap", "scoped-ssa")
    apply_object(desired, "amoebius", force=True)
    after_noop = get("configmap", "scoped-ssa")
    if before_noop["metadata"]["resourceVersion"] != after_noop["metadata"]["resourceVersion"]:
        raise LiveFailure("idempotent-ssa-changed-resource-version")

    result = {
        "schema": "amoebius.phase26.sprint26.2-live.v1",
        "capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "register": 3,
        "substrate": "linux-cpu",
        "challenge": challenge,
        "coldStartOrder": cold_order,
        "lease": {
            "holder": HOLDER,
            "uid": lease_uid,
            "resourceVersion": lease_rv,
            "staleCasExit": stale_result.returncode,
            "staleCasReason": "object has been modified",
        },
        "ssa": {
            "fieldManager": "amoebius",
            "managedFieldManagers": managers,
            "ownedFieldCorrected": True,
            "foreignFieldPreserved": True,
            "noOpResourceVersionStable": True,
        },
    }
    kubectl("delete", "namespace", NAMESPACE, "--wait=true", "--timeout=120s")
    if kubectl("get", "namespace", NAMESPACE, check=False).returncode == 0:
        raise LiveFailure("namespace-leaked")
    result["postflightNamespaceAbsent"] = True
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    try:
        result = execute()
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.output is None:
            print(encoded, end="")
        else:
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(encoded, encoding="utf-8")
        print("phase26-sprint26.2-live: PASS (Lease CAS + scoped SSA + leak-free teardown)")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase26-sprint26.2-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
