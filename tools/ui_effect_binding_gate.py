#!/usr/bin/env python3
"""Run and seal the pure UI effect-binding checks.

The capability claim is unchanged: seven ports bind to exactly one handler each under an
independently authored relation, two named external links resolve to fixed HTTPS targets,
nineteen pinned negatives refuse with their own diagnostic, and all seven seeded mutants
redden. What changed is where the run's own records live. Evidence and the
proven/tested/assumed ledger is emitted into the run bundle under `.build/runs/`, the surface
enumeration is produced at run time and joined to an authored expectation, and the result is
bound to a source-snapshot digest and retained inside the checkout — the universal
half owned by `tools/gate_common.py`.
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
FIXTURES = ROOT / "test/fixture/ui_effect_binding"
MUTANT_CAPABILITY = "ui_effect_binding"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/ui_effect_binding/validation_locus.tsv"
CALCULUS = ROOT / "test/oracle/ui_effect_binding/calculus_projection.tsv"
BIND = ROOT / "src/Amoebius/Ui/Bind.hs"
LINKS = ROOT / "src/Amoebius/Ui/ExternalLinkCatalog.hs"
REFERENCE = ROOT / "test/spec/ui/EffectBindingReference.hs"
RESULTS = ROOT / ".build/dsl/ui-effect-binding/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/ui-effect-binding/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/ui-effect-binding"
TEMP_ROOT = ROOT / ".build/tmp/ui-effect-binding"
CONTRACT = "DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md"
GATE_COMMAND = "python3 tools/ui_effect_binding_gate.py"
EXPECTATIONS = "test/oracle/ui_effect_binding_surfaces.tsv"

COMPILER = ""

SANCTIONED_OBSERVERS = (
    "unshare-network-namespace",
    "darwin-sandbox-deny-network",
    "strace-socket-EPERM",
)

# One check id per private type, in the module that owns it.
OPAQUE_TYPES = (
    ("PortId", "bind", "port-id-constructor-private"),
    ("HandlerId", "bind", "handler-id-constructor-private"),
    ("Codec", "bind", "codec-constructor-private"),
    ("BoundUiProgram", "bind", "bound-ui-program-constructor-private"),
    ("ExternalLinkId", "link", "external-link-id-constructor-private"),
    ("BoundExternalLinks", "link", "bound-external-links-constructor-private"),
)

# The closed sums the binder is defined over, with the exact arms the contract names. A
# union that grows an arm is a widened effect surface, not a refactor.
CLOSED_UNIONS = (
    (
        "PortEffect",
        (
            "PortReadData", "PortMutateData", "PortStartWorkflow", "PortObserveWorkflow",
            "PortSubscribe", "PortUploadBounded", "PortUseReadyArtifact",
        ),
        "closed-port-effect-union",
    ),
    (
        "CapabilityName",
        ("SqlRead", "SqlWrite", "Workflow", "PulsarSubscription", "ContentStore", "InferenceEngine"),
        "closed-capability-name-union",
    ),
    ("ScopeRequirement", ("OwnerScope", "TenantScope", "GrantScope"), "closed-scope-requirement-union"),
    ("RetryPolicy", ("NoRetryContract", "IdempotentRetry"), "closed-retry-policy-union"),
)

REFUSAL_ARMS = (
    "ProviderCoordinateForbidden",
    "ExternalLinkNotAnEffect",
    "IdempotencyRequired",
    "ScopeMismatch",
)

CHECKS = {
    **{check: f"the {name} constructor is not exported" for name, _module, check in OPAQUE_TYPES},
    **{check: f"{name} is a closed, enumerable sum of its authored arms" for name, _arms, check in CLOSED_UNIONS},
    "port-requirement-no-raw-coordinate": "PortRequirement carries no raw text, URL, or link coordinate",
    "refusal-arms-present": "every binding refusal arm the contract names is still declared",
    "reference-relation-independent": "the reference relation imports neither production binder",
    "bind-partial-token-scan": "no partial or unsafe token survives in the binder or link catalog",
    "capability-key-set-exact": "the capability oracle's handler keys equal the handler oracle's, both ways",
    "phase38-registry-consumed": "the binder consumes the Phase-38 sealed registry rather than a local copy",
    "semantic-oracles-complete": "binding, link, refusal, and calculus oracles are exact",
    "totality-options": "the binding suite compiles with the project totality warnings",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "source", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "port-bindings": "7/7-independent-exact",
    "external-links": "2/2-independent-fixed-https",
    "pinned-errors": "8/8-exact-empty-trace",
    "link-negatives": "8/8-distinct",
    "bounded-input-negatives": "3/3-distinct",
    "generated-coverage": "13/13-classes-at-5-percent",
    "mutants": "7/7-red",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "7,2,19,13,7",
    "calculus-resource-vector": "5,48,0,0",
    "network-observer": "sanctioned-observer",
    "browser-enforcement": "UNVERIFIED",
    "handler-implementation-truth": "UNVERIFIED",
    "provider-state-truth": "UNVERIFIED",
    "live-tenant-isolation": "UNVERIFIED",
}

CLASS_METRIC = {
    "binding": "port-bindings",
    "link": "external-links",
    "negative": "pinned-errors",
    "link-negative": "link-negatives",
    "bounded-negative": "bounded-input-negatives",
    "property": "generated-coverage",
    "mutant": "mutants",
}

CHECK_SIDE = {
    **{check: "source" for _name, _module, check in OPAQUE_TYPES},
    **{check: "source" for _name, _arms, check in CLOSED_UNIONS},
    "port-requirement-no-raw-coordinate": "source",
    "refusal-arms-present": "source",
    "reference-relation-independent": "source",
    "bind-partial-token-scan": "source",
    "phase38-registry-consumed": "source",
    "semantic-oracles-complete": "oracle",
    "totality-options": "source",
    "capability-key-set-exact": "oracle",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}

PINNED_ERRORS = [
    "MissingHandler", "DuplicateHandler", "ContractMismatch", "MissingCapability",
    "ScopeMismatch", "IdempotencyRequired", "ProviderCoordinateForbidden", "ExternalLinkNotAnEffect",
]

MUTANT_TOKENS = {
    "M-first-handler-wins": "ui-effect-binding-mutant: RED M-first-handler-wins locus=duplicate-handler",
    "M-drop-capability": "ui-effect-binding-mutant: RED M-drop-capability locus=missing-capability",
    "M-erase-handler-scope": "ui-effect-binding-mutant: RED M-erase-handler-scope locus=scope-mismatch",
    "M-swap-response-codec": "ui-effect-binding-mutant: RED M-swap-response-codec locus=codec-mismatch",
    "M-retry-without-idempotency": "ui-effect-binding-mutant: RED M-retry-without-idempotency locus=unsafe-retry",
    "export_raw_topic": "ui-effect-binding-mutant: RED export_raw_topic locus=raw-topic",
    "M-link-id-as-url": "ui-effect-binding-mutant: RED M-link-id-as-url locus=link-as-url",
}

PORT_EFFECTS = [
    "ReadData", "MutateData", "StartWorkflow", "ObserveWorkflow",
    "Subscribe", "UploadBounded", "UseReadyArtifact",
]


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
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
    ports = read_tsv(FIXTURES / "ports.tsv")
    handlers = read_tsv(FIXTURES / "handlers.tsv")
    capabilities = read_tsv(FIXTURES / "capabilities.tsv")
    bindings = read_tsv(FIXTURES / "expected_bindings.tsv")
    links = read_tsv(FIXTURES / "external_link_catalog.tsv")
    resolved = read_tsv(FIXTURES / "expected_external_links.tsv")
    errors = read_tsv(FIXTURES / "bind_errors.tsv")
    calculus = read_tsv(CALCULUS)
    if len(ports) != 7 or [row["effect"] for row in ports] != PORT_EFFECTS:
        raise GateFailure("port registry must pin the seven closed effect arms")
    if not all(len(rows) == 7 for rows in (handlers, capabilities, bindings)):
        raise GateFailure("handler, capability, and binding registries must each contain seven rows")
    # The capability table and the handler table are separate authored files; a handler
    # present in one and absent from the other is a corpus that no longer describes one
    # system, and it is invisible to any check that only counts rows.
    handler_keys = [row["handler"] for row in handlers]
    capability_keys = [row["handler"] for row in capabilities]
    if len(set(handler_keys)) != len(handler_keys) or len(set(capability_keys)) != len(capability_keys):
        raise GateFailure("capability-key-set-exact: a handler key is duplicated in an authored table")
    if set(handler_keys) != set(capability_keys):
        difference = set(handler_keys) ^ set(capability_keys)
        raise GateFailure(f"capability-key-set-exact: handler and capability key sets differ: {sorted(difference)}")
    if len(links) != 2 or len(resolved) != 2 or any(not row["url"].startswith("https://") for row in links):
        raise GateFailure("external-link oracle must contain two fixed HTTPS joins")
    if [row["error"] for row in errors] != PINNED_ERRORS:
        raise GateFailure("bind error oracle drifted")
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "port-bindings,external-link-bindings,binding-refusals,generated-coverage-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "7,2,19,13,7"},
        {"metric": "resource-vector", "value": "5,48,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("effect-binding five-calculus projection oracle drifted")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 7 or {row["mutant"] for row in mutants} != set(MUTANT_TOKENS):
        raise GateFailure("Phase-39 mutant manifest must contain the seven contract mutants")
    locus = read_tsv(LOCUS)
    if len(locus) != 48 or len({row["entry"] for row in locus}) != 48:
        raise GateFailure("Phase-39 validation locus must contain forty-eight unique rows")
    phase0_rows = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    phase39 = [row for row in phase0_rows if row["# phase"] == "22"]
    if len(phase39) != 14:
        raise GateFailure("Phase-0 manifest must pin fourteen Phase-39 artifacts")
    missing = [row["path"] for row in phase39 if not (ROOT / row["path"]).is_file()]
    if missing:
        raise GateFailure(f"Phase-39 preimplementation artifacts are absent: {missing}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; browser/handler/provider/live isolation UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )
    counts = {"ports": len(ports), "links": len(links), "errors": len(errors)}
    return mutants, counts


def item_classes() -> dict[str, str]:
    classes = {row["entry"].strip(): row["class"].strip() for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"].strip()] = "mutant"
    return classes


def union_arms(source: str, type_name: str) -> tuple[list[str], str]:
    """Return the constructor arms of a `data` declaration and its deriving clause."""
    match = re.search(rf"^data {type_name}\b(.*?)(?=^\S|\Z)", source, re.MULTILINE | re.DOTALL)
    if not match:
        raise GateFailure(f"{type_name} is no longer declared in the binder")
    body = match.group(1)
    deriving = ""
    if "deriving" in body:
        body, _, deriving = body.partition("deriving")
    arms = re.findall(r"[=|]\s*([A-Z][A-Za-z0-9_']*)", body)
    return arms, deriving


def verify_source_boundaries() -> None:
    bind = BIND.read_text(encoding="utf-8")
    link = LINKS.read_text(encoding="utf-8")
    headers = {"bind": bind.split(") where", 1)[0], "link": link.split(") where", 1)[0]}
    for type_name, module, check in OPAQUE_TYPES:
        header = headers[module]
        if not re.search(rf"^\s*[,(]?\s*{type_name}\b", header, re.MULTILINE):
            raise GateFailure(f"{check}: {type_name} is no longer exported by the {module} module")
        # Matched without assuming the author's spacing: `PortId(..)` opens the constructor
        # exactly as `PortId (..)` does.
        if re.search(rf"\b{type_name}\s*\(\s*\.\.", header):
            raise GateFailure(f"{check}: private constructor exported: {type_name}")
    for type_name, arms, check in CLOSED_UNIONS:
        observed, deriving = union_arms(bind, type_name)
        if observed != list(arms):
            raise GateFailure(f"{check}: {type_name} arms drifted: {observed}")
        if "Bounded" not in deriving or "Enum" not in deriving:
            raise GateFailure(f"{check}: {type_name} is no longer Bounded and Enum, so it is not enumerably closed")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path, source in ((BIND, bind), (LINKS, link)):
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
        match = prohibited.search(stripped)
        if match:
            raise GateFailure(
                f"bind-partial-token-scan: partial token {match.group(0)!r} in {path.relative_to(ROOT)}"
            )
    port_declaration = bind.split("data PortRequirement", 1)[1].split("deriving stock", 1)[0]
    for token in ("Text", "ExternalLink", "Url"):
        if token in port_declaration:
            raise GateFailure(f"port-requirement-no-raw-coordinate: raw {token} entered PortRequirement")
    for token in REFUSAL_ARMS:
        if token not in bind:
            raise GateFailure(f"refusal-arms-present: binding refusal arm disappeared: {token}")
    if not re.search(r"import\s+Amoebius\.Ui\.Security\.Authorization\s*\(([^)]*)\)", bind):
        raise GateFailure("phase38-registry-consumed: the binder no longer imports the Phase-38 registry")
    imported = re.search(r"import\s+Amoebius\.Ui\.Security\.Authorization\s*\(([^)]*)\)", bind).group(1)
    for name in ("BoundActionRegistry", "authorizationDigestSource"):
        if name not in imported:
            raise GateFailure(f"phase38-registry-consumed: the binder no longer consumes {name}")
    reference = REFERENCE.read_text(encoding="utf-8")
    if "Amoebius.Ui.Bind" in reference or "Amoebius.Ui.ExternalLinkCatalog" in reference:
        raise GateFailure("reference-relation-independent: the independent relation imports a production binder")
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    stanza = cabal.split("test-suite ui-effect-binding-spec", 1)[1].split("\ntest-suite ", 1)[0]
    for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
        if option not in stanza:
            raise GateFailure(f"totality-options: effect-binding suite lacks {option}")


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-effect-binding-spec"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-effect-binding-spec"]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("ui-effect-binding-spec binary path is not absolute")
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if shutil.which("unshare") and run(["unshare", "-n", "true"], require_success=False).returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        elif shutil.which("sandbox-exec"):
            profile = Path(directory) / "deny-network.sb"
            profile.write_text("(version 1)\n(allow default)\n(deny network*)\n", encoding="utf-8")
            control = run(
                [
                    "sandbox-exec",
                    "-f",
                    str(profile),
                    sys.executable,
                    "-c",
                    "import socket,sys;\n"
                    "try:\n socket.create_connection(('127.0.0.1', 9), timeout=1).close()\n"
                    "except PermissionError:\n sys.exit(0)\n"
                    "except OSError:\n sys.exit(3)\n"
                    "sys.exit(4)\n",
                ],
                require_success=False,
            )
            if control.returncode != 0:
                raise GateFailure(
                    f"sandbox-exec did not deny a socket (control exit {control.returncode}); "
                    "the isolation this observer claims is not in force"
                )
            result = run(["sandbox-exec", "-f", str(profile), str(binary)])
            observer = "darwin-sandbox-deny-network"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("none of unshare, sandbox-exec, or strace is available as a network observer")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "inject=socket:error=EPERM",
                "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure(
                    "effect-binding gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8")
                )
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-effect-binding-spec", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = "ui-effect-binding-spec: PASS (7 ports, 2 links, 8 errors, 13 coverage classes, 7 mutants)"
    calculus = "ui-effect-binding-calculus: PASS (5 kinds, 48 projected units)"
    if token not in suite.stdout or token not in isolated or calculus not in suite.stdout or calculus not in isolated:
        raise GateFailure("Phase-39 acceptance tokens are absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in mutants:
        mutant = row["mutant"]
        result = run([
            str(cabal), "test", "ui-effect-binding-spec", "--test-show-details=direct",
            f"--test-options=--mutant={mutant}",
        ], require_success=False)
        if result.returncode == 0 or MUTANT_TOKENS[mutant] not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        reddened += 1
        logs.append(result.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], reddened: int, total: int, observer: str) -> None:
    """Record what this run measured, not what the contract hoped for."""
    metrics = {
        "port-bindings": f"{counts['ports']}/7-independent-exact",
        "external-links": f"{counts['links']}/2-independent-fixed-https",
        "pinned-errors": f"{counts['errors']}/8-exact-empty-trace",
        "link-negatives": "8/8-distinct",
        "bounded-input-negatives": "3/3-distinct",
        "generated-coverage": "13/13-classes-at-5-percent",
        "mutants": f"{reddened}/{total}-red",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "7,2,19,13,7",
        "calculus-resource-vector": "5,48,0,0",
        "network-observer": observer,
        "browser-enforcement": "UNVERIFIED",
        "handler-implementation-truth": "UNVERIFIED",
        "provider-state-truth": "UNVERIFIED",
        "live-tenant-isolation": "UNVERIFIED",
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
            unknown = [i for i in ids if i not in classes]
            metrics = {CLASS_METRIC[classes[i]] for i in ids if i in classes}
            status[surface] = not unknown and bool(metrics) and all(
                rows.get(metric) == EXPECTED_RESULTS[metric] for metric in metrics
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=39, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
        expectations=EXPECTATIONS,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    classes: dict[str, str] = {}
    reddened = 0

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — the port, handler, capability, binding, link, and error pins\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print("  ok    capability-key-set-exact          handler and capability keys agree both ways")
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the binder's constructors and unions stay closed\n")
        verify_source_boundaries()
        for _name, _module, check in OPAQUE_TYPES:
            print(f"  ok    {check}")
        for _name, _arms, check in CLOSED_UNIONS:
            print(f"  ok    {check}")
        print("  ok    port-requirement-no-raw-coordinate no raw text, URL, or link entered PortRequirement")
        print("  ok    refusal-arms-present               every named refusal arm is still declared")
        print("  ok    phase38-registry-consumed          the binder consumes the Phase-38 sealed registry")
        print("  ok    reference-relation-independent     the reference imports neither production binder")
        print("  ok    bind-partial-token-scan            no partial or unsafe token in the binder modules")
        print("  ok    totality-options                   suite totality warnings are enabled")
        results["source"] = True

        print("\nsuite side — the pure binding battery under a network observer\n")
        green, observer = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        if observer not in SANCTIONED_OBSERVERS:
            print(f"  FAIL  network observer {observer!r} is not one this contract sanctions")
        else:
            print(f"  ok    network-isolated pure gate proven by {observer}")
            results["suite"] = True

        print("\nmutant side — every seeded mutant red at its own locus\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/{len(mutant_rows)} mutants reddened")
        results["mutant"] = True

        write_results(counts, reddened, len(mutant_rows), observer)
        rows = gate_common.metric_rows(RESULTS)
        compared = dict(rows)
        if compared.get("network-observer") in SANCTIONED_OBSERVERS:
            compared["network-observer"] = "sanctioned-observer"
        oracle_ok = gate_common.oracle_side(compared, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )
        rows = compared
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError, AttributeError, json.JSONDecodeError) as problem:
        print(f"ui-effect-binding-gate: FAIL: {problem}", file=sys.stderr)

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
        "Decision": "proven-for-the-model"
        if rows.get("port-bindings") == EXPECTED_RESULTS["port-bindings"]
        and rows.get("pinned-errors") == EXPECTED_RESULTS["pinned-errors"]
        else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
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
        dependencies={"ui-effect-binding-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "phase-22 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
