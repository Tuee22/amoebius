"""The quality floor: ruff, then black, then mypy, then the escape-hatch scan.

Fail-fast and in that order, because the cost of each step is roughly its position
in it: a style violation should cost a second, not a full type-check. The order is
also the order in which one step's output makes the next one's readable -- an
unformatted file produces type errors at lines that will move.

The last step is not a third-party tool. `mypy`'s `disallow_any_explicit` refuses a
written `Any`, but nothing in the toolchain refuses `cast(...)` or a
`# type: ignore` comment, and both defeat the type checker just as completely
while looking like ordinary code. This module scans for all three, so "no `Any`,
no `cast`, no `type: ignore`" is enforced rather than hoped for.
"""

from __future__ import annotations

import re
import sys
import tokenize
from collections.abc import Sequence
from pathlib import Path

from pb import process
from pb.process import Kind

PACKAGES = ("pb", "stubs")
ROOT = Path(__file__).resolve().parents[1]

# The three escape hatches. Each defeats the type checker as completely as the
# others while looking like ordinary code, and none of the three tools reports them:
# `disallow_any_explicit` refuses a written `Any` but says nothing about `cast(...)`
# or a `# type: ignore` comment.
BANNED_NAMES = {
    "Any": "type it as `object` and narrow it with pb.narrow",
    "cast": "narrow with an isinstance check instead of asserting the type",
}
TYPE_IGNORE = re.compile(r"#\s*type:\s*ignore")

# This module *uses* the banned names as data, so its own tokens are not evidence.
EXEMPT = {"pb/check_code.py"}


def _tool(name: str) -> Path:
    """The checker inside this distribution's own environment, by absolute path.

    Resolving against `PATH` would let whichever `mypy` happens to be first decide
    whether this code passes, which is not a property of this code.
    """
    candidate = Path(sys.executable).parent / name
    if process.executable_problem(candidate) is not None:
        raise process.ProcessError(f"quality-tool-absent:{candidate}; run `poetry install`")
    return candidate


def _run(name: str, arguments: Sequence[str]) -> int:
    print(f"$ {name} {' '.join(arguments)}", flush=True)
    return process.run(_tool(name), arguments, kind=Kind.PROBE, cwd=ROOT).returncode


def _sources(directory: Path) -> list[Path]:
    """Authored Python beneath `directory`: `.py` and `.pyi`, never bytecode.

    A `*.py*` glob also matches `.pyc`, so the scan used to try to decode compiled
    bytecode as UTF-8 -- which fails outright on a worktree that has been imported
    once, and would have matched hatch spellings inside a binary if it had not.
    """
    return [
        path
        for suffix in (".py", ".pyi")
        for path in directory.rglob(f"*{suffix}")
        if "__pycache__" not in path.parts
    ]


def scan_file(path: Path, relative: str) -> list[str]:
    """Every escape hatch this file *uses*, ignoring every one it merely names.

    The scan is over tokens rather than lines, and that is the whole difference
    between a rule and a nuisance: a docstring explaining why `Any` is banned is
    not a use of `Any`, and a textual scan that cannot tell them apart makes the
    rule unstatable in its own module. Names are read from code tokens; the
    `type: ignore` form is read from comment tokens, because that is where it lives.
    """
    findings: list[str] = []
    with path.open("rb") as handle:
        for token in tokenize.tokenize(handle.readline):
            if token.type == tokenize.NAME and token.string in BANNED_NAMES:
                label = "explicit-Any" if token.string == "Any" else "cast"
                findings.append(
                    f"{relative}:{token.start[0]}: {label} -- {BANNED_NAMES[token.string]}"
                )
            elif token.type == tokenize.COMMENT and TYPE_IGNORE.search(token.string):
                findings.append(
                    f"{relative}:{token.start[0]}: type-ignore -- "
                    "fix the type error, or add a stub under pb/stubs/"
                )
    return findings


def scan_escape_hatches(root: Path = ROOT) -> list[str]:
    """Every place the distribution reaches for an escape hatch."""
    findings: list[str] = []
    for package in PACKAGES:
        for path in sorted(_sources(root / package)):
            relative = path.relative_to(root).as_posix()
            if relative not in EXEMPT:
                findings.extend(scan_file(path, relative))
    return findings


def main() -> int:
    for name, arguments in (
        ("ruff", ("check", *PACKAGES)),
        ("black", ("--check", *PACKAGES)),
        # `stubs/` is on `mypy_path` for resolution, not a check target; mypy errors
        # on a directory holding no module, so only the package is type-checked.
        ("mypy", ("pb",)),
    ):
        code = _run(name, arguments)
        if code != 0:
            return code
    print("$ escape-hatch scan", flush=True)
    findings = scan_escape_hatches()
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
