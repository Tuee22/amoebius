#!/usr/bin/env python3
"""Validate amoebius proven/tested/assumed ledger artifacts.

The schema and committed path convention are owned by
documents/engineering/testing_doctrine.md section 4.  This checker is kept
independent of the amoebius binary so a ledger cannot certify itself.

Examples:

  python3 tools/ledger_lint.py .build/runs/phase_16/<run-id>/ledger.json \
      --enumeration .build/test-surfaces/phase_16.json
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
    "tracker": "register, substrate and lane equal the tracker row",
    "architecture": "the recorded architecture is the one its lane names",
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
    "lane",
    "architecture",
    "date",
    "layers",
    "coverage",
    "ledger_hash",
}
STATUSES = {"proven", "proven-for-the-model", "tested", "assumed", "UNVERIFIED"}
LAYERS = {"Decision", "Protocol", "Runtime"}
# Section S clause 15: the closed architecture set, and the architecture each lane
# names. A lane that names one is a claim about the hardware the run executed on, so
# the two cannot disagree; a lane that names none still records where it ran.
ARCHITECTURES = {"amd64", "arm64"}
LANE_ARCHITECTURE = {
    "linux-cpu/amd64": "amd64",
    "linux-cpu/arm64": "arm64",
    "metal": "arm64",
}


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


def parse_tracker(path: Path) -> dict[int, dict[str, str]]:
    """Read the tracker's phase overview as {phase: {column name: cell}}.

    Keyed on the header row's names, never on cell positions: a positional reader
    starts reading the wrong column the moment the table gains one, which is exactly
    what the `Lane` column did to the reader this replaces.
    """
    rows: dict[int, dict[str, str]] = {}
    header: list[str] | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        cells = [cell.strip() for cell in line.split("|")]
        if len(cells) < 4 or cells[0] or cells[-1]:
            continue
        cells = cells[1:-1]
        # README contains historical phase tables before the authoritative Phase
        # overview. Reset on every exact `Phase` header so the last such table owns the
        # rows instead of freezing the parser onto the first historical table it sees.
        if cells[0].lower() == "phase":
            header = [cell.lower() for cell in cells]
            continue
        if header is None:
            continue
        if len(cells) != len(header) or not re.fullmatch(r"\d+", cells[0]):
            continue
        rows[int(cells[0])] = dict(zip(header, cells))
    if not rows:
        raise ValueError(f"no phase rows found in tracker {path}")
    return rows


def declared(cell: str) -> str:
    """The value a tracker cell declares, without its backticks or trailing prose.

    The separator is a *spaced* em dash, because the no-register marker is an em dash
    on its own and a bare split would read it as an empty declaration.
    """
    return re.split(r"\s+—\s+|\s+\(", cell, 1)[0].replace("`", "").strip()


def load_enumeration(path: Path) -> set[str]:
    """Read a run-time surface enumeration.

    `repository_layout_doctrine.md` section 3.1 places the enumeration at
    `.build/test-surfaces/phase_*.json`; the plain-text form is still read so a corpus
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
    lane = value.get("lane")
    architecture = value.get("architecture")
    if not isinstance(register, str) or not register:
        problems.append(Problem("schema", "register must be a non-empty string"))
    if not isinstance(substrate, str) or not substrate:
        problems.append(Problem("schema", "substrate must be a non-empty string"))
    if not isinstance(lane, str) or not lane:
        problems.append(Problem("schema", "lane must be a non-empty string"))
    if architecture not in ARCHITECTURES:
        problems.append(
            Problem("architecture", f"architecture {architecture!r} is not one of {sorted(ARCHITECTURES)}")
        )
    elif isinstance(lane, str) and LANE_ARCHITECTURE.get(lane, architecture) != architecture:
        problems.append(
            Problem(
                "architecture",
                f"lane {lane!r} names {LANE_ARCHITECTURE[lane]}, but the run recorded {architecture}",
            )
        )

    problems.extend(validate_rows(value.get("layers"), "layers", "name"))
    problems.extend(validate_rows(value.get("coverage"), "coverage", "surface"))

    try:
        tracker = parse_tracker(tracker_path)
    except (OSError, ValueError) as exc:
        problems.append(Problem("tracker", str(exc)))
        tracker = {}
    if isinstance(phase, int):
        row = tracker.get(phase)
        if row is None:
            problems.append(Problem("tracker", f"phase {phase} has no tracker row"))
        else:
            for field, recorded in (
                ("substrate", substrate),
                ("lane", lane),
                ("register", register),
            ):
                if field not in row:
                    problems.append(Problem("tracker", f"the tracker declares no {field} column"))
                    continue
                expected = declared(row[field])
                if recorded != expected:
                    problems.append(
                        Problem("tracker", f"{field} {recorded!r} != tracker value {expected!r}")
                    )

        # A ledger emitted into the run bundle is named by the bundle, not by the
        # phase: repository-layout doctrine section 3.1 fixes it at
        # .build/runs/<phase>/<run-id>/ledger.json. The phase-named form is only the
        # legacy committed convention, and that convention is what is being retired.
        expected_name = f"phase_{phase:02d}_ledger.json"
        resolved = ledger_path.resolve()
        in_run_bundle = (ROOT / ".build" / "runs") in resolved.parents
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
        path = CORPUS / name / "ledger.json"
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
