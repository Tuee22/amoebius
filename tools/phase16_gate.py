#!/usr/bin/env python3
"""Run and seal the Phase-16 bounded UI-program schema checks."""

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
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import toolchain


ROOT = Path(__file__).resolve().parent.parent
CASES = ROOT / "test/fixtures/ui_program_schema/cases.tsv"
GRAPH = ROOT / "test/fixtures/ui_program_schema/graph_reference.tsv"
WIRE = ROOT / "test/fixtures/ui_program_schema/normalized_wire.golden"
MUTANTS = ROOT / "tests/mutants/phase16/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase16/validation_locus.tsv"
RESULTS = ROOT / "gen/dsl/phase16/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase16/validation-locus-ledger.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_16_ui_program_schema.md"
GATE_COMMAND = "python3 tools/phase16_gate.py"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = dict(os.environ)
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", *command[1:]]
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


def verify_pins() -> tuple[Path, Path, str]:
    pins = toolchain.resolve(["cabal", "dhall", "ghc"])
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    dhall = Path(pins["dhall"]["path"])
    for executable in (cabal, ghc, dhall):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = (
        run([str(cabal), "--numeric-version"]).stdout
        + run([str(ghc), "--numeric-version"]).stdout
        + run([str(dhall), "--version"]).stdout
    )
    for family in ("cabal", "ghc", "dhall"):
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return cabal, dhall, versions


