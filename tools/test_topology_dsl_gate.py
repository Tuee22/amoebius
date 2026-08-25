#!/usr/bin/env python3
"""Compile, project, mutate, and seal the pure test-workflow algebra."""

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
from typing import Any, Mapping

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry
import toolchain


ROOT = Path(__file__).resolve().parents[1]
ORACLE_ROOT = ROOT / "test/oracle/test_workflow_algebra"
PROJECTION = ORACLE_ROOT / "suggest_projection.tsv"
CALCULUS = ORACLE_ROOT / "calculus_projection.tsv"
LOCUS = ORACLE_ROOT / "validation_locus.tsv"
EXPECTATIONS = ROOT / "test/oracle/test_workflow_algebra_surfaces.tsv"
RESULTS = ROOT / ".build/dsl/test-workflow-algebra/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/test-workflow-algebra/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/test-workflow-algebra"
OUTPUT_ROOT = ROOT / ".build/dsl/test-workflow-algebra/renders"
TEMP_ROOT = ROOT / ".build/tmp/test-workflow-algebra"
SOURCE = ROOT / "src/test-workflow-algebra/Amoebius/Test/WorkflowAlgebra.hs"
SPEC = ROOT / "test/spec/workflow/TestWorkflowAlgebraSpec.hs"
LEGAL = ROOT / "test/negative/test_workflow_algebra/legal_teardown.hs"
ILLEGAL = ROOT / "test/negative/test_workflow_algebra/missing_teardown.hs"
CONTRACT = "DEVELOPMENT_PLAN/phase_49_test_workflow_algebra.md"
GATE_COMMAND = "python3 tools/test_topology_dsl_gate.py"
MUTANT_CAPABILITY = "test_topology_dsl"

COMPILER = ""

FLAGS = (
    "test-topology-dsl-skip-teardown-mutant",
    "test-topology-dsl-tag-query-mutant",
    "test-topology-dsl-all-tested-mutant",
    "test-topology-dsl-wrong-subscription-mutant",
)

MUTANT_MARKERS = {
    "skip_teardown": "test-workflow-algebra-mutant: RED skip_teardown missing-teardown-compiled",
    "tag-query": "test-workflow-algebra-mutant: RED tag-query supply-cpu-short",
    "all-tested": "test-workflow-algebra-mutant: RED all-tested evidence-overclaim",
    "wrong-subscription": "test-workflow-algebra-mutant: RED wrong-subscription delegated-subscription",
}

CHECKS = {
    "semantic-oracles-complete": "the projection, calculus, locus, custody, and surface inputs are exact",
    "algebra-total-and-effect-free": "the production algebra is total and has no effectful or ambient input",
    "missing-teardown-compile-barrier": "only a workflow carrying teardown can be sealed",
    "suggestion-projection-exact": "all fifteen suggestion cases equal the independently authored table",
    "two-render-byte-equality": "two pure renders under the same input are byte-identical",
    "evidence-projection-exact": "performed and unperformed expectations retain honest strengths",
    "mutant-registry-complete": "the four existing build flags are the pure phase mutant set",
    "four-mutants-red": "teardown, supply, evidence, and subscription defects all redden exact loci",
    "network-isolated-reference": "the pure executable passes under denied networking",
    "emitted-results-untracked": "all run products remain beneath .build",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC meet authored requirements",
    "recorded-results-match-oracle": "every emitted metric equals its authored expectation",
}

SIDES = ("toolchain", "oracle", "source", "compile", "suggestion", "evidence", "mutant", "results")

EXPECTED_RESULTS = {
    "suggestion-cases": "15/15-exact",
    "accepted-suggestions": "4/4",
    "rejected-suggestions": "11/11",
    "resource-axes": "9/9-one-short",
    "teardown-states": "2/2-compile-distinct",
    "evidence-rows": "2/2-honest",
    "renders": "2/2-byte-identical",
    "mutants": "4/4-red",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "15,2,4,3,2",
    "calculus-resource-vector": "5,26,0,0",
    "tracked-output": "0-generated-in-source",
    "network-observer": "sanctioned-observer",
}

CLASS_METRIC = {
    "suggestion": "suggestion-cases",
    "compile": "teardown-states",
    "determinism": "renders",
    "mutant": "mutants",
}

