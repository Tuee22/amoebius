#!/usr/bin/env python3
"""Run and seal the Phase-20 deterministic paired-plan compiler checks."""

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
FIXTURES = ROOT / "test/fixtures/ui_plan_compiler"
MUTANTS = ROOT / "tests/mutants/phase20/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase20/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_20_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_20_ledger.json"
RESULTS = ROOT / "gen/dsl/phase20/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase20/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_20"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = dict(os.environ)
    value["AMOEBIUS_UI_PLAN_CACHE"] = "disabled"
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
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
    projections = read_tsv(FIXTURES / "projection_rows.tsv")
    digests = read_tsv(FIXTURES / "expected_digests.tsv")
    if len(projections) != 4 or sum(row["server"] != "-" for row in projections) != 2:
        raise GateFailure("projection oracle must contain four rows and two server actions")
    if len(digests) != 4 or any(re.fullmatch(r"sha256:[0-9a-f]{64}", row["canonical_digest"]) is None for row in digests):
        raise GateFailure("digest oracle must contain four concrete canonical SHA-256 values")
    for name in (
        "client_plan.golden.json", "ui_server_plan.golden.json",
        "public_contracts.golden.json", "content_manifest.golden.json",
    ):
        payload = (FIXTURES / name).read_text(encoding="utf-8").strip()
        if json.dumps(json.loads(payload), sort_keys=True, separators=(",", ":")) != payload:
            raise GateFailure(f"noncanonical JSON golden: {name}")
    if len(read_tsv(MUTANTS)) != 6:
        raise GateFailure("Phase-20 mutant manifest must contain six rows")
    locus = read_tsv(LOCUS)
    if len(locus) != 35 or len({row["entry"] for row in locus}) != 35:
        raise GateFailure("Phase-20 validation locus must contain thirty-five unique rows")
    phase0_rows = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "20"]) != 12:
        raise GateFailure("Phase-0 manifest must pin twelve Phase-20 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; interpreters/release/edge runtime UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )


def verify_source_boundaries() -> None:
    paths = sorted((ROOT / "src/Amoebius/Ui/Compile").glob("*.hs"))
    if {path.name for path in paths} != {"ClientPlan.hs", "ServerPlan.hs", "Manifest.hs", "Demand.hs"}:
        raise GateFailure("paired compiler module inventory drifted")
    sources = {path: path.read_text(encoding="utf-8") for path in paths}
    headers = {path: source.split(") where", 1)[0] for path, source in sources.items()}
    for type_name, filename in (
        ("ClientPlan", "ClientPlan.hs"), ("UiServerPlan", "ServerPlan.hs"), ("CompiledUiPlans", "Manifest.hs"),
    ):
        header = next(value for path, value in headers.items() if path.name == filename)
        if f"{type_name} (.." in header:
            raise GateFailure(f"private compiler constructor exported: {type_name}")
    manifest = sources[ROOT / "src/Amoebius/Ui/Compile/Manifest.hs"]
    if "compileUiPlans :: BoundUiProgram -> Either UiPlanError CompiledUiPlans" not in manifest:
        raise GateFailure("compiler no longer accepts only the Phase-19 sealed value")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path, source in sources.items():
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
        match = prohibited.search(stripped)
        if match:
            raise GateFailure(f"partial/unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")
    reference = (ROOT / "test/ui/PlanCompilerReference.hs").read_text(encoding="utf-8")
    if "Amoebius.Ui.Compile" in reference or "Amoebius.Ui.Bind" in reference:
        raise GateFailure("independent plan oracle imports production projection/digest code")


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-plan-compiler-spec", "--offline"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-plan-compiler-spec", "--offline"]).stdout.strip())
    with tempfile.TemporaryDirectory(prefix="amoebius-phase20-") as directory:
        trace = Path(directory) / "network.trace"
        probe = run(["unshare", "-n", "true"], require_success=False)
        if probe.returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("neither network namespace isolation nor strace socket injection is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "signal=none", "-e", "inject=socket:error=EPERM",
                "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("plan-compiler gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-plan-compiler-spec", "--offline", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = "ui-plan-compiler-spec: PASS (4 projections, 4 canonical artifacts, 4 digests, 6 demand cells, 2 fresh processes, 6 mutants)"
    if token not in suite.stdout or token not in isolated:
        raise GateFailure("Phase-20 acceptance token is absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path) -> str:
    logs: list[str] = []
    for row in read_tsv(MUTANTS):
        mutant = row["mutant"]
        locus = {
            "M-drop-server-action": "workflow.start",
            "M-swap-action-targets": "handler-projection",
            "M-emit-private-field": "public-allowlist",
            "M-client-only-authority-digest": "authority-digest",
            "M-link-navigation-as-fetch": "docs.link",
            "M-preserve-map-insertion-order": "fresh-process-bytes",
        }[mutant]
        result = run([
            str(cabal), "test", "ui-plan-compiler-spec", "--offline", "--test-show-details=direct",
            f"--test-options=--mutant={mutant}",
        ], require_success=False)
        token = f"phase20-plan-mutant: RED {mutant} {locus}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"plan compiler mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "logical-projections": "4/4-independent-exact",
        "canonical-artifacts": "4/4-byte-exact",
        "canonical-digests": "4/4-concrete-independent",
        "runtime-demand": "6/6-finite-exact",
        "fresh-process-determinism": "2/2-byte-identical",
        "mutants": "6/6-red",
        "network-observer": observer,
        "browser-interpreter-fidelity": "UNVERIFIED",
        "server-interpreter-fidelity": "UNVERIFIED",
        "release-publication": "UNVERIFIED",
        "edge-runtime-enforcement": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    model_proven = {
        "opaque-client-plan", "opaque-ui-server-plan", "opaque-compiled-plan-pair",
        "bound-program-only-compiler-input", "inseparable-client-server-compilation",
    }
    unverified = {"browser-interpreter-fidelity", "server-interpreter-fidelity", "release-publication", "edge-runtime-enforcement"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in model_proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 20,
        "gate_command": "python3 tools/phase20_gate.py",
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
        raise GateFailure("committed Phase-20 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, mutants: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
    (EVIDENCE / "mutant.log").write_text(mutants, encoding="utf-8")
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
        green, observer = run_green(cabal)
        mutants = run_mutants(cabal)
        write_results(observer)
        ledger_hash = verify_ledger()
        retain_evidence(green, mutants, versions)
        print(green, end="", flush=True)
        print(f"phase20-network-observer: {observer}")
        print(f"phase20-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase20-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
