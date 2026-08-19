#!/usr/bin/env python3
"""A substrate-portable OS-boundary argv observer.

**The problem.** A gate that claims its tools are invoked by absolute path needs to
*observe* the invocations, not assert them. The predecessor observed them with
`strace -e trace=execve`, which reads the kernel's own record and is therefore the most
trustworthy answer available — on Linux. On Apple there is no `strace`; `dtruss` needs
System Integrity Protection disabled, which is a change to the operator's machine that no
gate may require. So a gate built on `strace` is decidable on one of the four declared
substrates and dies before its first check on two of them
(`development_plan_standards.md` section L: a gate declaring substrate `none` is decidable
on every substrate).

**Why the obvious alternative fails.** Dropping to "the suite passed, so the tools must
have run" replaces an observation with an inference, which
`development_plan_standards.md` section M treats as no result at all: a gate that stopped
invoking a tool would report exactly the same thing.

**The rule.** Both routes by which a tool can be reached are made observable, using only
the process model every substrate shares:

  * the **declared** route — the gate hands out an absolute path. That path is an
    *interposer*: a two-line executable that appends its own argv to the log and then
    `exec`s the real tool, also by absolute path. An invocation through the declared route
    is therefore recorded at the boundary, by the boundary, not by its caller.
  * the **ambient** route — a bare name resolved through `PATH`. A directory of *refusing*
    shims goes first on `PATH`, one per name the observed families can be spelled as. A
    shim records the attempt and exits non-zero, so an ambient lookup is both observed and
    fatal rather than merely observed.

There is no third route to a tool in this repository: nothing addresses a compiler by a
relative path, and `toolchain.contained_env` owns the `PATH` a gate runs with. That
boundary is the honest limit of this observer and is stated rather than papered over — it
sees the two routes that exist, where `strace` saw every `execve` on one substrate.

Companion executables are deliberately **not** interposed. Cabal derives `ghc-pkg` and
friends from the compiler path it is given, so an interposer standing where a real
compiler should be would break that derivation for no observational gain: a companion is
not one of the families a phase makes a claim about.

    observer = ArgvObserver(tag="gadt-decode", families={"cabal": ..., "ghc": ..., "dhall": ...})
    observer.begin()
    env = observer.env(base_env)                 # refusing shims first on PATH
    run([observer.tool("cabal"), ...], env=env)  # the declared, absolute route
    seen, ambient = observer.observations()
"""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

DECLARED = "declared"
AMBIENT = "ambient"


class ObserverError(RuntimeError):
    """The observer cannot be built — an authored-input failure, not a failed check."""


@dataclass(frozen=True)
class Invocation:
    route: str
    family: str
    program: str
    arguments: tuple[str, ...]

    def render(self) -> str:
        return f"{self.route} {self.family}: {self.program} {' '.join(self.arguments)}".rstrip()


class ArgvObserver:
    """One run's worth of boundary observation, contained beneath `.build/`."""

    def __init__(self, *, tag: str, families: dict[str, str], root: Path = ROOT) -> None:
        if not families:
            raise ObserverError("an observer with no families observes nothing")
        for family, path in families.items():
            if not Path(path).is_absolute():
                raise ObserverError(f"{family}: the observed tool must be given as an absolute path, not {path!r}")
            if not Path(path).is_file():
                raise ObserverError(f"{family}: {path} is not a file")
        self.tag = tag
        self.families = dict(families)
        self.base = root / ".build" / "argv-observer" / tag
        self.declared_dir = self.base / "declared"
        self.refuse_dir = self.base / "refuse"
        self.log = self.base / "argv.log"

    # -- materialisation ---------------------------------------------------

    def begin(self, *, ambient_names: dict[str, str] | None = None) -> None:
        """Write the interposers and the refusing shims, and open an empty log.

        `ambient_names` maps an extra spelling to the family it belongs to — a resolved
        `ghc-9.12.4` is the same family as `ghc`, and a phase that did not refuse the
        versioned spelling would leave the ambient route open under another name.
        """
        for directory in (self.declared_dir, self.refuse_dir):
            if directory.exists():
                for path in directory.iterdir():
                    path.unlink()
            directory.mkdir(parents=True, exist_ok=True)
        self.base.mkdir(parents=True, exist_ok=True)
        self.log.write_text("", encoding="utf-8")

        for family, real in self.families.items():
            self._write(self.declared_dir / family, self._interposer(family, real))
        names = dict(ambient_names or {})
        for family in self.families:
            names.setdefault(family, family)
        for name, family in names.items():
            self._write(self.refuse_dir / name, self._refusal(family, name))

    def _write(self, path: Path, body: str) -> None:
        path.write_text(body, encoding="utf-8")
        path.chmod(0o755)

    def _interposer(self, family: str, real: str) -> str:
        # `exec` replaces this shell, so the observer costs one process and adds no wait
        # state the caller could confuse with the tool's own.
        return (
            "#!/bin/sh\n"
            f"# Boundary observer for {family}: record the invocation, then become the tool.\n"
            f'printf \'%s\\t%s\\t%s\\t%s\\n\' {DECLARED} {shlex.quote(family)} '
            f'{shlex.quote(real)} "$*" >> {shlex.quote(str(self.log))}\n'
            f"exec {shlex.quote(real)} \"$@\"\n"
        )

    def _refusal(self, family: str, name: str) -> str:
        # A refusing shim is fatal on purpose: an ambient lookup that merely got logged
        # would leave the run's result depending on a tool nobody declared.
        return (
            "#!/bin/sh\n"
            f"# Ambient-PATH refusal for {family}: {name} was resolved through PATH.\n"
            f'printf \'%s\\t%s\\t%s\\t%s\\n\' {AMBIENT} {shlex.quote(family)} '
            f'{shlex.quote(name)} "$*" >> {shlex.quote(str(self.log))}\n'
            f'echo "argv-observer: {name} was resolved through PATH; this gate invokes it by'
            f' absolute path" >&2\n'
            "exit 127\n"
        )

    # -- use ---------------------------------------------------------------

    def tool(self, family: str) -> str:
        if family not in self.families:
            raise ObserverError(f"{family} is not an observed family")
        return str(self.declared_dir / family)

    def env(self, base: dict[str, str]) -> dict[str, str]:
        """`base` with the refusing shims first on PATH."""
        out = dict(base)
        out["PATH"] = os.pathsep.join([str(self.refuse_dir), base.get("PATH", "")])
        return out

    # -- observation -------------------------------------------------------

    def invocations(self) -> list[Invocation]:
        if not self.log.is_file():
            raise ObserverError(f"the observer log {self.log} is missing")
        out: list[Invocation] = []
        for line in self.log.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            fields = line.split("\t")
            if len(fields) < 3:
                raise ObserverError(f"{self.log}: malformed record {line!r}")
            route, family, program = fields[0], fields[1], fields[2]
            arguments = tuple(fields[3].split()) if len(fields) > 3 else ()
            out.append(Invocation(route, family, program, arguments))
        return out

    def observations(self) -> tuple[set[str], list[Invocation]]:
        """(families observed on the declared route, ambient lookups that were refused)."""
        records = self.invocations()
        declared = {r.family for r in records if r.route == DECLARED}
        ambient = [r for r in records if r.route == AMBIENT]
        for record in records:
            if record.route == DECLARED and not Path(record.program).is_absolute():
                raise ObserverError(f"declared route recorded a relative program: {record.render()}")
        return declared, ambient
