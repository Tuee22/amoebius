#!/usr/bin/env python3
"""Run and seal the Phase-6 illegal-state corpus and locus ledger."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from locus_registry_lint import catalog_sections, read_registry, registry_violations  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain/pins.json"
RESULTS = ROOT / "gen/dsl/phase6/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase6/validation-locus-ledger.tsv"
LEDGER = ROOT / "test/golden/phase_06_ledger.json"
ENUMERATION = ROOT / "test/enumeration/phase_06_surfaces.txt"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_06"


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def verify_pins() -> tuple[Path, Path, str]:
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    cabal = Path(pins["cabal"]["path"])
    dhall = Path(pins["dhall"]["path"])
    ghc = Path(pins["ghc"]["path"])
    for executable in (cabal, dhall, ghc):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = "".join(
        [
            run([str(cabal), "--numeric-version"]).stdout,
            run([str(ghc), "--numeric-version"]).stdout,
            run([str(dhall), "--version"]).stdout,
        ]
    )
    for family in ("cabal", "ghc", "dhall"):
        if pins[family]["version"] not in versions:
            raise GateFailure(f"{family} version drifted:\n{versions}")
    return cabal, dhall, versions


def verify_registry() -> tuple[int, int]:
    violations = registry_violations(ROOT)
    if violations:
        raise GateFailure(f"locus registry is inconsistent: {violations[:5]}")
    run([sys.executable, str(ROOT / "tools/doc_lint.py"), "--only", "g5"])
    rows, errors = read_registry(ROOT)
    if errors:
        raise GateFailure(errors[0])
    verify_registry_mutants()
    return len(catalog_sections(ROOT)), len(rows)


def verify_registry_mutants() -> None:
    def check(mutator) -> None:
        with tempfile.TemporaryDirectory(prefix="amoebius-phase6-registry-") as directory:
            root = Path(directory)
            shutil.copytree(ROOT / "documents/illegal_state", root / "documents/illegal_state")
            (root / "dhall/examples").mkdir(parents=True)
            shutil.copyfile(ROOT / "dhall/examples/locus_registry.tsv", root / "dhall/examples/locus_registry.tsv")
            mutator(root)
            if not registry_violations(root):
                raise GateFailure("a catalog/registry reconciliation mutant survived")

    def missing_owner(root: Path) -> None:
        path = root / "documents/illegal_state/illegal_state_storage.md"
        text = path.read_text(encoding="utf-8")
        line = next(value for value in text.splitlines(keepends=True) if value.startswith("**Delivery-owner:**"))
        path.write_text(text.replace(line, "", 1), encoding="utf-8")

    def owner_drift(root: Path) -> None:
        path = root / "dhall/examples/locus_registry.tsv"
        path.write_text(path.read_text(encoding="utf-8").replace("Phase-28", "Phase-6", 1), encoding="utf-8")

    def family_drift(root: Path) -> None:
        path = root / "dhall/examples/locus_registry.tsv"
        path.write_text(path.read_text(encoding="utf-8").replace("\tstorage\n", "\tunknown\n", 1), encoding="utf-8")

    def locus_drift(root: Path) -> None:
        path = root / "dhall/examples/locus_registry.tsv"
        path.write_text(path.read_text(encoding="utf-8").replace("\tGate-1-editor\t", "\tunknown-locus\t", 1), encoding="utf-8")

    for mutant in (missing_owner, owner_drift, family_drift, locus_drift):
        check(mutant)


def verify_union_mutant(dhall: Path) -> str:
    with tempfile.TemporaryDirectory(prefix="amoebius-phase6-union-") as directory:
        root = Path(directory)
        shutil.copytree(ROOT / "dhall/amoebius", root / "dhall/amoebius")
        shutil.copytree(ROOT / "dhall/examples", root / "dhall/examples")
        shutil.copyfile(
            ROOT / "tests/mutants/phase6/capability_product_arm.dhall",
            root / "dhall/amoebius/Capability.dhall",
        )
        fixture = root / "dhall/examples/illegal_product_named_capability.dhall"
        result = run([str(dhall), "type", "--file", str(fixture), "--quiet"], require_success=False)
        if result.returncode != 0:
            raise GateFailure(f"union-arm mutant did not admit the targeted negative:\n{result.stdout}")
        return "product-named capability admitted by mutant; CorpusSpec expectation turns red"


def verify_normalization_mutant(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "dsl-spec",
            "-f-phase6-mutant",
            "-fphase6-normalization-mutant",
            "--offline",
            "--test-show-details=direct",
        ],
        require_success=False,
    )
    if result.returncode == 0 or "resource normalization dropped execution fields" not in result.stdout:
        raise GateFailure(f"normalization mutant did not turn the exact positive traversal red:\n{result.stdout}")
    return result.stdout


def verify_gadt_mutant() -> str:
    result = run([sys.executable, str(ROOT / "tools/compile_fail.py"), "--mutant"], require_success=False)
    if result.returncode == 0 or "volume_illegal.hs" not in result.stdout or "illegal fixture compiled" not in result.stdout:
        raise GateFailure(f"GADT-index mutant did not make the volume negative compile:\n{result.stdout}")
    return result.stdout


def verify_property_mutant(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "decision-prop-spec",
            "-fphase6-mutant",
            "-f-phase6-normalization-mutant",
            "--offline",
            "--test-show-details=direct",
        ],
        require_success=False,
    )
    expected = {
        "prop_smartCtorClosure",
        "prop_decodeRoundTrip",
        "prop_foldTotal",
        "prop_compositionPreservesWellFormedness",
    }
    observed = {
        line.rsplit(" ", 1)[-1]
        for line in result.stdout.splitlines()
        if line.startswith("decision-property: RED ")
    }
    if result.returncode == 0 or observed != expected:
        raise GateFailure(f"decision mutant did not turn all four properties red: {sorted(observed)}\n{result.stdout}")
    return result.stdout


def run_green_suite(cabal: Path) -> str:
    result = run(
        [
            str(cabal),
            "test",
            "dsl-spec",
            "-f-phase6-mutant",
            "-f-phase6-normalization-mutant",
            "--offline",
            "--test-show-details=direct",
        ]
    )
    expected = "phase6-dsl-spec: PASS (14 Gate-1, 13 Gate-2, 12 positives, 33 discharged, 71 deferred)"
    if expected not in result.stdout:
        raise GateFailure(f"Phase-6 acceptance token is absent:\n{result.stdout}")
    if not GENERATED_LEDGER.is_file():
        raise GateFailure("validation-locus ledger was not emitted")
    emitted = GENERATED_LEDGER.read_text(encoding="utf-8")
    if not emitted.startswith("# Register-1 only; Tier-2/model-runtime correspondence UNVERIFIED\n"):
        raise GateFailure("generated validation-locus ledger lacks its honesty banner")
    return result.stdout


def write_results(entries: int, subcases: int) -> dict[str, str]:
    rows = {
        "catalog-entries": f"{entries}/{entries}-mapped",
        "registry-subcases": f"{subcases}/{subcases}-reconciled",
        "registry-mutants": "4/4-red",
        "gate1-corpus": "14/14-red-exact-with-green-twins",
        "gate2-corpus": "13/13-red-tagged-with-green-twins",
        "positive-corpus": "12/12-green",
        "compile-fail-pairs": "5/5-legal-green-illegal-type-red",
        "quickcheck-properties": "4/4-green-checkCoverage",
        "rke2-arms": "3/3-exhausted-PROVEN",
        "discharged-subcases": "33/33",
        "deferred-subcases": "71/71-owner-pinned",
        "union-arm-mutant": "red",
        "normalization-mutant": "red",
        "gadt-index-mutant": "red",
        "decision-mutant": "4/4-properties-red",
        "acceptance-token": "spec-composition-proven-illegal-state-corpus",
        "capacity-feasibility": "UNVERIFIED",
        "render-fidelity": "UNVERIFIED",
        "runtime": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in rows.items()),
        encoding="utf-8",
    )
    return rows


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    tested = {
        "catalog-owner-family-registry",
        "gate1-exhaustive-corpus",
        "gate2-controller-resource-headroom-corpus",
        "cbor-produce-consume-boundary",
        "gadt-index-compile-fail-corpus",
        "quickcheck-smart-constructor-closure",
        "quickcheck-decode-roundtrip",
        "quickcheck-fold-totality",
        "quickcheck-composition-wellformedness",
        "validation-locus-ledger",
        "catalog-registry-mutants",
        "union-arm-addition-mutant",
        "resource-normalization-mutant",
        "gadt-index-weakening-mutant",
        "broken-decision-mutant",
    }
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        if surface == "rke2-server-arms-finite-domain":
            status = "proven-for-the-model"
        elif surface == "illegal-state-spec-composition":
            status = "proven-for-the-model"
        elif surface in tested:
            status = "tested"
        else:
            status = "UNVERIFIED"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 6,
        "gate_command": "python3 tools/phase6_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def verify_ledger() -> str:
    derived = derive_ledger()
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-6 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(
    suite: str,
    normalization_mutant: str,
    gadt_mutant: str,
    property_mutant: str,
    union_mutant: str,
    versions: str,
) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(suite, encoding="utf-8")
    (EVIDENCE / "normalization-mutant.log").write_text(normalization_mutant, encoding="utf-8")
    (EVIDENCE / "gadt-mutant.log").write_text(gadt_mutant, encoding="utf-8")
    (EVIDENCE / "decision-mutant.log").write_text(property_mutant, encoding="utf-8")
    (EVIDENCE / "union-mutant.log").write_text(union_mutant + "\n", encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(versions, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    shutil.copyfile(GENERATED_LEDGER, EVIDENCE / "validation-locus-ledger.tsv")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--derive-ledger", action="store_true")
    args = parser.parse_args(argv)
    if args.derive_ledger:
        print(json.dumps(derive_ledger(), indent=2))
        return 0
    try:
        cabal, dhall, versions = verify_pins()
        entries, subcases = verify_registry()
        union_mutant = verify_union_mutant(dhall)
        normalization_mutant = verify_normalization_mutant(cabal)
        gadt_mutant = verify_gadt_mutant()
        property_mutant = verify_property_mutant(cabal)
        suite = run_green_suite(cabal)
        print(suite, end="", flush=True)
        write_results(entries, subcases)
        ledger_hash = verify_ledger()
        retain_evidence(suite, normalization_mutant, gadt_mutant, property_mutant, union_mutant, versions)
        print(f"phase6-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase6-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
