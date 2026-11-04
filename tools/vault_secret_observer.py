#!/usr/bin/env python3
"""Scan the declared secret surfaces out of process; the needle arrives on stdin.

No matching content or filename is emitted. Pod roots and processes must belong
to the kind node whose overlay is backed by this exact marker-owned test run.
"""

from __future__ import annotations

import argparse
import base64
import ctypes
import hashlib
import json
import os
import stat
import sys
import time
from pathlib import Path
from typing import Any

import containment


class ScanError(ValueError):
    pass


class NamespaceHandle(ValueError):
    """An nsfs kernel handle has identity but no readable file payload."""


class ProcessExited(ValueError):
    """The kernel has already discarded this process's address space."""


def namespace_handle(descriptor: int) -> bool:
    # Linux statfs starts with a native long f_type; 256 bytes accommodates the
    # complete structure on both supported CPU architectures. Inspect the open
    # descriptor so rename/mount races cannot turn an ordinary file into a skip.
    buffer = ctypes.create_string_buffer(256)
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.fstatfs(descriptor, ctypes.byref(buffer)):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))
    return ctypes.c_long.from_buffer(buffer).value == 0x6E736673  # NSFS_MAGIC


def scan_file(path: Path, needle: bytes) -> tuple[int, bool]:
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as handle:
        if not stat.S_ISREG(os.fstat(handle.fileno()).st_mode):
            raise ScanError("secret-observer-file-type-changed")
        if namespace_handle(handle.fileno()):
            raise NamespaceHandle()
        total, found, tail = 0, False, b""
        while chunk := handle.read(256 * 1024):
            total += len(chunk)
            combined = tail + chunk
            found = found or needle in combined
            tail = combined[-(len(needle) - 1):] if len(needle) > 1 else b""
        return total, found


def scan_tree(root: Path, needle: bytes, *, pod: bool = False) -> dict[str, int]:
    counts = {"files": 0, "bytes": 0, "matches": 0, "vanishedFiles": 0,
              "vanishedDirectories": 0, "namespaceHandles": 0}

    def unavailable(error: OSError) -> None:
        if isinstance(error, FileNotFoundError) and error.filename != str(root):
            counts["vanishedDirectories"] += 1
            return
        raise ScanError("secret-observer-directory-unavailable") from error

    for directory, directories, names in os.walk(root, followlinks=False, onerror=unavailable):
        if pod and Path(directory) == root:
            directories[:] = [name for name in directories if name not in {"proc", "sys", "dev"}]
        for name in directories + names:
            if needle in os.fsencode(name):
                counts["matches"] += 1
        for name in names:
            path = Path(directory) / name
            try:
                observed = path.lstat()
                if stat.S_ISLNK(observed.st_mode):
                    counts["matches"] += int(needle in os.fsencode(os.readlink(path)))
                elif stat.S_ISREG(observed.st_mode):
                    size, found = scan_file(path, needle)
                    counts["files"] += 1
                    counts["bytes"] += size
                    counts["matches"] += int(found)
            except FileNotFoundError:
                counts["vanishedFiles"] += 1
            except NamespaceHandle:
                counts["namespaceHandles"] += 1
            except OSError as error:
                raise ScanError("secret-observer-file-unavailable") from error
    return counts


def process_status(pid: int) -> dict[str, list[int]]:
    fields = Path(f"/proc/{pid}/status").read_text().splitlines()
    result = {}
    for line in fields:
        if line.startswith(("PPid:", "NSpid:")):
            key, value = line.split(":", 1)
            result[key] = [int(part) for part in value.split()]
    return result


def process_identity(pid: int) -> str:
    # Linux stat field 22 (starttime), after the parenthesized command.
    fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    return fields[19]


def owned_processes(node_pid: int) -> tuple[dict[int, dict[str, list[int]]], set[int]]:
    statuses = {}
    for path in Path("/proc").iterdir():
        if path.name.isdigit():
            try:
                statuses[int(path.name)] = process_status(int(path.name))
            except FileNotFoundError:
                continue
    owned = {node_pid}
    while True:
        expanded = owned | {pid for pid, value in statuses.items() if value.get("PPid", [-1])[0] in owned}
        if expanded == owned:
            return statuses, owned
        owned = expanded


def scan_process(pid: int, needle: bytes) -> dict[str, int]:
    try:
        environment = Path(f"/proc/{pid}/environ").read_bytes()
        arguments = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError as error:
        try:
            status = Path(f"/proc/{pid}/status").read_text().splitlines()
        except FileNotFoundError:
            raise ProcessExited("vanishedProcesses") from error
        state = next((line.split()[1] for line in status if line.startswith("State:")), "?")
        if state in {"Z", "X", "x"}:
            raise ProcessExited("zombieProcesses") from error
        raise ScanError("secret-observer-process-unavailable") from error
    return {"processes": 1, "matches": int(needle in environment) + int(needle in arguments)}


