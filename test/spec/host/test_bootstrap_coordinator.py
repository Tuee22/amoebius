from __future__ import annotations

import copy
import dataclasses
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "pb"))

from pb.bootstrap_coordinator import (  # noqa: E402
    HostObservation,
    BootstrapCoordinatorError,
    ToolPaths,
    ValidatedExecution,
    _fixed_environment,
    assert_authored_envelope,
    bootstrap_arguments,
    cabal_build_arguments,
    cabal_list_bin_arguments,
    cabal_update_arguments,
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

    def test_exact_tool_plan(self) -> None:
        self.assertEqual(
            [step["tool"] for step in self.envelope["installer"]["steps"]],
            ["ghcup", "ghc", "cabal", "kubectl", "kind"],
        )

    def test_envelope_carries_no_resolver_output(self) -> None:
        """The split is the point: a version, URL, or digest here is a tracked pin."""
        self.assertEqual(set(self.envelope), {"schema", "_comment", "installer", "build"})
        source = (ROOT / "pb/bootstrap_execution_envelope.json").read_text(encoding="utf-8")
        prose = source.replace("tools/toolchain_requirements.json", "").replace(".build/toolchain/", "")
        for token in ("sha256", "https://", '"toolchain"', '"downloads"'):
            self.assertNotIn(token, prose)
        for restored in ("toolchain", "downloads"):
            polluted = copy.deepcopy(self.envelope)
            polluted[restored] = {}
            with self.subTest(key=restored):
                with self.assertRaisesRegex(BootstrapCoordinatorError, "envelope-carries-resolver-output"):
                    assert_authored_envelope(polluted)

    def test_candidates_carry_no_resolved_version(self) -> None:
        """A version-stamped filename is a pin that also stops matching silently."""
        for name, paths in candidate_paths(Path("/home/operator")).items():
            self.assertTrue(all(path.is_absolute() for path in paths))
            for path in paths:
                self.assertFalse(
                    any(character.isdigit() for character in path.name),
                    f"{name} candidate {path} carries a resolved version",
                )

    def test_handoff_arguments(self) -> None:
        self.assertEqual(
            bootstrap_arguments("kind", 1),
            ["bootstrap", "--distro=kind", "--replicas=1", "--layout=unified"],
        )

    def test_build_state_and_patch_helper_are_checkout_contained(self) -> None:
        root = Path("/root/amoebius")
        home = root / ".build/toolchain/runtime/home"
        tools = ToolPaths(*(Path(f"/usr/bin/{name}") for name in ("apt-get", "ghcup", "ghc", "cabal", "kubectl", "kind")))
        update = cabal_update_arguments(root)
        build = cabal_build_arguments(root, tools, "1")
        list_bin = cabal_list_bin_arguments(root, tools)
        self.assertEqual(update[1:3], ["update", "--ignore-project"])
        self.assertEqual(build[1], "build")
        self.assertEqual(list_bin[1], "list-bin")
        self.assertEqual(build[-1], "./amoebius.cabal:exe:amoebius")
        self.assertEqual(list_bin[-1], "./amoebius.cabal:exe:amoebius")
        for arguments in (update, build, list_bin):
            self.assertEqual(arguments[0], f"--store-dir={root / '.build/cabal-store'}")
        for arguments in (build, list_bin):
            self.assertIn(f"--builddir={root / '.build/dist-newstyle/bootstrap-coordinator'}", arguments)
        self.assertIn(f"--builddir={root / '.build/dist-newstyle/bootstrap-coordinator-update'}", update)
        environment = _fixed_environment(ROOT / ".build/toolchain/runtime/home")
        self.assertEqual(environment["PATH"].split(":"), [str(ROOT / "tools"), "/usr/bin", "/bin"])
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
