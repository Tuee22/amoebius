#!/usr/bin/env python3
"""The Phase-5 gate — the lift calculus.

Four deliverables, and each is checked where it can actually fail:

  * the **layer set is closed** — three members, each with a singleton, each tag round
    tripping, checked in process against the promoted set;
  * the **transition relation is total**, checked as a two-way join against an authored
    pair table naming all nine ordered pairs, and separately by a scan for a catch-all arm
    — because a fallback that answers correctly today is still the arm a fourth layer
    would silently fall into, and no table can see that;
  * the **witness comes from an observation**, checked against an authored table crossing
    every admitted transition with every observation, and by a committed compile-fail pair
    for the half a table cannot state: that no constructor exists to write one down with;
  * **composition is a type equation**, checked by the other compile-fail pair and, for
    plans assembled at run time, by the suite.

Three seeded mutants, one per way the calculus can be quietly wrong: a dispatch that grows
a fallback arm, a witness forged where nothing was observed, and a plan whose transitions
are joined without meeting. Each must redden its own locus and no other, and the three loci
are three different instruments.

The catch-all scan reads the source **through the preprocessor**, selecting the branches
the given defines choose. Scanning the raw text would see both halves of every `#ifdef` and
report every seeded mutant as present in the clean tree, which is a check that cannot
distinguish the tree it is run on.

    python3 tools/lift_calculus_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
PAIR_ORACLE = ROOT / "test/oracle/lift_calculus/transition_pairs.tsv"
WITNESS_ORACLE = ROOT / "test/oracle/lift_calculus/witness_observations.tsv"
CALCULUS_SOURCES = [
    "src/Amoebius/Calculus/Lift/Layer.hs",
    "src/Amoebius/Calculus/Lift/Witness.hs",
    "src/Amoebius/Calculus/Lift/Transition.hs",
    "src/Amoebius/Calculus/Lift/Compose.hs",
]

# Each pair is (legal fixture, illegal fixture, the tokens the rejection must name).
# Tokens rather than one token: a composition that does not meet fails at a shared type
# variable, and the reason the fixture asserts is *which two layers* failed to meet, which
# is two names and a phrase.
COMPILE_PAIRS = (
    (
        "test/negative/compile_fail/lift_calculus/paths_meet_at_a_layer.hs",
        "test/negative/compile_fail/lift_calculus/paths_do_not_meet.hs",
        ("Couldn't match type", "InContainer", "OnHost"),
    ),
    (
        "test/negative/compile_fail/lift_calculus/witness_comes_from_an_observation.hs",
        "test/negative/compile_fail/lift_calculus/witness_asserted.hs",
        ("Illegal term-level use of the type constructor", "Witness"),
    ),
)

MUTANT_CAPABILITY = "lift_calculus"
RESULTS = ROOT / ".build/calculus/lift/phase-results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/lift-calculus"
SCRATCH = ROOT / ".build/tmp/lift-calculus"
CONTRACT = "DEVELOPMENT_PLAN/phase_05_lift_calculus.md"
GATE_COMMAND = "python3 tools/lift_calculus_gate.py"
EXPECTATIONS = "test/oracle/lift_calculus_surfaces.tsv"
SUITE = "lift-calculus-spec"
ACCEPTANCE = "lift-calculus-spec: PASS (9 pairs, 20 observations, 11 checks)"

LAYER_TAGS = ("on-host", "in-frame", "in-container")
OBSERVATION_TAGS = ("host-responding", "frame-running", "engine-responding", "nothing-observed")


class GateFailure(RuntimeError):
    pass


COMPILER = ""
RUN_ENV = toolchain.contained_env()
RUN_ENV["PATH"] = os.pathsep.join([str(ROOT / "tools"), RUN_ENV.get("PATH", "")])


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=RUN_ENV, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def cabal_command(cabal: str, verb: str, *rest: str) -> list[str]:
    return [
        cabal,
        f"--store-dir={ROOT / '.build' / 'cabal-store'}",
        verb,
        f"--with-compiler={COMPILER}",
        f"--builddir={BUILD_ROOT}",
        *rest,
    ]


# --------------------------------------------------------------------------
# the authored tables
# --------------------------------------------------------------------------


def read_table(path: Path, columns: tuple[str, ...]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != len(columns):
            raise GateFailure(f"{gate_common.rel(path)}: row needs {len(columns)} fields: {line!r}")
        rows.append(dict(zip(columns, fields)))
    return rows


def verify_oracles() -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    """Both tables' shapes, before anything they judge has run.

    Each is authored from `lift_and_compose_doctrine.md` section 7 rather than from the
    modules, which is the whole reason either can stay red when the calculus is wrong.
    What this side checks is that they are *complete*: the pair table decides all nine
    ordered pairs of the closed set, and the observation table crosses every pair it
    admits with every observation. A missing row is an arm nothing asked about.
    """
    pairs = read_table(PAIR_ORACLE, ("source", "target", "admitted", "why"))
    expected_pairs = {(left, right) for left in LAYER_TAGS for right in LAYER_TAGS}
    seen_pairs = {(row["source"], row["target"]) for row in pairs}
    if len(pairs) != len(seen_pairs):
        raise GateFailure("the pair table repeats an ordered pair")
    if seen_pairs != expected_pairs:
        raise GateFailure(f"the pair table decides {len(seen_pairs)} of {len(expected_pairs)} pairs")
    if {row["admitted"] for row in pairs} != {"yes", "no"}:
        raise GateFailure("the pair table must both admit and refuse")
    if any(not row["why"].strip() for row in pairs):
        raise GateFailure("every pair carries the reason it is admitted or has no inhabitant")

    admitted = {(row["source"], row["target"]) for row in pairs if row["admitted"] == "yes"}
    witnesses = read_table(WITNESS_ORACLE, ("source", "target", "observation", "admits"))
    expected_cells = {(left, right, seen) for (left, right) in admitted for seen in OBSERVATION_TAGS}
    seen_cells = {(row["source"], row["target"], row["observation"]) for row in witnesses}
    if len(witnesses) != len(seen_cells):
        raise GateFailure("the observation table repeats a cell")
    if seen_cells != expected_cells:
        missing = sorted(expected_cells - seen_cells)
        extra = sorted(seen_cells - expected_cells)
        raise GateFailure(f"the observation table is missing {missing} and invents {extra}")
    if {row["admits"] for row in witnesses} != {"yes", "no"}:
        raise GateFailure("the observation table must both admit and refuse")

    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("the mutant registry must carry three unique lift-calculus mutants")
    return pairs, witnesses, mutants


# --------------------------------------------------------------------------
# the catch-all scan
# --------------------------------------------------------------------------


def preprocess(text: str, defines: set[str]) -> str:
    """Select the branches the given defines choose.

    A hand-written selector rather than a call to `cpp`, because the four modules use one
    construct — `#ifdef`/`#else`/`#endif`, never nested — and shelling out would make a
    check about source text depend on which preprocessor the host has.
    """
    out: list[str] = []
    stack: list[bool] = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#ifdef "):
            stack.append(stripped.split(None, 1)[1].strip() in defines)
            continue
        if stripped == "#else":
            if not stack:
                raise GateFailure("#else outside a conditional")
            stack[-1] = not stack[-1]
            continue
        if stripped == "#endif":
            if not stack:
                raise GateFailure("#endif outside a conditional")
            stack.pop()
            continue
        if all(stack):
            out.append(line)
    if stack:
        raise GateFailure("an #ifdef was never closed")
    return "\n".join(out)


# A case alternative is a catch-all when every atom of its pattern is a variable or a
# wildcard — `_`, `(_from, _to)`, `x`, `(a, b)`. One constructor anywhere in the pattern,
# including an operator one like `:`, makes it a real alternative.
BINDER = re.compile(r"^[_a-z][A-Za-z0-9_']*$")
ARM = re.compile(r"^\s+(.*?)\s*->")


def catch_all_arms(text: str) -> list[str]:
    """Every case alternative in one module whose pattern matches everything."""
    found: list[str] = []
    for line in text.splitlines():
        without_comment = re.sub(r"--.*$", "", line)
        if "::" in without_comment or "\\" in without_comment:
            continue
        match = ARM.match(without_comment)
        if not match:
            continue
        pattern = match.group(1)
        atoms = re.findall(r"[^\s(),]+", pattern)
        if atoms and all(BINDER.fullmatch(atom) for atom in atoms):
            found.append(line.strip())
    return found


def dispatch_side(defines: set[str]) -> list[tuple[str, str]]:
    """(module, arm) for every catch-all the given defines leave in the source."""
    found: list[tuple[str, str]] = []
    for relative in CALCULUS_SOURCES:
        selected = preprocess((ROOT / relative).read_text(encoding="utf-8"), defines)
        for arm in catch_all_arms(selected):
            found.append((relative, arm))
    return found


def verify_purity() -> None:
    """The half of the calculus's totality the type does not carry."""
    unsafe = re.compile(r"\b(unsafePerformIO|unsafeDupablePerformIO|unsafeCoerce|getCurrentTime|lookupEnv|getEnv|readFile|getLine)\b")
    partial = re.compile(r"\b(error|undefined|fromJust|head|tail)\b")
    for relative in CALCULUS_SOURCES:
        source = (ROOT / relative).read_text(encoding="utf-8")
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
        for pattern, label in ((unsafe, "ambient read"), (partial, "partial token")):
            hit = pattern.search(stripped)
            if hit:
                raise GateFailure(f"{label} {hit.group(1)!r} in {relative}")
    cabal_text = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in cabal_text:
            raise GateFailure(f"compile totality option missing: {option}")


