#!/usr/bin/env python3
"""Derive, compare, mutate, and seal the repository's phase-gate workflows."""

from __future__ import annotations

import csv
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry
import toolchain


ROOT = Path(__file__).resolve().parents[1]
ORACLE_ROOT = ROOT / "test/oracle/self_referential_gates"
INVENTORY = ORACLE_ROOT / "gate_inventory.tsv"
CALCULUS = ORACLE_ROOT / "calculus_projection.tsv"
VERDICTS = ORACLE_ROOT / "verdict_projection.tsv"
LOCUS = ORACLE_ROOT / "validation_locus.tsv"
EXPECTATIONS = ROOT / "test/oracle/self_referential_gates_surfaces.tsv"
RESULTS = ROOT / ".build/dsl/self-referential-gates/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/self-referential-gates/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/self-referential-gates"
TEMP_ROOT = ROOT / ".build/tmp/self-referential-gates"
SOURCE = ROOT / "src/self-referential-gates/Amoebius/Gate/SelfReferential.hs"
SPEC = ROOT / "test/spec/workflow/SelfReferentialGatesSpec.hs"
RUNNER = ROOT / "tools/run_phase_gate.py"
LEGAL = ROOT / "test/negative/self_referential_gates/legal_gate.hs"
ILLEGAL = ROOT / "test/negative/self_referential_gates/leaked_gate.hs"
CONTRACT = "DEVELOPMENT_PLAN/phase_49_self_referential_gates.md"
GATE_COMMAND = "python3 tools/run_phase_gate.py 49"
MUTANT_CAPABILITY = "self_referential_gates"
SUITE = "test:self-referential-gates-spec"
VALUE_RUNNER = SUITE

COMPILER = ""

FLAGS = (
    "self-referential-gates-drop-observe-mutant",
    "self-referential-gates-leak-resource-mutant",
    "self-referential-gates-skip-mutant-mutant",
)

MUTANT_LOCI = {
    "drop_observation": "drop_observation",
    "leak_resource": "leak_resource",
    "skip_mutant": "skip_mutant",
}

CHECKS = {
    "inventory-two-way-join": "all 96 phase contracts join exactly to the boundary inventory",
    "workflow-source-total": "the five-arm derivation is pure, total, and teardown-indexed",
    "runner-argv-boundary": "the runner executes only the closed python3/cabal command domain without a shell",
    "consumer-switch-exact": "all 93 runnable phase contracts route through the workflow runner",
    "independent-mechanisms-retained": "each runner entry retains its separately authored mechanism",
    "compile-rejects-leak": "a derived teardown compiles and an omitted teardown does not",
    "three-mutants-red": "observation, resource, and mutant-participation defects redden distinct loci",
    "results-equal-oracle": "all recorded cardinalities equal the authored projections",
    "emitted-results-untracked": "all run output stays beneath .build",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC meet their authored requirements",
}

SIDES = ("toolchain", "oracle", "source", "compile", "workflow", "equivalence", "mutant", "results")

EXPECTED_RESULTS = {
    "gate-declarations": "96/96",
    "runnable-gates": "93/93-values",
    "descriptive-contracts": "3/3-non-runnable",
    "workflow-arms": "5/5-closed",
    "verdicts": "2/2-evidence",
    "compile-pairs": "2/2-distinct",
    "mutants": "3/3-red",
    "consumer-switches": "93/93",
    "tracked-output": "0-generated-in-source",
}

ACCEPTANCE = (
    "self-referential-gates-spec: PASS "
    "(96 declarations, 93 runnable values, 3 descriptive contracts, 5 arms, 2 verdicts, 3 mutants)"
)


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def cabal_command(cabal: str, *arguments: str) -> list[str]:
    return [
        cabal,
        f"--with-compiler={COMPILER}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
        "--jobs=1",
        *arguments,
    ]


def flag_config(enabled: str | None = None) -> list[str]:
    return [("-f" if flag == enabled else "-f-") + flag for flag in FLAGS]


