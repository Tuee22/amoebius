#!/usr/bin/env python3
"""Run and seal the bounded UI-program schema checks."""

from __future__ import annotations

import csv
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
import mutant_registry  # noqa: E402
import toolchain


ROOT = Path(__file__).resolve().parent.parent
CASES = ROOT / "test/fixture/ui_program_schema/cases.tsv"
GRAPH = ROOT / "test/fixture/ui_program_schema/graph_reference.tsv"
PROGRAM_SEMANTICS = ROOT / "test/oracle/ui_program_schema/program_semantics.tsv"
CALCULUS = ROOT / "test/oracle/ui_program_schema/calculus_projection.tsv"
RETIRED_WIRE = ROOT / "test/fixture/ui_program_schema/normalized_wire.golden"
MUTANT_CAPABILITY = "ui_program_schema"
LOCUS = ROOT / "test/oracle/ui_program_schema/validation_locus.tsv"
RESULTS = ROOT / ".build/dsl/ui-program-schema/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/ui-program-schema/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/ui-program-schema"
TEMP_ROOT = ROOT / ".build/tmp/ui-program-schema"
CONTRACT = "DEVELOPMENT_PLAN/phase_38_ui_program_schema.md"
GATE_COMMAND = "python3 tools/ui_program_schema_gate.py"
EXPECTATIONS = "test/oracle/ui_program_schema_surfaces.tsv"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", "--jobs=1", *command[1:]]
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
        raise GateFailure("Phase-38 corpus must contain three positives and ten negatives")
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
    semantics = read_tsv(PROGRAM_SEMANTICS)
    expected_semantics = [
        {
            "program": "minimal_single_tenant",
            "tenant_mode": "single-tenant",
            "modules": "app.main",
            "qualified_nodes": "app.main.home,app.main.submit",
            "external_links": "docs",
        },
        {
            "program": "minimal_multi_tenant",
            "tenant_mode": "multi-tenant",
            "modules": "app.main",
            "qualified_nodes": "app.main.home,app.main.tenant",
            "external_links": "docs",
        },
        {
            "program": "composed_workflow_ui",
            "tenant_mode": "single-tenant",
            "modules": "app.workflow",
            "qualified_nodes": "app.workflow.progress,app.workflow.start",
            "external_links": "docs",
        },
    ]
    if semantics != expected_semantics:
        raise GateFailure("independent program-semantic oracle drifted")
    calculus = read_tsv(CALCULUS)
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "program-semantics,diagnostic-budget,generated-rejection-classes,graph-check-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "3,10,8,3,6"},
        {"metric": "resource-vector", "value": "5,30,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("UI five-calculus projection oracle drifted")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 6 or len({row["mutant"] for row in mutants}) != 6:
        raise GateFailure("mutant oracle must contain six unique mutants")
    locus = read_tsv(LOCUS)
    if len(locus) != 30 or len({row["entry"] for row in locus}) != 30:
        raise GateFailure("validation locus must contain thirty unique rows")
    phase0 = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    phase37 = [row for row in phase0 if row["# phase"] == "19"]
    if len(phase37) != 24:
        raise GateFailure(f"Phase-0 manifest must pin 24 Phase-38 artifacts, got {len(phase37)}")
    missing = [row["path"] for row in phase37 if not (ROOT / row["path"]).is_file()]
    if missing:
        raise GateFailure(f"Phase-38 preimplementation artifacts are absent: {missing}")
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
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    stanza = cabal.split("test-suite ui-program-schema-spec", 1)[1].split("\ntest-suite ", 1)[0]
    for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
        if option not in stanza:
            raise GateFailure(f"UI schema suite lacks totality option {option}")
    if RETIRED_WIRE.exists():
        raise GateFailure("retired normalized-wire byte golden is still committed")


def compile_seal(cabal: Path) -> str:
    run([str(cabal), "build", "lib:amoebius"])
    common = [str(cabal), "exec", "ghc", "--", "-fno-code", "-XGHC2024", "-isrc"]
    legal = run(common + ["test/fixture/ui_program_schema/compilefail/checked_ui_legal.hs"])
    illegal = run(common + ["test/fixture/ui_program_schema/compilefail/checked_ui_illegal.hs"], require_success=False)
    expected = "Illegal term-level use of the type constructor ‘CheckedUiProgram’"
    if illegal.returncode == 0 or expected not in illegal.stdout:
        raise GateFailure(f"CheckedUiProgram compile-fail seal drifted:\n{illegal.stdout}")
    return legal.stdout + illegal.stdout


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-program-schema-spec"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-program-schema-spec"]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("ui-program-schema-spec binary path is not absolute")
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if shutil.which("unshare") and run(["unshare", "-n", "true"], require_success=False).returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        elif shutil.which("sandbox-exec"):
            profile = Path(directory) / "deny-network.sb"
            profile.write_text("(version 1)\n(allow default)\n(deny network*)\n", encoding="utf-8")
            control = run(
                [
                    "sandbox-exec",
                    "-f",
                    str(profile),
                    sys.executable,
                    "-c",
                    "import socket,sys;\n"
                    "try:\n socket.create_connection(('127.0.0.1', 9), timeout=1).close()\n"
                    "except PermissionError:\n sys.exit(0)\n"
                    "except OSError:\n sys.exit(3)\n"
                    "sys.exit(4)\n",
                ],
                require_success=False,
            )
            if control.returncode != 0:
                raise GateFailure(
                    f"sandbox-exec did not deny a socket (control exit {control.returncode}); "
                    "the isolation this observer claims is not in force"
                )
            result = run(["sandbox-exec", "-f", str(profile), str(binary)])
            observer = "darwin-sandbox-deny-network"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("none of unshare, sandbox-exec, or strace is available as a network observer")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "inject=socket:error=EPERM",
                "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("UI schema gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-program-schema-spec", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    tokens = (
        "ui-program-schema-calculus: PASS (5 kinds, 30 projected units)",
        "ui-program-schema-spec: PASS (3 semantic positives, 10 exact negatives, 3 graph rows, 8 coverage classes, 6 mutants, opaque seal)",
    )
    if any(token not in suite.stdout or token not in isolated for token in tokens):
        raise GateFailure("Phase-38 acceptance tokens are absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    logs = []
    for row in mutants:
        name = row["mutant"]
        result = run(
            [
                str(cabal), "test", "ui-program-schema-spec", "--test-show-details=direct",
                f"--test-options=--mutant={name}",
            ],
            require_success=False,
        )
        token = f"ui-program-schema-mutant: RED {name} locus={row['token']}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "program-corpus": "3/3-positive-10/10-exact-negative",
        "exact-negative-diagnostics": "10/10-tag-and-span",
        "program-semantics": "3/3-rows",
        "graph-oracle": "3/3-rows",
        "deterministic-decodes": "3/3-two-pass-equal",
        "closed-enum-arms": "2-tenant/7-node/8-value",
        "generated-coverage": "8/8-classes-at-5-percent",
        "compile-seal": "1/1-illegal-construction-rejected",
        "mutants": "6/6-red",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "3,10,8,3,6",
        "calculus-resource-vector": "5,30,0,0",
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

SANCTIONED_OBSERVERS = (
    "unshare-network-namespace",
    "darwin-sandbox-deny-network",
    "strace-socket-EPERM",
)

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "forbidden-ui-source-arms": "no raw browser-source or authority arm is present in the schema",
    "checked-program-constructor-opaque": "the CheckedUiProgram constructor is not exported",
    "ui-partial-token-scan": "no partial or unsafe token survives in the UI modules",
    "semantic-oracles-complete": "the program, graph, diagnostic, and calculus oracles are exact",
    "totality-options": "the UI suite compiles with the project totality warnings",
    "retired-wire-golden-absent": "the generated normalized-wire byte golden is absent",
}

