#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
# The bytes the fake copy puts on disk. The expected digest is derived from them below
# rather than restated as a literal, so the assertion stays a claim about the probe
# hashing what it copied instead of a constant that has to be re-typed alongside it.
LAUNCHER_PAYLOAD = b"#!/bin/sh\n"
SPEC = importlib.util.spec_from_file_location("phase25_source_probe", ROOT / "tools/phase25_source_probe.py")
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)


class SourceProbeTest(unittest.TestCase):
    def test_oracle_and_catalog_reconcile(self) -> None:
        pairs = PROBE.reconcile()
        self.assertEqual(22, len(pairs))
        self.assertEqual(22, len(PROBE.oracle_inventory()))
        self.assertEqual({"amd64": 62, "arm64": 183}, PROBE.EXPECTED_MACHINE)

    def test_acquisition_identity_recovers_the_rung_from_its_fields(self) -> None:
        # `dhall-to-json` drops the arm name, so the rung is recovered from the
        # fields the arm carries. A step with none of the three distinguishing
        # fields is the one amoebius builds itself.
        self.assertEqual(
            ("apt:redis-tools=5:7.0.15-1ubuntu0.24.04.4", "sha256:resolved-from-the-archive-at-build"),
            PROBE.acquisition_identity(
                {"package": "redis-tools", "packageVersion": "5:7.0.15-1ubuntu0.24.04.4"}
            ),
        )
        self.assertEqual(
            ("dl.min.io@RELEASE.1", "sha256:resolved-from-the-publisher-manifest"),
            PROBE.acquisition_identity({"publisher": "dl.min.io", "releaseVersion": "RELEASE.1"}),
        )
        self.assertEqual(
            ("redis:7.4.5", "sha256:abc"),
            PROBE.acquisition_identity({"sourceImage": "redis:7.4.5", "sourceDigest": "sha256:abc"}),
        )
        self.assertEqual(
            ("amoebius-source", "sha256:source-bound-at-build"),
            PROBE.acquisition_identity({"source": {"cabalTarget": "exe:amoebius"}}),
        )
        self.assertEqual(
            (
                "https://github.com/metallb/metallb@v0.15.2",
                "sha256:resolved-from-the-module-checksum-database-at-build",
            ),
            PROBE.acquisition_identity(
                {"source": {"repository": "https://github.com/metallb/metallb", "reference": "v0.15.2"}}
            ),
        )
        self.assertEqual(
            ("pypi:pgadmin4==9.6", "sha256:resolved-from-the-package-index-at-build"),
            PROBE.acquisition_identity(
                {"source": {"distribution": "pgadmin4", "distributionVersion": "9.6"}}
            ),
        )
        # A step carrying none of the four shapes is a rung the recovery does not
        # know, which must fail rather than be classified as something plausible.
        with self.assertRaisesRegex(PROBE.ProbeFailure, "unclassifiable-step"):
            PROBE.acquisition_identity({"name": "mystery", "targetPath": "/usr/bin/mystery"})

    def test_reconcile_rejects_a_catalog_step_no_oracle_row_names(self) -> None:
        # The direction that used to be missing: an oracle-driven loop passes for
        # every row it still has, so a binary added to the catalog alone would
        # enter the image with nothing having authored it.
        catalog = PROBE.decode_dhall(PROBE.CATALOG)
        oracle = PROBE.decode_dhall(PROBE.ORACLE)
        catalog["stages"][0]["content"]["tail"].append(
            {
                "name": "unauthored", "package": "unauthored", "packageVersion": "1",
                "archiveSuite": "noble/main", "targetPath": "/usr/bin/unauthored",
                "arguments": ["--version"], "expectedVersion": "1", "kind": "Elf",
            }
        )
        with mock.patch.object(
            PROBE, "decode_dhall",
            side_effect=lambda path: catalog if path == PROBE.CATALOG else oracle,
        ):
            with self.assertRaisesRegex(PROBE.ProbeFailure, "catalog-step-no-oracle-row:unauthored"):
                PROBE.reconcile()

    def test_elf_machine_parser(self) -> None:
        for endian, expected in ((1, 62), (2, 183)):
            header = bytearray(20)
            header[:4] = b"\x7fELF"
            header[5] = endian
            header[18:20] = expected.to_bytes(2, "little" if endian == 1 else "big")
            with tempfile.TemporaryDirectory() as temporary:
                binary = Path(temporary) / "binary"
                binary.write_bytes(header)
                self.assertEqual(expected, PROBE.elf_machine(binary))

    def test_final_launcher_probe_uses_assembled_absolute_path(self) -> None:
        oracle = {
            "catalogName": "launcher",
            "binary": "/opt/launcher",
            "arguments": ["version"],
            "version": "1.2.3",
            "kind": "Launcher",
        }
        completed = subprocess.CompletedProcess([], 0, "launcher 1.2.3\n")
        def fake_copy(_docker: str, _reference: str, _platform: str, _path: str, destination: Path) -> None:
            destination.write_bytes(LAUNCHER_PAYLOAD)

        with mock.patch.object(PROBE, "run", return_value=completed) as invoked, mock.patch.object(
            PROBE, "copy_binary", side_effect=fake_copy
        ):
            result = PROBE.probe_final_one(
                "/usr/bin/docker", oracle, "registry.local/image@sha256:abc", "arm64", {}
            )
        self.assertEqual("linux/arm64", result["platform"])
        self.assertEqual("launcher", result["elf_machine"])
        self.assertEqual(
            "sha256:" + hashlib.sha256(LAUNCHER_PAYLOAD).hexdigest(),
            result["sha256"],
        )
        self.assertEqual(
            (
                "/usr/bin/docker", "run", "--rm", "--platform", "linux/arm64",
                "--entrypoint", "/opt/launcher", "registry.local/image@sha256:abc", "version",
            ),
            invoked.call_args.args[0],
        )

    def test_forbidden_payload_scan_turns_presence_red(self) -> None:
        completed = subprocess.CompletedProcess([], 0, "/opt/llama.cpp\n")
        with mock.patch.object(PROBE, "run", return_value=completed):
            with self.assertRaisesRegex(PROBE.ProbeFailure, "forbidden-payload-present"):
                PROBE.probe_forbidden_payloads(
                    "/usr/bin/docker", "amoebius/phase25:amd64", "amd64"
                )


if __name__ == "__main__":
    unittest.main()
