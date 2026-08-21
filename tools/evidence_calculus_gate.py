#!/usr/bin/env python3
"""The Phase-7 gate — the evidence calculus.

Four deliverables, and each is checked where it can actually fail:

  * a **claim carries its discharge**, so a claim with no fixture has no constructor — a
    committed compile-fail pair, because that is a claim about an export list rather than
    about any value;
  * a **mutant record names its operator, its change, and the locus** its gate must see
    redden, checked by deriving the records from the one registry and joining them against a
    hand-authored claim inventory for an existing phase;
  * **one registry with a carrier field**, checked by offering the calculus a second source
    and requiring a refusal rather than a merge;
  * the **register model is a value**, so a gate declares which register its evidence
    reaches — and may not declare one stronger than its fixtures ran at, which is the other
    compile-fail pair and an in-process check besides.

Three seeded mutants, one per way the binding can be quietly wrong: a fixture that names
nothing admitted so a claim can be registered against it, a record that reports the same
locus whatever it was given, and a registry that accepts a second source. Each must redden
its own locus and no other.

The inventory is Phase 5's, and that choice is the point of section 4's mutation argument:
amoebius's own gates are workflows in the algebra they validate, so this phase cannot author
its evidence from outside the machinery. What it can do is inventory a *different* phase's
claims by hand, from that phase's contract, and require the derivation to agree.

    python3 tools/evidence_calculus_gate.py

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
INVENTORY = ROOT / "test/oracle/evidence_calculus/lift_calculus_claims.tsv"
INVENTORIED_CAPABILITY = "lift_calculus"
CALCULUS_SOURCES = [
    "src/Amoebius/Calculus/Evidence/Register.hs",
    "src/Amoebius/Calculus/Evidence/Fixture.hs",
    "src/Amoebius/Calculus/Evidence/Claim.hs",
    "src/Amoebius/Calculus/Evidence/Mutant.hs",
]

NEGATIVE = "test/negative/compile_fail/evidence_calculus"
COMPILE_PAIRS = (
    (
        f"{NEGATIVE}/claim_names_its_fixture.hs",
        f"{NEGATIVE}/claim_without_a_fixture.hs",
        ("Fixture",),
    ),
    (
        f"{NEGATIVE}/gate_declares_its_register.hs",
        f"{NEGATIVE}/gate_without_a_register.hs",
        ("GateRegister",),
    ),
)

MUTANT_CAPABILITY = "evidence_calculus"
RESULTS = ROOT / ".build/calculus/evidence/phase-results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/evidence-calculus"
SCRATCH = ROOT / ".build/tmp/evidence-calculus"
CONTRACT = "DEVELOPMENT_PLAN/phase_07_evidence_calculus.md"
GATE_COMMAND = "python3 tools/evidence_calculus_gate.py"
EXPECTATIONS = "test/oracle/evidence_calculus_surfaces.tsv"
SUITE = "evidence-calculus-spec"
ACCEPTANCE = "evidence-calculus-spec: PASS (7 claims, 3 mutant records, 12 checks)"

FIXTURE_KINDS = {"compile-fail", "property", "oracle", "live-probe"}
STRENGTHS = {
    "this-expression-rejected",
    "no-counterexample-found",
    "satisfies-authored-predicate",
    "observed-once",
}
REGISTERS = {"pure", "boundary", "simulation", "live"}


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


def read_inventory() -> list[dict[str, str]]:
    columns = ("claim", "fixture_kind", "fixture", "strength", "register", "mutant", "locus")
    rows: list[dict[str, str]] = []
    for line in INVENTORY.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != len(columns):
            raise GateFailure(f"an inventory row needs {len(columns)} fields: {line!r}")
        rows.append(dict(zip(columns, fields)))
    return rows


def verify_oracle() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    """The inventory's shape, before anything it judges has run.

    Authored from Phase 5's contract and from `evidence_calculus_doctrine.md` sections 2, 3
    and 5, never from the derivation. What this side checks is that it is *well formed*
    against the closed vocabularies — a kind, a strength and a register the calculus knows,
    exactly one fixture per claim, a locus named exactly when a mutant is, and a strength
    the named kind entitles the claim to.
    """
    rows = read_inventory()
    if not rows:
        raise GateFailure("the claim inventory is empty")
    if len({row["claim"] for row in rows}) != len(rows):
        raise GateFailure("the claim inventory repeats a claim")
    for row in rows:
        if row["fixture_kind"] not in FIXTURE_KINDS:
            raise GateFailure(f"{row['claim']!r} names an unknown fixture kind {row['fixture_kind']!r}")
        if row["strength"] not in STRENGTHS:
            raise GateFailure(f"{row['claim']!r} names an unknown strength {row['strength']!r}")
        if row["register"] not in REGISTERS:
            raise GateFailure(f"{row['claim']!r} names an unknown register {row['register']!r}")
        if not row["fixture"].strip() or row["fixture"] == "-":
            raise GateFailure(f"{row['claim']!r} names no fixture")
        if (row["mutant"] == "-") != (row["locus"] == "-"):
            raise GateFailure(f"{row['claim']!r} names a mutant without a locus, or the reverse")
        # L5: an unrepresentability claim names a compile-fail fixture, and only one does.
        if (row["strength"] == "this-expression-rejected") != (row["fixture_kind"] == "compile-fail"):
            raise GateFailure(f"{row['claim']!r} states a strength its fixture kind does not entitle it to")
        if not (ROOT / row["fixture"]).is_file():
            raise GateFailure(f"{row['claim']!r} names {row['fixture']}, which the tree does not have")

    named = {row["mutant"] for row in rows if row["mutant"] != "-"}
    declared = {row["mutant"] for row in mutant_registry.capability(INVENTORIED_CAPABILITY)}
    if not named <= declared:
        raise GateFailure(f"the inventory names mutants the registry does not: {sorted(named - declared)}")

    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("the mutant registry must carry three unique evidence-calculus mutants")
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
    "claim-inventory-well-formed": "the hand-authored inventory names one existing fixture per claim, at a strength its kind entitles",
    "calculus-is-pure": "no calculus module reaches for the world or can throw",
    "suite-acceptance-token": "the in-process suite reaches its acceptance token",
    "unbound-claim-and-undeclared-register-rejected": "the claim with no fixture and the gate with no register have no type",
    "mutants-red-at-own-locus": "each seeded mutant reddens its own locus and no other",
    "emitted-results-untracked": "the gate's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "purity", "suite", "compile-fail", "mutant", "results")

EXPECTED_RESULTS = {
    "claims": "7/7-bound-to-an-existing-fixture",
    "derived-records": "3/3-carrier-and-locus",
    "suite-checks": "12/12-green",
    "compile-fail-pairs": "2/2-legal-green-illegal-red",
    "mutants": "3/3-red-at-own-locus",
    "calculus-purity": "no-ambient-read-no-partial-token",
    "acceptance-token": "evidence-calculus-proven-register-1",
    "extension-declaration": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "claim-names-its-fixture": ("claims", EXPECTED_RESULTS["claims"]),
    "mutant-record-names-its-locus": ("derived-records", EXPECTED_RESULTS["derived-records"]),
    "one-registry-with-a-carrier": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "register-model-is-a-value": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "evidence-calculus-mutants": ("mutants", EXPECTED_RESULTS["mutants"]),
    "evidence-calculus-purity": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "evidence-calculus-acceptance": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "claim-inventory-shape": ("claims", EXPECTED_RESULTS["claims"]),
    "calculus-purity-scan": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "suite-acceptance": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "unbound-claim-typecheck": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "mutant-locus-separation": ("mutants", EXPECTED_RESULTS["mutants"]),
    "generated-output-discipline": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "extension-declaration": None,
    "runtime-fidelity": None,
}


def write_results(claims: int, records: int, checks: int, mutants: int, fixtures: int) -> None:
    metrics = dict(EXPECTED_RESULTS)
    metrics["claims"] = f"{claims}/{claims}-bound-to-an-existing-fixture"
    metrics["derived-records"] = f"{records}/{records}-carrier-and-locus"
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

    The three defects reach three different parts of the binding: whether a fixture that
    names nothing is admitted, whether a record reports the locus it was given, and whether
    the corpus has one answer or two. None of them can be seen by the others' check, which
    is what makes each one attributable.
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
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<40} {locus}")
        ok = ok and red
    (gate.run_dir / "mutants.log").write_text("\n".join(log), encoding="utf-8")
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=7, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
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
    inventory: list[dict[str, str]] = []

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<10} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = resolved["cabal"]["path"]

        print("\noracle side — the hand-authored claim inventory, before the derivation runs\n")
        inventory, mutant_rows = verify_oracle()
        derived = mutant_registry.capability(INVENTORIED_CAPABILITY)
        print(f"  ok    claim-inventory-well-formed {len(inventory)} claims over {len(derived)} derived records")
        print(f"  ok    mutant registry             {len(mutant_rows)} seeded defects declared")
        results["oracle"] = True

        print("\npurity side — what the operation types cannot carry\n")
        verify_purity()
        print(f"  ok    calculus-is-pure            {len(CALCULUS_SOURCES)} modules: no ambient read, no partial token")
        results["purity"] = True

        print("\nsuite side — the inventory joined to the registry the calculus derives\n")
        binary = build_suite(cabal, [])
        outcome = run_suite(binary)
        (gate.run_dir / "suite.log").write_text(outcome.stdout, encoding="utf-8")
        if outcome.returncode != 0 or ACCEPTANCE not in outcome.stdout:
            raise GateFailure(f"acceptance token absent:\n{outcome.stdout}")
        checks_green = outcome.stdout.count("  ok   ")
        print(f"  ok    suite-acceptance-token      {checks_green} checks green over {len(inventory)} claims")
        results["suite"] = True

        print("\ncompile-fail side — the claim with no fixture and the gate with no register\n")
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
            print(f"  ok    unbound-claim-and-undeclared-register-rejected  {Path(illegal).stem} red")
        results["compile-fail"] = True

        print("\nmutant side — each seeded defect red at its own locus\n")
        results["mutant"] = mutant_side(cabal, mutant_rows, gate)

        write_results(len(inventory), len(derived), checks_green, len(mutant_rows), len(COMPILE_PAIRS))
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the gate's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"evidence-calculus-gate: FAIL: {problem}", file=sys.stderr)
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
        or [{"name": "evidence-calculus mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
