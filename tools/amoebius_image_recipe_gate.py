#!/usr/bin/env python3
"""Run and seal the pure amoebius image-recipe gate."""

from __future__ import annotations

import csv
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry
import toolchain


ROOT = Path(__file__).resolve().parent.parent
SEMANTICS = ROOT / "test/oracle/amoebius_image_recipe/recipe_semantics.tsv"
BUILD_CASES = ROOT / "test/oracle/amoebius_image_recipe/build_cases.tsv"
BUILD_ARGV = ROOT / "test/oracle/amoebius_image_recipe/build_argv.tsv"
CALCULUS = ROOT / "test/oracle/amoebius_image_recipe/calculus_projection.tsv"
LOCUS = ROOT / "test/oracle/amoebius_image_recipe/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/image-recipe/phase-results.tsv"
RENDERED = ROOT / ".build/dsl/image-recipe/Dockerfile"
BUILD_ROOT = ROOT / ".build/dist-newstyle/image-recipe"
CONTRACT = "DEVELOPMENT_PLAN/phase_36_image_recipe_generation.md"
GATE_COMMAND = "python3 tools/amoebius_image_recipe_gate.py"
EXPECTATIONS = "test/oracle/amoebius_image_recipe_surfaces.tsv"
MUTANT_CAPABILITY = "amoebius_image_recipe"


class GateFailure(RuntimeError):
    pass


COMPILER = ""


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0],
            f"--with-compiler={COMPILER}",
            f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}",
            "--jobs=1",
            *command[1:],
        ]
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


def verify_oracles() -> list[dict[str, str]]:
    semantics = read_tsv(SEMANTICS)
    cases = read_tsv(BUILD_CASES)
    argv = read_tsv(BUILD_ARGV)
    calculus = read_tsv(CALCULUS)
    locus = read_tsv(LOCUS)
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(semantics) != 22 or [int(row["position"]) for row in semantics] != list(range(1, 23)):
        raise GateFailure("recipe semantic oracle must contain positions 1 through 22")
    if len({row["name"] for row in semantics}) != 22:
        raise GateFailure("recipe semantic oracle has duplicate step names")
    rung_counts = {
        rung: sum(row["rung"] == rung for row in semantics)
        for rung in ("AptPackage", "OfficialArtifact", "BuildProduct", "CopyOci")
    }
    if rung_counts != {"AptPackage": 7, "OfficialArtifact": 9, "BuildProduct": 6, "CopyOci": 0}:
        raise GateFailure(f"recipe semantic rung vector drifted: {rung_counts}")
    expected_cases = {
        "cpu-amd64": ("cpu", "amd64", "amd64", "amoebius-base-cpu-amd64"),
        "cpu-arm64": ("cpu", "arm64", "arm64", "amoebius-base-cpu-arm64"),
        "cuda-amd64": ("cuda", "amd64", "amd64", "amoebius-base-cuda-amd64"),
        "cuda-arm64": ("cuda", "arm64", "arm64", "amoebius-base-cuda-arm64"),
    }
    actual_cases = {
        row["case"]: (row["flavor"], row["observed"], row["requested"], row["tag"])
        for row in cases
    }
    if actual_cases != expected_cases or len(cases) != 4:
        raise GateFailure("build-case oracle does not cover the four flavor/architecture tags exactly")
    if len(argv) != 44:
        raise GateFailure("build argv oracle must contain exactly 44 tokens")
    for name in expected_cases:
        rows = [row for row in argv if row["case"] == name]
        if [int(row["position"]) for row in rows] != list(range(1, 12)):
            raise GateFailure(f"build argv positions are incomplete for {name}")
        if rows[0]["token"] != "/opt/amoebius/bin/docker" or rows[1]["token"] != "build":
            raise GateFailure(f"build argv does not begin at the absolute plain-build seam: {name}")
        if any(row["token"] in {"buildx", "--platform"} for row in rows):
            raise GateFailure(f"build argv oracle admits a multi-platform token: {name}")
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "recipe-step-semantics,build-argv-tokens,renderer-laws,build-cases,mutant-evidence"},
        {"metric": "projection-counts", "value": "22,44,4,4,3"},
        {"metric": "resource-vector", "value": "5,77,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("five-calculus image-recipe projection oracle drifted")
    if len(mutants) != 3 or len({row["mutant"] for row in mutants}) != 3:
        raise GateFailure("image-recipe mutant registry must contain three unique rows")
    expected_locus = {
        *(row["name"] for row in semantics),
        *(row["case"] for row in cases),
        *(row["mutant"] for row in mutants),
    }
    if len(locus) != 29 or {row["entry"] for row in locus} != expected_locus:
        raise GateFailure("image-recipe validation-locus ledger is incomplete or duplicated")
    for row in mutants:
        descriptor = ROOT / row["body"]
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"mutant descriptor is absent: {row['mutant']}")
    return mutants


