#!/usr/bin/env python3
"""Build, observe, mutate, and seal the encrypted browser offline runtime."""

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
import mutant_registry
import toolchain


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "test/golden/browser/encrypted_browser_runtime"
LOCUS = ROOT / "test/oracle/encrypted_browser_runtime/validation_locus.tsv"
CALCULUS = ROOT / "test/oracle/encrypted_browser_runtime/calculus_projection.tsv"
EXPECTATIONS = ROOT / "test/oracle/encrypted_browser_runtime_surfaces.tsv"
RESULTS = ROOT / ".build/dsl/encrypted-browser-runtime/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/encrypted-browser-runtime/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/encrypted-browser-runtime"
BUNDLE_ROOT = ROOT / ".build/ui/encrypted-browser-runtime"
WORKSPACE_ROOT = BUNDLE_ROOT / "workspace"
TEMP_ROOT = ROOT / ".build/tmp/encrypted-browser-runtime"
CONTRACT = "DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md"
GATE_COMMAND = "python3 tools/encrypted_browser_runtime_gate.py"
MUTANT_CAPABILITY = "encrypted_browser_runtime"

COMPILER = ""
BROWSER = ""

FLAGS = (
    "encrypted-browser-runtime-store-plaintext-mutant",
    "encrypted-browser-runtime-retain-credentials-mutant",
    "encrypted-browser-runtime-two-replay-leaders-mutant",
    "encrypted-browser-runtime-omit-fencing-mutant",
    "encrypted-browser-runtime-silent-dependency-eviction-mutant",
    "encrypted-browser-runtime-reuse-partition-key-mutant",
)

CHECKS = {
    "production-offline-module-graph": "all five browser facilities enter the production PureScript graph",
    "bundle-runtime-token-set": "the built generic bundle carries the closed offline capability set",
    "real-webcrypto-source": "the production runtime uses PBKDF2 and AES-GCM through WebCrypto",
    "unsupported-coordination-refusal": "missing coordination primitives refuse concurrent ownership",
    "semantic-oracles-complete": "five fixture tables, custody, calculus, locus, and mutants are exact",
    "totality-options": "the Haskell reference suite retains the project totality warnings",
    "credential-environment-scrub": "ambient provider and cluster credentials are absent",
    "emitted-results-untracked": "generated measurements remain under ignored build roots",
    "toolchain-satisfies-requirements": "resolved Haskell, PureScript, and Chrome tools meet authored ranges",
    "recorded-results-match-oracle": "every emitted metric equals its authored expectation",
}

SIDES = ("toolchain", "oracle", "source", "build", "suite", "browser", "mutant", "results")

EXPECTED_RESULTS = {
    "actions": "14/14-exact",
    "storage": "3/3-ciphertext-and-prohibition",
    "assets": "2/2-public-immutable",
    "quota": "3/3-explicit",
    "partitions": "3/3-own-foreign",
    "browser-assertions": "12/12-real-chrome",
    "fresh-canary": "second-process-ciphertext-recovery",
    "production-bundle": "purescript+ffi-linked",
    "service-worker": "immutable-cache-observed",
    "mutants": "6/6-red",
    "network-observer": "loopback-only",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "2,3,25,14,6",
    "calculus-resource-vector": "5,50,0,0",
    "server-replay": "UNVERIFIED",
    "live-multizone": "UNVERIFIED",
}

SURFACE_METRIC = {
    **{name: "actions" for name in (
        "action-trace", "derive-partition", "local-unlock", "queue-encrypted", "raw-ciphertext",
        "restart", "recover", "claim-tab-a", "refuse-tab-b", "release-tab-a", "claim-tab-b",
        "upgrade-assets", "switch-partition", "quota-refusal",
    )},
    **{name: "storage" for name in ("storage-records", "storage-metadata", "storage-prohibited")},
    **{name: "assets" for name in ("asset-app", "asset-runtime")},
    **{name: "quota" for name in ("quota-within", "quota-independent", "quota-depended")},
    **{name: "partitions" for name in ("partition-own", "partition-subject", "partition-tenant")},
    **{name: "browser-assertions" for name in (
        "webcrypto", "indexeddb", "browser-restart", "raw-observer", "web-locks", "broadcast",
        "service-worker", "coordination-unsupported",
    )},
    **{name: "mutants" for name in (
        "store-plaintext-mutant", "retain-credentials-mutant", "two-replay-leaders-mutant",
        "omit-fencing-mutant", "silent-dependency-eviction-mutant", "reuse-partition-key-mutant",
    )},
    "server-replay": "server-replay",
    "live-multizone": "live-multizone",
}

