#!/usr/bin/env python3
"""Verify the live Phase-25 BuildKit process and finite backing boundaries."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


EXPECTED_IMAGE = (
    "moby/buildkit:buildx-stable-1@"
    "sha256:2f5adac4ecd194d9f8c10b7b5d7bceb5186853db1b26e5abd3a657af0b7e26ec"
)
EXPECTED_CPU_NANO = 7_000_000_000
EXPECTED_CPU_MAX = "700000 100000"
EXPECTED_MEMORY = 7_516_192_768
EXPECTED_SCRATCH_CAPACITY = 103_079_215_104
EXPECTED_CACHE_CAPACITY = 68_719_476_736
DOCKER = "/usr/bin/docker"


class BuilderFailure(RuntimeError):
    pass


def run(arguments: Sequence[str]) -> str:
    result = subprocess.run(
        list(arguments), text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False,
    )
    if result.returncode:
        raise BuilderFailure(f"command-failed:{arguments[0]}:{result.stdout}")
    return result.stdout


def docker_json(*arguments: str) -> Any:
    return json.loads(run((DOCKER, *arguments)))


def cgroup_value(container: str, path: str) -> str:
    return run((DOCKER, "exec", container, "cat", path)).strip()


def filesystem(path: Path) -> dict[str, Any]:
    stats = os.statvfs(path)
    return {
        "path": str(path.resolve()),
        "device": os.stat(path).st_dev,
        "sizeBytes": stats.f_blocks * stats.f_frsize,
        "usedBytes": (stats.f_blocks - stats.f_bfree) * stats.f_frsize,
        "availableBytes": stats.f_bavail * stats.f_frsize,
    }


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise BuilderFailure(tag)


def inspect_builder(
    container: str,
    cache_root: Path,
    scratch_root: Path,
    config: Path,
) -> dict[str, Any]:
    decoded = docker_json("inspect", container)
    require(isinstance(decoded, list) and len(decoded) == 1, "builder-inspect-count")
    inspected = decoded[0]
    host = inspected["HostConfig"]
    require(inspected["State"]["Running"] is True, "builder-not-running")
    require(inspected["Config"]["Image"] == EXPECTED_IMAGE, "builder-image-drift")
    require(host["Runtime"] == "runc", "builder-runtime-not-runc")
    require(not host.get("DeviceRequests"), "builder-accelerator-exposed")
    require(host["NanoCpus"] == EXPECTED_CPU_NANO, "builder-cpu-limit-drift")
    require(host["Memory"] == EXPECTED_MEMORY, "builder-memory-limit-drift")
    require(host["MemorySwap"] == EXPECTED_MEMORY, "builder-memory-swap-limit-drift")
    require(host["Privileged"] is True, "builder-oci-worker-not-privileged")
    require(host["RestartPolicy"]["Name"] == "no", "builder-restart-policy-drift")

    mounts = {row["Destination"]: row for row in inspected["Mounts"]}
    require("/var/lib/buildkit" in mounts, "builder-cache-mount-missing")
    require("/amoebius-scratch" in mounts, "builder-scratch-mount-missing")
    require("/etc/buildkit/buildkitd.toml" in mounts, "builder-config-mount-missing")
    scratch_mount = mounts["/amoebius-scratch"]
    config_mount = mounts["/etc/buildkit/buildkitd.toml"]
    require(
        Path(scratch_mount["Source"]).resolve() == scratch_root.resolve(),
        "builder-scratch-root-drift",
    )
    require(
        Path(config_mount["Source"]).resolve() == config.resolve() and not config_mount["RW"],
        "builder-config-root-drift",
    )
    volume = docker_json("volume", "inspect", mounts["/var/lib/buildkit"]["Name"])
    require(isinstance(volume, list) and len(volume) == 1, "builder-cache-volume-count")
    require(
        Path(volume[0]["Options"]["device"]).resolve()
        == (scratch_root / "buildkit-state").resolve(),
        "builder-state-root-drift",
    )

    cache_fs = filesystem(cache_root)
    scratch_fs = filesystem(scratch_root)
    require(cache_fs["device"] != scratch_fs["device"], "builder-backing-alias")
    require(cache_fs["sizeBytes"] >= EXPECTED_CACHE_CAPACITY, "builder-cache-capacity")
    require(scratch_fs["sizeBytes"] >= EXPECTED_SCRATCH_CAPACITY, "builder-scratch-capacity")
    require(cache_fs["usedBytes"] <= EXPECTED_CACHE_CAPACITY, "builder-cache-write-overrun")
    require(scratch_fs["usedBytes"] <= EXPECTED_SCRATCH_CAPACITY, "builder-scratch-write-overrun")

    cpu_max = cgroup_value(container, "/sys/fs/cgroup/cpu.max")
    memory_max = cgroup_value(container, "/sys/fs/cgroup/memory.max")
    memory_swap_max = cgroup_value(container, "/sys/fs/cgroup/memory.swap.max")
    require(cpu_max == EXPECTED_CPU_MAX, "builder-cgroup-cpu-drift")
    require(memory_max == str(EXPECTED_MEMORY), "builder-cgroup-memory-drift")
    require(memory_swap_max == "0", "builder-cgroup-swap-enabled")
    worker_config = run(
        (DOCKER, "exec", container, "cat", "/etc/buildkit/buildkitd.toml")
    )
    normalized = worker_config.replace(" ", "")
    require("max-parallelism=2" in normalized, "builder-stage-parallelism-drift")

    return {
        "schema": "amoebius.phase25.builder-boundary.v1",
        "container": container,
        "image": EXPECTED_IMAGE,
        "runtime": host["Runtime"],
        "acceleratorDeviceRequests": host.get("DeviceRequests"),
        "cpuNano": host["NanoCpus"],
        "cpuMax": cpu_max,
        "cpuStat": cgroup_value(container, "/sys/fs/cgroup/cpu.stat"),
        "memoryBytes": host["Memory"],
        "memoryMax": memory_max,
        "memorySwapMax": memory_swap_max,
        "memoryEvents": cgroup_value(container, "/sys/fs/cgroup/memory.events"),
        "stageParallelism": 2,
        "cache": cache_fs,
        "scratch": scratch_fs,
        "config": str(config.resolve()),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", default="amoebius-phase25-buildkitd")
    parser.add_argument("--cache-root", type=Path, required=True)
    parser.add_argument("--scratch-root", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        result = inspect_builder(
            arguments.container,
            arguments.cache_root,
            arguments.scratch_root,
            arguments.config,
        )
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        print("phase25-builder-probe: PASS (runc linux-cpu boundary; CPU, memory, cache, scratch, and stage limits verified)")
        return 0
    except (BuilderFailure, KeyError, OSError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase25-builder-probe: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
