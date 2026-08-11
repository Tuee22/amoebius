#!/usr/bin/env python3
"""Run and seal the Phase-21 generic browser-interpreter boundary checks."""

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
FIXTURES = ROOT / "test/fixtures/ui_browser"
MUTANTS = ROOT / "tests/mutants/phase21/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase21/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_21_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_21_ledger.json"
RESULTS = ROOT / "gen/dsl/phase21/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase21/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_21"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = dict(os.environ)
    value["PATH"] = f"{ROOT / 'node_modules/.bin'}:/usr/bin:/bin"
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
    executables = [
        (Path(pins["purs"]["path"]), pins["purs"]["version"]),
        (Path(pins["spago"]["path"]), pins["spago"]["version"]),
        (Path(pins["chromium"]["path"]), pins["chromium"]["version"]),
    ]
    if not cabal.is_file() or any(not path.is_file() for path, _ in executables):
        raise GateFailure("one or more Phase-21 pinned executables are absent")
    versions = run([str(cabal), "--numeric-version"]).stdout
    versions += run([str(executables[0][0]), "--version"]).stdout
    versions += run(["node", str(executables[1][0]), "--version"]).stdout
    versions += run([str(executables[2][0]), "--version"]).stdout
    for _path, version in executables:
        if version not in versions:
            raise GateFailure(f"Phase-21 tool version drifted: {version}\n{versions}")
    package = json.loads((ROOT / "node_modules/playwright-core/package.json").read_text(encoding="utf-8"))
    root_package = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
    if package["version"] != "1.62.1" or root_package["devDependencies"].get("playwright-core") != "1.62.1":
        raise GateFailure("playwright-core must remain exactly pinned at 1.62.1")
    return cabal, versions + f"playwright-core {package['version']}\n"


def verify_oracles() -> None:
    interactions = read_tsv(FIXTURES / "interactions.tsv")
    traces = read_tsv(FIXTURES / "reference_traces.tsv")
    accessibility = read_tsv(FIXTURES / "expected_accessibility.tsv")
    focus = read_tsv(FIXTURES / "expected_keyboard_focus.tsv")
    transport = read_tsv(FIXTURES / "expected_transport.tsv")
    allowlist = read_tsv(FIXTURES / "artifact_allowlist.tsv")
    if len(interactions) != 5 or len(traces) != 4:
        raise GateFailure("browser corpus must pin five interactions and four reference steps")
    if len(accessibility) != 3 or len(focus) != 5 or len(transport) != 4:
        raise GateFailure("browser observation table counts drifted")
    if len(allowlist) != 9 or sum(row["class"] == "forbidden" for row in allowlist) != 4:
        raise GateFailure("built-artifact allowlist drifted")
    plans = [json.loads(path.read_text(encoding="utf-8")) for path in sorted((FIXTURES / "plans").glob("*.json"))]
    generated_events = {event for plan in plans for event in plan["events"]}
    authored_events = {row["event"] for row in interactions}
    if generated_events != authored_events:
        raise GateFailure(f"generated/authored event join is incomplete: {generated_events ^ authored_events}")
    if len(read_tsv(ROOT / "test/fixtures/ui_security/production_headers.tsv")) != 5:
        raise GateFailure("production browser header set must contain five rows")
    if len(read_tsv(MUTANTS)) != 9:
        raise GateFailure("Phase-21 mutant manifest must contain nine rows")
    locus = read_tsv(LOCUS)
    if len(locus) != 45 or len({row["entry"] for row in locus}) != 45:
        raise GateFailure("Phase-21 validation locus must contain forty-five unique rows")
    phase0_rows = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "21"]) != 20:
        raise GateFailure("Phase-0 manifest must pin twenty Phase-21 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 with local Chrome/fakes; server/provider/live runtime UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )


def verify_source_boundaries() -> None:
    interpreter = (ROOT / "ui-runtime/src/Amoebius/Ui/Interpreter.purs").read_text(encoding="utf-8")
    components = (ROOT / "ui-runtime/src/Amoebius/Ui/Components.purs").read_text(encoding="utf-8")
    ffi = (ROOT / "ui-runtime/src/Main.js").read_text(encoding="utf-8")
    for token in ("edit", "submit", "cancel", "open-docs", "choose"):
        if f'"{token}"' not in interpreter:
            raise GateFailure(f"closed PureScript event arm disappeared: {token}")
    for token in ("innerHTML", "eval(", "localStorage", "sessionStorage", "indexedDB", "provider.invalid"):
        if token in interpreter + components + ffi:
            raise GateFailure(f"forbidden generic-browser source token: {token}")
    if "textContent" not in ffi or "new WebSocket" not in ffi:
        raise GateFailure("escaped DOM sink or same-origin WebSocket disappeared")
    if "playwright-core" not in (ROOT / "test/ui/browser/phase21_browser.mjs").read_text(encoding="utf-8"):
        raise GateFailure("browser harness no longer drives Playwright")
    reference = (ROOT / "test/ui/ReferenceClientPlan.hs").read_text(encoding="utf-8")
    if "Amoebius.Ui" in reference:
        raise GateFailure("independent Haskell semantics imports production UI code")


def run_green(cabal: Path) -> str:
    result = run([str(cabal), "test", "ui-browser-interpreter-spec", "--offline", "--test-show-details=direct"])
    token = "ui-browser-interpreter-spec: PASS (2 plans, 5 interactions, 4 traces, 2 DOM snapshots, 3 accessibility rows, 5 focus rows, 4 transport rows, 9 mutants)"
    if token not in result.stdout:
        raise GateFailure("Phase-21 acceptance token is absent")
    return result.stdout


def observed_binary(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-browser-interpreter-spec", "--offline"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-browser-interpreter-spec", "--offline"]).stdout.strip())
    if shutil.which("strace") is None:
        raise GateFailure("strace is required for the browser OS-network observer")
    with tempfile.TemporaryDirectory(prefix="amoebius-phase21-") as directory:
        trace = Path(directory) / "network.trace"
        result = run([
            "strace", "-f", "-qq", "-e", "trace=connect,sendto",
            "-e", "status=successful,failed", "-e", "signal=none",
            "-o", str(trace), str(binary),
        ])
        trace_text = trace.read_text(encoding="utf-8")
        forbidden = []
        hard_failed = []
        for line in trace_text.splitlines():
            if "AF_INET" not in line and "AF_INET6" not in line:
                continue
            if any(allowed in line for allowed in ('inet_addr("127.', 'inet_pton(AF_INET6, "::1"', 'sin_addr=htonl(INADDR_LOOPBACK)')):
                continue
            if " = -1 ENETUNREACH " in line:
                hard_failed.append(line)
                continue
            forbidden.append(line)
        if forbidden:
            raise GateFailure("browser boundary attempted non-loopback network access:\n" + "\n".join(forbidden[:30]))
    observer = f"strace-established-loopback-only;nonloopback-enetunreach={len(hard_failed)}"
    return result.stdout, observer