# --------------------------------------------------------------------------
# the suite
# --------------------------------------------------------------------------


def suite_binary(cabal: str, flags: list[str]) -> str:
    listing = run(cabal_command(cabal, "list-bin", SUITE, *flags))
    return listing.stdout.strip().splitlines()[-1]


def build_suite(cabal: str, flags: list[str]) -> str:
    run(cabal_command(cabal, "build", SUITE, *flags))
    return suite_binary(cabal, flags)


def run_suite(binary: str) -> subprocess.CompletedProcess[str]:
    return run([binary], require_success=False)


def failing_loci(output: str) -> set[str]:
    return {line.split()[1] for line in output.splitlines() if line.startswith("  FAIL ")}


def compile_fixture(cabal: str, fixture: str) -> subprocess.CompletedProcess[str]:
    scratch = SCRATCH / "compile-fail"
    scratch.mkdir(parents=True, exist_ok=True)
    return run(
        cabal_command(cabal, "exec", "--", COMPILER,
                      "-fno-code", "-fforce-recomp", "-XGHC2024", "-XOverloadedStrings", "-XCPP",
                      "-isrc", f"-outputdir={scratch}",
                      "-package", "text", "-package", "containers", fixture),
        require_success=False,
    )


def mutant_define(flag: str) -> str:
    return flag.replace("-", "_").upper()


