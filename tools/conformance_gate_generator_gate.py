#!/usr/bin/env python3
"""Phase 25: declaration-derived suite plan, passing verdict, and gated admission."""

from __future__ import annotations

import csv
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / ".build/dsl/extension-conformance-gate"
RESULTS = OUTPUT / "phase-results.tsv"
INVENTORY = OUTPUT / "inventory.tsv"
COVERAGE = OUTPUT / "coverage-observed.tsv"
VERDICT = OUTPUT / "verdict.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/extension-conformance-gate"
CONTRACT = "DEVELOPMENT_PLAN/phase_25_conformance_gate_generator.md"
GATE_COMMAND = "python3 tools/conformance_gate_generator_gate.py"
EXPECTATIONS = "test/oracle/extension_conformance_gate_surfaces.tsv"
EXPECTED_INVENTORY = ROOT / "test/oracle/extension_conformance/suite_inventory.tsv"
EXPECTED_COVERAGE = ROOT / "test/oracle/extension_conformance/coverage_grid.tsv"
VERDICT_CASES = ROOT / "test/oracle/extension_conformance/verdict_cases.tsv"
CATALOG = ROOT / "test/oracle/extension_conformance/mutation_catalog.tsv"
CAPABILITY = "extension_conformance"
SUITE = "extension-conformance-gate-spec"
COMPILE_SUITE = "extension-conformance-gate-compile"
GENERATED_NAMES = (
    "property-suite.tsv", "composition-suite.tsv", "compile-fail-suite.tsv",
    "security-suite.tsv", "transaction-suite.tsv", "coverage-grid.tsv",
)

SIDES = ("toolchain", "source", "suite", "typed", "mutant", "oracle", "artifact")

CHECKS = {
    "opaque-generator-scan": "plan, core version, verdict, and link-set constructors remain private",
    "suite-inventory-independent": "nineteen decoded emitted rows equal the authored inventory",
    "coverage-grid-independent": "eighteen required and six explicit P deferrals equal the authored grid",
    "case-id-independent": "Python recomputes all nineteen length-framed case identifiers",
    "suite-digest-independent": "Python recomputes the digest over all six generated files",
    "verdict-digest-independent": "Python recomputes declaration/core/suite/result verdict content address",
    "verdict-cases-independent": "six authored seal/admission outcomes name distinct refusal boundaries",
    "typed-admission-barriers": "three illegal constructor/admission programs fail at pinned GHC reasons",
    "results-untracked": "all generated suite and verdict observations remain beneath .build/**",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC satisfy authored ranges",
    "recorded-results-match-oracle": "all fifteen exact metrics match the contract",
}

EXPECTED_RESULTS = {
    "executable-cases": "19/19-derived",
    "suite-files": "5/5-plus-coverage",
    "property-cases": "5/5-L1-L5",
    "composition-cases": "7/7-C1-C7-one-peer",
    "compile-cases": "1/1-declared-claim",
    "security-cases": "6/6-S1-S6",
    "transaction-coverage": "6/6-not-applicable-no-vocabulary",
    "coverage-grid": "24/24-authored",
    "verdict-seal": "declaration-core-suite-result-bound",
    "admission": "1/1-verdict-required",
    "mutants": "3/3-red-exactly",
    "compiler-barriers": "3/3-specific-red",
    "source-scans": "opaque-derived-no-unsafe",
    "independent-digests": "19-case/1-suite/1-verdict",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "derived-case-inventory": ("executable-cases", EXPECTED_RESULTS["executable-cases"]),
    "generated-suite-files": ("suite-files", EXPECTED_RESULTS["suite-files"]),
    "transaction-applicability": ("transaction-coverage", EXPECTED_RESULTS["transaction-coverage"]),
    "generated-coverage-grid": ("coverage-grid", EXPECTED_RESULTS["coverage-grid"]),
    "content-bound-verdict": ("verdict-seal", EXPECTED_RESULTS["verdict-seal"]),
    "verdict-gated-admission": ("admission", EXPECTED_RESULTS["admission"]),
    "exact-mutant-summary": ("mutants", EXPECTED_RESULTS["mutants"]),
    "admission-compiler-barriers": ("compiler-barriers", EXPECTED_RESULTS["compiler-barriers"]),
    "closed-generator-source": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "independent-content-addresses": ("independent-digests", EXPECTED_RESULTS["independent-digests"]),
    "runtime-correspondence": None,
    "opaque-generator-boundary": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "authored-suite-oracle": ("executable-cases", EXPECTED_RESULTS["executable-cases"]),
    "authored-coverage-oracle": ("coverage-grid", EXPECTED_RESULTS["coverage-grid"]),
    "python-case-addresses": ("independent-digests", EXPECTED_RESULTS["independent-digests"]),
    "python-suite-address": ("independent-digests", EXPECTED_RESULTS["independent-digests"]),
    "python-verdict-address": ("independent-digests", EXPECTED_RESULTS["independent-digests"]),
    "authored-verdict-cases": ("verdict-seal", EXPECTED_RESULTS["verdict-seal"]),
    "specific-compiler-negatives": ("compiler-barriers", EXPECTED_RESULTS["compiler-barriers"]),
    "inventory-omission-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "suite-binding-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "admission-authority-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
}


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-12000:]}")
    return result