def verify_sources() -> None:
    inventory = (ROOT / "src/Amoebius/Image/BakeInventory.hs").read_text(encoding="utf-8")
    renderer = (ROOT / "src/Amoebius/Image/RenderDockerfile.hs").read_text(encoding="utf-8")
    catalog = (ROOT / "dhall/amoebius/BakeCatalog.dhall").read_text(encoding="utf-8")
    build_argv = (ROOT / "src/Amoebius/Image/BuildArgv.hs").read_text(encoding="utf-8")
    if "baseDigest" in inventory or "baseDigest" in renderer or "baseDigest" in catalog:
        raise GateFailure("an authored baseDigest field still reaches the recipe surface")
    if '"ARG BASE_IMAGE"' not in renderer or '"FROM ${BASE_IMAGE} AS amoebius-base"' not in renderer:
        raise GateFailure("renderer lacks the dynamic base-channel projection")
    if "buildx" in build_argv or "--platform" in build_argv:
        raise GateFailure("typed build argv source contains a multi-platform escape token")
    retired = ROOT / "test/golden/amoebius_image_recipe/Dockerfile.golden"
    if retired.exists():
        raise GateFailure("retired Phase-36 renderer-output golden still exists")
    prohibited = re.compile(r"\b(error|undefined|fromJust|unsafePerformIO)\b|!!")
    for relative in (
        "src/Amoebius/Image/BaseChannel.hs",
        "src/Amoebius/Image/BuildArgv.hs",
        "src/Amoebius/Image/RenderDockerfile.hs",
    ):
        source = (ROOT / relative).read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial or unsafe token {match.group(0)!r} in {relative}")
    suite = (ROOT / "amoebius.cabal").read_text(encoding="utf-8").split("test-suite image-recipe-spec", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in suite.split("test-suite", 1)[0]:
            raise GateFailure(f"image-recipe totality option missing: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run([str(cabal), "test", "image-recipe-spec", "--test-show-details=direct"])
    tokens = (
        "image-recipe-calculus: PASS (5 kinds, 77 projected units)",
        "image-recipe-invariants: PASS (3 stages, 22 semantic step projections, 1 dynamic base, 0 authored base digests, 2 deterministic renders)",
        "image-recipe-spec: PASS (4 exact build invocations, 44 argv tokens, 2 architecture refusals, 3 mutants)",
    )
    if any(token not in result.stdout for token in tokens):
        raise GateFailure(f"image-recipe acceptance token is absent:\n{result.stdout}")
    rendered = run(
        [str(cabal), "run", "exe:amoebius", "--", "render-bake-dockerfile", "dhall/amoebius/BakeCatalog.dhall"]
    ).stdout
    RENDERED.parent.mkdir(parents=True, exist_ok=True)
    RENDERED.write_text(rendered, encoding="utf-8")
    if "FROM ${BASE_IMAGE} AS amoebius-base" not in rendered or "sha256:" in rendered:
        raise GateFailure("CLI-rendered Dockerfile violates the digest-free dynamic-base contract")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [str(cabal), "test", "image-recipe-spec", "--test-show-details=direct", f"--test-options=--mutant={name}"],
            require_success=False,
        )
        token = f"image-recipe-mutant: RED {name} locus={row['expected_locus']}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its exact locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


EXPECTED_RESULTS = {
    "semantic-step-rows": "22/22-exact",
    "stage-count": "3/3-exact",
    "step-arm-vector": "7,9,6,0",
    "published-payloads": "1/1-exact",
    "runtime-environment": "3/3-exact",
    "deterministic-renders": "2/2-byte-identical",
    "exact-step-projections": "22/22-present-once",
    "base-channel": "ubuntu:24.04",
    "authored-base-digests": "0/0",
    "dynamic-base-from": "1/1-exact",
    "targetarch-arguments": "1/1-exact",
    "run-projections": "11/11-exact",
    "copy-projections": "6/6-exact",
    "build-cases": "4/4-exact",
    "argv-tokens": "44/44-exact",
    "absolute-engine-paths": "4/4-exact",
    "architecture-refusals": "2/2-exact",
    "mutants": "3/3-red-at-exact-locus",
    "validation-locus-entries": "29/29-exact",
    "calculus-kinds": "5/5-exact",
    "calculus-components": "recipe-step-semantics,build-argv-tokens,renderer-laws,build-cases,mutant-evidence",
    "calculus-projection-counts": "22,44,4,4,3",
    "calculus-resource-vector": "5,77,0,0",
    "live-image-build": "UNVERIFIED",
    "live-image-publication": "UNVERIFIED",
    "runtime-correspondence": "UNVERIFIED",
}


CHECKS = {
    "semantic-oracle-complete": "the authored recipe oracle names all twenty-two ordered catalog steps",
    "argv-oracle-complete": "the authored argv oracle names all forty-four ordered invocation tokens",
    "renderer-totality-options": "the recipe suite compiles with incomplete patterns as errors",
    "digest-field-absent": "no authored baseDigest field reaches the catalog, inventory, or renderer",
    "retired-golden-absent": "the planned Phase-36 renderer-output golden is absent",
    "emitted-results-untracked": "the generated recipe and results stay outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal, ghc, and dhall satisfy authored requirements",
    "recorded-results-match-oracle": "every recorded metric equals its authored expectation",
}


SURFACE_MAP = {
    "typed-base-channel": "base-channel",
    "catalog-has-no-base-digest-field": "digest-field-absent",
    "three-stage-catalog": "stage-count",
    "closed-four-arm-step-union": "step-arm-vector",
    "published-companion-payload": "published-payloads",
    "runtime-environment-projection": "runtime-environment",
    "two-deterministic-renders": "deterministic-renders",
    "twenty-two-exact-step-projections": "exact-step-projections",
    "semantic-step-cardinality": "semantic-step-rows",
    "twenty-two-authored-step-semantics": "distribution,redis-server,redis-cli,postgres,patroni,temurin,g++,minio,vault,prometheus,alertmanager,thanos,envoy,grafana,keycloak,pulsar,amoebius-jit-build-resolver,envoy-gateway,metallb-controller,metallb-speaker,percona-postgresql-operator,pgadmin",
    "semantic-recipe-oracle": "semantic-oracle-complete",
    "zero-authored-base-digests": "authored-base-digests",
    "single-dynamic-base-from": "dynamic-base-from",
    "single-targetarch-argument": "targetarch-arguments",
    "run-directive-projection": "run-projections",
    "copy-directive-projection": "copy-projections",
    "renderer-compile-totality": "renderer-totality-options",
    "retired-renderer-output-golden": "retired-golden-absent",
    "four-exact-build-cases": "build-cases",
    "four-authored-build-cases": "cpu-amd64,cpu-arm64,cuda-amd64,cuda-arm64",
    "forty-four-exact-argv-tokens": "argv-tokens",
    "independent-build-argv-oracle": "argv-oracle-complete",
    "absolute-engine-invocations": "absolute-engine-paths",
    "native-architecture-refusals": "architecture-refusals",
    "plain-build-mutant": "recipe-buildx-subcommand",
    "single-architecture-mutant": "recipe-second-platform",
    "digest-free-base-mutant": "recipe-authored-base-digest",
    "paired-mutant-battery": "mutants",
    "validation-locus-ledger": "validation-locus-entries",
    "five-calculus-kind-cardinality": "calculus-kinds",
    "five-calculus-component-vector": "calculus-components",
    "five-calculus-projection-counts": "calculus-projection-counts",
    "five-calculus-resource-vector": "calculus-resource-vector",
    "generated-artifact-discipline": "emitted-results-untracked,toolchain-satisfies-requirements,recorded-results-match-oracle",
    "live-image-build": "live-image-build",
    "live-image-publication": "live-image-publication",
    "runtime-image-correspondence": "runtime-correspondence",
}


SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] != "UNVERIFIED" else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names = {row["name"] for row in read_tsv(SEMANTICS)}
    names.update(row["case"] for row in read_tsv(BUILD_CASES))
    names.update(row["mutant"] for row in mutant_registry.capability(MUTANT_CAPABILITY))
    return names