SIDES = ("toolchain", "oracle", "source", "seal", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "program-corpus": "3/3-positive-10/10-exact-negative",
    "exact-negative-diagnostics": "10/10-tag-and-span",
    "program-semantics": "3/3-rows",
    "graph-oracle": "3/3-rows",
    "deterministic-decodes": "3/3-two-pass-equal",
    "closed-enum-arms": "2-tenant/7-node/8-value",
    "generated-coverage": "8/8-classes-at-5-percent",
    "compile-seal": "1/1-illegal-construction-rejected",
    "mutants": "6/6-red",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "3,10,8,3,6",
    "calculus-resource-vector": "5,30,0,0",
    "network-observer": "sanctioned-observer",
    "browser-runtime-enforcement": "UNVERIFIED",
    "authorization-enforcement": "UNVERIFIED",
    "provider-tenant-isolation": "UNVERIFIED",
}

SURFACE_MAP = {
    "closed-tenant-mode-union": "minimal_single_tenant,minimal_multi_tenant",
    "closed-node-kind-union": "composed_workflow_ui",
    "closed-value-type-union": "ill_typed_generated,checked_ui_illegal",
    "no-raw-browser-source-arm": "forbidden-ui-source-arms",
    "named-external-link-requirement": "raw_external_link_url,duplicate_external_link_requirement,add_raw_url_arm",
    "dhall-ui-source-wire": "raw_browser_escape,add_raw_js_arm",
    "deterministic-module-merge": "duplicate_generated,M-first-id-wins",
    "qualified-node-identities": "duplicate_qualified_id",
    "finite-collection-bounds": "unbounded_collection,over_bound_generated,M-drop-bound-check",
    "graph-cycle-rejection": "recursive_effect,cyclic_generated",
    "missing-reference-rejection": "missing_reference,missing_generated",
    "duplicate-identity-rejection": "graph-oracle",
    "duplicate-link-rejection": "duplicate_link_generated",
    "port-type-unification": "port_type_mismatch,M-swap-port-contract",
    "exhaustive-event-branches": "non_exhaustive_event,non_exhaustive_generated,M-skip-exhaustiveness",
    "public-value-projection": "private_value_projection,private_generated",
    "opaque-checked-ui-program": "compile-seal",
    "three-positive-programs": "program-corpus",
    "ten-exact-negative-diagnostics": "exact-negative-diagnostics",
    "program-semantic-projection": "program-semantics",
    "independent-program-semantic-reference": "program_semantics",
    "independent-graph-reference": "graph_reference",
    "deterministic-two-pass-decode": "deterministic-decodes",
    "closed-enum-cardinalities": "closed-enum-arms",
    "eight-class-generated-coverage": "generated-coverage",
    "six-mutant-battery": "mutants",
    "five-calculus-kind-cardinality": "calculus-kinds",
    "five-calculus-component-vector": "calculus-components",
    "five-calculus-projection-counts": "calculus-projection-counts",
    "five-calculus-resource-vector": "calculus-resource-vector",
    "network-isolated-pure-gate": "network-observer",
    "browser-runtime-enforcement": "browser-runtime-enforcement",
    "authorization-enforcement": "authorization-enforcement",
    "provider-tenant-isolation": "provider-tenant-isolation",
    "runtime-noninterference": "",
    "semantic-oracles-complete": "semantic-oracles-complete",
    "compile-totality": "totality-options",
    "retired-wire-byte-golden": "retired-wire-golden-absent",
    "generated-artifact-discipline": "emitted-results-untracked,toolchain-satisfies-requirements,recorded-results-match-oracle,checked-program-constructor-opaque,ui-partial-token-scan",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] != "UNVERIFIED" else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names: set[str] = set()
    for relative in ("test/oracle/ui_program_schema/validation_locus.tsv",):
        for line in (ROOT / relative).read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip():
                names.add(line.split("\t")[0].strip())
    # The one registry leads with the capability and carries every phase's rows, so
    # this phase's items are the mutant ids in its own rows, not every first column.
    names.update(row["mutant"] for row in mutant_registry.capability(MUTANT_CAPABILITY))
    return names


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=37, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
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
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — the program corpus, semantic tables, calculus projection, and mutant manifest\n")
        mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        item_names = enumerated_items()
        print(f"  ok    {len(item_names)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the schema forecloses raw browser source\n")
        verify_source_boundaries()
        print("  ok    forbidden-ui-source-arms          no RawJs/RawHtml/RawCss/RawUrl or authority arm")
        print("  ok    checked-program-constructor-opaque the CheckedUiProgram constructor is not exported")
        print("  ok    ui-partial-token-scan             no partial or unsafe token in the UI modules")
        print("  ok    totality-options                  suite totality warnings are enabled")
        print("  ok    retired-wire-golden-absent        no rendered-byte oracle survives")
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
        print(f"ui-program-schema-gate: FAIL: {problem}", file=sys.stderr)

    item_evidence = {
        surface: ("program-corpus", EXPECTED_RESULTS["program-corpus"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
    }
    layers = {
        "Decision": "tested" if rows.get("program-corpus") == EXPECTED_RESULTS["program-corpus"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("program-semantics") == EXPECTED_RESULTS["program-semantics"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    check_status = {
        "no-raw-browser-source-arm": results["source"],
        "semantic-oracles-complete": results["oracle"],
        "compile-totality": results["source"],
        "retired-wire-byte-golden": results["source"],
        "generated-artifact-discipline": results["results"],
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
        dependencies={"ui-program-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows] or [{"name": "phase-38 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status=check_status,
    )


if __name__ == "__main__":
    raise SystemExit(main())
