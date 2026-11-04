"""Initial-file readiness preserves the independently frozen genesis contract."""
import json
import stat
import sys
import tempfile
import threading
import time
import types
import unittest
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import platform_backbone_live as live
import platform_backbone_zookeeper_observer as wire


class GenesisStartupTests(unittest.TestCase):
    def test_independent_before_after_and_shared_deadline_cases(self):
        corpus = json.loads((ROOT / "test/oracle/platform_backbone_zookeeper_startup.json").read_text())
        original = (ROOT / "test/oracle/platform_backbone_zookeeper_genesis.json").read_bytes()
        import hashlib
        self.assertEqual(hashlib.sha256(original).hexdigest(), corpus["genesisCorpusSha256"])
        data = bytes.fromhex(json.loads(original)["cases"][0]["wireHex"])
        for row in corpus["cases"]:
            with self.subTest(row["id"]):
                now = [row["initialSeconds"]]
                events = list(row["events"])

                def event(operation, remaining):
                    self.assertGreater(remaining, 0)
                    self.assertAlmostEqual(remaining, row["deadlineSeconds"]-now[0])
                    next_event = events.pop(0)
                    self.assertEqual(next_event["operation"], operation)
                    now[0] += next_event["advanceSeconds"]
                    if next_event.get("raises") == "PermissionError":
                        raise PermissionError("source-error")
                    return next_event.get("value") if operation == "stat" else data

                clock = types.SimpleNamespace(monotonic=lambda: now[0], sleep=lambda seconds: now.__setitem__(0, now[0]+seconds))
                with patch.object(live, "time", clock):
                    try:
                        result, _ = live.wait_initial_zookeeper_snapshot(lambda seconds: event("stat", seconds),
                            lambda seconds: event("read", seconds), device=corpus["expectedSourceDevice"],
                            deadline=row["deadlineSeconds"])
                    except (live.BackboneLiveFailure, PermissionError) as failure:
                        self.assertEqual(row["expectedAdmission"], "deny")
                        category = row["expectedReasonCategory"]
                        self.assertIn({"deadline": "before-deadline", "provenance": "file-provenance",
                                       "source-error": "source-error"}[category], str(failure))
                    else:
                        self.assertEqual(row["expectedAdmission"], "allow")
                        self.assertEqual(result, data)
                    self.assertFalse(events)

    def test_absent_then_partial_then_stable_native_genesis(self):
        row = json.loads((ROOT / "test/oracle/platform_backbone_zookeeper_genesis.json").read_text())["cases"][0]
        expected = bytes.fromhex(row["wireHex"])
        create, finish = threading.Event(), threading.Event()
        with tempfile.TemporaryDirectory(dir=ROOT / ".build/tmp", prefix="genesis-startup-") as folder:
            source = Path(folder) / "snapshot.0"

            def writer():
                if create.wait(2):
                    source.write_bytes(expected[:100])
                    if finish.wait(2):
                        source.write_bytes(expected)

            thread = threading.Thread(target=writer)
            thread.start()

            def observe(_remaining):
                try:
                    observed = source.stat(follow_symlinks=False)
                except FileNotFoundError:
                    create.set()
                    return None
                self.assertTrue(stat.S_ISREG(observed.st_mode))
                if observed.st_size == 100:
                    finish.set()
                return {"device": observed.st_dev, "inode": observed.st_ino, "sizeBytes": observed.st_size,
                        "allocatedBytes": observed.st_blocks * 512, "modifiedNs": observed.st_mtime_ns}

            try:
                data, evidence = live.wait_initial_zookeeper_snapshot(observe, lambda _remaining: source.read_bytes(),
                    device=Path(folder).stat().st_dev, deadline=time.monotonic()+3)
            finally:
                create.set(); finish.set(); thread.join(3)
            self.assertEqual(data, expected)
            self.assertEqual(evidence["sizeBytes"], row["wireBytes"])
            self.assertTrue(create.is_set() and finish.is_set())
            wire.validate_native_genesis(wire.parse_snapshot(data), file_name="snapshot.0", snapshot_file_zxid=0)

    def test_deadline_never_creates_or_reads_missing_source(self):
        with self.assertRaisesRegex(live.BackboneLiveFailure, "file-not-ready-before-deadline"):
            live.wait_initial_zookeeper_snapshot(lambda _remaining: None, lambda _remaining: self.fail("read missing source"),
                device=1, deadline=time.monotonic()+0.01)

    def test_other_filesystem_rejects_before_read(self):
        with self.assertRaisesRegex(live.BackboneLiveFailure, "file-provenance"):
            live.wait_initial_zookeeper_snapshot(lambda _remaining: {"device": 2, "sizeBytes": 742},
                lambda _remaining: self.fail("read wrong device"), device=1, deadline=time.monotonic()+1)

    def test_larger_file_rejects_before_read(self):
        with self.assertRaisesRegex(live.BackboneLiveFailure, "file-provenance"):
            live.wait_initial_zookeeper_snapshot(lambda _remaining: {"device": 1, "sizeBytes": 743},
                lambda _remaining: self.fail("read oversized source"), device=1, deadline=time.monotonic()+1)

    def test_source_error_is_not_an_absence_retry(self):
        def denied(_remaining):
            raise PermissionError("observer-authority-denied")
        with self.assertRaisesRegex(PermissionError, "observer-authority-denied"):
            live.wait_initial_zookeeper_snapshot(denied, lambda _remaining: self.fail("read denied source"),
                device=1, deadline=time.monotonic()+1)


if __name__ == "__main__":
    unittest.main()
