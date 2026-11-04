from __future__ import annotations

import json
import os
import sys
import unittest
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import containment  # noqa: E402
import vault_storage_observer as observer  # noqa: E402


class VaultStorageObserverSpec(unittest.TestCase):
    def setUp(self) -> None:
        self.run = containment.create_test_run("vault-storage-spec-" + uuid.uuid4().hex)
        self.addCleanup(containment.cleanup_test_run, self.run)

    def test_inventory_reads_actual_length_and_allocation(self) -> None:
        path = self.run.path / "data"
        path.write_bytes(b"x" * 5000)
        observed = observer.inventory(self.run.path)
        self.assertEqual(observed["files"]["data"]["sizeBytes"], 5000)
        self.assertEqual(observed["files"]["data"]["allocatedBytes"], path.stat().st_blocks * 512)

    def test_fifo_is_not_read_as_a_file(self) -> None:
        pipe = self.run.path / "audit.fifo"
        os.mkfifo(pipe)
        self.addCleanup(pipe.unlink, missing_ok=True)
        self.assertNotIn("audit.fifo", observer.inventory(self.run.path)["files"])

    def test_snapshot_install_observes_two_distinct_allocated_databases(self) -> None:
        active = self.run.path / "raft/vault.db"
        incoming = self.run.path / "raft/raft/snapshots/1-42-123.tmp/vault.db"
        incoming.parent.mkdir(parents=True)
        active.write_bytes(b"old database")
        incoming.write_bytes(b"new database")
        files = observer.inventory(self.run.path)["files"]
        self.assertEqual(observer.snapshot_databases(files), ["raft/raft/snapshots/1-42-123.tmp/vault.db"])
        incoming.unlink()
        incoming.hardlink_to(active)
        self.assertEqual(observer.snapshot_databases(observer.inventory(self.run.path)["files"]), [])
        incoming.unlink()
        incoming.write_bytes(b"new database")
        old_inode, new_inode = active.stat().st_ino, incoming.stat().st_ino
        incoming.replace(active)
        self.assertNotEqual(old_inode, active.stat().st_ino)
        self.assertEqual(new_inode, active.stat().st_ino)
        self.assertEqual(observer.snapshot_databases(observer.inventory(self.run.path)["files"]), [])

    def test_observation_reports_an_actual_ceiling_violation(self) -> None:
        volumes = {name: self.run.path / name for name in ("vault", "vault-audit")}
        for path in volumes.values():
            path.mkdir()
        (volumes["vault-audit"] / "audit.log").write_bytes(b"x" * (1048576 + 1))
        stop = self.run.path / "stop"
        stop.touch()
        output, summary = self.run.path / "trace.jsonl", self.run.path / "summary.json"
        observer.watch(volumes, output, summary, stop)
        observed = json.loads(summary.read_text())
        self.assertEqual(observed["maximumActiveAuditBytes"], 1048576 + 1)
        self.assertEqual(observed["maximumAuditFileCount"], 1)
        self.assertEqual(observed["samples"], 1)


if __name__ == "__main__":
    unittest.main()
