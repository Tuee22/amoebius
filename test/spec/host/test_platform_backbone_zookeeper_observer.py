"""Pinned upstream wire literals, independently authored before reader tests."""

from pathlib import Path
import copy
import hashlib
import json
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import platform_backbone_zookeeper_observer as subject


def public_literal(value):
    """Hash literal payloads; never copy raw payloads into public evidence."""
    if isinstance(value, list):
        return [public_literal(item) for item in value]
    if not isinstance(value, dict):
        return value
    result = {key: public_literal(item) for key, item in value.items() if key != "dataHex"}
    if "dataHex" in value:
        data = bytes.fromhex(value["dataHex"] or "")
        derived = {"dataBytes": len(data), "dataSha256": hashlib.sha256(data).hexdigest()}
        for key, expected in derived.items():
            if key in result:
                assert result[key] == expected, "inconsistent independent literal payload"
            result[key] = expected
    return result


class ZooKeeperWireTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = json.loads((ROOT / "test/oracle/platform_backbone_zookeeper_wire.json").read_text())
        cls.snapshots = {row["id"]: row for row in cls.corpus["snapshots"]}
        cls.records = {row["id"]: row for row in cls.corpus["records"]}
        cls.logs = {row["id"]: row for row in cls.corpus["logs"]}
        assert len(cls.snapshots) == len(cls.corpus["snapshots"])
        assert len(cls.records) == len(cls.corpus["records"])
        assert len(cls.logs) == len(cls.corpus["logs"])

    def snapshot(self, row):
        return subject.parse_snapshot(bytes.fromhex(row["wireHex"]), subject.EncodingProfile(**row["profile"]))

    def log(self, row):
        return subject.parse_transaction_log(bytes.fromhex(row["wireHex"]), subject.EncodingProfile(**row["profile"]))

    def genesis(self):
        rows = [row for row in self.snapshots.values()
                if row["snapshotFileZxid"] == 0 and row["expected"]["serializedLastZxid"] == 0]
        self.assertEqual(len(rows), 1)
        snapshot = self.snapshot(rows[0])
        self.assertEqual(snapshot.state_projection(), public_literal(self.corpus["syntheticGenesis"]))
        return snapshot

    def test_every_full_snapshot_and_all_component_seals(self):
        for row in self.snapshots.values():
            with self.subTest(row["id"]):
                self.assertEqual(self.snapshot(row).projection(), public_literal(row["expected"]))

    def test_real_static_genesis_all_independent_wire_cases(self):
        corpus = json.loads((ROOT / "test/oracle/platform_backbone_zookeeper_genesis.json").read_text())
        accepted = rejected = 0
        for row in corpus["cases"]:
            with self.subTest(row["id"]):
                data = bytes.fromhex(row["wireHex"])
                self.assertEqual(len(data), row["wireBytes"])
                self.assertEqual(hashlib.sha256(data).hexdigest(), row["wireSha256"])
                if row["expected"] == "reject":
                    with self.assertRaises(subject.ZooKeeperObservationFailure):
                        snapshot = self.snapshot(row)
                        subject.validate_native_genesis(snapshot, file_name=row["fileName"], snapshot_file_zxid=row["snapshotFileZxid"])
                    rejected += 1
                else:
                    self.assertEqual(row["expected"], "accept")
                    snapshot = self.snapshot(row)
                    self.assertEqual(snapshot.projection(), public_literal(row["expectedParsed"]))
                    subject.validate_native_genesis(snapshot, file_name=row["fileName"], snapshot_file_zxid=row["snapshotFileZxid"])
                    accepted += 1
        self.assertEqual((accepted, rejected), (8, 25))

    def test_saved_genesis_binds_raw_bytes_projection_and_independent_devices(self):
        corpus = json.loads((ROOT / "test/oracle/platform_backbone_zookeeper_genesis.json").read_text())
        case = next(row for row in corpus["cases"] if row["expected"] == "accept")
        data = bytes.fromhex(case["wireHex"])
        with tempfile.TemporaryDirectory(dir=ROOT / ".build/tmp") as temporary:
            directory = Path(temporary)
            members = []
            devices = {"phase30-zookeeper-" + str(ordinal): 100 + ordinal for ordinal in range(3)}
            for ordinal in range(3):
                name = "member-" + str(ordinal) + "-snapshot.0"
                (directory / name).write_bytes(data)
                members.append({"ordinal": ordinal, "backing": "phase30-zookeeper-" + str(ordinal), "file": name,
                    "sha256": "sha256:" + case["wireSha256"], "bootstrap": public_literal(case["expectedParsed"]),
                    "source": {"device": 100 + ordinal, "inode": 200 + ordinal, "sizeBytes": 742,
                               "allocatedBytes": 4096, "modifiedNs": 7}})
            evidence = {"capturedBeforeMetadataWriters": True, "sourceBackingsEmptyBeforeStart": True,
                        "currentStateProof": False, "members": members}
            result = subject.verify_native_genesis_capture(directory, evidence, devices)
            self.assertEqual(result, {"rawBootstrapVerified": True, "members": 3, "bytesPerMember": 742,
                                      "completeCurrentStateProof": False})
            bad = copy.deepcopy(evidence)
            bad["members"][1]["source"]["device"] = devices["phase30-zookeeper-0"]
            with self.assertRaisesRegex(subject.ZooKeeperObservationFailure, "device-identity"):
                subject.verify_native_genesis_capture(directory, bad, devices)
            bad = copy.deepcopy(evidence)
            bad["members"][0]["bootstrap"]["serializedLastZxid"] = 1
            with self.assertRaisesRegex(subject.ZooKeeperObservationFailure, "capture-projection"):
                subject.verify_native_genesis_capture(directory, bad, devices)
            with self.assertRaisesRegex(subject.ZooKeeperObservationFailure, "capture-member-domain"):
                subject.verify_native_genesis_capture(directory, {**evidence, "members": members[:-1]}, devices)
            (directory / members[0]["file"]).write_bytes(data[:-1] + bytes([data[-1] ^ 1]))
            with self.assertRaisesRegex(subject.ZooKeeperObservationFailure, "capture-digest"):
                subject.verify_native_genesis_capture(directory, evidence, devices)

    def test_nullable_transaction_digests_keep_all_frozen_framing_checks(self):
        path = ROOT / "test/oracle/platform_backbone_zookeeper_optional_digest.json"
        corpus = json.loads(path.read_text())
        self.assertEqual(hashlib.sha256((ROOT / "test/oracle/platform_backbone_zookeeper_wire.json").read_bytes()).hexdigest(),
                         corpus["sourceCorpusSha256"])
        records = {row["id"]: row for row in corpus["records"]}
        for row in records.values():
            with self.subTest(row["id"]):
                actual = subject.parse_transaction_record(bytes.fromhex(row["wireHex"]), subject.EncodingProfile(**row["profile"]))
                self.assertEqual(actual.projection(), public_literal(row["expected"]))
        for row in corpus["logs"]:
            with self.subTest(row["id"]):
                raw = bytes.fromhex(row["wireHex"])
                parsed = subject.parse_transaction_log(raw, subject.EncodingProfile(**row["profile"]))
                self.assertEqual(len(parsed), row["expectedTransactionCount"])
                self.assertEqual(sum(record.framed_bytes for record in parsed), row["expectedSerializedFramedBytes"])
                self.assertEqual(len(raw), row["expectedWireBytes"])
                self.assertEqual(len(raw)-16-sum(record.framed_bytes for record in parsed), row["expectedPaddingBytes"])
                self.assertEqual([record.projection() for record in parsed],
                                 [public_literal(records[name]["expected"]) for name in row["recordIds"]])
        readers = {"record": subject.parse_transaction_record, "log": subject.parse_transaction_log}
        for row in corpus["negativeCases"]:
            with self.subTest(row["id"]), self.assertRaises(subject.ZooKeeperObservationFailure):
                readers[row["kind"]](bytes.fromhex(row["wireHex"]), subject.EncodingProfile(**row["profile"]))

    def test_replay_checks_present_digests_after_nullable_rows(self):
        corpus = json.loads((ROOT / "test/oracle/platform_backbone_zookeeper_optional_digest.json").read_text())
        logs = {row["id"]: row for row in corpus["logs"]}
        for row in corpus["replayCases"]:
            log = logs[row["log"]]
            records = subject.parse_transaction_log(bytes.fromhex(log["wireHex"]), subject.EncodingProfile(**log["profile"]))
            actual = subject.replay_from_genesis(self.genesis(), records)
            self.assertEqual(actual.state_projection(), public_literal(row["expected"]))

    def test_every_exact_transaction_record(self):
        for row in self.records.values():
            with self.subTest(row["id"]):
                actual = subject.parse_transaction_record(bytes.fromhex(row["wireHex"]), subject.EncodingProfile(**row["profile"]))
                self.assertEqual(actual.projection(), public_literal(row["expected"]))

    def test_complete_logs_keep_record_order_and_exclude_zero_padding(self):
        for row in self.logs.values():
            with self.subTest(row["id"]):
                actual = self.log(row)
                expected = [public_literal(self.records[name]["expected"]) for name in row["recordIds"]]
                self.assertEqual([record.projection() for record in actual], expected)
                serialized = 16 + sum(record.framed_bytes for record in actual)
                self.assertEqual(serialized, row["expectedSerializedBytes"])
                self.assertEqual(len(bytes.fromhex(row["wireHex"]))-serialized, row["expectedPaddingBytes"])

    def test_all_independent_protocol_rejections(self):
        readers = {"snapshot": subject.parse_snapshot, "record": subject.parse_transaction_record,
                   "log": subject.parse_transaction_log}
        for row in self.corpus["negativeCases"]:
            with self.subTest(row["id"]):
                self.assertEqual(row["expected"], "reject")
                with self.assertRaises(subject.ZooKeeperObservationFailure):
                    readers[row["kind"]](bytes.fromhex(row["wireHex"]), subject.EncodingProfile(**row["profile"]))

    def test_every_saved_replay_step_and_true_tree_digest(self):
        case = next(row for row in self.corpus["replayCases"] if row["id"] == "synthetic-genesis-full-history")
        log = self.logs[case["log"]]
        records = self.log(log)
        initial = self.genesis()
        unchanged = copy.deepcopy(initial.state_projection())
        for count, name in enumerate(log["recordIds"], 1):
            with self.subTest(name):
                actual = subject.replay_from_genesis(initial, records[:count])
                self.assertEqual(actual.state_projection(), public_literal(self.records[name]["expectedStateAfter"]))
        self.assertEqual(initial.state_projection(), unchanged)

    def test_genesis_and_checked_anchor_match_independent_end_states(self):
        for case in self.corpus["replayCases"]:
            with self.subTest(case["id"]):
                records = self.log(self.logs[case["log"]])
                if "snapshot" in case:
                    row = self.snapshots[case["snapshot"]]
                    actual = subject.replay_from_checked_anchor(self.snapshot(row), records,
                                                                snapshot_file_zxid=row["snapshotFileZxid"])
                else:
                    actual = subject.replay_from_genesis(self.genesis(), records)
                self.assertEqual(actual.state_projection(), public_literal(case["expected"]))

    def test_missing_noop_cannot_satisfy_complete_history(self):
        case = next(row for row in self.corpus["replayCases"] if row["id"] == "synthetic-genesis-full-history")
        records = self.log(self.logs[case["log"]])
        noop = next(record for record in records if record.operation.opcode == 14
                    and all(child.opcode == 13 for child in record.operation.fields["children"]))
        with self.assertRaisesRegex(subject.ZooKeeperObservationFailure, "log-gap"):
            subject.replay_from_genesis(self.genesis(), [record for record in records if record is not noop])

    def test_old_snapshot_or_mismatched_filename_is_not_a_genesis_witness(self):
        case = next(row for row in self.corpus["replayCases"] if "snapshot" in row)
        row = self.snapshots[case["snapshot"]]
        snapshot, records = self.snapshot(row), self.log(self.logs[case["log"]])
        with self.assertRaisesRegex(subject.ZooKeeperObservationFailure, "genesis-zxid-required"):
            subject.replay_from_genesis(snapshot, records)
        with self.assertRaisesRegex(subject.ZooKeeperObservationFailure, "anchor-zxid-mismatch"):
            subject.replay_from_checked_anchor(snapshot, records, snapshot_file_zxid=row["snapshotFileZxid"]-1)


if __name__ == "__main__":
    unittest.main()
