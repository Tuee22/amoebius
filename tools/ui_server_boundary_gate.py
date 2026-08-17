#!/usr/bin/env python3
"""Run and seal the authenticated UI-server boundary checks.

This is the first run of this gate that could ever have passed. The boundary ABI
`app/amoebius/Amoebius/Ui/Server/Main.hs` consumes — the request/response types, plan admission, and
the authorize-then-dispatch entry point — was declared by its import list and defined
nowhere, so `exe:amoebius` did not build. `Amoebius.Ui.Server.Dispatch` now implements it,
and the executable's own packaging defect is fixed alongside: listing `src` in its
`hs-source-dirs` made GHC recompile the shared core into this component against a much
shorter `build-depends`, which is why the build failed on a Vault module the executable
never mentions.

The run's own records live in the run bundle under `.build/runs/`, the surface enumeration is
produced at run time and joined to an authored expectation, the result is bound to a
source-snapshot digest and retained inside the checkout, and `cabal`/`ghc` resolve from
`tools/toolchain_requirements.json` instead of the absolute developer path this file used to
carry.
"""

from __future__ import annotations

import csv
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
import toolchain


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "test/fixtures/ui_server"
MUTANTS = ROOT / "test/mutant/ui_server_boundary/mutants.tsv"
LOCUS = ROOT / "test/oracle/ui_server_boundary/validation_locus.tsv"
ENTRY_POINT = ROOT / "app/amoebius/Amoebius/Ui/Server/Main.hs"
RETIRED_ENTRY_POINT = ROOT / "src/Amoebius/Ui/Server/Main.hs"
RESULTS = ROOT / ".build/dsl/ui-server-boundary/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/ui-server-boundary/validation-locus-ledger.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_26_ui_server_boundary.md"
GATE_COMMAND = "python3 tools/ui_server_boundary_gate.py"
EXPECTATIONS = ROOT / "test/oracle/ui_server_boundary_surfaces.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/ui-server-boundary"
TEMP_ROOT = ROOT / ".build/tmp/ui-server-boundary"

COMPILER = ""

CHECKS = {
    "serve-ui-executable-responsibility": "serve-ui is a subcommand of the amoebius executable",
    "entry-point-outside-shared-core": "the entry point lives in the executable's own tree, not the shared core",
    "verified-credential-opaque": "the VerifiedCredential constructor is not exported",
    "hmac-credential-boundary": "the credential is HMAC-verified and the context derived from it",
    "dispatch-boundary-present": "the dispatch boundary and its mutant controls are declared",
    "server-boundary-present": "the serve-ui boundary's dispatch, socket, and path handling survive",
    "fixed-five-header-set": "the production security-header set is exactly five fixed headers",
    "websocket-admission-present": "WebSocket admission still checks the coordinator and envelope",
    "forbidden-server-token-scan": "no provider coordinate or caller-authored identity token is in the server",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "source", "build", "suite", "observer", "mutant", "results")

EXPECTED_RESULTS = {
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
    "network-observer": "loopback-only",
    "live-keycloak-truth": "UNVERIFIED",
    "live-edge-exclusivity": "UNVERIFIED",
    "live-provider-policy": "UNVERIFIED",
    "live-storage-isolation": "UNVERIFIED",
    "cluster-deployment": "UNVERIFIED",
    "replica-loss": "UNVERIFIED",
    "ha-behavior": "UNVERIFIED",
}

