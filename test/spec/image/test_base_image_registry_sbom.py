#!/usr/bin/env python3

from __future__ import annotations

import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[3]
TEMP_ROOT = ROOT / ".build/tmp/base-image-registry-specs"
TEMP_ROOT.mkdir(parents=True, exist_ok=True)
SPEC = importlib.util.spec_from_file_location("base_image_registry_sbom", ROOT / "tools/base_image_registry_sbom.py")
assert SPEC and SPEC.loader
SBOM = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SBOM)


# The amended oracle shape: `acquisition` names what the rung acquires from and
# `integrity` names where the integrity value is resolved during the build. The
# retired `sourceImage`/`sourceDigest` pair could only describe the scavenge rung,
# which the 2026-08-13 monocontainer amendment removed from the catalog entirely.
ORACLE = {
    "catalogName": "redis-server",
    "binary": "/usr/bin/redis-server",
    "version": "7.0.15",
    "acquisition": "apt:redis-server=5:7.0.15-1ubuntu0.24.04.4",
    "integrity": "sha256:resolved-from-the-archive-at-build",
}


class BaseImageRegistrySbomTest(unittest.TestCase):
    def test_two_architecture_rows_make_a_deterministic_spdx_document(self) -> None:
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as temporary:
            root = Path(temporary)
            probes = [
                self.write_probe(root / "amd64.tsv", "linux/amd64", "a"),
                self.write_probe(root / "arm64.tsv", "linux/arm64", "b"),
            ]
            with patch.object(SBOM.SOURCE_PROBE, "oracle_inventory", return_value=[ORACLE]):
                first = SBOM.make_sbom(probes)
                second = SBOM.make_sbom(list(reversed(probes)))
        self.assertEqual(first, second)
        self.assertEqual("SPDX-2.3", first["spdxVersion"])
        self.assertEqual(2, len(first["files"]))
        self.assertEqual(
            {"/usr/bin/redis-server"}, {row["fileName"] for row in first["files"]}
        )

    def test_missing_architecture_row_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as temporary:
            probe = self.write_probe(Path(temporary) / "amd64.tsv", "linux/amd64", "a")
            with patch.object(SBOM.SOURCE_PROBE, "oracle_inventory", return_value=[ORACLE]):
                with self.assertRaisesRegex(SBOM.SbomFailure, "probe-inventory-mismatch"):
                    SBOM.make_sbom([probe])

    @staticmethod
    def write_probe(path: Path, platform: str, digest_character: str) -> Path:
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=(
                    "catalog_name", "platform", "exit", "marker",
                    "elf_machine", "sha256", "output",
                ),
                delimiter="\t",
            )
            writer.writeheader()
            writer.writerow(
                {
                    "catalog_name": "redis-server",
                    "platform": platform,
                    "exit": "0",
                    "marker": "7.0.15",
                    "elf_machine": "62" if platform.endswith("amd64") else "183",
                    "sha256": "sha256:" + digest_character * 64,
                    "output": "Redis server v=7.0.15",
                }
            )
        return path


if __name__ == "__main__":
    unittest.main()
