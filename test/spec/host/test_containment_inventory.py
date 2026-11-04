from __future__ import annotations

import json
import sys
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))

import containment  # noqa: E402


class CacheInventorySpec(unittest.TestCase):
    def inventory_pair(self, first, second):
        records = iter([first, second])

        def docker(command):
            if command[:2] == ["builder", "du"]:
                return (json.dumps(next(records)),), ""
            return (), ""

        with ExitStack() as stack:
            for name in (
                "_external_paths", "_mounts", "_loop_devices", "_contained_test_mounts",
                "_contained_test_loops", "_network_links",
            ):
                stack.enter_context(mock.patch.object(containment, name, return_value=()))
            stack.enter_context(mock.patch.object(containment, "_amoebius_firewall_rules", return_value=((), "")))
            stack.enter_context(mock.patch.object(containment, "_docker", side_effect=docker))
            return containment.host_inventory(), containment.host_inventory()

    def test_relative_cache_age_does_not_change_inventory(self) -> None:
        first = {"ID": "cache-a", "Size": "8kB", "UsageCount": 2, "LastUsedAt": "15 minutes ago"}
        before, after = self.inventory_pair(first, {**first, "LastUsedAt": "16 minutes ago"})
        self.assertEqual(containment.host_inventory_problems(before, after), [])

    def test_cache_identity_size_and_usage_remain_observed(self) -> None:
        first = {"ID": "cache-a", "Size": "8kB", "UsageCount": 2, "Reclaimable": True}
        changes = (("ID", "cache-b"), ("Size", "9kB"), ("UsageCount", 3), ("Reclaimable", False))
        for field, changed in changes:
            with self.subTest(field=field):
                before, after = self.inventory_pair(first, {**first, field: changed})
                self.assertIn(
                    "outside-host inventory changed during the gate",
                    containment.host_inventory_problems(before, after),
                )


if __name__ == "__main__":
    unittest.main()
