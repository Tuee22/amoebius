from __future__ import annotations

import contextlib
import sys
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import containment  # noqa: E402
import retained_storage_backing as backing  # noqa: E402
import vault_pki_live as vault  # noqa: E402


class ReachedLive(RuntimeError):
    pass


class VaultPkiCompositionSpec(unittest.TestCase):
    def setUp(self) -> None:
        self.run = containment.create_test_run("vault-compose-" + uuid.uuid4().hex)
        self.addCleanup(containment.cleanup_test_run, self.run)
        self.archive = self.run.path / "archive"
        self.archive.write_bytes(b"boundary-test-placeholder")
        self.events: list[tuple[str, object]] = []

    def invoke(self, *, usable_shortfall=0, **arguments):
        def reserve(root, capacity, inventory):
            self.events.append(("pool", dict(inventory)))

        def allocate(name, size):
            self.events.append(("volume", name))
            return {"rawBytes": size, "usableBytes": size - usable_shortfall}

        def live(*_arguments):
            self.events.append(("live", None))
            raise ReachedLive()

        with patch.multiple(vault, IMAGE_ARCHIVE=self.archive,
                            RETAINED_ROOT=self.run.path / "retained",
                            install_current_binary=lambda: {"path": str(self.run.path / "binary")},
                            preallocation_rejections=lambda _binary: {},
                            prepare_volume=allocate, execute_live=live,
                            storage_observer=lambda: contextlib.nullcontext(self.run.path / "unused-summary")):
            with patch.object(backing, "prepare_pool", reserve):
                return vault.execute(**arguments)

    def test_default_preserves_the_two_vault_backings(self) -> None:
        with self.assertRaises(ReachedLive):
            self.invoke()
        self.assertEqual(self.events[0], ("pool", {"vault": 134217728, "vault-audit": 67108864}))
        self.assertEqual(self.events[1:], [("volume", "vault"), ("volume", "vault-audit"), ("live", None)])

    def test_complete_extra_inventory_is_reserved_before_live_creation(self) -> None:
        extra = {"first-drive": 16777216, "second-drive": 16777216}
        offered = 134217728 + 67108864 + sum(extra.values()) + 4096
        with self.assertRaises(ReachedLive):
            self.invoke(additional_volumes=extra, pool_capacity_bytes=offered)
        self.assertEqual(set(self.events[0][1]), {"vault", "vault-audit", *extra})
        self.assertEqual([value for event, value in self.events if event == "volume"],
                         ["vault", "vault-audit", *extra])
        self.assertEqual(self.events[-1], ("live", None))
        self.events.clear()
        with self.assertRaisesRegex(backing.BackingError, "durable-demand-exceeds-backing"):
            self.invoke(additional_volumes=extra, pool_capacity_bytes=offered - 1)
        self.assertEqual(self.events, [])

    def test_successor_cannot_resize_a_required_vault_backing(self) -> None:
        with self.assertRaisesRegex(backing.BackingError, "retained-image-resize-not-authorized"):
            self.invoke(additional_volumes={"vault": 268435456})
        self.assertEqual(self.events, [])

    def test_successor_usable_presentation_is_checked_before_live_creation(self) -> None:
        with self.assertRaisesRegex(vault.VaultLiveFailure, "retained-volume-usable-capacity:bookie"):
            self.invoke(additional_volumes={"bookie": 64}, additional_usable_bytes={"bookie": 56}, usable_shortfall=9)
        self.assertTrue(any(event == "volume" for event, _ in self.events))
        self.assertFalse(any(event == "live" for event, _ in self.events))
        self.events.clear()
        with self.assertRaises(ReachedLive):
            self.invoke(additional_volumes={"bookie": 64}, additional_usable_bytes={"bookie": 56}, usable_shortfall=8)
        self.assertEqual(self.events[-1], ("live", None))

    def test_successor_usable_inventory_mismatch_has_no_allocation_effect(self) -> None:
        with self.assertRaisesRegex(vault.VaultLiveFailure, "successor-usable-inventory-mismatch"):
            self.invoke(additional_volumes={"bookie": 64}, additional_usable_bytes={"other": 56})
        self.assertEqual(self.events, [])


if __name__ == "__main__":
    unittest.main()
