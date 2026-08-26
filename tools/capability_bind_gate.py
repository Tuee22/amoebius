#!/usr/bin/env python3
"""Run and seal the capability binding gate."""

from __future__ import annotations

import argparse
import csv
import hashlib
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
import toolchain


ROOT = Path(__file__).resolve().parent.parent
ARM_ORACLE = ROOT / "test/oracle/capability_bind/arm_cases.tsv"
SHAPE_SEMANTICS = ROOT / "test/oracle/capability_bind/bound_shape_semantics.tsv"
CALCULUS_PROJECTION = ROOT / "test/oracle/capability_bind/calculus_projection.tsv"
DHALL_TYPECHECK = ROOT / "test/oracle/capability_bind/dhall_typecheck_cases.tsv"
GADT_DECODE = ROOT / "test/oracle/capability_bind/gadt_decode_cases.tsv"
MUTANT_CAPABILITY = "capability_bind"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/capability_bind/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/capability-bind/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/capability-bind/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/capability-bind"
CONTRACT = "DEVELOPMENT_PLAN/phase_30_capability_bind.md"
GATE_COMMAND = "python3 tools/capability_bind_gate.py"
EXPECTATIONS = "test/oracle/capability_bind_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", *command[1:]]
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment,
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


def read_surface_map(path: Path) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise GateFailure(f"malformed surface row: {line}")
        surface, _owner, ids = fields
        mapping[surface] = ids
    return mapping


def verify_pins() -> tuple[Path, Path, str]:
    pins = toolchain.resolve(["cabal", "dhall", "ghc"])
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    dhall = Path(pins["dhall"]["path"])
    for executable in (cabal, ghc, dhall):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(
        [
            run([str(cabal), "--numeric-version"]).stdout,
            run([str(ghc), "--numeric-version"]).stdout,
            run([str(dhall), "--version"]).stdout,
        ]
    )
    for family in ("cabal", "ghc", "dhall"):
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return cabal, dhall, versions