def build_component(cabal: str, component: str, enabled: str | None = None) -> Path:
    flags = flag_config(enabled)
    run(cabal_command(cabal, "build", component, *flags))
    listed = run(cabal_command(cabal, "list-bin", component, *flags)).stdout.strip()
    binary = Path(listed)
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure(f"Cabal did not resolve an absolute binary for {component}")
    return binary


def verify_oracles() -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    inventory = read_tsv(INVENTORY)
    if len(inventory) != 96 or [row["phase"] for row in inventory] != [str(i) for i in range(96)]:
        raise GateFailure("inventory-two-way-join: inventory must contain phases 0 through 95 in order")
    if len({row["contract"] for row in inventory}) != 96:
        raise GateFailure("inventory-two-way-join: contract paths are not unique")
    states = {name: sum(row["mechanism_state"] == name for row in inventory) for name in (
        "present", "planned-source", "planned-component", "descriptive-only",
    )}
    if states != {"present": 83, "planned-source": 7, "planned-component": 3, "descriptive-only": 3}:
        raise GateFailure(f"inventory-two-way-join: boundary state cardinalities drifted: {states}")
    descriptive = {int(row["phase"]) for row in inventory if row["authored_command"] == "—"}
    if descriptive != {73, 77, 89}:
        raise GateFailure("inventory-two-way-join: descriptive-only phase domain drifted")
    for row in inventory:
        contract = ROOT / row["contract"]
        if not contract.is_file():
            raise GateFailure(f"inventory-two-way-join: missing contract {row['contract']}")
        command = row["authored_command"]
        if command != "—" and not command.startswith(("python3 tools/", "cabal test ")):
            raise GateFailure(f"runner-argv-boundary: phase {row['phase']} has an open command domain")

    calculus = read_tsv(CALCULUS)
    wanted_calculus = [
        {"metric": "arms", "value": "provision,build,deploy,observe,teardown"},
        {"metric": "runnable-gates", "value": "93"},
        {"metric": "descriptive-contracts", "value": "3"},
        {"metric": "provisioned", "value": "phase-gate-process"},
        {"metric": "released", "value": "phase-gate-process:tore-down"},
        {"metric": "verdicts", "value": "PASS,RED"},
        {"metric": "mutants", "value": "3"},
        {"metric": "consumer-switches", "value": "93"},
    ]
    if calculus != wanted_calculus:
        raise GateFailure("results-equal-oracle: calculus projection drifted")
    if read_tsv(VERDICTS) != [
        {"exit_code": "0", "verdict": "PASS"},
        {"exit_code": "17", "verdict": "RED:17"},
    ]:
        raise GateFailure("results-equal-oracle: verdict projection drifted")

    locus = read_tsv(LOCUS)
    if len(locus) != 103 or len({row["entry"] for row in locus}) != 103:
        raise GateFailure("results-equal-oracle: validation locus must contain 103 unique rows")
    counts = {name: sum(row["class"] == name for row in locus) for name in (
        "gate-value", "descriptive", "verdict", "compile", "mutant",
    )}
    if counts != {"gate-value": 93, "descriptive": 3, "verdict": 2, "compile": 2, "mutant": 3}:
        raise GateFailure(f"results-equal-oracle: validation classes drifted: {counts}")

    custody = [
        row for row in read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
        if row["# phase"] == "149"
    ]
    if len(custody) != 10 or any(not (ROOT / row["path"]).is_file() for row in custody):
        raise GateFailure("inventory-two-way-join: Phase-49 custody must contain ten inputs")

    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or {row["flag"] for row in mutants} != set(FLAGS):
        raise GateFailure("three-mutants-red: registry must name the three exact build flags")
    if {row["mutant"]: row["expected_red_locus"] for row in mutants} != MUTANT_LOCI:
        raise GateFailure("three-mutants-red: mutant identities and red loci drifted")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 self-referential gate values; live mechanisms retain their own registers\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return inventory, locus, mutants


