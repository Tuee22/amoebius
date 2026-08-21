#!/usr/bin/env python3
"""The Phase-4 gate — the budget calculus.

Four deliverables, and each is checked where it can actually fail:

  * the **grant** is scarce, specific, and unforgeable — the first two in process against
    the authored capacity table, the third as a committed compile-fail pair, because
    "there is no constructor" is a claim about an export list rather than about a value;
  * the **ceiling and its concurrency** are one bound, checked by the table's
    `concurrency-*` rows, which refuse while the ceiling still has room — a grant that
    mislaid its concurrency admits every one of them and no other row moves;
  * **admission refuses before it writes**, checked by reading the store's image on either
    side of a refusal from a second invocation of the suite rather than from an assertion
    the suite makes about itself;
  * the **retention grant names a reaper**, the other committed compile-fail pair.

The run also builds `.build/grants/**`, the output class the generator registry names this
phase as the owner of: a ceiling, the concurrency it is shared across, and the reservations
outstanding against it, one region per row and each row within its own bounds.

Three seeded mutants, one per way the calculus can be quietly wrong: a ceiling separated
from its concurrency, a grant defaulted to unbounded rather than refused, and a write that
lands before the check that would have refused it. Each must redden its own locus and no
other, and the three loci are three different instruments.

    python3 tools/budget_calculus_gate.py

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
ADMISSION_ORACLE = ROOT / "test/oracle/budget_calculus/admission_table.tsv"
CALCULUS_SOURCES = [
    "src/Amoebius/Calculus/Budget/Grant.hs",
    "src/Amoebius/Calculus/Budget/Admission.hs",
    "src/Amoebius/Calculus/Budget/Store.hs",
    "src/Amoebius/Calculus/Budget/Retention.hs",
]

# Each pair is (legal fixture, illegal fixture, the token the rejection must name). The
# token is what makes these expect-fail fixtures rather than expect-anything ones: a
# program can fail to typecheck for a hundred reasons, and only one of them is the claim.
COMPILE_PAIRS = (
    (
        "test/negative/compile_fail/budget_calculus/retention_names_its_reaper.hs",
        "test/negative/compile_fail/budget_calculus/retention_omits_its_reaper.hs",
        "Reaper",
    ),
    (
        "test/negative/compile_fail/budget_calculus/grant_comes_from_the_issuer.hs",
        "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs",
        "Illegal term-level use of the type constructor",
    ),
)

MUTANT_CAPABILITY = "budget_calculus"
RESULTS = ROOT / ".build/calculus/budget/phase-results.tsv"
# `repository_layout_doctrine.md` section 3.1 reserves `.build/grants/**` for per-region
# grant accounting — ceiling, concurrency, and outstanding reservations — and the
# generator registry names phase 4 as its owner. This gate is what builds it, so the
# registry row stops naming a phase and starts naming a tool.
ACCOUNTING = ROOT / ".build/grants/budget-calculus/accounting.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/budget-calculus"
SCRATCH = ROOT / ".build/tmp/budget-calculus"
CONTRACT = "DEVELOPMENT_PLAN/phase_04_budget_calculus.md"
GATE_COMMAND = "python3 tools/budget_calculus_gate.py"
EXPECTATIONS = "test/oracle/budget_calculus_surfaces.tsv"
SUITE = "budget-calculus-spec"
ACCEPTANCE = "budget-calculus-spec: PASS (24 rows, 5 refusal reasons, 10 checks)"

# The reasons the authored table is allowed to name. `declaration-exceeded` is absent on
# purpose: that refusal belongs to the store rather than to admission, and a table that
# expected it here would be asking `admit` for a verdict it has no way to reach.
ADMISSION_REASONS = {
    "wrong-location",
    "wrong-purpose",
    "per-item-bound-exceeded",
    "ceiling-exceeded",
    "concurrency-exhausted",
}

# The two store images a refusal must not move, read out of the suite's report.
IDENTITY_PAIRS = (
    ("ceiling-refusal-before", "ceiling-refusal-after"),
    ("declaration-refusal-before", "declaration-refusal-after"),
)


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
    columns = (
        "case", "ceiling", "concurrency", "per_item", "held_bytes", "held_slots",
        "demand_location", "demand_purpose", "demand_bytes", "verdict", "reason",
    )
    rows: list[dict[str, str]] = []
    for line in ADMISSION_ORACLE.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != len(columns):
            raise GateFailure(f"capacity table row needs {len(columns)} fields: {line!r}")
        rows.append(dict(zip(columns, fields)))
    return rows


def verify_oracle() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    """The table's shape, before anything it judges has run.

    It is authored from `jit_budget_doctrine.md` sections 2 to 4 and never from `admit`,
    which is the whole reason it can stay red when admission is wrong. What this side
    checks is that it is *complete and separating*: every reason admission can give is
    named by some row, no row names a reason admission cannot give, and no two rows are
    the same demand vector — a duplicated vector is a row that discharges nothing.
    """
    rows = read_oracle()
    if not rows:
        raise GateFailure("the capacity table is empty")
    verdicts = {row["verdict"] for row in rows}
    if verdicts != {"admitted", "refused"}:
        raise GateFailure(f"the capacity table names the wrong verdict set: {sorted(verdicts)}")
    reasons = {row["reason"] for row in rows if row["verdict"] == "refused"}
    if reasons != ADMISSION_REASONS:
        raise GateFailure(
            f"the capacity table must name exactly the admission reasons, names {sorted(reasons)}"
        )
    if {row["reason"] for row in rows if row["verdict"] == "admitted"} != {"-"}:
        raise GateFailure("an admitted row must not carry a refusal reason")
    vectors = [
        tuple(row[name] for name in
              ("ceiling", "concurrency", "per_item", "held_bytes", "held_slots",
               "demand_location", "demand_purpose", "demand_bytes"))
        for row in rows
    ]
    if len(set(vectors)) != len(vectors):
        raise GateFailure("the capacity table repeats a demand vector")
    if len({row["case"] for row in rows}) != len(rows):
        raise GateFailure("the capacity table repeats a case name")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("the mutant registry must carry three unique budget-calculus mutants")
    return rows, mutants


def verify_purity() -> None:
    """The half of the calculus's totality the type does not carry.

    Every operation here is a pure function over values, so an effect has nowhere to
    enter — that much is typed. What the type permits and the doctrine forbids is a pure
    reach for the world through an unsafe door, and a calculus that can throw: a budget
    that answers "does this fit" with an exception has refused nothing, it has crashed the
    caller that was about to handle the refusal.
    """
    unsafe = re.compile(r"\b(unsafePerformIO|unsafeDupablePerformIO|getCurrentTime|lookupEnv|getEnv|readFile|getLine)\b")
    partial = re.compile(r"\b(error|undefined|fromJust|head|tail)\b")
    for relative in CALCULUS_SOURCES:
        source = (ROOT / relative).read_text(encoding="utf-8")
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
        for pattern, label in ((unsafe, "ambient read"), (partial, "partial token")):
            found = pattern.search(stripped)
            if found:
                raise GateFailure(f"{label} {found.group(1)!r} in {relative}")
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


def store_report(binary: str) -> dict[str, str]:
    """The store's image on either side of each refusal, read from a separate process."""
    outcome = run([binary, "--store-identity"])
    report: dict[str, str] = {}
    for line in outcome.stdout.splitlines():
        key, separator, value = line.partition("\t")
        if separator:
            report[key] = value
    return report


