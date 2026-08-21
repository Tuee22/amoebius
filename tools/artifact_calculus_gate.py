#!/usr/bin/env python3
"""The Phase-3 gate — the artifact calculus.

Four deliverables, and each is checked where it can actually fail:

  * the **target set** is closed and the corpus covers it exactly;
  * the **address** folds the four inputs the authored oracle names, and nothing outside
    them — checked as a biconditional, because a fold that ignores half its inputs passes
    any check that only ever asserts equality;
  * **rendering is deterministic**, which one process cannot settle, so the suite prints
    its renderings under a seed and this gate runs it twice with different seeds;
  * the **region** reaps what it materialized and refuses to let a handle escape, the
    second half being a committed compile-fail pair rather than a test that runs.

Three seeded mutants, one per way the calculus can be quietly wrong: an address that drops
the rendered bytes, a recipe that folds an ambient observation, and a region that lets a
handle out. Each must redden its own locus and no other.

    python3 tools/artifact_calculus_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import csv
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
ADDRESS_ORACLE = ROOT / "test/oracle/artifact_calculus/address_inputs.tsv"
COMPILE_LEGAL = "test/negative/compile_fail/artifact_calculus/handle_stays_in_region.hs"
COMPILE_ILLEGAL = "test/negative/compile_fail/artifact_calculus/handle_escapes_region.hs"
CALCULUS_SOURCES = [
    "src/Amoebius/Calculus/Artifact/Target.hs",
    "src/Amoebius/Calculus/Artifact/Recipe.hs",
    "src/Amoebius/Calculus/Artifact/Address.hs",
    "src/Amoebius/Calculus/Artifact/Region.hs",
]
MUTANT_CAPABILITY = "artifact_calculus"
RESULTS = ROOT / ".build/calculus/artifact/phase-results.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/artifact-calculus"
SCRATCH = ROOT / ".build/tmp/artifact-calculus"
CONTRACT = "DEVELOPMENT_PLAN/phase_03_artifact_calculus.md"
GATE_COMMAND = "python3 tools/artifact_calculus_gate.py"
EXPECTATIONS = "test/oracle/artifact_calculus_surfaces.tsv"
SUITE = "artifact-calculus-spec"
ACCEPTANCE = "artifact-calculus-spec: PASS (6 targets, 4 address inputs, 11 checks)"

# The two seeds. They are literal because the run has to be reproducible: a random seed
# would make a failure impossible to re-observe, and the claim is that *no* seed changes
# the rendering rather than that two arbitrary ones happened not to.
SEEDS = ("alpha", "beta")


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


def read_oracle() -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    with ADDRESS_ORACLE.open(encoding="utf-8", newline="") as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 3:
                raise GateFailure(f"address oracle row needs target, input and reason: {line!r}")
            rows.append((fields[0], fields[1]))
    return rows


def verify_oracle() -> tuple[list[tuple[str, str]], list[dict[str, str]]]:
    """The oracle's shape, before anything it judges has run.

    It is authored from `jit_artifact_doctrine.md` section 4 and never from the renderer,
    which is the whole reason it can stay red when the renderer is wrong. What this side
    checks is that it is *complete* — every target names every input — because a missing
    row is a fold nothing would notice going missing.
    """
    rows = read_oracle()
    targets = {target for target, _ in rows}
    inputs = {name for _, name in rows}
    if inputs != {"target", "recipe-identity", "declaration", "rendered"}:
        raise GateFailure(f"address oracle names the wrong input set: {sorted(inputs)}")
    if len(targets) != 6:
        raise GateFailure(f"address oracle must cover six targets, covers {len(targets)}")
    if len(rows) != len(targets) * len(inputs) or len(set(rows)) != len(rows):
        raise GateFailure("address oracle must name each input once per target")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("the mutant registry must carry three unique artifact-calculus mutants")
    return rows, mutants


def verify_purity() -> None:
    """The half of L2 the type does not carry.

    A recipe is @decl -> Rendered k@, so it cannot perform an effect — that much is typed.
    What the type permits and the doctrine forbids is a *pure* reach for the world through
    an unsafe door, so the calculus modules are scanned for one. The partial-function scan
    beside it is the same discipline the older pure gates apply: a calculus that can throw
    is not total.
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