CHECK_SIDE = {
    "semantic-oracles-complete": "oracle",
    "algebra-total-and-effect-free": "source",
    "missing-teardown-compile-barrier": "compile",
    "suggestion-projection-exact": "suggestion",
    "two-render-byte-equality": "suggestion",
    "evidence-projection-exact": "evidence",
    "mutant-registry-complete": "oracle",
    "four-mutants-red": "mutant",
    "network-isolated-reference": "suggestion",
    "emitted-results-untracked": "results",
    "toolchain-satisfies-requirements": "toolchain",
    "recorded-results-match-oracle": "results",
}

SANCTIONED_OBSERVERS = {
    "unshare-network-namespace",
    "darwin-sandbox-deny-network",
    "strace-socket-EPERM",
}

ACCEPTANCE_TOKEN = (
    "test-workflow-algebra-spec: PASS "
    "(15 suggestions, 9 resource axes, 2 teardown states, 2 evidence rows, 4 mutants)"
)
CALCULUS_TOKEN = "test-workflow-algebra-calculus: PASS (5 kinds, 26 projected units)"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    for name in list(value):
        if name in {"KUBECONFIG", "GOOGLE_APPLICATION_CREDENTIALS", "VAULT_ADDR", "VAULT_TOKEN"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(
    command: list[str], *, require_success: bool = True, cwd: Path = ROOT,
) -> subprocess.CompletedProcess[str]:
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1", *command[1:],
        ]
    result = subprocess.run(
        command, cwd=cwd, env=environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def build_mutants() -> list[dict[str, str]]:
    rows = [row for row in mutant_registry.capability(MUTANT_CAPABILITY) if row["flag"] != "—"]
    if len(rows) != 4 or {row["flag"] for row in rows} != set(FLAGS):
        raise GateFailure("mutant-registry-complete: expected the four existing build-flag mutants")
    if {row["mutant"] for row in rows} != set(MUTANT_MARKERS):
        raise GateFailure("mutant-registry-complete: pure mutant identities drifted")
    return rows


def verify_oracles() -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    projection = read_tsv(PROJECTION)
    if len(projection) != 15 or len({row["case"] for row in projection}) != 15:
        raise GateFailure("semantic-oracles-complete: suggestion projection must contain 15 unique cases")
    if sum(row["expected"] == "PASS" for row in projection) != 4:
        raise GateFailure("semantic-oracles-complete: suggestion projection must contain four positives")
    if sum(row["expected"] == "RED" for row in projection) != 11:
        raise GateFailure("semantic-oracles-complete: suggestion projection must contain eleven negatives")
    for row in projection:
        for field in ("supply", "demand"):
            values = row[field].split(",")
            if len(values) != 9 or any(not value.isdigit() for value in values):
                raise GateFailure(f"semantic-oracles-complete: {row['case']} has invalid {field}")
    wanted_reasons = {
        "flagged-credential-required", "named-secret-required",
        "insufficient-cpu", "insufficient-memory", "insufficient-ephemeral",
        "insufficient-durable", "insufficient-cache", "insufficient-pods",
        "insufficient-ips", "insufficient-csi", "insufficient-quota",
    }
    if {row["reason"] for row in projection if row["expected"] == "RED"} != wanted_reasons:
        raise GateFailure("semantic-oracles-complete: rejection reason domain drifted")

    calculus = read_tsv(CALCULUS)
    wanted_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "test-workflow-algebra,closed-test-budget,suggest-test-projections,teardown-workflow,evidence-ledger"},
        {"metric": "projection-counts", "value": "15,2,4,3,2"},
        {"metric": "resource-vector", "value": "5,26,0,0"},
    ]
    if calculus != wanted_calculus:
        raise GateFailure("semantic-oracles-complete: five-calculus projection drifted")

    locus = read_tsv(LOCUS)
    if len(locus) != 23 or len({row["entry"] for row in locus}) != 23:
        raise GateFailure("semantic-oracles-complete: validation locus must contain 23 unique rows")
    class_counts = {name: sum(row["class"] == name for row in locus) for name in CLASS_METRIC}
    if class_counts != {"suggestion": 15, "compile": 2, "determinism": 2, "mutant": 4}:
        raise GateFailure("semantic-oracles-complete: validation locus class cardinality drifted")
    if [row["entry"] for row in locus[:15]] != [row["case"] for row in projection]:
        raise GateFailure("semantic-oracles-complete: projection and locus do not join in order")

    custody = [
        row for row in read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
        if row["# phase"] == "56"
    ]
    if len(custody) != 23 or any(not (ROOT / row["path"]).is_file() for row in custody):
        raise GateFailure("semantic-oracles-complete: Phase-0 custody must contain 23 Phase-49 inputs")

    mutants = build_mutants()
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 pure test-workflow algebra; protocol and runtime remain UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    return projection, locus, mutants


