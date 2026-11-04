from __future__ import annotations

import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import vault_raft_observer as observer  # noqa: E402


SIZE = 4096


def meta(identity: int, transaction: int, pages: int = 4) -> bytes:
    data = bytearray(SIZE)
    struct.pack_into("<QHHI", data, 0, identity, 4, 0, 0)
    struct.pack_into("<IIIIQQQQQ", data, 16, 0xED0CDAED, 2, SIZE, 0, 2, 0, 0, pages, transaction)
    struct.pack_into("<Q", data, 72, observer.checksum(data[16:72]))
    return bytes(data)


def leaf(identity: int, entries: list[tuple[int, bytes, bytes]]) -> bytes:
    data = bytearray(SIZE)
    struct.pack_into("<QHHI", data, 0, identity, 2, len(entries), 0)
    position = 16 + len(entries) * 16
    for index, (flags, key, value) in enumerate(entries):
        element = 16 + index * 16
        struct.pack_into("<IIII", data, element, flags, position - element, len(key), len(value))
        data[position:position + len(key) + len(value)] = key + value
        position += len(key) + len(value)
    return bytes(data)


def database(indexes: tuple[int, ...] = (5, 7)) -> bytes:
    return (meta(0, 1) + meta(1, 2)
            + leaf(2, [(1, b"logs", struct.pack("<QQ", 3, 0))])
            + leaf(3, [(0, index.to_bytes(8, "big"), b"encrypted-log") for index in indexes]))


class VaultRaftObserverSpec(unittest.TestCase):
    def test_reads_newest_valid_meta_and_only_indexes(self) -> None:
        result = observer.log_indexes(database())
        self.assertEqual((result["lowestLogIndex"], result["highestLogIndex"], result["logEntryCount"]), (5, 7, 2))
        self.assertEqual(result["metaTransactionId"], 2)
        self.assertEqual(result["logIndexes"], [5, 7])

    def test_bad_latest_checksum_uses_valid_previous_meta(self) -> None:
        data = bytearray(database())
        data[SIZE + 72] ^= 1
        self.assertEqual(observer.log_indexes(bytes(data))["metaTransactionId"], 1)

    def test_both_bad_checksums_fail_closed(self) -> None:
        data = bytearray(database())
        data[72] ^= 1
        data[SIZE + 72] ^= 1
        with self.assertRaisesRegex(observer.ObservationError, "meta-checksum"):
            observer.log_indexes(bytes(data))

    def test_compacted_prefix_is_visible_from_real_keys(self) -> None:
        before = observer.log_indexes(database((1, 2, 3, 4)))
        after = observer.log_indexes(database((3, 4)))
        self.assertGreater(after["lowestLogIndex"], before["lowestLogIndex"])
        self.assertEqual(after["logEntryCount"], 2)

    def test_branch_tree_is_followed(self) -> None:
        branch = bytearray(SIZE)
        struct.pack_into("<QHHI", branch, 0, 3, 1, 1, 0)
        struct.pack_into("<IIQ", branch, 16, 16, 8, 4)
        branch[32:40] = (9).to_bytes(8, "big")
        data = (meta(0, 1, 5) + meta(1, 2, 5)
                + leaf(2, [(1, b"logs", struct.pack("<QQ", 3, 0))]) + bytes(branch)
                + leaf(4, [(0, (9).to_bytes(8, "big"), b"encrypted")]))
        self.assertEqual(observer.log_indexes(data)["lowestLogIndex"], 9)

    def test_inline_bucket_is_supported(self) -> None:
        inline = leaf(0, [(0, (8).to_bytes(8, "big"), b"encrypted")])[:57]
        data = (meta(0, 1) + meta(1, 2)
                + leaf(2, [(1, b"logs", struct.pack("<QQ", 0, 0) + inline)]) + bytes(SIZE))
        self.assertEqual(observer.log_indexes(data)["highestLogIndex"], 8)

    def test_out_of_order_keys_are_rejected(self) -> None:
        with self.assertRaisesRegex(observer.ObservationError, "index-order"):
            observer.log_indexes(database((7, 5)))


if __name__ == "__main__":
    unittest.main()
