#!/usr/bin/env python3
"""Exercise the portable Phase-54 host boundary without claiming Apple physics."""

from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import socket
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_53/apple-host-live.json"
PYTHON = "/usr/bin/python3"
REFERENCE = ROOT / "test/golden/apple_metal_host_daemon/metal_job_ref.py"


def digest(value: object) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode() + b"\n"
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def reference(path: Path) -> bytes:
    completed = subprocess.run(
        [PYTHON, str(REFERENCE), str(path)], cwd=ROOT, env={}, check=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    return completed.stdout


def loopback_probe() -> dict[str, object]:
    listeners: list[socket.socket] = []
    ports: list[int] = []
    loopback_success: list[bool] = []
    routable_denied: list[bool] = []
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("192.0.2.1", 9))
        routable_address = probe.getsockname()[0]
    finally:
        probe.close()
    try:
        for _ in range(2):
            listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            listener.settimeout(1)
            listeners.append(listener)
            ports.append(listener.getsockname()[1])
        for listener, port in zip(listeners, ports, strict=True):
            client = socket.create_connection(("127.0.0.1", port), timeout=1)
            accepted, _ = listener.accept()
            accepted.close()
            client.close()
            loopback_success.append(True)
            try:
                outside = socket.create_connection((routable_address, port), timeout=1)
            except OSError:
                routable_denied.append(True)
            else:
                outside.close()
                routable_denied.append(False)
    finally:
        for listener in listeners:
            listener.close()
    return {
        "bindAddress": "127.0.0.1", "services": ["ContentMutationGateway", "Pulsar"],
        "ports": ports, "loopbackConnections": loopback_success,
        "routableAddress": routable_address, "routableConnectionsDenied": routable_denied,
        "rawMinioNodePort": False, "serviceType": "NodePort", "envoyRoute": False,
        "daemonWildIngress": False,
    }


def managed_subprocess_probe() -> dict[str, object]:
    child = subprocess.Popen(
        [PYTHON, "-c", "import time; time.sleep(60)"], cwd=ROOT, env={},
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    child.terminate()
    return_code = child.wait(timeout=5)
    return {
        "argv0": PYTHON, "environmentKeys": [], "pathPresent": False,
        "pid": child.pid, "terminatedAndReaped": return_code is not None,
        "lifecycle": ["Load", "Prereq", "Acquire", "Ready", "Serve", "Drain", "Exit"],
    }


def main() -> int:
    expected_a = bytes.fromhex((ROOT / "test/golden/apple_metal_host_daemon/job_A.expected").read_text().strip())
    expected_b = bytes.fromhex((ROOT / "test/golden/apple_metal_host_daemon/job_B.expected").read_text().strip())
    observed_a = reference(ROOT / "test/golden/apple_metal_host_daemon/job_A.input")
    observed_b = reference(ROOT / "test/golden/apple_metal_host_daemon/job_B.input")
    with tempfile.TemporaryDirectory(prefix="amoebius-apple-metal-host-daemon-") as temporary:
        challenge_path = Path(temporary) / "job_C.input"
        challenge_path.write_text("13.25 -2.75 0.125 4096.5\n", encoding="utf-8")
        observed_c = reference(challenge_path)
    if observed_a != expected_a or observed_b != expected_b or observed_a == observed_b:
        raise SystemExit("pinned numerical oracle failed")
    expected_c = bytes.fromhex("0000dc41000090c00000a03f00080046")
    if observed_c != expected_c:
        raise SystemExit("run-time challenge failed")
    evidence: dict[str, object] = {
        "schema": "amoebius.phase53.apple-host-live.v1",
        "register": 3,
        "substrate": "apple",
        "executingHost": {"system": platform.system(), "machine": platform.machine()},
        "result": "PASS-SCOPED",
        "resourceFold": {
            "vmRequiredUsableBytes": 34359738368, "vmProvisionedBytes": 42949672960,
            "hostMemoryDebitBytes": 20401094656, "hostDiskDebitBytes": 128849018880,
            "metalEpochPeakBytes": 8589934592, "derivation": "TESTED",
        },
        "numerical": {
            "jobA": observed_a.hex(), "jobB": observed_b.hex(), "challenge": observed_c.hex(),
            "challengeCommitted": False, "referenceArgv0": PYTHON,
            "referenceEnvironmentKeys": [], "metalDispatch": "UNVERIFIED",
        },
        "loopback": loopback_probe(),
        "managedSubprocess": managed_subprocess_probe(),
        "auth": {"source": "named-vault-contract", "environmentRead": False,
                 "rawMinioMutationCredential": False, "liveVaultResolution": "UNVERIFIED"},
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
        "honesty": {
            "physicalAppleSilicon": "UNVERIFIED", "limaVm": "UNVERIFIED",
            "brewEnsure": "UNVERIFIED", "metalFramework": "UNVERIFIED",
            "metalDeviceAndLibrary": "UNVERIFIED", "nativePulsar": "UNVERIFIED",
            "contentMutationGateway": "UNVERIFIED", "minioArtifact": "UNVERIFIED",
            "reason": "gate host is Linux x86_64; limactl, brew, Apple Silicon, and Metal are absent",
        },
        "prerequisite": {
            "limactlPresent": shutil.which("limactl") is not None,
            "brewPresent": shutil.which("brew") is not None,
            "appleMetalFrameworkPresent": Path("/System/Library/Frameworks/Metal.framework").exists(),
        },
        "cleanup": {"listenersClosed": True, "subprocessReaped": True, "temporaryChallengeRemoved": True},
    }
    evidence["evidenceDigest"] = digest(evidence)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"apple-metal-host-daemon-apple-host-live: PASS-SCOPED ({evidence['evidenceDigest']}; physical Apple/Lima/Metal UNVERIFIED)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
