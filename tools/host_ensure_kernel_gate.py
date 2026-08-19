#!/usr/bin/env python3
"""The Phase-4 gate — the ensure algebra is typed data and the driver is probe-first.

Phase 4 makes one cohesive claim, and the gate runs it as six sides over one emission
of the host modules:

  totality    the host modules build under `-Werror`, and no `case` over `Substrate`,
              `Frame` or `HostTool` carries a wildcard arm
  plan        the plan rendered for all four catalogue members joins the authored
              oracle, both ways
  reconciler  the applicability column is the single statement of the set: the
              diagnostic renders from it, and an excluded substrate is refused
  replay      absent -> present -> present against a committed fake tool directory:
              pass one converges having issued exactly the authored argv, and passes
              two and three mutate nothing
  lift        one step list, three contexts, differing only in the prefix the fold
              emits, with every inner command a guest name
  mutant      five committed seeded defects, each red at its own check and no other

The independent oracle is deliberately **not this phase's code**:
`test/oracle/host_ensure_plans.tsv` and the three fixtures under
`test/fixture/host_ensure_kernel/` are authored from `substrate_doctrine.md` sections
3, 3.1, 4 and 6 -- which root each substrate has, which order the steps run in, and who
supplies the container engine. None is captured from a run.

    python3 tools/host_ensure_kernel_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import mutant_registry  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

GATE_COMMAND = "python3 tools/host_ensure_kernel_gate.py"
CONTRACT = "DEVELOPMENT_PLAN/phase_04_host_ensure_kernel.md"
EXPECTATIONS = "test/oracle/host_ensure_kernel_surfaces.tsv"

PLAN_ORACLE = ROOT / "test/oracle/host_ensure_plans.tsv"
FIXTURES = ROOT / "test/fixture/host_ensure_kernel"
MUTANT_DIR = ROOT / "test/mutant/host_ensure_kernel"
MUTANT_CAPABILITY = "host_ensure_kernel"
EMISSION = ROOT / ".build/host_ensure_kernel"
BUILDDIR = ROOT / ".build/dist-newstyle/phase04"
STORE = ROOT / ".build/cabal-store"
SPEC = "amoebius:test:host-ensure-kernel-spec"

# The modules the totality claim is about.
HOST_MODULES = (
    "src/Amoebius/Host/Substrate.hs",
    "src/Amoebius/Host/Frame.hs",
    "src/Amoebius/Host/HostTool.hs",
    "src/Amoebius/Host/Ensure.hs",
    "src/Amoebius/Host/Reconciler.hs",
    "src/Amoebius/Host/Lift.hs",
    "src/Amoebius/Host/Context.hs",
    "src/Amoebius/Cluster/Bootstrap.hs",
)

# The constructors of the three closed types. An arm set mentioning one of these is a
# `case` over that type, which is what makes the wildcard rule decidable without a
# type checker.
CLOSED_CONSTRUCTORS = frozenset(
    {
        "LinuxCpu", "LinuxCuda", "Apple", "Windows",
        "NativeLinux", "LimaGuest", "Wsl2Guest",
        "PackageManagerRoot", "Ghcup", "Cabal", "Docker", "Kubectl", "Kind",
    }
)

SIDES = ("totality", "plan", "reconciler", "replay", "lift", "mutant")

CHECKS = {
    "build-total-under-werror": "the host modules compile with every warning an error",
    "no-wildcard-arm-in-host-modules": "no case over a closed host type has a default arm",
    "plans-join-the-oracle": "every substrate's rendered plan is the authored one",
    "table-applicability-matches-the-golden": "the applicability column is the golden's",
    "diagnostic-derives-from-applicability": "a diagnostic names exactly the set its row admits",
    "reconciler-refuses-excluded-substrate": "an excluded substrate is refused before any effect",
    "first-pass-converges": "the first pass reaches the requested tool",
    "first-pass-issues-the-authored-argv": "the first pass issues exactly the authored install argv",
    "second-pass-mutates-nothing": "the second and third passes carry no mutation",
    "lift-prefix-per-context": "the three contexts differ only in the prefix the fold emits",
    "lift-inner-command-is-a-guest-name": "a nested command is the guest's own bare name",
}

SIDE_CHECKS = {
    "totality": ("build-total-under-werror", "no-wildcard-arm-in-host-modules"),
    "plan": ("plans-join-the-oracle",),
    "reconciler": (
        "table-applicability-matches-the-golden",
        "diagnostic-derives-from-applicability",
        "reconciler-refuses-excluded-substrate",
    ),
    "replay": (
        "first-pass-converges",
        "first-pass-issues-the-authored-argv",
        "second-pass-mutates-nothing",
    ),
    "lift": ("lift-prefix-per-context", "lift-inner-command-is-a-guest-name"),
}

SIDE_HEADLINE = {
    "totality": "the closed algebra, proved by the compiler and by the absence of a default arm",
    "plan": "every catalogue member's plan against the authored oracle",
    "reconciler": "the applicability column as the single statement of the set",
    "replay": "absent -> present -> present against the committed fake tool directory",
    "lift": "one step list, three contexts",
}


class GateFailure(RuntimeError):
    """An authored input is missing — the gate cannot decide, rather than deciding no."""


def rel(path: Path) -> str:
    return os.path.relpath(str(path), str(ROOT))


def rows(path: Path) -> list[str]:
    """Authored rows, with the provenance comments stripped."""
    if not path.is_file():
        raise GateFailure(f"the authored input {rel(path)} is missing")
    kept = [
        line
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if not kept:
        raise GateFailure(f"{rel(path)} carries no row")
    return kept


def emitted(name: str) -> list[str]:
    path = EMISSION / name
    if not path.is_file():
        raise GateFailure(f"the spec emitted no {name}")
    return [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


# ---------------------------------------------------------------------------
# the compiler, and the arm scan it cannot do
# ---------------------------------------------------------------------------


def cabal_environment() -> dict[str, str]:
    """`tools/` on PATH, because `cabal.project`'s post-checkout hook resolves there."""
    environment = dict(os.environ)
    environment["PATH"] = str(ROOT / "tools") + os.pathsep + environment.get("PATH", "")
    return environment


