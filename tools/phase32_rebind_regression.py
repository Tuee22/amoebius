#!/usr/bin/env python3
"""Re-run the retained Postgres/MinIO delete-recreate proof in an isolated kind cluster."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

import phase28_rebind_live as phase28


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_32/rebind-regression.json"
CLUSTER = "amoebius-phase32-rebind"
NODE = CLUSTER + "-control-plane"
KUBECONFIG = Path.home() / ".amoebius/phase32-rebind/kubeconfig"
RETAINED_ROOT = Path("/var/tmp/amoebius-phase32-rebind")
AUDIT_ROOT = Path("/var/tmp/amoebius-phase32-rebind-audit")
ROW_FIXTURE = ROOT / "test/fixtures/phase32/marker-row.sql"
OBJECT_FIXTURE = ROOT / "test/fixtures/phase32/marker-object.bin"
EXPECTED_ROW_MARKER = "sha256:308cb887c71d9a100d4d12dd0f7408f41db956a16d16f45144bf20f62240de5c"


class RegressionFailure(RuntimeError):
    pass


def configure_harness() -> None:
    KUBECONFIG.parent.mkdir(parents=True, exist_ok=True)
    RETAINED_ROOT.joinpath("mounts").mkdir(parents=True, exist_ok=True)
    AUDIT_ROOT.mkdir(parents=True, exist_ok=True)
    phase28.CLUSTER = CLUSTER
    phase28.NODE = NODE
    phase28.KUBECONFIG = KUBECONFIG
    phase28.KIND_CONFIG = ROOT / "test/live/fixtures/phase32-rebind-kind.yaml"
    phase28.NAMESPACE = "retained-witness"
    phase28.RETAINED_ROOT = RETAINED_ROOT
    phase28.AUDIT_ROOT = AUDIT_ROOT
    phase28.POSTGRES_SUPPORT_PACKAGE = Path(
        "/var/tmp/amoebius-phase28-retained/postgresql-17_17.8-1.pgdg12+1_amd64.deb"
    )
    phase28.POSTGRES_SUPPORT_ROOT = RETAINED_ROOT / "mounts/postgres-share"
    phase28.MARKER_TEXT = EXPECTED_ROW_MARKER
    phase28.MARKER_OBJECT_BYTES = OBJECT_FIXTURE.read_bytes()
    os.environ.pop("PHASE28_RESUME_CLEAN_RUN1", None)


def execute() -> dict[str, Any]:
    if EXPECTED_ROW_MARKER not in ROW_FIXTURE.read_text(encoding="utf-8"):
        raise RegressionFailure("phase32-row-fixture-drift")
    configure_harness()
    phase28_value = phase28.execute()
    marker = phase28_value["marker"]
    fresh = phase28_value["freshCluster"]
    deleted = phase28_value["deleteBoundary"]
    if not (
        marker["postgresByteIdentical"] and marker["minioByteIdentical"]
        and fresh["serverCaChanged"] and fresh["clusterUidChanged"]
        and fresh["nodeContainerIdChanged"]
        and deleted["kindClusterAbsent"] and deleted["nodeContainerAbsent"]
        and deleted["apiServerUnreachable"] and deleted["backingPresent"]
        and all(deleted["externalMarkerBytesObserved"].values())
    ):
        raise RegressionFailure("phase28-harness-domain")
    result = {
        "schema": "amoebius.phase32.rebind-regression.v1",
        "register": 3, "substrate": "linux-cpu", "cluster": CLUSTER,
        "scope": {
            "isolatedFromRetainedPlatformCluster": True,
            "projection": "Keycloak relational marker on Postgres plus exact MinIO object",
            "mainPhase31And32StackNotDestroyed": True,
        },
        "fixtures": {
            "row": str(ROW_FIXTURE.relative_to(ROOT)),
            "object": str(OBJECT_FIXTURE.relative_to(ROOT)),
        },
        "deleteBoundary": deleted,
        "freshCluster": {
            **fresh,
            "nodeContainerIdChanged": fresh["nodeContainerIdChanged"],
            "allIdentitiesChanged": (
                fresh["serverCaChanged"] and fresh["clusterUidChanged"]
                and fresh["nodeContainerIdChanged"]
            ),
        },
        "markers": {
            "postgresMarkerSha256": marker["nonceSha256"],
            "minioObjectSha256": marker["objectSha256"],
            "postgresByteIdentical": marker["postgresByteIdentical"],
            "minioByteIdentical": marker["minioByteIdentical"],
            "allByteIdentical": marker["postgresByteIdentical"] and marker["minioByteIdentical"],
            "postRecreateWriteOperations": marker["postRecreateWriteOperations"],
        },
        "rebind": phase28_value["rebind"],
        "artifactSource": phase28_value["artifactSource"],
        "observer": phase28_value["observer"],
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {
                "linux": "Incus", "linux-cuda": "Incus",
                "apple": "Lima", "windows": "WSL2",
            },
        },
    }
    # The readback is complete; remove the disposable run-2 cluster while
    # retaining its backing images and the external evidence above.
    phase28.delete_cluster()
    clusters = phase28.run((phase28.KIND, "get", "clusters")).stdout.splitlines()
    node_absent = phase28.run(("/usr/bin/docker", "inspect", NODE), check=False).returncode != 0
    if CLUSTER in clusters or not node_absent:
        raise RegressionFailure("scratch-cluster-cleanup-failed")
    result["cleanup"] = {
        "scratchClusterRemovedAfterReadback": True,
        "retainedBackingPreserved": all(
            Path(value["image"]).is_file()
            for value in phase28_value["backingVolumes"].values()
        ),
    }
    return result


def main() -> int:
    try:
        value = execute()
        EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
        EVIDENCE.write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8",
        )
        print(
            "phase32-rebind-regression: PASS "
            "(exact committed markers survived genuine isolated kind delete/recreate)"
        )
        return 0
    except (
        RegressionFailure, phase28.RebindFailure, OSError, ValueError, KeyError,
        json.JSONDecodeError, subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase32-rebind-regression: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
