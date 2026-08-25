#!/usr/bin/env python3
"""Phase 24: bounded S1-S6 security-law evidence over a pure scoped kernel."""

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
RESULTS = ROOT / ".build/dsl/extension-security-laws/phase-results.tsv"
ENVELOPE = ROOT / ".build/dsl/extension-security-laws/envelope.tsv"
NAMESPACES = ROOT / ".build/dsl/extension-security-laws/namespaces.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/extension-security-laws"
CONTRACT = "DEVELOPMENT_PLAN/phase_24_extension_security_laws.md"
GATE_COMMAND = "python3 tools/extension_security_laws_gate.py"
EXPECTATIONS = "test/oracle/extension_security_laws_surfaces.tsv"
OPERATIONS = ROOT / "test/oracle/extension_security/operation_matrix.tsv"
NAMESPACE_CASES = ROOT / "test/oracle/extension_security/namespace_cases.tsv"
REVOCATION = ROOT / "test/oracle/extension_security/revocation_layers.tsv"
VERDICTS = ROOT / "test/oracle/extension_security/law_verdicts.tsv"
CATALOG = ROOT / "test/oracle/extension_security/mutation_catalog.tsv"
CAPABILITY = "extension_security_laws"
SUITE = "extension-security-laws-spec"
COMPILE_SUITE = "extension-security-laws-compile"

SIDES = ("toolchain", "source", "suite", "typed", "mutant", "oracle", "artifact")

CHECKS = {
    "opaque-mandatory-scan": "security constructors stay private and scoped operations have no optional/default arm",
    "operation-matrix-independent": "Python checks five operations across own, foreign, and absent targets",
    "refusal-matrix-independent": "foreign and absent authored outcomes are identical and mutation-free",
    "namespace-output-independent": "Python recomputes all five emitted length-framed namespace pairs",
    "revocation-table-independent": "two authority layers state exactly one edge-or-bound policy each",
    "verdict-grid-independent": "one control and six defects state all 42 S-law verdicts",
    "signature-independent": "Python recomputes the emitted length-framed SHA-256 signature",
    "typed-security-barriers": "four illegal identity/scope/key programs fail at their pinned GHC reasons",
    "results-untracked": "generated security observations remain beneath .build/**",
    "toolchain-satisfies-requirements": "resolved Cabal and GHC satisfy authored ranges",
    "recorded-results-match-oracle": "all thirteen exact metrics match the contract",
}

EXPECTED_RESULTS = {
    "identity-envelope": "1-valid/1-tampered-refused",
    "operation-matrix": "15/15-exact",
    "refusal-pairs": "5/5-byte-identical-zero-mutation",
    "timing-envelope": "5/5-modeled-bound",
    "namespaces": "5/5-injective-round-trip",
    "revocation-layers": "2/2-edge-or-bound",
    "law-verdicts": "42/42-authored",
    "single-law-defects": "6/6-exact",
    "mutants": "6/6-red-exactly",
    "compile-barriers": "4/4-specific-red",
    "source-scans": "opaque-mandatory-no-unsafe",
    "independent-signature": "1/1-sha256",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "identity-attestation": ("independent-signature", EXPECTED_RESULTS["independent-signature"]),
    "scoped-operation-matrix": ("operation-matrix", EXPECTED_RESULTS["operation-matrix"]),
    "indistinguishable-refusal": ("refusal-pairs", EXPECTED_RESULTS["refusal-pairs"]),
    "modeled-refusal-timing": ("timing-envelope", EXPECTED_RESULTS["timing-envelope"]),
    "injective-keyspaces": ("namespaces", EXPECTED_RESULTS["namespaces"]),
    "revocation-policy": ("revocation-layers", EXPECTED_RESULTS["revocation-layers"]),
    "authored-security-verdicts": ("law-verdicts", EXPECTED_RESULTS["law-verdicts"]),
    "single-law-defects": ("single-law-defects", EXPECTED_RESULTS["single-law-defects"]),
    "exact-mutant-summary": ("mutants", EXPECTED_RESULTS["mutants"]),
    "security-compiler-barriers": ("compile-barriers", EXPECTED_RESULTS["compile-barriers"]),
    "closed-security-source": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "runtime-correspondence": None,
    "opaque-mandatory-boundary": ("source-scans", EXPECTED_RESULTS["source-scans"]),
    "authored-operation-oracle": ("operation-matrix", EXPECTED_RESULTS["operation-matrix"]),
    "authored-namespace-oracle": ("namespaces", EXPECTED_RESULTS["namespaces"]),
    "authored-revocation-oracle": ("revocation-layers", EXPECTED_RESULTS["revocation-layers"]),
    "authored-verdict-oracle": ("law-verdicts", EXPECTED_RESULTS["law-verdicts"]),
    "python-signature-oracle": ("independent-signature", EXPECTED_RESULTS["independent-signature"]),
    "specific-compiler-negatives": ("compile-barriers", EXPECTED_RESULTS["compile-barriers"]),
    "s1-attestation-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "s2-skolem-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "s3-default-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "s4-refusal-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "s5-namespace-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
    "s6-revocation-mutant": ("mutants", EXPECTED_RESULTS["mutants"]),
}


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
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
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-12000:]}")
    return result