CHECK_SIDE = {
    "production-offline-module-graph": "source",
    "bundle-runtime-token-set": "build",
    "real-webcrypto-source": "source",
    "unsupported-coordination-refusal": "source",
    "semantic-oracles-complete": "oracle",
    "totality-options": "source",
    "credential-environment-scrub": "source",
    "emitted-results-untracked": "results",
    "toolchain-satisfies-requirements": "toolchain",
    "recorded-results-match-oracle": "results",
}

ACCEPTANCE_TOKEN = (
    "offline-browser-runtime-spec: PASS "
    "(14 actions, 3 storage rows, 2 assets, 3 quota rows, 3 partition rows, 6 mutants)"
)
CALCULUS_TOKEN = "offline-browser-runtime-calculus: PASS (5 kinds, 50 projected units)"
BROWSER_TOKEN = "encrypted-browser-runtime-browser: PASS"


class GateFailure(RuntimeError):
    pass


def environment(extra: dict[str, str] | None = None) -> dict[str, str]:
    value = toolchain.contained_env()
    inherited = value.get("PATH", "/usr/bin:/bin")
    value["PATH"] = f"{ROOT / '.build/node_modules/.bin'}:{ROOT / 'tools'}:{inherited}"
    value["AMOEBIUS_TEST_TMP"] = str(TEMP_ROOT)
    if COMPILER:
        value["AMOEBIUS_GHC"] = COMPILER
    if BROWSER:
        value["AMOEBIUS_CHROMIUM"] = BROWSER
    for name in list(value):
        if name in {"KUBECONFIG", "GOOGLE_APPLICATION_CREDENTIALS"} or name.startswith(
            ("AWS_", "AZURE_", "VAULT_", "KUBE_")
        ):
            value.pop(name, None)
    if extra:
        value.update(extra)
    return value