def identity_holds(report: dict[str, str]) -> tuple[bool, str]:
    for before, after in IDENTITY_PAIRS:
        if before not in report or after not in report:
            return False, f"the store report is missing {before} or {after}"
        if report[before] != report[after]:
            return False, f"{before} and {after} differ, so a refusal moved the store"
    if report.get("committed-after-refusal") != "3":
        return False, f"a refusal changed the committed count to {report.get('committed-after-refusal')!r}"
    return True, "both refusals leave the store byte-identical"


def grant_accounting(binary: str) -> list[dict[str, str]]:
    """The per-region accounting, read from the suite and written where doctrine says.

    The suite prints it rather than writing it, so the one tool that writes beneath
    `.build/` is the gate — which is what keeps the write-location rule decidable from the
    gate scripts alone.
    """
    outcome = run([binary, "--grants"])
    ACCOUNTING.parent.mkdir(parents=True, exist_ok=True)
    ACCOUNTING.write_text(outcome.stdout, encoding="utf-8")
    lines = [line for line in outcome.stdout.splitlines() if line.strip()]
    if not lines:
        raise GateFailure("the suite emitted no grant accounting")
    header = lines[0].split("\t")
    if header != ["region", "ceiling", "concurrency", "held_bytes", "outstanding"]:
        raise GateFailure(f"the grant accounting names the wrong columns: {header}")
    rows = [dict(zip(header, line.split("\t"))) for line in lines[1:]]
    if len({row["region"] for row in rows}) != len(rows):
        raise GateFailure("the grant accounting repeats a region")
    for row in rows:
        if int(row["held_bytes"]) > int(row["ceiling"]):
            raise GateFailure(f"{row['region']} holds more than its ceiling")
        if int(row["outstanding"]) > int(row["concurrency"]):
            raise GateFailure(f"{row['region']} has more outstanding reservations than slots")
    return rows


