#!/usr/bin/env python3
"""Validate amoebius proven/tested/assumed ledger artifacts.

The schema and committed path convention are owned by
documents/engineering/testing_doctrine.md section 4.  This checker is kept
independent of the amoebius binary so a ledger cannot certify itself.

Examples:

  python3 tools/ledger_lint.py gen/runs/phase_16/<run-id>/ledger.json \
      --enumeration gen/test-surfaces/phase_16.json
  python3 tools/ledger_lint.py --verify-corpus
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
TRACKER = ROOT / "DEVELOPMENT_PLAN" / "README.md"
CORPUS = HERE / "ledger_lint_corpus"

# The checker's own diagnostic vocabulary, declared so a run can enumerate what this
# side of the gate actually implements and join it to an authored expectation.
CHECKS = {
    "json": "the ledger parses as JSON",
    "schema": "required keys, row shapes, and field types",
    "phase": "phase is a non-negative integer",
    "status": "every row status is in the honesty vocabulary",
    "layers": "the three correctness layers, with out-of-register ones UNVERIFIED",
    "honesty": "a substrate-none ledger claims no runtime or unqualified proof",
    "tracker": "register and substrate equal the tracker row",
    "path": "a committed ledger uses its phase's filename",
    "enumeration": "the run enumeration loads",
    "surface": "coverage joins completely to the enumeration",
    "hash": "ledger_hash matches the canonical payload",
}

REQUIRED_KEYS = {
    "phase",
    "gate_command",
    "register",
    "substrate",
    "date",
    "layers",
    "coverage",
    "ledger_hash",
}
STATUSES = {"proven", "proven-for-the-model", "tested", "assumed", "UNVERIFIED"}
LAYERS = {"Decision", "Protocol", "Runtime"}


@dataclass(frozen=True)
class Problem:
    check: str
    message: str

    def render(self, path: Path) -> str:
        return f"{self.check}: {path}: {self.message}"


def canonical_hash(value: dict[str, Any]) -> str:
    """Hash the canonical ledger payload, excluding the self-describing hash."""
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def parse_tracker(path: Path) -> dict[int, tuple[str, str]]:
    rows: dict[int, tuple[str, str]] = {}
    row_re = re.compile(r"^\|\s*(\d+)\s*\|(?:[^|]*\|){1}\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|")
    for line in path.read_text(encoding="utf-8").splitlines():
        match = row_re.match(line)
        if match:
            rows[int(match.group(1))] = (match.group(2).strip(), match.group(3).strip())
    if not rows:
        raise ValueError(f"no phase rows found in tracker {path}")
    return rows


def load_enumeration(path: Path) -> set[str]:
    """Read a run-time surface enumeration.

    `repository_layout_doctrine.md` section 3.1 places the enumeration at
    `gen/test-surfaces/phase_*.json`; the plain-text form is still read so a corpus
    case or an older caller keeps working.
    """
    raw = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        value = json.loads(raw)
        if isinstance(value, dict):
            value = value.get("surfaces", [])
        surfaces = {str(item) for item in value}
    else:
        surfaces = {
            line.strip()
            for line in raw.splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
    if not surfaces:
        raise ValueError(f"enumeration {path} contains no surfaces")
    return surfaces


def validate_rows(value: Any, key_name: str, identity: str) -> list[Problem]:
    problems: list[Problem] = []
    if not isinstance(value, list) or not value:
        return [Problem("schema", f"{key_name} must be a non-empty array")]
    seen: set[str] = set()
    for index, row in enumerate(value):
        where = f"{key_name}[{index}]"
        if not isinstance(row, dict) or set(row) != {identity, "status"}:
            problems.append(Problem("schema", f"{where} must contain exactly {identity!r} and 'status'"))
            continue
        name = row.get(identity)
        status = row.get("status")
        if not isinstance(name, str) or not name.strip():
            problems.append(Problem("schema", f"{where}.{identity} must be a non-empty string"))
        elif name in seen:
            problems.append(Problem("schema", f"duplicate {identity} {name!r}"))
        else:
            seen.add(name)
        if status not in STATUSES:
            problems.append(Problem("status", f"{where}.status {status!r} is not in the honesty vocabulary"))
    return problems


def validate_ledger(
    ledger_path: Path,
    enumeration_path: Path,
    tracker_path: Path = TRACKER,
) -> list[Problem]:
    problems: list[Problem] = []
    try:
        value = json.loads(ledger_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [Problem("json", str(exc))]
    if not isinstance(value, dict):
        return [Problem("schema", "ledger root must be an object")]

    missing = REQUIRED_KEYS - set(value)
    extra = set(value) - REQUIRED_KEYS
    if missing:
        problems.append(Problem("schema", f"missing keys: {', '.join(sorted(missing))}"))
    if extra:
        problems.append(Problem("schema", f"unexpected keys: {', '.join(sorted(extra))}"))
    if missing:
        return problems

    phase = value.get("phase")
    if isinstance(phase, str) and phase.isdigit():
        phase = int(phase)
    if not isinstance(phase, int) or isinstance(phase, bool) or phase < 0:
        problems.append(Problem("phase", "phase must be a non-negative integer"))

    gate = value.get("gate_command")
    if not isinstance(gate, str) or not gate.strip() or "\n" in gate:
        problems.append(Problem("schema", "gate_command must be a non-empty single-line command"))

    date = value.get("date")
    try:
        if not isinstance(date, str):
            raise ValueError
        dt.date.fromisoformat(date)
    except ValueError:
        problems.append(Problem("schema", "date must be an ISO-8601 calendar date (YYYY-MM-DD)"))

    register = value.get("register")
    substrate = value.get("substrate")
    if not isinstance(register, str) or not register:
        problems.append(Problem("schema", "register must be a non-empty string"))
    if not isinstance(substrate, str) or not substrate:
        problems.append(Problem("schema", "substrate must be a non-empty string"))

    problems.extend(validate_rows(value.get("layers"), "layers", "name"))
    problems.extend(validate_rows(value.get("coverage"), "coverage", "surface"))

    try:
        tracker = parse_tracker(tracker_path)
    except (OSError, ValueError) as exc:
        problems.append(Problem("tracker", str(exc)))
        tracker = {}
    if isinstance(phase, int):
        expected = tracker.get(phase)
        if expected is None:
            problems.append(Problem("tracker", f"phase {phase} has no tracker row"))
        else:
            expected_substrate, expected_register = expected
            if substrate != expected_substrate:
                problems.append(
                    Problem("tracker", f"substrate {substrate!r} != tracker value {expected_substrate!r}")
                )
            if register != expected_register:
                problems.append(
                    Problem("tracker", f"register {register!r} != tracker value {expected_register!r}")
                )

        # A ledger emitted into the run bundle is named by the bundle, not by the
        # phase: repository-layout doctrine section 3.1 fixes it at
        # gen/runs/<phase>/<run-id>/ledger.json. The phase-named form is only the
        # legacy committed convention, and that convention is what is being retired.
        expected_name = f"phase_{phase:02d}_ledger.json"
        resolved = ledger_path.resolve()
        in_run_bundle = (ROOT / "gen" / "runs") in resolved.parents
        if (
            ledger_path.name != expected_name
            and not in_run_bundle
            and CORPUS not in resolved.parents
        ):
            problems.append(Problem("path", f"committed ledger path must end in {expected_name}"))

    layer_rows = value.get("layers")
    if isinstance(layer_rows, list):
        layer_map = {
            row.get("name"): row.get("status")
            for row in layer_rows
            if isinstance(row, dict) and isinstance(row.get("name"), str)
        }
        absent = LAYERS - set(layer_map)
        unknown = set(layer_map) - LAYERS
        if absent:
            problems.append(Problem("layers", f"missing correctness layers: {', '.join(sorted(absent))}"))
        if unknown:
            problems.append(Problem("layers", f"unknown correctness layers: {', '.join(sorted(unknown))}"))
        if register in {"1", "2", "1/2"} and layer_map.get("Runtime") != "UNVERIFIED":
            problems.append(Problem("layers", f"Register {register} requires Runtime = UNVERIFIED"))
        if register == "—":
            claimed = sorted(name for name, status in layer_map.items() if status != "UNVERIFIED")
            if claimed:
                problems.append(
                    Problem("layers", f"no-register ledger requires every correctness layer UNVERIFIED: {claimed}")
                )
        if substrate == "none":
            for name, status in layer_map.items():
                if status == "proven":
                    problems.append(
                        Problem("honesty", f"design-proof layer {name!r} must use proven-for-the-model, not proven")
                    )
                if name == "Runtime" and status not in {"UNVERIFIED", "assumed"}:
                    problems.append(
                        Problem("honesty", "a substrate-none ledger cannot claim runtime evidence")
                    )

    try:
        surfaces = load_enumeration(enumeration_path)
    except (OSError, ValueError) as exc:
        problems.append(Problem("enumeration", str(exc)))
        surfaces = set()
    coverage = value.get("coverage")
    if isinstance(coverage, list) and surfaces:
        named = {
            row.get("surface")
            for row in coverage
            if isinstance(row, dict) and isinstance(row.get("surface"), str)
        }
        for surface in sorted(named - surfaces):
            problems.append(Problem("surface", f"coverage surface {surface!r} is not in the enumeration"))
        for surface in sorted(surfaces - named):
            problems.append(Problem("surface", f"enumerated surface {surface!r} has no coverage row"))

    actual_hash = value.get("ledger_hash")
    expected_hash = canonical_hash(value)
    if actual_hash != expected_hash:
        problems.append(Problem("hash", f"ledger_hash {actual_hash!r} != {expected_hash!r}"))

    return problems


def verify_corpus() -> bool:
    manifest = CORPUS / "cases.tsv"
    rows = []
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        name, expected = line.split("\t")
        rows.append((name, expected))

    ok = True
    for name, expected in rows:
        path = CORPUS / name / "phase_16_ledger.json"
        enumeration = CORPUS / name / "surfaces.txt"
        problems = validate_ledger(path, enumeration)
        checks = {problem.check for problem in problems}
        if expected == "PASS":
            passed = not problems
        else:
            passed = expected in checks
        print(f"  {'ok  ' if passed else 'FAIL'} {name:<28} {expected}")
        if not passed:
            for problem in problems:
                print("       " + problem.render(path))
            ok = False
    return ok


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ledger", nargs="?", type=Path)
    parser.add_argument("--enumeration", type=Path)
    parser.add_argument("--tracker", type=Path, default=TRACKER)
    parser.add_argument("--verify-corpus", action="store_true")
    args = parser.parse_args(argv)

    if args.verify_corpus:
        if args.ledger or args.enumeration:
            parser.error("--verify-corpus does not accept a ledger or --enumeration")
        return 0 if verify_corpus() else 1
    if args.ledger is None or args.enumeration is None:
        parser.error("ledger and --enumeration are required")

    problems = validate_ledger(args.ledger, args.enumeration, args.tracker)
    for problem in problems:
        print(problem.render(args.ledger), file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