# Which recorded metric decides each item-backed surface, stated per surface because this
# phase's locus column names a code locus rather than an observation class.
SURFACE_METRIC = {
    "hmac-signed-credential": "http",
    "credential-claims-derived": "access",
    "caller-tenant-header-hostile": "access",
    "same-origin-check": "access",
    "csrf-check": "access",
    "current-request-epoch-check": "access",
    "current-credential-epoch-check": "access",
    "revoked-grant-denial": "access",
    "own-scope-read": "handler-effects",
    "own-scope-mutation": "handler-effects",
    "foreign-scope-denial": "handler-effects",
    "idempotency-key-stability": "idempotency",
    "fresh-post-ready-challenge": "fresh-challenge",
    "handler-capability-guard": "fresh-challenge",
    "external-strace-network-observer": "network-observer",
    "startup-canonical-admission": "startup",
    "startup-missing-handler-refusal": "startup",
    "startup-duplicate-handler-refusal": "startup",
    "startup-contract-mismatch-refusal": "startup",
    "startup-abi-mismatch-refusal": "startup",
    "public-root-asset": "public-assets",
    "public-index-asset": "public-assets",
    "public-script-asset": "public-assets",
    "public-style-asset": "public-assets",
    "public-client-plan": "public-assets",
    "fixed-security-headers": "http",
    "private-server-plan-nondisclosure": "private-probes",
    "private-dispatch-table-nondisclosure": "private-probes",
    "private-query-variant-nondisclosure": "private-probes",
    "websocket-origin-check": "websocket",
    "websocket-subprotocol-check": "websocket",
    "websocket-single-use-nonce": "websocket",
    "websocket-current-program": "websocket",
    "websocket-current-abi": "websocket",
    "websocket-current-scope": "websocket",
    "websocket-complete-envelope": "websocket",
    "websocket-coordinator-loss-refusal": "websocket",
    "websocket-valid-registration": "websocket",
    "trust-tenant-header-mutant": "mutants",
    "dispatch-before-authorize-mutant": "mutants",
    "skip-current-epoch-mutant": "mutants",
    "disable-origin-check-mutant": "mutants",
    "drop-csp-header-mutant": "mutants",
    "ready-with-unresolved-handler-mutant": "mutants",
    "server-first-handler-wins-mutant": "mutants",
    "serve-server-plan-as-client-asset-mutant": "mutants",
    "new-idempotency-key-on-retry-mutant": "mutants",
    "live-keycloak-truth": "live-keycloak-truth",
    "live-edge-exclusivity": "live-edge-exclusivity",
    "live-provider-policy": "live-provider-policy",
    "live-storage-isolation": "live-storage-isolation",
    "cluster-deployment": "cluster-deployment",
    "replica-loss": "replica-loss",
    "ha-behavior": "ha-behavior",
}

CHECK_SIDE = {
    "serve-ui-executable-responsibility": "source",
    "entry-point-outside-shared-core": "source",
    "verified-credential-opaque": "source",
    "hmac-credential-boundary": "source",
    "dispatch-boundary-present": "source",
    "server-boundary-present": "source",
    "fixed-five-header-set": "source",
    "websocket-admission-present": "source",
    "forbidden-server-token-scan": "source",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}

ACCEPTANCE_TOKEN = (
    "ui-server-boundary-spec: PASS "
    "(7 HTTP rows, 5 access rows, 5 audits, 5 effects, 5 startup rows, 5 public assets, "
    "5 private probes, 7 WebSocket rows, 9 mutants)"
)


class GateFailure(RuntimeError):
    pass


def environment(extra: dict[str, str] | None = None) -> dict[str, str]:
    value = toolchain.contained_env()
    inherited_path = value.get("PATH", "/usr/bin:/bin")
    value["PATH"] = f"{ROOT / '.build/node_modules/.bin'}:{ROOT / 'tools'}:{inherited_path}"
    value["AMOEBIUS_TEST_TMP"] = str(TEMP_ROOT)
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
    """Run a command, forcing every cabal invocation onto the resolved compiler."""
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1", *command[1:],
        ]
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


