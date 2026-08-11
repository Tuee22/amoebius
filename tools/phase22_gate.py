#!/usr/bin/env python3
"""Run and seal the Phase-22 authenticated UI-server boundary checks."""

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
FIXTURES = ROOT / "test/fixtures/ui_server"
MUTANTS = ROOT / "tests/mutants/phase22/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase22/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_22_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_22_ledger.json"
RESULTS = ROOT / "gen/dsl/phase22/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase22/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_22"


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
    expected_counts = {
        "requests.tsv": 7,
        "access_matrix.tsv": 5,
        "expected_http.tsv": 7,
        "expected_effects.tsv": 5,
        "expected_audit.tsv": 5,
        "startup_plan_matrix.tsv": 5,
        "public_asset_allowlist.tsv": 5,
        "forbidden_server_manifest_paths.tsv": 4,
        "websocket_registration.tsv": 7,
        "idempotency.tsv": 1,
    }
    for name, expected in expected_counts.items():
        actual = len(read_tsv(FIXTURES / name))
        if actual != expected:
            raise GateFailure(f"{name} must retain {expected} rows, got {actual}")
    headers = read_tsv(ROOT / "test/fixtures/ui_security/production_headers.tsv")
    if len(headers) != 5 or {row["header"] for row in headers} != {
        "Content-Security-Policy", "Cross-Origin-Opener-Policy", "Cross-Origin-Resource-Policy",
        "Referrer-Policy", "X-Content-Type-Options",
    }:
        raise GateFailure("production security-header contract drifted")
    mutants = read_tsv(MUTANTS)
    if len(mutants) != 9 or len({row["mutant"] for row in mutants}) != 9:
        raise GateFailure("Phase-22 mutant manifest must contain nine unique rows")
    for row in mutants:
        fixture = ROOT / row["fixture"]
        if not fixture.is_file() or "operator=" not in fixture.read_text(encoding="utf-8"):
            raise GateFailure(f"mutant fixture is absent or malformed: {fixture}")
    locus = read_tsv(LOCUS)
    if len(locus) != 54 or len({row["entry"] for row in locus}) != 54:
        raise GateFailure("Phase-22 validation locus must contain fifty-four unique rows")
    phase0_rows = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "22"]) != 19:
        raise GateFailure("Phase-0 manifest must pin nineteen Phase-22 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 with local signed authority/handler fakes; live layers UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )


def verify_source_boundaries() -> None:
    request_context = (ROOT / "src/Amoebius/Ui/Server/RequestContext.hs").read_text(encoding="utf-8")
    dispatch = (ROOT / "src/Amoebius/Ui/Server/Dispatch.hs").read_text(encoding="utf-8")
    server = (ROOT / "src/Amoebius/Ui/Server/Main.hs").read_text(encoding="utf-8")
    headers = (ROOT / "src/Amoebius/Ui/Server/SecurityHeaders.hs").read_text(encoding="utf-8")
    websocket = (ROOT / "src/Amoebius/Ui/Server/WebSocket.hs").read_text(encoding="utf-8")
    app = (ROOT / "app/Main.hs").read_text(encoding="utf-8")
    if "VerifiedCredential (" in request_context.split("where", 1)[0]:
        raise GateFailure("VerifiedCredential constructor became public")
    for token in ("SHA256.hmac", "verifyCredential", "serverRequestContext"):
        if token not in request_context:
            raise GateFailure(f"signed credential boundary disappeared: {token}")
    for token in ("admitServerPlan", "authorizeAndDispatch", "DispatchBeforeAuthorize", "NewIdempotencyKeyOnRetry"):
        if token not in dispatch:
            raise GateFailure(f"dispatch boundary or mutant control disappeared: {token}")
    for token in ("dispatchOnce", "sendHandlerInvocation", "serveWebSocket", "pathOnly"):
        if token not in server:
            raise GateFailure(f"server boundary disappeared: {token}")
    if len([line for line in headers.splitlines() if line.strip().startswith(", (")]) != 4:
        raise GateFailure("fixed five-header production set drifted")
    if "validateRegistration" not in websocket or "registrationCoordinatorAvailable" not in websocket:
        raise GateFailure("WebSocket admission/coordinator boundary disappeared")
    if '"serve-ui" : options -> runServeUi options' not in app:
        raise GateFailure("serve-ui is no longer an amoebius executable responsibility")
    for forbidden in ("provider.invalid", "redis://", "pulsar://", "X-Subject"):
        if forbidden in server:
            raise GateFailure(f"forbidden server authority/provider token: {forbidden}")


def build_binaries() -> tuple[Path, Path, str]:
    build = run([str(CABAL), "build", "exe:amoebius", "test:ui-server-boundary-spec", "--offline"])
    executable = Path(run([str(CABAL), "list-bin", "exe:amoebius", "--offline"]).stdout.strip())
    suite = Path(run([str(CABAL), "list-bin", "test:ui-server-boundary-spec", "--offline"]).stdout.strip())
    if not executable.is_file() or not suite.is_file():
        raise GateFailure("Phase-22 executable or suite binary is absent")
    return executable, suite, build.stdout


def run_green(executable: Path) -> str:
    result = run(
        [str(CABAL), "test", "ui-server-boundary-spec", "--offline", "--test-show-details=direct"],
        extra_env={"AMOEBIUS_BIN": str(executable)},
    )
    token = "ui-server-boundary-spec: PASS (7 HTTP rows, 5 access rows, 5 audits, 5 effects, 5 startup rows, 5 public assets, 5 private probes, 7 WebSocket rows, 9 mutants)"
    if token not in result.stdout:
        raise GateFailure("Phase-22 acceptance token is absent")
    return result.stdout


def observed_binary(executable: Path, suite: Path) -> tuple[str, str]:
    if shutil.which("strace") is None:
        raise GateFailure("strace is required for the UI-server OS-network observer")
    with tempfile.TemporaryDirectory(prefix="amoebius-phase22-") as directory:
        trace = Path(directory) / "network.trace"
        result = run([
            "strace", "-f", "-qq", "-e", "trace=connect,sendto",
            "-e", "status=successful,failed", "-e", "signal=none",
            "-o", str(trace), str(suite),
        ], extra_env={"AMOEBIUS_BIN": str(executable)})
        trace_text = trace.read_text(encoding="utf-8")
        forbidden = []
        loopback = []
        for line in trace_text.splitlines():
            if "AF_INET" not in line and "AF_INET6" not in line:
                continue
            if any(allowed in line for allowed in (
                'inet_addr("127.', 'inet_pton(AF_INET6, "::1"', "sin_addr=htonl(INADDR_LOOPBACK)",
            )):
                loopback.append(line)
                continue
            forbidden.append(line)
        if forbidden:
            raise GateFailure("UI-server boundary used a non-loopback network address:\n" + "\n".join(forbidden[:30]))
        if len(loopback) < 3:
            raise GateFailure("OS observer did not see server/authority/handler boundary traffic")
    if "ui-server-boundary-spec: PASS" not in result.stdout:
        raise GateFailure("observed Phase-22 binary missed its acceptance token")
    return result.stdout, f"strace-connect-sendto-loopback-only;syscalls={len(loopback)}"


def run_mutants(executable: Path, suite: Path) -> str:
    logs: list[str] = []
    for row in read_tsv(MUTANTS):
        mutant = row["mutant"]
        result = run(
            [str(suite), f"--mutant={mutant}"], require_success=False,
            extra_env={"AMOEBIUS_BIN": str(executable)},
        )
        token = f"phase22-server-mutant: RED {mutant} {row['locus']}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"server mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "http": "7/7-exact",
        "access": "5/5-exact",
        "audit": "5/5-sanitized",
        "handler-effects": "5/5-allow-deny",
        "startup": "5/5-pre-readiness",
        "public-assets": "5/5-allowlisted",
        "private-probes": "5/5-nondisclosing",
        "websocket": "7/7-admission",
        "fresh-challenge": "signed-authority-to-handler-process",
        "idempotency": "2-requests/1-handler-effect",
        "mutants": "9/9-red",
        "network-observer": observer,
        "live-keycloak-truth": "UNVERIFIED",
        "live-edge-exclusivity": "UNVERIFIED",
        "live-provider-policy": "UNVERIFIED",
        "live-storage-isolation": "UNVERIFIED",
        "cluster-deployment": "UNVERIFIED",
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
        "live-keycloak-truth", "live-edge-exclusivity", "live-provider-policy",
        "live-storage-isolation", "cluster-deployment", "replica-loss", "ha-behavior",
    }
    coverage = [
        {"surface": surface, "status": "UNVERIFIED" if surface in unverified else "tested"}
        for surface in ENUMERATION.read_text(encoding="utf-8").splitlines()
    ]
    ledger = {
        "phase": 22,
        "gate_command": "python3 tools/phase22_gate.py",
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
        raise GateFailure("committed Phase-22 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, observed: str, mutants: str, build: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
    (EVIDENCE / "server-observed.log").write_text(observed, encoding="utf-8")
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
        print(f"phase22-network-observer: {observer}")
        print(f"phase22-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase22-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