def cabal_command(resolved: dict[str, Any], *arguments: str) -> list[str]:
    return [
        resolved["cabal"]["path"],
        f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
        "--jobs=1",
        *arguments,
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
    print("\nsource side — opaque introductions, mandatory scope, and no unsafe escape\n")
    production = (ROOT / "src/extension-security-laws/Amoebius/Extension/Laws/Security.hs").read_text(encoding="utf-8")
    header = production.split(") where", 1)[0]
    opaque = ("Identity", "VerificationKey", "SecurityStore", "ScopedKey", "StalenessBound", "AuthorityLayer")
    exposed = [name for name in opaque if re.search(rf"\b{re.escape(name)}\s*\(\.\.\)", header)]
    forbidden = (
        "unsafeCoerce", "unsafePerformIO", "Maybe (RequestScope", "Maybe RequestScope",
        "IORef", "System.Environment", "getCurrentTime",
    )
    escaped = [token for token in forbidden if token in production]
    required = (
        "data Identity (trust :: Trust)", "verifyIdentity", "Identity 'Attested",
        "forall scope. RequestScope scope", "runScopedOperation", "RequestScope scope",
        "renderScopedKey", "parseRenderedKey", "evaluateSecurityLaws",
        "RevocationLayer", "BoundedLayer",
    )
    missing = [token for token in required if token not in production]
    green = not exposed and not escaped and not missing
    print(f"  {'ok  ' if green else 'FAIL'}  opaque-mandatory-scan exposed={exposed} forbidden={escaped} missing={missing}")
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
    print("\nsuite side — scoped operations, six security laws, and legal compile twin\n")
    try:
        result = run(cabal_command(resolved, "test", SUITE, COMPILE_SUITE, "--test-show-details=direct"))
        listing = run(cabal_command(resolved, "list-bin", SUITE))
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  security-law suite; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}, ""
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    tokens = (
        "extension-security-laws-spec: PASS (15 operations, 5 refusal pairs, 5 namespaces, 42 verdicts, 6 exact mutants)",
        "extension-security-compile: PASS legal claimed/attested boundary",
    )
    green = all(token in result.stdout for token in tokens)
    print(f"  {'ok  ' if green else 'FAIL'}  behavioral suite and legal identity boundary green")
    rows = read_results() if green else {}
    rows.pop("mutants", None)
    binary = listing.stdout.strip().splitlines()[-1] if green else ""
    return green, rows, binary


NEGATIVES = {
    "claimed-as-attested": (
        "EXTENSION_SECURITY_TEST_CLAIMED_AS_ATTESTED",
        ("GHC-83865", "Claimed", "Attested", "attestedOnly identity"),
    ),
    "promotion": (
        "EXTENSION_SECURITY_TEST_PROMOTION",
        ("GHC-83865", "Claimed", "Attested", "promote identity = identity"),
    ),
    "missing-scope": (
        "EXTENSION_SECURITY_TEST_MISSING_SCOPE",
        ("GHC-83865", "RequestScope", "runScopedOperation Read"),
    ),
    "cross-key": (
        "EXTENSION_SECURITY_TEST_CROSS_KEY",
        ("GHC-25897", "Couldn't match type", "RequestScope", "renderScopedKey right"),
    ),
}


def compile_negative(resolved: dict[str, Any], macro: str, name: str) -> subprocess.CompletedProcess[str]:
    output = BUILD_ROOT / "compile-negative" / name
    output.mkdir(parents=True, exist_ok=True)
    return run(
        cabal_command(
            resolved,
            "exec", "--", resolved["ghc"]["path"], "-fno-code", "-fforce-recomp",
            "-XGHC2024", "-XCPP", "-isrc/extension-security-laws", "-isrc",
            f"-outputdir={output}", "-package", "base", "-package", "bytestring",
            "-package", "containers", "-package", "text", f"-D{macro}",
            "test/negative/compile_fail/extension_security/SecurityCompile.hs",
        ),
        require_success=False,
    )


