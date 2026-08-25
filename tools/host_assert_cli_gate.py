#!/usr/bin/env python3
"""The Phase-3 gate — the pre-binary assertions are idempotent and the surface is closed.

Phase 3 makes one cohesive claim, and the gate runs it as five sides over one
observation of the distribution:

  quality    ruff, black, mypy strict and the escape-hatch scan pass, and the suite
             runs at 100% branch coverage -- a precondition, not a report
  topology   the parser's own enumeration joins the authored oracle both ways, an
             unknown verb is refused, and the maintainer surface resolves only in a
             development checkout
  replay     absent -> present -> present against a committed fake host: pass one
             converges, passes two and three probe and mutate nothing
  floor      every substrate's floor is well-formed, each refusal carries its remedy,
             and a run whose floor refused stops
  mutant     four committed seeded defects, each red at its own check and no other

The independent oracles are deliberately **not this phase's code**:
`test/fixture/host_assert_cli/ensure_transcript.tsv` is authored from
`substrate_doctrine.md` sections 3 and 6, and
`test/oracle/host_assert_cli_surfaces.tsv` from this phase's own contract. Neither is
captured from a run, so the gate compares the implementation against a plan rather
than against itself.

    python3 tools/host_assert_cli_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import mutant_registry  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

GATE_COMMAND = "python3 tools/host_assert_cli_gate.py"
CONTRACT = "DEVELOPMENT_PLAN/phase_51_host_assert_cli.md"
EXPECTATIONS = "test/oracle/host_assert_cli_surfaces.tsv"

DISTRIBUTION = ROOT / "pb"
ENVIRONMENT_ROOT = ROOT / ".build" / "toolchain" / "host_assert_cli"
VIRTUALENVS = ENVIRONMENT_ROOT / "virtualenvs"
HARNESS = ROOT / "test" / "harness" / "host_assert_cli" / "observe.py"
TRANSCRIPT = ROOT / "test" / "fixture" / "host_assert_cli" / "ensure_transcript.tsv"
MUTANT_DIR = ROOT / "test" / "mutant" / "host_assert_cli"
MUTANT_CAPABILITY = "host_assert_cli"
SCRATCH = ROOT / ".build" / "tmp" / "host_assert_cli"

SIDES = ("quality", "topology", "replay", "floor", "mutant")

# The five tool names `pb` must never reach through an ambient search path. A shim
# for each goes first on PATH while the harness runs: an ambient lookup is then both
# recorded and fatal, rather than merely absent from a trace the code writes itself.
OBSERVED_TOOLS = ("ghcup", "ghc", "cabal", "kubectl", "kind")

CHECKS = {
    "quality-floor-green": "ruff, black, mypy strict, the escape-hatch scan and the 100% branch floor",
    "coverage-omit-list-exact": "the coverage floor excludes exactly the two files it cannot measure",
    "first-pass-converges": "the first pass performs exactly the authored acquisitions and installs",
    "probe-decides-convergence": "a converged pass reports converged because it re-probed",
    "second-pass-mutates-nothing": "the second and third passes carry no mutation at all",
    "no-ambient-path-lookup": "no tool was reached through an ambient search path",
    "invocation-absolute-path-only": "the choke point refuses a bare name and an existing relative path",
    "surface-joins-the-oracle": "the parser's enumeration matches the authored command topology",
    "unknown-verb-refused": "an unknown verb resolves to no command",
    "maintainer-surface-hidden": "the maintainer surface is absent from the consumer listing",
    "maintainer-authority-rechecked": "the maintainer command resolves, and its body refuses, by checkout",
    "floor-decidable-for-every-substrate": "every catalogue member's floor is well-formed",
    "floor-remedy-present": "every refusal names what clears it",
    "floor-refusal-halts-the-run": "a run whose floor refused stops instead of proceeding",
}

SIDE_CHECKS = {
    "quality": ("quality-floor-green", "coverage-omit-list-exact"),
    "topology": (
        "surface-joins-the-oracle",
        "unknown-verb-refused",
        "maintainer-surface-hidden",
        "maintainer-authority-rechecked",
    ),
    "replay": (
        "first-pass-converges",
        "probe-decides-convergence",
        "second-pass-mutates-nothing",
        "no-ambient-path-lookup",
        "invocation-absolute-path-only",
    ),
    "floor": (
        "floor-decidable-for-every-substrate",
        "floor-remedy-present",
        "floor-refusal-halts-the-run",
    ),
}

SIDE_HEADLINE = {
    "quality": "the quality floor, before any assertion is exercised",
    "topology": "the closed command surface against its authored oracle",
    "replay": "absent -> present -> present against the committed fake host",
    "floor": "the per-substrate floor, and what a refusal does",
}


class GateFailure(RuntimeError):
    """An authored input is missing — the gate cannot decide, rather than deciding no."""


def rel(path: Path) -> str:
    return os.path.relpath(str(path), str(ROOT))


# ---------------------------------------------------------------------------
# the environment the distribution is checked in
# ---------------------------------------------------------------------------


def poetry() -> Path:
    """Poetry at an absolute path, never a name resolved against `PATH`."""
    for candidate in (Path("/opt/homebrew/bin/poetry"), Path("/usr/local/bin/poetry"), Path("/usr/bin/poetry")):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate
    raise GateFailure("poetry is absent; the distribution's own environment cannot be ensured")


def poetry_environment() -> dict[str, str]:
    """Keep every Poetry-owned cache, datum and virtualenv beneath `.build`."""
    environment = dict(os.environ)
    settings = {
        "POETRY_CACHE_DIR": ENVIRONMENT_ROOT / "cache",
        "POETRY_DATA_DIR": ENVIRONMENT_ROOT / "data",
        "POETRY_VIRTUALENVS_IN_PROJECT": "false",
        "POETRY_VIRTUALENVS_PATH": VIRTUALENVS,
        "PIP_CACHE_DIR": ENVIRONMENT_ROOT / "pip-cache",
    }
    for name, value in settings.items():
        environment[name] = str(value)
    return environment


def resolved_environment_python(environment: dict[str, str]) -> Path | None:
    """Ask Poetry for the interpreter it selected, then enforce containment."""
    result = subprocess.run(
        [str(poetry()), "env", "info", "--path"],
        cwd=DISTRIBUTION,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    environment_path = Path(result.stdout.strip()).resolve()
    try:
        environment_path.relative_to(VIRTUALENVS.resolve())
    except ValueError as error:
        raise GateFailure(
            f"poetry selected {environment_path}, outside the governed build root"
        ) from error
    candidate = environment_path / "bin" / "python"
    if not candidate.is_file() or not os.access(candidate, os.X_OK):
        return None
    return candidate


def ensure_environment() -> Path:
    """Probe for the build-contained virtualenv, install it when absent, resolve it.

    The same four-step ensure the distribution itself performs, applied to the
    distribution: a gate that assumed the environment would fail on a fresh clone
    with a message about a missing interpreter rather than about the phase.
    """
    environment = poetry_environment()
    VIRTUALENVS.mkdir(parents=True, exist_ok=True)
    python = resolved_environment_python(environment)
    if python is not None:
        return python
    print("  note  the build-contained Poetry environment is absent; installing it")
    subprocess.run(
        [str(poetry()), "install", "--no-interaction"],
        cwd=DISTRIBUTION,
        env=environment,
        check=True,
    )
    python = resolved_environment_python(environment)
    if python is None:
        raise GateFailure("poetry install did not produce a build-contained interpreter")
    return python


def refusing_shims(directory: Path, log: Path) -> Path:
    """A directory of refusing shims, one per tool this phase claims never to search for."""
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("", encoding="utf-8")
    for name in OBSERVED_TOOLS:
        shim = directory / name
        shim.write_text(
            "#!/bin/sh\n"
            f"printf 'ambient\\t{name}\\t%s\\n' \"$*\" >> {log}\n"
            f"echo 'host-assert-cli-gate: {name} was reached through PATH' >&2\n"
            "exit 127\n",
            encoding="utf-8",
        )
        shim.chmod(0o755)
    return directory


# ---------------------------------------------------------------------------
# observation
# ---------------------------------------------------------------------------


def observe(python: Path, pb_root: Path, work: Path) -> dict[str, object]:
    """Run the harness against one `pb` tree and read back what it saw."""
    out = work / "observations.json"
    shims = refusing_shims(work / "refuse", work / "ambient.log")
    environment = dict(os.environ)
    environment["PATH"] = os.pathsep + environment.get("PATH", "")
    environment["PATH"] = str(shims) + environment["PATH"]
    result = subprocess.run(
        [
            str(python), str(HARNESS),
            "--pb-root", str(pb_root),
            "--work", str(work / "host"),
            "--out", str(out),
        ],
        cwd=ROOT, env=environment, text=True, capture_output=True, check=False,
    )
    if not out.is_file():
        raise GateFailure(f"the harness produced no observation:\n{result.stdout}{result.stderr}")
    observations: dict[str, object] = json.loads(out.read_text(encoding="utf-8"))
    ambient = (work / "ambient.log").read_text(encoding="utf-8").strip()
    observations["ambient"] = [line for line in ambient.splitlines() if line.strip()]
    return observations


def authored_transcript() -> list[tuple[str, str, str, str]]:
    """The absent -> present -> present transcript, as a human authored it."""
    if not TRANSCRIPT.is_file():
        raise GateFailure(f"the authored transcript {rel(TRANSCRIPT)} is missing")
    rows: list[tuple[str, str, str, str]] = []
    for number, line in enumerate(TRANSCRIPT.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 4:
            raise GateFailure(f"{rel(TRANSCRIPT)}:{number}: expected four tab-separated fields")
        rows.append((fields[0], fields[1], fields[2], fields[3]))
    if not rows:
        raise GateFailure(f"{rel(TRANSCRIPT)} carries no row")
    return rows


def oracle_topology() -> list[tuple[str, str, str]]:
    """The authored command topology, read out of the surface expectation."""
    rows: list[tuple[str, str, str]] = []
    path = ROOT / EXPECTATIONS
    if not path.is_file():
        raise GateFailure(f"the authored expectation {EXPECTATIONS} is missing")
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("# command "):
            continue
        body = line.partition("# command ")[2]
        fields = body.split("|")
        if len(fields) != 3:
            raise GateFailure(f"{EXPECTATIONS}: malformed command row {body!r}")
        rows.append((fields[0].strip(), fields[1].strip(), fields[2].strip()))
    if not rows:
        raise GateFailure(f"{EXPECTATIONS} declares no command topology")
    return sorted(rows)


# ---------------------------------------------------------------------------
# the decision, over one observation
# ---------------------------------------------------------------------------


def _rows(observations: dict[str, object], pass_index: str, kind: str) -> list[tuple[str, ...]]:
    replay = observations.get("replay") or []
    return [
        tuple(str(field) for field in row[1:])
        for row in replay
        if str(row[0]) == pass_index and str(row[1]) == kind
    ]


def _authored(transcript: list[tuple[str, str, str, str]], pass_index: str, kind: str) -> list[tuple[str, ...]]:
    return [row[1:] for row in transcript if row[0] == pass_index and row[1] == kind]


def decide(
    observations: dict[str, object], transcript: list[tuple[str, str, str, str]]
) -> dict[str, list[str]]:
    """Every check this gate owns, over one observation, as check id -> problems."""
    problems: dict[str, list[str]] = {name: [] for name in CHECKS}

    error = observations.get("replay_error")
    if error:
        problems["first-pass-converges"].append(f"the replay did not run: {error}")

    # Pass one is compared on its *mutations* only. Its probes belong to the
    # convergence check, and folding them in here would make one seeded defect
    # redden two checks, which is what makes a mutant unattributable.
    if _rows(observations, "1", "mutation") != _authored(transcript, "1", "mutation"):
        problems["first-pass-converges"].append(
            "pass one's acquisitions and installs differ from the authored transcript"
        )

    for index in ("2", "3"):
        observed = _rows(observations, index, "probe")
        if not observed:
            problems["probe-decides-convergence"].append(
                f"pass {index} reports converged without probing anything"
            )
        elif observed != _authored(transcript, index, "probe"):
            problems["probe-decides-convergence"].append(
                f"pass {index}'s post-condition probes differ from the authored transcript"
            )
        for row in _rows(observations, index, "mutation"):
            problems["second-pass-mutates-nothing"].append(
                f"pass {index} mutated: {' '.join(row)}"
            )

    for record in observations.get("ambient") or []:
        problems["no-ambient-path-lookup"].append(f"a tool was reached through PATH: {record}")

    guards = observations.get("guards") or {}
    if not guards.get("absent_bare_name_refused"):
        problems["invocation-absolute-path-only"].append("a bare command name was admitted")
    if not guards.get("existing_relative_path_refused"):
        problems["invocation-absolute-path-only"].append(
            "an existing relative path was admitted; the absolute-path guard is gone"
        )
    if not guards.get("absolute_path_admitted"):
        problems["invocation-absolute-path-only"].append("an absolute path was refused")

    surface = observations.get("surface") or {}
    observed_topology = sorted(tuple(str(field) for field in row) for row in surface.get("topology") or [])
    authored = oracle_topology()
    for row in authored:
        if row not in observed_topology:
            problems["surface-joins-the-oracle"].append(f"the oracle names {row[0]}, which the parser does not")
    for row in observed_topology:
        if row not in authored:
            problems["surface-joins-the-oracle"].append(f"the parser has {row[0]} ({row[1]}), which no oracle row names")

    if surface.get("unknown_verb_exit") == 0:
        problems["unknown-verb-refused"].append("an unknown verb was accepted")
    if "No such command" not in str(surface.get("unknown_verb_output", "")):
        problems["unknown-verb-refused"].append("an unknown verb did not produce `No such command`")

    listed = set(surface.get("listed_commands") or [])
    maintainer = set(surface.get("maintainer_commands") or [])
    if not maintainer:
        problems["maintainer-surface-hidden"].append("no command is declared maintainer-only")
    for name in sorted(listed & maintainer):
        problems["maintainer-surface-hidden"].append(f"{name} is listed to a consumer")

    if not surface.get("maintainer_resolves_in_checkout"):
        problems["maintainer-authority-rechecked"].append(
            "the maintainer command does not resolve inside the checkout"
        )
    if surface.get("maintainer_resolves_outside_checkout"):
        problems["maintainer-authority-rechecked"].append(
            "the maintainer command resolves outside a development checkout"
        )
    if not surface.get("maintainer_body_refuses_outside_checkout"):
        problems["maintainer-authority-rechecked"].append(
            "the maintainer body does not re-check its own authority"
        )

    if sorted(surface.get("coverage_omit") or []) != ["pb/__init__.py", "pb/test_all.py"]:
        problems["coverage-omit-list-exact"].append(
            f"the coverage omit list is {surface.get('coverage_omit')!r}, not the two unmeasurable files"
        )

    floor = observations.get("floor") or {}
    for problem in floor.get("plan_problems") or []:
        problems["floor-decidable-for-every-substrate"].append(str(problem))
    declared = floor.get("declared") or {}
    for substrate, identifiers in declared.items():
        if not identifiers:
            problems["floor-decidable-for-every-substrate"].append(f"{substrate} declares no floor row")

    identifiers = floor.get("identifiers") or []
    remedies = floor.get("remedies") or []
    if not identifiers:
        problems["floor-remedy-present"].append("a substrate this host is not produced no refusal")
    if len(remedies) != len(identifiers) or any(not str(remedy).strip() for remedy in remedies):
        problems["floor-remedy-present"].append("a refusal names nothing that clears it")

    if floor.get("cli_exit") == 0:
        problems["floor-refusal-halts-the-run"].append(
            "the run continued past a floor refusal and reported success"
        )

    return problems


# ---------------------------------------------------------------------------
# the seeded mutants
# ---------------------------------------------------------------------------


def load_mutants() -> list[dict[str, str]]:
    if not MUTANT_DIR.is_dir():
        raise GateFailure(f"the committed mutants under {rel(MUTANT_DIR)} are missing")
    registered = {row["mutant"] for row in mutant_registry.capability(MUTANT_CAPABILITY)}
    out: list[dict[str, str]] = []
    for path in sorted(MUTANT_DIR.glob("*.mutant")):
        record: dict[str, str] = {"name": path.stem, "statement": ""}
        for line in path.read_text(encoding="utf-8").splitlines():
            key, _, value = line.partition("=")
            if key == "statement":
                record["statement"] = (record["statement"] + " " + value).strip()
            elif key:
                record[key] = value
        for required in ("check", "operator", "mutation", "target"):
            if required not in record:
                raise GateFailure(f"{path.name}: no {required} field")
        if record["check"] not in CHECKS:
            raise GateFailure(f"{path.name}: targets {record['check']!r}, which this gate does not decide")
        if record["name"] not in registered:
            raise GateFailure(f"{path.name}: the one mutant registry does not name it")
        out.append(record)
    if len(out) != len(registered):
        raise GateFailure("the registry and the committed bodies disagree on the mutant set")
    if not out:
        raise GateFailure(f"{rel(MUTANT_DIR)} carries no mutant")
    return out


def materialize(destination: Path) -> Path:
    """A scratch copy of the distribution, beneath the build root.

    The two checkout markers are recreated as empty stand-ins. `pb` decides whether
    it is running from a source checkout by looking for them, so a scratch tree
    without them would make every mutant redden the maintainer-authority check as
    well as its own -- a collateral failure caused by the copy rather than by the
    mutation, which is exactly what makes a mutant unattributable.
    """
    if destination.exists():
        shutil.rmtree(destination)
    (destination / "pb").mkdir(parents=True)
    shutil.copytree(DISTRIBUTION / "pb", destination / "pb" / "pb")
    for name in ("pyproject.toml", "bootstrap_execution_envelope.json"):
        shutil.copy2(DISTRIBUTION / name, destination / "pb" / name)
    (destination / "amoebius.cabal").write_text("", encoding="utf-8")
    (destination / "DEVELOPMENT_PLAN").mkdir()
    return destination / "pb"


def apply(record: dict[str, str], scratch_pb: Path) -> None:
    """Apply one mutation to the scratch copy.

    Fields are separated by ` | ` and never by `:`, because the payloads are Python
    source and repository paths that carry colons of their own.
    """
    fields = [field.replace("\\n", "\n") for field in record["mutation"].split(" | ")]
    verb, arguments = fields[0].strip(), fields[1:]
    if verb != "replace":
        raise GateFailure(f"{record['name']}: unknown mutation verb {verb!r}")
    relative, old, new = arguments
    target = scratch_pb / Path(relative).relative_to("pb")
    text = target.read_text(encoding="utf-8")
    if old not in text:
        raise GateFailure(f"{record['name']}: {relative} does not contain the text it mutates")
    target.write_text(text.replace(old, new, 1), encoding="utf-8")


def mutant_side(
    python: Path, transcript: list[tuple[str, str, str, str]], clean: dict[str, list[str]]
) -> tuple[bool, list[dict[str, str]]]:
    print("\nmutant side — four seeded defects, each red at its own check\n")
    ok = True
    outcomes: list[dict[str, str]] = []
    for record in load_mutants():
        scratch = SCRATCH / "mutant" / record["name"]
        try:
            scratch_pb = materialize(scratch)
            apply(record, scratch_pb)
            observations = observe(python, scratch_pb, scratch / "run")
            verdict = decide(observations, transcript)
        except (GateFailure, OSError, json.JSONDecodeError) as error:
            print(f"  FAIL  {record['name']:32} could not be applied: {error}")
            outcomes.append({"name": record["name"], "status": "unapplied"})
            ok = False
            continue

        target = record["check"]
        reddened = sorted(name for name, found in verdict.items() if found)
        collateral = [name for name in reddened if name != target and not clean[name]]
        if target not in reddened:
            print(f"  FAIL  {record['name']:32} did not redden {target}")
            outcomes.append({"name": record["name"], "status": "survived"})
            ok = False
        elif collateral:
            print(f"  FAIL  {record['name']:32} also reddened {', '.join(collateral)}")
            outcomes.append({"name": record["name"], "status": "imprecise"})
            ok = False
        else:
            print(f"  ok    {record['name']:32} reddens {target} and no other check")
            outcomes.append({"name": record["name"], "status": "red"})
    return ok, outcomes


# ---------------------------------------------------------------------------
# the quality floor
# ---------------------------------------------------------------------------


def quality_floor(python: Path) -> list[str]:
    """`check_code` then `test_all`, fail-fast, before any assertion is exercised.

    A style or typing failure should cost seconds rather than a full run, and a
    distribution that does not type-check is not one whose assertions mean anything.
    """
    problems: list[str] = []
    for module, label in (("pb.check_code", "ruff, black, mypy, escape-hatch scan"), ("pb.test_all", "suite at 100% branch coverage")):
        result = subprocess.run(
            [str(python), "-m", module], cwd=DISTRIBUTION, text=True, capture_output=True, check=False
        )
        if result.returncode != 0:
            problems.append(f"{module} ({label}) failed:\n{result.stdout[-4000:]}{result.stderr[-2000:]}")
            return problems
        print(f"  ok    {module:20} {label}")
    return problems


# ---------------------------------------------------------------------------
# reporting
# ---------------------------------------------------------------------------


def report_side(name: str, verdict: dict[str, list[str]]) -> bool:
    print(f"\n{name} side — {SIDE_HEADLINE[name]}\n")
    ok = True
    for check in SIDE_CHECKS[name]:
        found = verdict[check]
        if found:
            ok = False
            for problem in found[:8]:
                print(f"  FAIL  {check:36} {problem}")
            if len(found) > 8:
                print(f"  FAIL  {check:36} … and {len(found) - 8} more")
        else:
            print(f"  ok    {check}")
    return ok


SURFACE_EVIDENCE = {f"check.{name}": name for name in CHECKS}


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=50, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="2", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    try:
        print("\nquality side — the floor, before any assertion is exercised\n")
        python = ensure_environment()
        transcript = authored_transcript()
        quality = quality_floor(python)
        if quality:
            for problem in quality:
                print(f"  FAIL  quality-floor-green {problem}")
            # A distribution that does not pass its own checks cannot be asked what
            # its assertions do, so the run stops here rather than reporting on it.
            results["quality"] = False
            return gate.report(results)
        observations = observe(python, DISTRIBUTION, SCRATCH / "authored")
        verdict = decide(observations, transcript)
    except (GateFailure, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"host-assert-cli-gate: FAIL: {error}", file=sys.stderr)
        return 1

    results["quality"] = report_side("quality", verdict)
    for name in ("topology", "replay", "floor"):
        results[name] = report_side(name, verdict)

    try:
        results["mutant"], outcomes = mutant_side(python, transcript, verdict)
    except GateFailure as error:
        print(f"host-assert-cli-gate: FAIL: {error}", file=sys.stderr)
        return 1

    # `commands` is enumerated from the *parser*, never from the oracle it is joined
    # against: an expectation that supplied its own subject would agree with itself.
    surface = observations.get("surface") or {}
    implemented = {
        "checks": set(CHECKS),
        "mutants": {record["name"] for record in load_mutants()},
        "commands": {str(row[0]) for row in surface.get("topology") or []},
    }
    rows = {name: ("clean" if not found else "findings") for name, found in verdict.items()}
    rows.update({f"mutant:{outcome['name']}": outcome["status"] for outcome in outcomes})
    evidence: dict[str, tuple[str, str] | None] = {
        surface: (check, "clean") for surface, check in SURFACE_EVIDENCE.items()
    }
    for outcome in outcomes:
        evidence[f"mutant.{outcome['name']}"] = (f"mutant:{outcome['name']}", "red")
    for command in implemented["commands"]:
        evidence[f"command.{command}"] = ("surface-joins-the-oracle", "clean")

    layers = {
        "Decision": "tested",
        "Protocol": "tested" if results["replay"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented=implemented,
        rows=rows,
        evidence=evidence,
        layers=layers,
        toolchain={"python": sys.version.split()[0], "distribution": "amoebius-pb 0.1.0"},
        dependencies={"click": "the closed command topology"},
        mutants=outcomes,
        observations={
            "transcript": "sha256:" + artifact_policy.digest(str(TRANSCRIPT)),
            "oracle": "sha256:" + artifact_policy.digest(str(ROOT / EXPECTATIONS)),
        },
    )


if __name__ == "__main__":
    raise SystemExit(main())