def cabal_command(resolved: dict[str, Any], *arguments: str) -> list[str]:
    return [
        resolved["cabal"]["path"], f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}", f"--store-dir={ROOT / '.build/cabal-store'}",
        "--jobs=1", *arguments,
    ]


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — compiler and build driver from authored requirements\n")
    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("ghc", "cabal"):
        record = resolved[name]
        print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
    return True, resolved


def source_side() -> bool:
    print("\nsource side — declaration-derived plan and opaque verdict/admission authority\n")
    production = (ROOT / "src/extension-conformance-gate/Amoebius/Extension/Conformance/Gate.hs").read_text(encoding="utf-8")
    header = production.split(") where", 1)[0]
    opaque = ("CoreVersion", "GatePlan", "ConformanceVerdict", "LinkSet")
    exposed = [name for name in opaque if re.search(rf"\b{re.escape(name)}\s*\(\.\.\)", header)]
    forbidden = ("unsafeCoerce", "unsafePerformIO", "IORef", "System.Environment", "getCurrentTime", "listDirectory")
    escaped = [token for token in forbidden if token in production]
    required = (
        "declarationVocabulary declaration", "everyCompositionLaw", "everySecurityLaw",
        "transaction-vocabulary-not-declared", "gatePlanSuiteDigest", "runGeneratedGate",
        "verifyVerdict", "admitExtension", "ConformanceVerdict declaration version",
    )
    missing = [token for token in required if token not in production]
    green = not exposed and not escaped and not missing
    print(f"  {'ok  ' if green else 'FAIL'}  opaque-generator-scan exposed={exposed} forbidden={escaped} missing={missing}")
    return green


def read_results() -> dict[str, str]:
    if not RESULTS.is_file():
        return {}
    rows: dict[str, str] = {}
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, separator, value = line.partition("\t")
        if separator:
            rows[key] = value
    return rows


def write_results(rows: dict[str, str]) -> None:
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{rows[key]}\n" for key in EXPECTED_RESULTS if key in rows),
        encoding="utf-8",
    )


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str], str]:
    print("\nsuite side — derived manifests, passing seal, and legal admission signature\n")
    try:
        result = run(cabal_command(resolved, "test", SUITE, COMPILE_SUITE, "--test-show-details=direct"))
        listing = run(cabal_command(resolved, "list-bin", SUITE))
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  generated-conformance suite; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}, ""
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    tokens = (
        "extension-conformance-gate-spec: PASS (19 cases, 24 coverage cells, 1 sealed admission, 3 exact mutants)",
        "extension-conformance-compile: PASS verdict-gated admission signature",
    )
    green = all(token in result.stdout for token in tokens)
    print(f"  {'ok  ' if green else 'FAIL'}  generator suite and legal verdict-gated admission green")
    rows = read_results() if green else {}
    rows.pop("mutants", None)
    binary = listing.stdout.strip().splitlines()[-1] if green else ""
    return green, rows, binary


