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
        self.assertEqual(23, len(PROBE.oracle_inventory()))
        self.assertEqual({"amd64": 62, "arm64": 183}, PROBE.EXPECTED_MACHINE)

    def test_bundle_probe_paths(self) -> None:
        pairs = {oracle["catalogName"]: (oracle, catalog) for oracle, catalog in PROBE.reconcile()}
        self.assertEqual("/pulsar/bin/pulsar", PROBE.source_probe_path(*pairs["pulsar"]))
        self.assertEqual("/usr/share/grafana/bin/grafana", PROBE.source_probe_path(*pairs["grafana"]))
        self.assertEqual("/usr/bin/python3.12", PROBE.source_probe_path(*pairs["pgadmin"]))

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

    def test_repository_tag_removal(self) -> None:
        self.assertEqual("registry", PROBE.untagged_repository("registry:2.8.3"))
        self.assertEqual("quay.io/thanos/thanos", PROBE.untagged_repository("quay.io/thanos/thanos:v0.39.2"))
        self.assertEqual("registry.example:5000/repo", PROBE.untagged_repository("registry.example:5000/repo"))

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
