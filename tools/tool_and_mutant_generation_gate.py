#!/usr/bin/env python3
"""Generate, compare, mutate, and seal the checking-tool and mutation corpus."""

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
ORACLE_ROOT = ROOT / "test/oracle/tool_and_mutant_generation"
TOOL_INVENTORY = ORACLE_ROOT / "tool_inventory.tsv"
MUTATION_INVENTORY = ORACLE_ROOT / "mutation_inventory.tsv"
LOCUS = ORACLE_ROOT / "validation_locus.tsv"
CALCULUS = ORACLE_ROOT / "calculus_projection.tsv"
EXPECTATIONS = ROOT / "test/oracle/tool_and_mutant_generation_surfaces.tsv"
RESULTS = ROOT / ".build/dsl/tool-and-mutant-generation/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/tool-and-mutant-generation/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/tool-and-mutant-generation"
OUTPUT_ROOT = ROOT / ".build/tools/tool-and-mutant-generation"
RENDER_ROOT = OUTPUT_ROOT / "renders"
WORKSPACE_ROOT = OUTPUT_ROOT / "workspace"
TEMP_ROOT = ROOT / ".build/tmp/tool-and-mutant-generation"
CONTRACT = "DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md"
GATE_COMMAND = "python3 tools/tool_and_mutant_generation_gate.py"
MUTANT_CAPABILITY = "tool_and_mutant_generation"
SELF = "tools/tool_and_mutant_generation_gate.py"

COMPILER = ""

FLAGS = (
    "tool-generation-missing-rule-mutant",
    "tool-generation-drop-operator-mutant",
    "tool-generation-track-output-mutant",
)

CHECKS = {
    "tool-source-inventory-exact": "the authored inventory joins both ways to every pre-existing tools source",
    "mutation-inventory-exact": "the mutation inventory joins both ways to every registered body declaration",
    "recipe-total-and-caller-owned": "the Haskell recipe is total and writes only below its caller-owned root",
    "semantic-oracles-complete": "inventories, calculus, locus, custody, and equivalence concerns are exact",
    "mutant-registry-complete": "three production CPP defects name distinct red loci",
    "two-render-byte-equality": "two fresh materializations contain identical paths and bytes",
    "generated-content-addresses": "every emitted body receives a run-local SHA-256 address",
    "whole-corpus-equivalence": "four generated checking mechanisms equal authored verdicts over the corpus",
    "generated-output-untracked": "no emitted tool or mutation body enters the source snapshot",
    "network-isolated-reference": "a generated whole-corpus checker passes under denied networking",
    "emitted-results-untracked": "generated mirrors, workspaces, logs, and measurements stay under .build",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC meet authored requirements",
    "recorded-results-match-oracle": "every emitted metric equals its authored expectation",
}

SIDES = ("toolchain", "oracle", "source", "render", "equivalence", "mutant", "results")

EXPECTED_RESULTS = {
    "tool-sources": "234/234-exact",
    "mutation-declarations": "371/371-exact",
    "generated-artifacts": "605/605-build-only",
    "renders": "2/2-complete",
    "byte-determinism": "605/605-byte-identical",
    "equivalence": "4/4-whole-corpus",
    "mutants": "3/3-red",
    "tracked-output": "0-generated-in-source",
    "content-addresses": "605/605-sha256",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "605,2,605,4,3",
    "calculus-resource-vector": "5,1219,0,0",
    "network-observer": "sanctioned-observer",
}

CLASS_METRIC = {
    "tool": "tool-sources",
    "mutation": "mutation-declarations",
    "render": "renders",
    "determinism": "byte-determinism",
    "equivalence": "equivalence",
    "mutant": "mutants",
}

CHECK_SIDE = {
    "tool-source-inventory-exact": "oracle",
    "mutation-inventory-exact": "oracle",
    "recipe-total-and-caller-owned": "source",
    "semantic-oracles-complete": "oracle",
    "mutant-registry-complete": "oracle",
    "two-render-byte-equality": "render",
    "generated-content-addresses": "render",
    "whole-corpus-equivalence": "equivalence",
    "generated-output-untracked": "results",
    "network-isolated-reference": "equivalence",
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
    "tool-and-mutant-generation-spec: PASS "
    "(234 tool sources, 371 mutation declarations, 605 artifacts, 3 mutants)"
)
CALCULUS_TOKEN = "tool-and-mutant-generation-calculus: PASS (5 kinds, 1219 projected units)"


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


