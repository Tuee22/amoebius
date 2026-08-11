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


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain/pins.json"
MUTANTS = ROOT / "tests/mutants/phase14/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase14/validation_locus.tsv"
AST_ORACLE = ROOT / "test/fixtures/phase14/astcheck/astcheck_negatives.expected"
LEDGER = ROOT / "test/golden/phase_14_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_14_surfaces.txt"
RESULTS = ROOT / "gen/dsl/phase14/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase14/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_14"


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
    pins = json.loads(PINS.read_text(encoding="utf-8"))
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
    # Phase 24 tightened the original boundary behind the opaque AbsExe tool
    # ensure. Exec.Tool remains the Phase-14 compatibility facade; only the
    # Host.Ensure implementation is permitted to reach the process primitive.
    expected = [ROOT / "src/Amoebius/Host/Ensure.hs"]
    if primitive_hits != expected:
        raise GateFailure("subprocess primitive sites drifted: " + ", ".join(str(path.relative_to(ROOT)) for path in primitive_hits))


def compile_link_seal(cabal: Path) -> str:
    legal = run([str(cabal), "exec", "--offline", "ghc", "--", "-fno-code", "-XGHC2024", "-XOverloadedStrings", "-isrc", "test/fixtures/phase14/compilefail/checked_ctor_legal.hs"])
    illegal = run(
        [str(cabal), "exec", "--offline", "ghc", "--", "-fno-code", "-XGHC2024", "-XOverloadedStrings", "-isrc", "test/fixtures/phase14/compilefail/checked_ctor_illegal.hs"],
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


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    proven = {"pure-chain-builder", "canonical-render-chain-plan", "single-subprocess-seam", "absolute-tool-path-seal", "no-raw-io-effect-arm", "opaque-checked-extension-source", "phase14-compile-totality"}
    unverified = {"live-tool-fidelity", "live-apiserver-apply", "runtime-model-correspondence"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 14,
        "gate_command": "python3 tools/phase14_gate.py",
        "register": "1/2",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def verify_ledger() -> str:
    derived = derive_ledger()
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-14 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(suites: str, mutants: str, compile_log: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(suites, encoding="utf-8")
    (EVIDENCE / "mutants.log").write_text(mutants, encoding="utf-8")
    (EVIDENCE / "compile-fail.log").write_text(compile_log, encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(versions, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    shutil.copyfile(GENERATED_LEDGER, EVIDENCE / "validation-locus-ledger.tsv")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--derive-ledger", action="store_true")
    args = parser.parse_args(argv)
    if args.derive_ledger:
        print(json.dumps(derive_ledger(), indent=2))
        return 0
    try:
        cabal, dhall, versions = verify_pins()
        mutants = verify_oracles(dhall)
        verify_source_boundaries()
        compile_log = compile_link_seal(cabal)
        suites, observer = run_green_suites(cabal)
        mutant_log = verify_mutants(cabal, mutants)
        write_results(mutants, observer)
        ledger_hash = verify_ledger()
        retain_evidence(suites, mutant_log, compile_log, versions)
        print(suites, end="", flush=True)
        print(f"phase14-network-observer: {observer}")
        print(f"phase14-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase14-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
