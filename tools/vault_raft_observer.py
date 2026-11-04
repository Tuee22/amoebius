#!/usr/bin/env python3
"""Read Raft log indexes from bbolt bytes without consulting Vault's own trace.

The v2 page/meta layout and checksum are defined by etcd-io/bbolt's page.go
and db.go; hashicorp/raft-boltdb stores big-endian indexes in its `logs` bucket.
Only structural indexes are returned. Encrypted log values are never emitted.
"""

from __future__ import annotations

import struct
import time
from pathlib import Path


class ObservationError(ValueError):
    pass


def checksum(data: bytes) -> int:
    value = 14695981039346656037
    for byte in data:
        value = ((value ^ byte) * 1099511628211) & ((1 << 64) - 1)
    return value


def log_indexes(data: bytes) -> dict[str, int | list[int]]:
    candidates: list[tuple[int, int, int, int]] = []
    for size in (4096, 8192, 16384, 32768, 65536):
        for offset in (0, size):
            if offset + 80 > len(data):
                continue
            page_id, flags, _count, _overflow = struct.unpack_from("<QHHI", data, offset)
            magic, version, page_size, _flags = struct.unpack_from("<IIII", data, offset + 16)
            root, _sequence, _freelist, high_water, transaction, observed_sum = struct.unpack_from("<QQQQQQ", data, offset + 32)
            if (page_id == offset // size and flags == 4 and magic == 0xED0CDAED
                    and version == 2 and page_size == size
                    and observed_sum == checksum(data[offset + 16:offset + 72])):
                candidates.append((transaction, root, high_water, size))
    if not candidates:
        raise ObservationError("raft-bbolt-meta-checksum-or-format")
    transaction, root, high_water, page_size = max(candidates)
    if root >= high_water or high_water * page_size > len(data):
        raise ObservationError("raft-bbolt-meta-bounds")

    def walk(page_id: int, seen: set[int], inline: bytes | None = None) -> list[tuple[int, bytes, bytes]]:
        if inline is None:
            if page_id in seen or page_id >= high_water:
                raise ObservationError("raft-page-cycle-or-bounds")
            seen.add(page_id)
            offset = page_id * page_size
            if offset + 16 > len(data):
                raise ObservationError("raft-page-header-bounds")
            identity, flags, count, overflow = struct.unpack_from("<QHHI", data, offset)
            if identity != page_id:
                raise ObservationError("raft-page-identity")
            end = offset + (overflow + 1) * page_size
            if end > len(data):
                raise ObservationError("raft-page-overflow-bounds")
            page = data[offset:end]
        else:
            if len(inline) < 16:
                raise ObservationError("raft-inline-page-bounds")
            _identity, flags, count, _overflow = struct.unpack_from("<QHHI", inline)
            page = inline
        if 16 + count * 16 > len(page):
            raise ObservationError("raft-page-elements-bounds")
        result: list[tuple[int, bytes, bytes]] = []
        for index in range(count):
            element = 16 + index * 16
            if flags == 1:
                position, key_size, child = struct.unpack_from("<IIQ", page, element)
                if element + position + key_size > len(page):
                    raise ObservationError("raft-branch-key-bounds")
                result.extend(walk(child, seen))
            elif flags == 2:
                entry_flags, position, key_size, value_size = struct.unpack_from("<IIII", page, element)
                start = element + position
                end = start + key_size + value_size
                if start < 16 + count * 16 or end > len(page):
                    raise ObservationError("raft-leaf-value-bounds")
                result.append((entry_flags, page[start:start + key_size], page[start + key_size:end]))
            else:
                raise ObservationError("raft-page-kind")
        return result

    buckets = [(flags, value) for flags, key, value in walk(root, set()) if key == b"logs"]
    if len(buckets) != 1 or buckets[0][0] != 1 or len(buckets[0][1]) < 16:
        raise ObservationError("raft-log-bucket-absent-or-invalid")
    bucket = buckets[0][1]
    bucket_root, _sequence = struct.unpack_from("<QQ", bucket)
    entries = walk(bucket_root, set(), bucket[16:] if bucket_root == 0 else None)
    indexes: list[int] = []
    for flags, key, _value in entries:
        if flags != 0 or len(key) != 8:
            raise ObservationError("raft-log-index-format")
        indexes.append(int.from_bytes(key, "big"))
    if indexes != sorted(set(indexes)):
        raise ObservationError("raft-log-index-order")
    return {"lowestLogIndex": min(indexes, default=0), "highestLogIndex": max(indexes, default=0),
            "logEntryCount": len(indexes), "logIndexes": indexes, "metaTransactionId": transaction,
            "databaseBytes": len(data), "pageSize": page_size}


def observe(path: Path, maximum_bytes: int) -> dict[str, int | list[int]]:
    """Retry a changing database; fail closed on incomplete or unknown bytes."""
    for _attempt in range(10):
        if path.stat().st_size > maximum_bytes:
            raise ObservationError("raft-database-exceeds-provision")
        with path.open("rb") as handle:
            before = handle.read(131072)
            handle.seek(0)
            data = handle.read(maximum_bytes + 1)
            handle.seek(0)
            after = handle.read(131072)
        if before == after and data[:len(before)] == before:
            return log_indexes(data)
        time.sleep(0.02)
    raise ObservationError("raft-database-did-not-quiesce")


def main() -> int:
    import argparse
    import json
    import containment

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test-root", required=True, type=Path)
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--maximum-bytes", required=True, type=int)
    arguments = parser.parse_args()
    root = containment.require_state_path(arguments.test_root, "test", actor="test")
    if (root / containment.MARKER).read_bytes() != containment._marker_bytes(root.name):
        raise ObservationError("raft-observer-marker-invalid")
    database = arguments.database.resolve()
    if not database.is_relative_to(root) or arguments.maximum_bytes <= 0:
        raise ObservationError("raft-observer-path-or-capacity-invalid")
    print(json.dumps(observe(database, arguments.maximum_bytes), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
