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


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain/pins.json"
CASES = ROOT / "test/fixtures/ui_program_schema/cases.tsv"
GRAPH = ROOT / "test/fixtures/ui_program_schema/graph_reference.tsv"
WIRE = ROOT / "test/fixtures/ui_program_schema/normalized_wire.golden"
MUTANTS = ROOT / "tests/mutants/phase16/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase16/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_16_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_16_ledger.json"
RESULTS = ROOT / "gen/dsl/phase16/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase16/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_16"


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
    pins = json.loads(PINS.read_text(encoding="utf-8"))
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
    phase0 = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
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


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    model_proven = {
        "closed-tenant-mode-union", "closed-node-kind-union", "closed-value-type-union",
        "no-raw-browser-source-arm", "opaque-checked-ui-program", "deterministic-module-merge",
    }
    unverified = {
        "browser-runtime-enforcement", "authorization-enforcement", "provider-tenant-isolation",
        "runtime-noninterference",
    }
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in model_proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 16,
        "gate_command": "python3 tools/phase16_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "proven-for-the-model"},
            {"name": "Protocol", "status": "UNVERIFIED"},
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
        raise GateFailure("committed Phase-16 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, mutants: str, compile_log: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
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
        compile_log = compile_seal(cabal)
        green, observer = run_green(cabal)
        mutant_log = run_mutants(cabal, mutants)
        write_results(observer)
        ledger_hash = verify_ledger()
        retain_evidence(green, mutant_log, compile_log, versions)
        print(green, end="", flush=True)
        print(f"phase16-network-observer: {observer}")
        print(f"phase16-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase16-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
