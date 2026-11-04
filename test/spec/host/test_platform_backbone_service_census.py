import struct
import copy
import json
import tempfile
import sys
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from platform_backbone_service_census import (
    CensusFailure, bookkeeper_records, zookeeper_transactions, validate_extents, final_records, zookeeper_snapshot,
    verify_final_records, inventory, gateway_filesystem_growth,
    ZK_PREALLOCATION_KIB, ZK_INITIAL_LOG_BYTES, ZK_NEXT_PAD_POSITION, zookeeper_history_below_next_padding,
)


class ServiceCensusTests(unittest.TestCase):
    def test_gateway_components_and_whole_filesystem_growth(self):
        mib = 1048576
        row = lambda size: {"sizeBytes": size, "allocatedBytes": size}
        legal = {"state.json": row(mib), "state.json.next": row(mib), "owner.lock": row(0),
                 "zookeeper-history/state": row(mib), "zookeeper-history/state.next": row(mib),
                 "zookeeper-history/owner.lock": row(0)}
        validate_extents("phase30-gateway-state", legal)
        self.assertEqual(gateway_filesystem_growth(7*mib, 15*mib), 8*mib)
        with self.assertRaisesRegex(CensusFailure, "whole-filesystem-growth"):
            gateway_filesystem_growth(7*mib, 15*mib+1)
        for path in ("state.json", "zookeeper-history/state", "zookeeper-history/state.next"):
            changed = copy.deepcopy(legal)
            changed[path] = row(mib+1)
            with self.subTest(path), self.assertRaisesRegex(CensusFailure, "state-profile-exceeded"):
                validate_extents("phase30-gateway-state", changed)

    def test_gateway_unknown_files_and_nonempty_locks_reject(self):
        with self.assertRaisesRegex(CensusFailure, "state-file-domain"):
            validate_extents("phase30-gateway-state", {"zookeeper-history/foreign": {"sizeBytes": 1, "allocatedBytes": 4096}})
        with self.assertRaisesRegex(CensusFailure, "state-lock-extent"):
            validate_extents("phase30-gateway-state", {"zookeeper-history/owner.lock": {"sizeBytes": 1, "allocatedBytes": 4096}})

    def entry(self, ledger=5, entry=7, payload=b"fresh-history"):
        body = struct.pack(">qq", ledger, entry) + payload
        return struct.pack(">i", len(body)) + body

    def test_entrylog_retains_deleted_history_without_metadata_lookup(self):
        header = b"BKLO\x00\x00\x00\x01" + bytes(1016)
        record = self.entry()
        result = bookkeeper_records(header + record, False)
        self.assertEqual(result["serializedBytes"], len(record))
        self.assertEqual(list(result["entries"]), [(5, 7)])

    def test_journal_padding_and_duplicate_physical_records_are_charged(self):
        header = b"BKLG\x00\x00\x00\x06" + bytes(504)
        record = self.entry()
        result = bookkeeper_records(header + record + record + struct.pack(">ii", -256, 4) + bytes(4 + 512), True)
        self.assertEqual(result["serializedBytes"], 2 * len(record))
        self.assertEqual(result["duplicateRecordCount"], 1)

    def test_all_history_includes_journal_controls(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            normal = self.entry()
            control = self.entry(entry=-4096, payload=b"master-key")
            (root / "0.log").write_bytes(b"BKLO\x00\x00\x00\x01" + bytes(1016) + normal)
            (root / "0.txn").write_bytes(b"BKLG\x00\x00\x00\x06" + bytes(504) + normal + control)
            result = final_records("phase30-bookkeeper-0", root, {"0.log": {}, "0.txn": {}})
            self.assertEqual(result["serializedHistoryBytes"], len(normal) + len(control))
            self.assertEqual(result["normalEntryHistoryBytes"], len(normal))

    def test_sparse_entry_id_cannot_fit_one_index_page(self):
        header = b"BKLO\x00\x00\x00\x01" + bytes(1016)
        with self.assertRaisesRegex(CensusFailure, "entry-id-exceeds-index-page"):
            bookkeeper_records(header + self.entry(entry=1024), False)

    def test_truncated_history_fails_closed(self):
        header = b"BKLO\x00\x00\x00\x01" + bytes(1016)
        with self.assertRaisesRegex(CensusFailure, "record-truncated"):
            bookkeeper_records(header + self.entry()[:-1], False)

    def test_nonzero_short_trailer_is_not_silently_discarded(self):
        header = b"BKLO\x00\x00\x00\x01" + bytes(1016)
        with self.assertRaisesRegex(CensusFailure, "unframed-trailer"):
            bookkeeper_records(header + self.entry() + b"X", False)
        with self.assertRaisesRegex(CensusFailure, "unframed-trailer"):
            zookeeper_transactions(self.transaction() + b"X")

    def transaction(self):
        header = b"ZKLG\x00\x00\x00\x02" + bytes(8)
        body = struct.pack(">qiqqi", 1, 2, 3, 4, 5)
        return header + struct.pack(">Qi", zlib.adler32(body), len(body)) + body + b"B"

    def test_zookeeper_jute_extent_and_adler32(self):
        result = zookeeper_transactions(self.transaction() + bytes(64))
        self.assertEqual(result, {"transactionCount": 1, "serializedTransactionBytes": 45})

    def test_bad_transaction_checksum_and_terminator_reject(self):
        bad_checksum = bytearray(self.transaction()); bad_checksum[16] ^= 1
        with self.assertRaisesRegex(CensusFailure, "transaction-checksum"):
            zookeeper_transactions(bytes(bad_checksum))
        with self.assertRaisesRegex(CensusFailure, "transaction-terminator"):
            zookeeper_transactions(self.transaction()[:-1] + b"C")

    def test_checksum_alone_cannot_attest_an_unparsed_tree(self):
        prefix = b"ZKSN\x00\x00\x00\x02" + bytes(8) + struct.pack(">i", 0) + b"tree-prefix"
        seal = lambda data: struct.pack(">Q", zlib.adler32(data)) + b"\x00\x00\x00\x01/"
        old = prefix + seal(prefix)
        whole = old + b"optional-zxid" + seal(old + b"optional-zxid")
        with self.assertRaisesRegex(CensusFailure, "zookeeper-complete-snapshot"):
            zookeeper_snapshot(whole)

    def test_census_uses_complete_frozen_snapshot_decoding(self):
        corpus = json.loads((Path(__file__).resolve().parents[2] / "oracle/platform_backbone_zookeeper_wire.json").read_text())
        checked = 0
        for row in corpus["snapshots"]:
            with self.subTest(row["id"]):
                # The installed profile explicitly enables both optional
                # sections; other codec profiles are tested by the wire suite.
                if not (row["profile"]["snapshot_digest"] and row["profile"]["snapshot_last_zxid"]):
                    continue
                checked += 1
                snapshot = bytes.fromhex(row["wireHex"])
                self.assertEqual(zookeeper_snapshot(snapshot), {"snapshotBytes": row["expected"]["bytes"],
                    "sessionCount": len(row["expected"]["state"]["sessions"])})
                with self.assertRaises(CensusFailure):
                    zookeeper_snapshot(snapshot[:-1] + b"X")
        self.assertGreater(checked, 0)
        for row in corpus["negativeCases"]:
            if row["kind"] == "snapshot":
                with self.subTest(row["id"]), self.assertRaises(CensusFailure):
                    zookeeper_snapshot(bytes.fromhex(row["wireHex"]))

    def test_saved_raw_history_recomputes_counters_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / "0.log").write_bytes(b"BKLO\x00\x00\x00\x01" + bytes(1016) + self.entry())
            volume = "phase30-bookkeeper-0"
            saved = root / "raw" / volume
            files = inventory(source)["files"]
            result = final_records(volume, source, files, capture=saved)
            verify_final_records(root, volume, result, files)
            corrupted = copy.deepcopy(result)
            corrupted["serializedHistoryBytes"] += 1
            with self.assertRaisesRegex(CensusFailure, "final-record-drift"):
                verify_final_records(root, volume, corrupted, files)
            with self.assertRaisesRegex(CensusFailure, "raw-inventory-mismatch"):
                verify_final_records(root, volume, result, {**files, "1.log": {}})
            wrong_size = copy.deepcopy(files)
            wrong_size["0.log"]["sizeBytes"] += 1
            with self.assertRaisesRegex(CensusFailure, "raw-final-extent-mismatch"):
                verify_final_records(root, volume, result, wrong_size)
            data = (saved / "0.log").read_bytes()
            (saved / "0.log").write_bytes(data[:-1] + bytes([data[-1] ^ 1]))
            with self.assertRaisesRegex(CensusFailure, "raw-digest"):
                verify_final_records(root, volume, result, files)

    def test_capture_rejects_growth_after_the_final_extent_sample(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            path = source / "0.txn"
            path.write_bytes(b"BKLG\x00\x00\x00\x06" + bytes(504) + self.entry())
            files = inventory(source)["files"]
            with path.open("ab") as stream:
                stream.write(bytes(512))
            with self.assertRaisesRegex(CensusFailure, "source-changed-after-final-sample"):
                final_records("phase30-bookkeeper-0", source, files, capture=root / "raw")

    def test_preallocation_and_generation_boundaries(self):
        exact = {"journal/current/1.txn": {"sizeBytes": 16 * 1048576, "allocatedBytes": 16 * 1048576}}
        self.assertEqual(validate_extents("phase30-bookkeeper-0", exact)["journalGenerations"], 1)
        over = {"journal/current/1.txn": {"sizeBytes": 16 * 1048576 + 1, "allocatedBytes": 16 * 1048576}}
        with self.assertRaisesRegex(CensusFailure, "journal-generations-or-extent"):
            validate_extents("phase30-bookkeeper-0", over)
        three = {str(i) + ".txn": {"sizeBytes": 0, "allocatedBytes": 0} for i in range(3)}
        with self.assertRaisesRegex(CensusFailure, "journal-generations-or-extent"):
            validate_extents("phase30-bookkeeper-0", three)

    def test_default_zookeeper_64m_preallocation_cannot_hide_in_128m_raw_claim(self):
        files = {"version-2/log.1": {"sizeBytes": 64 * 1048576, "allocatedBytes": 4096}}
        with self.assertRaisesRegex(CensusFailure, "log-generations-or-extent"):
            validate_extents("phase30-zookeeper-0", files)

    def test_reviewed_preallocation_header_extent_and_actual_next_pad_boundary(self):
        corpus = json.loads((Path(__file__).resolve().parents[2] / "oracle/platform_backbone_zookeeper_padding.json").read_text())
        profile = corpus["profile"]
        self.assertEqual("-Dzookeeper.preAllocSize=" + str(ZK_PREALLOCATION_KIB), profile["jvmProperty"])
        self.assertEqual(ZK_INITIAL_LOG_BYTES, profile["firstPaddedFileBytes"])
        self.assertEqual(ZK_NEXT_PAD_POSITION, profile["padTriggerPosition"])
        maximum = profile["maximumFinalFramedRecordBytesWithoutAnotherPaddingCheck"]
        self.assertTrue(zookeeper_history_below_next_padding(maximum))
        self.assertFalse(zookeeper_history_below_next_padding(maximum+1))
        for row in corpus["cases"]:
            size = row["expectedFileSize"]
            files = {"version-2/log.1": {"sizeBytes": size, "allocatedBytes": (size+4095)//4096*4096}}
            with self.subTest(row["id"]):
                if row["expectedWithin16MiBCap"]:
                    validate_extents("phase30-zookeeper-0", files)
                else:
                    with self.assertRaisesRegex(CensusFailure, "log-generations-or-extent"):
                        validate_extents("phase30-zookeeper-0", files)

    def test_sparse_journals_do_not_fund_extra_entrylog_data(self):
        files = {str(i) + ".txn": {"sizeBytes": 16 * 1048576, "allocatedBytes": 4096} for i in range(2)}
        files.update({str(i) + ".idx": {"sizeBytes": 16384, "allocatedBytes": 16384} for i in range(512)})
        files["0.log"] = {"sizeBytes": 20 * 1048576, "allocatedBytes": 20 * 1048576}
        with self.assertRaisesRegex(CensusFailure, "data-and-auxiliary-bound"):
            validate_extents("phase30-bookkeeper-0", files)

    def test_recovery_log_allowance_cannot_be_spent_in_steady_state(self):
        files = {"log." + str(i): {"sizeBytes": 16 * 1048576, "allocatedBytes": 4096} for i in range(3)}
        with self.assertRaisesRegex(CensusFailure, "log-generations-or-extent"):
            validate_extents("phase30-zookeeper-0", files)


if __name__ == "__main__":
    unittest.main()
