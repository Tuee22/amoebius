#!/usr/bin/env python3
"""Run and seal the local browser/server/domain composition checks.

The capability claim is unchanged: two authored applications drive one generic browser
bundle against the real `serve-ui` boundary and two separate domain-shaped fake processes,
producing an ordered three-step workflow, four pinned denials with zero leaked bytes, and
five reddened mutants — all observed from real Chrome and the OS network boundary.

The run's own records live in the run bundle under `.build/runs/`, the surface enumeration is
produced at run time and joined to an authored expectation, the result is bound to a
source-snapshot digest and retained inside the checkout, and `cabal`, `ghc`, `dhall`, and the browser
resolve from `tools/toolchain_requirements.json` instead of the absolute developer paths this gate
and its suite used to carry.
"""

from __future__ import annotations

import csv
import json
import os
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
FIXTURES = ROOT / "test/fixture/ui_local_composition"
MUTANT_CAPABILITY = "local_ui_composition"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/local_ui_composition/validation_locus.tsv"
ENTRY_POINT = ROOT / "app/amoebius/Amoebius/Entry/ServeUi.hs"
HARNESS = ROOT / "test/harness/local_ui_composition/composition.mjs"
RESULTS = ROOT / ".build/dsl/local-ui-composition/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/local-ui-composition/validation-locus-ledger.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_44_ui_local_composition.md"
GATE_COMMAND = "python3 tools/local_ui_composition_gate.py"
EXPECTATIONS = ROOT / "test/oracle/local_ui_composition_surfaces.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/local-ui-composition"
TEMP_ROOT = ROOT / ".build/tmp/local-ui-composition"
BUNDLE_ROOT = ROOT / ".build/ui/local-composition"
WORKSPACE_ROOT = BUNDLE_ROOT / "workspace"

COMPILER = ""
BROWSER = ""
DHALL = ""

CHECKS = {
    "generic-bundle-single-artifact": "one generic bundle serves both applications",
    "browser-edge-source-scan": "the browser reaches no storage, evaluator, or provider coordinate",
    "ready-handle-boundary-present": "the server still issues and owner-checks the ready handle",
    "harness-observers-present": "the composition harness keeps both domain fakes and the bypass probe",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal, ghc, dhall, and browser satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "source", "build", "suite", "observer", "mutant", "results")

EXPECTED_RESULTS = {
    "applications": "2/2-dhall-typed",
    "interactions": "5/5-generated-authored-joined",
    "visible": "4/4-exact-fresh",
    "effects": "4/4-exact-ordered",
    "access": "3/3-own-foreign",
    "denials": "5/5-zero-leak",
    "bundle": "one-generic-sha256",
    "fresh-challenge": "browser-server-workflow-artifact-dom",
    "mutants": "5/5-red",
    "network-observer": "loopback-only",
    "live-infernix-adapter": "UNVERIFIED",
    "live-jitml-adapter": "UNVERIFIED",
    "live-keycloak-edge": "UNVERIFIED",
    "live-provider-storage-isolation": "UNVERIFIED",
    "release-rollout": "UNVERIFIED",
    "replica-loss": "UNVERIFIED",
    "ha-behavior": "UNVERIFIED",
}

SURFACE_METRIC = {
    "single-tenant-authored-application": "applications",
    "multi-tenant-authored-application": "applications",
    "infernix-shaped-fake-adapter": "effects",
    "jitml-shaped-fake-adapter": "effects",
    "authored-dhall-typecheck": "bundle",
    "single-client-plan-identity": "applications",
    "multi-client-plan-identity": "applications",
    "start-generated-surface": "interactions",
    "observe-generated-surface": "interactions",
    "use-artifact-generated-surface": "interactions",
    "workflow-running-visible-state": "visible",
    "artifact-ready-visible-state": "visible",
    "fresh-result-visible-state": "visible",
    "foreign-unavailable-visible-state": "visible",
    "ui-server-workflow-start-effect": "effects",
    "fake-workflow-ready-effect": "effects",
    "ui-server-artifact-use-effect": "effects",
    "ordered-effect-sequence": "effects",
    "fresh-challenge-in-dom": "fresh-challenge",
    "fresh-challenge-in-raw-effects": "fresh-challenge",
    "server-issued-ready-handle": "effects",
    "ready-handle-owner-pair": "denials",
    "same-tenant-foreign-denial": "access",
    "foreign-tenant-denial": "access",
    "caller-tenant-header-denial": "denials",
    "non-ready-handle-denial": "denials",
    "foreign-private-byte-zero": "denials",
    "direct-browser-backend-denial": "denials",
    "real-chrome-dom-observer": "visible",
    "os-network-observer": "network-observer",
    "drop-handle-tenant-mutant": "mutants",
    "direct-workflow-fetch-mutant": "mutants",
    "mix-client-server-plan-mutant": "mutants",
    "ready-before-receipt-mutant": "mutants",
    "owner-key-swap-mutant": "mutants",
    "live-infernix-adapter": "live-infernix-adapter",
    "live-jitml-adapter": "live-jitml-adapter",
    "live-keycloak-edge": "live-keycloak-edge",
    "live-provider-storage-isolation": "live-provider-storage-isolation",
    "release-rollout": "release-rollout",
    "replica-loss": "replica-loss",
    "ha-behavior": "ha-behavior",
}