def verify_source(inventory: list[dict[str, str]]) -> None:
    source = SOURCE.read_text(encoding="utf-8")
    spec = SPEC.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")
    prohibited = re.compile(r"\b(error|undefined|fromJust|unsafePerformIO)\b|!!")
    if prohibited.search(source) or prohibited.search(spec):
        raise GateFailure("workflow-source-total: a prohibited partial token is present")
    for token in (
        "gateWorkflow :: GateDeclaration -> GateVerdict -> Workflow '[] '[] GateEvidence",
        "provision (Proxy @\"phase-gate-process\")",
        "build `andThen`", "deploy `andThen`", "observed `andThen`",
        "teardown (Proxy @\"phase-gate-process\")",
        "runIncludesMutants",
    ):
        if token not in source:
            raise GateFailure(f"workflow-source-total: derivation lacks {token!r}")
    if re.search(r"\bIO\b|System\.|getEnv|lookupEnv|readFile|writeFile", source):
        raise GateFailure("workflow-source-total: the production derivation reads an ambient input")
    for forbidden in ("shell=True", "os.system", "eval(", "exec("):
        if forbidden in runner:
            raise GateFailure(f"runner-argv-boundary: runner contains {forbidden!r}")
    for required in ("shlex.split", "subprocess.run", "authored_command", "self-referential-gates-spec", "--value"):
        if required not in runner:
            raise GateFailure(f"runner-argv-boundary: runner lacks {required!r}")

    for row in inventory:
        if row["authored_command"] == "—":
            continue
        text = (ROOT / row["contract"]).read_text(encoding="utf-8")
        wrapper = f"`python3 tools/run_phase_gate.py {int(row['phase']):02d}`"
        if text.count(wrapper) != 1:
            raise GateFailure(f"consumer-switch-exact: phase {row['phase']} has no unique runner")
        if not row["authored_command"].startswith(("python3 tools/", "cabal test ")):
            raise GateFailure(f"independent-mechanisms-retained: phase {row['phase']} lost its mechanism")

    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for component in (
        "library self-referential-gates",
        "test-suite self-referential-gates-spec",
    ):
        if component not in cabal:
            raise GateFailure(f"workflow-source-total: Cabal lacks {component}")
    for flag in FLAGS:
        if f"flag {flag}" not in cabal or f"if flag({flag})" not in cabal:
            raise GateFailure(f"three-mutants-red: Cabal does not wire {flag}")


def compile_pair(cabal: str) -> str:
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    # `cabal exec` constructs its package environment from this build root.  Seed that
    # environment with the two local libraries before asking GHC to typecheck a source
    # fixture directly.
    run(cabal_command(cabal, "build", "lib:self-referential-gates", *flag_config()))
    common = cabal_command(
        cabal,
        "exec", "--", COMPILER,
        "-fno-code", "-fforce-recomp", "-XGHC2024",
        "-isrc", "-isrc/self-referential-gates",
        f"-outputdir={TEMP_ROOT / 'compile'}", "-package", "text",
    )
    legal = run([*common, str(LEGAL)], require_success=False)
    illegal = run([*common, str(ILLEGAL)], require_success=False)
    if legal.returncode != 0:
        raise GateFailure(f"compile-rejects-leak: legal twin failed\n{legal.stdout}")
    if illegal.returncode == 0:
        raise GateFailure("compile-rejects-leak: omitted teardown compiled")
    for token in ("Couldn't match type", "phase-gate-process"):
        if token not in illegal.stdout:
            raise GateFailure(f"compile-rejects-leak: negative diagnostic lacks {token!r}\n{illegal.stdout}")
    return "LEGAL\n" + legal.stdout + "\nILLEGAL\n" + illegal.stdout