NEGATIVES = {
    "forge-verdict": (
        "EXTENSION_CONFORMANCE_TEST_FORGE_VERDICT",
        ("GHC-01928", "Illegal term-level use", "ConformanceVerdict"),
    ),
    "unsealed-admission": (
        "EXTENSION_CONFORMANCE_TEST_UNSEALED_ADMISSION",
        ("GHC-83865", "applied to too few arguments", "ConformanceVerdict", "LinkSet"),
    ),
    "cross-scope-verdict": (
        "EXTENSION_CONFORMANCE_TEST_CROSS_SCOPE_VERDICT",
        ("GHC-25897", "Couldn't match type", "ConformanceVerdict", "admitExtension"),
    ),
}


def compile_negative(resolved: dict[str, Any], macro: str, name: str) -> subprocess.CompletedProcess[str]:
    output = BUILD_ROOT / "compile-negative" / name
    output.mkdir(parents=True, exist_ok=True)
    source_dirs = (
        "-isrc/extension-conformance-gate", "-isrc/extension-laws-compositional",
        "-isrc/extension-laws", "-isrc/extension-security-laws", "-isrc/extension-declaration",
        "-isrc/calculus-composition", "-isrc",
    )
    return run(
        cabal_command(
            resolved, "exec", "--", resolved["ghc"]["path"], "-fno-code", "-fforce-recomp",
            "-XGHC2024", "-XCPP", *source_dirs, f"-outputdir={output}",
            "-package", "base", "-package", "bytestring", "-package", "containers", "-package", "text",
            f"-D{macro}", "test/negative/compile_fail/extension_conformance/ConformanceCompile.hs",
        ),
        require_success=False,
    )


def typed_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\ntyped side — verdict construction, omission, and cross-request use are rejected\n")
    ok = True
    for name, (macro, tokens) in NEGATIVES.items():
        result = compile_negative(resolved, macro, name)
        (run_dir / f"compile-{name}.log").write_text(result.stdout, encoding="utf-8")
        red = result.returncode != 0 and all(token in result.stdout for token in tokens)
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<22} rejected at specific type reason")
        ok = ok and red
    return ok


