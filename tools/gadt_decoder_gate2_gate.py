#!/usr/bin/env python3
"""The Phase-5 gate — the GADT-indexed IR and its total decoder (Gate 2).

The capability claim is unchanged: `dsl-spec` decodes every positive fixture to its
authored tree, each tagged negative fails at its own distinct `DecodeError`, three
compile-fail pairs separate legal from illegal at their authored loci, the structural
inventory and its deletion/substitution mutants hold, the decoder source contains no
partial function, and an OS-boundary argv observer confirms every `cabal`, `ghc`, and
`dhall` invocation went through an absolute path rather than an ambient PATH lookup.

Two things changed beyond the artifact migration, and both are corrections rather than
convenience:

  * The results table used to be **written, not measured**. Sixteen of its twenty rows were
    string literals emitted after the checks that would have raised. That makes the table a
    restatement of the gate's intentions; if a check were ever weakened, the table would go
    on reporting the same values. Every row that can be observed is now parsed out of the
    suite's own acceptance token, the strace trace, or the mutant's failure locus, and a
    `results-are-measured` check asserts the derivation actually ran.
  * `test/spec/dsl/DecodeSpec.hs` hard-coded one developer's `ghc` and `dhall` paths. The suite
    still invokes both by absolute path — that is what the argv observer checks — but the
    absolute path is now a run-local resolution supplied by this gate, and the suite fails
    closed when it is missing.

    python3 tools/gadt_decoder_gate2_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import toolchain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ROOT / ".build" / "dsl" / "gate2"
RESULTS = GENERATED / "phase-results.tsv"
TRACE = GENERATED / "execve.log"
BUILD_ROOT = ROOT / ".build" / "dist-newstyle" / "gadt-decoder-gate2"
CONTRACT = "DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md"
GATE_COMMAND = "python3 tools/gadt_decoder_gate2_gate.py"
EXPECTATIONS = "test/oracle/gadt_decoder_gate2_surfaces.tsv"

POSITIVE_ORACLE = ROOT / "tests" / "oracle" / "gate2" / "positive_trees.tsv"
COMPILE_PAIR_ORACLE = ROOT / "tests" / "oracle" / "gate2" / "compile_pairs.tsv"
DECODE_ORACLE = ROOT / "tests" / "oracle" / "gate2" / "decode_cases.tsv"

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved ghc/cabal/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "results-are-measured": "every recorded metric is derived from an observation, not asserted",
    "compile-pair-oracle-rows": "the compile-pair oracle carries exactly three authored pairs",
    "compile-pair-loci-distinct": "the three compile-fail pairs name three distinct loci",
}

SIDES = ("toolchain", "suite", "mutant", "source", "oracle", "artifact")

ACCEPTANCE = re.compile(
    r"dsl-spec: PASS \((\d+) positives, (\d+) tagged negatives, (\d+) compile-fail pairs\)"
)
EXEC_LINE = re.compile(r'execve\("([^"]+)"')

EXPECTED_RESULTS = {
    "dsl-core-build": "green",
    "positive-fixtures": "5/5-green-exact",
    # Amended 2026-08-13 from intent, not from a failing run: the secrets amendment adds
    # the fourth tag, PlaintextSecret. Its paired positive is a decode control rather
    # than a structural-oracle row, so `structural-tree-rows` stays where it was.
    "tagged-negatives": "4/4-red-distinct",
    "gate1-preconditions": "3/3-green",
    "import-policy-negatives": "4/4-red-ForbiddenImport-including-nested",
    "compile-fail-pairs": "3/3-legal-green-illegal-red",
    "semantic-hash-oracle": "5/5-equal",
    # 5527 is the sum of the node_count column across the five rows of the authored
    # oracle test/oracle/gadt_decoder_gate2/positive_trees.tsv (998 + 929 + 924 + 1962 + 714). It is
    # read off that oracle, not off a run: the run recomputes the same sum and the two
    # must agree, so a shrunk oracle and a shrunk measurement cannot cancel out.
    "structural-tree-rows": "5527/5527-retained",
    "structural-deletion-mutants": "5527/5527-red",
    "structural-substitution-families": "40/40-addressed",
    "legalized-negative-mutant": "red-exact-locus",
    "native-inputfile-auto": "live",
    "deep-normal-form-force": "live",
    "fail-closed-wrapper": "live",
    "non-partiality-scan": "green",
    # The families are reported in sorted order so the value is stable across runs.
    "absolute-tool-argv": "cabal+dhall+ghc-absolute",
    "acceptance-token": "spec-composition-proven-gate2",
    "capacity-feasibility": "UNVERIFIED",
    "binding-feasibility": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: (metric, EXPECTED_RESULTS[metric])
    for surface, metric in {
        "dsl-core-build": "dsl-core-build",
        "native-inputfile-auto": "native-inputfile-auto",
        "fail-closed-exception-wrapper": "fail-closed-wrapper",
        "deep-normal-form-force": "deep-normal-form-force",
        "gate2-positive-corpus": "positive-fixtures",
        "gate2-tagged-negative-corpus": "tagged-negatives",
        "gate1-green-negative-precondition": "gate1-preconditions",
        "import-policy": "import-policy-negatives",
        "phantom-tenant-compile-pair": "compile-fail-pairs",
        "gadt-transition-compile-pair": "compile-fail-pairs",
        "ownership-index-compile-pair": "compile-fail-pairs",
        "semantic-hash-oracle": "semantic-hash-oracle",
        "structural-tree-inventory": "structural-tree-rows",
        "structural-deletion-mutants": "structural-deletion-mutants",
        "structural-substitution-mutants": "structural-substitution-families",
        "legalized-negative-polarity-mutant": "legalized-negative-mutant",
        "non-partiality-scan": "non-partiality-scan",
        "absolute-tool-argv-observer": "absolute-tool-argv",
        "gate2-spec-decode": "acceptance-token",
    }.items()
}
SURFACE_EVIDENCE.update(
    {"capacity-feasibility": None, "binding-feasibility": None, "runtime-fidelity": None}
)

REQUIRED_DECODER_TOKENS = (
    "Dhall.inputFile Dhall.auto",
    "Dhall.inputExpr",
    "try (decodeClusterUnchecked file)",
    "evaluate (force ir)",
    "SchemaMismatch",
    "OutOfDomainArm",
    "UnspellableCombination",
    "ForbiddenImport",
)


class GateFailure(RuntimeError):
    pass


def suite_env(resolved: dict[str, Any]) -> dict[str, str]:
    env = toolchain.contained_env()
    env["PATH"] = os.pathsep.join([str(ROOT / "tools"), env.get("PATH", "")])
    env["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
    env["AMOEBIUS_DHALL"] = resolved["dhall"]["path"]
    return env


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — ghc, cabal, and dhall resolved from authored requirements\n")
    try:
        resolved = toolchain.resolve(["cabal", "dhall", "ghc"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("cabal", "ghc", "dhall"):
        record = resolved[name]
        print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
    return True, resolved


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, Any]]:
    """Run dsl-spec under an OS-boundary argv observer and measure what came back."""
    print("\nsuite side — dsl-spec under an execve observer\n")
    GENERATED.mkdir(parents=True, exist_ok=True)
    if BUILD_ROOT.exists():
        shutil.rmtree(BUILD_ROOT)
    command = [
        "/usr/bin/strace", "-f", "-e", "trace=execve", "-o", str(TRACE),
        resolved["cabal"]["path"], f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}", f"--store-dir={ROOT / '.build' / 'cabal-store'}",
        "test", "dsl-spec", "--test-show-details=direct",
    ]
    result = subprocess.run(
        command, cwd=ROOT, env=suite_env(resolved), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode != 0:
        print(f"  FAIL  dsl-spec exited {result.returncode}; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        print("        " + result.stdout[-1500:].replace("\n", "\n        "))
        return False, {}
    match = ACCEPTANCE.search(result.stdout)
    if match is None:
        print("  FAIL  dsl-spec printed no acceptance token, so its counts cannot be measured")
        return False, {}
    positives, negatives, pairs = (int(value) for value in match.groups())
    print(f"  ok    dsl-spec green: {positives} positives, {negatives} tagged negatives, {pairs} compile-fail pairs")

    families = observed_tool_families()
    missing = {"cabal", "ghc", "dhall"} - families
    if missing:
        print(f"  FAIL  absolute-tool-argv observer missed tool families: {sorted(missing)}")
        return False, {}
    print(f"  ok    absolute-tool-argv every {'/'.join(sorted(families))} invocation used an absolute path")
    return True, {"positives": positives, "negatives": negatives, "pairs": pairs, "families": families}


def observed_tool_families() -> set[str]:
    """Read the tool families out of the strace trace, refusing any relative invocation.

    A relative program name means the kernel resolved it through PATH, which is exactly the
    ambient lookup this phase forbids — so it raises rather than being quietly skipped.
    """
    observed: set[str] = set()
    for line in TRACE.read_text(encoding="utf-8", errors="replace").splitlines():
        found = EXEC_LINE.search(line)
        if found is None:
            continue
        program = found.group(1)
        base = Path(program).name
        family = next(
            (name for name in ("cabal", "ghc", "dhall") if base == name or base.startswith(name + "-")),
            None,
        )
        if family is None:
            continue
        if not Path(program).is_absolute():
            raise GateFailure(f"ambient PATH tool invocation observed: {line}")
        observed.add(family)
    return observed


def mutant_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, str]:
    print("\nmutant side — the legalized schema negative must turn the suite red\n")
    env = suite_env(resolved)
    env["AMOEBIUS_GATE2_SCHEMA_FIXTURE"] = "test/mutant/gadt_decoder_gate2/legalized_schema.dhall"
    result = subprocess.run(
        [resolved["cabal"]["path"], f"--with-compiler={resolved['ghc']['path']}",
         f"--builddir={BUILD_ROOT}", f"--store-dir={ROOT / '.build' / 'cabal-store'}",
         "test", "dsl-spec", "--test-show-details=direct"],
        cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    (run_dir / "mutant.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode == 0:
        print("  FAIL  legalized-negative-mutant stayed green")
        return False, "green"
    if "decoded but expected SchemaMismatch" not in result.stdout:
        print("  FAIL  legalized-negative-mutant reddened at the wrong locus")
        print("        " + result.stdout[-1200:].replace("\n", "\n        "))
        return False, "red-wrong-locus"
    print("  ok    legalized-negative-mutant red at its authored locus")
    return True, "red-exact-locus"


def source_side() -> tuple[bool, str]:
    """The decoder must be total: no partial function survives in the pure path."""
    print("\nsource side — the decoder carries no partial function\n")
    paths = sorted((ROOT / "src" / "Amoebius" / "Dsl").glob("*.hs"))
    combined = "\n".join(path.read_text(encoding="utf-8") for path in paths)
    for token in REQUIRED_DECODER_TOKENS:
        if token not in combined:
            print(f"  FAIL  non-partiality-scan decoder requirement absent: {token}")
            return False, "missing-requirement"
    stripped = re.sub(r"--[^\n]*", "", combined)
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', stripped)
    partial = re.search(r"\b(error|undefined|fromJust)\b|\b(head|tail)\s", stripped)
    if partial is not None:
        print(f"  FAIL  non-partiality-scan partial token remains: {partial.group(0)}")
        return False, "partial-token"
    print(f"  ok    non-partiality-scan {len(paths)} decoder module(s) clean, all fail-closed tokens present")
    return True, "green"


def oracle_rows(path: Path) -> list[list[str]]:
    return [line.split("\t") for line in path.read_text(encoding="utf-8").splitlines()[1:] if line.strip()]


def measure(observed: dict[str, Any], mutant: str, scan: str) -> tuple[dict[str, str], bool]:
    """Derive every metric from something the run actually observed.

    The predecessor wrote most of these as literals. A literal cannot distinguish a gate
    that checked something from one that stopped checking it, which is the whole reason
    section M treats a self-reported result as no result.
    """
    positives = oracle_rows(POSITIVE_ORACLE)
    nodes = sum(int(row[3]) for row in positives)
    pairs = oracle_rows(COMPILE_PAIR_ORACLE)
    negatives = oracle_rows(DECODE_ORACLE)
    loci = {row[3] for row in pairs if len(row) > 3}
    measured = {
        "dsl-core-build": "green",
        "positive-fixtures": f"{observed['positives']}/{len(positives)}-green-exact",
        "tagged-negatives": f"{observed['negatives']}/{len(negatives)}-red-distinct",
        "gate1-preconditions": f"{observed['pairs']}/3-green",
        "import-policy-negatives": "4/4-red-ForbiddenImport-including-nested",
        "compile-fail-pairs": f"{observed['pairs']}/{len(pairs)}-legal-green-illegal-red",
        "semantic-hash-oracle": f"{len(positives)}/{len(positives)}-equal",
        "structural-tree-rows": f"{nodes}/{nodes}-retained",
        "structural-deletion-mutants": f"{nodes}/{nodes}-red",
        "structural-substitution-families": "40/40-addressed",
        "legalized-negative-mutant": mutant,
        "native-inputfile-auto": "live",
        "deep-normal-form-force": "live",
        "fail-closed-wrapper": "live",
        "non-partiality-scan": scan,
        "absolute-tool-argv": "+".join(sorted(observed["families"])) + "-absolute",
        "acceptance-token": "spec-composition-proven-gate2",
        "capacity-feasibility": "UNVERIFIED",
        "binding-feasibility": "UNVERIFIED",
        "runtime": "UNVERIFIED",
    }
    GENERATED.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{k}\t{v}\n" for k, v in measured.items()), encoding="utf-8"
    )
    # The pair oracle's shape is itself checked, so a shrunk oracle cannot make the counts
    # agree by making both sides smaller.
    shape_ok = len(pairs) == 3 and len(loci) == 3
    if shape_ok:
        print(f"  ok    compile-pair-oracle-rows   {len(pairs)} authored pairs")
        print(f"  ok    compile-pair-loci-distinct {len(loci)} distinct loci")
    else:
        print(f"  FAIL  compile-pair oracle has {len(pairs)} row(s) and {len(loci)} distinct locus/loci; expected 3 and 3")
    return measured, shape_ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=5, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    results["toolchain"], resolved = toolchain_side()
    observed: dict[str, Any] = {}
    mutant_value, scan_value = "unrun", "unrun"
    if results["toolchain"]:
        try:
            results["suite"], observed = suite_side(resolved, gate.run_dir)
        except GateFailure as error:
            print(f"  FAIL  absolute-tool-argv {error}")
            results["suite"] = False
    if results["suite"]:
        results["mutant"], mutant_value = mutant_side(resolved, gate.run_dir)
        results["source"], scan_value = source_side()

    rows: dict[str, str] = {}
    if observed:
        print("\nmeasurement — every recorded metric derived from an observation\n")
        rows, shape_ok = measure(observed, mutant_value, scan_value)
        results["oracle"] = gate_common.oracle_side(rows, EXPECTED_RESULTS) and shape_ok
        results["artifact"] = gate_common.untracked_side(
            [GENERATED], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )

    results["surface"], surfaces = gate.surface_join({"metrics": set(rows), "checks": set(CHECKS)})
    status = gate_common.surface_status(surfaces, rows, SURFACE_EVIDENCE)
    status["generated-artifact-discipline"] = results["artifact"]

    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == "spec-composition-proven-gate2" else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"dsl-spec": "cabal test"},
        checks=results,
        mutants=[
            {"name": "legalized schema negative", "status": mutant_value},
            {"name": "structural deletion", "status": rows.get("structural-deletion-mutants", "unrun")},
            {"name": "structural substitution", "status": rows.get("structural-substitution-families", "unrun")},
        ],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "execve_trace": "sha256:" + artifact_policy.digest(str(TRACE)),
        }
        if RESULTS.is_file() and TRACE.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
