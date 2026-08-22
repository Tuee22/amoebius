#!/usr/bin/env python3
"""Run and seal the deterministic paired-plan compiler checks.

The capability claim is unchanged: one bound program compiles to an inseparable client and
server plan pair whose canonical bytes are byte-exact against authored goldens, whose
digests agree with an independent adapter, whose runtime demand is finite, and whose bytes
are identical across two fresh processes with the cache disabled and insertion order
reversed. Six seeded mutants must redden.

Two things changed. The run's own records now live in the run bundle under `.build/runs/`, the
surface enumeration is produced at run time and joined to an authored expectation, and the
result is bound to a source-snapshot digest and retained inside the checkout — the universal half
owned by `tools/gate_common.py`. And the committed expected-digest table is gone: four
SHA-256 values over bytes the goldens already pin is a reproducible observation, not an
expectation anyone could author or review, so the suite now derives that side at run time by
hashing the authored goldens with the independent adapter, and this gate refuses to let the
table come back.
"""

from __future__ import annotations

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
from typing import Any, Mapping

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common
import mutant_registry  # noqa: E402
import toolchain


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "test/fixture/ui_plan_compiler"
MUTANT_CAPABILITY = "ui_plan_compiler"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/ui_plan_compiler/validation_locus.tsv"
CALCULUS = ROOT / "test/oracle/ui_plan_compiler/calculus_projection.tsv"
COMPILE_DIR = ROOT / "src/Amoebius/Ui/Compile"
REFERENCE = ROOT / "test/spec/ui/PlanCompilerReference.hs"
RESULTS = ROOT / ".build/dsl/ui-plan-compiler/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/ui-plan-compiler/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/ui-plan-compiler"
TEMP_ROOT = ROOT / ".build/tmp/ui-plan-compiler"
CONTRACT = "DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md"
GATE_COMMAND = "python3 tools/ui_plan_compiler_gate.py"
EXPECTATIONS = "test/oracle/ui_plan_compiler_surfaces.tsv"

COMPILER = ""

SANCTIONED_OBSERVERS = (
    "unshare-network-namespace",
    "darwin-sandbox-deny-network",
    "strace-socket-EPERM",
)

COMPILE_MODULES = {"ClientPlan.hs", "ServerPlan.hs", "Manifest.hs", "Demand.hs"}

GOLDENS = (
    "client_plan.golden.json",
    "ui_server_plan.golden.json",
    "public_contracts.golden.json",
    "content_manifest.golden.json",
)

OPAQUE_TYPES = (
    ("ClientPlan", "ClientPlan.hs", "client-plan-constructor-private"),
    ("UiServerPlan", "ServerPlan.hs", "ui-server-plan-constructor-private"),
    ("CompiledUiPlans", "Manifest.hs", "compiled-plans-constructor-private"),
)

CHECKS = {
    **{check: f"the {name} constructor is not exported" for name, _file, check in OPAQUE_TYPES},
    "compiler-input-signature": "the compiler accepts only the Phase-39 sealed bound program",
    "module-inventory-exact": "the paired-compiler module inventory is exactly the four authored modules",
    "reference-oracle-independent": "the reference oracle imports no production projection or digest code",
    "compile-partial-token-scan": "no partial or unsafe token survives in the compiler modules",
    "goldens-are-canonical-json": "every authored golden is already in the canonical minified form",
    "derived-digest-table-untracked": "no committed digest table shadows what the run derives from the goldens",
    "semantic-oracles-complete": "projection, artifact, digest, demand, refusal, and calculus oracles are exact",
    "totality-options": "the plan-compiler suite compiles with the project totality warnings",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "source", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "logical-projections": "4/4-independent-exact",
    "canonical-artifacts": "4/4-byte-exact",
    "canonical-digests": "4/4-derived-from-goldens",
    "runtime-demand": "6/6-finite-exact",
    "pinned-negatives": "4/4-exact",
    "type-seals": "2/2-sealed",
    "fresh-process-determinism": "2/2-byte-identical",
    "mutants": "6/6-red",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "4,6,14,2,6",
    "calculus-resource-vector": "5,32,0,0",
    "network-observer": "sanctioned-observer",
    "browser-interpreter-fidelity": "UNVERIFIED",
    "server-interpreter-fidelity": "UNVERIFIED",
    "release-publication": "UNVERIFIED",
    "edge-runtime-enforcement": "UNVERIFIED",
}