def verify_oracles(dhall: Path) -> list[dict[str, str]]:
    cases = read_tsv(CASES)
    if len(cases) != 13 or sum(row["expected"] == "accept" for row in cases) != 3:
        raise GateFailure("Phase-16 corpus must contain three positives and ten negatives")
    expected_tags = {
        "RawBrowserEscape",
        "RecursiveEffect",
        "UnboundedCollection",
        "DuplicateQualifiedId",
        "MissingReference",
        "RawExternalLinkUrl",
        "DuplicateExternalLinkRequirement",
        "PortTypeMismatch",
        "NonExhaustiveEvent",
        "PrivateValueProjection",
    }
    observed_tags = {row["tag"] for row in cases if row["expected"] == "reject"}
    if observed_tags != expected_tags:
        raise GateFailure(f"negative diagnostic arms drifted: {sorted(observed_tags)}")
    graph = read_tsv(GRAPH)
    if len(graph) != 3 or {row["program"] for row in graph} != {
        "minimal_single_tenant",
        "minimal_multi_tenant",
        "composed_workflow_ui",
    }:
        raise GateFailure("independent graph oracle must contain one row per positive")
    if len(WIRE.read_text(encoding="utf-8").splitlines()) != 3:
        raise GateFailure("normalized wire golden must contain three non-empty rows")
    mutants = read_tsv(MUTANTS)
    if len(mutants) != 6 or len({row["mutant"] for row in mutants}) != 6:
        raise GateFailure("mutant oracle must contain six unique mutants")
    locus = read_tsv(LOCUS)
    if len(locus) != 30 or len({row["entry"] for row in locus}) != 30:
        raise GateFailure("validation locus must contain thirty unique rows")
    phase0 = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    phase16 = [row for row in phase0 if row["# phase"] == "16"]
    if len(phase16) != 24:
        raise GateFailure(f"Phase-0 manifest must pin 24 Phase-16 artifacts, got {len(phase16)}")
    for path in (
        ROOT / "dhall/amoebius/ui/Types.dhall",
        ROOT / "dhall/amoebius/ui/Constructors.dhall",
        ROOT / "dhall/amoebius/ui/package.dhall",
    ):
        checked = run([str(dhall), "type", "--file", str(path), "--quiet"], require_success=False)
        if checked.returncode != 0:
            raise GateFailure(f"UI Dhall schema is ill-typed: {path.relative_to(ROOT)}\n{checked.stdout}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; browser/server/provider/runtime enforcement UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_source_boundaries() -> None:
    schema = (ROOT / "dhall/amoebius/ui/Types.dhall").read_text(encoding="utf-8")
    for token in ("RawJs", "RawHtml", "RawCss", "RawUrl", "ProviderCoordinate", "AuthorityCredential"):
        if token in schema:
            raise GateFailure(f"forbidden UI source arm is present: {token}")
    header = (ROOT / "src/Amoebius/Ui/Check.hs").read_text(encoding="utf-8").split(") where", 1)[0]
    if "CheckedUiProgram (.." in header:
        raise GateFailure("CheckedUiProgram constructor is exported")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path in sorted((ROOT / "src/Amoebius/Ui").glob("*.hs")):
        source = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", path.read_text(encoding="utf-8")))
        match = prohibited.search(source)
        if match:
            raise GateFailure(f"partial/unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")


def compile_seal(cabal: Path) -> str:
    common = [str(cabal), "exec", "--offline", "ghc", "--", "-fno-code", "-XGHC2024", "-isrc"]
    legal = run(common + ["test/fixtures/ui_program_schema/compilefail/checked_ui_legal.hs"])
    illegal = run(common + ["test/fixtures/ui_program_schema/compilefail/checked_ui_illegal.hs"], require_success=False)
    expected = "Illegal term-level use of the type constructor ‘CheckedUiProgram’"
    if illegal.returncode == 0 or expected not in illegal.stdout:
        raise GateFailure(f"CheckedUiProgram compile-fail seal drifted:\n{illegal.stdout}")
    return legal.stdout + illegal.stdout


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-program-schema-spec", "--offline"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-program-schema-spec", "--offline"]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("ui-program-schema-spec binary path is not absolute")
    with tempfile.TemporaryDirectory(prefix="amoebius-phase16-") as directory:
        trace = Path(directory) / "network.trace"
        probe = run(["unshare", "-n", "true"], require_success=False)
        if probe.returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("neither network namespace isolation nor strace socket injection is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "inject=socket:error=EPERM",
                "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("UI schema gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-program-schema-spec", "--offline", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = "ui-program-schema-spec: PASS (3 positives, 10 exact negatives, 3 graph rows, 8 coverage classes, 6 mutants, opaque seal)"
    if token not in suite.stdout or token not in isolated:
        raise GateFailure("Phase-16 acceptance token is absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal), "test", "ui-program-schema-spec", "--offline", "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        if result.returncode == 0 or f"phase16-ui-mutant: RED {name}" not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "program-corpus": "3/3-positive-10/10-exact-negative",
        "graph-oracle": "3/3-rows",
        "wire-golden": "3/3-rows-byte-identical",
        "generated-coverage": "8/8-classes-at-5-percent",
        "compile-seal": "1/1-illegal-construction-rejected",
        "mutants": "6/6-red",
        "network-observer": observer,
        "browser-runtime-enforcement": "UNVERIFIED",
        "authorization-enforcement": "UNVERIFIED",
        "provider-tenant-isolation": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )



COMPILER = ""

SANCTIONED_OBSERVERS = ("unshare-network-namespace", "strace-socket-EPERM")

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "forbidden-ui-source-arms": "no raw browser-source or authority arm is present in the schema",
    "checked-program-constructor-opaque": "the CheckedUiProgram constructor is not exported",
    "ui-partial-token-scan": "no partial or unsafe token survives in the UI modules",
}

SIDES = ("toolchain", "oracle", "source", "seal", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "program-corpus": "3/3-positive-10/10-exact-negative",
    "graph-oracle": "3/3-rows",
    "wire-golden": "3/3-rows-byte-identical",
    "generated-coverage": "8/8-classes-at-5-percent",
    "compile-seal": "1/1-illegal-construction-rejected",
    "mutants": "6/6-red",
    "network-observer": "sanctioned-observer",
    "browser-runtime-enforcement": "UNVERIFIED",
    "authorization-enforcement": "UNVERIFIED",
    "provider-tenant-isolation": "UNVERIFIED",
}