def run_mutants(cabal: Path) -> str:
    logs: list[str] = []
    loci = {
        "M-raw-html-sink": "hostile-text-dom",
        "M-drop-event-effect": "single-submit-effect",
        "M-swap-route-target": "route-focus",
        "M-accept-stale-plan": "ReloadRequired",
        "M-direct-provider-fetch": "provider-zero",
        "M-sequential-state-writes": "atomic-trace",
        "M-break-focus-return": "modal-opener",
        "M-unsafe-inline-build": "csp-canary",
        "M-hardcoded-response": "fresh-nonce",
    }
    for row in read_tsv(MUTANTS):
        mutant = row["mutant"]
        result = run([
            str(cabal), "test", "ui-browser-interpreter-spec", "--offline", "--test-show-details=direct",
            f"--test-options=--mutant={mutant}",
        ], require_success=False)
        token = f"phase21-browser-mutant: RED {mutant} {loci[mutant]}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"browser mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "plans": "2/2-decoded",
        "generated-enumeration": "5/5-events-exact-join",
        "differential-traces": "4/4-step-exact",
        "dom-snapshots": "2/2-exact-fresh-nonce",
        "accessibility": "3/3-exact",
        "keyboard-focus": "5/5-exact",
        "transport": "4/4-allow-deny",
        "websocket": "same-origin-upgrade-observed",
        "artifact-csp": "scanner+browser-canary-pass",
        "mutants": "9/9-red",
        "network-observer": observer,
        "server-authorization-truth": "UNVERIFIED",
        "provider-isolation": "UNVERIFIED",
        "live-edge-enforcement": "UNVERIFIED",
        "release-rollout": "UNVERIFIED",
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
    unverified = {"server-authorization-truth", "provider-isolation", "live-edge-enforcement", "release-rollout", "ha-behavior"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        coverage.append({"surface": surface, "status": "UNVERIFIED" if surface in unverified else "tested"})
    ledger = {
        "phase": 21,
        "gate_command": "python3 tools/phase21_gate.py",
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
        raise GateFailure("committed Phase-21 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, observed: str, mutants: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
    (EVIDENCE / "browser-observed.log").write_text(observed, encoding="utf-8")
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
        green = run_green(cabal)
        observed, observer = observed_binary(cabal)
        token = "ui-browser-interpreter-spec: PASS"
        if token not in observed:
            raise GateFailure("observed browser binary missed its acceptance token")
        mutants = run_mutants(cabal)
        write_results(observer)
        ledger_hash = verify_ledger()
        retain_evidence(green, observed, mutants, versions)
        print(green, end="", flush=True)
        print(f"phase21-network-observer: {observer}")
        print(f"phase21-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase21-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