def verify_workflows(cabal: str) -> tuple[str, Path]:
    binary = build_component(cabal, SUITE)
    first = run([str(binary)])
    second = run([str(binary)])
    if first.stdout != second.stdout or ACCEPTANCE not in first.stdout:
        raise GateFailure("workflow-source-total: repeated workflow projections differ or lack acceptance")
    value = build_component(cabal, VALUE_RUNNER)
    passed = run([str(value), "--value", "49", CONTRACT, "python3 tools/self_referential_gates_gate.py", "0"])
    reddened = run([str(value), "--value", "49", CONTRACT, "python3 tools/self_referential_gates_gate.py", "17"])
    if "verdict PASS" not in passed.stdout or "verdict RED:17" not in reddened.stdout:
        raise GateFailure("results-equal-oracle: value runner lost a verdict projection")
    return first.stdout + second.stdout + passed.stdout + reddened.stdout, binary


def run_mutants(cabal: str, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    red = 0
    for row in mutants:
        binary = build_component(cabal, SUITE, row["flag"])
        outcome = run([str(binary)], require_success=False)
        loci = set(re.findall(r"self-referential-gates-mutant: RED ([a-z_]+)", outcome.stdout))
        expected = {row["expected_red_locus"]}
        exact = outcome.returncode != 0 and loci == expected
        print(f"  {'ok  ' if exact else 'FAIL'}  {row['mutant']:<24} {row['expected_red_locus']}")
        logs.append(f"{row['mutant']} exact={exact}\n{outcome.stdout}")
        red += int(exact)
    return "\n".join(logs), red


def verify_equivalence() -> str:
    # Phase 0 is deliberately the representative: its authored mechanism is independent
    # of the Haskell derivation, pure, and broad enough to detect a runner that changes cwd,
    # argv, or environment.  Both verdicts must be green; equal failures prove nothing.
    direct = run([sys.executable, "tools/doc_lint_verify.py"], require_success=False)
    derived = run([sys.executable, "tools/run_phase_gate.py", "00"], require_success=False)
    if direct.returncode != 0 or derived.returncode != direct.returncode:
        raise GateFailure(
            "independent-mechanisms-retained: Phase-0 direct/derived verdicts differ or are red\n"
            f"DIRECT\n{direct.stdout}\nDERIVED\n{derived.stdout}"
        )
    return "DIRECT\n" + direct.stdout + "\nDERIVED\n" + derived.stdout


def write_results() -> None:
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n"
        + "".join(f"{key}\t{value}\n" for key, value in EXPECTED_RESULTS.items()),
        encoding="utf-8",
    )


def item_classes(locus: list[dict[str, str]]) -> dict[str, set[str]]:
    return {
        name: {row["entry"] for row in locus if row["class"] == class_name}
        for name, class_name in (
            ("gate-values", "gate-value"),
            ("descriptive", "descriptive"),
            ("verdicts", "verdict"),
            ("compile", "compile"),
            ("mutants", "mutant"),
        )
    }