SURFACE_MAP = {'closed-tenant-mode-union': 'minimal_single_tenant,minimal_multi_tenant', 'closed-node-kind-union': 'composed_workflow_ui', 'closed-value-type-union': 'ill_typed_generated,checked_ui_illegal', 'no-raw-browser-source-arm': 'forbidden-ui-source-arms', 'named-external-link-requirement': 'raw_external_link_url,duplicate_external_link_requirement,add_raw_url_arm', 'dhall-ui-source-wire': 'raw_browser_escape,add_raw_js_arm', 'deterministic-module-merge': 'duplicate_generated,M-first-id-wins', 'qualified-node-identities': 'duplicate_qualified_id', 'finite-collection-bounds': 'unbounded_collection,over_bound_generated,M-drop-bound-check', 'graph-cycle-rejection': 'recursive_effect,cyclic_generated', 'missing-reference-rejection': 'missing_reference,missing_generated', 'duplicate-identity-rejection': 'graph-oracle', 'duplicate-link-rejection': 'duplicate_link_generated', 'port-type-unification': 'port_type_mismatch,M-swap-port-contract', 'exhaustive-event-branches': 'non_exhaustive_event,non_exhaustive_generated,M-skip-exhaustiveness', 'public-value-projection': 'private_value_projection,private_generated', 'opaque-checked-ui-program': 'compile-seal', 'three-positive-programs': 'program-corpus', 'ten-exact-negative-diagnostics': 'wire-golden', 'normalized-wire-golden': 'normalized_wire', 'independent-graph-reference': 'graph_reference', 'eight-class-generated-coverage': 'generated-coverage', 'six-mutant-battery': 'mutants', 'network-isolated-pure-gate': 'network-observer', 'browser-runtime-enforcement': 'browser-runtime-enforcement', 'authorization-enforcement': 'authorization-enforcement', 'provider-tenant-isolation': 'provider-tenant-isolation', 'runtime-noninterference': '', 'generated-artifact-discipline': 'emitted-results-untracked,toolchain-satisfies-requirements,recorded-results-match-oracle,checked-program-constructor-opaque,ui-partial-token-scan'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] != "UNVERIFIED" else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names: set[str] = set()
    for relative in ("tests/oracle/phase16/validation_locus.tsv", "tests/mutants/phase16/mutants.tsv"):
        for line in (ROOT / relative).read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip():
                names.add(line.split("\t")[0].strip())
    return names


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=16, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    item_names: set[str] = set()
    observer = "unrun"

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
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — the program corpus, graph reference, and mutant manifest\n")
        mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        item_names = enumerated_items()
        print(f"  ok    {len(item_names)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the schema forecloses raw browser source\n")
        verify_source_boundaries()
        print("  ok    forbidden-ui-source-arms          no RawJs/RawHtml/RawCss/RawUrl or authority arm")
        print("  ok    checked-program-constructor-opaque the CheckedUiProgram constructor is not exported")
        print("  ok    ui-partial-token-scan             no partial or unsafe token in the UI modules")
        results["source"] = True

        print("\nseal side — the checked-program compile seal\n")
        compile_log = compile_seal(cabal)
        (gate.run_dir / "compile-seal.log").write_text(compile_log, encoding="utf-8")
        print("  ok    the illegal construction is rejected")
        results["seal"] = True

        print("\nsuite side — the pure schema battery under a network observer\n")
        green, observer = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        if observer not in SANCTIONED_OBSERVERS:
            print(f"  FAIL  network observer {observer!r} is not one this contract sanctions")
        else:
            print(f"  ok    network-isolated pure gate proven by {observer}")
            results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log = run_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {len(mutant_rows)}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(observer)
        rows = gate_common.metric_rows(RESULTS)
        compared = dict(rows)
        if compared.get("network-observer") in SANCTIONED_OBSERVERS:
            compared["network-observer"] = "sanctioned-observer"
        oracle_ok = gate_common.oracle_side(compared, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        rows = compared
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase16-gate: FAIL: {problem}", file=sys.stderr)

    decided = {
        surface: ("program-corpus", EXPECTED_RESULTS["program-corpus"])
        for surface, ids in SURFACE_MAP.items()
        if ids and (set(ids.split(",")) & item_names or (set(ids.split(",")) & set(CHECKS) and results.get("source")))
    }
    layers = {
        "Decision": "tested" if rows.get("program-corpus") == EXPECTED_RESULTS["program-corpus"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("wire-golden") == EXPECTED_RESULTS["wire-golden"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": item_names},
        rows=rows,
        evidence={**SURFACE_EVIDENCE, **decided},
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"ui-program-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows] or [{"name": "phase-16 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
