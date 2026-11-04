#!/usr/bin/env python3
"""Physically owned retained-storage pool and pre-allocation inventory admission."""

from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
from pathlib import Path
from typing import Mapping

import containment


class BackingError(ValueError):
    pass


POOL_OVERHEAD_BYTES = 64 * 1024**2


def pool_raw_bytes(capacity: int) -> int:
    """ext4-v1 metadata allowance: at least 64 MiB, otherwise five percent.

    Round the added allowance to MiB. A constant overhead that fits the small
    Vault pool cannot fund inode tables and journals on a multi-gigabyte pool.
    """
    if capacity <= 0:
        raise BackingError("durable-backing-capacity-invalid")
    quantum = 1024**2
    scaled = ((capacity + 20 * quantum - 1) // (20 * quantum)) * quantum
    return capacity + max(POOL_OVERHEAD_BYTES, scaled)


def inventory_plan(capacity: int, existing: Mapping[str, int], proposed: Mapping[str, int]) -> dict[str, int]:
    """Union stable identities before spending; a retry cannot debit one twice."""
    if capacity <= 0:
        raise BackingError("durable-backing-capacity-invalid")
    planned = dict(existing)
    for name, size in proposed.items():
        if not name or Path(name).name != name or name in {".", ".."} or size <= 0:
            raise BackingError("retained-image-demand-invalid")
        if name in planned and planned[name] != size:
            raise BackingError(f"retained-image-resize-not-authorized:{name}")
        planned[name] = size
    if any(size <= 0 for size in planned.values()) or sum(planned.values()) > capacity:
        raise BackingError("durable-demand-exceeds-backing")
    return planned


def reserved_bytes(path: Path, raw_bytes: int) -> int:
    observed = path.stat(follow_symlinks=False)
    if not stat.S_ISREG(observed.st_mode) or observed.st_size != raw_bytes:
        raise BackingError(f"retained-image-size:{path}:{observed.st_size}:{raw_bytes}")
    allocated = observed.st_blocks * 512
    if allocated < raw_bytes:
        raise BackingError(f"retained-image-not-physically-reserved:{path}:{allocated}:{raw_bytes}")
    return allocated


def create_image(path: Path, raw_bytes: int) -> None:
    """Create exclusively, reserve blocks, and initialize only this new image.

    Writing the reserved extent also avoids later unwritten-extent conversions
    confusing the independent parent-allocation observation during the fill test.
    Existing retained bytes are never truncated or initialized here.
    """
    if raw_bytes <= 0:
        raise BackingError("retained-image-demand-invalid")
    with path.open("xb") as handle:
        try:
            os.posix_fallocate(handle.fileno(), 0, raw_bytes)
            block = bytes(min(raw_bytes, 4 * 1024**2))
            remaining = raw_bytes
            while remaining:
                amount = min(remaining, len(block))
                handle.write(block[:amount])
                remaining -= amount
            handle.flush()
            os.fsync(handle.fileno())
        except BaseException:
            path.unlink(missing_ok=True)
            raise
    reserved_bytes(path, raw_bytes)


def _run(*arguments: str) -> str:
    result = subprocess.run(arguments, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
    if result.returncode:
        raise BackingError(f"retained-backing-command:{arguments[0]}:{result.returncode}:{result.stdout}")
    return result.stdout.strip()


def _mounted(root: Path) -> bool:
    return subprocess.run(("/usr/bin/mountpoint", "-q", str(root)), check=False).returncode == 0


def format_and_mount_new_image(image: Path, target: Path, raw_bytes: int) -> None:
    """Format an exclusively created, completely zero-initialized block device.

    Prezeroed storage also prevents background inode-table zeroing from issuing
    zero-range operations that release the parent's physically reserved blocks.
    Never use this for a remount or any image not initialized by create_image.
    A loop created by this call is detached if formatting or mounting fails.
    """
    reserved_bytes(image, raw_bytes)
    loop = _run("/usr/bin/sudo", "-n", "/usr/sbin/losetup", "--find", "--show", str(image))
    if not loop.startswith("/dev/loop"):
        raise BackingError("retained-loop-identity")
    try:
        _run("/usr/bin/sudo", "-n", "/usr/sbin/mkfs.ext4", "-q", "-F", "-m", "0", "-E", "nodiscard,assume_storage_prezeroed=1", loop)
        reserved_bytes(image, raw_bytes)
        _run("/usr/bin/sudo", "-n", "/usr/bin/mount", "-o", "nodiscard", loop, str(target))
        # Release the explicit attachment after unmount, like mount -o loop.
        _run("/usr/bin/sudo", "-n", "/usr/sbin/losetup", "--detach", loop)
    except BaseException:
        subprocess.run(("/usr/bin/sudo", "-n", "/usr/sbin/losetup", "--detach", loop), check=False)
        raise


def _pool_image(root: Path) -> Path:
    return root.parent / "disks/retained-durable-pool.ext4"


def existing_inventory(root: Path) -> dict[str, int]:
    return {path.stem: path.stat().st_size for path in (root / "images").glob("*.ext4")}


def observe_pool(root: Path) -> dict[str, object]:
    if not _mounted(root):
        raise BackingError("durable-pool-not-mounted")
    metadata = json.loads((root / ".durable-pool.json").read_text())
    capacity = int(metadata["capacityBytes"])
    raw_bytes = pool_raw_bytes(capacity)
    image = _pool_image(root)
    allocated = reserved_bytes(image, raw_bytes)
    source = _run("/usr/bin/findmnt", "-n", "-o", "SOURCE", "--target", str(root))
    filesystem = _run("/usr/bin/findmnt", "-n", "-o", "FSTYPE", "--target", str(root))
    if not source.startswith("/dev/loop") or filesystem != "ext4":
        raise BackingError("durable-pool-filesystem-identity")
    backing = Path("/sys/class/block") / Path(source).name / "loop/backing_file"
    if Path(backing.read_text().strip()).resolve() != image.resolve():
        raise BackingError("durable-pool-backing-identity")
    space = os.statvfs(root)
    usable = space.f_blocks * space.f_frsize
    if usable < capacity or root.stat().st_dev == root.parent.stat().st_dev:
        raise BackingError("durable-pool-capacity-not-owned")
    inventory = existing_inventory(root)
    inventory_plan(capacity, inventory, {})
    for name, size in inventory.items():
        reserved_bytes(root / "images" / f"{name}.ext4", size)
    return {
        "capacityBytes": capacity, "physicalRawBytes": raw_bytes,
        "physicalAllocatedBytes": allocated, "physicalUsableBytes": usable,
        "poolImage": str(image), "filesystemType": filesystem,
        "inventory": inventory, "postReconcileDebitBytes": sum(inventory.values()),
    }


def prepare_pool(root: Path, capacity: int, proposed: Mapping[str, int]) -> dict[str, int]:
    """Reject over-budget demand before creating any backing, mount, or child."""
    root = containment.require_state_path(root, "test", actor="test")
    if not (root.parent / containment.MARKER).is_file():
        raise BackingError("test-root-marker-absent")
    existing = existing_inventory(root)
    planned = inventory_plan(capacity, existing, proposed)
    if _mounted(root):
        if observe_pool(root)["capacityBytes"] != capacity:
            raise BackingError("durable-pool-capacity-changed")
        return planned
    if root.exists() and any(path.is_file() or path.is_symlink() for path in root.rglob("*")):
        raise BackingError("unmounted-retained-bytes-present")
    image = _pool_image(root)
    raw_bytes = pool_raw_bytes(capacity)
    if image.exists():
        raise BackingError("unmounted-durable-pool-present")
    if raw_bytes > shutil.disk_usage(root.parent).free:
        raise BackingError("durable-pool-parent-capacity")
    image.parent.mkdir(parents=True, exist_ok=True)
    root.mkdir(parents=True, exist_ok=True)
    create_image(image, raw_bytes)
    format_and_mount_new_image(image, root, raw_bytes)
    _run("/usr/bin/sudo", "-n", "/usr/bin/chown", f"{os.getuid()}:{os.getgid()}", str(root))
    (root / ".durable-pool.json").write_text(json.dumps({"capacityBytes": capacity}) + "\n")
    observe_pool(root)
    return planned