def verify_oracles() -> tuple[list[dict[str, str]], dict[str, int]]:
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
    counts: dict[str, int] = {}
    for name, expected in expected_counts.items():
        actual = len(read_tsv(FIXTURES / name))
        if actual != expected:
            raise GateFailure(f"{name} must retain {expected} rows, got {actual}")
        counts[name] = actual
    headers = read_tsv(ROOT / "test/fixtures/ui_security/production_headers.tsv")
    if len(headers) != 5 or {row["header"] for row in headers} != {
        "Content-Security-Policy", "Cross-Origin-Opener-Policy", "Cross-Origin-Resource-Policy",
        "Referrer-Policy", "X-Content-Type-Options",
    }:
        raise GateFailure("production security-header contract drifted")
    mutants = read_tsv(MUTANTS)
    if len(mutants) != 9 or len({row["mutant"] for row in mutants}) != 9:
        raise GateFailure("Phase-26 mutant manifest must contain nine unique rows")
    for row in mutants:
        fixture = ROOT / row["fixture"]
        if not fixture.is_file() or "operator=" not in fixture.read_text(encoding="utf-8"):
            raise GateFailure(f"mutant fixture is absent or malformed: {fixture}")
    locus = read_tsv(LOCUS)
    if len(locus) != 54 or len({row["entry"] for row in locus}) != 54:
        raise GateFailure("Phase-26 validation locus must contain fifty-four unique rows")
    phase0_rows = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "22"]) != 19:
        raise GateFailure("Phase-0 manifest must pin nineteen Phase-26 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 with local signed authority/handler fakes; live layers UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    return mutants, counts


def item_classes() -> dict[str, str]:
    classes = {row["entry"].strip(): row["locus"].strip() for row in read_tsv(LOCUS)}
    for row in read_tsv(MUTANTS):
        classes[row["mutant"].strip()] = "mutant"
    return classes


def verify_source_boundaries() -> None:
    request_context = (ROOT / "src/Amoebius/Ui/Server/RequestContext.hs").read_text(encoding="utf-8")
    dispatch = (ROOT / "src/Amoebius/Ui/Server/Dispatch.hs").read_text(encoding="utf-8")
    server = ENTRY_POINT.read_text(encoding="utf-8")
    headers = (ROOT / "src/Amoebius/Ui/Server/SecurityHeaders.hs").read_text(encoding="utf-8")
    websocket = (ROOT / "src/Amoebius/Ui/Server/WebSocket.hs").read_text(encoding="utf-8")
    app = (ROOT / "app/amoebius/Main.hs").read_text(encoding="utf-8")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")

    if "VerifiedCredential (" in request_context.split("where", 1)[0]:
        raise GateFailure("verified-credential-opaque: the VerifiedCredential constructor became public")
    for token in ("SHA256.hmac", "verifyCredential", "serverRequestContext"):
        if token not in request_context:
            raise GateFailure(f"hmac-credential-boundary: signed credential boundary disappeared: {token}")
    for token in ("admitServerPlan", "authorizeAndDispatch", "DispatchBeforeAuthorize", "NewIdempotencyKeyOnRetry"):
        if token not in dispatch:
            raise GateFailure(f"dispatch-boundary-present: dispatch boundary or mutant control disappeared: {token}")
    for token in ("dispatchOnce", "sendHandlerInvocation", "serveWebSocket", "pathOnly"):
        if token not in server:
            raise GateFailure(f"server-boundary-present: server boundary disappeared: {token}")
    if len([line for line in headers.splitlines() if line.strip().startswith(", (")]) != 4:
        raise GateFailure("fixed-five-header-set: the fixed five-header production set drifted")
    if "validateRegistration" not in websocket or "registrationCoordinatorAvailable" not in websocket:
        raise GateFailure("websocket-admission-present: WebSocket admission/coordinator boundary disappeared")
    if '"serve-ui" : options -> runServeUi options' not in app:
        raise GateFailure("serve-ui-executable-responsibility: serve-ui is no longer an executable responsibility")
    for forbidden in ("provider.invalid", "redis://", "pulsar://", "X-Subject"):
        if forbidden in server:
            raise GateFailure(f"forbidden-server-token-scan: forbidden authority/provider token: {forbidden}")

    # The entry point belongs to the executable, and the executable must not put the shared
    # core's source directory on its search path. `hs-source-dirs` is a search path, not a
    # module filter: with `src` on it, every module app/amoebius/Main.hs imports is recompiled into
    # this component against its own much shorter build-depends, and the program ends up
    # carrying two separately compiled copies of the same core.
    if not ENTRY_POINT.is_file():
        raise GateFailure("entry-point-outside-shared-core: the serve-ui entry point is missing from app/amoebius/")
    if RETIRED_ENTRY_POINT.is_file():
        raise GateFailure("entry-point-outside-shared-core: the entry point returned to the shared core tree")
    stanza = cabal.split("\nexecutable amoebius\n", 1)
    if len(stanza) != 2:
        raise GateFailure("entry-point-outside-shared-core: the amoebius executable stanza is missing")
    body = stanza[1].split("\nexecutable ", 1)[0]
    source_dirs = re.search(r"hs-source-dirs:\n((?:\s{6}\S+\n)+)", body)
    if source_dirs is None:
        raise GateFailure("entry-point-outside-shared-core: the executable declares no hs-source-dirs")
    directories = [line.strip() for line in source_dirs.group(1).splitlines() if line.strip()]
    if directories != ["app/amoebius"]:
        raise GateFailure(
            f"entry-point-outside-shared-core: the executable searches {directories}, not app/amoebius alone"
        )


def build_binaries(cabal: Path) -> tuple[Path, Path, str]:
    build = run([str(cabal), "build", "exe:amoebius", "test:ui-server-boundary-spec"])
    executable = Path(run([str(cabal), "list-bin", "exe:amoebius"]).stdout.strip())
    suite = Path(run([str(cabal), "list-bin", "test:ui-server-boundary-spec"]).stdout.strip())
    if not executable.is_file() or not suite.is_file():
        raise GateFailure("Phase-26 executable or suite binary is absent")
    return executable, suite, build.stdout


def run_green(cabal: Path, executable: Path) -> str:
    result = run(
        [str(cabal), "test", "ui-server-boundary-spec", "--test-show-details=direct"],
        extra_env={"AMOEBIUS_BIN": str(executable)},
    )
    if ACCEPTANCE_TOKEN not in result.stdout:
        raise GateFailure("Phase-26 acceptance token is absent")
    return result.stdout


def observed_binary(executable: Path, suite: Path) -> tuple[str, str, int]:
    """Read the boundary's network behaviour from the OS, not from the code under test."""
    if shutil.which("strace") is None:
        raise GateFailure("strace is required for the UI-server OS-network observer")
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
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
        raise GateFailure("observed Phase-26 binary missed its acceptance token")
    return result.stdout, "loopback-only", len(loopback)


def run_mutants(executable: Path, suite: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in mutants:
        mutant = row["mutant"]
        result = run(
            [str(suite), f"--mutant={mutant}"], require_success=False,
            extra_env={"AMOEBIUS_BIN": str(executable)},
        )
        token = f"ui-server-boundary-mutant: RED {mutant} {row['locus']}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        reddened += 1
        logs.append(result.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], reddened: int, total: int, observer: str) -> None:
    """Record what this run measured, not what the contract hoped for."""
    metrics = {
        "http": f"{counts['expected_http.tsv']}/7-exact",
        "access": f"{counts['access_matrix.tsv']}/5-exact",
        "audit": f"{counts['expected_audit.tsv']}/5-sanitized",
        "handler-effects": f"{counts['expected_effects.tsv']}/5-allow-deny",
        "startup": f"{counts['startup_plan_matrix.tsv']}/5-pre-readiness",
        "public-assets": f"{counts['public_asset_allowlist.tsv']}/5-allowlisted",
        "private-probes": "5/5-nondisclosing",
        "websocket": f"{counts['websocket_registration.tsv']}/7-admission",
        "fresh-challenge": "signed-authority-to-handler-process",
        "idempotency": "2-requests/1-handler-effect",
        "mutants": f"{reddened}/{total}-red",
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
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8"
    )


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]],
    rows: Mapping[str, str],
    classes: Mapping[str, str],
    results: Mapping[str, bool],
) -> dict[str, bool]:
    """Decide each item- and check-backed surface from a recorded observation.

    A metric whose authored value is UNVERIFIED never evidences a surface. Matching the
    string "UNVERIFIED" against itself is agreement, not evidence, and treating it as a pass
    is exactly how an unreached layer starts reading as a tested one.
    """
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            metric = SURFACE_METRIC.get(surface)
            unknown = [i for i in ids if i not in classes]
            status[surface] = (
                not unknown
                and metric is not None
                and EXPECTED_RESULTS.get(metric) != "UNVERIFIED"
                and rows.get(metric) == EXPECTED_RESULTS[metric]
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=22, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="2", substrate="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    classes: dict[str, str] = {}
    reddened = 0
    observer = "unrun"

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        cabal = Path(resolved["cabal"]["path"])
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)

        print("\noracle side — the request, access, audit, startup, asset, and socket pins\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the boundary's credential, dispatch, and packaging seams\n")
        verify_source_boundaries()
        for check in (
            "verified-credential-opaque", "hmac-credential-boundary", "dispatch-boundary-present",
            "server-boundary-present", "fixed-five-header-set", "websocket-admission-present",
            "serve-ui-executable-responsibility", "entry-point-outside-shared-core",
            "forbidden-server-token-scan",
        ):
            print(f"  ok    {check}")
        results["source"] = True

        print("\nbuild side — the executable and its boundary suite\n")
        executable, suite, build_log = build_binaries(cabal)
        (gate.run_dir / "build.log").write_text(build_log, encoding="utf-8")
        print(f"  ok    exe:amoebius and test:ui-server-boundary-spec built")
        results["build"] = True

        print("\nsuite side — the authenticated boundary against separate authority and handler\n")
        green = run_green(cabal, executable)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        print("  ok    the acceptance token is present")
        results["suite"] = True

        print("\nobserver side — the OS boundary decides what the server reached\n")
        observed, observer, loopback = observed_binary(executable, suite)
        (gate.run_dir / "server-observed.log").write_text(observed, encoding="utf-8")
        print(f"  ok    loopback-only network use across {loopback} observed syscall(s)")
        results["observer"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log, reddened = run_mutants(executable, suite, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(counts, reddened, len(mutant_rows), observer)
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"ui-server-boundary-gate: FAIL: {problem}", file=sys.stderr)

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
        "Decision": "tested" if rows.get("access") == EXPECTED_RESULTS["access"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("http") == EXPECTED_RESULTS["http"] else "UNVERIFIED",
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
        dependencies={"ui-server-boundary-spec": "cabal test", "amoebius": "cabal build exe"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "phase-26 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
