#!/usr/bin/env python3
"""Run and seal the Phase-18 pure UI-authorization checks."""

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
FIXTURES = ROOT / "test/fixtures/ui_authorization"
MUTANTS = ROOT / "tests/mutants/phase18/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase18/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_18_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_18_ledger.json"
RESULTS = ROOT / "gen/dsl/phase18/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase18/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_18"


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
    registry = read_tsv(FIXTURES / "action_registry.tsv")
    matrix = read_tsv(FIXTURES / "authorization_matrix.tsv")
    errors = read_tsv(FIXTURES / "decode_errors.tsv")
    stale = read_tsv(FIXTURES / "stale_decision_cases.tsv")
    expected_effects = ["ReadData", "MutateData", "StartWorkflow", "ObserveWorkflow", "EndSession"]
    if len(registry) != 5 or [row["effect"] for row in registry] != expected_effects:
        raise GateFailure("action registry must pin the five closed effect arms in order")
    if [row["decision"] for row in matrix] != ["allow", "allow", "deny", "deny", "deny", "deny"]:
        raise GateFailure("authorization matrix decisions drifted")
    hidden = next((row for row in matrix if row["case"] == "hidden-invocable"), None)
    default = next((row for row in matrix if row["case"] == "default-deny"), None)
    if hidden is None or hidden["visible"] != "false" or hidden["decision"] != "allow":
        raise GateFailure("hidden-but-invocable canary drifted")
    if default is None or default["policy"] != "absent" or default["decision"] != "deny":
        raise GateFailure("default-deny canary drifted")
    if [row["error"] for row in errors] != [
        "MissingAction", "UnexpectedAction", "DuplicateAction", "ProjectionMismatch",
    ]:
        raise GateFailure("registry parity errors drifted")
    if [row["expected"] for row in stale] != [
        "StalePolicyEpoch", "StaleMembershipEpoch", "StaleGrantEpoch", "StaleScopeEpoch",
    ]:
        raise GateFailure("authority epoch errors drifted")
    if len(read_tsv(MUTANTS)) != 2:
        raise GateFailure("Phase-18 mutant manifest must contain exactly two rows")
    locus = read_tsv(LOCUS)
    if len(locus) != 30 or len({row["entry"] for row in locus}) != 30:
        raise GateFailure("Phase-18 validation locus must contain thirty unique rows")
    phase0_rows = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "18"]) != 6:
        raise GateFailure("Phase-0 manifest must pin six Phase-18 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; identity/provider/runtime enforcement UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )


def verify_source_boundaries() -> None:
    path = ROOT / "src/Amoebius/Ui/Security/Authorization.hs"
    source = path.read_text(encoding="utf-8")
    header = source.split(") where", 1)[0]
    for type_name in (
        "ActionId", "BoundActionRegistry", "AuthorityEpochs", "AuthoritySnapshot",
        "AuthorizedAction", "CanRead", "CanInvoke",
    ):
        if f"{type_name} (.." in header:
            raise GateFailure(f"private constructor exported: {type_name}")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
    match = prohibited.search(stripped)
    if match:
        raise GateFailure(f"partial/unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")
    authorize_body = source.split("authorize (BoundActionRegistry", 1)[1].split("\ncanRead ::", 1)[0]
    if "specVisibility" in authorize_body or "Visible" in authorize_body or "Hidden" in authorize_body:
        raise GateFailure("client visibility entered the production authorization transition")
    if "interpretAuthorized :: AuthorizedAction -> [EffectEvent]" not in source:
        raise GateFailure("effect interpreter no longer requires AuthorizedAction")
    reference = (ROOT / "test/ui/AuthorizationReference.hs").read_text(encoding="utf-8")
    if "Amoebius.Ui.Security.Authorization" in reference:
        raise GateFailure("independent evaluator imports the production authorization module")


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-authorization-spec", "--offline"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-authorization-spec", "--offline"]).stdout.strip())
    with tempfile.TemporaryDirectory(prefix="amoebius-phase18-") as directory:
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
                raise GateFailure("authorization gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-authorization-spec", "--offline", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = "ui-authorization-spec: PASS (5 actions, 6 matrix rows, 4 parity errors, 4 stale epochs, 9 coverage classes, 2 mutants)"
    if token not in suite.stdout or token not in isolated:
        raise GateFailure("Phase-18 acceptance token is absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path) -> str:
    tokens = {
        "default_allow": "phase18-auth-mutant: RED default_allow default-deny",
        "visibility_is_authorization": "phase18-auth-mutant: RED visibility_is_authorization hidden-invocable+stale",
    }
    logs: list[str] = []
    for mutant, token in tokens.items():
        result = run(
            [
                str(cabal), "test", "ui-authorization-spec", "--offline", "--test-show-details=direct",
                f"--test-options=--mutant={mutant}",
            ],
            require_success=False,
        )
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"authorization mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "action-registry": "5/5-exact",
        "projection-parity": "client=server=independent-pin",
        "authorization-matrix": "6/6-independent-agreement",
        "registry-errors": "4/4-exact",
        "stale-epochs": "4/4-exact-empty-trace",
        "generated-coverage": "9/9-classes-at-5-percent",
        "mutants": "2/2-red",
        "network-observer": observer,
        "identity-provider-truth": "UNVERIFIED",
        "runtime-policy-enforcement": "UNVERIFIED",
        "provider-isolation": "UNVERIFIED",
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
        "opaque-action-id", "closed-action-effect", "closed-permission", "opaque-bound-action-registry",
        "opaque-authority-epochs", "opaque-authority-snapshot", "opaque-authorized-action",
        "opaque-can-read", "opaque-can-invoke", "effect-after-authorization-only",
    }
    unverified = {"identity-provider-truth", "runtime-policy-enforcement", "provider-isolation"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in model_proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 18,
        "gate_command": "python3 tools/phase18_gate.py",
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
        raise GateFailure("committed Phase-18 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
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
        print(f"phase18-network-observer: {observer}")
        print(f"phase18-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase18-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