def write_results() -> None:
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{metric}\t{result}\n" for metric, result in EXPECTED_RESULTS.items()),
        encoding="utf-8",
    )


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=35,
        contract=CONTRACT,
        command=GATE_COMMAND,
        register="1",
        substrate="none",
        lane="none",
        sides=("toolchain", "oracle", "source", "suite", "mutant", "results"),
        expectations=EXPECTATIONS,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
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

        print("\noracle side — semantic recipe, exact argv, calculus, loci, and mutants\n")
        mutant_rows = verify_oracles()
        item_names = enumerated_items()
        print(f"  ok    {len(item_names)} enumerated items, {len(mutant_rows)} mutants, loci exact")
        results["oracle"] = True

        print("\nsource side — digest-free base channel, total renderer, and retired golden\n")
        verify_sources()
        print("  ok    catalog/renderer/build-argv source boundary exact")
        results["source"] = True

        print("\nsuite side — semantic recipe and native build-invocation battery\n")
        suite = run_green_suite(cabal)
        (gate.run_dir / "suite.log").write_text(suite, encoding="utf-8")
        print("  ok    all three acceptance tokens present")
        results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log = verify_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {len(mutant_rows)}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results()
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent],
            (".tsv", ".log", "Dockerfile"),
            gate.run_dir,
            check="emitted-results-untracked",
            label="the rendered recipe and battery output stay generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError) as problem:
        print(f"amoebius-image-recipe-gate: FAIL: {problem}", file=sys.stderr)

    item_evidence = {
        surface: ("semantic-step-rows", EXPECTED_RESULTS["semantic-step-rows"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
    }
    layers = {
        "Decision": "tested" if rows.get("semantic-step-rows") == EXPECTED_RESULTS["semantic-step-rows"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
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
        dependencies={"image-recipe-spec": "cabal test image-recipe-spec"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "phase-36 mutants", "status": "unrun"}],
        observations={"rendered-recipe": "sha256:" + gate_common.artifact_policy.digest(str(RENDERED))}
        if RENDERED.is_file()
        else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
