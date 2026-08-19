"""The one place `pb` starts a child process.

Four properties hold here and nowhere else, which is the whole reason the module
exists rather than the calls being spread across the assertions:

* **argv only, never a shell.** No string is handed to `/bin/sh`, so no argument
  can be reinterpreted as syntax. `pyproject.toml` bans importing `subprocess`
  anywhere else in the distribution, so this is the only route to a child.
* **An absolute executable, refused before the kernel sees it.** A bare name would
  be resolved against the ambient `PATH`, which is exactly the thing the binary's
  no-`PATH` contract forbids and which `pb` must not do either
  (`substrate_doctrine.md` section 3). The refusal is a value, not a crash.
* **An environment overlaid, not replaced.** Replacing it is what makes a run
  depend on the operator's shell twice over — once for what it removed and once
  for what the tool then rediscovers. The overlay states the difference.
* **Output mirrored live and captured at once.** A long install must show progress
  while it runs *and* leave a transcript a failure can be classified from
  afterwards; capturing only, or mirroring only, gives up one of the two.

Every invocation is also *classified* as a probe or a mutation and recorded in a
`Ledger`. That classification is what makes idempotence checkable rather than
asserted: a converged second pass is one whose ledger holds probes and no
mutations at all.
"""

from __future__ import annotations

import dataclasses
import enum
import os
import subprocess
import sys
from collections.abc import Iterator, Mapping, Sequence
from pathlib import Path


class ProcessError(RuntimeError):
    """A child could not be started, or was refused before it was started."""


class Kind(enum.Enum):
    """What an invocation does to the host.

    A probe reads and a mutation writes. The distinction is authored per call site
    rather than inferred from the argv, because only the caller knows whether
    `ghcup list` is being asked a question or being used to cause an install.
    """

    PROBE = "probe"
    MUTATION = "mutation"

    def __str__(self) -> str:
        return self.value


@dataclasses.dataclass(frozen=True)
class Invocation:
    """One argv this run issued, as it was issued."""

    kind: Kind
    executable: str
    arguments: tuple[str, ...]

    def render(self) -> str:
        return f"{self.kind}\t{self.executable}\t{' '.join(self.arguments)}".rstrip()


@dataclasses.dataclass(frozen=True)
class Completed:
    """A finished child, with the whole of its interleaved output."""

    invocation: Invocation
    returncode: int
    output: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0


class Ledger:
    """Every argv a run issued, in order, with what each one was for.

    The ledger is `pb`'s own account of what it did. It is deliberately *not* the
    only observer: `tools/host_assert_cli_gate.py` also watches the OS boundary
    with an argv-recording interposer, because a program's account of its own
    calls cannot record the call that bypassed the account.
    """

    def __init__(self) -> None:
        self._entries: list[Invocation] = []

    def record(self, invocation: Invocation) -> None:
        self._entries.append(invocation)

    def note(self, kind: Kind, subject: str, *detail: str) -> None:
        """Record something that is not a child process but is still an act.

        A probe that reads the filesystem and an acquisition that writes a file are
        both things the run did, and a ledger holding only `execve` would report a
        converged second pass as having done nothing at all -- which is
        indistinguishable from a pass that skipped its post-condition.
        """
        self._entries.append(Invocation(kind, subject, detail))

    @property
    def entries(self) -> tuple[Invocation, ...]:
        return tuple(self._entries)

    @property
    def mutations(self) -> tuple[Invocation, ...]:
        return tuple(entry for entry in self._entries if entry.kind is Kind.MUTATION)

    @property
    def probes(self) -> tuple[Invocation, ...]:
        return tuple(entry for entry in self._entries if entry.kind is Kind.PROBE)

    def render(self) -> str:
        return "".join(entry.render() + "\n" for entry in self._entries)


def executable_problem(executable: Path) -> str | None:
    """Why this path may not be invoked, or `None` when it may.

    Separated from `run` so a caller can decide without starting anything, and so
    the suite can exercise every refusal without a host that has the tool.
    """
    if not executable.is_absolute():
        return f"non-absolute-executable:{executable}"
    if not executable.is_file():
        return f"missing-executable:{executable}"
    if not os.access(executable, os.X_OK):
        return f"not-executable:{executable}"
    return None


def environment(overlay: Mapping[str, str] | None = None) -> dict[str, str]:
    """The caller's environment with `overlay` applied on top of it."""
    merged = dict(os.environ)
    merged.update(overlay or {})
    return merged


def _drain(stream: Iterator[str], mirror: bool) -> str:
    captured: list[str] = []
    for line in stream:
        captured.append(line)
        if mirror:
            sys.stdout.write(line)
            sys.stdout.flush()
    return "".join(captured)


def run(
    executable: Path,
    arguments: Sequence[str],
    *,
    kind: Kind,
    ledger: Ledger | None = None,
    overlay: Mapping[str, str] | None = None,
    cwd: Path | None = None,
    mirror: bool = True,
) -> Completed:
    """Start one child by absolute path and return its whole result.

    The invocation is recorded *before* the child starts. Recording it afterwards
    would leave a crashed or refused call out of the ledger, and a ledger that
    omits the call that failed is worse than no ledger.
    """
    problem = executable_problem(executable)
    if problem is not None:
        raise ProcessError(problem)
    invocation = Invocation(kind, str(executable), tuple(arguments))
    if ledger is not None:
        ledger.record(invocation)
    try:
        child = subprocess.Popen(
            [str(executable), *arguments],
            cwd=None if cwd is None else str(cwd),
            env=environment(overlay),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
    except OSError as failure:
        raise ProcessError(f"could-not-start:{executable}:{failure}") from failure
    with child:
        stream = child.stdout
        output = "" if stream is None else _drain(stream, mirror)
    return Completed(invocation, child.returncode, output)


def become(executable: Path, arguments: Sequence[str]) -> int:
    """Replace this process with `executable` on POSIX; run it on Windows.

    This lives beside `run` because it is the *other* route by which this program
    reaches another program, and a choke point with a second door is not one. The
    asymmetry is honest rather than papered over: on POSIX the image is replaced,
    so no parent survives to misreport the child's result and this call does not
    return; Windows has no call that replaces a running process, so the child is
    run and its exit code propagated.
    """
    problem = executable_problem(executable)
    if problem is not None:
        raise ProcessError(problem)
    if os.name == "nt":
        return run(executable, arguments, kind=Kind.MUTATION).returncode
    sys.stdout.flush()
    sys.stderr.flush()
    # S606 asks whether a process is started without a shell. It is, deliberately:
    # a shell here would be the ambient-resolution route this program exists to refuse.
    os.execv(str(executable), [str(executable), *arguments])  # noqa: S606
    raise ProcessError("execv-returned")  # pragma: no cover - unreachable on POSIX


def run_checked(
    executable: Path,
    arguments: Sequence[str],
    *,
    kind: Kind,
    ledger: Ledger | None = None,
    overlay: Mapping[str, str] | None = None,
    cwd: Path | None = None,
    mirror: bool = True,
) -> str:
    """`run`, refusing a non-zero exit. Returns the output on success."""
    completed = run(
        executable, arguments, kind=kind, ledger=ledger, overlay=overlay, cwd=cwd, mirror=mirror
    )
    if not completed.ok:
        raise ProcessError(
            f"command-failed:{executable}:{completed.returncode}\n{completed.output}"
        )
    return completed.output
