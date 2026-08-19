#!/usr/bin/env python3
"""Drive `pb`'s host assertions absent -> present -> present against a fake host.

The gate cannot prove idempotence on a real machine: the first pass would mutate
the operator's host, and a host that is already provisioned never exercises the
absent arm at all. So the boundary is faked and the *transcript* is the evidence.
Three passes run against one fake host, and each pass's whole ledger is emitted.

Two properties are read off the result rather than asserted here, because a driver
that judged its own run would be the thing the gate exists to check:

  * the first pass converges, and the second reports converged **because it
    probed** -- pass two's ledger carries post-condition probes;
  * the second pass mutates nothing -- pass two's ledger carries no mutation.

The `pb` under test is imported from `--pb-root`, so the same driver runs against
the authored tree and against each seeded mutant's scratch copy.

This driver **observes and does not judge**. It emits one JSON document of what it
saw; `tools/host_assert_cli_gate.py` decides. Keeping the two apart is what lets the
same driver run against the authored tree and against each seeded mutant's scratch
copy without the judgement travelling with the mutation.

    observe.py --pb-root pb --work .build/... --out observations.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

GHCUP_VERSION = "9.12.4"
CABAL_VERSION = "3.16.1.0"
DIGEST = "0" * 64

# A ghcup that lays down exactly the tool it was asked for. Laying both down at
# once would hide a driver that installs one and reports two.
GHCUP_STUB = """#!/bin/sh
if [ "$1" = "install" ]; then
  case "$2" in
    ghc)   target={ghc} ;;
    cabal) target={cabal} ;;
    *)     exit 1 ;;
  esac
  mkdir -p "$(dirname "$target")"
  printf '#!/bin/sh\\nexit 0\\n' > "$target"
  chmod 755 "$target"
fi
exit 0
"""

TOOL_STUB = "#!/bin/sh\nexit 0\n"


def envelope(root: Path) -> object:
    """The authored capacity envelope, read from the tree under test."""
    from pb import narrow

    return narrow.as_mapping(
        narrow.load(root / "pb" / "bootstrap_execution_envelope.json"), "envelope"
    )


def build(work: Path) -> Path:
    """A fake host: an empty run-local home, and nothing installed in it."""
    home = work / "home"
    if home.exists():
        import shutil

        shutil.rmtree(home)
    home.mkdir(parents=True)
    return home


def acquisition(home: Path):
    """Collaborators that lay down real stub executables instead of downloading."""
    from pb import bootstrap_toolchain as toolchain
    from pb import prereqs

    def resolved(name: str) -> toolchain.Resolved:
        return toolchain.Resolved(
            name=name,
            source="github-release",
            version="1.0.0",
            requirement=">=1",
            url=f"https://example.invalid/{name}",
            publisher_sha256=DIGEST,
        )

    def download(_url: str, _digest: str, target: Path) -> str:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.name == "ghcup":
            body = GHCUP_STUB.format(
                ghc=prereqs.install_target(home, "ghc"),
                cabal=prereqs.install_target(home, "cabal"),
            )
        else:
            body = TOOL_STUB
        target.write_text(body, encoding="utf-8")
        target.chmod(0o755)
        return DIGEST

    def managed(_root: Path, _ghcup: Path, _home: Path):
        return {
            "ghc": toolchain.Resolved(
                name="ghc", source="managed", provider="ghcup",
                version=GHCUP_VERSION, requirement=">=9",
            ),
            "cabal": toolchain.Resolved(
                name="cabal", source="managed", provider="ghcup",
                version=CABAL_VERSION, requirement=">=3",
            ),
        }

    return prereqs.Acquisition(
        resolve_acquired=lambda _root: {name: resolved(name) for name in toolchain.ACQUIRED},
        resolve_managed=managed,
        download=download,
    )


def replay(root: Path, work: Path, passes: int = 3) -> list[tuple[int, str, str, str]]:
    """Run the ensure driver `passes` times against one fake host."""
    from pb import prereqs, process

    home = build(work)
    plan = acquisition(home)
    document = envelope(root)
    rows: list[tuple[int, str, str, str]] = []
    for index in range(1, passes + 1):
        ledger = process.Ledger()
        prereqs.ensure_toolchain(
            root=root, home=home, envelope=document, ledger=ledger, acquisition=plan
        )
        for entry in ledger.entries:
            rows.append(
                (
                    index,
                    str(entry.kind),
                    _portable(entry.executable, home),
                    " ".join(_portable(argument, home) for argument in entry.arguments),
                )
            )
    return rows


def _portable(value: str, home: Path) -> str:
    """One field with the run-local home elided, so the transcript is authorable.

    A transcript carrying a temporary directory could only ever be compared against
    itself, which is the difference between an oracle and a snapshot.
    """
    return str(value).replace(str(home), "$HOME")


def floor_observations(root: Path) -> dict[str, object]:
    """What the floor does on a substrate this host is not, and what the CLI does about it.

    `windows` is chosen deliberately: its floor can never hold on any host that runs
    this driver, so the refusal arm is reached on every substrate the gate runs on.
    A run that continued past a refusal is not a louder failure later -- it is a host
    mutated without the operator ever being told what was missing.
    """
    from pb import cli, prereqs

    refusals = prereqs.evaluate(
        prereqs.Substrate.WINDOWS, prereqs.observe(prereqs.Substrate.WINDOWS)
    )
    return {
        "plan_problems": list(prereqs.well_formed()),
        "identifiers": [refusal.identifier for refusal in refusals],
        "remedies": [refusal.remedy for refusal in refusals],
        "cli_exit": cli.main(["floor", "--substrate", "windows"]),
        "declared": {
            str(substrate): [row.identifier for row in rows]
            for substrate, rows in prereqs.FLOOR.items()
        },
    }


def surface_observations(root: Path) -> dict[str, object]:
    """The parser's own topology, and how it answers a verb it does not have."""
    import click
    from click.testing import CliRunner

    from pb import cli

    runner = CliRunner()
    unknown = runner.invoke(cli.cli, ["nosuchverb"])
    help_text = runner.invoke(cli.cli, ["--help"]).output
    listed = {
        line.split()[0]
        for line in help_text.split("Commands:", 1)[-1].splitlines()
        if line.startswith("  ") and line.split()
    }
    # Both arms of the maintainer guard, observed rather than argued. Hiding a
    # command from `--help` is presentation; the body's own check is the guard, and
    # only running it with the checkout taken away can tell whether it is there.
    resolves_here = cli.cli.get_command(click.Context(cli.cli), "surface") is not None
    original = cli.development_checkout
    cli.development_checkout = lambda: None
    try:
        outside_resolves = cli.cli.get_command(click.Context(cli.cli), "surface") is not None
        body_refuses = False
        try:
            cli.require_maintainer("surface")
        except Exception as problem:  # noqa: BLE001 -- the gate reads the tag, not the type
            body_refuses = "maintainer-command-unavailable" in str(problem)
    finally:
        cli.development_checkout = original

    return {
        "topology": [list(row) for row in cli.topology()],
        "maintainer_commands": sorted(cli.MAINTAINER_COMMANDS),
        "listed_commands": sorted(listed),
        "unknown_verb_exit": unknown.exit_code,
        "unknown_verb_output": unknown.output,
        "in_checkout": cli.development_checkout() is not None,
        "maintainer_resolves_in_checkout": resolves_here,
        "maintainer_resolves_outside_checkout": outside_resolves,
        "maintainer_body_refuses_outside_checkout": body_refuses,
        "coverage_omit": _coverage_omit(root),
    }