def run(
    command: list[str], *, require_success: bool = True, cwd: Path = ROOT,
    extra_env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1", *command[1:],
        ]
    result = subprocess.run(
        command, cwd=cwd, env=environment(extra_env), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_oracles() -> tuple[list[dict[str, str]], dict[str, int]]:
    action = json.loads((FIXTURES / "action_trace.json").read_text(encoding="utf-8"))
    if action.get("expected") != "PASS" or len(action.get("actions", [])) != 14:
        raise GateFailure("the authored action trace must retain fourteen PASS actions")
    expected = {
        "storage_inventory.tbl": 3,
        "asset_manifest.tbl": 2,
        "quota_outcomes.tbl": 3,
        "partition_access.tbl": 3,
    }
    counts = {"actions": len(action["actions"])}
    for name, wanted in expected.items():
        actual = len((FIXTURES / name).read_text(encoding="utf-8").splitlines()) - 1
        if actual != wanted:
            raise GateFailure(f"{name} must retain {wanted} rows, got {actual}")
        counts[name] = actual
    calculus = read_tsv(CALCULUS)
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "production-offline-artifacts,closed-offline-budget,browser-offline-corpus,fenced-tab-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "2,3,25,14,6"},
        {"metric": "resource-vector", "value": "5,50,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("encrypted-browser-runtime five-calculus projection drifted")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 6 or {row["flag"] for row in mutants} != set(FLAGS):
        raise GateFailure("Phase-45 mutant registry must contain the six exact build flags")
    if any(not row.get("expected_red_locus") for row in mutants):
        raise GateFailure("each Phase-45 mutant must name its distinct red locus")
    if any(not (ROOT / row["body"]).is_file() for row in mutants):
        raise GateFailure("a Phase-45 mutant descriptor body is absent")
    locus = read_tsv(LOCUS)
    if len(locus) != 41 or len({row["entry"] for row in locus}) != 41:
        raise GateFailure("Phase-45 validation locus must contain forty-one unique rows")
    custody = [row for row in read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv") if row["# phase"] == "28"]
    if len(custody) != 11:
        raise GateFailure("Phase-0 manifest must pin eleven Phase-45 artifacts under custody phase 28")
    missing = [row["path"] for row in custody if not (ROOT / row["path"]).is_file()]
    if missing:
        raise GateFailure(f"Phase-45 preimplementation artifacts are absent: {missing}")
    descriptors = {row["expected gate locus"] for row in custody if row["kind"] == "mutant"}
    wanted_descriptors = {f"gate-red:phase_28_{Path(row['body']).name}" for row in mutants}
    if descriptors != wanted_descriptors:
        raise GateFailure("Phase-45 mutant custody descriptors do not name custody phase 28 exactly")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 2 production browser runtime; server replay and live multi-zone remain UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    return mutants, counts


def item_classes() -> dict[str, str]:
    classes = {row["entry"]: row["locus"] for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"]] = "mutant"
    return classes


def verify_source_boundaries() -> None:
    runtime_purs = (ROOT / "ui/src/Amoebius/Ui/Offline/Runtime.purs").read_text(encoding="utf-8")
    runtime_js = (ROOT / "ui/src/Amoebius/Ui/Offline/Runtime.js").read_text(encoding="utf-8")
    main_purs = (ROOT / "ui/src/Main.purs").read_text(encoding="utf-8")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for module in ("Crypto", "Leader", "Partition", "ServiceWorker", "Store"):
        if f"Amoebius.Ui.Offline.{module}" not in runtime_purs:
            raise GateFailure(f"production-offline-module-graph: {module} is outside the runtime graph")
    if "installOfflineRuntime offlineCapabilities" not in main_purs:
        raise GateFailure("production-offline-module-graph: the generic Main does not install the runtime")
    for token in ("crypto.subtle", "PBKDF2", "AES-GCM", "indexedDB", "navigator.locks", "BroadcastChannel", "serviceWorker"):
        if token not in runtime_js:
            raise GateFailure(f"real-webcrypto-source: production facility disappeared: {token}")
    if "CoordinationUnsupported: concurrent offline ownership refused" not in runtime_js:
        raise GateFailure("unsupported-coordination-refusal: safe refusal disappeared")
    stanza = cabal.split("test-suite offline-browser-runtime-spec", 1)[1].split("\ntest-suite ", 1)[0]
    for component in (
        "artifact-calculus", "budget-calculus", "calculus-composition", "capacity-topology",
        "evidence-calculus", "lift-calculus", "scope-index", "workflow-calculus",
    ):
        if f"amoebius:{component}" not in stanza:
            raise GateFailure(f"semantic-oracles-complete: suite lacks {component}")
    for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
        if option not in stanza:
            raise GateFailure(f"totality-options: offline suite lacks {option}")
    for flag in FLAGS:
        macro = flag.upper().replace("-", "_")
        if f"-D{macro}" not in cabal:
            raise GateFailure(f"semantic-oracles-complete: {flag} does not select its production CPP arm")
    leaked = [name for name in environment() if name in {"KUBECONFIG", "GOOGLE_APPLICATION_CREDENTIALS"}
              or name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_"))]
    if leaked:
        raise GateFailure(f"credential-environment-scrub: ambient credentials survived: {leaked}")


def build_outputs(cabal: Path) -> tuple[Path, str]:
    built = run([str(cabal), "build", "test:offline-browser-runtime-spec"])
    command = [
        "node", str(ROOT / ".build/node_modules/spago/bin/bundle.js"),
        "bundle", "--platform", "browser", "--bundle-type", "app", "--module", "Main",
        "--output", str(BUNDLE_ROOT / "output"), "--outfile", str(BUNDLE_ROOT / "ui.js"), "--strict",
    ]
    bundled = run(command, cwd=WORKSPACE_ROOT)
    bundle = BUNDLE_ROOT / "ui.js"
    if not bundle.is_file() or "Bundle succeeded" not in bundled.stdout:
        raise GateFailure("production PureScript bundle was not emitted")
    body = bundle.read_text(encoding="utf-8")
    for token in ("webcrypto-aes-gcm", "indexeddb-ciphertext", "web-lock-fencing", "CoordinationUnsupported"):
        if token not in body:
            raise GateFailure(f"bundle-runtime-token-set: built bundle lacks {token}")
    return bundle, built.stdout + "\n" + bundled.stdout


def configuration(enabled: str | None = None) -> list[str]:
    return [("-f" if flag == enabled else "-f-") + flag for flag in FLAGS]


def run_green(cabal: Path) -> str:
    result = run([
        str(cabal), "test", "offline-browser-runtime-spec", *configuration(), "--test-show-details=direct",
    ])
    if ACCEPTANCE_TOKEN not in result.stdout or CALCULUS_TOKEN not in result.stdout:
        raise GateFailure("Phase-45 acceptance or calculus token is absent")
    return result.stdout


def observe_browser(bundle: Path, output: Path) -> tuple[str, dict[str, Any], str, int]:
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable, str(ROOT / "tools/encrypted_browser_runtime_live.py"),
        "--browser", BROWSER, "--bundle", str(bundle), "--output", str(output),
    ]
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if sys.platform == "darwin" and shutil.which("sandbox-exec"):
            profile = (
                '(version 1) (allow default) '
                '(deny network-outbound (remote ip "*:*")) '
                '(allow network-outbound (remote ip "localhost:*"))'
            )
            control = run([
                "sandbox-exec", "-p", profile, sys.executable, "-c",
                "import socket,sys\n"
                "server=socket.socket();server.bind(('127.0.0.1',0));server.listen()\n"
                "client=socket.create_connection(server.getsockname());peer,_=server.accept()\n"
                "client.send(b'x');assert peer.recv(1)==b'x'\n"
                "external=socket.socket();external.settimeout(1)\n"
                "try: external.connect(('1.1.1.1',80))\n"
                "except PermissionError: sys.exit(0)\n"
                "except OSError: sys.exit(3)\n"
                "sys.exit(4)\n",
            ], require_success=False)
            if control.returncode != 0:
                raise GateFailure(f"Darwin loopback-only control exited {control.returncode}: {control.stdout}")
            result = run(["sandbox-exec", "-p", profile, *command])
            observations = 1
        else:
            if shutil.which("strace") is None:
                raise GateFailure("neither Darwin sandbox-exec nor strace is available as an OS network observer")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=connect,sendto", "-e", "status=successful,failed",
                "-e", "signal=none", "-o", str(trace), *command,
            ])
            forbidden = []
            loopback = []
            for line in trace.read_text(encoding="utf-8").splitlines():
                if "AF_INET" not in line and "AF_INET6" not in line:
                    continue
                if any(allowed in line for allowed in (
                    'inet_addr("127.', 'inet_pton(AF_INET6, "::1"', "sin_addr=htonl(INADDR_LOOPBACK)",
                )):
                    loopback.append(line)
                elif " = -1 ENETUNREACH " not in line:
                    forbidden.append(line)
            if forbidden:
                raise GateFailure("offline runtime used a non-loopback address:\n" + "\n".join(forbidden[:30]))
            if len(loopback) < 5:
                raise GateFailure("OS observer did not see the Chrome/storage boundary")
            observations = len(loopback)
    if BROWSER_TOKEN not in result.stdout or not output.is_file():
        raise GateFailure("real-Chrome production-bundle observation is absent")
    observed = json.loads(output.read_text(encoding="utf-8"))
    assertions = observed.get("assertions", {})
    if len(assertions) != 12 or not all(assertions.values()):
        raise GateFailure("the real-Chrome assertion battery is incomplete or red")
    return result.stdout, observed, "loopback-only", observations


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs = []
    reddened = 0
    for row in mutants:
        flag = row["flag"]
        result = run([
            str(cabal), "test", "offline-browser-runtime-spec", *configuration(flag),
            "--test-show-details=direct",
        ], require_success=False)
        locus = row["expected_red_locus"]
        if result.returncode == 0 or locus not in result.stdout:
            raise GateFailure(f"mutant survived or missed its distinct red locus: {row['mutant']}\n{result.stdout}")
        logs.append(f"encrypted-browser-runtime-mutant: RED {row['mutant']} {locus}\n{result.stdout}")
        reddened += 1
    restored = run_green(cabal)
    logs.append("encrypted-browser-runtime-mutant: restored PASS\n" + restored)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], browser_assertions: int, reddened: int, observer: str) -> None:
    metrics = {
        "actions": f"{counts['actions']}/14-exact",
        "storage": f"{counts['storage_inventory.tbl']}/3-ciphertext-and-prohibition",
        "assets": f"{counts['asset_manifest.tbl']}/2-public-immutable",
        "quota": f"{counts['quota_outcomes.tbl']}/3-explicit",
        "partitions": f"{counts['partition_access.tbl']}/3-own-foreign",
        "browser-assertions": f"{browser_assertions}/12-real-chrome",
        "fresh-canary": "second-process-ciphertext-recovery",
        "production-bundle": "purescript+ffi-linked",
        "service-worker": "immutable-cache-observed",
        "mutants": f"{reddened}/6-red",
        "network-observer": observer,
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "2,3,25,14,6",
        "calculus-resource-vector": "5,50,0,0",
        "server-replay": "UNVERIFIED",
        "live-multizone": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")


def surface_decisions(expected_rows, rows, classes, results):
    status = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            metric = SURFACE_METRIC.get(surface)
            status[surface] = (
                all(item in classes for item in ids) and metric is not None
                and EXPECTED_RESULTS.get(metric) != "UNVERIFIED"
                and rows.get(metric) == EXPECTED_RESULTS[metric]
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=45, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="2", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    classes: dict[str, str] = {}
    reddened = 0
    observer = "unrun"
    observed: dict[str, Any] = {}

    try:
        resolved = toolchain.resolve(["cabal", "ghc", "purs", "spago", "chromium"])
        print("toolchain side — the browser runtime lane resolved from authored requirements\n")
        for name in ("cabal", "ghc", "purs", "spago", "chromium"):
            record = resolved[name]
            print(f"  ok    {name:<9} {record['version']:<20} satisfies {record['requirement']}")
        globals()["COMPILER"] = resolved["ghc"]["path"]
        globals()["BROWSER"] = resolved["chromium"]["path"]
        results["toolchain"] = True
        for path in (BUILD_ROOT, BUNDLE_ROOT):
            if path.exists():
                shutil.rmtree(path)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        shutil.copytree(
            ROOT / "ui", WORKSPACE_ROOT,
            ignore=shutil.ignore_patterns(".spago", "output", "dist", "spago.lock"),
        )
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — action, storage, assets, quota, partitions, calculus, and mutants\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print("  ok    semantic-oracles-complete")
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the production PureScript graph owns the closed browser facilities\n")
        verify_source_boundaries()
        for check in (
            "production-offline-module-graph", "real-webcrypto-source", "unsupported-coordination-refusal",
            "totality-options", "credential-environment-scrub",
        ):
            print(f"  ok    {check}")
        results["source"] = True

        print("\nbuild side — Haskell reference and production PureScript bundle\n")
        bundle, build_log = build_outputs(cabal)
        (gate.run_dir / "build.log").write_text(build_log, encoding="utf-8")
        print("  ok    offline-browser-runtime-spec built")
        print("  ok    bundle-runtime-token-set")
        results["build"] = True

        print("\nsuite side — reference model, independent fixtures, and real calculus\n")
        suite_log = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(suite_log, encoding="utf-8")
        print("  ok    acceptance and calculus tokens are present")
        results["suite"] = True

        print("\nbrowser side — two Chrome processes inspect one contained profile\n")
        browser_log, observed, observer, network_count = observe_browser(bundle, gate.run_dir / "browser.json")
        (gate.run_dir / "browser.log").write_text(browser_log, encoding="utf-8")
        print(f"  ok    12/12 real-browser assertions; {network_count} OS-boundary observation(s)")
        results["browser"] = True

        print("\nmutant side — six production reference defects red at distinct loci\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/6 mutants reddened and clean configuration restored")
        results["mutant"] = True

        write_results(counts, len(observed["assertions"]), reddened, observer)
        rows = gate_common.metric_rows(RESULTS)
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent, BUNDLE_ROOT], (".tsv", ".js", ".log"), gate.run_dir,
            check="emitted-results-untracked", label="offline runtime output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"encrypted-browser-runtime-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids and EXPECTED_RESULTS.get(ids[0], "UNVERIFIED") != "UNVERIFIED"
        else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "tested" if rows.get("partitions") == EXPECTED_RESULTS["partitions"] else "UNVERIFIED",
        "Protocol": "tested" if rows.get("actions") == EXPECTED_RESULTS["actions"] else "UNVERIFIED",
        # Register 2 validates the real browser boundary against controlled local facilities.
        # The ledger's Runtime layer remains reserved for a Register-3 live deployment.
        "Runtime": "UNVERIFIED",
    }
    observations = {}
    if RESULTS.is_file():
        observations["results"] = "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))
    if (gate.run_dir / "browser.json").is_file():
        observations["browser"] = "sha256:" + gate_common.artifact_policy.digest(str(gate.run_dir / "browser.json"))
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(classes)},
        rows=rows, evidence=evidence, layers=layers,
        toolchain={name: {"version": record["version"], "requirement": record["requirement"]}
                   for name, record in resolved.items() if name != "platform"},
        dependencies={"offline-browser-runtime-spec": "cabal test", "amoebius-ui-runtime": "spago bundle"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "phase-45 mutants", "status": "unrun"}],
        observations=observations,
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
