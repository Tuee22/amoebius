from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path
from contextlib import ExitStack, contextmanager
from types import SimpleNamespace
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))

import containment  # noqa: E402
import project_container_engine as engine  # noqa: E402


class BuildBackingSpec(unittest.TestCase):
    def setUp(self) -> None:
        temporary_root = ROOT / ".build/tmp/base-image-registry-specs"
        temporary_root.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(dir=temporary_root)
        self.addCleanup(temporary.cleanup)
        self.mount_root = Path(temporary.name)
        self.test_run = containment.create_test_run(f"build-backings-{uuid.uuid4().hex}")
        self.addCleanup(containment.cleanup_test_run, self.test_run)

    def test_shared_disk_shortfall_rejects_before_creating_backings(self) -> None:
        # Each backing fits individually; the parent can support only one of them.
        provisions = {
            "scratch": (self.mount_root / "scratch", 8192),
            "cache": (self.mount_root / "cache", 8192),
        }
        with mock.patch.object(shutil, "disk_usage", return_value=SimpleNamespace(free=8192)), mock.patch.object(
            engine, "_run"
        ) as invoked:
            with self.assertRaisesRegex(engine.EngineFailure, "finite-build-backings-capacity"):
                engine.create_filesystems(self.test_run, provisions)
        invoked.assert_not_called()
        self.assertFalse((self.test_run.path / "disks").exists())

    def test_exact_fit_reserves_blocks_before_attaching_loop_device(self) -> None:
        image = self.test_run.path / "disks/scratch.ext4"

        def observe_command(arguments: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
            if str(engine.LOSETUP) in arguments and "--find" in arguments:
                self.assertEqual(image.stat().st_size, 8192)
                self.assertGreaterEqual(image.stat().st_blocks * 512, 8192)
            if str(engine.MKFS_EXT4) in arguments:
                self.assertEqual(arguments[arguments.index("-E") + 1], "nodiscard")
            if str(engine.MOUNT) in arguments:
                self.assertIn("nodiscard", arguments[arguments.index("-o") + 1].split(","))
            return subprocess.CompletedProcess(arguments, 0, "/dev/loop-test\n")

        with mock.patch.object(shutil, "disk_usage", return_value=SimpleNamespace(free=8192)), mock.patch.object(
            engine, "_run", side_effect=observe_command
        ):
            filesystems = engine.create_filesystems(
                self.test_run, {"scratch": (self.mount_root / "scratch", 8192)}
            )
        self.assertEqual(filesystems.entries, [(self.mount_root / "scratch", "/dev/loop-test")])

    def test_ownership_restore_only_touches_created_build_outputs(self) -> None:
        evidence = self.mount_root / "evidence"
        evidence.write_text("retained evidence\n", encoding="utf-8")
        absent = self.mount_root / "not-created"
        with mock.patch.object(
            engine, "_run", return_value=subprocess.CompletedProcess([], 0, "")
        ) as invoked:
            engine.restore_build_ownership([evidence, absent])
            self.assertEqual(invoked.call_count, 2)
            for call in invoked.call_args_list:
                self.assertIn(str(evidence), call.args[0])
                self.assertNotIn(str(absent), call.args[0])
            invoked.reset_mock()
            engine.restore_build_ownership([absent])
            invoked.assert_not_called()

    def test_absent_output_outside_build_is_still_rejected(self) -> None:
        with mock.patch.object(engine, "_run") as invoked:
            with self.assertRaisesRegex(containment.ContainmentError, "build state must be beneath"):
                engine.restore_build_ownership([ROOT / "app/not-a-build-output"])
        invoked.assert_not_called()

    @contextmanager
    def startup_fixture(self, docker_probe):
        processes = [mock.Mock(), mock.Mock()]
        for process in processes:
            process.poll.return_value = None
            process.wait.return_value = 0
        count = 0

        def launch(_arguments, **kwargs):
            nonlocal count
            self.addCleanup(kwargs["stdout"].close)
            if count == 0:
                (self.test_run.path / "r/containerd.sock").touch()
            process = processes[count]
            count += 1
            return process

        with ExitStack() as stack:
            stack.enter_context(mock.patch.object(engine, "_iptables_snapshot", return_value=()))
            stack.enter_context(mock.patch.object(engine, "_run", return_value=subprocess.CompletedProcess([], 0, "")))
            launched = stack.enter_context(mock.patch.object(engine.subprocess, "Popen", side_effect=launch))
            stack.enter_context(mock.patch.object(engine.ProjectContainerEngine, "docker", side_effect=docker_probe))
            stack.enter_context(mock.patch.object(engine.time, "sleep"))
            yield processes, launched

    def test_readiness_timeout_retries_the_same_daemon(self) -> None:
        attempts = 0

        def probe(*arguments, **_kwargs):
            nonlocal attempts
            attempts += 1
            if attempts == 1:
                raise subprocess.TimeoutExpired(["docker", "info"], 5)
            output = "[]" if "{{json .DriverStatus}}" in arguments else str(self.test_run.path / "d")
            return subprocess.CompletedProcess([], 0, output)

        with self.startup_fixture(probe) as (processes, launched):
            instance = engine.start(self.test_run, log_path=self.mount_root / "engine.log")
        self.assertIs(instance.process, processes[1])
        self.assertIs(instance.containerd_process, processes[0])
        self.assertEqual(launched.call_count, 2)
        self.assertGreaterEqual(attempts, 4)
        for process in processes:
            process.terminate.assert_not_called()

    def test_boundary_failure_stops_the_unreturned_engine(self) -> None:
        def probe(*_arguments, **_kwargs):
            return subprocess.CompletedProcess([], 0, "/var/lib/docker")

        with self.startup_fixture(probe), mock.patch.object(engine.ProjectContainerEngine, "stop") as stopped:
            with self.assertRaisesRegex(engine.EngineFailure, "daemon-data-root"):
                engine.start(self.test_run, log_path=self.mount_root / "engine.log")
        stopped.assert_called_once()

    def test_unready_stop_uses_owned_processes_without_querying_the_daemon(self) -> None:
        process, containerd_process = mock.Mock(), mock.Mock()
        containerd_process.poll.return_value = None
        instance = engine.ProjectContainerEngine(
            test_run=self.test_run, process=process, log_handle=mock.Mock(),
            containerd_process=containerd_process, containerd_log_handle=mock.Mock(),
            containerd_socket=self.test_run.path / "r/containerd.sock",
            socket=self.test_run.path / "r/docker.sock", data_root=self.test_run.path / "d",
            exec_root=self.test_run.path / "x", bridge="ambr00000000", bridge_subnet="172.30.160.1/24",
            client_config=self.test_run.path / "c", iptables_baseline=(),
        )
        with mock.patch.object(instance, "docker", side_effect=AssertionError("unverified daemon queried")), mock.patch.object(
            engine, "_run", return_value=subprocess.CompletedProcess([], 0, "")
        ), mock.patch.object(engine, "_mount_targets", return_value=[]), mock.patch.object(
            engine, "_remove_added_iptables_rules", return_value=[]
        ):
            instance.stop()
        process.wait.assert_called_once()
        containerd_process.terminate.assert_called_once()
        containerd_process.wait.assert_called_once()

if __name__ == "__main__":
    unittest.main()
