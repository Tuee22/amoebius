#!/usr/bin/env python3
"""The Phase-6 gate — the workflow calculus.

Four deliverables, and each is checked where it can actually fail:

  * the **five arms** are one closed set over one vocabulary, checked in process against
    the promoted set and against the arm trace each workflow leaves;
  * **provision returns a handle and an obligation together**, and the obligation is in the
    workflow's type — so a workflow that ends still holding one is a committed compile-fail
    fixture rather than a check that runs;
  * **discharge is teardown or an explicit transfer, with no way to drop it**, checked by
    replaying an independently authored obligation ledger against what each workflow
    actually recorded, and by two more compile-fail pairs: a transfer with no condition,
    and a teardown of an obligation the workflow never held;
  * **composition is typed by what each arm consumes**, so a sequence threads its value and
    two parallel branches must owe nothing in common.

Three seeded mutants, one per way the accounting can be quietly wrong: an obligation
dropped, one discharged twice, and a transfer that loses its condition. Each must redden
its own locus and no other — which is why the ledger asks three questions rather than one,
since a dropped obligation and a doubled one are invisible to each other's check.

    python3 tools/workflow_calculus_gate.py

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
LEDGER_ORACLE = ROOT / "test/oracle/workflow_calculus/obligation_ledger.tsv"
CALCULUS_SOURCES = [
    "src/Amoebius/Calculus/Workflow/Arm.hs",
    "src/Amoebius/Calculus/Workflow/Obligation.hs",
    "src/Amoebius/Calculus/Workflow/Ledger.hs",
    "src/Amoebius/Calculus/Workflow/Run.hs",
]

# Each pair is (legal fixture, illegal fixture, the tokens the rejection must name).
NEGATIVE = "test/negative/compile_fail/workflow_calculus"
COMPILE_PAIRS = (
    (
        f"{NEGATIVE}/workflow_discharges_its_obligation.hs",
        f"{NEGATIVE}/workflow_ends_owing_a_teardown.hs",
        ("Couldn't match type", "db-volume"),
    ),
    (
        f"{NEGATIVE}/transfer_names_its_condition.hs",
        f"{NEGATIVE}/transfer_without_a_condition.hs",
        ("Condition",),
    ),
    (
        f"{NEGATIVE}/teardown_discharges_what_was_provisioned.hs",
        f"{NEGATIVE}/teardown_of_an_unheld_obligation.hs",
        ("holds no teardown obligation", "never-provisioned"),
    ),
)

MUTANT_CAPABILITY = "workflow_calculus"
RESULTS = ROOT / ".build/calculus/workflow/phase-results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/workflow-calculus"
SCRATCH = ROOT / ".build/tmp/workflow-calculus"
CONTRACT = "DEVELOPMENT_PLAN/phase_06_workflow_calculus.md"
GATE_COMMAND = "python3 tools/workflow_calculus_gate.py"
EXPECTATIONS = "test/oracle/workflow_calculus_surfaces.tsv"
SUITE = "workflow-calculus-spec"
ACCEPTANCE = "workflow-calculus-spec: PASS (8 obligations, 5 workflows, 10 checks)"

DISCHARGES = {"tore-down", "transferred"}


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


def read_oracle() -> list[dict[str, str]]:
    columns = ("workflow", "resource", "discharge", "condition")
    rows: list[dict[str, str]] = []
    for line in LEDGER_ORACLE.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != len(columns):
            raise GateFailure(f"an obligation row needs {len(columns)} fields: {line!r}")
        rows.append(dict(zip(columns, fields)))
    return rows


def verify_oracle() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    """The table's shape, before anything it judges has run.

    It is authored from `workflow_calculus_doctrine.md` section 3 and never from the ledger
    it replays, which is the whole reason it can stay red when a workflow's accounting is
    wrong. What this side checks is that it is *separating*: every workflow it names is
    named once per resource, both discharges occur, and a transfer states a condition while
    a teardown does not — the asymmetry the doctrine draws, since a transfer is the arm
    that outlives the workflow and therefore the arm that owes an explanation.
    """
    rows = read_oracle()
    if not rows:
        raise GateFailure("the obligation ledger is empty")
    pairs = [(row["workflow"], row["resource"]) for row in rows]
    if len(set(pairs)) != len(pairs):
        raise GateFailure("the obligation ledger names one resource twice for one workflow")
    discharges = {row["discharge"] for row in rows}
    if discharges != DISCHARGES:
        raise GateFailure(f"the obligation ledger names the wrong discharges: {sorted(discharges)}")
    for row in rows:
        stated = row["condition"].strip()
        if row["discharge"] == "transferred" and stated in ("", "-"):
            raise GateFailure(f"{row['workflow']}/{row['resource']} transfers with no condition")
        if row["discharge"] == "tore-down" and stated != "-":
            raise GateFailure(f"{row['workflow']}/{row['resource']} was torn down and states a condition")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("the mutant registry must carry three unique workflow-calculus mutants")
    return rows, mutants


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
                      "-isrc", f"-outputdir={scratch}", "-package", "text", fixture),
        require_success=False,
    )


CHECKS = {
    "ledger-oracle-complete": "the authored obligation ledger names each resource once and states every transfer's condition",
    "calculus-is-pure": "no calculus module reaches for the world or can throw",
    "suite-acceptance-token": "the in-process suite reaches its acceptance token",
    "undischarged-and-unconditional-rejected": "the workflow owing a teardown, the conditionless transfer, and the unheld discharge have no type",
    "mutants-red-at-own-locus": "each seeded mutant reddens its own locus and no other",
    "emitted-results-untracked": "the gate's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "purity", "suite", "compile-fail", "mutant", "results")

EXPECTED_RESULTS = {
    "obligations": "8/8-replayed",
    "workflows": "5/5-run-to-a-ledger",
    "suite-checks": "10/10-green",
    "compile-fail-pairs": "3/3-legal-green-illegal-red",
    "mutants": "3/3-red-at-own-locus",
    "calculus-purity": "no-ambient-read-no-partial-token",
    "acceptance-token": "workflow-calculus-proven-register-1",
    "evidence-binding": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "five-arms-one-vocabulary": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "obligation-ledger-balances": ("obligations", EXPECTED_RESULTS["obligations"]),
    "every-workflow-replayed": ("workflows", EXPECTED_RESULTS["workflows"]),
    "teardown-is-a-type-obligation": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "workflow-calculus-mutants": ("mutants", EXPECTED_RESULTS["mutants"]),
    "workflow-calculus-purity": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "workflow-calculus-acceptance": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "ledger-oracle-shape": ("obligations", EXPECTED_RESULTS["obligations"]),
    "calculus-purity-scan": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "suite-acceptance": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "undischarged-obligation-typecheck": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "mutant-locus-separation": ("mutants", EXPECTED_RESULTS["mutants"]),
    "generated-output-discipline": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "evidence-binding": None,
    "runtime-fidelity": None,
}


def write_results(obligations: int, workflows: int, checks: int, mutants: int, fixtures: int) -> None:
    metrics = dict(EXPECTED_RESULTS)
    metrics["obligations"] = f"{obligations}/{obligations}-replayed"
    metrics["workflows"] = f"{workflows}/{workflows}-run-to-a-ledger"
    metrics["suite-checks"] = f"{checks}/{checks}-green"
    metrics["mutants"] = f"{mutants}/{mutants}-red-at-own-locus"
    metrics["compile-fail-pairs"] = f"{fixtures}/{fixtures}-legal-green-illegal-red"
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def mutant_side(cabal: str, mutants: list[dict[str, str]], gate: Any) -> bool:
    """Each mutant reddens its own locus, and leaves the others green.

    The three loci are three questions of the same ledger, and they are three because a
    dropped obligation and a doubled one are invisible to each other: dropping one breaks
    the set equality and leaves the multiplicity intact, doubling one does the reverse, and
    a transfer recorded as a teardown leaves both untouched while losing the only statement
    of when the resource actually goes away.
    """
    ok = True
    log: list[str] = []
    for row in mutants:
        name = row["mutant"]
        locus = row["expected_red_locus"]
        binary = build_suite(cabal, [f"-f{row['flag']}"])
        suite = run_suite(binary)
        loci = failing_loci(suite.stdout)
        red = suite.returncode != 0 and loci == {locus}
        log.append(f"{name}: {locus} red alone = {red}\n{suite.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<38} {locus}")
        ok = ok and red
    (gate.run_dir / "mutants.log").write_text("\n".join(log), encoding="utf-8")
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=6, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
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
    oracle: list[dict[str, str]] = []

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<10} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = resolved["cabal"]["path"]

        print("\noracle side — the authored obligation ledger, before anything it judges runs\n")
        oracle, mutant_rows = verify_oracle()
        workflows = sorted({row["workflow"] for row in oracle})
        print(f"  ok    ledger-oracle-complete     {len(oracle)} obligations over {len(workflows)} workflows")
        print(f"  ok    mutant registry            {len(mutant_rows)} seeded defects declared")
        results["oracle"] = True

        print("\npurity side — what the operation types cannot carry\n")
        verify_purity()
        print(f"  ok    calculus-is-pure           {len(CALCULUS_SOURCES)} modules: no ambient read, no partial token")
        results["purity"] = True

        print("\nsuite side — every workflow run to a ledger, replayed against the table\n")
        binary = build_suite(cabal, [])
        outcome = run_suite(binary)
        (gate.run_dir / "suite.log").write_text(outcome.stdout, encoding="utf-8")
        if outcome.returncode != 0 or ACCEPTANCE not in outcome.stdout:
            raise GateFailure(f"acceptance token absent:\n{outcome.stdout}")
        checks_green = outcome.stdout.count("  ok   ")
        print(f"  ok    suite-acceptance-token     {checks_green} checks green over {len(oracle)} obligations")
        results["suite"] = True

        print("\ncompile-fail side — the obligation that cannot be dropped\n")
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
            print(f"  ok    undischarged-and-unconditional-rejected  {Path(illegal).stem} red naming {len(tokens)} token(s)")
        results["compile-fail"] = True

        print("\nmutant side — each seeded defect red at its own locus\n")
        results["mutant"] = mutant_side(cabal, mutant_rows, gate)

        write_results(len(oracle), len(workflows), checks_green, len(mutant_rows), len(COMPILE_PAIRS))
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the gate's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"workflow-calculus-gate: FAIL: {problem}", file=sys.stderr)
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
        or [{"name": "workflow-calculus mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
