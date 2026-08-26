#!/usr/bin/env python3
"""Render, scan, mutate, and seal the generated browser contract recipes."""

from __future__ import annotations

import csv
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
import mutant_registry
import toolchain


ROOT = Path(__file__).resolve().parents[1]
ORACLE_ROOT = ROOT / "test/oracle/ui_contract_generation"
INVENTORY = ORACLE_ROOT / "contract_inventory.tsv"
SCANNER_RULES = ORACLE_ROOT / "scanner_rules.tsv"
LOCUS = ORACLE_ROOT / "validation_locus.tsv"
CALCULUS = ORACLE_ROOT / "calculus_projection.tsv"
EXPECTATIONS = ROOT / "test/oracle/ui_contract_generation_surfaces.tsv"
RESULTS = ROOT / ".build/dsl/ui-contract-generation/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/ui-contract-generation/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/ui-contract-generation"
RENDER_ROOT = ROOT / ".build/dsl/ui-contract-generation/renders"
BUNDLE_ROOT = ROOT / ".build/ui/ui-contract-generation"
WORKSPACE_ROOT = BUNDLE_ROOT / "workspace"
TEMP_ROOT = ROOT / ".build/tmp/ui-contract-generation"
CONTRACT = "DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md"
GATE_COMMAND = "python3 tools/ui_contract_generation_gate.py"
MUTANT_CAPABILITY = "ui_contract_generation"

COMPILER = ""

FLAGS = (
    "ui-contract-generation-raw-sink-mutant",
    "ui-contract-generation-serialize-server-handle-mutant",
    "ui-contract-generation-undeclared-codec-mutant",
)

ARTIFACTS = (
    "Amoebius/Ui/Generated/Contracts.purs",
    "Amoebius/Ui/Generated/Codecs.purs",
    "GeneratedBundleMain.purs",
)

CHECKS = {
    "checked-public-boundary": "the independent source projection equals the authored contract inventory",
    "generator-input-type-enumeration": "the generator enumerates the closed ValueType and excludes ServerHandle",
    "generated-only-output-root": "the renderer accepts its only output root from the caller",
    "generator-totality-options": "generator and suite retain totality warnings and contain no partial token",
    "contract-oracle-complete": "contract, scanner, calculus, locus, custody, and mutant inputs are exact",
    "artifact-scanner-independent": "a Python scanner independent of the Haskell renderer applies every rule",
    "two-render-byte-equality": "two clean renders have identical paths and bytes",
    "generic-bundle-content-address": "the generated ABI entry point compiles and its bytes are SHA-256 addressed",
    "mutant-registry-complete": "the registry selects the three production CPP mutations at exact loci",
    "network-isolated-reference": "the generated reference suite passes beneath a denied-network observer",
    "toolchain-satisfies-requirements": "resolved Haskell and PureScript tools meet authored requirements",
    "recorded-results-match-oracle": "every emitted metric equals its authored expectation",
    "emitted-results-untracked": "renders, bundle, logs, and measurements remain beneath ignored build roots",
}

SIDES = (
    "toolchain", "oracle", "source", "render", "scanner", "bundle", "mutant", "results"
)

EXPECTED_RESULTS = {
    "contracts": "16/16-independent-exact",
    "generated-recipes": "3/3-output-only",
    "renders": "2/2-byte-identical",
    "bundle": "1/1-ui-client-v1-content-addressed",
    "scanner": "6/6-forbidden-tokens-absent",
    "mutants": "3/3-red-at-independent-scanner",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "3,1,22,2,3",
    "calculus-resource-vector": "5,31,0,0",
    "network-observer": "sanctioned-observer",
}

CLASS_METRIC = {
    "contract": "contracts",
    "artifact": "generated-recipes",
    "render": "renders",
    "bundle": "bundle",
    "mutant": "mutants",
}

