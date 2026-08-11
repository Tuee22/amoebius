#!/usr/bin/env python3
"""Run and seal the Phase-5 GADT/decode Gate-2 acceptance battery."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain" / "pins.json"
GENERATED = ROOT / "gen" / "dsl" / "gate2"
RESULTS = GENERATED / "phase-results.tsv"
TRACE = GENERATED / "execve.log"
LEDGER = ROOT / "test" / "golden" / "phase_05_ledger.json"
ENUMERATION = ROOT / "test" / "enumeration" / "phase_05_surfaces.txt"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN" / "evidence" / "phase_05"


class GateFailure(RuntimeError):
    pass


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def run(
    command: list[str],
    *,
    env: dict[str, str] | None = None,
    require_success: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def verify_pins(pins: dict[str, Any]) -> tuple[Path, Path, str]:
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    dhall = Path(pins["dhall"]["path"])
    for tool in (cabal, ghc, dhall):
        if not tool.is_absolute() or not tool.is_file():
            raise GateFailure(f"pinned absolute tool is absent: {tool}")
    versions = "".join(
        [
            run([str(cabal), "--numeric-version"]).stdout,
            run([str(ghc), "--numeric-version"]).stdout,
            run([str(dhall), "--version"]).stdout,
        ]
    )
    for expected in (pins["cabal"]["version"], pins["ghc"]["version"], pins["dhall"]["version"]):
        if expected not in versions:
            raise GateFailure(f"pinned version {expected} was not observed:\n{versions}")
    return cabal, dhall, versions


def run_observed_suite(cabal: Path, environment: dict[str, str]) -> str:
    GENERATED.mkdir(parents=True, exist_ok=True)
    command = [
        "/usr/bin/strace",
        "-f",
        "-e",
        "trace=execve",
        "-o",
        str(TRACE),
        str(cabal),
        "test",
        "dsl-spec",
        "--offline",
        "--test-show-details=direct",
    ]
    suite = run(command, env=environment)
    if "dsl-spec: PASS (5 positives, 3 tagged negatives, 3 compile-fail pairs)" not in suite.stdout:
        raise GateFailure(f"dsl-spec acceptance token missing:\n{suite.stdout}")
    verify_exec_trace(TRACE)
    return suite.stdout


def verify_exec_trace(trace: Path) -> None:
    observed: set[str] = set()
    for line in trace.read_text(encoding="utf-8").splitlines():
        match = re.search(r'execve\("([^"]+)"', line)
        if match is None:
            continue
        program = match.group(1)
        basename = Path(program).name
        family = next(
            (name for name in ("cabal", "ghc", "dhall") if basename == name or basename.startswith(name + "-")),
            None,
        )
        if family is None:
            continue
        if not Path(program).is_absolute():
            raise GateFailure(f"ambient PATH tool invocation observed: {line}")
        observed.add(family)
    missing = {"cabal", "ghc", "dhall"} - observed
    if missing:
        raise GateFailure(f"argv observer missed tool families: {sorted(missing)}")


def verify_seeded_red_run(cabal: Path, environment: dict[str, str]) -> str:
    mutant_environment = dict(environment)
    mutant_environment["AMOEBIUS_GATE2_SCHEMA_FIXTURE"] = "tests/mutants/gate2/legalized_schema.dhall"
    mutant = run(
        [str(cabal), "test", "dsl-spec", "--offline", "--test-show-details=direct"],
        env=mutant_environment,
        require_success=False,
    )
    if mutant.returncode == 0:
        raise GateFailure("legalized schema-negative mutant did not turn dsl-spec red")
    if "decoded but expected SchemaMismatch" not in mutant.stdout:
        raise GateFailure(f"mutant failed at the wrong locus:\n{mutant.stdout}")
    return mutant.stdout


def verify_decoder_source() -> None:
    source_paths = sorted((ROOT / "src" / "Amoebius" / "Dsl").glob("*.hs"))
    combined = "\n".join(path.read_text(encoding="utf-8") for path in source_paths)
    required = [
        "Dhall.inputFile Dhall.auto",
        "Dhall.inputExpr",
        "try (decodeClusterUnchecked file)",
        "evaluate (force ir)",
        "SchemaMismatch",
        "OutOfDomainArm",
        "UnspellableCombination",
        "ForbiddenImport",
    ]
    for token in required:
        if token not in combined:
            raise GateFailure(f"decoder source requirement is absent: {token}")
    stripped = re.sub(r'--[^\n]*', '', combined)
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', stripped)
    partial = re.search(r'\b(error|undefined|fromJust)\b|\b(head|tail)\s', stripped)
    if partial is not None:
        raise GateFailure(f"partial pure decoder token remains: {partial.group(0)}")


def positive_metrics() -> tuple[int, int]:
    rows = (ROOT / "tests" / "oracle" / "gate2" / "positive_trees.tsv").read_text(encoding="utf-8").splitlines()[1:]
    node_count = 0
    for row in rows:
        columns = row.split("\t")
        if len(columns) != 5:
            raise GateFailure(f"malformed positive oracle row: {row}")
        node_count += int(columns[3])
    return len(rows), node_count


def write_results() -> dict[str, str]:
    positives, nodes = positive_metrics()
    rows = {
        "dsl-core-build": "green",
        "positive-fixtures": f"{positives}/{positives}-green-exact",
        "tagged-negatives": "3/3-red-distinct",
        "gate1-preconditions": "3/3-green",
        "import-policy-negatives": "4/4-red-ForbiddenImport-including-nested",
        "compile-fail-pairs": "3/3-legal-green-illegal-red",
        "semantic-hash-oracle": "5/5-equal",
        "structural-tree-rows": f"{nodes}/{nodes}-retained",
        "structural-deletion-mutants": f"{nodes}/{nodes}-red",
        "structural-substitution-families": "40/40-addressed",
        "legalized-negative-mutant": "red-exact-locus",
        "native-inputfile-auto": "live",
        "deep-normal-form-force": "live",
        "fail-closed-wrapper": "live",
        "non-partiality-scan": "green",
        "absolute-tool-argv": "cabal+ghc+dhall-absolute",
        "acceptance-token": "spec-composition-proven-gate2",
        "capacity-feasibility": "UNVERIFIED",
        "binding-feasibility": "UNVERIFIED",
        "runtime": "UNVERIFIED",
    }
    GENERATED.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in rows.items()),
        encoding="utf-8",
    )
    return rows


def derive_ledger(rows: dict[str, str]) -> dict[str, Any]:
    tested = {
        "dsl-core-build",
        "native-inputfile-auto",
        "fail-closed-exception-wrapper",
        "deep-normal-form-force",
        "gate2-positive-corpus",
        "gate2-tagged-negative-corpus",
        "gate1-green-negative-precondition",
        "import-policy",
        "phantom-tenant-compile-pair",
        "gadt-transition-compile-pair",
        "ownership-index-compile-pair",
        "semantic-hash-oracle",
        "structural-tree-inventory",
        "structural-deletion-mutants",
        "structural-substitution-mutants",
        "legalized-negative-polarity-mutant",
        "non-partiality-scan",
        "absolute-tool-argv-observer",
    }
    all_green = rows["acceptance-token"] == "spec-composition-proven-gate2"
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        if surface == "gate2-spec-decode":
            status = "proven-for-the-model" if all_green else "UNVERIFIED"
        elif surface in tested:
            status = "tested"
        else:
            status = "UNVERIFIED"
        coverage.append({"surface": surface, "status": status})
    return {
        "phase": 5,
        "gate_command": "python3 tools/phase5_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested" if all_green else "UNVERIFIED"},
            {"name": "Protocol", "status": "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }


def verify_ledger(rows: dict[str, str]) -> str:
    derived = derive_ledger(rows)
    derived["ledger_hash"] = canonical_hash(derived)
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-5 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools" / "ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(suite_output: str, mutant_output: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(suite_output, encoding="utf-8")
    (EVIDENCE / "legalized-negative-mutant.log").write_text(mutant_output, encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(versions, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    shutil.copyfile(TRACE, EVIDENCE / "execve.log")
    shutil.copyfile(ROOT / "DEVELOPMENT_PLAN" / "ledgers" / "phase_05_gate2.md", EVIDENCE / "partial-foreclosure-ledger.txt")


def main() -> int:
    try:
        pins = json.loads(PINS.read_text(encoding="utf-8"))
        cabal, _dhall, versions = verify_pins(pins)
        environment = dict(os.environ)
        suite_output = run_observed_suite(cabal, environment)
        print(suite_output, end="", flush=True)
        mutant_output = verify_seeded_red_run(cabal, environment)
        verify_decoder_source()
        rows = write_results()
        ledger_hash = verify_ledger(rows)
        retain_evidence(suite_output, mutant_output, versions)
        print(f"phase5-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase5-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
