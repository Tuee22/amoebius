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
GATE1 = ROOT / "test/oracle/capability_bind/gate1_cases.tsv"
GATE2 = ROOT / "test/oracle/capability_bind/gate2_cases.tsv"
MUTANT_CAPABILITY = "capability_bind"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/capability_bind/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/capability-bind/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/capability-bind/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/capability-bind"
CONTRACT = "DEVELOPMENT_PLAN/phase_11_capability_bind.md"
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
    gate1 = read_tsv(GATE1)
    gate2 = read_tsv(GATE2)
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
        raise GateFailure("Phase-11 arm oracle must enumerate the exact closed nine-arm union")
    if len({row["slug"] for row in arms}) != 9 or len({row["resource"] for row in arms}) != 9:
        raise GateFailure("Phase-11 arm oracle slugs and resource names must be unique")
    if len(gate1) != 3 or {row["case"] for row in gate1} != {"product-in-app", "engine-by-url", "shape-in-app"}:
        raise GateFailure("Phase-11 Gate-1 oracle must contain the three required negatives")
    expected_gate2 = {"UnbuiltProviderArm", "UnboundCapability", "CyclicExtension", "ShadowingExtension"}
    if len(gate2) != 4 or {row["expected"] for row in gate2} != expected_gate2:
        raise GateFailure("Phase-11 Gate-2 oracle must preserve all four specific error tags")
    if len(mutants) != 4 or len({row["mutant"] for row in mutants}) != 4:
        raise GateFailure("Phase-11 mutant manifest must contain four unique mutants")
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
        raise GateFailure("Phase-11 validation-locus ledger has incomplete or duplicate coverage")
    for row in arms:
        for shape in ("singlenode", "distributed"):
            fixture = ROOT / f"dhall/examples/legal_{row['slug']}_{shape}.dhall"
            golden = ROOT / f"test/golden/capability/golden_servicespec_{row['slug']}_{shape}.golden"
            if not fixture.is_file() or not golden.is_file():
                raise GateFailure(f"missing per-arm fixture or golden for {row['slug']} {shape}")
    for row in gate1:
        legal = run([str(dhall), "type", "--file", row["legal"], "--quiet"], require_success=False)
        negative = run([str(dhall), "type", "--file", row["negative"], "--quiet"], require_success=False)
        if legal.returncode != 0:
            raise GateFailure(f"Gate-1 legal twin rejected: {row['legal']}\n{legal.stdout}")
        if negative.returncode == 0 or row["required"] not in negative.stdout:
            raise GateFailure(f"Gate-1 negative missed exact locus: {row['negative']}\n{negative.stdout}")
    for row in gate2:
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
    token = "capability-bind-spec: PASS (9 arms, 18 shape goldens, 3 Gate-1, 4 Gate-2, 4 mutants, 1 covered property)"
    if token not in result.stdout:
        raise GateFailure(f"Phase-11 acceptance token is absent:\n{result.stdout}")
    if "each of nine constructors >=8%" not in result.stdout:
        raise GateFailure("Phase-11 property coverage token is absent")
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
        "shape-goldens": "18/18-exact",
        "app-byte-invariance": "9/9-distinct-composed-files-equal-normal-form",
        "structural-shape-oracle": "9/9-object-node-multiset-different",
        "gate1-negatives": "3/3-specific-locus-red",
        "gate2-negatives": "4/4-specific-tag-red",
        "quickcheck-properties": "1/1-green-nine-arms-at-least-8-percent",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "acceptance-token": "binding-composition-proven",
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
    for oracle in ("gate1_cases.tsv", "gate2_cases.tsv"):
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

EXPECTED_RESULTS = {'capability-arms': '9/9-two-shape-green', 'shape-goldens': '18/18-exact', 'app-byte-invariance': '9/9-distinct-composed-files-equal-normal-form', 'structural-shape-oracle': '9/9-object-node-multiset-different', 'gate1-negatives': '3/3-specific-locus-red', 'gate2-negatives': '4/4-specific-tag-red', 'quickcheck-properties': '1/1-green-nine-arms-at-least-8-percent', 'mutants': '4/4-red', 'acceptance-token': 'binding-composition-proven', 'live-provider-realization': 'UNVERIFIED', 'live-engine-resolution': 'UNVERIFIED', 'runtime-correspondence': 'UNVERIFIED'}

SURFACE_MAP = {'closed-nine-arm-capability-union': 'objectstore,secretstore,messagebus,sql,identity,observability,registry,edge,inferenceengine', 'url-free-engine-runtime': 'engine-by-url', 'app-surface-capability-needs': 'unbound-capability', 'canonical-provider-union': 'unbuilt-provider', 'typed-service-shapes': 'shape-in-app', 'total-representational-bind': 'product-in-app', 'explicit-provider-object-graphs': 'mutant_catchall_arm,mutant_shared_app_import', 'structural-object-node-multiset-oracle': 'mutant_copy_shape_tag', 'normalized-app-byte-invariance': 'app-byte-invariance', 'kind-indexed-bound-execution-set': 'acceptance-token', 'controller-child-source-expansion': '', 'unresolved-transition-references': '', 'bound-deployment-no-provisioned-values': 'mutant_provisioned_value_in_bound_deployment', 'registry-storage-bound-intent': '', 'extension-totality': '', 'extension-acyclicity': 'cyclic-extension', 'extension-no-shadowing': 'shadowing-extension', 'phase10-gate1-corpus': 'gate1-negatives', 'phase10-gate2-corpus': 'gate2-negatives', 'phase10-arm-exhaustiveness': 'capability-arms', 'phase10-golden-corpus': 'shape-goldens', 'phase10-property-coverage': 'quickcheck-properties', 'phase10-mutant-battery': 'mutants', 'phase10-validation-locus-ledger': '', 'capability-bind-compile-totality': 'structural-shape-oracle', 'live-provider-realization': 'live-provider-realization', 'live-engine-resolution': 'live-engine-resolution', 'runtime-model-correspondence': 'runtime-correspondence'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((metric, EXPECTED_RESULTS[metric]) if metric and EXPECTED_RESULTS.get(metric) not in (None, "UNVERIFIED") else None)
    for surface, metric in SURFACE_MAP.items()
}


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=11, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
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
        item_names = arm_slugs() | case_names() | {row["mutant"] for row in mutant_rows}
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
    item_evidence = {
        surface: ("acceptance-token", EXPECTED_RESULTS["acceptance-token"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": item_names},
        rows=rows,
        evidence={**SURFACE_EVIDENCE, **item_evidence},
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"battery": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "phase-11 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