def cabal(*arguments: str, flags: tuple[str, ...] = ()) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            "cabal", f"--store-dir={STORE}", *arguments,
            f"--builddir={BUILDDIR}", *[f"-f{flag}" for flag in flags],
        ],
        cwd=ROOT, env=cabal_environment(), text=True, capture_output=True, check=False,
    )


def build_under_werror() -> list[str]:
    """The compiler's own answer to exhaustiveness, with every warning an error."""
    result = cabal("build", "--ghc-options=-Werror", SPEC)
    if result.returncode == 0:
        return []
    return [(result.stdout + result.stderr)[-4000:]]


def wildcard_arms() -> list[str]:
    """Every `case` over a closed host type that carries a default arm.

    The compiler refuses a match that is *incomplete*; it says nothing about one made
    complete by a wildcard, which is the failure mode here — a wildcard makes an
    exhaustive-looking match silently absorb the next constructor. Decidable without a
    type checker because an arm set naming one of the closed constructors is, by
    construction, a case over that type.
    """
    findings: list[str] = []
    arm = re.compile(r"^(\s*)(_|[a-z][A-Za-z0-9_']*)\s*->")
    for relative in HOST_MODULES:
        path = ROOT / relative
        if not path.is_file():
            findings.append(f"{relative}: the module is missing")
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            if not re.search(r"\bcase\b.*\bof\b\s*$", line):
                continue
            block: list[str] = []
            for follower in lines[index + 1 :]:
                if follower.strip() and not follower.startswith(" "):
                    break
                block.append(follower)
                if re.match(r"^\s*(where|in)\b", follower):
                    break
            # Key on the arm *patterns*, never on a constructor appearing anywhere in
            # the block: `classify` cases over a `String` whose arms *produce*
            # `Substrate` values, and a block-wide scan would read that as a case over
            # `Substrate` and refuse its legitimate catch-all.
            patterns = [
                follower.split("->")[0].strip()
                for follower in block
                if "->" in follower
            ]
            heads = {pattern.split()[0] for pattern in patterns if pattern.split()}
            if not (CLOSED_CONSTRUCTORS & heads):
                continue
            for follower in block:
                match = arm.match(follower)
                if match and match.group(2) != "otherwise":
                    findings.append(
                        f"{relative}:{index + 1}: a case over a closed host type has the default arm"
                        f" {follower.strip()!r}"
                    )
    return findings


# ---------------------------------------------------------------------------
# the decision, over one emission
# ---------------------------------------------------------------------------


def pass_rows(replay: list[str], index: str, kind: str) -> list[str]:
    out: list[str] = []
    for line in replay:
        fields = line.split("\t")
        if len(fields) >= 3 and fields[0] == index and fields[1] == kind:
            out.append("\t".join(fields[2:]))
    return out


