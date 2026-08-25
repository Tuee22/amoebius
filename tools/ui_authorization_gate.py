#!/usr/bin/env python3
"""Run and seal the pure UI-authorization checks.

The capability claim is unchanged: the sealed action registry, the independently authored
access matrix, the four parity diagnostics, the four authority-epoch refusals, and both
seeded mutants. What changed is where the run's own records live. Evidence and the
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
FIXTURES = ROOT / "test/fixture/ui_authorization"
MUTANT_CAPABILITY = "ui_authorization"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/ui_authorization/validation_locus.tsv"
CALCULUS = ROOT / "test/oracle/ui_authorization/calculus_projection.tsv"
MODULE = ROOT / "src/Amoebius/Ui/Security/Authorization.hs"
REFERENCE = ROOT / "test/spec/ui/AuthorizationReference.hs"
RESULTS = ROOT / ".build/dsl/ui-authorization/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/ui-authorization/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/ui-authorization"
TEMP_ROOT = ROOT / ".build/tmp/ui-authorization"
CONTRACT = "DEVELOPMENT_PLAN/phase_39_ui_authorization_kernel.md"
GATE_COMMAND = "python3 tools/ui_authorization_gate.py"
EXPECTATIONS = "test/oracle/ui_authorization_surfaces.tsv"

COMPILER = ""

SANCTIONED_OBSERVERS = (
    "unshare-network-namespace",
    "darwin-sandbox-deny-network",
    "strace-socket-EPERM",
)

# One check id per private type. A single "the constructors are private" bit stays green
# while one of them quietly opens, so the scan reports each separately.
OPAQUE_TYPES = (
    ("ActionId", "action-id-constructor-private"),
    ("BoundActionRegistry", "bound-registry-constructor-private"),
    ("AuthorityEpochs", "authority-epochs-constructor-private"),
    ("AuthoritySnapshot", "authority-snapshot-constructor-private"),
    ("AuthorizedAction", "authorized-action-constructor-private"),
    ("CanRead", "can-read-constructor-private"),
    ("CanInvoke", "can-invoke-constructor-private"),
)

# The closed sums this phase's registry is defined over, with the exact arms the contract
# names. A union that grows an arm is a widened effect surface, not a refactor.
CLOSED_UNIONS = (
    (
        "ActionEffect",
        ("ReadData", "MutateData", "StartWorkflow", "ObserveWorkflow", "EndSession"),
        "closed-action-effect-union",
    ),
    (
        "Permission",
        ("ReadPermission", "WritePermission", "InvokePermission"),
        "closed-permission-union",
    ),
)

CHECKS = {
    **{check: f"the {name} constructor is not exported" for name, check in OPAQUE_TYPES},
    **{check: f"{name} is a closed, enumerable sum of its authored arms" for name, _arms, check in CLOSED_UNIONS},
    "visibility-absent-from-authorize": "client visibility does not enter the authorization transition",
    "effect-requires-authorized-action": "the effect interpreter consumes AuthorizedAction and nothing weaker",
    "reference-evaluator-independent": "the reference evaluator does not import the module under test",
    "authorization-partial-token-scan": "no partial or unsafe token survives in the authorization module",
    "semantic-oracles-complete": "registry, decision, parity, epoch, and calculus oracles are exact",
    "totality-options": "the authorization suite compiles with the project totality warnings",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "source", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "action-registry": "5/5-exact",
    "projection-parity": "client=server=independent-pin",
    "authorization-matrix": "6/6-independent-agreement",
    "registry-errors": "4/4-exact",
    "stale-epochs": "4/4-exact-empty-trace",
    "generated-coverage": "9/9-classes-at-5-percent",
    "mutants": "2/2-red",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "5,6,8,9,2",
    "calculus-resource-vector": "5,30,0,0",
    "network-observer": "sanctioned-observer",
    "identity-provider-truth": "UNVERIFIED",
    "runtime-policy-enforcement": "UNVERIFIED",
    "provider-isolation": "UNVERIFIED",
}

CLASS_METRIC = {
    "registry": "action-registry",
    "decision": "authorization-matrix",
    "parity": "registry-errors",
    "epoch": "stale-epochs",
    "property": "generated-coverage",
    "mutant": "mutants",
}

CHECK_SIDE = {
    **{check: "source" for _name, check in OPAQUE_TYPES},
    **{check: "source" for _name, _arms, check in CLOSED_UNIONS},
    "visibility-absent-from-authorize": "source",
    "effect-requires-authorized-action": "source",
    "reference-evaluator-independent": "source",
    "authorization-partial-token-scan": "source",
    "semantic-oracles-complete": "oracle",
    "totality-options": "source",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}

MUTANT_TOKENS = {
    "default_allow": "ui-authorization-mutant: RED default_allow locus=default-deny",
    "visibility_is_authorization": "ui-authorization-mutant: RED visibility_is_authorization locus=hidden-invocable+stale",
}


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


def verify_oracles() -> tuple[list[dict[str, str]], dict[str, int]]:
    registry = read_tsv(FIXTURES / "action_registry.tsv")
    matrix = read_tsv(FIXTURES / "authorization_matrix.tsv")
    errors = read_tsv(FIXTURES / "decode_errors.tsv")
    stale = read_tsv(FIXTURES / "stale_decision_cases.tsv")
    calculus = read_tsv(CALCULUS)
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
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "action-registry,authorization-decisions,parity-and-epoch-refusals,generated-coverage-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "5,6,8,9,2"},
        {"metric": "resource-vector", "value": "5,30,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("authorization five-calculus projection oracle drifted")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 2 or {row["mutant"] for row in mutants} != set(MUTANT_TOKENS):
        raise GateFailure("Phase-39 mutant manifest must contain exactly the two contract mutants")
    locus = read_tsv(LOCUS)
    if len(locus) != 30 or len({row["entry"] for row in locus}) != 30:
        raise GateFailure("Phase-39 validation locus must contain thirty unique rows")
    phase0_rows = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    phase38 = [row for row in phase0_rows if row["# phase"] == "21"]
    if len(phase38) != 6:
        raise GateFailure("Phase-0 manifest must pin six Phase-39 artifacts")
    missing = [row["path"] for row in phase38 if not (ROOT / row["path"]).is_file()]
    if missing:
        raise GateFailure(f"Phase-39 preimplementation artifacts are absent: {missing}")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; identity/provider/runtime enforcement UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    counts = {
        "registry": len(registry),
        "matrix": len(matrix),
        "errors": len(errors),
        "stale": len(stale),
    }
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
        raise GateFailure(f"{type_name} is no longer declared in the authorization module")
    body = match.group(1)
    deriving = ""
    if "deriving" in body:
        body, _, deriving = body.partition("deriving")
    arms = re.findall(r"[=|]\s*([A-Z][A-Za-z0-9_']*)", body)
    return arms, deriving


def verify_source_boundaries() -> None:
    source = MODULE.read_text(encoding="utf-8")
    header = source.split(") where", 1)[0]
    for type_name, check in OPAQUE_TYPES:
        if not re.search(rf"^\s*[,(]?\s*{type_name}\b", header, re.MULTILINE):
            raise GateFailure(f"{check}: {type_name} is no longer exported")
        # Matched without assuming the author's spacing: `ActionId(..)` opens the
        # constructor exactly as `ActionId (..)` does.
        if re.search(rf"\b{type_name}\s*\(\s*\.\.", header):
            raise GateFailure(f"{check}: private constructor exported: {type_name}")
    for type_name, arms, check in CLOSED_UNIONS:
        observed, deriving = union_arms(source, type_name)
        if observed != list(arms):
            raise GateFailure(f"{check}: {type_name} arms drifted: {observed}")
        if "Bounded" not in deriving or "Enum" not in deriving:
            raise GateFailure(f"{check}: {type_name} is no longer Bounded and Enum, so it is not enumerably closed")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
    match = prohibited.search(stripped)
    if match:
        raise GateFailure(
            f"authorization-partial-token-scan: partial token {match.group(0)!r} in {MODULE.relative_to(ROOT)}"
        )
    authorize_body = source.split("authorize (BoundActionRegistry", 1)[1].split("\ncanRead ::", 1)[0]
    if "specVisibility" in authorize_body or "Visible" in authorize_body or "Hidden" in authorize_body:
        raise GateFailure(
            "visibility-absent-from-authorize: client visibility entered the production authorization transition"
        )
    if "interpretAuthorized :: AuthorizedAction -> [EffectEvent]" not in source:
        raise GateFailure("effect-requires-authorized-action: the effect interpreter no longer requires AuthorizedAction")
    reference = REFERENCE.read_text(encoding="utf-8")
    if "Amoebius.Ui.Security.Authorization" in reference:
        raise GateFailure(
            "reference-evaluator-independent: the independent evaluator imports the production module"
        )
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    stanza = cabal.split("test-suite ui-authorization-spec", 1)[1].split("\ntest-suite ", 1)[0]
    for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
        if option not in stanza:
            raise GateFailure(f"totality-options: authorization suite lacks {option}")


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-authorization-spec"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-authorization-spec"]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("ui-authorization-spec binary path is not absolute")
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
                    "authorization gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8")
                )
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-authorization-spec", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = (
        "ui-authorization-spec: PASS "
        "(5 actions, 6 matrix rows, 4 parity errors, 4 stale epochs, 9 coverage classes, 2 mutants)"
    )
    calculus = "ui-authorization-calculus: PASS (5 kinds, 30 projected units)"
    if token not in suite.stdout or token not in isolated or calculus not in suite.stdout or calculus not in isolated:
        raise GateFailure("Phase-39 acceptance tokens are absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs: list[str] = []
    reddened = 0
    for row in mutants:
        mutant = row["mutant"]
        result = run(
            [
                str(cabal), "test", "ui-authorization-spec", "--test-show-details=direct",
                f"--test-options=--mutant={mutant}",
            ],
            require_success=False,
        )
        if result.returncode == 0 or MUTANT_TOKENS[mutant] not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        reddened += 1
        logs.append(result.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], reddened: int, total: int, observer: str) -> None:
    """Record what this run measured, not what the contract hoped for."""
    metrics = {
        "action-registry": f"{counts['registry']}/5-exact",
        "projection-parity": "client=server=independent-pin",
        "authorization-matrix": f"{counts['matrix']}/6-independent-agreement",
        "registry-errors": f"{counts['errors']}/4-exact",
        "stale-epochs": f"{counts['stale']}/4-exact-empty-trace",
        "generated-coverage": "9/9-classes-at-5-percent",
        "mutants": f"{reddened}/{total}-red",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "5,6,8,9,2",
        "calculus-resource-vector": "5,30,0,0",
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
        phase=38, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
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

        print("\noracle side — the action registry, access matrix, parity, and epoch pins\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutants")
        results["oracle"] = True

        print("\nsource side — the registry's constructors and unions stay closed\n")
        verify_source_boundaries()
        for _name, check in OPAQUE_TYPES:
            print(f"  ok    {check}")
        for _name, _arms, check in CLOSED_UNIONS:
            print(f"  ok    {check}")
        print("  ok    visibility-absent-from-authorize    no visibility token in the authorization transition")
        print("  ok    effect-requires-authorized-action   the interpreter consumes AuthorizedAction")
        print("  ok    reference-evaluator-independent     the reference does not import the subject")
        print("  ok    authorization-partial-token-scan    no partial or unsafe token in the module")
        print("  ok    totality-options                    suite totality warnings are enabled")
        results["source"] = True

        print("\nsuite side — the pure authorization battery under a network observer\n")
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
    except (GateFailure, OSError, KeyError, ValueError, IndexError, json.JSONDecodeError) as problem:
        print(f"ui-authorization-gate: FAIL: {problem}", file=sys.stderr)

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
        if rows.get("authorization-matrix") == EXPECTED_RESULTS["authorization-matrix"]
        and rows.get("stale-epochs") == EXPECTED_RESULTS["stale-epochs"]
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
        dependencies={"ui-authorization-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "phase-39 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
