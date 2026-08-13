#!/usr/bin/env python3
"""Run and seal the composite Phase-14 kernel, boundary, and Gate-3 checks."""

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
MUTANTS = ROOT / "tests/mutants/phase14/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase14/validation_locus.tsv"
AST_ORACLE = ROOT / "test/fixtures/phase14/astcheck/astcheck_negatives.expected"
RESULTS = ROOT / "gen/dsl/phase14/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase14/validation-locus-ledger.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md"
GATE_COMMAND = "python3 tools/phase14_gate.py"


class GateFailure(RuntimeError):
    pass


def scrubbed_environment() -> dict[str, str]:
    environment = dict(os.environ)
    exact = {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}
    prefixes = ("AWS_", "AZURE_", "VAULT_", "KUBE_")
    for name in list(environment):
        if name in exact or name.startswith(prefixes):
            environment.pop(name, None)
    return environment


def run(
    command: list[str],
    *,
    require_success: bool = True,
    environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    # Every cabal invocation carries the resolved compiler. Without it cabal picks whatever
    # `ghc` the ambient PATH offers, and on a host holding a newer GHC the solver rejects
    # `base` — a failure with nothing to do with this phase's claim.
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", *command[1:]]
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment or scrubbed_environment(),
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
    executables = {name: Path(pins[name]["path"]) for name in ("cabal", "ghc", "dhall")}
    for executable in executables.values():
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(
        run([str(executable), "--numeric-version"] if name != "dhall" else [str(executable), "--version"]).stdout
        for name, executable in executables.items()
    )
    for family in executables:
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return executables["cabal"], executables["dhall"], versions


def verify_oracles(dhall: Path) -> list[dict[str, str]]:
    mutants = read_tsv(MUTANTS)
    locus = read_tsv(LOCUS)
    ast_rows = read_tsv(AST_ORACLE)
    cfgs = sorted((ROOT / "test/kernel/fixtures/cfg").glob("*.cfg.json"))
    plans = sorted((ROOT / "test/kernel/fixtures/plan").glob("*.plan.golden"))
    descents = sorted((ROOT / "test/kernel/fixtures/descent").glob("*.descent.golden"))
    if len(cfgs) != 2 or len(plans) != 2 or len(descents) != 2:
        raise GateFailure("Phase-14 Part-A corpus must contain two cfg, plan, and descent fixtures")
    expected_steps = json.loads((ROOT / "test/kernel/fixtures/plan/expected_steps.json").read_text(encoding="utf-8"))
    if set(expected_steps) != {"minimal", "multi"} or any(not labels for labels in expected_steps.values()):
        raise GateFailure("Phase-14 independent step-set oracle is incomplete")
    reasons = {row["reason"] for row in ast_rows}
    if len(ast_rows) != 6 or reasons != {"UnsanctionedImport", "RawIO", "ForeignCall", "UnsafeOperation", "TemplateHaskell", "OrphanInstance"}:
        raise GateFailure("Gate-3 oracle must enumerate all six violation reasons exactly once")
    if len(mutants) != 7 or len({row["mutant"] for row in mutants}) != 7:
        raise GateFailure("Phase-14 mutant manifest must contain seven unique mutants")
    if len(locus) != 20 or len({row["entry"] for row in locus}) != 20:
        raise GateFailure("Phase-14 validation-locus ledger must contain twenty unique rows")
    for path in [*cfgs, *plans, *descents, ROOT / "test/kernel/fixtures/plan/expected_steps.json"]:
        if not path.is_file() or not path.read_bytes():
            raise GateFailure(f"empty oracle fixture: {path.relative_to(ROOT)}")
    for tool in ("kubectl", "docker", "helm", "pulumi"):
        fake = ROOT / f"test/boundary/fakes/{tool}"
        if not fake.is_file() or not os.access(fake, os.X_OK):
            raise GateFailure(f"fake tool is absent or not executable: {tool}")
    argv_goldens = list((ROOT / "test/boundary/golden/argv").glob("*.argv.golden"))
    if len(argv_goldens) != 4 or any(not path.read_bytes() for path in argv_goldens):
        raise GateFailure("boundary argv oracle must contain four non-empty transcripts")
    sanctioned = run([str(dhall), "type", "--file", "dhall/amoebius/SanctionedApi.dhall", "--quiet"], require_success=False)
    if sanctioned.returncode != 0:
        raise GateFailure(f"sanctioned API Dhall oracle is ill-typed:\n{sanctioned.stdout}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Registers 1/2 only; live tools, apiserver apply, and runtime correspondence UNVERIFIED\n" + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    return mutants


def verify_source_boundaries() -> None:
    total_paths = [
        *sorted((ROOT / "src/Amoebius/Kernel").glob("*.hs")),
        ROOT / "src/Amoebius/Cli.hs",
        ROOT / "src/Amoebius/Exec/Tool.hs",
        ROOT / "src/Amoebius/Host/Ensure.hs",
        ROOT / "src/Amoebius/Dsl/SanctionedApi.hs",
        ROOT / "src/Amoebius/Dsl/AstCheck.hs",
    ]
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path in total_paths:
        source = path.read_text(encoding="utf-8")
        without_comments = re.sub(r"--[^\n]*", "", source)
        without_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', without_comments)
        match = prohibited.search(without_strings)
        if match:
            raise GateFailure(f"partial or unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")
    plan_surface = (ROOT / "src/Amoebius/Kernel/Plan.hs").read_text(encoding="utf-8") + (ROOT / "src/Amoebius/Cli.hs").read_text(encoding="utf-8")
    if any(token in plan_surface for token in ("System.Process", "Network.", "Vault", "KUBECONFIG", "unsafePerformIO")):
        raise GateFailure("dry-run surface reaches a process/network/credential module")
    step_header = (ROOT / "src/Amoebius/Kernel/Step.hs").read_text(encoding="utf-8").split(") where", 1)[0]
    if "Step (.." in step_header:
        raise GateFailure("raw Step constructor is exported")
    ast_header = (ROOT / "src/Amoebius/Dsl/AstCheck.hs").read_text(encoding="utf-8").split(") where", 1)[0]
    if "CheckedExtensionSource (.." in ast_header:
        raise GateFailure("CheckedExtensionSource constructor is exported")
    primitive_pattern = re.compile(r"\b(createProcess|readProcess|callProcess|spawnProcess|readCreateProcess|callCommand|runProcess|startProcess|withProcessWait|executeFile|forkProcess|createSession)\b")
    primitive_hits: list[Path] = []
    for path in (ROOT / "src").rglob("*.hs"):
        if primitive_pattern.search(path.read_text(encoding="utf-8")):
            primitive_hits.append(path)
    # The declared subprocess sites. This is a whole-tree invariant, so the list has to
    # name every module in `src/` that legitimately reaches the primitive — not only the
    # ones Phase 14 itself wrote.
    #
    # Phase 24 tightened the original boundary behind the opaque AbsExe tool ensure;
    # Exec.Tool remains the Phase-14 compatibility facade and only Host.Ensure reaches the
    # primitive on that path. Amended 2026-08-12 for the three Phase-25 image modules: an
    # image build, its runtime, and its publish step invoke a builder by construction, and
    # a whole-tree list that omitted them would report a Phase-25 design decision as a
    # Phase-14 defect. The check stays exact — any site not named here still fails —
    # which is the property this phase actually claims
    # (development_plan_standards.md section M clause 1, amendment).
    expected = sorted(
        [
            ROOT / "src/Amoebius/Host/Ensure.hs",
            ROOT / "src/Amoebius/Image/Build.hs",
            ROOT / "src/Amoebius/Image/BuildRuntime.hs",
            ROOT / "src/Amoebius/Image/Publish.hs",
        ]
    )
    if sorted(primitive_hits) != expected:
        unexpected = sorted(set(primitive_hits) - set(expected))
        absent = sorted(set(expected) - set(primitive_hits))
        raise GateFailure(
            "subprocess primitive sites drifted: "
            + f"unexpected={[str(p.relative_to(ROOT)) for p in unexpected]} "
            + f"absent={[str(p.relative_to(ROOT)) for p in absent]}"
        )


def compile_link_seal(cabal: Path) -> str:
    legal = run([str(cabal), "exec", "ghc", "--", "-fno-code", "-XGHC2024", "-XOverloadedStrings", "-isrc", "test/fixtures/phase14/compilefail/checked_ctor_legal.hs"])
    illegal = run(
        [str(cabal), "exec", "ghc", "--", "-fno-code", "-XGHC2024", "-XOverloadedStrings", "-isrc", "test/fixtures/phase14/compilefail/checked_ctor_illegal.hs"],
        require_success=False,
    )
    if illegal.returncode == 0 or "Illegal term-level use of the type constructor ‘CheckedExtensionSource’" not in illegal.stdout:
        raise GateFailure(f"CheckedExtensionSource compile-fail seal drifted:\n{illegal.stdout}")
    return legal.stdout + illegal.stdout


def network_isolated_chain(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:chain-spec", "--offline"])
    binary = Path(run([str(cabal), "list-bin", "test:chain-spec", "--offline"]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("chain-spec binary path is not absolute")
    with tempfile.TemporaryDirectory(prefix="amoebius-phase14-") as directory:
        trace = Path(directory) / "network.trace"
        unshare_probe = run(["unshare", "-n", "true"], require_success=False)
        if unshare_probe.returncode == 0:
            isolated = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("neither unshare network isolation nor strace socket injection is available")
            isolated = run(["strace", "-f", "-qq", "-e", "trace=%network", "-e", "inject=socket:error=EPERM", "-o", str(trace), str(binary)])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("chain render attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    token = "chain-spec: PASS (2 cfg fixtures, 2 plan goldens, 2 descent goldens, 0 render actions, 1 canary, 2 mutants)"
    if token not in isolated.stdout:
        raise GateFailure(f"isolated chain acceptance token is absent:\n{isolated.stdout}")
    return isolated.stdout, observer


def run_green_suites(cabal: Path) -> tuple[str, str]:
    chain = run([str(cabal), "test", "chain-spec", "--offline", "--test-show-details=direct"])
    isolated, observer = network_isolated_chain(cabal)
    amoebius_binary = run([str(cabal), "list-bin", "exe:amoebius", "--offline"]).stdout.strip()
    environment = scrubbed_environment()
    environment["AMOEBIUS_BIN"] = amoebius_binary
    boundary = run([str(cabal), "test", "boundary-spec", "--offline", "--test-show-details=direct"], environment=environment)
    astcheck = run([str(cabal), "test", "astcheck-spec", "--offline", "--test-show-details=direct"])
    tokens = [
        "chain-spec: PASS (2 cfg fixtures, 2 plan goldens, 2 descent goldens, 0 render actions, 1 canary, 2 mutants)",
        "boundary-spec: PASS (4 real-binary invocations, 3 invoked tools, 1 zero-invocation helm control, exact argv and bytes, absolute paths, 3 mutants)",
        "astcheck-spec: PASS (2 positives, 6 exact reason/span negatives, 2 sanctioned modules, 4 sanctioned effects, opaque link seal, 2 mutants)",
    ]
    combined = chain.stdout + isolated + boundary.stdout + astcheck.stdout
    for token in tokens:
        if token not in combined:
            raise GateFailure(f"Phase-14 acceptance token is absent: {token}")
    return combined, observer


def verify_mutants(cabal: Path, mutants: list[dict[str, str]]) -> str:
    amoebius_binary = run([str(cabal), "list-bin", "exe:amoebius", "--offline"]).stdout.strip()
    boundary_environment = scrubbed_environment()
    boundary_environment["AMOEBIUS_BIN"] = amoebius_binary
    logs: list[str] = []
    for row in mutants:
        name = row["mutant"]
        if name.startswith("mB"):
            suite, token, environment = "boundary-spec", "phase14-boundary-mutant: RED", boundary_environment
        elif name.startswith("astcheck"):
            suite, token, environment = "astcheck-spec", "phase14-ast-mutant: RED", None
        else:
            suite, token, environment = "chain-spec", "phase14-chain-mutant: RED", None
        result = run(
            [str(cabal), "test", suite, "--offline", "--test-show-details=direct", f"--test-options=--mutant={name}"],
            require_success=False,
            environment=environment,
        )
        if result.returncode == 0 or f"{token} {name}" not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(mutants: list[dict[str, str]], observer: str) -> None:
    metrics = {
        "chain-fixtures": "2/2-plan-and-descent-byte-locked",
        "render-actions": "0-with-1/1-canary-observed",
        "network-observer": observer,
        "boundary-tools": "3/3-invoked-helm-0",
        "boundary-transcripts": "4/4-argv-and-bytes-exact",
        "astcheck": "2/2-positive-6/6-exact-negative",
        "compile-link-seal": "1/1-illegal-construction-rejected",
        "mutants": f"{len(mutants)}/{len(mutants)}-red",
        "live-tool-fidelity": "UNVERIFIED",
        "live-apiserver-apply": "UNVERIFIED",
        "runtime-correspondence": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")



COMPILER = ""

# The two observers this contract sanctions for proving the render path touched no network.
# Which one a host supports is a property of the host, not of amoebius, so the gate asserts
# membership and records the normalized result rather than pinning one of them.
SANCTIONED_OBSERVERS = ("unshare-network-namespace", "strace-socket-EPERM")

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/ghc/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "step-constructor-opaque": "the raw Step constructor is not exported",
    "dry-run-import-closure": "the dry-run surface reaches no process, network, or credential module",
    "subprocess-primitive-sites": "the subprocess primitive appears only at its declared sites",
    "partial-token-scan": "no partial or unsafe token survives in the kernel modules",
    "independent-step-set-oracle-complete": "the independent step-set oracle names both fixtures with labels",
    "fake-tools-executable": "every fake boundary tool is present and executable",
}

SIDES = ("toolchain", "oracle", "source", "seal", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "chain-fixtures": "2/2-plan-and-descent-byte-locked",
    "render-actions": "0-with-1/1-canary-observed",
    "network-observer": "sanctioned-observer",
    "boundary-tools": "3/3-invoked-helm-0",
    "boundary-transcripts": "4/4-argv-and-bytes-exact",
    "astcheck": "2/2-positive-6/6-exact-negative",
    "compile-link-seal": "1/1-illegal-construction-rejected",
    "mutants": "7/7-red",
    "live-tool-fidelity": "UNVERIFIED",
    "live-apiserver-apply": "UNVERIFIED",
    "runtime-correspondence": "UNVERIFIED",
}

SURFACE_MAP = {'opaque-step-constructor': 'step-constructor-opaque', 'counted-step-run': '', 'step-nfdata-excludes-action': '', 'whole-provisioned-plan-config': '', 'pure-chain-builder': '', 'identity-disjoint-step-projections': '', 'render-all-object-union': '', 'four-frame-activation-projection': '', 'pure-next-frame-after': '', 'pure-fold-lift': '', 'canonical-render-chain-plan': '', 'dry-run-effect-import-closure': 'dry-run-import-closure', 'zero-step-run-render': '', 'step-run-canary': 'render-actions', 'two-cfg-plan-goldens': 'minimal_cfg,multi_cfg', 'two-descent-goldens': 'chain-fixtures', 'independent-step-set-oracle': 'independent-step-set-oracle-complete', 'chain-mutant-battery': 'm1_cfg_drop_service,m2_descent_inframe', 'single-subprocess-seam': 'subprocess-primitive-sites', 'absolute-tool-path-seal': 'fake-tools-executable', 'real-binary-fake-boundary': 'boundary_corpus', 'exact-argv-transcripts': 'boundary-transcripts', 'exact-applied-bytes': '', 'hostile-path-canary': '', 'helm-zero-invocation-control': 'boundary-tools', 'boundary-mutant-battery': 'mB1_argv,mB2_byte,mB3_path_resolve', 'closed-sanctioned-api': 'sanctioned_api', 'no-raw-io-effect-arm': 'astcheck', 'six-arm-ast-violation-union': 'negative_import,negative_raw_io,negative_foreign,negative_unsafe,negative_template_haskell,negative_orphan', 'exact-ast-reason-span-corpus': 'positive_basic,positive_manifest', 'opaque-checked-extension-source': 'checked_ctor_illegal', 'checked-source-compile-fail-seal': 'compile-link-seal', 'astcheck-mutant-battery': 'astcheck-allow-rawio,astcheck-export-ctor', 'phase14-validation-locus-ledger': 'mutants', 'phase14-compile-totality': 'partial-token-scan', 'network-isolated-render-observer': 'network-observer', 'live-tool-fidelity': 'live-tool-fidelity', 'live-apiserver-apply': 'live-apiserver-apply', 'runtime-model-correspondence': 'runtime-correspondence', 'generated-artifact-discipline': 'emitted-results-untracked,toolchain-satisfies-requirements,recorded-results-match-oracle'}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    surface: ((ids, EXPECTED_RESULTS[ids]) if ids in EXPECTED_RESULTS and EXPECTED_RESULTS[ids] != "UNVERIFIED" else None)
    for surface, ids in SURFACE_MAP.items()
}


def enumerated_items() -> set[str]:
    names: set[str] = set()
    for relative in ("tests/oracle/phase14/validation_locus.tsv", "tests/mutants/phase14/mutants.tsv"):
        for line in (ROOT / relative).read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip():
                names.add(line.split("\t")[0].strip())
    return names


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=14, contract=CONTRACT, command=GATE_COMMAND, register="1/2", substrate="none", sides=SIDES
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

        print("\noracle side — Part-A corpus, Gate-3 reasons, fake tools, and the locus ledger\n")
        mutant_rows = verify_oracles(Path(resolved["dhall"]["path"]))
        item_names = enumerated_items()
        print(f"  ok    {len(item_names)} enumerated items, {len(mutant_rows)} mutants")
        print("  ok    independent-step-set-oracle-complete both fixtures named with labels")
        print("  ok    fake-tools-executable    every fake boundary tool present and executable")
        results["oracle"] = True

        print("\nsource side — the kernel's export and import boundaries\n")
        verify_source_boundaries()
        print("  ok    step-constructor-opaque      the raw Step constructor is not exported")
        print("  ok    dry-run-import-closure       no process, network, or credential module on the dry-run surface")
        print("  ok    subprocess-primitive-sites   the subprocess primitive appears only at its declared sites")
        print("  ok    partial-token-scan           no partial or unsafe token in the kernel modules")
        results["source"] = True

        print("\nseal side — the checked-source compile-fail seal\n")
        compile_log = compile_link_seal(cabal)
        (gate.run_dir / "compile-fail.log").write_text(compile_log, encoding="utf-8")
        print("  ok    the illegal construction is rejected at its authored locus")
        results["seal"] = True

        print("\nsuite side — Part A, Part B, and the network-isolated render observer\n")
        suites, observer = run_green_suites(cabal)
        (gate.run_dir / "suites.log").write_text(suites, encoding="utf-8")
        if observer not in SANCTIONED_OBSERVERS:
            print(f"  FAIL  network observer {observer!r} is not one this contract sanctions")
        else:
            print(f"  ok    network-isolated render proven by {observer}")
            results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log = verify_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {len(mutant_rows)}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(mutant_rows, observer)
        rows = gate_common.metric_rows(RESULTS)
        # The observer is normalized to the membership the contract actually admits, so a
        # host that reaches the same conclusion by the other sanctioned route still passes.
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
        print(f"phase14-gate: FAIL: {problem}", file=sys.stderr)

    item_evidence = {
        surface: ("mutants", EXPECTED_RESULTS["mutants"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & item_names
    }
    check_evidence = {
        surface: ("mutants", EXPECTED_RESULTS["mutants"])
        for surface, ids in SURFACE_MAP.items()
        if ids and set(ids.split(",")) & set(CHECKS) and results.get("source") and results.get("oracle")
    }
    layers = {
        "Decision": "tested" if rows.get("chain-fixtures") == EXPECTED_RESULTS["chain-fixtures"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("boundary-transcripts") == EXPECTED_RESULTS["boundary-transcripts"] else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": item_names},
        rows=rows,
        evidence={**SURFACE_EVIDENCE, **item_evidence, **check_evidence},
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"chain-spec": "cabal test", "boundary-spec": "cabal test", "astcheck-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red"} for row in mutant_rows] or [{"name": "phase-14 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status={"generated-artifact-discipline": results["results"]},
    )


if __name__ == "__main__":
    raise SystemExit(main())