CHECK_SIDE = {
    "checked-public-boundary": "source",
    "generator-input-type-enumeration": "source",
    "generated-only-output-root": "source",
    "generator-totality-options": "source",
    "contract-oracle-complete": "oracle",
    "artifact-scanner-independent": "scanner",
    "two-render-byte-equality": "render",
    "generic-bundle-content-address": "bundle",
    "mutant-registry-complete": "oracle",
    "network-isolated-reference": "render",
    "toolchain-satisfies-requirements": "toolchain",
    "recorded-results-match-oracle": "results",
    "emitted-results-untracked": "results",
}

MUTANT_TOKEN = {
    "raw_sink": "rawHtml",
    "serialize_server_handle": "ServerHandle",
    "undeclared_codec": "providerCoordinate",
}

SANCTIONED_OBSERVERS = {
    "unshare-network-namespace",
    "darwin-sandbox-deny-network",
    "strace-socket-EPERM",
}

ACCEPTANCE_TOKEN = "ui-contract-generation-spec: PASS (16 contracts, 3 generated recipes, 3 mutants)"
CALCULUS_TOKEN = "ui-contract-generation-calculus: PASS (5 kinds, 31 projected units)"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    inherited = value.get("PATH", "/usr/bin:/bin")
    value["PATH"] = f"{ROOT / '.build/node_modules/.bin'}:{ROOT / 'tools'}:{inherited}"
    for name in list(value):
        if name in {"KUBECONFIG", "GOOGLE_APPLICATION_CREDENTIALS", "VAULT_ADDR", "VAULT_TOKEN"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(
    command: list[str], *, require_success: bool = True, cwd: Path = ROOT,
) -> subprocess.CompletedProcess[str]:
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0], f"--with-compiler={COMPILER}", f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1", *command[1:],
        ]
    result = subprocess.run(
        command, cwd=cwd, env=environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_oracles() -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    inventory = read_tsv(INVENTORY)
    if len(inventory) != 16 or len({(row["kind"], row["name"]) for row in inventory}) != 16:
        raise GateFailure("contract inventory must contain sixteen unique kind/name rows")
    if {row["visibility"] for row in inventory} != {"public"}:
        raise GateFailure("contract inventory may contain only public rows")
    rules = read_tsv(SCANNER_RULES)
    if len(rules) != 6 or len({row["token"] for row in rules}) != 6:
        raise GateFailure("scanner catalog must contain six unique forbidden tokens")
    calculus = read_tsv(CALCULUS)
    wanted_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "generated-browser-artifacts,closed-runtime-abi,browser-contract-inventory,deterministic-render-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "3,1,22,2,3"},
        {"metric": "resource-vector", "value": "5,31,0,0"},
    ]
    if calculus != wanted_calculus:
        raise GateFailure("UI contract five-calculus projection drifted")
    locus = read_tsv(LOCUS)
    if len(locus) != 27 or len({row["entry"] for row in locus}) != 27:
        raise GateFailure("UI contract validation locus must contain twenty-seven unique rows")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 3 or {row["flag"] for row in mutants} != set(FLAGS):
        raise GateFailure("UI contract mutant registry must contain the three exact flags")
    if any(not (ROOT / row["body"]).is_file() for row in mutants):
        raise GateFailure("a UI contract mutant descriptor is absent")
    custody = [
        row for row in read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
        if row["# phase"] == "29"
    ]
    if len(custody) != 5 or any(not (ROOT / row["path"]).is_file() for row in custody):
        raise GateFailure("Phase-0 custody must retain all five Phase-46 preimplementation artifacts")
    descriptors = {row["expected gate locus"] for row in custody if row["kind"] == "mutant"}
    wanted_descriptors = {f"gate-red:phase_29_{Path(row['body']).name}" for row in mutants}
    if descriptors != wanted_descriptors:
        raise GateFailure("Phase-46 mutant custody descriptors must name custody phase 29 exactly")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for flag in FLAGS:
        macro = flag.upper().replace("-", "_")
        if f"-D{macro}" not in cabal:
            raise GateFailure(f"mutant-registry-complete: {flag} has no production CPP arm")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 generated-contract decision; protocol and runtime remain UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    return inventory, rules, mutants