def decide() -> dict[str, list[str]]:
    """Every check this gate owns, over one emission, as check id -> problems."""
    problems: dict[str, list[str]] = {name: [] for name in CHECKS}

    if emitted("plans.tsv") != rows(PLAN_ORACLE):
        authored = set(rows(PLAN_ORACLE))
        observed = set(emitted("plans.tsv"))
        for extra in sorted(observed - authored):
            problems["plans-join-the-oracle"].append(f"the plan carries {extra!r}, which no oracle row names")
        for missing in sorted(authored - observed):
            problems["plans-join-the-oracle"].append(f"the oracle names {missing!r}, which no plan renders")
        if observed == authored:
            problems["plans-join-the-oracle"].append("the plan and the oracle differ in order")

    golden = [line for line in rows(FIXTURES / "reconciler_table.tsv") if line.startswith("applies\t")]
    observed_applies = [line for line in emitted("table.tsv") if line.startswith("applies\t")]
    if observed_applies != golden:
        problems["table-applicability-matches-the-golden"].append(
            "the applicability column differs from the golden"
        )

    for line in emitted("refusal.tsv"):
        fields = line.split("\t")
        if len(fields) < 5:
            continue
        name, substrate, outcome, diagnostic = fields[0], fields[1], fields[2], fields[4]
        declared = next((row.split("\t")[2] for row in golden if row.split("\t")[1] == name), "")
        wanted = ", ".join(declared.split(","))
        # Exact, not substring: a diagnostic naming a superset passes a substring test
        # while describing substrates its row does not admit, which is the drift.
        named = diagnostic.partition("applies to ")[2].partition(";")[0]
        if named != wanted:
            problems["diagnostic-derives-from-applicability"].append(
                f"{name} on {substrate} names {named!r}, not its applicability column {wanted!r}"
            )
        if outcome == "refused" and substrate in declared.split(","):
            problems["reconciler-refuses-excluded-substrate"].append(
                f"{name} refused {substrate}, which its own column admits"
            )
        if outcome == "admitted" and substrate not in declared.split(","):
            problems["reconciler-refuses-excluded-substrate"].append(
                f"{name} admitted {substrate}, which its own column excludes"
            )
    refused = [line for line in emitted("refusal.tsv") if line.split("\t")[2:3] == ["refused"]]
    if not refused:
        problems["reconciler-refuses-excluded-substrate"].append(
            "no reconciler refused any substrate, so the refusal path never ran"
        )

    replay = emitted("replay.tsv")
    authored_replay = rows(FIXTURES / "replay_transcript.tsv")
    for index in ("1", "2", "3"):
        verdicts = pass_rows(replay, index, "converged")
        if not any(row.startswith("converged") for row in verdicts):
            problems["first-pass-converges"].append(f"pass {index} did not converge: {verdicts}")
    if pass_rows(replay, "1", "mutation") != pass_rows(authored_replay, "1", "mutation"):
        problems["first-pass-issues-the-authored-argv"].append(
            "the first pass's install argv differs from the authored transcript"
        )
    for index in ("2", "3"):
        for row in pass_rows(replay, index, "mutation"):
            problems["second-pass-mutates-nothing"].append(f"pass {index} mutated: {row}")

    lift = emitted("lift.tsv")
    authored_lift = rows(FIXTURES / "lift_argv.tsv")
    if lift != authored_lift:
        problems["lift-prefix-per-context"].append("the lifted argv differs from the authored golden")
    by_context: dict[str, list[str]] = {}
    for line in lift:
        context, _, argv = line.partition("\t")
        by_context.setdefault(context, []).append(argv)
    for context, argvs in sorted(by_context.items()):
        for argv in argvs:
            head = argv.split()[0] if argv.split() else ""
            if not head.startswith("/"):
                problems["lift-prefix-per-context"].append(
                    f"{context}: the outermost tool {head!r} is not an absolute path"
                )
        if context != "on-host":
            for argv in argvs:
                nested = argv.split()
                if len(nested) > 1 and nested[-len(nested) + 1 :] and any(
                    part.startswith("/") for part in nested[1:]
                ):
                    problems["lift-inner-command-is-a-guest-name"].append(
                        f"{context}: a nested command is an absolute host path: {argv}"
                    )
    return problems


# ---------------------------------------------------------------------------
# the seeded mutants
# ---------------------------------------------------------------------------


def load_mutants() -> list[dict[str, str]]:
    if not MUTANT_DIR.is_dir():
        raise GateFailure(f"the committed mutants under {rel(MUTANT_DIR)} are missing")
    registered = {row["mutant"]: row for row in mutant_registry.capability(MUTANT_CAPABILITY)}
    out: list[dict[str, str]] = []
    for path in sorted(MUTANT_DIR.glob("*.mutant")):
        record: dict[str, str] = {"name": path.stem, "statement": ""}
        for line in path.read_text(encoding="utf-8").splitlines():
            key, _, value = line.partition("=")
            if key == "statement":
                record["statement"] = (record["statement"] + " " + value).strip()
            elif key:
                record[key] = value
        for required in ("check", "operator", "target"):
            if required not in record:
                raise GateFailure(f"{path.name}: no {required} field")
        if record["check"] not in CHECKS:
            raise GateFailure(f"{path.name}: targets {record['check']!r}, which this gate does not decide")
        registry_row = registered.get(record["name"])
        if registry_row is None:
            raise GateFailure(f"{path.name}: the one mutant registry does not name it")
        if registry_row["flag"] == mutant_registry.ABSENT:
            raise GateFailure(f"{path.name}: the registry names no build flag to switch it on")
        record["flag"] = registry_row["flag"]
        out.append(record)
    if len(out) != len(registered):
        raise GateFailure("the registry and the committed bodies disagree on the mutant set")
    return out