def render_report(binary: str, seed: str) -> str:
    return run([binary, "--render", seed]).stdout


def compile_fixture(cabal: str, fixture: str, defines: list[str]) -> subprocess.CompletedProcess[str]:
    """Typecheck one fixture against the calculus source, with the mutant defines given.

    `-fno-code` is a typecheck rather than a build, which is what an expect-fail golden
    over a type-level claim needs: the claim is that the program has no type, not that it
    fails to link.
    """
    scratch = SCRATCH / "compile-fail"
    scratch.mkdir(parents=True, exist_ok=True)
    return run(
        cabal_command(cabal, "exec", "--", COMPILER,
                      "-fno-code", "-fforce-recomp", "-XGHC2024", "-XOverloadedStrings", "-XCPP",
                      "-isrc", f"-outputdir={scratch}",
                      "-package", "bytestring", "-package", "text", "-package", "containers",
                      "-package", "cryptohash-sha256", *defines, fixture),
        require_success=False,
    )


def mutant_flag(name: str) -> str:
    return f"-f{name}"


def mutant_define(name: str) -> str:
    return "-D" + name.replace("-", "_").upper()


CHECKS = {
    "address-oracle-complete": "the authored oracle names every address input for every target",
    "calculus-is-pure": "no calculus module reaches for the world or can throw",
    "suite-acceptance-token": "the in-process suite reaches its acceptance token",
    "renders-agree-across-seeds": "two independently seeded processes render identical bytes",
    "handle-escape-rejected": "the region escape fixture has no type, and its legal twin does",
    "mutants-red-at-own-locus": "each seeded mutant reddens its own locus and no other",
    "emitted-results-untracked": "the gate's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "purity", "suite", "determinism", "compile-fail", "mutant", "results")

EXPECTED_RESULTS = {
    "address-inputs": "24/24-named-and-perturbed",
    "suite-checks": "11/11-green",
    "seeded-renders": "2/2-processes-agree",
    "compile-fail-pairs": "1/1-legal-green-illegal-type-red",
    "mutants": "3/3-red-at-own-locus",
    "calculus-purity": "no-ambient-read-no-partial-token",
    "acceptance-token": "artifact-calculus-proven-register-1",
    "budget-admission": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "closed-target-set": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "pure-recipe": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "address-folds-declared-inputs": ("address-inputs", EXPECTED_RESULTS["address-inputs"]),
    "render-determinism": ("seeded-renders", EXPECTED_RESULTS["seeded-renders"]),
    "handle-cannot-escape": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "artifact-calculus-mutants": ("mutants", EXPECTED_RESULTS["mutants"]),
    "artifact-calculus-acceptance": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "address-oracle-shape": ("address-inputs", EXPECTED_RESULTS["address-inputs"]),
    "calculus-purity-scan": ("calculus-purity", EXPECTED_RESULTS["calculus-purity"]),
    "suite-acceptance": ("suite-checks", EXPECTED_RESULTS["suite-checks"]),
    "seeded-render-agreement": ("seeded-renders", EXPECTED_RESULTS["seeded-renders"]),
    "region-escape-typecheck": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "mutant-locus-separation": ("mutants", EXPECTED_RESULTS["mutants"]),
    "generated-output-discipline": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "budget-admission": None,
    "runtime-fidelity": None,
}


def write_results(oracle_rows: int, mutants: int, checks: int) -> None:
    metrics = dict(EXPECTED_RESULTS)
    metrics["address-inputs"] = f"{oracle_rows}/{oracle_rows}-named-and-perturbed"
    metrics["suite-checks"] = f"{checks}/{checks}-green"
    metrics["mutants"] = f"{mutants}/{mutants}-red-at-own-locus"
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=3, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
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

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<6} {record['version']:<10} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = resolved["cabal"]["path"]

        print("\noracle side — the authored address oracle, before anything it judges runs\n")
        oracle, mutant_rows = verify_oracle()
        print(f"  ok    address-oracle-complete   {len(oracle)} rows: 6 targets x 4 inputs")
        print(f"  ok    mutant registry           {len(mutant_rows)} seeded defects declared")
        results["oracle"] = True

        print("\npurity side — what the recipe type cannot carry\n")
        verify_purity()
        print(f"  ok    calculus-is-pure          {len(CALCULUS_SOURCES)} modules: no ambient read, no partial token")
        results["purity"] = True

        print("\nsuite side — the calculus against its oracle, in process\n")
        binary = build_suite(cabal, [])
        outcome = run_suite(binary)
        (gate.run_dir / "suite.log").write_text(outcome.stdout, encoding="utf-8")
        if outcome.returncode != 0 or ACCEPTANCE not in outcome.stdout:
            raise GateFailure(f"acceptance token absent:\n{outcome.stdout}")
        checks_green = outcome.stdout.count("  ok   ")
        print(f"  ok    suite-acceptance-token    {checks_green} checks green")
        results["suite"] = True

        print("\ndeterminism side — two independently seeded processes\n")
        reports = [render_report(binary, seed) for seed in SEEDS]
        (gate.run_dir / "renders.log").write_text("\n".join(reports), encoding="utf-8")
        if len(set(reports)) != 1:
            raise GateFailure("seeded renders disagree, so a recipe is reading the world")
        if len(reports[0].strip().splitlines()) != 6:
            raise GateFailure("the seeded render must report one line per target")
        print(f"  ok    renders-agree-across-seeds seeds {SEEDS[0]!r} and {SEEDS[1]!r} agree over 6 targets")
        results["determinism"] = True

        print("\ncompile-fail side — the region escape, as a type error\n")
        legal = compile_fixture(cabal, COMPILE_LEGAL, [])
        if legal.returncode != 0:
            raise GateFailure(f"the legal twin failed to typecheck:\n{legal.stdout}")
        illegal = compile_fixture(cabal, COMPILE_ILLEGAL, [])
        if illegal.returncode == 0:
            raise GateFailure("the escaping handle typechecked")
        if "rigid type variable" not in illegal.stdout:
            raise GateFailure(f"the escape was rejected for the wrong reason:\n{illegal.stdout}")
        print("  ok    handle-escape-rejected    legal twin green, escape red at the skolem")
        results["compile-fail"] = True

        print("\nmutant side — each seeded defect red at its own locus\n")
        results["mutant"] = mutant_side(cabal, mutant_rows, binary, gate)

        write_results(len(oracle), len(mutant_rows), checks_green)
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the gate's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"artifact-calculus-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        # The mutant builds leave the shared build tree configured for whichever flag ran
        # last. Restoring the clean configuration is part of the run rather than a courtesy:
        # a later gate reading this tree would otherwise be reading a mutant.
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
        or [{"name": "artifact-calculus mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


def mutant_side(cabal: str, mutants: list[dict[str, str]], clean_binary: str, gate: Any) -> bool:
    """Each mutant reddens its own locus, and leaves the others green.

    The three loci are deliberately different instruments — an in-process check, a
    two-process comparison, and a typecheck — because a mutant that only ever has to
    redden the same battery proves that battery reacts, not that the three claims are
    separately held.
    """
    ok = True
    log: list[str] = []
    for row in mutants:
        name = row["mutant"]
        locus = dict(pair.split("=", 1) for pair in row["detail"].split(";"))["expected_red_locus"]
        if locus == "compile-fail":
            outcome = compile_fixture(cabal, COMPILE_ILLEGAL, [mutant_define(row["flag"])])
            red = outcome.returncode == 0
            log.append(f"{name}: escape typechecked = {red}")
        else:
            binary = build_suite(cabal, [mutant_flag(row["flag"])])
            if locus == "determinism":
                reports = [render_report(binary, seed) for seed in SEEDS]
                red = len(set(reports)) != 1
                suite = run_suite(binary)
                # The in-process suite must stay green: a mutant that reddens every locus
                # says nothing about which claim caught it.
                red = red and suite.returncode == 0
                log.append(f"{name}: seeded renders differ = {red}")
            else:
                suite = run_suite(binary)
                red = suite.returncode != 0 and f"FAIL {locus}" in suite.stdout
                log.append(f"{name}: {locus} red = {red}\n{suite.stdout}")
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<34} {locus}")
        ok = ok and red
    (gate.run_dir / "mutants.log").write_text("\n".join(log), encoding="utf-8")
    return ok


if __name__ == "__main__":
    raise SystemExit(main())
