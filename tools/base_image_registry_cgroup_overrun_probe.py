#!/usr/bin/env python3
"""Deliberately cross the Phase-31 builder CPU and memory cgroup ceilings."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Sequence


DOCKER = "/usr/bin/docker"


class CgroupFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, check: bool = True, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        raise CgroupFailure(f"command-failed:{arguments[0]}:{result.stdout}")
    return result


def docker_exec(container: str, command: str, *, check: bool = True, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return run((DOCKER, "exec", container, "sh", "-c", command), check=check, timeout=timeout)


def counters(container: str, name: str) -> dict[str, int]:
    result = run((DOCKER, "exec", container, "cat", f"/sys/fs/cgroup/{name}"))
    decoded: dict[str, int] = {}
    for line in result.stdout.splitlines():
        key, value = line.split()
        decoded[key] = int(value)
    return decoded


def exercise(container: str) -> dict[str, object]:
    cpu_before = counters(container, "cpu.stat")
    docker_exec(
        container,
        'pids=""; for n in $(seq 1 64); do '
        'yes >/dev/null & pids="$pids $!"; done; sleep 12; kill $pids; wait || true',
    )
    cpu_after = counters(container, "cpu.stat")
    if cpu_after["nr_throttled"] <= cpu_before["nr_throttled"]:
        raise CgroupFailure("cpu-overrun-not-throttled")

    memory_before = counters(container, "memory.events")
    mount = "/amoebius-scratch/oom-boundary-probe"
    docker_exec(
        container,
        f"mkdir -p {mount}; mount -t tmpfs -o size=8g tmpfs {mount}",
    )
    try:
        oom = docker_exec(
            container,
            f"echo 1000 > /proc/self/oom_score_adj; exec dd if=/dev/zero of={mount}/fill bs=8388608 count=960",
            check=False,
            timeout=90,
        )
    finally:
        docker_exec(container, f"umount {mount}; rmdir {mount}", check=False, timeout=60)
    memory_after = counters(container, "memory.events")
    if oom.returncode not in (137, -9):
        raise CgroupFailure(f"memory-overrun-exit:{oom.returncode}:{oom.stdout}")
    if memory_after["oom_kill"] <= memory_before["oom_kill"]:
        raise CgroupFailure("memory-overrun-not-oom-killed")

    inspected = json.loads(run((DOCKER, "inspect", container)).stdout)[0]
    if inspected["State"]["Running"] is not True:
        raise CgroupFailure("builder-died-after-child-oom")
    process = docker_exec(container, "test -r /proc/1/comm; cat /proc/1/comm")
    if process.stdout.strip() != "buildkitd":
        raise CgroupFailure(f"builder-main-process:{process.stdout.strip()}")
    return {
        "schema": "amoebius.phase25.cgroup-overrun.v1",
        "container": container,
        "cpuBefore": cpu_before,
        "cpuAfter": cpu_after,
        "cpuThrottleDelta": cpu_after["nr_throttled"] - cpu_before["nr_throttled"],
        "memoryBefore": memory_before,
        "memoryAfter": memory_after,
        "oomKillDelta": memory_after["oom_kill"] - memory_before["oom_kill"],
        "oomStageExit": oom.returncode,
        "builderStillRunning": True,
        "builderMainProcess": "buildkitd",
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", default="amoebius-base-image-registry-buildkitd")
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        result = exercise(arguments.container)
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        print("phase25-cgroup-overrun-probe: PASS (CPU throttled; child OOM-killed; BuildKit survived)")
        return 0
    except (
        CgroupFailure, OSError, ValueError, KeyError, json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-cgroup-overrun-probe: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