def typed_side(resolved: dict[str, Any], run_dir: Path) -> bool:
    print("\ntyped side — claimed identity, promotion, missing scope, and cross-request key are uninhabited\n")
    ok = True
    for name, (macro, tokens) in NEGATIVES.items():
        result = compile_negative(resolved, macro, name)
        (run_dir / f"compile-{name}.log").write_text(result.stdout, encoding="utf-8")
        red = result.returncode != 0 and all(token in result.stdout for token in tokens)
        print(f"  {'ok  ' if red else 'FAIL'}  {name:<22} rejected at specific type reason")
        ok = ok and red
    return ok


def mutation_catalog() -> list[dict[str, str]]:
    with CATALOG.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def mutant_side(binary: str, run_dir: Path) -> bool:
    print("\nmutant side — six defects redden their exact S-law loci\n")
    catalog = mutation_catalog()
    registry = mutant_registry.capability(CAPABILITY)
    expected = {row["mutant"]: row["red_property"] for row in catalog}
    if len(expected) != 6 or {row["mutant"] for row in registry} != set(expected):
        print("  FAIL  mutation catalogue and registry do not name the same six mutants")
        return False
    ok = True
    for mutant, property_name in expected.items():
        result = run([binary, f"--mutant={mutant}"], require_success=False)
        (run_dir / f"mutant-{mutant}.log").write_text(result.stdout, encoding="utf-8")
        token = f"extension-security-mutant: RED {mutant} {property_name}"
        red = result.returncode != 0 and token in result.stdout
        print(f"  {'ok  ' if red else 'FAIL'}  {mutant:<29} reddens {property_name}")
        ok = ok and red
    return ok