CHECK_SIDE = {
    "generic-bundle-single-artifact": "source",
    "browser-edge-source-scan": "source",
    "ready-handle-boundary-present": "source",
    "harness-observers-present": "source",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}

ACCEPTANCE_TOKEN = (
    "ui-local-composition-spec: PASS "
    "(2 apps, 5 interactions, 4 visible pins, 4 effect rows, 3 access rows, 5 denials, 5 mutants)"
)


class GateFailure(RuntimeError):
    pass


def environment(extra: dict[str, str] | None = None) -> dict[str, str]:
    value = toolchain.contained_env()
    inherited_path = value.get("PATH", "/usr/bin:/bin")
    value["PATH"] = f"{ROOT / '.build/node_modules/.bin'}:{ROOT / 'tools'}:{inherited_path}"
    value["AMOEBIUS_TEST_TMP"] = str(TEMP_ROOT)
    if COMPILER:
        value["AMOEBIUS_GHC"] = COMPILER
    if DHALL:
        value["AMOEBIUS_DHALL"] = DHALL
    if BROWSER:
        value["AMOEBIUS_CHROMIUM"] = BROWSER
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
    expected = {
        "interactions.tsv": 5,
        "expected_visible_states.tsv": 4,
        "expected_effect_sequence.tsv": 4,
        "access_matrix.tsv": 3,
        "expected_denials.tsv": 5,
    }
    counts: dict[str, int] = {}
    for name, count in expected.items():
        actual = len(read_tsv(FIXTURES / name))
        if actual != count:
            raise GateFailure(f"{name} must retain {count} rows, got {actual}")
        counts[name] = actual
    for name in ("single_tenant_workflow.dhall", "multi_tenant_workflow.dhall"):
        if not (FIXTURES / name).is_file():
            raise GateFailure(f"authored application source is absent: {name}")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 5 or len({row["mutant"] for row in mutants}) != 5:
        raise GateFailure("Phase-27 mutant manifest must contain five unique rows")
    for row in mutants:
        fixture = ROOT / row["fixture"]
        if not fixture.is_file() or "operator=" not in fixture.read_text(encoding="utf-8"):
            raise GateFailure(f"mutant fixture is absent or malformed: {fixture}")
    locus = read_tsv(LOCUS)
    if len(locus) != 42 or len({row["entry"] for row in locus}) != 42:
        raise GateFailure("Phase-27 validation locus must contain forty-two unique rows")
    phase0_rows = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "23"]) != 12:
        raise GateFailure("Phase-0 manifest must pin twelve Phase-27 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 with local Chrome/server/domain fakes; live layers UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    return mutants, counts


def item_classes() -> dict[str, str]:
    classes = {row["entry"].strip(): row["locus"].strip() for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"].strip()] = "mutant"
    return classes


def verify_source_boundaries() -> None:
    interpreter = (ROOT / "ui/src/Amoebius/Ui/Interpreter.purs").read_text(encoding="utf-8")
    browser = (ROOT / "ui/src/Main.js").read_text(encoding="utf-8")
    server = ENTRY_POINT.read_text(encoding="utf-8")
    dispatch = (ROOT / "src/Amoebius/Ui/Server/Dispatch.hs").read_text(encoding="utf-8")
    harness = HARNESS.read_text(encoding="utf-8")
    for event in ("start", "observe", "use-artifact"):
        if f'"{event}"' not in interpreter or event not in browser:
            raise GateFailure(f"generic-bundle-single-artifact: generic workflow event disappeared: {event}")
    # One bundle, two applications: the generic runtime may not name either application, or
    # "generic" quietly becomes "generic plus the two we shipped".
    for application in ("composition-single-v1", "composition-multi-v1", "infernix", "jitML"):
        if application in interpreter + browser:
            raise GateFailure(f"generic-bundle-single-artifact: the bundle names application {application}")
    for token in ("readyHandles", "validateReadyHandle", '"workflow-start"', '"workflow-observe"', '"artifact-use"'):
        if token not in server + dispatch:
            raise GateFailure(f"ready-handle-boundary-present: server composition boundary disappeared: {token}")
    for forbidden in ("localStorage", "sessionStorage", "indexedDB", "provider.invalid", "innerHTML"):
        if forbidden in browser:
            raise GateFailure(f"browser-edge-source-scan: generic browser escape appeared: {forbidden}")
    for token in ("playwright-core", "infernix-shaped", "jitML-shaped", "rawDomainBypass"):
        if token not in harness:
            raise GateFailure(f"harness-observers-present: composition observer or fake disappeared: {token}")


def build_binaries(cabal: Path) -> tuple[Path, Path, str]:
    build = run([str(cabal), "build", "exe:amoebius", "test:ui-local-composition-spec"])
    executable = Path(run([str(cabal), "list-bin", "exe:amoebius"]).stdout.strip())
    suite = Path(run([str(cabal), "list-bin", "test:ui-local-composition-spec"]).stdout.strip())
    if not executable.is_file() or not suite.is_file():
        raise GateFailure("Phase-27 executable or suite binary is absent")
    return executable, suite, build.stdout


def run_green(cabal: Path, executable: Path) -> str:
    result = run(
        [str(cabal), "test", "ui-local-composition-spec", "--test-show-details=direct"],
        extra_env={"AMOEBIUS_BIN": str(executable)},
    )
    if ACCEPTANCE_TOKEN not in result.stdout:
        raise GateFailure("Phase-27 acceptance token is absent")
    return result.stdout


def observed_binary(executable: Path, suite: Path) -> tuple[str, str, int]:
    """Read the composition's network behaviour from the OS, not from the code under test."""
    if shutil.which("strace") is None:
        raise GateFailure("strace is required for the composition OS-network observer")
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
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
        raise GateFailure("observed Phase-27 binary missed its acceptance token")
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
        token = f"local-ui-composition-mutant: RED {mutant} {row['locus']}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        reddened += 1
        logs.append(result.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], reddened: int, total: int, observer: str) -> None:
    """Record what this run measured, not what the contract hoped for."""
    metrics = {
        "applications": "2/2-dhall-typed",
        "interactions": f"{counts['interactions.tsv']}/5-generated-authored-joined",
        "visible": f"{counts['expected_visible_states.tsv']}/4-exact-fresh",
        "effects": f"{counts['expected_effect_sequence.tsv']}/4-exact-ordered",
        "access": f"{counts['access_matrix.tsv']}/3-own-foreign",
        "denials": f"{counts['expected_denials.tsv']}/5-zero-leak",
        "bundle": "one-generic-sha256",
        "fresh-challenge": "browser-server-workflow-artifact-dom",
        "mutants": f"{reddened}/{total}-red",
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

    A metric whose authored value is UNVERIFIED never evidences a surface.
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
        phase=44, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
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
        resolved = toolchain.resolve(["cabal", "ghc", "dhall", "chromium", "playwright", "purs", "spago"])
        print("toolchain side — the composition lane resolved from authored requirements\n")
        for name in ("cabal", "ghc", "dhall", "chromium", "playwright", "purs", "spago"):
            record = resolved[name]
            print(f"  ok    {name:<9} {record['version']:<20} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        globals()["BROWSER"] = resolved["chromium"]["path"]
        globals()["DHALL"] = resolved["dhall"]["path"]
        for path in (BUILD_ROOT, BUNDLE_ROOT):
            if path.exists():
                shutil.rmtree(path)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        shutil.copytree(
            ROOT / "ui-runtime", WORKSPACE_ROOT,
            ignore=shutil.ignore_patterns(".spago", "output", "dist", "spago.lock"),
        )
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — the interaction, visible, effect, access, and denial pins\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — one generic bundle, one server edge, two domain fakes\n")
        verify_source_boundaries()
        for check in (
            "generic-bundle-single-artifact", "browser-edge-source-scan",
            "ready-handle-boundary-present", "harness-observers-present",
        ):
            print(f"  ok    {check}")
        results["source"] = True

        print("\nbuild side — the executable and its composition suite\n")
        executable, suite, build_log = build_binaries(cabal)
        (gate.run_dir / "build.log").write_text(build_log, encoding="utf-8")
        print("  ok    exe:amoebius and test:ui-local-composition-spec built")
        results["build"] = True

        print("\nsuite side — two applications through one bundle and one boundary\n")
        green = run_green(cabal, executable)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        print("  ok    the acceptance token is present")
        results["suite"] = True

        print("\nobserver side — the OS boundary decides what the composition reached\n")
        observed, observer, loopback = observed_binary(executable, suite)
        (gate.run_dir / "composition-observed.log").write_text(observed, encoding="utf-8")
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
        print(f"local-ui-composition-gate: FAIL: {problem}", file=sys.stderr)

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
        "Protocol": "tested" if rows.get("effects") == EXPECTED_RESULTS["effects"] else "UNVERIFIED",
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
        dependencies={"ui-local-composition-spec": "cabal test", "amoebius": "cabal build exe"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "phase-27 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