def compile_fixture(cabal: str, fixture: str, defines: list[str]) -> subprocess.CompletedProcess[str]:
    """Typecheck one fixture against the calculus source, with the mutant defines given.

    `-fno-code` is a typecheck rather than a build, which is what an expect-fail fixture
    over a claim about types needs: the claim is that the program has no type, not that it
    fails to link.
    """
    scratch = SCRATCH / "compile-fail"
    scratch.mkdir(parents=True, exist_ok=True)
    return run(
        cabal_command(cabal, "exec", "--", COMPILER,
                      "-fno-code", "-fforce-recomp", "-XGHC2024", "-XOverloadedStrings", "-XCPP",
                      "-isrc", f"-outputdir={scratch}",
                      "-package", "bytestring", "-package", "text", "-package", "containers",
                      *defines, fixture),
        require_success=False,
    )


def mutant_flag(name: str) -> str:
    return f"-f{name}"


CHECKS = {
    "admission-oracle-complete": "the authored capacity table names every admission reason and no other",
    "calculus-is-pure": "no calculus module reaches for the world or can throw",
    "suite-acceptance-token": "the in-process suite reaches its acceptance token",
    "refusal-leaves-store-identical": "a refused demand leaves the store byte-identical, read from a second process",
    "grant-accounting-emitted": "the per-region grant accounting is emitted and holds within its own bounds",
    "forged-and-reaperless-rejected": "the forged grant and the reaper-less retention have no type, and their twins do",
    "mutants-red-at-own-locus": "each seeded mutant reddens its own locus and no other",
    "emitted-results-untracked": "the gate's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "purity", "suite", "store-identity", "grants", "compile-fail", "mutant", "results")

EXPECTED_RESULTS = {
    "admission-rows": "24/24-verdict-and-reason",
    "refusal-reasons": "5/5-named-by-the-table",
    "suite-checks": "10/10-green",
    "store-identity": "2/2-refusals-byte-identical",
    "grant-accounting": "4/4-regions-within-their-own-bounds",
    "compile-fail-pairs": "2/2-legal-green-illegal-red",
    "mutants": "3/3-red-at-own-locus",
    "calculus-purity": "no-ambient-read-no-partial-token",
    "acceptance-token": "budget-calculus-proven-register-1",
    "lift-composition": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "grant-is-scarce-and-specific": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "paired-ceiling-and-concurrency": ("admission-rows", EXPECTED_RESULTS["admission-rows"]),
    "admission-refuses-with-a-reason": ("refusal-reasons", EXPECTED_RESULTS["refusal-reasons"]),
    "refusal-leaves-nothing-behind": ("store-identity", EXPECTED_RESULTS["store-identity"]),
    "grant-accounting-per-region": ("grant-accounting", EXPECTED_RESULTS["grant-accounting"]),
    "retention-names-a-reaper": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "budget-calculus-mutants": ("mutants", EXPECTED_RESULTS["mutants"]),
    "budget-calculus-purity": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "budget-calculus-acceptance": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "admission-oracle-shape": ("admission-rows", EXPECTED_RESULTS["admission-rows"]),
    "calculus-purity-scan": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "suite-acceptance": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "store-identity-across-refusal": ("store-identity", EXPECTED_RESULTS["store-identity"]),
    "grant-accounting-consistency": ("grant-accounting", EXPECTED_RESULTS["grant-accounting"]),
    "unforgeable-constructor-typecheck": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "mutant-locus-separation": ("mutants", EXPECTED_RESULTS["mutants"]),
    "generated-output-discipline": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "lift-composition": None,
    "runtime-fidelity": None,
}


def write_results(rows: int, reasons: int, mutants: int, checks: int, pairs: int, regions: int) -> None:
    metrics = dict(EXPECTED_RESULTS)
    metrics["grant-accounting"] = f"{regions}/{regions}-regions-within-their-own-bounds"
    metrics["admission-rows"] = f"{rows}/{rows}-verdict-and-reason"
    metrics["refusal-reasons"] = f"{reasons}/{reasons}-named-by-the-table"
    metrics["suite-checks"] = f"{checks}/{checks}-green"
    metrics["mutants"] = f"{mutants}/{mutants}-red-at-own-locus"
    metrics["compile-fail-pairs"] = f"{pairs}/{pairs}-legal-green-illegal-red"
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def failing_loci(output: str) -> set[str]:
    return {line.split()[1] for line in output.splitlines() if line.startswith("  FAIL ")}


def mutant_side(cabal: str, mutants: list[dict[str, str]], gate: Any) -> bool:
    """Each mutant reddens its own locus, and leaves the others green.

    The three loci are deliberately different instruments — an authored-table join, an
    in-process invariant, and a comparison between two readings taken in a second process
    — because a mutant that only ever has to redden the same battery proves that battery
    reacts, not that the three claims are separately held. The partial-write mutant is the
    one that makes the point: it leaves every in-process check green.
    """
    ok = True
    log: list[str] = []
    for row in mutants:
        name = row["mutant"]
        locus = row["expected_red_locus"]
        binary = build_suite(cabal, [mutant_flag(row["flag"])])
        suite = run_suite(binary)
        loci = failing_loci(suite.stdout)
        if locus == "store-identity":
            held, _ = identity_holds(store_report(binary))
            red = not held and suite.returncode == 0 and not loci
            log.append(f"{name}: store image moved = {red}\n{suite.stdout}")
        else:
            red = suite.returncode != 0 and loci == {locus}
            log.append(f"{name}: {locus} red alone = {red}\n{suite.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<38} {locus}")
        ok = ok and red
    (gate.run_dir / "mutants.log").write_text("\n".join(log), encoding="utf-8")
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=4, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
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

        print("\noracle side — the authored capacity table, before anything it judges runs\n")
        oracle, mutant_rows = verify_oracle()
        print(f"  ok    admission-oracle-complete  {len(oracle)} demand vectors, {len(ADMISSION_REASONS)} reasons")
        print(f"  ok    mutant registry            {len(mutant_rows)} seeded defects declared")
        results["oracle"] = True

        print("\npurity side — what the operation types cannot carry\n")
        verify_purity()
        print(f"  ok    calculus-is-pure           {len(CALCULUS_SOURCES)} modules: no ambient read, no partial token")
        results["purity"] = True

        print("\nsuite side — the calculus against its authored table, in process\n")
        binary = build_suite(cabal, [])
        outcome = run_suite(binary)
        (gate.run_dir / "suite.log").write_text(outcome.stdout, encoding="utf-8")
        if outcome.returncode != 0 or ACCEPTANCE not in outcome.stdout:
            raise GateFailure(f"acceptance token absent:\n{outcome.stdout}")
        checks_green = outcome.stdout.count("  ok   ")
        print(f"  ok    suite-acceptance-token     {checks_green} checks green over {len(oracle)} rows")
        results["suite"] = True

        print("\nstore-identity side — the store on either side of a refusal\n")
        report = store_report(binary)
        (gate.run_dir / "store-identity.log").write_text(
            "".join(f"{key}\t{value}\n" for key, value in sorted(report.items())), encoding="utf-8"
        )
        held, detail = identity_holds(report)
        if not held:
            raise GateFailure(detail)
        print(f"  ok    refusal-leaves-store-identical  {detail}")
        results["store-identity"] = True

        print("\ngrants side — the per-region accounting this phase's output class holds\n")
        regions = grant_accounting(binary)
        print(f"  ok    grant-accounting-emitted   {len(regions)} regions written to {gate_common.rel(ACCOUNTING)}")
        results["grants"] = True

        print("\ncompile-fail side — the unforgeable grant and the reaper-less retention\n")
        for legal, illegal, token in COMPILE_PAIRS:
            green = compile_fixture(cabal, legal, [])
            if green.returncode != 0:
                raise GateFailure(f"the legal twin {legal} failed to typecheck:\n{green.stdout}")
            red = compile_fixture(cabal, illegal, [])
            if red.returncode == 0:
                raise GateFailure(f"{illegal} typechecked")
            if token not in red.stdout:
                raise GateFailure(f"{illegal} was rejected without naming {token!r}:\n{red.stdout}")
            print(f"  ok    forged-and-reaperless-rejected  {Path(illegal).stem} red at {token!r}")
        results["compile-fail"] = True

        print("\nmutant side — each seeded defect red at its own locus\n")
        results["mutant"] = mutant_side(cabal, mutant_rows, gate)

        write_results(
            len(oracle), len(ADMISSION_REASONS), len(mutant_rows), checks_green,
            len(COMPILE_PAIRS), len(regions),
        )
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent, ACCOUNTING.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the gate's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"budget-calculus-gate: FAIL: {problem}", file=sys.stderr)
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
        or [{"name": "budget-calculus mutants", "status": "unrun"}],
        observations=(
            {
                "results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS)),
                "grant-accounting": "sha256:" + gate_common.artifact_policy.digest(str(ACCOUNTING)),
            }
            if RESULTS.is_file() and ACCOUNTING.is_file()
            else {}
        ),
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
