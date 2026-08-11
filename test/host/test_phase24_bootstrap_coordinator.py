from __future__ import annotations

import copy
import dataclasses
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pb"))

from pb.bootstrap_coordinator import (  # noqa: E402
    HostObservation,
    BootstrapCoordinatorError,
    ValidatedExecution,
    bootstrap_arguments,
    candidate_paths,
    load_envelope,
    validate_envelope,
)


class BootstrapCoordinatorSpec(unittest.TestCase):
    def setUp(self) -> None:
        self.envelope = load_envelope(ROOT)
        self.observation = HostObservation(
            cpu_count=8,
            memory_available_bytes=32 * 1024**3,
            disk_available_bytes=64 * 1024**3,
            fingerprint="fixed",
        )

    def test_exact_tool_plan_and_pins(self) -> None:
        self.assertEqual(
            [step["tool"] for step in self.envelope["installer"]["steps"]],
            ["ghcup", "ghc", "cabal", "kubectl", "kind"],
        )
        self.assertEqual(self.envelope["toolchain"]["ghc"], "9.12.4")
        self.assertEqual(self.envelope["toolchain"]["cabal"], "3.16.1.0")

    def test_absolute_candidates_and_handoff_arguments(self) -> None:
        for paths in candidate_paths(Path("/home/operator")).values():
            self.assertTrue(all(path.is_absolute() for path in paths))
        self.assertEqual(
            bootstrap_arguments("kind", 1),
            ["bootstrap", "--distro=kind", "--replicas=1", "--layout=unified"],
        )
        self.assertEqual(
            bootstrap_arguments("kind", 1, "split-runtime"),
            ["bootstrap", "--distro=kind", "--replicas=1", "--layout=split-runtime"],
        )

    def test_single_use_fingerprint_token(self) -> None:
        token = validate_envelope(self.envelope, self.observation, "installer")
        token.consume(self.observation)
        with self.assertRaisesRegex(BootstrapCoordinatorError, "already-consumed"):
            token.consume(self.observation)
        changed = ValidatedExecution("old")
        with self.assertRaisesRegex(BootstrapCoordinatorError, "fingerprint-changed"):
            changed.consume(dataclasses.replace(self.observation, fingerprint="new"))

    def test_one_unit_overdraws_are_specific(self) -> None:
        installer = self.envelope["installer"]
        build = self.envelope["build"]
        cases = [
            ("installer", dataclasses.replace(self.observation, cpu_count=installer["cpu_count"] - 1), "installer-cpu-overdraw"),
            ("installer", dataclasses.replace(self.observation, memory_available_bytes=installer["memory_bytes"] - 1), "installer-memory-overdraw"),
            ("installer", dataclasses.replace(self.observation, disk_available_bytes=installer["tool_install_backing_bytes"] - 1), "installer-disk-overdraw"),
            ("build", dataclasses.replace(self.observation, cpu_count=build["cpu_count"] - 1), "build-cpu-overdraw"),
            ("build", dataclasses.replace(self.observation, memory_available_bytes=build["memory_bytes"] - 1), "build-memory-overdraw"),
            ("build", dataclasses.replace(self.observation, disk_available_bytes=build["scratch_bytes"] + build["cache_write_bytes"] - 1), "build-disk-overdraw"),
        ]
        for stage, observed, reason in cases:
            with self.subTest(reason=reason), self.assertRaisesRegex(BootstrapCoordinatorError, reason):
                validate_envelope(self.envelope, observed, stage)

    def test_missing_or_duplicate_step_is_rejected(self) -> None:
        path = ROOT / "pb/bootstrap_execution_envelope.json"
        source = path.read_text(encoding="utf-8")
        for mutation in ("drop", "duplicate"):
            envelope = copy.deepcopy(self.envelope)
            if mutation == "drop":
                envelope["installer"]["steps"].pop()
            else:
                envelope["installer"]["steps"].append(envelope["installer"]["steps"][0])
            tools = tuple(step["tool"] for step in envelope["installer"]["steps"])
            self.assertNotEqual(tools, ("ghcup", "ghc", "cabal", "kubectl", "kind"))
        self.assertIn('"schema": 1', source)


if __name__ == "__main__":
    unittest.main()