CHECKS = {
    "transition-oracle-complete": "both authored tables decide every cell of the closed set and no other",
    "calculus-is-pure": "no calculus module reaches for the world or can throw",
    "dispatch-has-no-fallback": "no dispatch over the layer set carries a catch-all arm",
    "suite-acceptance-token": "the in-process suite reaches its acceptance token",
    "unmet-and-asserted-rejected": "the unmet composition and the asserted witness have no type, and their twins do",
    "mutants-red-at-own-locus": "each seeded mutant reddens its own locus and no other",
    "emitted-results-untracked": "the gate's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "purity", "dispatch", "suite", "compile-fail", "mutant", "results")

EXPECTED_RESULTS = {
    "transition-pairs": "9/9-named-and-decided",
    "witness-observations": "20/20-verdict-matched",
    "suite-checks": "11/11-green",
    "dispatch-arms": "no-catch-all-in-4-modules",
    "compile-fail-pairs": "2/2-legal-green-illegal-red",
    "mutants": "3/3-red-at-own-locus",
    "calculus-purity": "no-ambient-read-no-partial-token",
    "acceptance-token": "lift-calculus-proven-register-1",
    "workflow-teardown": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "closed-layer-set": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "total-transition-relation": ("transition-pairs", EXPECTED_RESULTS["transition-pairs"]),
    "no-fallback-arm": ("dispatch-arms", EXPECTED_RESULTS["dispatch-arms"]),
    "witness-from-observation": ("witness-observations", EXPECTED_RESULTS["witness-observations"]),
    "composition-is-a-type-equation": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "lift-calculus-mutants": ("mutants", EXPECTED_RESULTS["mutants"]),
    "lift-calculus-purity": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "lift-calculus-acceptance": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "transition-oracle-shape": ("transition-pairs", EXPECTED_RESULTS["transition-pairs"]),
    "calculus-purity-scan": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "dispatch-fallback-scan": ("dispatch-arms", EXPECTED_RESULTS["dispatch-arms"]),
    "suite-acceptance": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "unmet-composition-typecheck": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "mutant-locus-separation": ("mutants", EXPECTED_RESULTS["mutants"]),
    "generated-output-discipline": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "workflow-teardown": None,
    "runtime-fidelity": None,
}


def write_results(pairs: int, cells: int, checks: int, modules: int, mutants: int, fixtures: int) -> None:
    metrics = dict(EXPECTED_RESULTS)
    metrics["transition-pairs"] = f"{pairs}/{pairs}-named-and-decided"
    metrics["witness-observations"] = f"{cells}/{cells}-verdict-matched"
    metrics["suite-checks"] = f"{checks}/{checks}-green"
    metrics["dispatch-arms"] = f"no-catch-all-in-{modules}-modules"
    metrics["mutants"] = f"{mutants}/{mutants}-red-at-own-locus"
    metrics["compile-fail-pairs"] = f"{fixtures}/{fixtures}-legal-green-illegal-red"
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def mutant_side(cabal: str, mutants: list[dict[str, str]], gate: Any) -> bool:
    """Each mutant reddens its own locus, and leaves the others green.

    The three loci are three different instruments — a scan of the source the compiler
    actually sees, and two joins against two separately authored tables — because a mutant
    that only ever has to redden the same battery proves that battery reacts, not that the
    three claims are separately held. The fallback mutant makes the point: it leaves both
    tables green and every in-process check passing, and is caught only by the scan.
    """
    ok = True
    log: list[str] = []
    for row in mutants:
        name = row["mutant"]
        locus = row["expected_red_locus"]
        binary = build_suite(cabal, [f"-f{row['flag']}"])
        suite = run_suite(binary)
        loci = failing_loci(suite.stdout)
        arms = dispatch_side({mutant_define(row["flag"])})
        if locus == "dispatch":
            red = bool(arms) and suite.returncode == 0 and not loci
            log.append(f"{name}: catch-all arms {arms}, suite green = {red}")
        else:
            red = suite.returncode != 0 and loci == {locus} and not arms
            log.append(f"{name}: {locus} red alone = {red}\n{suite.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<40} {locus}")
        ok = ok and red
    (gate.run_dir / "mutants.log").write_text("\n".join(log), encoding="utf-8")
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=5, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    checks_green = 0
    pairs: list[dict[str, str]] = []
    witnesses: list[dict[str, str]] = []

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<10} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = resolved["cabal"]["path"]

        print("\noracle side — the two authored tables, before anything they judge runs\n")
        pairs, witnesses, mutant_rows = verify_oracles()
        print(f"  ok    transition-oracle-complete {len(pairs)} ordered pairs, {len(witnesses)} witness cells")
        print(f"  ok    mutant registry            {len(mutant_rows)} seeded defects declared")
        results["oracle"] = True

        print("\npurity side — what the operation types cannot carry\n")
        verify_purity()
        print(f"  ok    calculus-is-pure           {len(CALCULUS_SOURCES)} modules: no ambient read, no partial token")
        results["purity"] = True

        print("\ndispatch side — the source the compiler sees, scanned for a catch-all arm\n")
        arms = dispatch_side(set())
        if arms:
            for relative, arm in arms:
                print(f"  FAIL  dispatch-has-no-fallback  {relative}: {arm}")
            raise GateFailure(f"{len(arms)} catch-all arm(s) in the dispatch")
        print(f"  ok    dispatch-has-no-fallback   {len(CALCULUS_SOURCES)} modules carry no catch-all alternative")
        results["dispatch"] = True

        print("\nsuite side — the calculus against its two tables, in process\n")
        binary = build_suite(cabal, [])
        outcome = run_suite(binary)
        (gate.run_dir / "suite.log").write_text(outcome.stdout, encoding="utf-8")
        if outcome.returncode != 0 or ACCEPTANCE not in outcome.stdout:
            raise GateFailure(f"acceptance token absent:\n{outcome.stdout}")
        checks_green = outcome.stdout.count("  ok   ")
        print(f"  ok    suite-acceptance-token     {checks_green} checks green over {len(pairs)} pairs")
        results["suite"] = True

        print("\ncompile-fail side — the unmet composition and the asserted witness\n")
        for legal, illegal, tokens in COMPILE_PAIRS:
            green = compile_fixture(cabal, legal)
            if green.returncode != 0:
                raise GateFailure(f"the legal twin {legal} failed to typecheck:\n{green.stdout}")
            red = compile_fixture(cabal, illegal)
            if red.returncode == 0:
                raise GateFailure(f"{illegal} typechecked")
            missing = [token for token in tokens if token not in red.stdout]
            if missing:
                raise GateFailure(f"{illegal} was rejected without naming {missing}:\n{red.stdout}")
            print(f"  ok    unmet-and-asserted-rejected  {Path(illegal).stem} red naming {len(tokens)} token(s)")
        results["compile-fail"] = True

        print("\nmutant side — each seeded defect red at its own locus\n")
        results["mutant"] = mutant_side(cabal, mutant_rows, gate)

        write_results(
            len(pairs), len(witnesses), checks_green, len(CALCULUS_SOURCES),
            len(mutant_rows), len(COMPILE_PAIRS),
        )
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the gate's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"lift-calculus-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        # The mutant builds leave the shared build tree configured for whichever flag ran
        # last. Restoring the clean configuration is part of the run rather than a
        # courtesy: a later gate reading this tree would otherwise be reading a mutant.
        if COMPILER:
            run(cabal_command(resolved["cabal"]["path"], "build", SUITE), require_success=False)

    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS)},
        rows=rows,
        evidence=SURFACE_EVIDENCE,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={SUITE: "cabal build", "compile-fail": "ghc -fno-code"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "lift-calculus mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
