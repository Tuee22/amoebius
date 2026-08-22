#!/usr/bin/env python3
"""Run source-bound GHC compile-fail twins against structured diagnostic pins."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
from dataclasses import dataclass, replace
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = ROOT / "test/oracle/compile_fail_harness/fixtures.tsv"
DEFAULT_RESULTS = ROOT / ".build/checkers/compile-fail/results.tsv"
BUILD_ROOT = ROOT / ".build/tmp/compile-fail-harness"
WRONG_REASON = BUILD_ROOT / "WrongReason.hs"
FORBIDDEN_MESSAGES = ("Could not find module", "Variable not in scope", "parse error")


class HarnessFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class Pair:
    claim: str
    owner_phase: int
    legal: Path
    illegal: Path
    dimension: str
    code: int
    line: int
    column: int
    message_fragments: tuple[str, ...]
    legal_probe: str
    illegal_probe: str


@dataclass(frozen=True)
class Diagnostic:
    code: int
    line: int
    column: int
    severity: str
    message: str


@dataclass(frozen=True)
class Observation:
    claim: str
    legal_digest: str
    illegal_digest: str
    diagnostic_count: int


def read_manifest(path: Path) -> list[Pair]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    expected_columns = {
        "claim", "owner_phase", "legal", "illegal", "dimension", "code", "line", "column",
        "message_fragments", "legal_probe", "illegal_probe",
    }
    if not rows or set(rows[0]) != expected_columns:
        raise HarnessFailure(f"manifest columns differ from {sorted(expected_columns)}")
    pairs: list[Pair] = []
    for row in rows:
        fragments = tuple(part for part in row["message_fragments"].split(";;") if part)
        if not fragments:
            raise HarnessFailure(f"{row['claim']}: no diagnostic message fragment")
        pair = Pair(
            claim=row["claim"], owner_phase=int(row["owner_phase"]),
            legal=ROOT / row["legal"], illegal=ROOT / row["illegal"],
            dimension=row["dimension"], code=int(row["code"]), line=int(row["line"]),
            column=int(row["column"]), message_fragments=fragments,
            legal_probe=row["legal_probe"], illegal_probe=row["illegal_probe"],
        )
        validate_pair_shape(pair)
        pairs.append(pair)
    if len({pair.claim for pair in pairs}) != len(pairs):
        raise HarnessFailure("manifest repeats a claim")
    if len({pair.illegal for pair in pairs}) != len(pairs):
        raise HarnessFailure("manifest repeats an illegal fixture")
    return pairs


def validate_pair_shape(pair: Pair) -> None:
    for role, path in (("legal", pair.legal), ("illegal", pair.illegal)):
        if not path.is_file() or ROOT not in path.parents:
            raise HarnessFailure(f"{pair.claim}: {role} fixture is absent or outside the checkout")
        if "test/negative/compile_fail/" not in path.relative_to(ROOT).as_posix():
            raise HarnessFailure(f"{pair.claim}: {role} fixture is outside test/negative/compile_fail")
    legal_text = pair.legal.read_text(encoding="utf-8")
    illegal_text = pair.illegal.read_text(encoding="utf-8")
    if not pair.dimension.strip() or pair.legal_probe not in legal_text or pair.legal_probe in illegal_text:
        raise HarnessFailure(f"{pair.claim}: legal twin probe does not isolate {pair.dimension}")
    if pair.illegal_probe not in illegal_text or pair.illegal_probe in legal_text:
        raise HarnessFailure(f"{pair.claim}: illegal twin probe does not isolate {pair.dimension}")


def compile_source(ghc: Path, source: Path) -> subprocess.CompletedProcess[str]:
    if not ghc.is_absolute() or not ghc.is_file():
        raise HarnessFailure(f"GHC path is not an absolute file: {ghc}")
    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [
            str(ghc), "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024",
            "-isrc/calculus-composition", "-isrc", f"-outputdir={BUILD_ROOT}",
            "-package", "base", "-package", "bytestring", "-package", "containers",
            "-package", "deepseq", "-package", "text", str(source),
        ],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )


def diagnostics(output: str) -> list[Diagnostic]:
    found: list[Diagnostic] = []
    for line in output.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(value, dict) or value.get("severity") != "Error":
            continue
        span = value.get("span", {})
        start = span.get("start", {}) if isinstance(span, dict) else {}
        messages = value.get("message", [])
        if not isinstance(messages, list):
            messages = [str(messages)]
        found.append(Diagnostic(
            code=int(value.get("code", -1)), line=int(start.get("line", -1)),
            column=int(start.get("column", -1)), severity=str(value.get("severity", "")),
            message="\n".join(str(message) for message in messages),
        ))
    return found


def validate_illegal(pair: Pair, result: subprocess.CompletedProcess[str], *, accept_any: bool = False) -> int:
    errors = diagnostics(result.stdout)
    if result.returncode == 0 or not errors:
        raise HarnessFailure(f"{pair.claim}: illegal fixture compiled or emitted no structured error")
    if accept_any:
        return len(errors)
    if any(fragment in error.message for error in errors for fragment in FORBIDDEN_MESSAGES):
        raise HarnessFailure(f"{pair.claim}: illegal fixture failed for an unrelated compiler reason")
    if {error.code for error in errors} != {pair.code}:
        raise HarnessFailure(
            f"{pair.claim}: diagnostic codes {sorted({error.code for error in errors})} != [{pair.code}]"
        )
    pinned = [
        error for error in errors
        if error.code == pair.code and error.line == pair.line and error.column == pair.column
    ]
    if len(pinned) != 1:
        raise HarnessFailure(
            f"{pair.claim}: expected one diagnostic at {pair.line}:{pair.column}, got {len(pinned)}"
        )
    missing = [fragment for fragment in pair.message_fragments if fragment not in pinned[0].message]
    if missing:
        raise HarnessFailure(f"{pair.claim}: pinned diagnostic lacks {missing}")
    return len(errors)


def evaluate_pair(ghc: Path, pair: Pair, *, skip_positive: bool = False, accept_any: bool = False) -> Observation:
    if not skip_positive:
        legal = compile_source(ghc, pair.legal)
        if legal.returncode != 0 or diagnostics(legal.stdout):
            raise HarnessFailure(f"{pair.claim}: legal counterpart failed\n{legal.stdout[-4000:]}")
    illegal = compile_source(ghc, pair.illegal)
    count = validate_illegal(pair, illegal, accept_any=accept_any)
    return Observation(
        claim=pair.claim,
        legal_digest=digest(pair.legal), illegal_digest=digest(pair.illegal), diagnostic_count=count,
    )


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_results(path: Path, pairs: list[Pair], observations: list[Observation]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = [
        ("pair-count", str(len(pairs))),
        ("claim-count", str(len({pair.claim for pair in pairs}))),
        ("owner-count", str(len({pair.owner_phase for pair in pairs}))),
        ("legal-green-count", str(len(observations))),
        ("illegal-red-count", str(len(observations))),
        ("diagnostic-code-pin-count", str(len(observations))),
        ("source-span-pin-count", str(len(observations))),
        ("message-pin-count", str(len(observations))),
        ("twin-probe-count", str(len(observations))),
        ("source-digest-count", str(sum(
            int(len(item.legal_digest) == 64) + int(len(item.illegal_digest) == 64)
            for item in observations
        ))),
        ("structured-diagnostic-count", str(sum(item.diagnostic_count for item in observations))),
    ]
    path.write_text("metric\tvalue\n" + "\n".join(f"{key}\t{value}" for key, value in rows) + "\n", encoding="utf-8")


def run_mutant(ghc: Path, pair: Pair, mutant: str) -> None:
    if mutant == "accept-any-failure":
        WRONG_REASON.parent.mkdir(parents=True, exist_ok=True)
        WRONG_REASON.write_text("module WrongReason where\nvalue =\n", encoding="utf-8")
        challenge = replace(pair, illegal=WRONG_REASON)
        result = compile_source(ghc, challenge.illegal)
        try:
            validate_illegal(challenge, result, accept_any=True)
        except HarnessFailure:
            return
        raise HarnessFailure("accept-any-failure-locus: wrong diagnostic was accepted")
    if mutant == "drop-positive-counterpart":
        challenge = replace(pair, legal=pair.illegal)
        try:
            evaluate_pair(ghc, challenge, skip_positive=True)
        except HarnessFailure:
            return
        raise HarnessFailure("drop-positive-counterpart-locus: red twin was accepted as its own positive")
    if mutant == "impossible-diagnostic-pin":
        challenge = replace(pair, code=0)
        try:
            evaluate_pair(ghc, challenge)
        except HarnessFailure as problem:
            raise HarnessFailure(f"impossible-diagnostic-pin-locus: {problem}") from problem
        raise HarnessFailure("impossible-diagnostic-pin-locus: impossible code unexpectedly matched")
    raise HarnessFailure(f"unknown mutant {mutant!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghc", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--results", type=Path, default=DEFAULT_RESULTS)
    parser.add_argument("--mutant", choices=(
        "accept-any-failure", "drop-positive-counterpart", "impossible-diagnostic-pin",
    ))
    options = parser.parse_args()
    try:
        pairs = read_manifest(options.manifest)
        if options.mutant:
            run_mutant(options.ghc, pairs[0], options.mutant)
        observations = [evaluate_pair(options.ghc, pair) for pair in pairs]
        write_results(options.results, pairs, observations)
    except (OSError, ValueError, HarnessFailure) as problem:
        print(f"compile-fail-harness: FAIL: {problem}")
        return 1
    print(
        "compile-fail-harness: PASS "
        f"({len(pairs)} legal/illegal twins, {len({pair.code for pair in pairs})} diagnostic codes, "
        f"{len({pair.owner_phase for pair in pairs})} owner phases)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
