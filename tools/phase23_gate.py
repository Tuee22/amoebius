#!/usr/bin/env python3
"""Run and seal the Phase-23 local browser/server/domain composition checks."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
CABAL = Path("/home/matthewnowak/.ghcup/bin/cabal-3.16.1.0")
FIXTURES = ROOT / "test/fixtures/ui_local_composition"
MUTANTS = ROOT / "tests/mutants/phase23/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase23/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_23_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_23_ledger.json"
RESULTS = ROOT / "gen/dsl/phase23/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase23/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_23"


class GateFailure(RuntimeError):
    pass


def environment(extra: dict[str, str] | None = None) -> dict[str, str]:
    value = dict(os.environ)
    value["PATH"] = f"{ROOT / 'node_modules/.bin'}:/usr/bin:/bin"
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    if extra:
        value.update(extra)
    return value


def run(
    command: list[str], *, require_success: bool = True, extra_env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=environment(extra_env), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_oracles() -> None:
    expected = {
        "interactions.tsv": 5,
        "expected_visible_states.tsv": 4,
        "expected_effect_sequence.tsv": 4,
        "access_matrix.tsv": 3,
        "expected_denials.tsv": 5,
    }
    for name, count in expected.items():
        actual = len(read_tsv(FIXTURES / name))
        if actual != count:
            raise GateFailure(f"{name} must retain {count} rows, got {actual}")
    for name in ("single_tenant_workflow.dhall", "multi_tenant_workflow.dhall"):
        if not (FIXTURES / name).is_file():
            raise GateFailure(f"authored application source is absent: {name}")
    mutants = read_tsv(MUTANTS)
    if len(mutants) != 5 or len({row["mutant"] for row in mutants}) != 5:
        raise GateFailure("Phase-23 mutant manifest must contain five unique rows")
    for row in mutants:
        fixture = ROOT / row["fixture"]
        if not fixture.is_file() or "operator=" not in fixture.read_text(encoding="utf-8"):
            raise GateFailure(f"mutant fixture is absent or malformed: {fixture}")
    locus = read_tsv(LOCUS)
    if len(locus) != 42 or len({row["entry"] for row in locus}) != 42:
        raise GateFailure("Phase-23 validation locus must contain forty-two unique rows")
    phase0_rows = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "23"]) != 12:
        raise GateFailure("Phase-0 manifest must pin twelve Phase-23 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 with local Chrome/server/domain fakes; live layers UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )


def verify_source_boundaries() -> None:
    interpreter = (ROOT / "ui-runtime/src/Amoebius/Ui/Interpreter.purs").read_text(encoding="utf-8")
    browser = (ROOT / "ui-runtime/src/Main.js").read_text(encoding="utf-8")
    server = (ROOT / "src/Amoebius/Ui/Server/Main.hs").read_text(encoding="utf-8")
    dispatch = (ROOT / "src/Amoebius/Ui/Server/Dispatch.hs").read_text(encoding="utf-8")
    harness = (ROOT / "test/ui/local/phase23_local_composition.mjs").read_text(encoding="utf-8")
    for event in ("start", "observe", "use-artifact"):
        if f'"{event}"' not in interpreter or event not in browser:
            raise GateFailure(f"generic workflow event disappeared: {event}")
    for token in ("readyHandles", "validateReadyHandle", '"workflow-start"', '"workflow-observe"', '"artifact-use"'):
        if token not in server + dispatch:
            raise GateFailure(f"server composition boundary disappeared: {token}")
    for forbidden in ("localStorage", "sessionStorage", "indexedDB", "provider.invalid", "innerHTML"):
        if forbidden in browser:
            raise GateFailure(f"generic browser escape appeared: {forbidden}")
    for token in ("playwright-core", "infernix-shaped", "jitML-shaped", "rawDomainBypass"):
        if token not in harness:
            raise GateFailure(f"composition observer/fake disappeared: {token}")


def build_binaries() -> tuple[Path, Path, str]:
    build = run([str(CABAL), "build", "exe:amoebius", "test:ui-local-composition-spec", "--offline"])
    executable = Path(run([str(CABAL), "list-bin", "exe:amoebius", "--offline"]).stdout.strip())
    suite = Path(run([str(CABAL), "list-bin", "test:ui-local-composition-spec", "--offline"]).stdout.strip())
    if not executable.is_file() or not suite.is_file():
        raise GateFailure("Phase-23 executable or suite binary is absent")
    return executable, suite, build.stdout


def run_green(executable: Path) -> str:
    result = run(
        [str(CABAL), "test", "ui-local-composition-spec", "--offline", "--test-show-details=direct"],
        extra_env={"AMOEBIUS_BIN": str(executable)},
    )
    token = "ui-local-composition-spec: PASS (2 apps, 5 interactions, 4 visible pins, 4 effect rows, 3 access rows, 5 denials, 5 mutants)"
    if token not in result.stdout:
        raise GateFailure("Phase-23 acceptance token is absent")
    return result.stdout


def observed_binary(executable: Path, suite: Path) -> tuple[str, str]:
    if shutil.which("strace") is None:
        raise GateFailure("strace is required for the composition OS-network observer")
    with tempfile.TemporaryDirectory(prefix="amoebius-phase23-") as directory:
        trace = Path(directory) / "network.trace"
        result = run([
            "strace", "-f", "-qq", "-e", "trace=connect,sendto",
            "-e", "status=successful,failed", "-e", "signal=none",
            "-o", str(trace), str(suite),
        ], extra_env={"AMOEBIUS_BIN": str(executable)})
        forbidden = []
        loopback = []
        hard_failed = []
        for line in trace.read_text(encoding="utf-8").splitlines():
            if "AF_INET" not in line and "AF_INET6" not in line:
                continue
            if any(allowed in line for allowed in (
                'inet_addr("127.', 'inet_pton(AF_INET6, "::1"', "sin_addr=htonl(INADDR_LOOPBACK)",
            )):
                loopback.append(line)
                continue
            if " = -1 ENETUNREACH " in line:
                hard_failed.append(line)
                continue
            forbidden.append(line)
        if forbidden:
            raise GateFailure("local composition used a non-loopback network address:\n" + "\n".join(forbidden[:30]))
        if len(loopback) < 10:
            raise GateFailure("OS observer did not see browser/server/domain composition traffic")
    if "ui-local-composition-spec: PASS" not in result.stdout:
        raise GateFailure("observed Phase-23 binary missed its acceptance token")
    observer = f"strace-established-loopback-only;syscalls={len(loopback)};nonloopback-enetunreach={len(hard_failed)}"
    return result.stdout, observer


def run_mutants(executable: Path, suite: Path) -> str:
    logs: list[str] = []
    for row in read_tsv(MUTANTS):
        mutant = row["mutant"]
        result = run(
            [str(suite), f"--mutant={mutant}"], require_success=False,
            extra_env={"AMOEBIUS_BIN": str(executable)},
        )
        token = f"phase23-composition-mutant: RED {mutant} {row['locus']}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"composition mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "applications": "2/2-dhall-typed",
        "interactions": "5/5-generated-authored-joined",
        "visible": "4/4-exact-fresh",
        "effects": "4/4-exact-ordered",
        "access": "3/3-own-foreign",
        "denials": "5/5-zero-leak",
        "bundle": "one-generic-sha256",
        "fresh-challenge": "browser-server-workflow-artifact-dom",
        "mutants": "5/5-red",
        "network-observer": observer,
        "live-infernix-adapter": "UNVERIFIED",
        "live-jitml-adapter": "UNVERIFIED",
        "live-keycloak-edge": "UNVERIFIED",
        "live-provider-storage-isolation": "UNVERIFIED",
        "release-rollout": "UNVERIFIED",
        "replica-loss": "UNVERIFIED",
        "ha-behavior": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    unverified = {
        "live-infernix-adapter", "live-jitml-adapter", "live-keycloak-edge",
        "live-provider-storage-isolation", "release-rollout", "replica-loss", "ha-behavior",
    }
    coverage = [
        {"surface": surface, "status": "UNVERIFIED" if surface in unverified else "tested"}
        for surface in ENUMERATION.read_text(encoding="utf-8").splitlines()
    ]
    ledger = {
        "phase": 23,
        "gate_command": "python3 tools/phase23_gate.py",
        "register": "2",
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
        raise GateFailure("committed Phase-23 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, observed: str, mutants: str, build: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
    (EVIDENCE / "composition-observed.log").write_text(observed, encoding="utf-8")
    (EVIDENCE / "mutant.log").write_text(mutants, encoding="utf-8")
    (EVIDENCE / "build.log").write_text(build, encoding="utf-8")
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
        verify_oracles()
        verify_source_boundaries()
        executable, suite, build = build_binaries()
        green = run_green(executable)
        observed, observer = observed_binary(executable, suite)
        mutants = run_mutants(executable, suite)
        write_results(observer)
        ledger_hash = verify_ledger()
        retain_evidence(green, observed, mutants, build)
        print(green, end="", flush=True)
        print(f"phase23-network-observer: {observer}")
        print(f"phase23-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase23-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