def _coverage_omit(root: Path) -> list[str]:
    """The two files the coverage floor is allowed not to measure."""
    import re

    text = (root / "pb" / "pyproject.toml").read_text(encoding="utf-8")
    match = re.search(r"^omit = \[(.*?)\]", text, re.M | re.S)
    return sorted(re.findall(r'"([^"]+)"', match.group(1))) if match else []


def guard_observations(work: Path) -> dict[str, object]:
    """Direct probes of the guards no ordinary call exercises.

    Every call site in the authored tree already passes an absolute path, so the
    bare-name refusal is load-bearing for calls nobody has written yet, and nothing
    but a direct probe can tell whether it is still there.

    The probe deliberately uses a relative path that **exists and is executable**.
    A relative name that resolves to nothing is refused by the file check whether or
    not the absolute check is present, so probing with one would pass over a deleted
    guard without noticing -- which is precisely the mutation being watched for.
    """
    import os

    from pb import process

    real = work / "guard-probe"
    real.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    real.chmod(0o755)
    relative = Path(os.path.relpath(real, Path.cwd()))
    return {
        "absent_bare_name_refused": process.executable_problem(Path("ghcup")) is not None,
        "existing_relative_path_refused": process.executable_problem(relative) is not None,
        "absolute_path_admitted": process.executable_problem(real) is None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(prog="observe")
    parser.add_argument("--pb-root", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    arguments = parser.parse_args()
    # Resolved here rather than trusted from argv: `pb.process` refuses a
    # non-absolute executable, so a relative work root would be refused several
    # frames in and reported as a defect in the tree under test rather than in the call.
    pb_root = arguments.pb_root.resolve()
    work = arguments.work.resolve()
    out = arguments.out.resolve()

    sys.path.insert(0, str(pb_root))
    out.parent.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)

    root = pb_root.parent
    observations: dict[str, object] = {"pb_root": str(pb_root)}
    try:
        observations["replay"] = [list(row) for row in replay(root, work)]
    except Exception as problem:  # noqa: BLE001 -- a failed replay is an observation
        observations["replay"] = []
        observations["replay_error"] = f"{type(problem).__name__}: {problem}"
    observations["floor"] = floor_observations(root)
    observations["surface"] = surface_observations(root)
    observations["guards"] = guard_observations(work)
    out.write_text(json.dumps(observations, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