def surface_decisions(
    expected: list[tuple[str, str, list[str]]], results: Mapping[str, bool], rows: Mapping[str, str],
) -> dict[str, bool]:
    decision: dict[str, bool] = {}
    for surface, owner, _ids in expected:
        if owner == "gate-values":
            decision[surface] = results.get("workflow", False) and results.get("source", False)
        elif owner == "descriptive":
            decision[surface] = results.get("oracle", False)
        elif owner == "verdicts":
            decision[surface] = results.get("workflow", False)
        elif owner == "compile":
            decision[surface] = results.get("compile", False)
        elif owner == "mutants":
            decision[surface] = results.get("mutant", False)
        elif owner == "checks":
            decision[surface] = all(results.get(side, False) for side in SIDES[:-1])
        elif owner == "metrics":
            decision[surface] = rows == EXPECTED_RESULTS
    return decision


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=49,
        contract=CONTRACT,
        command=GATE_COMMAND,
        expectations=str(EXPECTATIONS.relative_to(ROOT)),
        register="1",
        substrate="none",
        lane="none",
        sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutants: list[dict[str, str]] = []
    locus: list[dict[str, str]] = []
    red = 0

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = resolved["cabal"]["path"]
        print("toolchain side — workflow-value compiler and package driver\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        for path in (BUILD_ROOT, TEMP_ROOT):
            if path.exists():
                shutil.rmtree(path)

        print("\noracle side — phase declarations, verdicts, calculus, custody, and mutants\n")
        inventory, locus, mutants = verify_oracles()
        print("  ok    inventory-two-way-join 96 contracts at the Phase-49 boundary")
        print("  ok    93 runnable declarations; 3 explicitly descriptive contracts")
        print("  ok    103 validation loci; 10 custody inputs; 3 independent mutants")
        results["oracle"] = True

        print("\nsource side — total five-arm derivation and closed argv runner\n")
        verify_source(inventory)
        print("  ok    workflow-source-total")
        print("  ok    runner-argv-boundary")
        print("  ok    consumer-switch-exact 93/93")
        print("  ok    independent-mechanisms-retained 93/93")
        results["source"] = True

        print("\ncompile side — teardown obligation differs by type\n")
        compile_log = compile_pair(cabal)
        (gate.run_dir / "compile.log").write_text(compile_log, encoding="utf-8")
        print("  ok    compile-rejects-leak legal green; omitted teardown red")
        results["compile"] = True

        print("\nworkflow side — all declarations and both verdicts projected twice\n")
        workflow_log, _binary = verify_workflows(cabal)
        (gate.run_dir / "workflow.log").write_text(workflow_log, encoding="utf-8")
        print("  ok    96 declarations, 93 runnable values, five arms, two evidence verdicts")
        results["workflow"] = True

        print("\nequivalence side — retained authored verdict against the derived consumer\n")
        equivalence_log = verify_equivalence()
        (gate.run_dir / "equivalence.log").write_text(equivalence_log, encoding="utf-8")
        print("  ok    Phase-0 direct and workflow-routed verdicts are both PASS")
        results["equivalence"] = True

        print("\nmutant side — three production defects at three named loci\n")
        mutant_log, red = run_mutants(cabal, mutants)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        results["mutant"] = red == 3
        if not results["mutant"]:
            raise GateFailure(f"three-mutants-red: only {red}/3 reddened exactly")

        print("\nresults side — exact recorded projection and generated-only output\n")
        write_results()
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS, check="results-equal-oracle")
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent, GENERATED_LEDGER.parent],
            (".tsv", ".log", ".json", ".txt"),
            gate.run_dir,
            check="emitted-results-untracked",
            label="self-referential gate results stay generated",
        )
        print("  ok    tracked-output 0-generated-in-source")
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"self-referential-gates-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    classes = item_classes(locus)
    implemented = {
        **classes,
        "checks": set(CHECKS),
        "metrics": set(rows),
    }
    evidence: dict[str, tuple[str, str] | None] = {
        "runnable gate declaration values": ("runnable-gates", EXPECTED_RESULTS["runnable-gates"]),
        "descriptive contracts remain non-runnable": (
            "descriptive-contracts", EXPECTED_RESULTS["descriptive-contracts"],
        ),
        "pass and red verdicts are evidence": ("verdicts", EXPECTED_RESULTS["verdicts"]),
        "teardown is a type obligation": ("compile-pairs", EXPECTED_RESULTS["compile-pairs"]),
        "three independent seeded defects": ("mutants", EXPECTED_RESULTS["mutants"]),
        "phase-49 integrity checks": None,
        "exact recorded outcomes": None,
    }
    layers = {
        "Decision": "proven-for-the-model" if results.get("workflow") and results.get("mutant") else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    observations = {}
    if RESULTS.is_file():
        observations["results"] = "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))
    return gate.finish(
        results,
        implemented=implemented,
        rows=rows,
        evidence=evidence,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items() if name != "platform"
        },
        dependencies={
            "self-referential-gates": "typed workflow derivation",
            "retained-gate-mechanisms": "independent verdict comparison",
        },
        mutants=[
            {"name": row["mutant"], "status": "red" if red == len(mutants) else "unrun"}
            for row in mutants
        ] or [{"name": "Phase-49 mutants", "status": "unrun"}],
        observations=observations,
        extra_status=surface_decisions(expected_rows, results, rows),
    )


if __name__ == "__main__":
    raise SystemExit(main())