def scan_owned_processes(node_pid: int, needle: bytes, required: set[int]) -> tuple[list[dict[str, int]], dict[str, int]]:
    last_error: ScanError | None = None
    for _attempt in range(10):
        _statuses, current_owned = owned_processes(node_pid)
        rows: list[dict[str, int]] = []
        lifecycle = {"zombieProcesses": 0, "vanishedProcesses": 0}
        try:
            if not required.issubset(current_owned):
                raise ScanError("secret-observer-required-process-not-owned")
            for pid in sorted(current_owned):
                try:
                    rows.append(scan_process(pid, needle))
                except ProcessExited as error:
                    if pid in required:
                        raise ScanError("secret-observer-required-process-exited") from error
                    lifecycle[str(error)] += 1
            return rows, lifecycle
        except ScanError as error:
            last_error = error
            time.sleep(0.05)
    # Preserve the sanitized errno when a live process remains unreadable.
    raise ScanError("secret-observer-process-snapshot-unavailable") from (last_error.__cause__ if last_error else None)


def observe(test_root: Path, run_root: Path, node_pid: int, container_pids: list[int], needle: bytes) -> dict[str, Any]:
    if not 1 <= len(needle) <= 128:
        raise ScanError("secret-observer-needle-invalid")
    test_root = containment.require_state_path(test_root, "test", actor="test")
    run_root = containment.require_state_path(run_root, "build", actor="test")
    if (test_root / containment.MARKER).read_bytes() != containment._marker_bytes(test_root.name):
        raise ScanError("secret-observer-marker-invalid")
    start = process_identity(node_pid)
    mounts = Path(f"/proc/{node_pid}/mountinfo").read_text().splitlines()
    root_mounts = [line for line in mounts if len(line.split()) > 5 and line.split()[4] == "/"]
    if not any(str(test_root) in line for line in root_mounts):
        raise ScanError("secret-observer-node-not-owned-by-test-run")
    statuses, owned = owned_processes(node_pid)
    namespace_depth = len(statuses[node_pid].get("NSpid", [])) - 1
    if namespace_depth < 0 or not container_pids:
        raise ScanError("secret-observer-pod-identity-unavailable")
    pod_pids = []
    for container_pid in container_pids:
        matches = [pid for pid in owned if len(statuses.get(pid, {}).get("NSpid", [])) > namespace_depth
                   and statuses[pid]["NSpid"][namespace_depth] == container_pid]
        if len(matches) != 1:
            raise ScanError("secret-observer-pod-identity-ambiguous")
        pod_pids.append(matches[0])
    identities = {pid: process_identity(pid) for pid in pod_pids}
    process_rows, lifecycle = scan_owned_processes(node_pid, needle, {node_pid, *pod_pids})
    surfaces = {
        "ownedHostState": scan_tree(test_root, needle),
        "runOutput": scan_tree(run_root, needle),
        "podFilesystems": [scan_tree(Path(f"/proc/{pid}/root"), needle, pod=True) for pid in pod_pids],
        "processState": process_rows,
        "processLifecycle": lifecycle,
    }
    if process_identity(node_pid) != start or any(process_identity(pid) != identity for pid, identity in identities.items()):
        raise ScanError("secret-observer-process-identity-changed")
    matches = (surfaces["ownedHostState"]["matches"] + surfaces["runOutput"]["matches"]
               + sum(row["matches"] for row in surfaces["podFilesystems"] + surfaces["processState"]))
    return {"schema": "amoebius.vault-secret-observer.v1", "clean": matches == 0,
            "needleSha256": hashlib.sha256(needle).hexdigest(), "surfaces": surfaces}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test-root", type=Path, required=True)
    parser.add_argument("--run-root", type=Path, required=True)
    parser.add_argument("--node-pid", type=int, required=True)
    parser.add_argument("--container-pid", type=int, action="append", required=True)
    arguments = parser.parse_args()
    payload = json.loads(sys.stdin.buffer.read(4096))
    needle = base64.b64decode(payload["needle"], validate=True)
    try:
        value = observe(arguments.test_root, arguments.run_root, arguments.node_pid, arguments.container_pid, needle)
    except (ScanError, OSError, ValueError, KeyError) as error:
        # Exception details can contain a filename that itself leaked the needle.
        detail = {"clean": False, "observerAvailable": False, "errorType": type(error).__name__}
        if isinstance(error, ScanError):
            # ScanError messages are fixed codes authored in this module.
            detail["errorCode"] = str(error)
        cause = error.__cause__ if error.__cause__ is not None else error
        if isinstance(cause, OSError):
            detail["errno"] = cause.errno
        print(json.dumps(detail))
        return 1
    print(json.dumps(value, sort_keys=True))
    return 0 if value["clean"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
