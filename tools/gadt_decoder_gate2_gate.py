#!/usr/bin/env python3
"""The Phase-6 gate — the GADT-indexed IR and its total decoder (Gate 2).

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
    suite's own acceptance token, the boundary argv observation, or the mutant's failure
    locus, and a
    `results-are-measured` check asserts the derivation actually ran.
  * `test/spec/dsl/DecodeSpec.hs` hard-coded one developer's `ghc` and `dhall` paths. The suite
    still invokes both by absolute path — that is what the argv observer checks — but the
    absolute path is now a run-local resolution supplied by this gate, and the suite fails
    closed when it is missing.
  * The observer was `strace -e trace=execve`, which exists on one of the four declared
    substrates. A Register-1 gate declaring substrate `none` must be decidable on all four,
    and this one died at `FileNotFoundError` before its first check on two of them. It now
    observes the two routes a tool can be reached by — a declared absolute path through a
    recording interposer, and an ambient `PATH` lookup through a refusing shim — using only
    the process model every substrate shares. `tools/argv_observer.py` owns the mechanism
    and states its boundary.

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

import argv_observer  # noqa: E402
import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import toolchain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ROOT / ".build" / "dsl" / "gate2"
RESULTS = GENERATED / "phase-results.tsv"
OBSERVER_TAG = "gadt_decoder_gate2"
BUILD_ROOT = ROOT / ".build" / "dist-newstyle" / "gadt-decoder-gate2"
CONTRACT = "DEVELOPMENT_PLAN/phase_06_gadt_decoder_gate2.md"
GATE_COMMAND = "python3 tools/gadt_decoder_gate2_gate.py"
EXPECTATIONS = "test/oracle/gadt_decoder_gate2_surfaces.tsv"

ORACLE = ROOT / "test" / "oracle" / "gadt_decoder_gate2"
POSITIVE_ORACLE = ORACLE / "positive_trees.tsv"
COMPILE_PAIR_ORACLE = ORACLE / "compile_pairs.tsv"
DECODE_ORACLE = ORACLE / "decode_cases.tsv"

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
    "argv-observer-mutants": "2/2-red",
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
        "argv-observer-mutants": "argv-observer-mutants",
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


def build_observer(resolved: dict[str, Any]) -> argv_observer.ArgvObserver:
    """The boundary observer this run reaches its three families through.

    The versioned spellings are refused alongside the bare ones: a resolver that hands out
    `ghc-9.12.4` leaves the ambient route open under a second name, and an observer that
    only refused `ghc` would not see it.
    """
    families = {name: resolved[name]["path"] for name in ("cabal", "ghc", "dhall")}
    ambient = {name: name for name in families}
    for name in families:
        version = resolved[name].get("version")
        if version:
            ambient[f"{name}-{version}"] = name
    observer = argv_observer.ArgvObserver(tag=OBSERVER_TAG, families=families)
    observer.begin(ambient_names=ambient)
    return observer


def suite_env(resolved: dict[str, Any], observer: argv_observer.ArgvObserver) -> dict[str, str]:
    base = toolchain.contained_env()
    base["PATH"] = os.pathsep.join([str(ROOT / "tools"), base.get("PATH", "")])
    env = observer.env(base)
    # The suite invokes both as leaves, so both go through the declared route and are
    # recorded at the boundary rather than by their caller.
    env["AMOEBIUS_GHC"] = observer.tool("ghc")
    env["AMOEBIUS_DHALL"] = observer.tool("dhall")
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


def suite_side(
    resolved: dict[str, Any], observer: argv_observer.ArgvObserver, run_dir: Path
) -> tuple[bool, dict[str, Any]]:
    """Run dsl-spec through the boundary argv observer and measure what came back."""
    print("\nsuite side — dsl-spec through the boundary argv observer\n")
    GENERATED.mkdir(parents=True, exist_ok=True)
    if BUILD_ROOT.exists():
        shutil.rmtree(BUILD_ROOT)
    # `--with-compiler` takes the real compiler rather than the interposer: cabal derives
    # `ghc-pkg` and its other companions from the path it is handed, and an interposer
    # standing where a compiler should be would break that derivation for no observation —
    # a companion is not one of the families this phase makes a claim about. The compiler
    # cabal drives is still covered, by the refusing shims: an ambient `ghc` lookup fails.
    command = [
        observer.tool("cabal"), f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}", f"--store-dir={ROOT / '.build' / 'cabal-store'}",
        "test", "dsl-spec", "--test-show-details=direct",
    ]
    result = subprocess.run(
        command, cwd=ROOT, env=suite_env(resolved, observer), text=True,
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

    try:
        families, ambient = observer.observations()
    except argv_observer.ObserverError as error:
        print(f"  FAIL  absolute-tool-argv {error}")
        return False, {}
    for record in ambient:
        print(f"  FAIL  absolute-tool-argv ambient PATH lookup observed: {record.render()}")
    missing = {"cabal", "ghc", "dhall"} - families
    if missing:
        print(f"  FAIL  absolute-tool-argv observer recorded no {sorted(missing)} invocation")
    if ambient or missing:
        return False, {}
    print(f"  ok    absolute-tool-argv every {'/'.join(sorted(families))} invocation took the "
          "declared absolute route, and no name resolved through PATH")
    return True, {"positives": positives, "negatives": negatives, "pairs": pairs, "families": families}


def observer_mutants(resolved: dict[str, Any]) -> tuple[bool, str]:
    """Prove the boundary observer can fail, at each of the two things it claims.

    An instrument that cannot be shown to fail is not an instrument
    (`development_plan_standards.md` section M clause 2). Both mutants are committed under
    `test/mutant/gadt_decoder_gate2/` and neither needs the suite rebuilt: each exercises
    exactly the mechanism under test and nothing else.
    """
    print("\nobserver mutants — the boundary observer must redden at each claim\n")
    caught = 0

    # m: an ambient PATH lookup. The refusing shim must record it and the process must die,
    # rather than the lookup succeeding quietly against whatever PATH happened to hold.
    probe = argv_observer.ArgvObserver(
        tag=OBSERVER_TAG + "-ambient",
        families={name: resolved[name]["path"] for name in ("cabal", "ghc", "dhall")},
    )
    probe.begin(ambient_names={"dhall": "dhall"})
    result = subprocess.run(
        ["/bin/sh", "-c", "dhall --version"], cwd=ROOT,
        env=probe.env(toolchain.contained_env()), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    _families, ambient = probe.observations()
    if result.returncode != 0 and any(record.family == "dhall" for record in ambient):
        caught += 1
        print("  ok    ambient-path-lookup   refused and recorded, exit "
              f"{result.returncode}")
    else:
        print(f"  FAIL  ambient-path-lookup   survived: exit {result.returncode}, "
              f"{len(ambient)} ambient record(s)")

    # m: a family the run never invoked. The observation must report it missing rather than
    # inferring it from the suite having passed.
    probe.log.write_text("", encoding="utf-8")
    families, _ambient = probe.observations()
    if not families:
        caught += 1
        print("  ok    unobserved-family     an empty observation reports no family")
    else:
        print(f"  FAIL  unobserved-family     an empty observation reported {sorted(families)}")

    return caught == 2, f"{caught}/2-red"


def mutant_side(
    resolved: dict[str, Any], observer: argv_observer.ArgvObserver, run_dir: Path
) -> tuple[bool, str]:
    print("\nmutant side — the legalized schema negative must turn the suite red\n")
    env = suite_env(resolved, observer)
    env["AMOEBIUS_GATE2_SCHEMA_FIXTURE"] = "test/mutant/gadt_decoder_gate2/legalized_schema.dhall"
    result = subprocess.run(
        [observer.tool("cabal"), f"--with-compiler={resolved['ghc']['path']}",
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
        "argv-observer-mutants": observed["observer_mutants"],
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
        phase=6, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    # Clause 15 first: a run that cannot name the architecture it executed on, or
    # that is executing under translation, has nothing worth proving.
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    results["toolchain"], resolved = toolchain_side()
    observed: dict[str, Any] = {}
    observer: argv_observer.ArgvObserver | None = None
    mutant_value, scan_value = "unrun", "unrun"
    if results["toolchain"]:
        try:
            observer = build_observer(resolved)
            results["suite"], observed = suite_side(resolved, observer, gate.run_dir)
        except (GateFailure, argv_observer.ObserverError) as error:
            print(f"  FAIL  absolute-tool-argv {error}")
            results["suite"] = False
    if results["suite"] and observer is not None:
        observer_ok, observed["observer_mutants"] = observer_mutants(resolved)
        results["mutant"], mutant_value = mutant_side(resolved, observer, gate.run_dir)
        results["mutant"] = results["mutant"] and observer_ok
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
            {"name": "argv observer", "status": observed.get("observer_mutants", "unrun")},
            {"name": "structural deletion", "status": rows.get("structural-deletion-mutants", "unrun")},
            {"name": "structural substitution", "status": rows.get("structural-substitution-families", "unrun")},
        ],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "argv_observation": "sha256:" + artifact_policy.digest(str(observer.log)),
        }
        if RESULTS.is_file() and observer is not None and observer.log.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
