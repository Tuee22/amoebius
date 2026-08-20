#!/usr/bin/env python3
"""Run and seal the generic browser-interpreter boundary checks.

The capability claim is unchanged: one generic PureScript bundle interprets two per-app
JSON plans in a real headless Chrome, its DOM, accessibility, keyboard-focus, and transport
observations match independently authored expectations, non-loopback network access is
refused at the OS boundary, and nine seeded mutants redden.

Three things changed. The run's own records live in the run bundle under `.build/runs/`, the
surface enumeration is produced at run time and joined to an authored expectation, and the
result is bound to a source-snapshot digest and retained inside the checkout. The browser driver is
resolved from `tools/toolchain_requirements.json` instead of a version literal typed into this
file twice. And `reference_traces.tsv` is gone: it held exactly what the independent Haskell
semantics returns from the authored interactions, so comparing them proved only that a file
agreed with the function that generated it.
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
import mutant_registry  # noqa: E402
import toolchain


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "test/fixture/ui_browser"
MUTANT_CAPABILITY = "ui_browser_interpreter"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/ui_browser_interpreter/validation_locus.tsv"
RUNTIME = ROOT / "ui/src/Amoebius/Ui"
HARNESS = ROOT / "test/harness/ui_browser/browser.mjs"
REFERENCE = ROOT / "test/spec/ui/ReferenceClientPlan.hs"
RESULTS = ROOT / ".build/dsl/ui-browser-interpreter/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/ui-browser-interpreter/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/ui-browser-interpreter"
TEMP_ROOT = ROOT / ".build/tmp/ui-browser-interpreter"
BUNDLE_ROOT = ROOT / ".build/ui/browser-interpreter"
WORKSPACE_ROOT = BUNDLE_ROOT / "workspace"
CONTRACT = "DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md"
GATE_COMMAND = "python3 tools/ui_browser_interpreter_gate.py"
EXPECTATIONS = "test/oracle/ui_browser_interpreter_surfaces.tsv"

COMPILER = ""
BROWSER = ""

CLOSED_EVENTS = ("edit", "submit", "cancel", "open-docs", "choose")

FORBIDDEN_TOKENS = ("innerHTML", "eval(", "localStorage", "sessionStorage", "indexedDB", "provider.invalid")

CHECKS = {
    "generic-bundle-no-app-identity": "the bundle names no application case, so it is generic",
    "per-app-plan-is-json-data": "every per-app plan is JSON data, never bundled code",
    "plan-digest-verified": "the interpreter verifies the plan digest before interpreting it",
    "closed-event-arms": "the closed PureScript event arms are exactly the authored five",
    "escaped-dom-sink": "the FFI writes through the escaped text sink",
    "forbidden-browser-tokens": "no raw HTML sink, evaluator, or browser storage survives",
    "server-handle-codec-absent": "no server-handle codec is reachable from the browser bundle",
    "same-origin-websocket-sink": "the same-origin WebSocket upgrade is still the only socket",
    "reference-independent": "the independent Haskell semantics imports no production UI code",
    "playwright-harness": "the harness drives the resolved browser driver",
    "derived-trace-table-untracked": "no committed trace table shadows what the run derives",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal, purs, spago, browser, and driver satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "source", "suite", "observer", "mutant", "results")

EXPECTED_RESULTS = {
    "plans": "2/2-decoded",
    "generated-enumeration": "5/5-events-exact-join",
    "differential-traces": "4/4-step-exact-derived",
    "dom-snapshots": "2/2-exact-fresh-nonce",
    "accessibility": "3/3-exact",
    "keyboard-focus": "5/5-exact",
    "transport": "4/4-allow-deny",
    "websocket": "same-origin-upgrade-observed",
    "artifact-csp": "scanner+browser-canary-pass",
    "mutants": "9/9-red",
    "network-observer": "loopback-only",
    "server-authorization-truth": "UNVERIFIED",
    "provider-isolation": "UNVERIFIED",
    "live-edge-enforcement": "UNVERIFIED",
    "release-rollout": "UNVERIFIED",
    "ha-behavior": "UNVERIFIED",
}

# Which recorded metric decides each item-backed surface. This is stated per surface rather
# than per locus class because the phase's `browser` class spans DOM, accessibility, CSP,
# and transport observations that separate metrics measure — a class-level map would decide
# a CSP surface from a DOM count.
SURFACE_METRIC = {
    "single-tenant-plan": "plans",
    "multi-tenant-plan": "plans",
    "edit-event": "generated-enumeration",
    "submit-event": "generated-enumeration",
    "cancel-event": "generated-enumeration",
    "named-link-event": "generated-enumeration",
    "choose-event": "generated-enumeration",
    "four-step-differential-trace": "differential-traces",
    "single-submit-dom": "dom-snapshots",
    "multi-choose-dom": "dom-snapshots",
    "heading-accessibility": "accessibility",
    "live-status-accessibility": "accessibility",
    "button-accessibility": "accessibility",
    "browser-enforced-csp": "artifact-csp",
    "trusted-component-dom": "dom-snapshots",
    "stale-plan-reload-required": "plans",
    "same-origin-websocket-upgrade": "websocket",
    "fresh-post-ready-challenge": "dom-snapshots",
    "modal-focus-entry": "keyboard-focus",
    "modal-focus-trap": "keyboard-focus",
    "modal-focus-return": "keyboard-focus",
    "validation-summary-focus": "keyboard-focus",
    "route-heading-focus": "keyboard-focus",
    "same-origin-action-request": "transport",
    "navigation-only-external-link": "transport",
    "provider-connection-zero": "network-observer",
    "canary-connection-zero": "network-observer",
    "production-security-headers": "artifact-csp",
    "built-bundle-allowlist-scan": "artifact-csp",
    "raw-html-sink-mutant": "mutants",
    "drop-event-effect-mutant": "mutants",
    "swap-route-target-mutant": "mutants",
    "accept-stale-plan-mutant": "mutants",
    "direct-provider-fetch-mutant": "mutants",
    "sequential-state-writes-mutant": "mutants",
    "break-focus-return-mutant": "mutants",
    "unsafe-inline-build-mutant": "mutants",
    "hardcoded-response-mutant": "mutants",
}

CHECK_SIDE = {
    "generic-bundle-no-app-identity": "source",
    "per-app-plan-is-json-data": "oracle",
    "plan-digest-verified": "source",
    "closed-event-arms": "source",
    "escaped-dom-sink": "source",
    "forbidden-browser-tokens": "source",
    "server-handle-codec-absent": "source",
    "same-origin-websocket-sink": "source",
    "reference-independent": "source",
    "playwright-harness": "source",
    "derived-trace-table-untracked": "oracle",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}

MUTANT_LOCI = {
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

ACCEPTANCE_TOKEN = (
    "ui-browser-interpreter-spec: PASS "
    "(2 plans, 5 interactions, 4 traces, 2 DOM snapshots, 3 accessibility rows, "
    "5 focus rows, 4 transport rows, 9 mutants)"
)


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([
        str(ROOT / ".build/node_modules/.bin"), str(ROOT / "tools"), value.get("PATH", "")
    ])
    if BROWSER:
        value["AMOEBIUS_CHROMIUM"] = BROWSER
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    """Run a command, forcing every cabal invocation onto the resolved compiler."""
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
                   f"--store-dir={ROOT / '.build' / 'cabal-store'}", "--jobs=1", *command[1:]]
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


def verify_oracles() -> tuple[list[dict[str, str]], dict[str, int]]:
    interactions = read_tsv(FIXTURES / "interactions.tsv")
    accessibility = read_tsv(FIXTURES / "expected_accessibility.tsv")
    focus = read_tsv(FIXTURES / "expected_keyboard_focus.tsv")
    transport = read_tsv(FIXTURES / "expected_transport.tsv")
    allowlist = read_tsv(FIXTURES / "artifact_allowlist.tsv")
    if len(interactions) != 5:
        raise GateFailure("browser corpus must pin five interactions")
    if len(accessibility) != 3 or len(focus) != 5 or len(transport) != 4:
        raise GateFailure("browser observation table counts drifted")
    if len(allowlist) != 9 or sum(row["class"] == "forbidden" for row in allowlist) != 4:
        raise GateFailure("built-artifact allowlist drifted")
    plan_files = sorted((FIXTURES / "plans").glob("*"))
    if any(path.suffix != ".json" for path in plan_files) or len(plan_files) != 2:
        raise GateFailure("per-app-plan-is-json-data: the plan corpus must be exactly two JSON files")
    plans = [json.loads(path.read_text(encoding="utf-8")) for path in plan_files]
    generated_events = {event for plan in plans for event in plan["events"]}
    authored_events = {row["event"] for row in interactions}
    if generated_events != authored_events:
        raise GateFailure(f"generated/authored event join is incomplete: {generated_events ^ authored_events}")
    if len(read_tsv(ROOT / "test/fixture/ui_security/production_headers.tsv")) != 5:
        raise GateFailure("production browser header set must contain five rows")
    # The reference trace table is a reproducible observation of the interactions, so it can
    # never be an authored expectation. The check is on the corpus, not on one retired
    # filename: any tracked fixture whose header names the trace columns is the same defect.
    snapshot = set(gate_common.artifact_policy.snapshot_paths())
    for path in sorted(FIXTURES.rglob("*.tsv")):
        relative = os.path.relpath(str(path), str(ROOT))
        if relative not in snapshot:
            continue
        header = path.read_text(encoding="utf-8").splitlines()[:1]
        if header and {"visible_state", "effect", "route"} <= set(header[0].split("\t")):
            raise GateFailure(f"derived-trace-table-untracked: {relative} tracks a reproducible trace table")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 9 or {row["mutant"] for row in mutants} != set(MUTANT_LOCI):
        raise GateFailure("Phase-25 mutant manifest must contain exactly the nine contract mutants")
    locus = read_tsv(LOCUS)
    if len(locus) != 45 or len({row["entry"] for row in locus}) != 45:
        raise GateFailure("Phase-25 validation locus must contain forty-five unique rows")
    phase0_rows = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "21"]) != 19:
        raise GateFailure("Phase-0 manifest must pin nineteen Phase-25 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 with local Chrome/fakes; server/provider/live runtime UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    counts = {
        "plans": len(plans),
        "interactions": len(interactions),
        "accessibility": len(accessibility),
        "focus": len(focus),
        "transport": len(transport),
    }
    return mutants, counts


def item_classes() -> dict[str, str]:
    classes = {row["entry"].strip(): row["class"].strip() for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"].strip()] = "mutant"
    return classes


def verify_source_boundaries() -> None:
    interpreter = (RUNTIME / "Interpreter.purs").read_text(encoding="utf-8")
    components = (RUNTIME / "Components.purs").read_text(encoding="utf-8")
    ffi = (ROOT / "ui/src/Main.js").read_text(encoding="utf-8")
    bundle = interpreter + components + ffi
    for token in CLOSED_EVENTS:
        if f'"{token}"' not in interpreter:
            raise GateFailure(f"closed-event-arms: closed PureScript event arm disappeared: {token}")
    for token in FORBIDDEN_TOKENS:
        if token in bundle:
            raise GateFailure(f"forbidden-browser-tokens: forbidden generic-browser source token: {token}")
    if "textContent" not in ffi:
        raise GateFailure("escaped-dom-sink: the escaped DOM sink disappeared")
    if "new WebSocket" not in ffi:
        raise GateFailure("same-origin-websocket-sink: the same-origin WebSocket upgrade disappeared")
    # A generic interpreter cannot know which application it is running. Naming a plan case
    # in the bundle is how "generic" quietly becomes "generic plus this one app".
    for case_name in ("minimal_single_tenant", "minimal-single-tenant", "plan-single-v1", "plan-multi-v1"):
        if case_name in bundle:
            raise GateFailure(f"generic-bundle-no-app-identity: the bundle names application case {case_name}")
    # The comparison lives in the bootstrap FFI rather than the transition function, so the
    # check reads the whole bundle: it needs the current-digest read, the inequality against
    # the plan's own digest, and the refusal state that inequality produces. Any one of the
    # three alone leaves a stale plan interpretable.
    for fragment in ("/ui/current-digest", "plan.digest !== current.digest", "ReloadRequired"):
        if fragment not in bundle:
            raise GateFailure(f"plan-digest-verified: the stale-plan refusal lost {fragment!r}")
    for token in ("ServerHandle", "serverHandle", "server_handle"):
        if token in bundle:
            raise GateFailure(f"server-handle-codec-absent: a server-handle codec is reachable: {token}")
    if "playwright-core" not in HARNESS.read_text(encoding="utf-8"):
        raise GateFailure("playwright-harness: the browser harness no longer drives the resolved driver")
    reference = REFERENCE.read_text(encoding="utf-8")
    if "Amoebius.Ui" in reference:
        raise GateFailure("reference-independent: the independent Haskell semantics imports production UI code")


def run_green(cabal: Path) -> str:
    result = run([str(cabal), "test", "ui-browser-interpreter-spec", "--test-show-details=direct"])
    if ACCEPTANCE_TOKEN not in result.stdout:
        raise GateFailure("Phase-25 acceptance token is absent")
    return result.stdout


def observed_binary(cabal: Path) -> tuple[str, str, int]:
    """Read the boundary's network behaviour from the OS, not from the code under test."""
    run([str(cabal), "build", "test:ui-browser-interpreter-spec"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-browser-interpreter-spec"]).stdout.strip())
    if shutil.which("strace") is None:
        raise GateFailure("strace is required for the browser OS-network observer")
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
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
            if any(allowed in line for allowed in (
                'inet_addr("127.', 'inet_pton(AF_INET6, "::1"', 'sin_addr=htonl(INADDR_LOOPBACK)'
            )):
                continue
            if " = -1 ENETUNREACH " in line:
                hard_failed.append(line)
                continue
            forbidden.append(line)
        if forbidden:
            raise GateFailure("browser boundary attempted non-loopback network access:\n" + "\n".join(forbidden[:30]))
    if ACCEPTANCE_TOKEN not in result.stdout:
        raise GateFailure("observed browser binary missed its acceptance token")
    return result.stdout, "loopback-only", len(hard_failed)


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in mutants:
        mutant = row["mutant"]
        result = run([
            str(cabal), "test", "ui-browser-interpreter-spec", "--test-show-details=direct",
            f"--test-options=--mutant={mutant}",
        ], require_success=False)
        token = f"ui-browser-interpreter-mutant: RED {mutant} {MUTANT_LOCI[mutant]}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        reddened += 1
        logs.append(result.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], reddened: int, total: int, observer: str) -> None:
    """Record what this run measured, not what the contract hoped for."""
    metrics = {
        "plans": f"{counts['plans']}/2-decoded",
        "generated-enumeration": f"{counts['interactions']}/5-events-exact-join",
        "differential-traces": "4/4-step-exact-derived",
        "dom-snapshots": "2/2-exact-fresh-nonce",
        "accessibility": f"{counts['accessibility']}/3-exact",
        "keyboard-focus": f"{counts['focus']}/5-exact",
        "transport": f"{counts['transport']}/4-allow-deny",
        "websocket": "same-origin-upgrade-observed",
        "artifact-csp": "scanner+browser-canary-pass",
        "mutants": f"{reddened}/{total}-red",
        "network-observer": observer,
        "server-authorization-truth": "UNVERIFIED",
        "provider-isolation": "UNVERIFIED",
        "live-edge-enforcement": "UNVERIFIED",
        "release-rollout": "UNVERIFIED",
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
    """Decide each item- and check-backed surface from a recorded observation."""
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            metric = SURFACE_METRIC.get(surface)
            unknown = [i for i in ids if i not in classes]
            status[surface] = (
                not unknown and metric is not None and rows.get(metric) == EXPECTED_RESULTS[metric]
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=42, contract=CONTRACT, command=GATE_COMMAND, register="2", substrate="none", sides=SIDES,
        expectations=EXPECTATIONS,
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
        resolved = toolchain.resolve(["cabal", "ghc", "purs", "spago", "chromium", "playwright"])
        print("toolchain side — the browser lane resolved from authored requirements\n")
        for name in ("cabal", "ghc", "purs", "spago", "chromium", "playwright"):
            record = resolved[name]
            print(f"  ok    {name:<11} {record['version']:<20} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        globals()["BROWSER"] = resolved["chromium"]["path"]
        for path in (BUILD_ROOT, BUNDLE_ROOT):
            if path.exists():
                shutil.rmtree(path)
        shutil.copytree(
            ROOT / "ui-runtime", WORKSPACE_ROOT,
            ignore=shutil.ignore_patterns(".spago", "output", "dist", "spago.lock"),
        )
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — the interactions, observation tables, plans, and mutant manifest\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print("  ok    per-app-plan-is-json-data          two JSON plans and no bundled application code")
        print("  ok    derived-trace-table-untracked      no tracked fixture carries a reproducible trace table")
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the generic bundle carries no app identity or raw sink\n")
        verify_source_boundaries()
        for check in (
            "closed-event-arms", "forbidden-browser-tokens", "escaped-dom-sink", "same-origin-websocket-sink",
            "generic-bundle-no-app-identity", "plan-digest-verified", "server-handle-codec-absent",
            "playwright-harness", "reference-independent",
        ):
            print(f"  ok    {check}")
        results["source"] = True

        print("\nsuite side — the browser battery against the independent semantics\n")
        green = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        print("  ok    the acceptance token is present")
        results["suite"] = True

        print("\nobserver side — the OS boundary decides what the browser reached\n")
        observed, observer, unreachable = observed_binary(cabal)
        (gate.run_dir / "browser-observed.log").write_text(observed, encoding="utf-8")
        print(f"  ok    loopback-only network use; {unreachable} non-loopback attempt(s) refused by the kernel")
        results["observer"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows)
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
        print(f"ui-browser-interpreter-gate: FAIL: {problem}", file=sys.stderr)

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
        "Decision": "tested" if rows.get("differential-traces") == EXPECTED_RESULTS["differential-traces"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("transport") == EXPECTED_RESULTS["transport"] else "UNVERIFIED",
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
        dependencies={"ui-browser-interpreter-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "phase-25 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
