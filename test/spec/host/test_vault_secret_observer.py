from __future__ import annotations

import os
import subprocess
import sys
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import containment  # noqa: E402
import vault_secret_observer as observer  # noqa: E402


class VaultSecretObserverSpec(unittest.TestCase):
    def setUp(self) -> None:
        self.run = containment.create_test_run("vault-secret-spec-" + uuid.uuid4().hex)
        self.addCleanup(containment.cleanup_test_run, self.run)
        self.needle = b"fresh-synthetic-private-canary"

    def test_absent_secret_is_clean(self) -> None:
        (self.run.path / "plain").write_bytes(b"ordinary data")
        self.assertEqual(observer.scan_tree(self.run.path, self.needle)["matches"], 0)

    def test_planted_file_content_is_detected(self) -> None:
        (self.run.path / "leak").write_bytes(b"prefix" + self.needle + b"suffix")
        result = observer.scan_tree(self.run.path, self.needle)
        self.assertEqual(result["matches"], 1)
        self.assertNotIn(self.needle.decode(), str(result))

    def test_canary_across_read_boundary_is_detected(self) -> None:
        path = self.run.path / "split"
        path.write_bytes(b"x" * (256 * 1024 - 7) + self.needle)
        self.assertTrue(observer.scan_file(path, self.needle)[1])

    def test_fifo_does_not_block_scan(self) -> None:
        pipe = self.run.path / "pipe"
        os.mkfifo(pipe)
        self.addCleanup(pipe.unlink, missing_ok=True)
        self.assertEqual(observer.scan_tree(self.run.path, self.needle)["matches"], 0)

    def test_symlinks_are_not_followed(self) -> None:
        inside = self.run.path / "inside"
        inside.mkdir()
        outside = self.run.path / "outside"
        outside.write_bytes(self.needle)
        (inside / "link").symlink_to(outside)
        self.assertEqual(observer.scan_tree(inside, self.needle)["matches"], 0)

    def test_secret_in_filename_is_detected_without_emitting_it(self) -> None:
        (self.run.path / self.needle.decode()).write_bytes(b"ordinary data")
        result = observer.scan_tree(self.run.path, self.needle)
        self.assertEqual(result["matches"], 1)
        self.assertNotIn(self.needle.decode(), str(result))

    def test_unavailable_file_fails_closed(self) -> None:
        with self.assertRaises(FileNotFoundError):
            observer.scan_file(self.run.path / "missing", self.needle)

    def test_directory_removed_during_walk_is_counted_but_missing_root_fails(self) -> None:
        child = self.run.path / "transient-exec"
        child.mkdir()
        walk = os.walk

        def concurrent_removal(*args, **kwargs):
            for index, row in enumerate(walk(*args, **kwargs)):
                yield row
                if index == 0:
                    child.rmdir()

        with patch.object(observer.os, "walk", concurrent_removal):
            result = observer.scan_tree(self.run.path, self.needle)
        self.assertEqual(result["vanishedDirectories"], 1)
        with self.assertRaisesRegex(observer.ScanError, "directory-unavailable"):
            observer.scan_tree(child, self.needle)

    def test_live_process_identity_and_state_are_read(self) -> None:
        pid = os.getpid()
        self.assertTrue(observer.process_identity(pid).isdigit())
        result = observer.scan_process(pid, self.needle)
        self.assertEqual(result, {"processes": 1, "matches": 0})

    def test_kernel_namespace_descriptor_is_distinguished_from_content_file(self) -> None:
        descriptor = os.open("/proc/self/ns/net", os.O_RDONLY)
        try:
            self.assertTrue(observer.namespace_handle(descriptor))
        finally:
            os.close(descriptor)
        content = self.run.path / "netns"
        content.write_bytes(self.needle)
        self.assertTrue(observer.scan_file(content, self.needle)[1])

    def test_zombie_and_reaped_child_are_counted_without_ignoring_live_processes(self) -> None:
        child = subprocess.Popen(["/bin/true"])
        try:
            os.waitid(os.P_PID, child.pid, os.WEXITED | os.WNOWAIT)
            with self.assertRaisesRegex(observer.ProcessExited, "zombieProcesses"):
                observer.scan_process(child.pid, self.needle)
            rows, lifecycle = observer.scan_owned_processes(os.getpid(), self.needle, {os.getpid()})
            self.assertGreaterEqual(lifecycle["zombieProcesses"], 1)
            self.assertTrue(rows)
            self.assertTrue(all(row["matches"] == 0 for row in rows))
            with self.assertRaisesRegex(observer.ScanError, "snapshot-unavailable"):
                observer.scan_owned_processes(child.pid, self.needle, {child.pid})
        finally:
            child.wait()
        with self.assertRaisesRegex(observer.ProcessExited, "vanishedProcesses"):
            observer.scan_process(child.pid, self.needle)

    def test_unreadable_live_process_still_fails_closed(self) -> None:
        with patch.object(Path, "read_bytes", side_effect=PermissionError(13, "denied")):
            with self.assertRaisesRegex(observer.ScanError, "process-unavailable"):
                observer.scan_process(os.getpid(), self.needle)

    def test_real_child_environment_and_arguments_leaks_are_detected(self) -> None:
        child = subprocess.Popen(
            [sys.executable, "-c", "import sys; sys.stdin.buffer.read()", self.needle.decode()],
            env={**os.environ, "OBSERVER_SYNTHETIC_CANARY": self.needle.decode()}, stdin=subprocess.PIPE,
        )
        try:
            self.assertEqual(observer.scan_process(child.pid, self.needle), {"processes": 1, "matches": 2})
        finally:
            child.communicate()


if __name__ == "__main__":
    unittest.main()
