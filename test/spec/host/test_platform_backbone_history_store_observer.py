"""Authored syscall-order cases, separate from the Haskell persistence code."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import platform_backbone_history_store_observer as observer


def trace_input():
    # Descriptor annotations model strace6.x -f -yy. The data-content test is
    # the independent AHST1 corpus; this fixture specifies ordering only.
    root = "/fixture/phase30-history-wire-a/store"
    lines = [
        f'11 mkdir("{root}", 0700) = 0',
        f'11 openat(AT_FDCWD, "{Path(root).parent}", O_RDONLY|O_DIRECTORY) = 4<{Path(root).parent}>',
        f'11 fsync(4<{Path(root).parent}>) = 0',
    ]

    def cycle(path, rename=True, directory_sync=True):
        rows = [
            f'11 openat(AT_FDCWD, "{path}", O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC) = 3<{path}>',
            f'11 openat(AT_FDCWD, "/proc/self/fd/3/owner.lock", O_RDWR|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC, 0600) = 5<{path}/owner.lock>',
            f'11 flock(5<{path}/owner.lock>, LOCK_EX|LOCK_NB) = 0',
            f'11 fsync(5<{path}/owner.lock>) = 0',
            f'11 openat(AT_FDCWD, "/proc/self/fd/3/state.next", O_RDWR|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC, 0600) = 9<{path}/state.next>',
            f'11 write(9<{path}/state.next>, "bounded-payload", 383) = 383',
            f'11 fsync(9<{path}/state.next>) = 0',
            f'11 close(9<{path}/state.next>) = 0',
        ]
        if rename:
            rows.append('11 rename("/proc/self/fd/3/state.next", "/proc/self/fd/3/state") = 0')
            if directory_sync:
                rows.append(f'11 fsync(3<{path}>) = 0')
        rows.extend([f'11 close(5<{path}/owner.lock>) = 0', f'11 close(3<{path}>) = 0'])
        return rows

    lines.extend(cycle(root))
    # Exactly two completed renames are deliberately interrupted before the
    # directory sync, plus four deliberately abandoned pre-rename candidates.
    for index in range(2):
        lines.extend(cycle(f"/fixture/phase30-history-fault-rename{index}/store", directory_sync=False))
    for index in range(4):
        lines.extend(cycle(f"/fixture/phase30-history-fault-prefix{index}/store", rename=False))
    lines.extend([
        f'12 flock(5<{root}/owner.lock>, LOCK_EX|LOCK_NB) = -1 EAGAIN (Resource temporarily unavailable)',
        f'13 flock(5<{root}/owner.lock>, LOCK_EX|LOCK_NB) = -1 EAGAIN (Resource temporarily unavailable)',
        '11 +++ exited with 0 +++',
    ])
    return "\n".join(lines) + "\n"


class HistoryStoreObserverTests(unittest.TestCase):
    def inspect(self, text):
        with tempfile.TemporaryDirectory(prefix="history-trace-", dir=".build/tmp") as folder:
            path = Path(folder) / "syscalls.log"
            path.write_text(text)
            return observer.check(path)

    def test_authored_positive(self):
        actual = self.inspect(trace_input())
        for key, expected in {
            "observedRenames": 3, "directorySyncedRenames": 1,
            "expectedFaultUnsealedRenames": 2, "expectedFaultCandidatePrefixes": 4,
            "observedNonblockingLockDenials": 2, "largestObservedCandidateBytes": 383,
            "allRenamesFollowExclusiveWriteFileSyncClose": True,
            "initialMkdirParentsSyncedBeforeCandidateCreation": True,
            "initialOwnerLocksSyncedBeforeCandidateCreation": True,
            "originalExclusiveLocksRetainedThroughRenameAndDirectorySync": True,
        }.items():
            self.assertEqual(actual[key], expected)

    def test_missing_candidate_sync(self):
        text = trace_input().replace('11 fsync(9</fixture/phase30-history-wire-a/store/state.next>) = 0\n', '', 1)
        with self.assertRaisesRegex(ValueError, "rename-without-write-sync-close"):
            self.inspect(text)

    def test_missing_initial_parent_sync(self):
        text = trace_input().replace('11 fsync(4</fixture/phase30-history-wire-a>) = 0\n', '', 1)
        with self.assertRaisesRegex(ValueError, "initial-parent-directory-not-synced"):
            self.inspect(text)

    def test_missing_post_rename_directory_sync(self):
        text = trace_input().replace('11 fsync(3</fixture/phase30-history-wire-a/store>) = 0\n', '', 1)
        with self.assertRaisesRegex(ValueError, "incomplete-cycle-outside-fault-case"):
            self.inspect(text)

    def test_nonexclusive_candidate(self):
        text = trace_input().replace('state.next", O_RDWR|O_CREAT|O_EXCL|', 'state.next", O_RDWR|O_CREAT|', 1)
        with self.assertRaisesRegex(ValueError, "rename-without-exclusive-candidate"):
            self.inspect(text)

    def test_candidate_without_owner_lock(self):
        text = trace_input().replace('11 flock(5</fixture/phase30-history-wire-a/store/owner.lock>, LOCK_EX|LOCK_NB) = 0\n', '', 1)
        with self.assertRaisesRegex(ValueError, "candidate-without-observed-exclusive-lock"):
            self.inspect(text)

    def test_wrong_rename_target(self):
        text = trace_input().replace('"/proc/self/fd/3/state") = 0', '"/proc/self/fd/3/other") = 0', 1)
        with self.assertRaisesRegex(ValueError, "rename-destination"):
            self.inspect(text)

    def test_missing_owner_lock_sync(self):
        text = trace_input().replace('11 fsync(5</fixture/phase30-history-wire-a/store/owner.lock>) = 0\n', '', 1)
        with self.assertRaisesRegex(ValueError, "initial-owner-lock-not-synced"):
            self.inspect(text)

    def test_owner_released_before_rename(self):
        text = trace_input().replace('11 rename("/proc/self/fd/3/state.next",',
            '11 close(5</fixture/phase30-history-wire-a/store/owner.lock>) = 0\n11 rename("/proc/self/fd/3/state.next",', 1)
        with self.assertRaisesRegex(ValueError, "rename-without-original-lock"):
            self.inspect(text)

    def test_unknown_interleaving(self):
        with self.assertRaisesRegex(ValueError, "unsupported-interleaved-syscall-format"):
            self.inspect(trace_input() + '11 fsync(9 <unfinished ...>\n')

    def test_owner_released_before_directory_sync(self):
        text = trace_input().replace('11 fsync(3</fixture/phase30-history-wire-a/store>) = 0',
            '11 close(5</fixture/phase30-history-wire-a/store/owner.lock>) = 0\n11 fsync(3</fixture/phase30-history-wire-a/store>) = 0', 1)
        with self.assertRaisesRegex(ValueError, "directory-sync-without-original-lock"):
            self.inspect(text)

    def test_trace_truncated(self):
        with self.assertRaisesRegex(ValueError, "trace-not-complete-successful-exit"):
            self.inspect(trace_input().replace('11 +++ exited with 0 +++\n', ''))

    def test_empty_trace(self):
        with self.assertRaisesRegex(ValueError, "expected-two-AfterStateRename-fault-cycles"):
            self.inspect('')


if __name__ == "__main__":
    unittest.main()
