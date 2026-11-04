from __future__ import annotations

import errno
import sys
import unittest
import uuid
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))

import containment  # noqa: E402
import retained_storage_backing as backing  # noqa: E402


class RetainedBackingSpec(unittest.TestCase):
    def setUp(self) -> None:
        self.run = containment.create_test_run(f"retained-backing-spec-{uuid.uuid4().hex}")
        self.addCleanup(containment.cleanup_test_run, self.run)

    def test_new_image_has_real_initialized_blocks(self) -> None:
        image = self.run.path / "image.ext4"
        backing.create_image(image, 65536)
        self.assertGreaterEqual(backing.reserved_bytes(image, 65536), 65536)
        self.assertEqual(image.read_bytes(), bytes(65536))

    def test_sparse_length_cannot_supply_reserved_capacity(self) -> None:
        image = self.run.path / "sparse.ext4"
        with image.open("wb") as handle:
            handle.truncate(65536)
        with self.assertRaisesRegex(backing.BackingError, "not-physically-reserved"):
            backing.reserved_bytes(image, 65536)

    def test_existing_bytes_cannot_be_reinitialized(self) -> None:
        image = self.run.path / "existing.ext4"
        image.write_bytes(b"retained nonce")
        with self.assertRaises(FileExistsError):
            backing.create_image(image, 65536)
        self.assertEqual(image.read_bytes(), b"retained nonce")

    def test_failed_reservation_removes_its_partial_file(self) -> None:
        image = self.run.path / "partial.ext4"
        with mock.patch.object(backing.os, "posix_fallocate", side_effect=OSError(errno.ENOSPC, "full")):
            with self.assertRaises(OSError):
                backing.create_image(image, 65536)
        self.assertFalse(image.exists())

    def test_union_retries_do_not_double_debit_existing_volume(self) -> None:
        plan = backing.inventory_plan(64, {"existing": 32}, {"existing": 32, "new": 32})
        self.assertEqual(sum(plan.values()), 64)
        with self.assertRaisesRegex(backing.BackingError, "resize-not-authorized"):
            backing.inventory_plan(64, {"existing": 32}, {"existing": 33})

    def test_over_budget_inventory_rejects_without_storage_effects(self) -> None:
        root = self.run.path / "retained"
        with mock.patch.object(backing, "create_image") as allocate, mock.patch.object(backing, "_run") as command:
            with self.assertRaisesRegex(backing.BackingError, "durable-demand-exceeds-backing"):
                backing.prepare_pool(root, 64, {"first": 32, "second": 33})
        allocate.assert_not_called()
        command.assert_not_called()
        self.assertFalse(root.exists())
        self.assertFalse((self.run.path / "disks").exists())

    def test_parent_shortfall_rejects_before_creating_pool(self) -> None:
        root = self.run.path / "retained"
        capacity = 65536
        with mock.patch.object(backing.shutil, "disk_usage", return_value=SimpleNamespace(free=capacity + backing.POOL_OVERHEAD_BYTES - 1)), mock.patch.object(backing, "create_image") as allocate:
            with self.assertRaisesRegex(backing.BackingError, "durable-pool-parent-capacity"):
                backing.prepare_pool(root, capacity, {"volume": capacity})
        allocate.assert_not_called()
        self.assertFalse(root.exists())
        self.assertFalse((self.run.path / "disks").exists())

    def test_large_pool_metadata_scales_and_short_parent_has_no_effect(self) -> None:
        self.assertEqual(backing.pool_raw_bytes(256 * 1024**2), 320 * 1024**2)
        capacity = 32 * 1024**3
        self.assertEqual(backing.pool_raw_bytes(capacity), capacity + 1639 * 1024**2)
        root = self.run.path / "retained"
        with mock.patch.object(backing.shutil, "disk_usage", return_value=SimpleNamespace(free=backing.pool_raw_bytes(capacity) - 1)), mock.patch.object(backing, "create_image") as allocate:
            with self.assertRaisesRegex(backing.BackingError, "durable-pool-parent-capacity"):
                backing.prepare_pool(root, capacity, {"volume": capacity})
        allocate.assert_not_called()
        self.assertFalse(root.exists())


if __name__ == "__main__":
    unittest.main()