def item_classes() -> dict[str, str]:
    classes = {row["entry"]: row["locus"] for row in read_tsv(LOCUS)}
    normalized: dict[str, str] = {}
    for name, locus in classes.items():
        if locus.startswith("BrowserContracts.public") or locus.startswith("BrowserContracts.client") or locus.startswith("BrowserContracts.transition"):
            normalized[name] = "contract"
        elif locus.startswith("BrowserContracts.render"):
            normalized[name] = "artifact"
        elif locus.startswith("fresh-render") or locus == "independent-byte-comparison":
            normalized[name] = "render"
        elif locus in {"spago-bundle", "sha256-generated-bundle"}:
            normalized[name] = "bundle"
        elif name.startswith("mutant-"):
            normalized[name] = "mutant"
        else:
            raise GateFailure(f"unclassified validation locus: {name} -> {locus}")
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        normalized[row["mutant"]] = "mutant"
    return normalized


def source_boundary_rows() -> list[tuple[str, str]]:
    source = (ROOT / "src/Amoebius/Ui/Source.hs").read_text(encoding="utf-8")
    match = re.search(r"data ValueType\s*=\s*(.*?)\n\s*deriving stock", source, re.DOTALL)
    if not match:
        raise GateFailure("checked-public-boundary: ValueType declaration was not found")
    values = [part.strip() for part in re.split(r"\s*\|\s*", match.group(1))]
    public_values = [value for value in values if value != "ServerHandle"]
    if "ServerHandle" not in values or len(public_values) != 7:
        raise GateFailure("checked-public-boundary: ValueType must retain seven public values and one private handle")

    client = (ROOT / "src/Amoebius/Ui/Compile/ClientPlan.hs").read_text(encoding="utf-8")
    encode = client.split("encodeClientPlan plan = object", 1)
    if len(encode) != 2:
        raise GateFailure("checked-public-boundary: ClientPlan encoder was not found")
    encode_body = encode[1].split("\n\nclientActionPorts", 1)[0]
    client_fields = re.findall(r'\("([A-Za-z][A-Za-z0-9]*)",', encode_body)

    transition = (ROOT / "ui/src/Amoebius/Ui/Interpreter.purs").read_text(encoding="utf-8")
    type_split = transition.split("type Transition =", 1)
    if len(type_split) != 2:
        raise GateFailure("checked-public-boundary: Transition type was not found")
    transition_body = type_split[1].split("\n\ntransition ::", 1)[0]
    transition_fields = re.findall(r"(?:\{|,)\s*([A-Za-z][A-Za-z0-9]*)\s*::", transition_body)
    return (
        [("value", name) for name in public_values]
        + [("client-plan", name) for name in client_fields]
        + [("transition", name) for name in transition_fields]
    )


def verify_source_boundaries(inventory: list[dict[str, str]]) -> None:
    expected = [(row["kind"], row["name"]) for row in inventory]
    actual = source_boundary_rows()
    if actual != expected:
        raise GateFailure(f"checked-public-boundary: source projection {actual!r} != oracle {expected!r}")
    generator = (ROOT / "src/ui-contract-generation/Amoebius/Ui/Generate/BrowserContracts.hs").read_text(encoding="utf-8")
    suite = (ROOT / "test/spec/ui/UiContractGenerationSpec.hs").read_text(encoding="utf-8")
    if "[minBound .. maxBound]" not in generator or "filter (/= Source.ServerHandle)" not in generator:
        raise GateFailure("generator-input-type-enumeration: generator does not enumerate and close ValueType")
    if "writeBrowserArtifacts :: FilePath -> IO ()" not in generator or '".build/' in generator:
        raise GateFailure("generated-only-output-root: generator owns or hard-codes an output root")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for name, body in (("BrowserContracts.hs", generator), ("UiContractGenerationSpec.hs", suite)):
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", body))
        match = prohibited.search(stripped)
        if match:
            raise GateFailure(f"generator-totality-options: partial token {match.group(0)!r} in {name}")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    for component in ("library ui-contract-generation", "test-suite ui-contract-generation-spec"):
        stanza = cabal.split(component, 1)[1].split("\n\n", 1)[0]
        for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
            if option not in stanza:
                raise GateFailure(f"generator-totality-options: {component} lacks {option}")