def run_spec(flags: tuple[str, ...] = ()) -> None:
    built = cabal("build", SPEC, flags=flags)
    if built.returncode != 0:
        raise GateFailure(f"the spec did not build with {flags}:\n{built.stdout[-3000:]}{built.stderr[-2000:]}")
    ran = cabal("run", "-v0", SPEC, flags=flags)
    if ran.returncode != 0:
        raise GateFailure(f"the spec did not run with {flags}:\n{ran.stdout[-3000:]}{ran.stderr[-2000:]}")


def mutant_side(clean: dict[str, list[str]]) -> tuple[bool, list[dict[str, str]]]:
    print("\nmutant side — five seeded defects, each red at its own check\n")
    ok = True
    outcomes: list[dict[str, str]] = []
    for record in load_mutants():
        try:
            run_spec((record["flag"],))
            verdict = decide()
        except GateFailure as error:
            print(f"  FAIL  {record['name']:34} could not be exercised: {error}")
            outcomes.append({"name": record["name"], "status": "unapplied"})
            ok = False
            continue
        target = record["check"]
        reddened = sorted(name for name, found in verdict.items() if found)
        collateral = [name for name in reddened if name != target and not clean[name]]
        if target not in reddened:
            print(f"  FAIL  {record['name']:34} did not redden {target}")
            outcomes.append({"name": record["name"], "status": "survived"})
            ok = False
        elif collateral:
            print(f"  FAIL  {record['name']:34} also reddened {', '.join(collateral)}")
            outcomes.append({"name": record["name"], "status": "imprecise"})
            ok = False
        else:
            print(f"  ok    {record['name']:34} reddens {target} and no other check")
            outcomes.append({"name": record["name"], "status": "red"})
    # Restore the authored emission, so the run bundle records the tree as authored.
    run_spec()
    return ok, outcomes


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
                print(f"  FAIL  {check:38} {problem}")
            if len(found) > 8:
                print(f"  FAIL  {check:38} … and {len(found) - 8} more")
        else:
            print(f"  ok    {check}")
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=4, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="2", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    try:
        print("\ntotality side — the closed algebra\n")
        werror = build_under_werror()
        arms = wildcard_arms()
        run_spec()
        verdict = decide()
        verdict["build-total-under-werror"] = werror
        verdict["no-wildcard-arm-in-host-modules"] = arms
    except (GateFailure, OSError) as error:
        print(f"host-ensure-kernel-gate: FAIL: {error}", file=sys.stderr)
        return 1

    for name in SIDE_CHECKS:
        results[name] = report_side(name, verdict)

    try:
        results["mutant"], outcomes = mutant_side(verdict)
    except GateFailure as error:
        print(f"host-ensure-kernel-gate: FAIL: {error}", file=sys.stderr)
        return 1

    implemented = {
        "checks": set(CHECKS),
        "mutants": {record["name"] for record in load_mutants()},
        "substrates": {line.split("\t")[0] for line in emitted("plans.tsv")},
        "contexts": {line.split("\t")[0] for line in emitted("lift.tsv")},
    }
    rows_ = {name: ("clean" if not found else "findings") for name, found in verdict.items()}
    rows_.update({f"mutant:{outcome['name']}": outcome["status"] for outcome in outcomes})
    evidence: dict[str, tuple[str, str] | None] = {f"check.{name}": (name, "clean") for name in CHECKS}
    for outcome in outcomes:
        evidence[f"mutant.{outcome['name']}"] = (f"mutant:{outcome['name']}", "red")
    for substrate in implemented["substrates"]:
        evidence[f"plan.{substrate}"] = ("plans-join-the-oracle", "clean")
    for context in implemented["contexts"]:
        evidence[f"lift.{context}"] = ("lift-prefix-per-context", "clean")

    layers = {
        "Decision": "tested",
        "Protocol": "tested" if results["replay"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented=implemented,
        rows=rows_,
        evidence=evidence,
        layers=layers,
        toolchain={"ghc": "9.12.4", "cabal": "3.16.1.0"},
        dependencies={"amoebius": "lib:dsl-core"},
        mutants=outcomes,
        observations={
            "plan_oracle": "sha256:" + artifact_policy.digest(str(PLAN_ORACLE)),
            "replay_transcript": "sha256:" + artifact_policy.digest(str(FIXTURES / "replay_transcript.tsv")),
        },
    )


if __name__ == "__main__":
    raise SystemExit(main())