def expected_tool_paths() -> list[str]:
    return sorted(
        path for path in gate_common.artifact_policy.snapshot_paths()
        if path.startswith("tools/") and path != SELF
    )


def expected_mutation_rows() -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    for row in mutant_registry.rows():
        if row["body"] == "—" or row["body"].startswith("gate:"):
            continue
        for body in row["body"].split(","):
            rows.append((body.strip(), row["capability"], row["mutant"]))
    return rows


def verify_oracles() -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    tools = read_tsv(TOOL_INVENTORY)
    mutations = read_tsv(MUTATION_INVENTORY)
    if len(tools) != 234 or len({row["path"] for row in tools}) != 234:
        raise GateFailure("tool-source-inventory-exact: inventory must contain 234 unique source paths")
    actual_tools = expected_tool_paths()
    if [row["path"] for row in tools] != actual_tools:
        raise GateFailure("tool-source-inventory-exact: authored inventory differs from the source snapshot")
    allowed_kinds = {"python-mechanism", "shell-mechanism", "declaration"}
    if {row["kind"] for row in tools} - allowed_kinds:
        raise GateFailure("tool-source-inventory-exact: inventory contains an unknown source kind")
    expected_mutations = expected_mutation_rows()
    actual_mutations = [(row["body"], row["capability"], row["mutant"]) for row in mutations]
    if len(mutations) != 371 or actual_mutations != expected_mutations:
        raise GateFailure("mutation-inventory-exact: authored inventory differs from the mutant registry")
    if {row["operator"] for row in mutations} != {"apply-declared-body"}:
        raise GateFailure("mutation-inventory-exact: mutation operator vocabulary drifted")
    if any(not (ROOT / row["path"]).is_file() for row in tools):
        raise GateFailure("tool-source-inventory-exact: an inventoried source is absent")
    if any(not (ROOT / row["body"]).is_file() for row in mutations):
        raise GateFailure("mutation-inventory-exact: an inventoried mutation body is absent")

    calculus = read_tsv(CALCULUS)
    wanted_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "generated-checking-corpus,closed-generation-budget,tool-and-mutation-declarations,equivalence-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "605,2,605,4,3"},
        {"metric": "resource-vector", "value": "5,1219,0,0"},
    ]
    if calculus != wanted_calculus:
        raise GateFailure("tool generation five-calculus projection drifted")
    locus = read_tsv(LOCUS)
    if len(locus) != 615 or len({row["entry"] for row in locus}) != 615:
        raise GateFailure("tool generation validation locus must contain 615 unique rows")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or {row["flag"] for row in mutants} != set(FLAGS):
        raise GateFailure("mutant-registry-complete: expected the three exact production flags")
    if len({row["expected_red_locus"] for row in mutants}) != 3:
        raise GateFailure("mutant-registry-complete: each mutant must own a distinct red locus")
    custody = [
        row for row in read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
        if row["# phase"] == "30"
    ]
    if len(custody) != 5 or any(not (ROOT / row["path"]).is_file() for row in custody):
        raise GateFailure("Phase-0 custody must retain all five Phase-47 preimplementation artifacts")
    descriptors = {row["expected gate locus"] for row in custody if row["kind"] == "mutant"}
    wanted_descriptors = {f"gate-red:phase_30_{Path(row['body']).name}" for row in mutants}
    if descriptors != wanted_descriptors:
        raise GateFailure("Phase-47 mutant custody descriptors must name custody phase 30 exactly")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 generated checking corpus; protocol and runtime remain UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    return tools, mutations, mutants


