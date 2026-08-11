#!/usr/bin/env python3
"""Run and seal the Phase-17 scoped-identity and flow-kernel checks."""

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
FIXTURES = ROOT / "test/fixtures/ui_scope"
MUTANTS = ROOT / "tests/mutants/phase17/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase17/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_17_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_17_ledger.json"
RESULTS = ROOT / "gen/dsl/phase17/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase17/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_17"


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


def verify_pins() -> tuple[Path, str]:
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    for executable in (cabal, ghc):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = run([str(cabal), "--numeric-version"]).stdout + run([str(ghc), "--numeric-version"]).stdout
    if pins["cabal"]["version"] not in versions or pins["ghc"]["version"] not in versions:
        raise GateFailure(f"toolchain version drifted:\n{versions}")
    return cabal, versions


def verify_oracles() -> None:
    owner = read_tsv(FIXTURES / "owner_join_table.tsv")
    swaps = read_tsv(FIXTURES / "owner_tenant_swaps.tsv")
    flows = read_tsv(FIXTURES / "flow_matrix.tsv")
    errors = read_tsv(FIXTURES / "decode_errors.tsv")
    if len(owner) != 6 or sum(row["decision"] == "allow" for row in owner) != 3:
        raise GateFailure("owner join oracle must contain three allows and three denies")
    if [row["expected_error"] for row in swaps] != ["OwnerMismatch", "TenantMismatch"]:
        raise GateFailure("owner swap error oracle drifted")
    if len(flows) != 4 or [row["decision"] for row in flows] != ["allow", "deny", "deny", "deny"]:
        raise GateFailure("flow oracle decisions drifted")
    if {row["error"] for row in errors} != {
        "UntrustedResourceId", "ScopeRetagForbidden", "DeclassificationForbidden",
    }:
        raise GateFailure("compile-fail error oracle drifted")
    if len(read_tsv(MUTANTS)) != 1:
        raise GateFailure("Phase-17 mutant manifest must contain exactly one row")
    locus = read_tsv(LOCUS)
    if len(locus) != 23 or len({row["entry"] for row in locus}) != 23:
        raise GateFailure("Phase-17 validation locus must contain twenty-three unique rows")
    phase0_rows = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "17"]) != 8:
        raise GateFailure("Phase-0 manifest must pin eight Phase-17 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; identity-provider/provider/runtime enforcement UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )


def verify_source_boundaries() -> None:
    scope = (ROOT / "src/Amoebius/Ui/Security/Scope.hs").read_text(encoding="utf-8")
    flow = (ROOT / "src/Amoebius/Ui/Security/Flow.hs").read_text(encoding="utf-8")
    scope_header = scope.split(") where", 1)[0]
    flow_header = flow.split(") where", 1)[0]
    for type_name, header in (
        ("Tenant", scope_header), ("Subject", scope_header), ("RequestContext", scope_header),
        ("ResourceId", scope_header), ("ScopedHandle", scope_header), ("FlowLabel", flow_header),
        ("CanFlowTo", flow_header),
    ):
        if f"{type_name} (.." in header:
            raise GateFailure(f"private constructor exported: {type_name}")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path in (ROOT / "src/Amoebius/Ui/Security").glob("*.hs"):
        source = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", path.read_text(encoding="utf-8")))
        match = prohibited.search(source)
        if match:
            raise GateFailure(f"partial/unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")
    for forbidden in ("retagHandle", "declassify"):
        if forbidden in scope_header + flow_header:
            raise GateFailure(f"general authority escape is exported: {forbidden}")


def compile_failures(cabal: Path) -> str:
    expected = {
        "raw_resource_id.hs.fail": "Illegal term-level use of the type constructor ‘ResourceId’",
        "scope_retag.hs.fail": "Variable not in scope:",
        "declassify.hs.fail": "Variable not in scope: declassify",
    }
    logs = []
    common = [str(cabal), "exec", "--offline", "ghc", "--", "-fno-code", "-XGHC2024", "-XOverloadedStrings", "-isrc", "-x", "hs"]
    for name, token in expected.items():
        result = run(common + [str(FIXTURES / "compile_fail" / name)], require_success=False)
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"compile-fail locus drifted: {name}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-scope-spec", "--offline"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-scope-spec", "--offline"]).stdout.strip())
    with tempfile.TemporaryDirectory(prefix="amoebius-phase17-") as directory:
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
                raise GateFailure("scope gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-scope-spec", "--offline", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = "ui-scope-spec: PASS (6 owner rows, 2 swap errors, 4 flow rows, 3 compile loci, 6 coverage classes, 1 mutant)"
    if token not in suite.stdout or token not in isolated:
        raise GateFailure("Phase-17 acceptance token is absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutant(cabal: Path) -> str:
    result = run(
        [
            str(cabal), "test", "ui-scope-spec", "--offline", "--test-show-details=direct",
            "--test-options=--mutant=drop_owner_equality",
        ],
        require_success=False,
    )
    token = "phase17-scope-mutant: RED drop_owner_equality same-tenant+cross-tenant"
    if result.returncode == 0 or token not in result.stdout:
        raise GateFailure(f"owner-equality mutant survived or missed its red locus:\n{result.stdout}")
    return result.stdout


def write_results(observer: str) -> None:
    metrics = {
        "owner-joins": "6/6-exact",
        "owner-swaps": "2/2-exact-errors",
        "flow-matrix": "4/4-independent-agreement",
        "compile-fail": "3/3-constructor-closure",
        "generated-coverage": "6/6-classes-at-5-percent",
        "mutants": "1/1-red-on-2-swaps",
        "network-observer": observer,
        "identity-provider-truth": "UNVERIFIED",
        "provider-row-policy": "UNVERIFIED",
        "live-noninterference": "UNVERIFIED",
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
        "opaque-tenant-identity", "opaque-subject-identity", "opaque-membership", "opaque-request-context",
        "opaque-resource-id", "scope-indexed-handle", "opaque-scope-witness", "opaque-flow-label",
        "opaque-can-flow-to-witness", "total-flow-path-check",
    }
    unverified = {"identity-provider-truth", "provider-row-policy", "live-noninterference"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in model_proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 17,
        "gate_command": "python3 tools/phase17_gate.py",
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
        raise GateFailure("committed Phase-17 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, mutant: str, compile_log: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
    (EVIDENCE / "mutant.log").write_text(mutant, encoding="utf-8")
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
        cabal, versions = verify_pins()
        verify_oracles()
        verify_source_boundaries()
        compile_log = compile_failures(cabal)
        green, observer = run_green(cabal)
        mutant = run_mutant(cabal)
        write_results(observer)
        ledger_hash = verify_ledger()
        retain_evidence(green, mutant, compile_log, versions)
        print(green, end="", flush=True)
        print(f"phase17-network-observer: {observer}")
        print(f"phase17-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase17-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
