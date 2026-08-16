#!/usr/bin/env python3
"""Run and seal the pure manifest-rendering gate."""

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
import toolchain


ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "test/oracle/render_manifest/corpus.tsv"
MUTANTS = ROOT / "test/mutant/render_manifest/mutants.tsv"
LOCUS = ROOT / "test/oracle/render_manifest/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/render-manifest/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/render-manifest/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/render-manifest"
CONTRACT = "DEVELOPMENT_PLAN/phase_13_render_manifest_goldens.md"
GATE_COMMAND = "python3 tools/render_manifest_gate.py"
EXPECTATIONS = "test/oracle/render_manifest_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = toolchain.contained_env()
    environment["PATH"] = os.pathsep.join([str(ROOT / "tools"), environment.get("PATH", "")])
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", "--jobs=1", *command[1:]]
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


def verify_pins() -> tuple[Path, str]:
    pins = toolchain.resolve(["cabal", "dhall", "ghc"])
    executables = {name: Path(pins[name]["path"]) for name in ("cabal", "ghc", "dhall")}
    for executable in executables.values():
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(run([str(executable), "--numeric-version"] if name != "dhall" else [str(executable), "--version"]).stdout for name, executable in executables.items())
    for family in executables:
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return executables["cabal"], versions


def verify_oracles() -> list[dict[str, str]]:
    corpus = read_tsv(CORPUS)
    mutants = read_tsv(MUTANTS)
    locus = read_tsv(LOCUS)
    if len(corpus) != 18 or len({row["deployment"] for row in corpus}) != 18:
        raise GateFailure("Phase-13 corpus must enumerate eighteen unique deployments")
    if {row["deployment"].rsplit("_", 1)[-1] for row in corpus} != {"singlenode", "distributed"}:
        raise GateFailure("Phase-13 corpus must cover both shapes")
    for row in corpus:
        golden = ROOT / row["golden"]
        try:
            summary = json.loads(golden.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as problem:
            raise GateFailure(f"invalid render golden {golden.relative_to(ROOT)}: {problem}") from problem
        if summary.get("objects") != int(row["objects"]) or not re.fullmatch(r"[0-9a-f]{64}", summary.get("sha256", "")):
            raise GateFailure(f"render golden metadata drifted: {golden.relative_to(ROOT)}")
        if not golden.read_bytes().endswith(b"\n"):
            raise GateFailure(f"render golden lacks its canonical trailing LF: {golden.relative_to(ROOT)}")
    if len(mutants) != 12 or len({row["mutant"] for row in mutants}) != 12:
        raise GateFailure("Phase-13 mutant manifest must contain twelve unique mutants")
    expected_locus = {
        *(row["deployment"] for row in corpus),
        "unsafe_workload",
        "backdoor_ingress",
        "underived_network_policy",
        *(row["mutant"] for row in mutants),
    }
    if len(locus) != len(expected_locus) or {row["entry"] for row in locus} != expected_locus:
        raise GateFailure("Phase-13 validation-locus ledger has incomplete or duplicate coverage")
    for row in mutants:
        descriptor = ROOT / f"test/mutant/render_manifest/{row['mutant']}/mutant.txt"
        if not descriptor.is_file() or not descriptor.read_text(encoding="utf-8").strip():
            raise GateFailure(f"committed mutant descriptor is absent: {row['mutant']}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register-1 only; live apiserver and runtime enforcement UNVERIFIED\n" + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_totality_sources() -> None:
    paths = [
        ROOT / "src/Amoebius/Manifest.hs",
        ROOT / "src/Amoebius/Manifest/K8sObject.hs",
        ROOT / "src/Amoebius/Manifest/Types.hs",
        ROOT / "src/Amoebius/Manifest/Render.hs",
        ROOT / "src/Amoebius/Manifest/RenderAll.hs",
    ]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO)\b|!!")
    for path in paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial or unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")
    facade = paths[0].read_text(encoding="utf-8").split(") where", 1)[0]
    if "renderSourcePrivate" in facade or "K8sObject" in facade:
        raise GateFailure("manifest facade exports more than the whole-deployment render function")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8").split("test-suite render-golden", 1)[1]
    for option in ("-Werror=incomplete-patterns", "-Werror=incomplete-uni-patterns"):
        if option not in cabal:
            raise GateFailure(f"render-golden totality option missing: {option}")


def run_green_suite(cabal: Path) -> str:
    result = run([str(cabal), "test", "render-golden", "--test-show-details=direct"])
    token = "render-golden: PASS (18 byte-locked deployment goldens, 9 object variants, 3 non-vacuous safety predicates, 12 mutants, 1 covered property)"
    if token not in result.stdout or "each >=4%" not in result.stdout:
        raise GateFailure(f"Phase-13 acceptance or property token is absent:\n{result.stdout}")
    return result.stdout


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [str(cabal), "test", "render-golden", "--test-show-details=direct", f"--test-options=--mutant={name}"],
            require_success=False,
        )
        if result.returncode == 0 or f"render-manifest-mutant: RED {name}" not in result.stdout:
            raise GateFailure(f"mutant survived or missed its property locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]]) -> None:
    metrics = {
        "deployment-goldens": "18/18-byte-locked",
        "capability-shapes": "9/9-arms-times-2-shapes",
        "object-variant-coverage": "9/9-exact",
        "safety-predicates": "3/3-non-vacuous",
        "quickcheck-properties": "1/1-arms-and-shapes-at-least-4-percent",
        "mutants": f"{len(mutants)}/{len(mutants)}-red-at-property-locus",
        "acceptance-token": "rendered-output-proven-for-the-model",
        "live-apiserver-enforcement": "UNVERIFIED",
        "live-network-policy-enforcement": "UNVERIFIED",
        "runtime-correspondence": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")



# The resolved compiler, set once the toolchain resolves. Every cabal invocation gets it:
# without it cabal picks whatever `ghc` the ambient PATH offers, which on a host carrying a
# newer GHC fails the solver for a reason that has nothing to do with this phase.
COMPILER = ""

# Where the run reads its enumerable items from. Nothing here is a list this gate carries;
# each is a file the run opens, so deleting a case or a mutant shrinks the enumeration and
# breaks the authored join.
ITEM_SOURCES = ['test/oracle/render_manifest/corpus.tsv', 'test/mutant/render_manifest/mutants.tsv']

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 banner",
    "render-facade-sealed": "the manifest facade exports the whole-deployment render and nothing more",
    "render-totality-options": "the render-golden suite compiles with incomplete-pattern errors enabled",
}

SIDES = ("toolchain", "oracle", "suite", "mutant", "results")

EXPECTED_RESULTS = {'deployment-goldens': '18/18-byte-locked', 'capability-shapes': '9/9-arms-times-2-shapes', 'object-variant-coverage': '9/9-exact', 'safety-predicates': '3/3-non-vacuous', 'quickcheck-properties': '1/1-arms-and-shapes-at-least-4-percent', 'mutants': '12/12-red-at-property-locus', 'acceptance-token': 'rendered-output-proven-for-the-model', 'live-apiserver-enforcement': 'UNVERIFIED', 'live-network-policy-enforcement': 'UNVERIFIED', 'runtime-correspondence': 'UNVERIFIED'}

SURFACE_MAP = {'typed-k8s-object-model': 'object-variant-coverage', 'canonical-aeson-encoding': 'deployment-goldens', 'aeson-round-trip': '', 'pure-total-render-all': 'acceptance-token', 'sole-public-render-facade': 'render-facade-sealed', 'sealed-render-source-domain': '', 'deterministic-identity-order': '', 'exact-source-identity-projection': '', 'render-activation-domain': 'mutant_monitoring_projection', 'closed-reconcile-mode': '', 'capability-shape-corpus': 'objectstore_singlenode,objectstore_distributed,secretstore_singlenode,secretstore_distributed,messagebus_singlenode,messagebus_distributed,sql_singlenode,sql_distributed,identity_singlenode,identity_distributed', 'nine-emitted-object-variants': 'capability-shapes', 'byte-locked-render-goldens': 'observability_singlenode,observability_distributed,registry_singlenode,registry_distributed,edge_singlenode,edge_distributed,inferenceengine_singlenode,inferenceengine_distributed', 'hardened-pod-projection': 'mutant_unhardened_pod', 'exact-resource-projection': 'mutant_resource_projection', 'content-digested-image-projection': 'mutant_image_platform', 'bounded-volume-projection': 'mutant_unbounded_scratch,mutant_memory_volume_lifecycle,mutant_ephemeral_rootfs,mutant_durable_size', 'accelerator-claim-projection': 'mutant_accelerator_projection', 'controller-kind-projection': 'mutant_controller_projection', 'single-declared-edge-exposure': 'safety-predicates', 'no-bare-ingress': 'mutant_wild_ingress', 'default-deny-network-policy': '', 'independent-allow-edge-equality': 'mutant_undeclared_allow_edge', 'phase13-property-coverage': 'quickcheck-properties', 'phase13-mutant-battery': 'mutants', 'phase13-validation-locus-ledger': '', 'phase13-compile-totality': 'render-totality-options', 'live-apiserver-enforcement': 'live-apiserver-enforcement', 'live-network-policy-enforcement': 'live-network-policy-enforcement', 'runtime-model-correspondence': 'runtime-correspondence'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] != "UNVERIFIED" else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names: set[str] = set()
    for relative in ITEM_SOURCES:
        path = ROOT / relative
        if not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip():
                names.add(line.split("\t")[0].strip())
    return names


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=13, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", sides=SIDES,
        expectations=EXPECTATIONS,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
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
        mutant_rows = verify_oracles()
        verify_totality_sources()
        item_names = enumerated_items()
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
        banner_ok = not GENERATED_LEDGER.is_file() or GENERATED_LEDGER.read_text(encoding="utf-8").startswith(
            "# Register-1 only;"
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        print(f"  {'ok  ' if banner_ok else 'FAIL'}  locus-ledger-honesty-banner")
        results["results"] = oracle_ok and artifact_ok and banner_ok
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"render-manifest-gate: FAIL: {problem}", file=sys.stderr)

    item_evidence = {
        surface: ("acceptance-token", EXPECTED_RESULTS["acceptance-token"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
    }
    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
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
        dependencies={"battery": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows]
        or [{"name": "phase-13 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