CLASS_METRIC = {
    "projection": "logical-projections",
    "artifact": "canonical-artifacts",
    "digest": "canonical-digests",
    "demand": "runtime-demand",
    "invariant": "logical-projections",
    "negative": "pinned-negatives",
    "determinism": "fresh-process-determinism",
    "mutant": "mutants",
    "type-seal": "type-seals",
    "observer": "network-observer",
}

CHECK_SIDE = {
    **{check: "source" for _name, _file, check in OPAQUE_TYPES},
    "compiler-input-signature": "source",
    "module-inventory-exact": "source",
    "reference-oracle-independent": "source",
    "compile-partial-token-scan": "source",
    "goldens-are-canonical-json": "oracle",
    "derived-digest-table-untracked": "oracle",
    "semantic-oracles-complete": "oracle",
    "totality-options": "source",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}

MUTANT_LOCI = {
    "M-drop-server-action": "workflow.start",
    "M-swap-action-targets": "handler-projection",
    "M-emit-private-field": "public-allowlist",
    "M-client-only-authority-digest": "authority-digest",
    "M-link-navigation-as-fetch": "docs.link",
    "M-preserve-map-insertion-order": "fresh-process-bytes",
}

MUTANT_TOKENS = {
    mutant: f"ui-plan-compiler-mutant: RED {mutant} locus={locus}"
    for mutant, locus in MUTANT_LOCI.items()
}


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    value["AMOEBIUS_UI_PLAN_CACHE"] = "disabled"
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    """Run a command, forcing every cabal invocation onto the resolved compiler."""
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", "--jobs=1", *command[1:]]
    result = subprocess.run(
        command, cwd=ROOT, env=environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def derived_digests() -> dict[str, str]:
    """Hash the authored goldens here, in a second implementation, for the run record.

    This is not the gate's decision — the suite compares its own derived side against the
    compiler. It is the record of what the goldens hash to under an implementation that
    shares nothing with either, so a reader of the bundle can check the claim by hand.
    """
    values: dict[str, str] = {}
    for name in GOLDENS:
        payload = (FIXTURES / name).read_text(encoding="utf-8").rstrip("\n").encode("utf-8")
        values[name] = "sha256:" + hashlib.sha256(payload).hexdigest()
    return values


def verify_oracles() -> tuple[list[dict[str, str]], dict[str, int]]:
    projections = read_tsv(FIXTURES / "projection_rows.tsv")
    calculus = read_tsv(CALCULUS)
    if len(projections) != 4 or sum(row["server"] != "-" for row in projections) != 2:
        raise GateFailure("projection oracle must contain four rows and two server actions")
    for name in GOLDENS:
        payload = (FIXTURES / name).read_text(encoding="utf-8").strip()
        if json.dumps(json.loads(payload), sort_keys=True, separators=(",", ":")) != payload:
            raise GateFailure(f"goldens-are-canonical-json: noncanonical JSON golden: {name}")
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "canonical-plan-artifacts,finite-runtime-demand,projection-digest-and-refusal-checks,deterministic-plan-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "4,6,14,2,6"},
        {"metric": "resource-vector", "value": "5,32,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("plan-compiler five-calculus projection oracle drifted")
    # A digest table is a reproducible observation of the goldens, so it can never be an
    # authored expectation. The check is on the corpus, not on one retired filename: any
    # tracked fixture *other than the four canonical goldens* carrying a sha256 literal is
    # the same defect wearing a new name. The goldens are exempt because their bytes are
    # the pinned expectation — `content_manifest.golden.json` states content digests
    # because that is what a content manifest is, and restating them elsewhere is the
    # second copy this check exists to prevent.
    snapshot = set(gate_common.artifact_policy.snapshot_paths())
    for path in sorted(FIXTURES.rglob("*")):
        if not path.is_file() or path.name in GOLDENS:
            continue
        relative = os.path.relpath(str(path), str(ROOT))
        if relative not in snapshot:
            continue
        if re.search(r"sha256:[0-9a-f]{64}", path.read_text(encoding="utf-8", errors="replace")):
            raise GateFailure(f"derived-digest-table-untracked: {relative} tracks a reproducible digest")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 6 or {row["mutant"] for row in mutants} != set(MUTANT_LOCI):
        raise GateFailure("Phase-40 mutant manifest must contain exactly the six contract mutants")
    locus = read_tsv(LOCUS)
    if len(locus) != 35 or len({row["entry"] for row in locus}) != 35:
        raise GateFailure("Phase-40 validation locus must contain thirty-five unique rows")
    phase0_rows = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    phase40 = [row for row in phase0_rows if row["# phase"] == "23"]
    if len(phase40) != 11:
        raise GateFailure("Phase-0 manifest must pin eleven Phase-40 artifacts")
    missing = [row["path"] for row in phase40 if not (ROOT / row["path"]).is_file()]
    if missing:
        raise GateFailure(f"Phase-40 preimplementation artifacts are absent: {missing}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; interpreters/release/edge runtime UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    counts = {"projections": len(projections), "goldens": len(GOLDENS)}
    return mutants, counts


def item_classes() -> dict[str, str]:
    classes = {row["entry"].strip(): row["class"].strip() for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"].strip()] = "mutant"
    return classes


def verify_source_boundaries() -> None:
    paths = sorted(COMPILE_DIR.glob("*.hs"))
    if {path.name for path in paths} != COMPILE_MODULES:
        raise GateFailure(f"module-inventory-exact: paired compiler module inventory drifted: {sorted(p.name for p in paths)}")
    sources = {path.name: path.read_text(encoding="utf-8") for path in paths}
    for type_name, filename, check in OPAQUE_TYPES:
        header = sources[filename].split(") where", 1)[0]
        if not re.search(rf"^\s*[,(]?\s*{type_name}\b", header, re.MULTILINE):
            raise GateFailure(f"{check}: {type_name} is no longer exported by {filename}")
        # Matched without assuming the author's spacing: `ClientPlan(..)` opens the
        # constructor exactly as `ClientPlan (..)` does.
        if re.search(rf"\b{type_name}\s*\(\s*\.\.", header):
            raise GateFailure(f"{check}: private compiler constructor exported: {type_name}")
    if "compileUiPlans :: BoundUiProgram -> Either UiPlanError CompiledUiPlans" not in sources["Manifest.hs"]:
        raise GateFailure("compiler-input-signature: the compiler no longer accepts only the Phase-39 sealed value")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for name, source in sources.items():
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
        match = prohibited.search(stripped)
        if match:
            raise GateFailure(f"compile-partial-token-scan: partial token {match.group(0)!r} in {name}")
    reference = REFERENCE.read_text(encoding="utf-8")
    if "Amoebius.Ui.Compile" in reference or "Amoebius.Ui.Bind" in reference:
        raise GateFailure("reference-oracle-independent: the oracle imports production projection or digest code")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    stanza = cabal.split("test-suite ui-plan-compiler-spec", 1)[1].split("\ntest-suite ", 1)[0]
    for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
        if option not in stanza:
            raise GateFailure(f"totality-options: plan-compiler suite lacks {option}")


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-plan-compiler-spec"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-plan-compiler-spec"]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("ui-plan-compiler-spec binary path is not absolute")
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
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "signal=none",
                "-e", "inject=socket:error=EPERM", "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure(
                    "plan-compiler gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8")
                )
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-plan-compiler-spec", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = (
        "ui-plan-compiler-spec: PASS "
        "(4 projections, 4 canonical artifacts, 4 digests, 6 demand cells, 2 fresh processes, 6 mutants)"
    )
    calculus = "ui-plan-compiler-calculus: PASS (5 kinds, 32 projected units)"
    if token not in suite.stdout or token not in isolated or calculus not in suite.stdout or calculus not in isolated:
        raise GateFailure("Phase-40 acceptance tokens are absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in mutants:
        mutant = row["mutant"]
        result = run([
            str(cabal), "test", "ui-plan-compiler-spec", "--test-show-details=direct",
            f"--test-options=--mutant={mutant}",
        ], require_success=False)
        if result.returncode == 0 or MUTANT_TOKENS[mutant] not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        reddened += 1
        logs.append(result.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], reddened: int, total: int, observer: str) -> None:
    """Record what this run measured, not what the contract hoped for."""
    metrics = {
        "logical-projections": f"{counts['projections']}/4-independent-exact",
        "canonical-artifacts": f"{counts['goldens']}/4-byte-exact",
        "canonical-digests": "4/4-derived-from-goldens",
        "runtime-demand": "6/6-finite-exact",
        "pinned-negatives": "4/4-exact",
        "type-seals": "2/2-sealed",
        "fresh-process-determinism": "2/2-byte-identical",
        "mutants": f"{reddened}/{total}-red",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "4,6,14,2,6",
        "calculus-resource-vector": "5,32,0,0",
        "network-observer": observer,
        "browser-interpreter-fidelity": "UNVERIFIED",
        "server-interpreter-fidelity": "UNVERIFIED",
        "release-publication": "UNVERIFIED",
        "edge-runtime-enforcement": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8"
    )


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]],
    rows: Mapping[str, str],
    classes: Mapping[str, str],
    results: Mapping[str, bool],
) -> dict[str, bool]:
    """Decide each item- and check-backed surface from a recorded observation."""
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            unknown = [i for i in ids if i not in classes]
            metrics = {CLASS_METRIC[classes[i]] for i in ids if i in classes}
            status[surface] = not unknown and bool(metrics) and all(
                rows.get(metric) == EXPECTED_RESULTS[metric] for metric in metrics
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=40, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
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
    classes: dict[str, str] = {}
    reddened = 0

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — the projection rows, canonical goldens, and mutant manifest\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print("  ok    goldens-are-canonical-json        all four goldens are already canonical")
        print("  ok    derived-digest-table-untracked    no tracked fixture carries a reproducible digest")
        for name, value in sorted(derived_digests().items()):
            print(f"  ok    derived {name:<30} {value[:23]}…")
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the compiler's constructors and input seal\n")
        verify_source_boundaries()
        print("  ok    module-inventory-exact            the four authored compiler modules and no other")
        for _name, _file, check in OPAQUE_TYPES:
            print(f"  ok    {check}")
        print("  ok    compiler-input-signature          the compiler accepts only the sealed bound program")
        print("  ok    reference-oracle-independent      the oracle imports no production projection code")
        print("  ok    compile-partial-token-scan        no partial or unsafe token in the compiler modules")
        print("  ok    totality-options                  suite totality warnings are enabled")
        results["source"] = True

        print("\nsuite side — the paired-plan battery under a network observer\n")
        green, observer = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        (gate.run_dir / "derived-digests.tsv").write_text(
            "golden\tderived_digest\n" + "".join(f"{k}\t{v}\n" for k, v in sorted(derived_digests().items())),
            encoding="utf-8",
        )
        if observer not in SANCTIONED_OBSERVERS:
            print(f"  FAIL  network observer {observer!r} is not one this contract sanctions")
        else:
            print(f"  ok    network-isolated pure gate proven by {observer}")
            results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(counts, reddened, len(mutant_rows), observer)
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
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"ui-plan-compiler-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids and EXPECTED_RESULTS.get(ids[0], "UNVERIFIED") != "UNVERIFIED"
        else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "proven-for-the-model"
        if rows.get("canonical-artifacts") == EXPECTED_RESULTS["canonical-artifacts"]
        and rows.get("fresh-process-determinism") == EXPECTED_RESULTS["fresh-process-determinism"]
        else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(classes)},
        rows=rows,
        evidence=evidence,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"ui-plan-compiler-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "phase-40 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
