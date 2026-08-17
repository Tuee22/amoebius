#!/usr/bin/env python3
"""Observe and fingerprint the no-builder Phase-30 host boundary."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "dhall/amoebius/BakeCatalog.dhall"
CPU_CARVE_MILLIS = 8_000
# Live host carve: one GiB above the independently derived 7 GiB transition.
# The Phase-0 pure fixture retains a larger 12 GiB residual to exercise exact
# arithmetic; live admission binds the smaller current snapshot.
MEMORY_CARVE_BYTES = 8_589_934_592
DOCKER = "/usr/bin/docker"


class PreflightFailure(RuntimeError):
    pass


def run(arguments: Sequence[str]) -> str:
    result = subprocess.run(
        list(arguments), text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False,
    )
    if result.returncode:
        raise PreflightFailure(f"command-failed:{arguments[0]}:{result.stdout}")
    return result.stdout.strip()


def provisions() -> tuple[int, int]:
    """The scratch and cache capacities the catalog declares.

    Read rather than restated: the pre-amendment constants here were sized for a
    CUDA devel base and exceeded the free space of every host in the linux-cpu
    lane, so the admission they gated could not have passed anywhere.
    """
    decoded = json.loads(
        run((shutil.which("dhall-to-json") or "dhall-to-json", "--file", str(CATALOG)))
    )
    return int(decoded["scratchCapacityBytes"]), int(decoded["cacheCapacityBytes"])


def memory_available() -> int:
    for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
        if line.startswith("MemAvailable:"):
            return int(line.split()[1]) * 1024
    raise PreflightFailure("mem-available-absent")


def filesystem(path: Path) -> dict[str, int | str]:
    stats = os.statvfs(path)
    return {
        "path": str(path.resolve()),
        "device": os.stat(path).st_dev,
        "sizeBytes": stats.f_blocks * stats.f_frsize,
        "availableBytes": stats.f_bavail * stats.f_frsize,
    }


def directory_bytes(path: Path) -> int:
    output = run(
        ("/usr/bin/sudo", "-n", "/usr/bin/du", "--summarize", "--bytes", str(path))
    )
    return int(output.split()[0])


def observe(cache_root: Path, scratch_root: Path, docker_config: Path) -> dict[str, Any]:
    scratch_capacity, cache_capacity = provisions()
    cache = filesystem(cache_root)
    scratch = filesystem(scratch_root)
    if cache["device"] == scratch["device"]:
        raise PreflightFailure("build-backing-alias")
    if int(cache["availableBytes"]) < cache_capacity:
        raise PreflightFailure("build-cache-capacity")
    if int(scratch["availableBytes"]) < scratch_capacity:
        raise PreflightFailure("build-scratch-capacity")

    # Docker emits one JSON object per line when multiple containers exist.
    raw_containers = run(
        (DOCKER, "--config", str(docker_config), "ps", "--all", "--format", "{{json .}}")
    )
    decoded_containers = [json.loads(line) for line in raw_containers.splitlines() if line]
    buildkit_containers = [
        row for row in decoded_containers
        if "buildkit" in str(row.get("Image", "")).lower()
        or "buildkit" in str(row.get("Names", "")).lower()
    ]
    if buildkit_containers:
        names = ",".join(str(row.get("Names", "unknown")) for row in buildkit_containers)
        raise PreflightFailure(f"unknown-build-commitment:{names}")
    builders = run((DOCKER, "--config", str(docker_config), "buildx", "ls"))
    if any(line.startswith("amoebius-base-image-registry-bounded") for line in builders.splitlines()):
        raise PreflightFailure("unknown-build-commitment:amoebius-base-image-registry-bounded")

    cpu_total = (os.cpu_count() or 0) * 1000
    available_memory = memory_available()
    if cpu_total < CPU_CARVE_MILLIS:
        raise PreflightFailure(f"host-cpu-short:{cpu_total}")
    if available_memory < MEMORY_CARVE_BYTES:
        raise PreflightFailure(f"host-memory-short:{available_memory}")
    cache_resident = directory_bytes(cache_root)
    if cache_resident > cache_capacity:
        raise PreflightFailure(f"cache-resident-over-capacity:{cache_resident}")

    observation = {
        "schema": "amoebius.phase25.build-preflight.v1",
        "cpuTotalMillis": cpu_total,
        "residualCpuMillis": CPU_CARVE_MILLIS,
        "memoryAvailableBytes": available_memory,
        "residualMemoryBytes": MEMORY_CARVE_BYTES,
        "scratch": scratch,
        "scratchCapacityBytes": scratch_capacity,
        "cache": cache,
        "cacheCapacityBytes": cache_capacity,
        "cacheResidentBytes": cache_resident,
        "architectureConcurrency": 2,
        "stageConcurrency": 2,
        "unknownBuildCommitments": [],
        "dockerConfig": str(docker_config.resolve()),
        "dockerVersion": run((DOCKER, "version", "--format", "{{.Client.Version}}/{{.Server.Version}}")),
        "buildxVersion": run((DOCKER, "buildx", "version")),
    }
    fingerprint_payload = json.dumps(observation, sort_keys=True, separators=(",", ":")).encode()
    observation["observedBuildFingerprint"] = "sha256:" + hashlib.sha256(fingerprint_payload).hexdigest()
    return observation


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-root", type=Path, required=True)
    parser.add_argument("--scratch-root", type=Path, required=True)
    parser.add_argument("--docker-config", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        result = observe(
            arguments.cache_root, arguments.scratch_root, arguments.docker_config
        )
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        print("phase25-build-preflight: PASS (no builder; finite host snapshot fingerprinted)")
        return 0
    except (PreflightFailure, OSError, ValueError, KeyError, json.JSONDecodeError) as problem:
        print(f"phase25-build-preflight: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