def configuration(enabled: str | None = None) -> list[str]:
    return [("-f" if flag == enabled else "-f-") + flag for flag in FLAGS]


def build_binary(cabal: Path, enabled: str | None = None) -> Path:
    flags = configuration(enabled)
    run([str(cabal), "build", "test:ui-contract-generation-spec", *flags])
    binary = Path(run([str(cabal), "list-bin", "test:ui-contract-generation-spec", *flags]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("ui-contract-generation-spec binary path is not an absolute file")
    return binary


def render(binary: Path, output: Path, *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    if output.exists():
        shutil.rmtree(output)
    return run([str(binary), "--output", str(output)], require_success=require_success)


def artifact_bytes(root: Path) -> dict[str, bytes]:
    found = {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in sorted(root.rglob("*")) if path.is_file()
    }
    if set(found) != set(ARTIFACTS):
        raise GateFailure(f"generated artifact inventory drifted: {sorted(found)}")
    return found


def isolated_render(binary: Path, output: Path) -> tuple[str, str]:
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if shutil.which("unshare") and run(["unshare", "-n", "true"], require_success=False).returncode == 0:
            result = run(["unshare", "-n", str(binary), "--output", str(output)])
            observer = "unshare-network-namespace"
        elif shutil.which("sandbox-exec"):
            profile = Path(directory) / "deny-network.sb"
            profile.write_text("(version 1)\n(allow default)\n(deny network*)\n", encoding="utf-8")
            control = run([
                "sandbox-exec", "-f", str(profile), sys.executable, "-c",
                "import socket,sys\n"
                "try: socket.create_connection(('127.0.0.1',9),timeout=1).close()\n"
                "except PermissionError: sys.exit(0)\n"
                "except OSError: sys.exit(3)\n"
                "sys.exit(4)\n",
            ], require_success=False)
            if control.returncode != 0:
                raise GateFailure(f"sandbox-exec denial control exited {control.returncode}")
            result = run(["sandbox-exec", "-f", str(profile), str(binary), "--output", str(output)])
            observer = "darwin-sandbox-deny-network"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("no sanctioned denied-network observer is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "signal=none",
                "-e", "inject=socket:error=EPERM", "-o", str(trace),
                str(binary), "--output", str(output),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("generated reference attempted a network syscall")
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    binary = build_binary(cabal)
    first = render(binary, RENDER_ROOT / "render-a")
    second = render(binary, RENDER_ROOT / "render-b")
    first_bytes = artifact_bytes(RENDER_ROOT / "render-a")
    second_bytes = artifact_bytes(RENDER_ROOT / "render-b")
    if first_bytes != second_bytes:
        raise GateFailure("two-render-byte-equality: clean renders differ in path or bytes")
    isolated_output = RENDER_ROOT / "network-isolated"
    if isolated_output.exists():
        shutil.rmtree(isolated_output)
    isolated, observer = isolated_render(binary, isolated_output)
    artifact_bytes(isolated_output)
    combined = first.stdout + second.stdout + isolated
    if combined.count(ACCEPTANCE_TOKEN) != 3 or combined.count(CALCULUS_TOKEN) != 3:
        raise GateFailure("acceptance or calculus token is absent from one clean render")
    return combined, observer


def scan(paths: list[Path], rules: list[dict[str, str]]) -> list[tuple[str, str, Path]]:
    findings: list[tuple[str, str, Path]] = []
    for path in paths:
        body = path.read_text(encoding="utf-8", errors="replace")
        for rule in rules:
            if rule["token"] in body:
                findings.append((rule["token"], rule["reason"], path))
    return findings


def build_bundle(rules: list[dict[str, str]]) -> tuple[Path, str]:
    if WORKSPACE_ROOT.exists():
        shutil.rmtree(WORKSPACE_ROOT)
    shutil.copytree(
        ROOT / "ui", WORKSPACE_ROOT,
        ignore=shutil.ignore_patterns(".spago", "output", "dist", "spago.lock"),
    )
    shutil.copytree(RENDER_ROOT / "render-a", WORKSPACE_ROOT / "src", dirs_exist_ok=True)
    command = [
        "node", str(ROOT / ".build/node_modules/spago/bin/bundle.js"),
        "bundle", "--platform", "browser", "--bundle-type", "app",
        "--module", "GeneratedBundleMain", "--output", str(BUNDLE_ROOT / "output"),
        "--outfile", str(BUNDLE_ROOT / "ui.js"), "--strict",
    ]
    result = run(command, cwd=WORKSPACE_ROOT)
    bundle = BUNDLE_ROOT / "ui.js"
    if not bundle.is_file() or "Bundle succeeded" not in result.stdout:
        raise GateFailure("generic-bundle-content-address: Spago emitted no strict bundle")
    generated_paths = [RENDER_ROOT / "render-a" / relative for relative in ARTIFACTS]
    findings = scan([*generated_paths, bundle], rules)
    if findings:
        token, reason, path = findings[0]
        raise GateFailure(f"artifact-scanner-independent: {token} ({reason}) in {path}")
    body = bundle.read_text(encoding="utf-8")
    if "amoebius-generated-contracts:" not in body or "ui-client-v1" not in body:
        raise GateFailure("generic-bundle-content-address: generated ABI entry point is absent")
    digest = "sha256:" + gate_common.artifact_policy.digest(str(bundle))
    (BUNDLE_ROOT / "ui.address").write_text(digest + "\n", encoding="utf-8")
    return bundle, digest


def run_mutants(
    cabal: Path, mutants: list[dict[str, str]], rules: list[dict[str, str]],
) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in mutants:
        binary = build_binary(cabal, row["flag"])
        output = RENDER_ROOT / f"mutant-{row['mutant']}"
        result = render(binary, output, require_success=False)
        token = MUTANT_TOKEN[row["mutant"]]
        findings = scan([path for path in output.rglob("*") if path.is_file()], rules)
        matching = [finding for finding in findings if finding[0] == token]
        locus = row["expected_red_locus"]
        if result.returncode == 0 or locus not in result.stdout or not matching:
            raise GateFailure(
                f"mutant survived or missed its independent scanner locus: {row['mutant']}\n{result.stdout}"
            )
        logs.append(f"ui-contract-generation-mutant: RED {row['mutant']} {locus} token={token}\n{result.stdout}")
        reddened += 1
    restored = build_binary(cabal)
    restored_result = render(restored, RENDER_ROOT / "restored")
    if ACCEPTANCE_TOKEN not in restored_result.stdout or CALCULUS_TOKEN not in restored_result.stdout:
        raise GateFailure("clean UI contract configuration did not restore after mutants")
    logs.append("ui-contract-generation-mutant: restored PASS\n" + restored_result.stdout)
    return "\n".join(logs), reddened


def write_results(reddened: int, observer: str) -> None:
    metrics = {
        "contracts": "16/16-independent-exact",
        "generated-recipes": "3/3-output-only",
        "renders": "2/2-byte-identical",
        "bundle": "1/1-ui-client-v1-content-addressed",
        "scanner": "6/6-forbidden-tokens-absent",
        "mutants": f"{reddened}/3-red-at-independent-scanner",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "3,1,22,2,3",
        "calculus-resource-vector": "5,31,0,0",
        "network-observer": observer,
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]], rows: Mapping[str, str],
    classes: Mapping[str, str], results: Mapping[str, bool],
) -> dict[str, bool]:
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            unknown = [item for item in ids if item not in classes]
            metrics = {CLASS_METRIC[classes[item]] for item in ids if item in classes}
            status[surface] = not unknown and bool(metrics) and all(
                rows.get(metric) == EXPECTED_RESULTS[metric] for metric in metrics
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=46, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    classes: dict[str, str] = {}
    reddened = 0
    observer = "unrun"
    bundle_digest = ""

    try:
        resolved = toolchain.resolve(["cabal", "ghc", "purs", "spago"])
        print("toolchain side — generator and bundle tools resolved from authored requirements\n")
        for name in ("cabal", "ghc", "purs", "spago"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<16} satisfies {record['requirement']}")
        globals()["COMPILER"] = resolved["ghc"]["path"]
        results["toolchain"] = True
        for path in (BUILD_ROOT, RENDER_ROOT, BUNDLE_ROOT):
            if path.exists():
                shutil.rmtree(path)
        TEMP_ROOT.mkdir(parents=True, exist_ok=True)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — authored inventory, scanner, calculus, custody, and mutants\n")
        inventory, rules, mutant_rows = verify_oracles()
        classes = item_classes()
        print("  ok    contract-oracle-complete")
        print("  ok    mutant-registry-complete")
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the generator follows the independently parsed public boundary\n")
        verify_source_boundaries(inventory)
        print("  ok    checked-public-boundary")
        print("  ok    generator-input-type-enumeration")
        print("  ok    generated-only-output-root")
        print("  ok    generator-totality-options")
        results["source"] = True

        print("\nrender side — two clean renders and one denied-network execution\n")
        render_log, observer = run_green(cabal)
        (gate.run_dir / "render.log").write_text(render_log, encoding="utf-8")
        if observer not in SANCTIONED_OBSERVERS:
            raise GateFailure(f"network observer {observer!r} is not sanctioned")
        print("  ok    two-render-byte-equality")
        print(f"  ok    network-isolated-reference ({observer})")
        results["render"] = True

        print("\nscanner side — all forbidden tokens are absent from clean generated artifacts\n")
        clean_paths = [RENDER_ROOT / "render-a" / relative for relative in ARTIFACTS]
        findings = scan(clean_paths, rules)
        if findings:
            raise GateFailure(f"artifact-scanner-independent: clean render findings: {findings}")
        print(f"  ok    artifact-scanner-independent ({len(rules)} rules)")
        results["scanner"] = True

        print("\nbundle side — one generated ABI entry point, strictly bundled and content-addressed\n")
        bundle, bundle_digest = build_bundle(rules)
        (gate.run_dir / "bundle.log").write_text(
            f"bundle={bundle}\naddress={bundle_digest}\n", encoding="utf-8",
        )
        print(f"  ok    generic-bundle-content-address {bundle_digest[:23]}…")
        results["bundle"] = True

        print("\nmutant side — three generator defects red in the independent scanner\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows, rules)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/3 mutants reddened and the clean configuration restored")
        results["mutant"] = True

        write_results(reddened, observer)
        rows = gate_common.metric_rows(RESULTS)
        compared = dict(rows)
        if compared.get("network-observer") in SANCTIONED_OBSERVERS:
            compared["network-observer"] = "sanctioned-observer"
        oracle_ok = gate_common.oracle_side(compared, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent, RENDER_ROOT, BUNDLE_ROOT], (".tsv", ".purs", ".js", ".log", ".address"),
            gate.run_dir, check="emitted-results-untracked",
            label="generated contracts and bundle stay generated",
        )
        rows = compared
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError) as problem:
        print(f"ui-contract-generation-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "proven-for-the-model"
        if rows.get("contracts") == EXPECTED_RESULTS["contracts"]
        and rows.get("renders") == EXPECTED_RESULTS["renders"] else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    observations = {}
    if RESULTS.is_file():
        observations["results"] = "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))
    if bundle_digest:
        observations["generic-bundle"] = bundle_digest
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(classes)},
        rows=rows, evidence=evidence, layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items() if name != "platform"
        },
        dependencies={
            "ui-contract-generation-spec": "cabal build/list-bin",
            "amoebius-ui-generated-bundle": "spago bundle",
        },
        mutants=[
            {"name": row["mutant"], "status": "red" if reddened == len(mutant_rows) else "unrun"}
            for row in mutant_rows
        ] or [{"name": "phase-46 mutants", "status": "unrun"}],
        observations=observations,
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