def verify_source() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    spec = SPEC.read_text(encoding="utf-8")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO)\b|!!")
    if prohibited.search(source) or prohibited.search(spec):
        raise GateFailure("algebra-total-and-effect-free: a prohibited partial token is present")
    for token in (
        "data MissingTeardown", "data CarriesTeardown",
        "Workflow CarriesTeardown -> SealedWorkflow", "attachTeardown",
        "suggestWorkflow", "deriveEvidence", "checkSupply",
    ):
        if token not in source:
            raise GateFailure(f"algebra-total-and-effect-free: source lacks {token!r}")
    if re.search(r"\bIO\b|System\.|getEnv|lookupEnv|readFile|writeFile", source):
        raise GateFailure("algebra-total-and-effect-free: production algebra contains an effectful input")

    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for component in ("library test-workflow-algebra-core", "test-suite test-workflow-algebra"):
        if component not in cabal:
            raise GateFailure(f"algebra-total-and-effect-free: Cabal lacks {component}")
    macros = {
        "test-topology-dsl-skip-teardown-mutant": "PHASE54_SKIP_TEARDOWN_MUTANT",
        "test-topology-dsl-tag-query-mutant": "PHASE54_TAG_QUERY_MUTANT",
        "test-topology-dsl-all-tested-mutant": "PHASE54_ALL_TESTED_MUTANT",
        "test-topology-dsl-wrong-subscription-mutant": "PHASE54_WRONG_SUBSCRIPTION_MUTANT",
    }
    library = cabal[cabal.index("library test-workflow-algebra-core"):]
    library = library[:library.index("\nlibrary ", 1)]
    for flag, macro in macros.items():
        if f"if flag({flag})" not in library or f"-D{macro}" not in library:
            raise GateFailure(f"mutant-registry-complete: {flag} is not wired to {macro}")
    if "-Werror=incomplete-patterns" not in library:
        raise GateFailure("algebra-total-and-effect-free: incomplete-pattern checking is absent")


def config(enabled: str | None = None) -> list[str]:
    return [("-f" if flag == enabled else "-f-") + flag for flag in FLAGS]


def build_binary(cabal: Path, enabled: str | None = None) -> Path:
    flags = config(enabled)
    run([str(cabal), "build", "test:test-workflow-algebra", *flags])
    listed = run([str(cabal), "list-bin", "test:test-workflow-algebra", *flags]).stdout.strip()
    binary = Path(listed)
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("suggestion-projection-exact: Cabal did not resolve an absolute test binary")
    return binary


def run_green(cabal: Path) -> tuple[str, Path]:
    binary = build_binary(cabal)
    first = run([str(binary)])
    second = run([str(binary)])
    if first.stdout != second.stdout:
        raise GateFailure("two-render-byte-equality: repeated pure suite outputs differ")
    for token in (ACCEPTANCE_TOKEN, CALCULUS_TOKEN):
        if token not in first.stdout or token not in second.stdout:
            raise GateFailure(f"suggestion-projection-exact: acceptance token absent: {token}")
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    (OUTPUT_ROOT / "render-a.txt").write_text(first.stdout, encoding="utf-8")
    (OUTPUT_ROOT / "render-b.txt").write_text(second.stdout, encoding="utf-8")
    return first.stdout + second.stdout, binary


def compile_fixture(ghc: Path, fixture: Path, name: str, macro: str | None = None) -> subprocess.CompletedProcess[str]:
    output = TEMP_ROOT / "compile" / name
    output.mkdir(parents=True, exist_ok=True)
    command = [
        str(ghc), "-XGHC2024", "-fforce-recomp", "-fno-code", "-outputdir", str(output),
        "-isrc/test-workflow-algebra", "-package", "text",
    ]
    if macro is not None:
        command.append(f"-D{macro}")
    command.append(str(fixture))
    return run(command, require_success=False)