def table(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def mutation_catalog() -> list[dict[str, str]]:
    return table(CATALOG)


def mutant_side(binary: str, run_dir: Path) -> bool:
    print("\nmutant side — inventory, suite binding, and admission bypasses turn red\n")
    catalog = mutation_catalog()
    registry = mutant_registry.capability(CAPABILITY)
    expected = {row["mutant"]: row["red_property"] for row in catalog}
    if len(expected) != 3 or {row["mutant"] for row in registry} != set(expected):
        print("  FAIL  mutation catalogue and registry do not name the same three mutants")
        return False
    ok = True
    for mutant, property_name in expected.items():
        result = run([binary, f"--mutant={mutant}"], require_success=False)
        (run_dir / f"mutant-{mutant}.log").write_text(result.stdout, encoding="utf-8")
        token = f"extension-conformance-mutant: RED {mutant} {property_name}"
        red = result.returncode != 0 and token in result.stdout
        print(f"  {'ok  ' if red else 'FAIL'}  {mutant:<29} reddens {property_name}")
        ok = ok and red
    return ok


def framed(fields: list[bytes]) -> bytes:
    return b"".join(len(field).to_bytes(8, "big") + field for field in fields)


def decode_suite_files() -> tuple[list[dict[str, str]], bool]:
    decoded: list[dict[str, str]] = []
    ids_green = True
    for name in GENERATED_NAMES[:5]:
        suite = name.removesuffix("-suite.tsv")
        lines = (OUTPUT / name).read_text(encoding="utf-8").splitlines()
        if len(lines) < 3 or lines[2] != "case_id\tlaw\taxis_hex\tpeer_digest":
            return [], False
        for line in lines[3:]:
            identifier, law, axis_hex, peer = line.split("\t")
            axis = bytes.fromhex(axis_hex).decode()
            peer_value = "" if peer == "-" else peer
            expected_id = "case-" + hashlib.sha256(
                framed([value.encode() for value in (suite, law, axis, peer_value)])
            ).hexdigest()
            ids_green = ids_green and identifier == expected_id
            decoded.append({"suite": suite, "law": law, "axis": axis})
    return decoded, ids_green


def decode_coverage() -> list[dict[str, str]]:
    lines = (OUTPUT / "coverage-grid.tsv").read_text(encoding="utf-8").splitlines()
    if len(lines) < 3 or lines[2] != "law\taxis_hex\tstatus\treason_hex":
        return []
    rows: list[dict[str, str]] = []
    for line in lines[3:]:
        law, axis_hex, status, reason_hex = line.split("\t")
        rows.append({
            "law": law,
            "axis": bytes.fromhex(axis_hex).decode(),
            "status": status,
            "reason": "-" if reason_hex == "-" else bytes.fromhex(reason_hex).decode(),
        })
    return rows


def suite_digest() -> str:
    fields: list[bytes] = []
    for name in sorted(GENERATED_NAMES):
        fields.extend([name.encode(), (OUTPUT / name).read_bytes()])
    return hashlib.sha256(framed(fields)).hexdigest()


def digest_oracles() -> tuple[bool, bool, bool, bool, bool, bool]:
    emitted_inventory, cases = decode_suite_files()
    inventory = sorted(emitted_inventory, key=lambda row: (row["suite"], row["law"], row["axis"])) == sorted(
        table(EXPECTED_INVENTORY), key=lambda row: (row["suite"], row["law"], row["axis"])
    )
    coverage = sorted(decode_coverage(), key=lambda row: (row["law"], row["axis"])) == sorted(
        table(EXPECTED_COVERAGE), key=lambda row: (row["law"], row["axis"])
    )
    verdict_rows = table(VERDICT)
    suite = False
    verdict = False
    if len(verdict_rows) == 1:
        row = verdict_rows[0]
        computed_suite = suite_digest()
        suite = computed_suite == row["suite_digest"]
        computed_verdict = hashlib.sha256(framed([
            value.encode() for value in (
                "amoebius-extension-verdict-v1", row["declaration_digest"], row["core_version"],
                row["suite_digest"], row["result"],
            )
        ])).hexdigest()
        verdict = computed_verdict == row["verdict_digest"]
    expected_verdict_cases = [
        ("canonical-passing-run", "sealed-and-admitted", "-"),
        ("modified-suite", "refused", "GeneratedSuiteMismatch"),
        ("failed-case", "refused", "CasesFailed"),
        ("wrong-declaration", "refused", "PlanDeclarationMismatch"),
        ("changed-core", "refused", "VerdictDidNotVerify"),
        ("unsealed-extension", "compile-refused", "missing-ConformanceVerdict"),
    ]
    verdict_cases = [(row["case"], row["result"], row["reason"]) for row in table(VERDICT_CASES)] == expected_verdict_cases
    return inventory, coverage, cases, suite, verdict, verdict_cases


def independent_side() -> bool:
    print("\nindependent oracle — decoded inventories and Python content addresses\n")
    try:
        inventory, coverage, cases, suite, verdict, verdict_cases = digest_oracles()
    except (OSError, KeyError, ValueError, UnicodeDecodeError) as error:
        print(f"  FAIL  independent oracle {error}")
        return False
    checks = (
        ("suite-inventory-independent", inventory, "nineteen decoded rows"),
        ("coverage-grid-independent", coverage, "eighteen required plus six P deferrals"),
        ("case-id-independent", cases, "nineteen length-framed SHA-256 ids"),
        ("suite-digest-independent", suite, "six-file content address"),
        ("verdict-digest-independent", verdict, "declaration/core/suite/result address"),
        ("verdict-cases-independent", verdict_cases, "six authored outcomes"),
    )
    for name, green, detail in checks:
        print(f"  {'ok  ' if green else 'FAIL'}  {name} {detail}")
    return all(green for _name, green, _detail in checks)


def oracle_side(rows: dict[str, str]) -> bool:
    print("\noracle side — complete results against fifteen exact metrics\n")
    ok = True
    for key, expected in EXPECTED_RESULTS.items():
        actual = rows.get(key)
        if actual != expected:
            print(f"  FAIL  recorded-results-match-oracle {key}: {actual!r} != {expected!r}")
            ok = False
    extras = sorted(set(rows) - set(EXPECTED_RESULTS))
    if extras:
        print(f"  FAIL  recorded-results-match-oracle unexpected metric(s): {', '.join(extras)}")
        ok = False
    if ok:
        print(f"  ok    recorded-results-match-oracle all {len(EXPECTED_RESULTS)} metrics match")
    return ok


def artifact_side() -> bool:
    print("\nartifact side — generated suites, observations, and verdict remain project-contained\n")
    snapshot = set(artifact_policy.snapshot_paths())
    paths = [RESULTS, INVENTORY, COVERAGE, VERDICT] + [OUTPUT / name for name in GENERATED_NAMES]
    ok = True
    for path in paths:
        relative = gate_common.rel(path)
        clean = path.is_file() and relative.startswith(".build/") and relative not in snapshot
        print(f"  {'ok  ' if clean else 'FAIL'}  results-untracked {relative}")
        ok = ok and clean
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=24, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    results["toolchain"], resolved = toolchain_side()
    rows: dict[str, str] = {}
    binary = ""
    if results["toolchain"]:
        results["source"] = source_side()
        results["suite"], rows, binary = suite_side(resolved, gate.run_dir)
    if results["suite"]:
        results["typed"] = typed_side(resolved, gate.run_dir)
        results["mutant"] = mutant_side(binary, gate.run_dir)
        independent = independent_side()
        if results["source"]:
            rows["source-scans"] = EXPECTED_RESULTS["source-scans"]
        if results["typed"]:
            rows["compiler-barriers"] = EXPECTED_RESULTS["compiler-barriers"]
        if results["mutant"]:
            rows["mutants"] = EXPECTED_RESULTS["mutants"]
        if independent:
            rows["independent-digests"] = EXPECTED_RESULTS["independent-digests"]
        write_results(rows)
        results["oracle"] = independent and oracle_side(rows)
        results["artifact"] = artifact_side()

    implemented = {
        "metrics": set(rows), "checks": set(CHECKS),
        "mutants": {row["mutant"] for row in mutant_registry.capability(CAPABILITY)},
    }
    results["surface"], surfaces = gate.surface_join(implemented)
    status = {
        surface: bool(SURFACE_EVIDENCE.get(surface))
        and rows.get(SURFACE_EVIDENCE[surface][0]) == SURFACE_EVIDENCE[surface][1]
        for surface in surfaces
    }
    status["generated-artifact-discipline"] = results["artifact"]
    decision_green = all(rows.get(key) == EXPECTED_RESULTS[key] for key in (
        "executable-cases", "coverage-grid", "verdict-seal", "admission", "mutants",
        "compiler-barriers", "source-scans", "independent-digests",
    ))
    layers = {"Decision": "tested" if decision_green else "UNVERIFIED", "Protocol": "UNVERIFIED", "Runtime": "UNVERIFIED"}
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={name: {"version": record["version"], "requirement": record["requirement"]}
                   for name, record in resolved.items() if name != "platform"},
        dependencies={SUITE: "cabal test", COMPILE_SUITE: "GHC legal/illegal verdict admission twins"},
        checks=results,
        mutants=[{"name": row["mutant"], "status": row["red_property"]} for row in mutation_catalog()],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "inventory": "sha256:" + artifact_policy.digest(str(INVENTORY)),
            "coverage": "sha256:" + artifact_policy.digest(str(COVERAGE)),
            "verdict": "sha256:" + artifact_policy.digest(str(VERDICT)),
        } if all(path.is_file() for path in (RESULTS, INVENTORY, COVERAGE, VERDICT)) else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