def item_classes() -> dict[str, str]:
    classes = {row["entry"]: row["class"] for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"]] = "mutant"
    return classes


def verify_source_boundaries() -> None:
    source = (ROOT / "src/tool-and-mutant-generation/Amoebius/Generate/CheckingCorpus.hs").read_text(encoding="utf-8")
    suite = (ROOT / "test/spec/generation/ToolAndMutantGenerationSpec.hs").read_text(encoding="utf-8")
    if "writeGeneratedCorpus :: FilePath -> [GeneratedArtifact] -> IO ()" not in source:
        raise GateFailure("recipe-total-and-caller-owned: generator does not accept its output root")
    if '".build/' in source or '"tools/' in source:
        raise GateFailure("recipe-total-and-caller-owned: generator hard-codes an authored or build root")
    if "OutputPolicy = BuildTree | AuthoredTree" not in source or "outputPolicy = BuildTree" not in source:
        raise GateFailure("recipe-total-and-caller-owned: output policy is not closed and build-only")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for name, body in (("CheckingCorpus.hs", source), ("ToolAndMutantGenerationSpec.hs", suite)):
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", body))
        match = prohibited.search(stripped)
        if match:
            raise GateFailure(f"recipe-total-and-caller-owned: partial token {match.group(0)!r} in {name}")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for flag in FLAGS:
        macro = flag.upper().replace("-", "_")
        if f"-D{macro}" not in cabal:
            raise GateFailure(f"mutant-registry-complete: {flag} has no CPP selector")
    for component in ("library tool-and-mutant-generation", "test-suite tool-and-mutant-generation-spec"):
        stanza = cabal.split(component, 1)[1].split("\n\n", 1)[0]
        for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
            if option not in stanza:
                raise GateFailure(f"recipe-total-and-caller-owned: {component} lacks {option}")


def configuration(enabled: str | None = None) -> list[str]:
    return [("-f" if flag == enabled else "-f-") + flag for flag in FLAGS]


def build_binary(cabal: Path, enabled: str | None = None) -> Path:
    flags = configuration(enabled)
    run([str(cabal), "build", "test:tool-and-mutant-generation-spec", *flags])
    binary = Path(run([str(cabal), "list-bin", "test:tool-and-mutant-generation-spec", *flags]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("tool-and-mutant-generation-spec binary is not an absolute file")
    return binary


def materialize(binary: Path, output: Path, *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    if output.exists():
        shutil.rmtree(output)
    return run([str(binary), "--output", str(output)], require_success=require_success)


def artifact_bytes(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in sorted(root.rglob("*")) if path.is_file()
    }


def run_green(cabal: Path) -> tuple[str, dict[str, bytes]]:
    binary = build_binary(cabal)
    first = materialize(binary, RENDER_ROOT / "render-a")
    second = materialize(binary, RENDER_ROOT / "render-b")
    first_bytes = artifact_bytes(RENDER_ROOT / "render-a")
    second_bytes = artifact_bytes(RENDER_ROOT / "render-b")
    if len(first_bytes) != 605 or len(second_bytes) != 605:
        raise GateFailure("two-render-byte-equality: a render does not contain 605 artifacts")
    if first_bytes != second_bytes:
        raise GateFailure("two-render-byte-equality: rendered paths or bytes differ")
    for output in (first.stdout, second.stdout):
        if ACCEPTANCE_TOKEN not in output or CALCULUS_TOKEN not in output:
            raise GateFailure("clean materialization acceptance tokens are absent")
    return first.stdout + second.stdout, first_bytes


def source_workspace() -> None:
    if WORKSPACE_ROOT.exists():
        shutil.rmtree(WORKSPACE_ROOT)
    for relative in gate_common.artifact_policy.snapshot_paths():
        source = ROOT / relative
        target = WORKSPACE_ROOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    shutil.rmtree(WORKSPACE_ROOT / "tools")
    shutil.copytree(RENDER_ROOT / "render-a/tools", WORKSPACE_ROOT / "tools")


def normalized_output(
    result: subprocess.CompletedProcess[str], root: Path, concern: str
) -> tuple[int, str]:
    output = result.stdout.replace(str(root), "<ROOT>")
    if concern == "phase-contract":
        output = re.sub(
            r"phase_contract_lint: \d+ of (\d+) contracts have no gate script yet",
            r"phase_contract_lint: <MISSING> of \1 contracts have no gate script yet",
            output,
        )
    return result.returncode, output


def equivalence_commands(root: Path) -> list[tuple[str, list[str]]]:
    python = sys.executable
    return [
        ("doc-lint", [python, str(root / "tools/doc_lint.py"), "--root", str(root), "--summary"]),
        ("phase-contract", [python, str(root / "tools/phase_contract_lint.py"), "--root", str(root), "--only", "d8", "--summary"]),
        ("locus-registry", [python, str(root / "tools/locus_registry_lint.py"), "--root", str(root)]),
        ("covering-grid", [python, str(root / "tools/covering_grid.py")]),
    ]


def compare_verdicts() -> tuple[str, str]:
    source_workspace()
    logs: list[str] = []
    for (source_name, source_command), (generated_name, generated_command) in zip(
        equivalence_commands(ROOT), equivalence_commands(WORKSPACE_ROOT),
    ):
        if source_name != generated_name:
            raise GateFailure("whole-corpus-equivalence: concern order drifted")
        source_result = run(source_command, require_success=False, cwd=ROOT)
        generated_result = run(generated_command, require_success=False, cwd=WORKSPACE_ROOT)
        source_observation = normalized_output(source_result, ROOT, source_name)
        generated_observation = normalized_output(generated_result, WORKSPACE_ROOT, generated_name)
        if source_observation != generated_observation:
            raise GateFailure(
                f"whole-corpus-equivalence: {source_name} verdict differs\n"
                f"authored={source_observation}\ngenerated={generated_observation}"
            )
        if source_result.returncode != 0:
            raise GateFailure(f"whole-corpus-equivalence: clean {source_name} corpus is red")
        logs.append(f"{source_name}: PASS\n{source_result.stdout}")
    isolated, observer = isolated_checker(equivalence_commands(WORKSPACE_ROOT)[0][1])
    logs.append(f"network-isolated: {observer}\n{isolated}")
    return "\n".join(logs), observer


def isolated_checker(command: list[str]) -> tuple[str, str]:
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if shutil.which("unshare") and run(["unshare", "-n", "true"], require_success=False).returncode == 0:
            result = run(["unshare", "-n", *command], cwd=WORKSPACE_ROOT)
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
                raise GateFailure(f"sandbox-exec denial control exited {control.returncode}")
            result = run(["sandbox-exec", "-f", str(profile), *command], cwd=WORKSPACE_ROOT)
            observer = "darwin-sandbox-deny-network"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("no sanctioned denied-network observer is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "signal=none",
                "-e", "inject=socket:error=EPERM", "-o", str(trace), *command,
            ], cwd=WORKSPACE_ROOT)
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("generated checker attempted a network syscall")
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in mutants:
        binary = build_binary(cabal, row["flag"])
        result = materialize(binary, RENDER_ROOT / f"mutant-{row['mutant']}", require_success=False)
        locus = row["expected_red_locus"]
        token = f"tool-and-mutant-generation-mutant: RED {row['mutant']} {locus}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its exact locus: {row['mutant']}\n{result.stdout}")
        logs.append(result.stdout)
        reddened += 1
    restored = build_binary(cabal)
    restored_result = materialize(restored, RENDER_ROOT / "restored")
    if ACCEPTANCE_TOKEN not in restored_result.stdout or CALCULUS_TOKEN not in restored_result.stdout:
        raise GateFailure("clean tool generation configuration did not restore")
    logs.append("tool-and-mutant-generation-mutant: restored PASS\n" + restored_result.stdout)
    return "\n".join(logs), reddened


def write_results(reddened: int, observer: str) -> None:
    metrics = {
        "tool-sources": "234/234-exact",
        "mutation-declarations": "371/371-exact",
        "generated-artifacts": "605/605-build-only",
        "renders": "2/2-complete",
        "byte-determinism": "605/605-byte-identical",
        "equivalence": "4/4-whole-corpus",
        "mutants": f"{reddened}/3-red",
        "tracked-output": "0-generated-in-source",
        "content-addresses": "605/605-sha256",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "605,2,605,4,3",
        "calculus-resource-vector": "5,1219,0,0",
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
        phase=47, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    classes: dict[str, str] = {}
    reddened = 0
    observer = "unrun"
    addresses: dict[str, str] = {}

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — checking-corpus generator tools resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<16} satisfies {record['requirement']}")
        globals()["COMPILER"] = resolved["ghc"]["path"]
        results["toolchain"] = True
        for path in (BUILD_ROOT, OUTPUT_ROOT):
            if path.exists():
                shutil.rmtree(path)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — closed tool and mutation inventories, calculus, custody, and mutants\n")
        tools, mutations, mutant_rows = verify_oracles()
        classes = item_classes()
        print("  ok    tool-source-inventory-exact")
        print("  ok    mutation-inventory-exact")
        print("  ok    semantic-oracles-complete")
        print("  ok    mutant-registry-complete")
        print(f"  ok    {len(tools)} tool sources, {len(mutations)} mutation declarations")
        results["oracle"] = True

        print("\nsource side — total Haskell recipe with a caller-owned build destination\n")
        verify_source_boundaries()
        print("  ok    recipe-total-and-caller-owned")
        results["source"] = True

        print("\nrender side — two complete byte-identical generated corpora\n")
        render_log, first_bytes = run_green(cabal)
        (gate.run_dir / "render.log").write_text(render_log, encoding="utf-8")
        addresses = {
            path: "sha256:" + gate_common.artifact_policy.digest(str(RENDER_ROOT / "render-a" / path))
            for path in sorted(first_bytes)
        }
        (OUTPUT_ROOT / "content-addresses.json").write_text(
            json.dumps(addresses, indent=2, sort_keys=True) + "\n", encoding="utf-8",
        )
        print("  ok    two-render-byte-equality")
        print(f"  ok    generated-content-addresses ({len(addresses)} SHA-256 observations)")
        results["render"] = True

        print("\nequivalence side — generated mechanisms reproduce four authored whole-corpus verdicts\n")
        equivalence_log, observer = compare_verdicts()
        (gate.run_dir / "equivalence.log").write_text(equivalence_log, encoding="utf-8")
        if observer not in SANCTIONED_OBSERVERS:
            raise GateFailure(f"network observer {observer!r} is not sanctioned")
        print("  ok    whole-corpus-equivalence (4/4)")
        print(f"  ok    network-isolated-reference ({observer})")
        results["equivalence"] = True

        print("\nmutant side — missing rule, missing operator, and tracked-output defects\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/3 mutants reddened and clean configuration restored")
        results["mutant"] = True

        write_results(reddened, observer)
        rows = gate_common.metric_rows(RESULTS)
        compared = dict(rows)
        if compared.get("network-observer") in SANCTIONED_OBSERVERS:
            compared["network-observer"] = "sanctioned-observer"
        oracle_ok = gate_common.oracle_side(compared, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent, OUTPUT_ROOT], (".tsv", ".py", ".sh", ".json", ".patch", ".mutant", ".txt", ".dhall", ".hs", ".md"),
            gate.run_dir, check="emitted-results-untracked",
            label="generated checking tools and mutation corpus stay generated",
        )
        source_snapshot = set(gate_common.artifact_policy.snapshot_paths())
        leaked = [str(path.relative_to(ROOT)) for path in RENDER_ROOT.rglob("*") if path.is_file() and str(path.relative_to(ROOT)) in source_snapshot]
        if leaked:
            raise GateFailure(f"generated-output-untracked: generated paths entered source snapshot: {leaked[:5]}")
        print("  ok    generated-output-untracked")
        rows = compared
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"tool-and-mutant-generation-gate: FAIL: {problem}", file=sys.stderr)

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
        if rows.get("equivalence") == EXPECTED_RESULTS["equivalence"]
        and rows.get("byte-determinism") == EXPECTED_RESULTS["byte-determinism"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    observations = {}
    if RESULTS.is_file():
        observations["results"] = "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))
    if (OUTPUT_ROOT / "content-addresses.json").is_file():
        observations["content-addresses"] = "sha256:" + gate_common.artifact_policy.digest(
            str(OUTPUT_ROOT / "content-addresses.json")
        )
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(classes)},
        rows=rows, evidence=evidence, layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items() if name != "platform"
        },
        dependencies={
            "tool-and-mutant-generation-spec": "cabal build/list-bin",
            "generated-whole-corpus-checkers": "four Python reference comparisons",
        },
        mutants=[
            {"name": row["mutant"], "status": "red" if reddened == len(mutant_rows) else "unrun"}
            for row in mutant_rows
        ] or [{"name": "phase-47 mutants", "status": "unrun"}],
        observations=observations,
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
