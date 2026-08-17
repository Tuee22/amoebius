#!/usr/bin/env python3
"""Prove Phase-30 BuildKit scratch and local-cache ENOSPC boundaries."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Sequence


DOCKER = "/usr/bin/docker"
SUDO = "/usr/bin/sudo"
ROOT = Path(__file__).resolve().parents[1]
BUILDKIT_CONFIG = ROOT / "test/fixture/base_image_registry/buildkitd.toml"
MEMORY_BYTES = 7_516_192_768
EXPECTED_MARKERS = ("no space left on device", "enospc")


class BoundaryFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, timeout: int = 180, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=timeout, check=False,
    )
    if check and result.returncode:
        raise BoundaryFailure(f"command-failed:{arguments[0]}:{result.stdout}")
    return result


def write_incompressible(path: Path, size: int) -> None:
    remaining = size
    with path.open("wb") as handle:
        while remaining:
            chunk = os.urandom(min(1024 * 1024, remaining))
            handle.write(chunk)
            remaining -= len(chunk)


def wait_for(path: Path) -> None:
    for _ in range(200):
        if path.exists():
            return
        time.sleep(0.05)
    raise BoundaryFailure(f"builder-socket-timeout:{path}")


def bootstrap(config: Path, builder: str) -> None:
    last = ""
    for _ in range(30):
        result = docker(
            config, "buildx", "inspect", "--builder", builder, "--bootstrap",
            check=False, timeout=20,
        )
        if result.returncode == 0:
            return
        last = result.stdout
        time.sleep(0.25)
    raise BoundaryFailure(f"disposable-builder-bootstrap:{last}")


def docker(config: Path, *arguments: str, check: bool = True, timeout: int = 180) -> subprocess.CompletedProcess[str]:
    return run((DOCKER, "--config", str(config), *arguments), check=check, timeout=timeout)


def cleanup(config: Path, builder: str, container: str) -> None:
    docker(config, "buildx", "rm", builder, check=False, timeout=60)
    run((DOCKER, "rm", "--force", container), check=False, timeout=60)


def builder_inspect(container: str) -> dict[str, Any]:
    decoded = json.loads(run((DOCKER, "inspect", container)).stdout)
    if not isinstance(decoded, list) or len(decoded) != 1:
        raise BoundaryFailure("disposable-builder-inspect-count")
    host = decoded[0]["HostConfig"]
    if host["Runtime"] != "runc" or host["NanoCpus"] != 7_000_000_000:
        raise BoundaryFailure("disposable-builder-cpu-boundary")
    if host["Memory"] != MEMORY_BYTES or host["MemorySwap"] != MEMORY_BYTES:
        raise BoundaryFailure("disposable-builder-memory-boundary")
    if host.get("DeviceRequests"):
        raise BoundaryFailure("disposable-builder-accelerator-exposed")
    return {
        "runtime": host["Runtime"],
        "cpuNano": host["NanoCpus"],
        "memoryBytes": host["Memory"],
        "memorySwapBytes": host["MemorySwap"],
        "tmpfs": host["Tmpfs"],
    }


def require_enospc(result: subprocess.CompletedProcess[str], scenario: str) -> str:
    if result.returncode == 0:
        raise BoundaryFailure(f"{scenario}-unexpectedly-succeeded")
    compact = " ".join(result.stdout.split()).lower()
    if not any(marker in compact for marker in EXPECTED_MARKERS):
        raise BoundaryFailure(f"{scenario}-wrong-failure:{result.stdout[-2000:]}")
    return " ".join(result.stdout.split())[-1000:]


def scenario(
    root: Path,
    image: str,
    name: str,
    worker_bytes: int,
    payload_bytes: int,
    cache_bytes: int | None,
) -> dict[str, Any]:
    config = root / f"{name}-docker-config"
    # AF_UNIX is limited to 108 bytes on Linux.  The marked test-run prefix is
    # intentionally descriptive, so keep only this internal socket component
    # compact while retaining the scenario name in every human-facing resource.
    socket_root = root / f"{name[0]}s"
    context = root / f"{name}-context"
    cache_root = root / f"{name}-cache"
    for path in (config, socket_root, context):
        path.mkdir()
    (context / "Dockerfile").write_text(
        "# syntax=docker/dockerfile:1.7\nFROM scratch\nCOPY payload /payload\n",
        encoding="utf-8",
    )
    write_incompressible(context / "payload", payload_bytes)
    builder = f"amoebius-base-image-registry-enospc-{name}"
    container = f"amoebius-base-image-registry-enospc-{name}-buildkitd"
    mounted_cache = False
    try:
        if cache_bytes is not None:
            cache_root.mkdir()
            run(
                (
                    SUDO, "-n", "/usr/bin/mount", "-t", "tmpfs",
                    "-o", f"size={cache_bytes},nosuid,nodev,noexec",
                    "phase25-cache-boundary", str(cache_root),
                )
            )
            mounted_cache = True
        run(
            (
                DOCKER, "run", "--detach", "--name", container,
                "--runtime", "runc", "--privileged", "--cpus", "7",
                "--memory", str(MEMORY_BYTES), "--memory-swap", str(MEMORY_BYTES),
                "--restart", "no",
                "--tmpfs", f"/var/lib/buildkit:rw,size={worker_bytes}",
                "--mount", f"type=bind,source={socket_root},target=/run/phase25",
                "--mount",
                f"type=bind,source={BUILDKIT_CONFIG},target=/etc/buildkit/buildkitd.toml,readonly",
                image, "--addr", "unix:///run/phase25/buildkitd.sock",
                "--group", str(os.getgid()),
                "--config", "/etc/buildkit/buildkitd.toml",
            )
        )
        socket = socket_root / "buildkitd.sock"
        wait_for(socket)
        docker(
            config, "buildx", "create", "--name", builder, "--driver", "remote",
            f"unix://{socket}",
        )
        bootstrap(config, builder)
        command = [
            "buildx", "build", "--builder", builder, "--platform", "linux/amd64",
            "--file", str(context / "Dockerfile"), "--provenance=false", "--sbom=false",
            "--output", "type=cacheonly",
        ]
        if cache_bytes is not None:
            command.extend(("--cache-to", f"type=local,dest={cache_root}/export,mode=max"))
        command.append(str(context))
        result = docker(config, *command, check=False, timeout=600)
        observed = builder_inspect(container)
        cache_fs = None
        if cache_bytes is not None:
            stats = os.statvfs(cache_root)
            cache_fs = {
                "sizeBytes": stats.f_blocks * stats.f_frsize,
                "usedBytes": (stats.f_blocks - stats.f_bfree) * stats.f_frsize,
            }
            if int(cache_fs["sizeBytes"]) > cache_bytes:
                raise BoundaryFailure("cache-tmpfs-size-exceeded")
        return {
            "scenario": name,
            "workerScratchBytes": worker_bytes,
            "payloadBytes": payload_bytes,
            "cacheBytes": cache_bytes,
            "exit": result.returncode,
            "failure": require_enospc(result, name),
            "builder": observed,
            "cacheFilesystem": cache_fs,
        }
    finally:
        cleanup(config, builder, container)
        if mounted_cache:
            run((SUDO, "-n", "/usr/bin/umount", str(cache_root)), check=False, timeout=60)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path)
    # The disposable builders this probe starts run the image the caller resolved for this
    # run. There is deliberately no default: a constant would pin a build that no longer
    # exists, and the boundary would then be proven against an image nobody is building on.
    parser.add_argument(
        "--builder-image", required=True, help="the resolved BuildKit builder image reference"
    )
    arguments = parser.parse_args(argv)
    try:
        test_root_text = os.environ.get("AMOEBIUS_TEST_ROOT", "")
        if not test_root_text:
            raise BoundaryFailure("AMOEBIUS_TEST_ROOT is required")
        temporary_parent = Path(test_root_text) / "e"
        temporary_parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="c-", dir=temporary_parent) as temporary:
            root = Path(temporary)
            results = [
                scenario(root, arguments.builder_image, "scratch", 536_870_912, 805_306_368, None),
                scenario(root, arguments.builder_image, "cache", 1_073_741_824, 67_108_864, 16_777_216),
            ]
        evidence = {
            "schema": "amoebius.phase25.builder-enospc.v1",
            "image": arguments.builder_image,
            "results": results,
        }
        encoded = json.dumps(evidence, indent=2, sort_keys=True) + "\n"
        if arguments.evidence:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        print("phase25-enospc-probe: PASS (scratch and cache writes failed inside distinct finite backings)")
        return 0
    except (BoundaryFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase25-enospc-probe: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
