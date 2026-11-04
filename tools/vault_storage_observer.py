#!/usr/bin/env python3
"""Independently sample owned Vault filesystems throughout a live run.

This elevated observer reads raw file metadata and filesystem allocation. It
does not accept a compliance report from Vault or the amoebius client.
"""

from __future__ import annotations

import argparse
import json
import os
import stat
import time
from pathlib import Path
from typing import Any

import containment


def inventory(root: Path) -> dict[str, Any]:
    files: dict[str, Any] = {}
    transient = 0

    def unreadable(error: OSError) -> None:
        nonlocal transient
        if isinstance(error, FileNotFoundError):
            transient += 1
        else:
            raise error

    for directory, _directories, names in os.walk(root, followlinks=False, onerror=unreadable):
        for name in names:
            path = Path(directory) / name
            try:
                observed = path.lstat()
            except FileNotFoundError:
                transient += 1
                continue
            if stat.S_ISREG(observed.st_mode):
                files[str(path.relative_to(root))] = {
                    "sizeBytes": observed.st_size,
                    "allocatedBytes": observed.st_blocks * 512,
                    "modifiedNs": observed.st_mtime_ns,
                    "inode": observed.st_ino,
                    "device": observed.st_dev,
                }
    space = root.stat().st_dev, os.statvfs(root)
    return {
        "device": space[0],
        "filesystemUsedBytes": (space[1].f_blocks - space[1].f_bfree) * space[1].f_frsize,
        "filesystemAvailableBytes": space[1].f_bavail * space[1].f_frsize,
        "files": files, "transientRemovals": transient,
    }


def snapshot_databases(files: dict[str, Any]) -> list[str]:
    """Vault 1.20.2 installs a new BoltDB beside its active FSM database."""
    active = files.get("raft/vault.db")
    if not active or active["allocatedBytes"] <= 0:
        return []
    return sorted(name for name, value in files.items()
                  if name.startswith("raft/raft/snapshots/") and name.endswith("/vault.db")
                  and len(Path(name).parts) == 5 and value["allocatedBytes"] > 0
                  and (value["device"], value["inode"]) != (active["device"], active["inode"]))


def watch(volumes: dict[str, Path], output: Path, summary_path: Path, stop: Path) -> None:
    baseline = {name: inventory(root) for name, root in volumes.items()}
    peaks = {name: value["filesystemUsedBytes"] for name, value in baseline.items()}
    snapshots: set[str] = set()
    max_simultaneous_databases = 0
    max_active = max_backup = max_files = 0
    samples = 0
    last: dict[str, Any] | None = None
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as trace:
        while True:
            current = {name: inventory(root) for name, root in volumes.items()}
            for name, value in current.items():
                peaks[name] = max(peaks[name], value["filesystemUsedBytes"])
            installing = snapshot_databases(current["vault"]["files"])
            snapshots.update(installing)
            if installing:
                max_simultaneous_databases = max(max_simultaneous_databases, 1 + len(installing))
            audit = current["vault-audit"]["files"]
            logs = {name: data["sizeBytes"] for name, data in audit.items() if name == "audit.log" or name.startswith("audit.log.")}
            max_active = max(max_active, logs.get("audit.log", 0))
            max_backup = max(max_backup, max((size for name, size in logs.items() if name != "audit.log"), default=0))
            max_files = max(max_files, len(logs))
            samples += 1
            if current != last:
                trace.write(json.dumps({"timeNs": time.time_ns(), "volumes": current}, sort_keys=True) + "\n")
                trace.flush()
                last = current
            if stop.exists():
                break
            time.sleep(0.001)
    summary = {
        "schema": "amoebius.vault-storage-observer.v1", "samples": samples,
        "baseline": baseline, "peakFilesystemUsedBytes": peaks,
        "peakDataAllocatedBytes": {name: peaks[name] - value["filesystemUsedBytes"] for name, value in baseline.items()},
        "installingSnapshotDatabasesObserved": sorted(snapshots),
        "maximumSimultaneousFsmDatabases": max_simultaneous_databases,
        "maximumActiveAuditBytes": max_active, "maximumBackupAuditBytes": max_backup,
        "maximumAuditFileCount": max_files,
    }
    summary_path.write_text(json.dumps(summary, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--stop", required=True, type=Path)
    arguments = parser.parse_args()
    root = containment.require_state_path(arguments.test_root, "test", actor="test")
    if (root / containment.MARKER).read_bytes() != containment._marker_bytes(root.name):
        raise ValueError("storage-observer-test-marker-invalid")
    for path in (arguments.output, arguments.summary, arguments.stop):
        containment.require_state_path(path, "build", actor="test")
    volumes = {name: root / "retained/mounts" / name for name in ("vault", "vault-audit")}
    if len({path.stat().st_dev for path in volumes.values()}) != 2 or any(path.stat().st_dev == root.stat().st_dev for path in volumes.values()):
        raise ValueError("storage-observer-volumes-not-independent-filesystems")
    watch(volumes, arguments.output, arguments.summary, arguments.stop)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
