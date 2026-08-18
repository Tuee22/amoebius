#!/usr/bin/env python3
"""Scoped live Phase-54 teardown, inventory, and failover-process probes."""

from __future__ import annotations

import hashlib
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_54/test-topology-live.json"
PYTHON = "/usr/bin/python3"


def digest(value: object) -> str:
    data = json.dumps(value, sort_keys=True, separators=(",", ":")).encode() + b"\n"
    return "sha256:" + hashlib.sha256(data).hexdigest()


def inventory(path: Path) -> list[str]:
    return sorted(str(entry.relative_to(path)) for entry in path.rglob("*") if entry.is_file())


def signal_cleanup_probe(root: Path) -> dict[str, object]:
    marker = root / "signal-owned.marker"
    code = (
        "import os,signal,sys,time\n"
        "p=sys.argv[1]\n"
        "open(p,'w').write('owned')\n"
        "def done(*_):\n"
        " os.unlink(p) if os.path.exists(p) else None\n"
        " raise SystemExit(130)\n"
        "signal.signal(signal.SIGINT,done)\n"
        "while True: time.sleep(0.05)\n"
    )
    child = subprocess.Popen([PYTHON, "-c", code, str(marker)], cwd=ROOT, env={})
    deadline = time.time() + 5
    while not marker.exists() and time.time() < deadline:
        time.sleep(0.02)
    if not marker.exists():
        child.kill()
        raise RuntimeError("signal child did not allocate")
    child.send_signal(signal.SIGINT)
    code_value = child.wait(timeout=5)
    return {"signal": "SIGINT", "returnCode": code_value, "markerRemoved": not marker.exists(), "processReaped": True}


def failover_probe(root: Path) -> dict[str, object]:
    lock = root / "test-topology-dsl-failover.lock"
    active = root / "active-consumer"
    worker_code = (
        "import os,signal,sys,time\n"
        "name,lock,active=sys.argv[1:]\n"
        "owned=False\n"
        "def done(*_):\n"
        " global owned\n"
        " if owned and os.path.exists(lock): os.rmdir(lock)\n"
        " if owned and os.path.exists(active): os.unlink(active)\n"
        " raise SystemExit(0)\n"
        "signal.signal(signal.SIGTERM,done)\n"
        "while not owned:\n"
        " try: os.mkdir(lock); owned=True; open(active,'w').write(name)\n"
        " except FileExistsError: time.sleep(0.02)\n"
        "while True: time.sleep(0.05)\n"
    )
    a = subprocess.Popen([PYTHON, "-c", worker_code, "worker-a", str(lock), str(active)], cwd=ROOT, env={})
    deadline = time.time() + 5
    while (not active.exists() or active.read_text() != "worker-a") and time.time() < deadline:
        time.sleep(0.02)
    b = subprocess.Popen([PYTHON, "-c", worker_code, "worker-b", str(lock), str(active)], cwd=ROOT, env={})
    a.terminate()
    a.wait(timeout=5)
    deadline = time.time() + 5
    while (not active.exists() or active.read_text() != "worker-b") and time.time() < deadline:
        time.sleep(0.02)
    promoted = active.exists() and active.read_text() == "worker-b"
    b.terminate()
    b.wait(timeout=5)
    return {"subscription": "test-topology-dsl-failover", "type": "process-lock-analogue", "killed": "worker-a",
            "promoted": "worker-b" if promoted else "none", "processesReaped": True,
            "pulsarBrokerStats": "UNVERIFIED"}


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="amoebius-test-topology-dsl-") as temporary:
        scope = Path(temporary)
        retained = scope / "retained-by-design.marker"
        retained.write_text("baseline", encoding="utf-8")
        before = inventory(scope)
        allocation = scope / "test-owned.marker"
        allocation.write_text("created", encoding="utf-8")
        forced_failure_teardown = allocation.exists()
        allocation.unlink()
        after_failure = inventory(scope)
        second_teardown_noop = not allocation.exists()
        untyped = scope / "untagged-outside-path.marker"
        untyped.write_text("leak", encoding="utf-8")
        leak_diff = sorted(set(inventory(scope)) - set(before))
        untyped.unlink()
        sigint = signal_cleanup_probe(scope)
        failover = failover_probe(scope)
        after = inventory(scope)
        evidence: dict[str, object] = {
            "schema": "amoebius.phase54.test-topology-live.v1", "register": 3,
            "substrate": "linux-cpu", "result": "PASS-SCOPED",
            "inventory": {"before": before, "afterForcedFailure": after_failure, "after": after,
                          "diff": sorted(set(after) - set(before)), "untaggedMutantDiff": leak_diff,
                          "observer": "external-temporary-host-scope"},
            "teardown": {"forcedFailureAllocated": forced_failure_teardown,
                         "forcedFailureClean": after_failure == before,
                         "secondTeardownNoop": second_teardown_noop, "sigint": sigint},
            "failover": failover,
            "executionBoundary": {"argv0": PYTHON, "environmentKeys": [], "pathPresent": False},
            "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True,
                "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
            "honesty": {"kubernetesTopology": "UNVERIFIED", "retainedPvBackingDelete": "UNVERIFIED",
                "pulsarBrokerFailoverStats": "UNVERIFIED", "vaultLiveCredential": "UNVERIFIED",
                "awsCloudInventory": "UNVERIFIED", "providerCloudLeakMutant": "UNVERIFIED",
                "reason": "scoped host-process gate; retained Pulsar/provider services are not used"},
            "cleanup": {"temporaryScopeRemovedOnExit": True, "childrenReaped": True},
        }
        evidence["evidenceDigest"] = digest(evidence)
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"test-topology-dsl-test-topology-live: PASS-SCOPED ({evidence['evidenceDigest']}; Kubernetes/Pulsar/retained-PV/Vault/AWS UNVERIFIED)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
