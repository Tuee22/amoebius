"""The one supported way to run the suite, under branch coverage.

Running `pytest` directly is refused by `test/spec/pb/conftest.py`, which looks for
the sentinel this runner sets. One entry point means one configuration: a suite
that can be started two ways is a suite whose coverage floor applies on only one
of them.

Coverage is *inside* the runner rather than beside it. A floor reached only when
someone remembers to type a second command is not a floor, and the phase contract
asks for a suite that runs at 100% branch coverage -- one claim, one command.

This module is the one thing `[tool.coverage.run] omit` excludes, and the reason is
structural rather than convenient: it is imported and running *before* measurement
starts, so its own lines can never be recorded as executed. Measuring it would
report a hole that no test could ever close.
"""

from __future__ import annotations

import os
import sys
from collections.abc import Sequence
from pathlib import Path

import coverage
import coverage.exceptions
import pytest

SENTINEL = "AMOEBIUS_PB_TEST_ALL"
ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "pyproject.toml"


def run(arguments: Sequence[str]) -> int:
    """Run the suite under branch coverage and report it against the floor."""
    measure = coverage.Coverage(config_file=str(CONFIG))
    measure.start()
    try:
        outcome = int(pytest.main(["-c", str(CONFIG), *arguments]))
    finally:
        measure.stop()
        measure.save()
    if outcome != 0:
        return outcome
    try:
        measure.report()
    except coverage.exceptions.CoverageException as problem:
        print(f"pb.test_all: {problem}", file=sys.stderr)
        return 1
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    os.environ[SENTINEL] = "1"
    return run(list(sys.argv[1:]) if argv is None else list(argv))


if __name__ == "__main__":
    raise SystemExit(main())
