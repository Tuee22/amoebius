#!/usr/bin/env python3
"""Run and seal the scoped-identity and flow-kernel checks.

The capability claim is unchanged: the scope/flow kernel agrees with an independently
authored finite relation, its constructors are closed against caller-supplied authority,
and the seeded owner-equality mutant turns the gate red. What changed is where the run's
own records live. Evidence and the proven/tested/assumed ledger are emitted into the run
bundle under `.build/runs/`, the surface enumeration is produced at run time and joined to
an authored expectation, and the result is bound to a source-snapshot digest and retained
inside the checkout — the universal half owned by `tools/gate_common.py`.
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
FIXTURES = ROOT / "test/fixture/ui_scope"
MUTANT_CAPABILITY = "scoped_identity"
MUTANTS = ROOT / "test/mutant/registry.tsv"
LOCUS = ROOT / "test/oracle/scoped_identity/validation_locus.tsv"
MUTANT_FIXTURE = ROOT / "test/mutant/scoped_identity/drop_owner_equality.mutant"
RESULTS = ROOT / ".build/dsl/scoped-identity/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/scoped-identity/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/scoped-identity"
TEMP_ROOT = ROOT / ".build/tmp/scoped-identity"
CONTRACT = "DEVELOPMENT_PLAN/phase_08_scope_index.md"
GATE_COMMAND = "python3 tools/scoped_identity_gate.py"
EXPECTATIONS = "test/oracle/scoped_identity_surfaces.tsv"

COMPILER = ""

SANCTIONED_OBSERVERS = (
    "macos-sandbox-network-deny",
    "unshare-network-namespace",
    "strace-socket-EPERM",
)

# The scope/flow kernel's private constructors, each with the check id that decides it.
# One id per type rather than one for the set: a single "constructors are private" bit
# stays green while one of them quietly opens.
OPAQUE_TYPES = (
    ("Tenant", "index", "tenant-constructor-private"),
    ("Subject", "index", "subject-constructor-private"),
    ("Membership", "index", "membership-constructor-private"),
    ("Owner", "index", "owner-constructor-private"),
    ("Grant", "index", "grant-constructor-private"),
    ("RequestScope", "index", "request-scope-constructor-private"),
    ("Scoped", "index", "scoped-value-constructor-private"),
    ("ScopedHandle", "index", "scoped-handle-constructor-private"),
    ("SomeScopedHandle", "index", "some-scoped-handle-constructor-private"),
    ("ResourceId", "index", "resource-id-constructor-private"),
    ("FlowLabel", "flow", "flow-label-constructor-private"),
    ("CanFlowTo", "flow", "can-flow-to-constructor-private"),
)

CHECKS = {
    **{check: f"the {name} constructor is not exported" for name, _module, check in OPAQUE_TYPES},
    "no-general-authority-escape": "no general retag or declassify function is exported",
    "scope-partial-token-scan": "no partial or unsafe token survives in the security modules",
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "oracle", "source", "seal", "suite", "mutant", "results")

EXPECTED_RESULTS = {
    "owner-joins": "6/6-exact",
    "owner-swaps": "2/2-exact-errors",
    "flow-matrix": "4/4-independent-agreement",
    "flow-diagnostics": "4/4-exact-tags-and-paths",
    "compile-fail": "5/5-specific-reason-pairs",
    "generated-coverage": "9/9-classes-at-5-percent",
    "mutants": "1/1-red-on-2-swaps",
    "network-observer": "sanctioned-observer",
    "identity-provider-truth": "UNVERIFIED",
    "provider-row-policy": "UNVERIFIED",
    "live-noninterference": "UNVERIFIED",
}

# Which recorded metric decides a locus entry of each class. A surface spanning classes is
# evidenced only when every metric its ids depend on matched, so a rejection surface backed
# by a pinned row *and* a generated class cannot be carried by one of the two.
CLASS_METRIC = {
    "owner": "owner-joins",
    "negative": "owner-swaps",
    "flow": "flow-matrix",
    "flow-diagnostic": "flow-diagnostics",
    "compile-fail": "compile-fail",
    "property": "generated-coverage",
    "mutant": "mutants",
}

# Which side's result decides each check id.
CHECK_SIDE = {
    **{check: "source" for _name, _module, check in OPAQUE_TYPES},
    "no-general-authority-escape": "source",
    "scope-partial-token-scan": "source",
    "emitted-results-untracked": "results",
    "recorded-results-match-oracle": "results",
    "toolchain-satisfies-requirements": "toolchain",
}

COMPILE_LOCI = {
    "raw_resource_id.hs.fail": "Illegal term-level use of the type constructor ‘ResourceId’",
    "scope_retag.hs.fail": "Couldn't match type",
    "declassify.hs.fail": "Variable not in scope:",
    "handle_escape.hs.fail": "is a rigid type variable bound by",
    "forge_request_scope.hs.fail": "Illegal term-level use of the type constructor ‘RequestScope’",
}

COMPILE_POSITIVES = tuple(name.removesuffix(".fail") for name in COMPILE_LOCI)


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
    """Run a command, forcing every cabal invocation onto the resolved compiler.

    Without the flag cabal picks whichever ghc the host PATH offers, which is a different
    compiler from the one the run resolved and attested — and on a host carrying two, the
    gate silently measures the wrong one.
    """
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


def refresh_package_index(cabal: Path) -> None:
    """Make a clean contained Cabal home capable of resolving project dependencies."""
    result = subprocess.run(
        [str(cabal), "--ignore-project", "update"],
        cwd=ROOT,
        env=environment(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        raise GateFailure(f"contained cabal package-index update failed:\n{result.stdout}")


def verify_oracles() -> tuple[list[dict[str, str]], dict[str, int]]:
    """Check the authored pins still say what the contract says they say.

    The counts are the phase contract's representative set, so a silently shrunk oracle is
    a gate failure rather than a smaller green run.
    """
    owner = read_tsv(FIXTURES / "owner_join_table.tsv")
    swaps = read_tsv(FIXTURES / "owner_tenant_swaps.tsv")
    flows = read_tsv(FIXTURES / "flow_matrix.tsv")
    diagnostics = read_tsv(FIXTURES / "flow_diagnostics.tsv")
    errors = read_tsv(FIXTURES / "decode_errors.tsv")
    if len(owner) != 6 or sum(row["decision"] == "allow" for row in owner) != 3:
        raise GateFailure("owner join oracle must contain three allows and three denies")
    if [row["expected_error"] for row in swaps] != ["OwnerMismatch", "TenantMismatch"]:
        raise GateFailure("owner swap error oracle drifted")
    if len(flows) != 4 or [row["decision"] for row in flows] != ["allow", "deny", "deny", "deny"]:
        raise GateFailure("flow oracle decisions drifted")
    if [(row["expected_error"], row["expected_path"]) for row in diagnostics] != [
        ("SubjectFlowMismatch", "-"),
        ("FlowCycleDetected", "source>route>source"),
        ("MissingFlowMember", "missing"),
        ("FlowPathMissing", "source>sink"),
    ]:
        raise GateFailure("flow diagnostic oracle drifted")
    if {row["error"] for row in errors} != {
        "UntrustedResourceId", "ScopeRetagForbidden", "DeclassificationForbidden",
        "ScopeEscapeForbidden", "RequestScopeConstructorPrivate",
    }:
        raise GateFailure("compile-fail error oracle drifted")
    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 1:
        raise GateFailure("Phase-8 mutant registry must contain exactly one row")
    if mutants[0]["flag"] != "scope-index-drop-owner-equality-mutant":
        raise GateFailure("the Phase-8 owner-equality mutant has no build-flag carrier")
    if not MUTANT_FIXTURE.is_file():
        raise GateFailure("the committed owner-equality mutant fixture is absent")
    locus = read_tsv(LOCUS)
    if len(locus) != 31 or len({row["entry"] for row in locus}) != 31:
        raise GateFailure("Phase-8 validation locus must contain thirty-one unique rows")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; identity-provider/provider/runtime enforcement UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    counts = {
        "owner": len(owner),
        "swaps": len(swaps),
        "flows": len(flows),
        "diagnostics": len(diagnostics),
        "errors": len(errors),
    }
    return mutants, counts


def item_classes() -> dict[str, str]:
    """Enumerate what the run actually read, with the class that decides each entry."""
    classes = {row["entry"].strip(): row["class"].strip() for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"].strip()] = "mutant"
    return classes


def verify_source_boundaries() -> None:
    index = (ROOT / "src/Amoebius/Scope/Index.hs").read_text(encoding="utf-8")
    flow = (ROOT / "src/Amoebius/Scope/Flow.hs").read_text(encoding="utf-8")
    headers = {"index": index.split(") where", 1)[0], "flow": flow.split(") where", 1)[0]}
    for type_name, module, check in OPAQUE_TYPES:
        header = headers[module]
        if not re.search(rf"^\s*[,(]?\s*{type_name}\b", header, re.MULTILINE):
            raise GateFailure(f"{check}: {type_name} is no longer exported by the {module} kernel")
        # Matched without assuming the author's spacing: `Tenant(..)` opens the constructor
        # exactly as `Tenant (..)` does, and a scan that only knows the spaced form reports
        # a closed constructor for an open one.
        if re.search(rf"\b{type_name}\s*\(\s*\.\.", header):
            raise GateFailure(f"{check}: private constructor exported: {type_name}")
    for forbidden in ("retagHandle", "retagScoped", "declassify"):
        if forbidden in headers["index"] + headers["flow"]:
            raise GateFailure(f"no-general-authority-escape: {forbidden} is exported")
    if not re.search(r"forall\s+scope\.\s*RequestScope\s+scope", index):
        raise GateFailure("withRequestScope no longer introduces a rank-2 request index")
    if "Amoebius.Ui." in index + flow:
        raise GateFailure("the Phase-8 scope index imports the later UI-program surface")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path in sorted((ROOT / "src/Amoebius/Scope").glob("*.hs")):
        source = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", path.read_text(encoding="utf-8")))
        match = prohibited.search(source)
        if match:
            raise GateFailure(
                f"scope-partial-token-scan: partial token {match.group(0)!r} in {path.relative_to(ROOT)}"
            )


def compile_failures(cabal: Path) -> tuple[str, int]:
    logs = []
    observed = 0
    run([str(cabal), "build", "lib:scope-index"])
    common = [
        str(cabal), "exec", "ghc", "--",
        "-fno-code", "-XGHC2024", "-XOverloadedStrings", "-isrc", "-x", "hs",
    ]
    for name in COMPILE_POSITIVES:
        result = run(common + [str(FIXTURES / "compile_pass" / name)], require_success=False)
        if result.returncode != 0:
            raise GateFailure(f"compile-positive twin failed: {name}\n{result.stdout}")
    for name, token in COMPILE_LOCI.items():
        result = run(common + [str(FIXTURES / "compile_fail" / name)], require_success=False)
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"compile-fail locus drifted: {name}\n{result.stdout}")
        observed += 1
        logs.append(result.stdout)
    return "\n".join(logs), observed


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:scope-index-spec"])
    binary = Path(run([str(cabal), "list-bin", "test:scope-index-spec"]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("scope-index-spec binary path is not absolute")
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if sys.platform == "darwin" and shutil.which("sandbox-exec") is not None:
            profile = "(version 1) (allow default) (deny network*)"
            result = run(["sandbox-exec", "-p", profile, str(binary)])
            observer = "macos-sandbox-network-deny"
        elif shutil.which("unshare") is not None and run(["unshare", "-n", "true"], require_success=False).returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("neither network namespace isolation nor strace socket injection is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "inject=socket:error=EPERM",
                "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("scope gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "scope-index-spec", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = "scope-index-spec: PASS (6 owner rows, 2 swap errors, 8 flow rows, 5 compile loci, 9 coverage classes, 1 mutant)"
    if token not in suite.stdout or token not in isolated:
        raise GateFailure("Phase-8 acceptance token is absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, int]:
    logs = []
    reddened = 0
    for row in mutants:
        name = row["mutant"]
        flag = f"-f{row['flag']}"
        run([str(cabal), "build", "test:scope-index-spec", flag])
        binary = Path(run([str(cabal), "list-bin", "test:scope-index-spec", flag]).stdout.strip())
        result = run([str(binary), f"--mutant={name}"], require_success=False)
        token = f"scope-index-mutant: RED {name} same-tenant+cross-tenant"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {name}\n{result.stdout}")
        reddened += 1
        logs.append(result.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], loci: int, reddened: int, mutant_total: int, observer: str) -> None:
    """Record what this run measured, not what the contract hoped for.

    Every count comes from something the run counted — rows read from the pinned oracles,
    compile loci that produced their expected diagnostic, mutants that actually reddened —
    so a shrunken corpus shows up as a metric mismatch instead of a smaller green run.
    """
    metrics = {
        "owner-joins": f"{counts['owner']}/6-exact",
        "owner-swaps": f"{counts['swaps']}/2-exact-errors",
        "flow-matrix": f"{counts['flows']}/4-independent-agreement",
        "flow-diagnostics": f"{counts['diagnostics']}/4-exact-tags-and-paths",
        "compile-fail": f"{loci}/5-specific-reason-pairs",
        "generated-coverage": "9/9-classes-at-5-percent",
        "mutants": f"{reddened}/{mutant_total}-red-on-{counts['swaps']}-swaps",
        "network-observer": observer,
        "identity-provider-truth": "UNVERIFIED",
        "provider-row-policy": "UNVERIFIED",
        "live-noninterference": "UNVERIFIED",
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
    """Decide each item- and check-backed surface from a recorded observation.

    A surface with no id stays False, which the ledger renders UNVERIFIED. That is the
    point: a surface nothing measured is not a surface anything proved.
    """
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
        phase=8, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", lane="none", sides=SIDES,
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
        refresh_package_index(cabal)

        print("\noracle side — the owner, flow, diagnostic, and compile-fail pins\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print(f"  ok    {len(classes)} enumerated items, {len(mutant_rows)} mutant(s)")
        results["oracle"] = True

        print("\nsource side — the kernel's constructors stay closed\n")
        verify_source_boundaries()
        for _name, _module, check in OPAQUE_TYPES:
            print(f"  ok    {check}")
        print("  ok    no-general-authority-escape       no retagHandle or declassify is exported")
        print("  ok    scope-partial-token-scan          no partial or unsafe token in the security modules")
        results["source"] = True

        print("\nseal side — five legal/illegal compile pairs at their pinned reasons\n")
        compile_log, loci = compile_failures(cabal)
        (gate.run_dir / "compile-fail.log").write_text(compile_log, encoding="utf-8")
        print(f"  ok    {loci}/{len(COMPILE_LOCI)} legal twins green and illegal twins red at their pinned diagnostic")
        results["seal"] = True

        print("\nsuite side — the pure scope battery under a network observer\n")
        green, observer = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        if observer not in SANCTIONED_OBSERVERS:
            print(f"  FAIL  network observer {observer!r} is not one this contract sanctions")
        else:
            print(f"  ok    network-isolated pure gate proven by {observer}")
            results["suite"] = True

        print("\nmutant side — the seeded mutant red at its own locus\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    {reddened}/{len(mutant_rows)} mutant(s) reddened on both swap pins")
        results["mutant"] = True

        write_results(counts, loci, reddened, len(mutant_rows), observer)
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
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"scoped-identity-gate: FAIL: {problem}", file=sys.stderr)

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
        if rows.get("owner-joins") == EXPECTED_RESULTS["owner-joins"]
        and rows.get("flow-matrix") == EXPECTED_RESULTS["flow-matrix"]
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
        dependencies={"scope-index-spec": "cabal test"},
        mutants=[{"name": row["mutant"], "status": "red" if reddened else "unrun"} for row in mutant_rows]
        or [{"name": "drop_owner_equality", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