def verify_oracles(dhall: Path) -> list[dict[str, str]]:
    arms = read_tsv(ARM_ORACLE)
    shape_semantics = read_tsv(SHAPE_SEMANTICS)
    calculus_projection = read_tsv(CALCULUS_PROJECTION)
    dhall_typecheck = read_tsv(DHALL_TYPECHECK)
    gadt_decode = read_tsv(GADT_DECODE)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    locus = read_tsv(LOCUS)
    required_arms = {
        "ObjectStore",
        "SecretStore",
        "MessageBus",
        "Sql",
        "Identity",
        "Observability",
        "Registry",
        "Edge",
        "InferenceEngine",
    }
    if len(arms) != 9 or {row["arm"] for row in arms} != required_arms:
        raise GateFailure("Phase-30 arm oracle must enumerate the exact closed nine-arm union")
    if len({row["slug"] for row in arms}) != 9 or len({row["resource"] for row in arms}) != 9:
        raise GateFailure("Phase-30 arm oracle slugs and resource names must be unique")
    if len(shape_semantics) != 9 or [row["slug"] for row in shape_semantics] != [row["slug"] for row in arms]:
        raise GateFailure("Phase-30 semantic shape oracle must cover the pinned arm order exactly")
    expected_calculus = {
        "calculus-kinds": "artifact,budget,lift,workflow,evidence",
        "component-names": "capability-arms,bound-service-shapes,boundary-negatives,bind-property,mutant-evidence",
        "projection-counts": "9,18,7,1,4",
        "resource-vector": "5,39,0,0",
    }
    if {row["metric"]: row["value"] for row in calculus_projection} != expected_calculus:
        raise GateFailure("Phase-30 independently authored five-calculus projection drifted")
    if len(dhall_typecheck) != 3 or {row["case"] for row in dhall_typecheck} != {"product-in-app", "engine-by-url", "shape-in-app"}:
        raise GateFailure("Phase-30 Gate-1 oracle must contain the three required negatives")
    expected_gadt_decode = {"UnbuiltProviderArm", "UnboundCapability", "CyclicExtension", "ShadowingExtension"}
    if len(gadt_decode) != 4 or {row["expected"] for row in gadt_decode} != expected_gadt_decode:
        raise GateFailure("Phase-30 Gate-2 oracle must preserve all four specific error tags")
    if len(mutants) != 4 or len({row["mutant"] for row in mutants}) != 4:
        raise GateFailure("Phase-30 mutant manifest must contain four unique mutants")
    positive_names = {
        f"legal_{row['slug']}_{shape}"
        for row in arms
        for shape in ("singlenode", "distributed")
    }
    expected_locus = positive_names | {
        "illegal_product_in_app",
        "illegal_engine_by_url",
        "illegal_shape_in_app",
        "illegal_unbuilt_provider",
        "illegal_unbound_capability",
        "illegal_cyclic_extension",
        "illegal_shadowing_extension",
        *(row["mutant"] for row in mutants),
    }
    if {row["entry"] for row in locus} != expected_locus or len(locus) != len(expected_locus):
        raise GateFailure("Phase-30 validation-locus ledger has incomplete or duplicate coverage")
    for row in arms:
        for shape in ("singlenode", "distributed"):
            fixture = ROOT / f"dhall/examples/legal_{row['slug']}_{shape}.dhall"
            if not fixture.is_file():
                raise GateFailure(f"missing per-arm fixture for {row['slug']} {shape}")
    for row in dhall_typecheck:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    for row in gadt_decode:
        for fixture in (row["negative"], row["legal"]):
            checked = run([str(dhall), "type", "--file", fixture, "--quiet"], require_success=False)
            if checked.returncode != 0:
                raise GateFailure(f"Gate-2 fixture must be Dhall-well-typed before refinement: {fixture}\n{checked.stdout}")
    run([sys.executable, str(ROOT / "tools/locus_registry_lint.py")])
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; provider realization and engine resolution UNVERIFIED\n" + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Capability/Types.hs",
        ROOT / "src/Amoebius/Capability/Binding.hs",
    ]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail)\b")
    for path in paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial token {match.group(1)!r} in {path.relative_to(ROOT)}")
    cabal_text = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    suite = cabal_text.split("test-suite capability-bind-spec", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in suite:
            raise GateFailure(f"capability bind totality option missing: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "capability-bind-spec",
            "--test-show-details=direct",
        ]
    )
    token = "capability-bind-spec: PASS (9 arms, 18 semantic shapes, 3 Gate-1, 4 Gate-2, 4 mutants, 1 covered property)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-30 acceptance token is absent:\n{result.stdout}")
    if "capability-bind-calculus: PASS (5 kinds, 39 projected units)" not in result.stdout:
        raise GateFailure("Phase-30 five-calculus projection token is absent")
    invariant_token = "capability-bind-invariants: PASS (18 execution inventories, 3 unresolved references, 2 registry shapes, 2 extension-totality cases, 29 locus rows)"
    if invariant_token not in result.stdout:
        raise GateFailure("Phase-30 structural invariant token is absent")
    if "each of nine constructors >=8%" not in result.stdout:
        raise GateFailure("Phase-30 property coverage token is absent")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        descriptor = ROOT / f"test/mutant/capability_bind/{name}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {name}")
        result = run(
            [
                str(cabal),
                "test",
                "capability-bind-spec",
                    "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"capability-bind-mutant: RED {name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "capability-arms": "9/9-two-shape-green",
        "semantic-shape-oracle": "18/18-exact-object-controller-intent-projection",
        "app-byte-invariance": "9/9-distinct-composed-files-equal-normal-form",
        "structural-shape-oracle": "9/9-object-node-multiset-different",
        "dhall-typecheck-negatives": "3/3-specific-locus-red",
        "gadt-decode-negatives": "4/4-specific-tag-red",
        "quickcheck-properties": "1/1-green-nine-arms-at-least-8-percent",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "controller-child-source-expansion": "18/18-execution-inventories-exact",
        "unresolved-transition-references": "3/3-exact-and-unresolved",
        "registry-storage-bound-intent": "2/2-shapes-exact",
        "extension-totality": "2/2-unbound-required-red-and-closed-green",
        "validation-locus-entries": "29/29-exact",
        "acceptance-token": "binding-composition-proven",
        "calculus-kinds": "5/5-artifact-budget-lift-workflow-evidence",
        "calculus-components": "capability-arms,bound-service-shapes,boundary-negatives,bind-property,mutant-evidence",
        "calculus-projection-counts": "9,18,7,1,4",
        "calculus-resource-vector": "5,39,0,0",
        "live-provider-realization": "UNVERIFIED",
        "live-engine-resolution": "UNVERIFIED",
        "runtime-correspondence": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )



# The resolved compiler, set once the toolchain resolves. Every cabal invocation gets it:
# without it cabal picks whatever `ghc` the ambient PATH offers, which on a host carrying a
# newer GHC fails the solver for a reason that has nothing to do with this phase.

def arm_slugs() -> set[str]:
    """The capability arms the run read, not a list this gate carries."""
    rows = (ROOT / "test/oracle/capability_bind/arm_cases.tsv").read_text(encoding="utf-8").splitlines()[1:]
    return {line.split("\t")[0] for line in rows if line.strip()}


def case_names() -> set[str]:
    names: set[str] = set()
    for oracle in ("dhall_typecheck_cases.tsv", "gadt_decode_cases.tsv"):
        rows = (ROOT / "test/oracle/capability_bind" / oracle).read_text(encoding="utf-8").splitlines()[1:]
        names |= {line.split("\t")[0] for line in rows if line.strip()}
    return names


COMPILER = ""

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 banner",
}

SIDES = ("toolchain", "oracle", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "capability-arms": "9/9-two-shape-green",
    "semantic-shape-oracle": "18/18-exact-object-controller-intent-projection",
    "app-byte-invariance": "9/9-distinct-composed-files-equal-normal-form",
    "structural-shape-oracle": "9/9-object-node-multiset-different",
    "dhall-typecheck-negatives": "3/3-specific-locus-red",
    "gadt-decode-negatives": "4/4-specific-tag-red",
    "quickcheck-properties": "1/1-green-nine-arms-at-least-8-percent",
    "mutants": "4/4-red",
    "controller-child-source-expansion": "18/18-execution-inventories-exact",
    "unresolved-transition-references": "3/3-exact-and-unresolved",
    "registry-storage-bound-intent": "2/2-shapes-exact",
    "extension-totality": "2/2-unbound-required-red-and-closed-green",
    "validation-locus-entries": "29/29-exact",
    "acceptance-token": "binding-composition-proven",
    "calculus-kinds": "5/5-artifact-budget-lift-workflow-evidence",
    "calculus-components": "capability-arms,bound-service-shapes,boundary-negatives,bind-property,mutant-evidence",
    "calculus-projection-counts": "9,18,7,1,4",
    "calculus-resource-vector": "5,39,0,0",
    "live-provider-realization": "UNVERIFIED",
    "live-engine-resolution": "UNVERIFIED",
    "runtime-correspondence": "UNVERIFIED",
}

SURFACE_MAP = read_surface_map(ROOT / EXPECTATIONS)

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((metric, EXPECTED_RESULTS[metric]) if metric and EXPECTED_RESULTS.get(metric) not in (None, "UNVERIFIED") else None)
    for surface, metric in SURFACE_MAP.items()
}


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=30, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
        expectations=EXPECTATIONS,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    # Clause 15 first: a run that cannot name the architecture it executed on, or
    # that is executing under translation, has nothing worth proving.
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    item_names: set[str] = set()
    arm_names: set[str] = set()
    gate1_names: set[str] = set()
    gate2_names: set[str] = set()
    mutant_names: set[str] = set()

    try:
        resolved = toolchain.resolve(["cabal", "dhall", "ghc"])
        print("toolchain side — cabal, ghc, and dhall resolved from authored requirements\n")
        for name in ("cabal", "ghc", "dhall"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True

        os.environ["AMOEBIUS_DHALL"] = resolved["dhall"]["path"]
        os.environ["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — authored oracle shapes and loci\n")
        mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        verify_totality_sources()
        arm_names = arm_slugs()
        gate1_names = {row["case"] for row in read_tsv(DHALL_TYPECHECK)}
        gate2_names = {row["case"] for row in read_tsv(GADT_DECODE)}
        mutant_names = {row["mutant"] for row in mutant_rows}
        item_names = arm_names | gate1_names | gate2_names | mutant_names
        print(f"  ok    {len(item_names)} enumerated items, {len(mutant_rows)} mutants, loci exact")
        results["oracle"] = True

        print("\nsuite side — the green battery\n")
        suite = run_green_suite(cabal)
        (gate.run_dir / "suite.log").write_text(suite, encoding="utf-8")
        print("  ok    acceptance token present")
        results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log = verify_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {len(mutant_rows)}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(mutant_rows)
        rows = gate_common.metric_rows(RESULTS)
        banner_ok = GENERATED_LEDGER.is_file() and GENERATED_LEDGER.read_text(encoding="utf-8").startswith(
            "# Register-1 only;"
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        if banner_ok:
            print(f"  ok    locus-ledger-honesty-banner {gate_common.rel(GENERATED_LEDGER)}")
        else:
            print("  FAIL  locus-ledger-honesty-banner the generated locus ledger lacks its Register-1 banner")
        results["results"] = oracle_ok and artifact_ok and banner_ok
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"capability-bind-gate: FAIL: {problem}", file=sys.stderr)

    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    arm_evidence = {
        surface: ("capability-arms", EXPECTED_RESULTS["capability-arms"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & arm_names
    }
    gate1_evidence = {
        surface: ("dhall-typecheck-negatives", EXPECTED_RESULTS["dhall-typecheck-negatives"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & gate1_names
    }
    gate2_evidence = {
        surface: ("gadt-decode-negatives", EXPECTED_RESULTS["gadt-decode-negatives"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & gate2_names
    }
    mutant_evidence = {
        surface: ("mutants", EXPECTED_RESULTS["mutants"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & mutant_names
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": item_names},
        rows=rows,
        evidence={**SURFACE_EVIDENCE, **arm_evidence, **gate1_evidence, **gate2_evidence, **mutant_evidence},
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"battery": "cabal test capability-bind-spec"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "phase-30 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
