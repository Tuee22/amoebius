"""Shared fixtures, and the refusal that keeps one supported suite entry point.

`pytest` invoked directly would run with whatever configuration it discovered and
without the branch-coverage floor, so a green run would mean less than the same
run through `pb.test_all`. The sentinel is a guardrail for the entry point, not a
claim that forwarded pytest arguments are disabled -- `poetry run python -m
pb.test_all -k narrow` works exactly as expected.
"""

from __future__ import annotations

import dataclasses
import os
import stat
import sys
from pathlib import Path

import pytest

PB_ROOT = Path(__file__).resolve().parents[3] / "pb"
if str(PB_ROOT) not in sys.path:
    sys.path.insert(0, str(PB_ROOT))

from pb.test_all import SENTINEL  # noqa: E402


def pytest_configure(config: pytest.Config) -> None:
    if os.environ.get(SENTINEL) != "1":
        raise pytest.UsageError(
            "Run the suite with `poetry run python -m pb.test_all` (not pytest directly); "
            "the runner sets the branch-coverage floor this suite is checked against."
        )


@pytest.fixture
def executable(tmp_path: Path):
    """Make an absolute, executable script that records the argv it was given."""

    def make(name: str, body: str = "#!/bin/sh\nexit 0\n") -> Path:
        path = tmp_path / name
        path.write_text(body, encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IRUSR)
        return path

    return make


@dataclasses.dataclass
class Recorder:
    """A factory for argv-recording stubs, and the log they all append to."""

    directory: Path
    log: Path

    def make(self, name: str, code: int = 0) -> Path:
        path = self.directory / name
        path.write_text(
            f'#!/bin/sh\nprintf "%s\\n" "$*" >> {self.log}\nexit {code}\n',
            encoding="utf-8",
        )
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IRUSR)
        return path

    def argv(self) -> list[str]:
        if not self.log.is_file():
            return []
        return [
            line for line in self.log.read_text(encoding="utf-8").splitlines() if line
        ]


@pytest.fixture
def recorder(tmp_path: Path) -> Recorder:
    """Argv-recording stubs: the boundary observer the suite watches."""
    return Recorder(tmp_path, tmp_path / "argv.log")
