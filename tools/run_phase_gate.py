#!/usr/bin/env python3
"""Run one authored phase-gate mechanism through its derived workflow value."""

from __future__ import annotations

import csv
import os
import shlex
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain


ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "test/oracle/self_referential_gates/gate_inventory.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/self-referential-gate-runner"
STORE_ROOT = ROOT / ".build/cabal-store"
COMPONENT = "test:self-referential-gates-spec"


class RunnerFailure(RuntimeError):
    pass


def read_declaration(phase: int) -> dict[str, str]:
    with INVENTORY.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    matches = [row for row in rows if row["phase"] == str(phase)]
    if len(matches) != 1:
        raise RunnerFailure(f"phase {phase}: expected one gate declaration, found {len(matches)}")
    row = matches[0]
    if row["authored_command"] == "—":
        raise RunnerFailure(f"phase {phase}: its contract has no runnable gate command yet")
    return row


def cabal_command(cabal: str, compiler: str, *arguments: str) -> list[str]:
    return [
        cabal,
        f"--with-compiler={compiler}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={STORE_ROOT}",
        "--jobs=1",
        *arguments,
    ]


def build_value_runner(cabal: str, compiler: str, environment: dict[str, str]) -> Path:
    built = subprocess.run(
        cabal_command(cabal, compiler, "build", COMPONENT),
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if built.returncode != 0:
        raise RunnerFailure(f"workflow-value build failed\n{built.stdout}")
    listed = subprocess.run(
        cabal_command(cabal, compiler, "list-bin", COMPONENT),
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    candidate = Path(listed.stdout.strip())
    if listed.returncode != 0 or not candidate.is_absolute() or not candidate.is_file():
        raise RunnerFailure(f"workflow-value binary did not resolve\n{listed.stdout}")
    return candidate


def mechanism_argv(command: str, cabal: str, compiler: str) -> list[str]:
    argv = shlex.split(command)
    if not argv:
        raise RunnerFailure("the authored gate command is empty")
    if argv[0] == "python3":
        return [sys.executable, *argv[1:]]
    if argv[0] == "cabal":
        return cabal_command(cabal, compiler, *argv[1:])
    raise RunnerFailure(f"the closed gate command domain does not admit {argv[0]!r}")


def main(arguments: list[str]) -> int:
    if len(arguments) != 1 or not arguments[0].isdigit():
        print("usage: python3 tools/run_phase_gate.py PHASE", file=sys.stderr)
        return 2
    phase = int(arguments[0])
    try:
        declaration = read_declaration(phase)
        resolved = toolchain.resolve(["cabal", "ghc"])
        cabal = resolved["cabal"]["path"]
        compiler = resolved["ghc"]["path"]
        environment = toolchain.contained_env()
        environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
        value_runner = build_value_runner(cabal, compiler, environment)
        command = declaration["authored_command"]
        print(f"self-referential gate {phase}: {command}", flush=True)
        observed = subprocess.run(
            mechanism_argv(command, cabal, compiler), cwd=ROOT, env=environment, check=False,
        )
        exit_code = observed.returncode if observed.returncode >= 0 else 128 + abs(observed.returncode)
        value = subprocess.run(
            [
                str(value_runner),
                "--value",
                str(phase),
                declaration["contract"],
                command,
                str(exit_code),
            ],
            cwd=ROOT,
            env=environment,
            check=False,
        )
        if value.returncode != 0:
            return value.returncode
        return exit_code
    except (OSError, KeyError, ValueError, RunnerFailure, toolchain.ResolutionError) as problem:
        print(f"run-phase-gate: FAIL: {problem}", file=sys.stderr)
        return 125


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