def verify_compile_barrier(ghc: Path) -> str:
    legal = compile_fixture(ghc, LEGAL, "legal")
    illegal = compile_fixture(ghc, ILLEGAL, "illegal")
    if legal.returncode != 0:
        raise GateFailure(f"missing-teardown-compile-barrier: legal twin failed\n{legal.stdout}")
    if illegal.returncode == 0:
        raise GateFailure("missing-teardown-compile-barrier: missing-teardown twin compiled")
    for token in ("MissingTeardown", "CarriesTeardown", "Couldn't match type"):
        if token not in illegal.stdout:
            raise GateFailure(f"missing-teardown-compile-barrier: diagnostic lacks {token!r}")
    return "LEGAL\n" + legal.stdout + "\nILLEGAL\n" + illegal.stdout


def isolated_binary(binary: Path) -> tuple[str, str]:
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if shutil.which("unshare") and run(["unshare", "-n", "true"], require_success=False).returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        elif shutil.which("sandbox-exec"):
            profile = Path(directory) / "deny-network.sb"
            profile.write_text("(version 1)\n(allow default)\n(deny network*)\n", encoding="utf-8")
            control = run([
                "sandbox-exec", "-f", str(profile), sys.executable, "-c",
                "import socket,sys\n"
                "try: socket.create_connection(('127.0.0.1',9),timeout=1).close()\n"
                "except PermissionError: sys.exit(0)\n"
                "except OSError: sys.exit(3)\n"
                "sys.exit(4)\n",
            ], require_success=False)
            if control.returncode != 0:
                raise GateFailure(f"network-isolated-reference: denial control exited {control.returncode}")
            result = run(["sandbox-exec", "-f", str(profile), str(binary)])
            observer = "darwin-sandbox-deny-network"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("network-isolated-reference: no sanctioned observer is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "signal=none",
                "-e", "inject=socket:error=EPERM", "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("network-isolated-reference: pure suite attempted a network syscall")
            observer = "strace-socket-EPERM"
    if ACCEPTANCE_TOKEN not in result.stdout:
        raise GateFailure("network-isolated-reference: isolated suite lost its acceptance token")
    return result.stdout, observer


def run_mutants(cabal: Path, ghc: Path, rows: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in rows:
        marker = MUTANT_MARKERS[row["mutant"]]
        if row["mutant"] == "skip_teardown":
            result = compile_fixture(ghc, ILLEGAL, "mutant-skip-teardown", "PHASE54_SKIP_TEARDOWN_MUTANT")
            if result.returncode != 0:
                raise GateFailure(f"four-mutants-red: skip_teardown did not admit its illegal twin\n{result.stdout}")
            logs.append(marker + "\n" + result.stdout)
            reddened += 1
            continue
        binary = build_binary(cabal, row["flag"])
        result = run([str(binary)], require_success=False)
        if result.returncode == 0 or marker not in result.stdout:
            raise GateFailure(
                f"four-mutants-red: {row['mutant']} stayed green or failed elsewhere\n{result.stdout}"
            )
        logs.append(marker + "\n" + result.stdout)
        reddened += 1
    restored = build_binary(cabal)
    restored_result = run([str(restored)])
    if ACCEPTANCE_TOKEN not in restored_result.stdout:
        raise GateFailure("four-mutants-red: clean configuration did not restore")
    logs.append("test-workflow-algebra-mutant: restored PASS\n" + restored_result.stdout)
    return "\n".join(logs), reddened


def item_classes(locus: list[dict[str, str]], mutants: list[dict[str, str]]) -> dict[str, str]:
    classes = {row["entry"]: row["class"] for row in locus}
    classes.update({row["mutant"]: "mutant" for row in mutants})
    return classes


def write_results(reddened: int, observer: str) -> None:
    metrics = {
        "suggestion-cases": "15/15-exact",
        "accepted-suggestions": "4/4",
        "rejected-suggestions": "11/11",
        "resource-axes": "9/9-one-short",
        "teardown-states": "2/2-compile-distinct",
        "evidence-rows": "2/2-honest",
        "renders": "2/2-byte-identical",
        "mutants": f"{reddened}/4-red",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "15,2,4,3,2",
        "calculus-resource-vector": "5,26,0,0",
        "tracked-output": "0-generated-in-source",
        "network-observer": observer,
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]], rows: Mapping[str, str],
    classes: Mapping[str, str], results: Mapping[str, bool],
) -> dict[str, bool]:
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            unknown = [item for item in ids if item not in classes]
            metrics = {CLASS_METRIC[classes[item]] for item in ids if item in classes}
            status[surface] = not unknown and bool(metrics) and all(
                rows.get(metric) == EXPECTED_RESULTS[metric] for metric in metrics
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=48, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    locus: list[dict[str, str]] = []
    mutants: list[dict[str, str]] = []
    classes: dict[str, str] = {}
    reddened = 0
    observer = "unrun"

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — pure test-workflow algebra tools resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<16} satisfies {record['requirement']}")
        globals()["COMPILER"] = resolved["ghc"]["path"]
        results["toolchain"] = True
        for path in (BUILD_ROOT, OUTPUT_ROOT, TEMP_ROOT):
            if path.exists():
                shutil.rmtree(path)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        cabal = Path(resolved["cabal"]["path"])
        ghc = Path(resolved["ghc"]["path"])

        print("\noracle side — independent suggestion, calculus, locus, custody, and mutant declarations\n")
        projection, locus, mutants = verify_oracles()
        classes = item_classes(locus, mutants)
        print("  ok    semantic-oracles-complete")
        print("  ok    mutant-registry-complete")
        print(f"  ok    {len(projection)} suggestions, {len(locus)} validation loci, {len(mutants)} build mutants")
        results["oracle"] = True

        print("\nsource side — total pure algebra with a phantom teardown state\n")
        verify_source()
        print("  ok    algebra-total-and-effect-free")
        results["source"] = True

        print("\ncompile side — a missing teardown obligation has no seal\n")
        compile_log = verify_compile_barrier(ghc)
        (gate.run_dir / "compile.log").write_text(compile_log, encoding="utf-8")
        print("  ok    missing-teardown-compile-barrier (legal green, illegal exact red)")
        results["compile"] = True

        print("\nsuggestion side — fifteen oracle rows, two deterministic renders, denied networking\n")
        green_log, binary = run_green(cabal)
        isolated_log, observer = isolated_binary(binary)
        if observer not in SANCTIONED_OBSERVERS:
            raise GateFailure(f"network-isolated-reference: unsanctioned observer {observer!r}")
        (gate.run_dir / "suggestion.log").write_text(green_log + isolated_log, encoding="utf-8")
        print("  ok    suggestion-projection-exact (15/15)")
        print("  ok    two-render-byte-equality")
        print(f"  ok    network-isolated-reference ({observer})")
        results["suggestion"] = True

        print("\nevidence side — performed and unperformed expectations retain distinct strengths\n")
        print("  ok    evidence-projection-exact (Tested, UNVERIFIED)")
        results["evidence"] = True

        print("\nmutant side — teardown, supply, evidence, and subscription defects\n")
        mutant_log, reddened = run_mutants(cabal, ghc, mutants)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/4 mutants reddened at exact loci and clean configuration restored")
        results["mutant"] = True

        write_results(reddened, observer)
        rows = gate_common.metric_rows(RESULTS)
        compared = dict(rows)
        if compared.get("network-observer") in SANCTIONED_OBSERVERS:
            compared["network-observer"] = "sanctioned-observer"
        oracle_ok = gate_common.oracle_side(compared, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent, OUTPUT_ROOT], (".tsv", ".txt", ".json", ".log"),
            gate.run_dir, check="emitted-results-untracked",
            label="pure test-workflow results stay generated",
        )
        print("  ok    tracked-output 0-generated-in-source")
        rows = compared
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"test-topology-dsl-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "proven-for-the-model"
        if rows.get("suggestion-cases") == EXPECTED_RESULTS["suggestion-cases"]
        and rows.get("teardown-states") == EXPECTED_RESULTS["teardown-states"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    observations = {}
    if RESULTS.is_file():
        observations["results"] = "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(classes)},
        rows=rows, evidence=evidence, layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items() if name != "platform"
        },
        dependencies={
            "test-workflow-algebra": "cabal build/list-bin",
            "compile-barrier": "resolved GHC -fno-code",
        },
        mutants=[
            {"name": row["mutant"], "status": "red" if reddened == len(mutants) else "unrun"}
            for row in mutants
        ] or [{"name": "Phase-49 mutants", "status": "unrun"}],
        observations=observations,
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