def table(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def operation_oracle() -> tuple[bool, bool]:
    rows = table(OPERATIONS)
    operations = ("Read", "Update", "Delete", "Replay", "CacheLookup")
    indexed = {(row["operation"], row["target"]): row for row in rows}
    own_results = {
        "Read": ("allow:own-value", "0"),
        "Update": ("allow:updated", "1"),
        "Delete": ("allow:deleted", "1"),
        "Replay": ("allow:replayed:own-value", "0"),
        "CacheLookup": ("allow:cached:own-value", "0"),
    }
    shape = len(rows) == 15 and len(indexed) == 15
    refusal = True
    for operation in operations:
        own = indexed.get((operation, "own-record"), {})
        foreign = indexed.get((operation, "foreign-record"), {})
        absent = indexed.get((operation, "absent-record"), {})
        shape = shape and (own.get("result"), own.get("mutation_count")) == own_results[operation]
        expected_denial = ("deny:resource-unavailable", "0")
        refusal = refusal and (
            (foreign.get("result"), foreign.get("mutation_count")) == expected_denial
            and (absent.get("result"), absent.get("mutation_count")) == expected_denial
        )
    return shape and refusal, refusal


def frame_text(fields: list[str]) -> str:
    return "".join(f"{len(field)}:{field}" for field in fields)


def namespace_oracle() -> bool:
    authored = table(NAMESPACE_CASES)
    emitted = table(NAMESPACES)
    tags = {"RowKey": "row", "ObjectPrefix": "object", "TopicName": "topic", "CacheKey": "cache", "ReplayKey": "replay"}
    indexed = {row["keyspace"]: row for row in emitted}
    green = len(authored) == 5 and len(emitted) == 5 and set(indexed) == set(tags)
    for row in authored:
        observed = indexed.get(row["keyspace"], {})
        left = frame_text([row["left_tenant"], row["left_subject"], tags[row["keyspace"]], row["left_domain"]])
        right = frame_text([row["right_tenant"], row["right_subject"], tags[row["keyspace"]], row["right_domain"]])
        green = green and observed.get("left") == left and observed.get("right") == right and left != right
    return green


def revocation_oracle() -> bool:
    rows = table(REVOCATION)
    return rows == [
        {"layer": "socket-cache", "policy": "edge", "value": "membership-epoch", "probe": "observed"},
        {"layer": "offline-partition", "policy": "bound", "value": "300", "probe": "enforced"},
    ]


def verdict_oracle() -> bool:
    rows = table(VERDICTS)
    catalog = mutation_catalog()
    indexed = {row["subject"]: row for row in rows}
    laws = [f"S{number}" for number in range(1, 7)]
    green = len(rows) == 7 and all(indexed.get("lawful", {}).get(law) == "PASS" for law in laws)
    for mutant in catalog:
        row = indexed.get(mutant["subject"], {})
        failed = [law for law in laws if row.get(law, "PASS") != "PASS"]
        green = green and failed == [mutant["red_law"]] and row.get(mutant["red_law"], "").startswith("FAIL:")
    return green


def signature_oracle() -> bool:
    rows = table(ENVELOPE)
    if len(rows) != 1:
        return False
    row = rows[0]
    framed = b"".join(
        len(value.encode()).to_bytes(8, "big") + value.encode()
        for value in (row["key"], row["tenant"], row["subject"])
    )
    return hashlib.sha256(framed).hexdigest() == row["signature"]


def independent_side() -> tuple[bool, bool]:
    print("\nindependent oracle — authored matrices and Python framing/signature implementation\n")
    try:
        operations, refusals = operation_oracle()
        namespaces = namespace_oracle()
        revocation = revocation_oracle()
        verdicts = verdict_oracle()
        signature = signature_oracle()
    except (OSError, KeyError, ValueError) as error:
        print(f"  FAIL  independent oracle {error}")
        return False, False
    checks = (
        ("operation-matrix-independent", operations, "five operations x own/foreign/absent"),
        ("refusal-matrix-independent", refusals, "foreign/absent byte result and mutation count"),
        ("namespace-output-independent", namespaces, "five emitted length-framed pairs"),
        ("revocation-table-independent", revocation, "one edge plus one bounded layer"),
        ("verdict-grid-independent", verdicts, "one control plus six exact defects"),
        ("signature-independent", signature, "one emitted SHA-256 envelope"),
    )
    for name, green, detail in checks:
        print(f"  {'ok  ' if green else 'FAIL'}  {name} {detail}")
    return all(green for _name, green, _detail in checks), signature


def oracle_side(rows: dict[str, str]) -> bool:
    print("\noracle side — complete results against thirteen exact metrics\n")
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
    print("\nartifact side — generated observations remain project-contained\n")
    snapshot = set(artifact_policy.snapshot_paths())
    ok = True
    for path in (RESULTS, ENVELOPE, NAMESPACES):
        relative = gate_common.rel(path)
        clean = path.is_file() and relative.startswith(".build/") and relative not in snapshot
        print(f"  {'ok  ' if clean else 'FAIL'}  results-untracked {relative}")
        ok = ok and clean
    return ok


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=23,
        contract=CONTRACT,
        command=GATE_COMMAND,
        expectations=EXPECTATIONS,
        register="1",
        substrate="none",
        lane="none",
        sides=SIDES,
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
        independent, signature = independent_side()
        if results["source"]:
            rows["source-scans"] = EXPECTED_RESULTS["source-scans"]
        if results["typed"]:
            rows["compile-barriers"] = EXPECTED_RESULTS["compile-barriers"]
        if results["mutant"]:
            rows["mutants"] = EXPECTED_RESULTS["mutants"]
        if signature:
            rows["independent-signature"] = EXPECTED_RESULTS["independent-signature"]
        write_results(rows)
        results["oracle"] = independent and oracle_side(rows)
        results["artifact"] = artifact_side()

    implemented = {
        "metrics": set(rows),
        "checks": set(CHECKS),
        "mutants": {row["mutant"] for row in mutant_registry.capability(CAPABILITY)},
    }
    results["surface"], surfaces = gate.surface_join(implemented)
    status = {
        surface: bool(SURFACE_EVIDENCE.get(surface))
        and rows.get(SURFACE_EVIDENCE[surface][0]) == SURFACE_EVIDENCE[surface][1]
        for surface in surfaces
    }
    status["generated-artifact-discipline"] = results["artifact"]

    decision_green = all(
        rows.get(key) == EXPECTED_RESULTS[key]
        for key in ("law-verdicts", "single-law-defects", "mutants", "compile-barriers", "source-scans")
    )
    protocol_green = all(
        rows.get(key) == EXPECTED_RESULTS[key]
        for key in ("operation-matrix", "refusal-pairs", "timing-envelope", "namespaces", "revocation-layers")
    )
    layers = {
        "Decision": "tested" if decision_green else "UNVERIFIED",
        "Protocol": "tested" if protocol_green else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={SUITE: "cabal test", COMPILE_SUITE: "GHC legal/illegal identity and scope twins"},
        checks=results,
        mutants=[{"name": row["mutant"], "status": row["red_property"]} for row in mutation_catalog()],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "envelope": "sha256:" + artifact_policy.digest(str(ENVELOPE)),
            "namespaces": "sha256:" + artifact_policy.digest(str(NAMESPACES)),
        }
        if RESULTS.is_file() and ENVELOPE.is_file() and NAMESPACES.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
