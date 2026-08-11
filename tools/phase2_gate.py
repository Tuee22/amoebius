#!/usr/bin/env python3
"""Run the complete Phase-2 formal-model acceptance gate."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PINS_PATH = ROOT / "toolchain" / "pins.json"
RUNTIME = ROOT / "toolchain" / "runtime"
RESULTS = ROOT / "gen" / "tla" / "formal-model-spec" / "phase-results.tsv"
LEDGER = ROOT / "test" / "golden" / "phase_02_ledger.json"
ENUMERATION = ROOT / "test" / "enumeration" / "phase_02_surfaces.txt"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN" / "evidence" / "phase_02"


class GateFailure(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_hash(value: dict[str, object]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        return
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        print(f"phase2-gate: acquiring {url}", flush=True)
        with urllib.request.urlopen(url) as response, temporary_path.open("wb") as output:
            shutil.copyfileobj(response, output)
        temporary_path.replace(destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def require_sha256(path: Path, expected: str) -> None:
    actual = sha256(path)
    if actual != expected:
        raise GateFailure(f"checksum mismatch for {path}: {actual} != {expected}")


def run(command: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def ensure_toolchain(pins: dict[str, object]) -> tuple[Path, Path, str]:
    java_pin = pins["java"]
    tla_pin = pins["tla2tools"]
    assert isinstance(java_pin, dict) and isinstance(tla_pin, dict)

    java_archive = RUNTIME / "downloads" / Path(str(java_pin["url"])).name
    download(str(java_pin["url"]), java_archive)
    require_sha256(java_archive, str(java_pin["sha256"]))

    java = Path(str(java_pin["path"]))
    if not java.is_file():
        java_root = java.parent.parent
        java_root.mkdir(parents=True, exist_ok=True)
        with tarfile.open(java_archive, "r:gz") as archive:
            members = archive.getmembers()
            for member in members:
                parts = Path(member.name).parts
                member.name = str(Path(*parts[1:])) if len(parts) > 1 else ""
            archive.extractall(java_root, members=(member for member in members if member.name), filter="data")

    jar = Path(str(tla_pin["path"]))
    download(str(tla_pin["url"]), jar)
    require_sha256(jar, str(tla_pin["sha256"]))

    java_version = run([str(java), "-version"]).stdout
    if 'version "21.0.12"' not in java_version:
        raise GateFailure(f"unexpected Java runtime:\n{java_version}")
    help_result = subprocess.run(
        [str(java), "-jar", str(jar), "-help"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    expected_tlc = "Version 2.19 of 08 August 2024"
    if expected_tlc not in help_result.stdout:
        raise GateFailure(f"unexpected TLC runtime:\n{help_result.stdout}")
    tlc_version = next(line for line in help_result.stdout.splitlines() if expected_tlc in line)
    return java, jar, java_version + tlc_version + "\n"


def parse_results(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise GateFailure(f"formal test did not emit {path}")
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines()[1:]:
        key, value = line.split("\t", 1)
        rows[key] = value
    return rows


def require_results(rows: dict[str, str]) -> None:
    exact = {
        "toy-distinct-state-count": "8",
        "toy-safety-explorer": "green",
        "toy-safety-tlc": "green",
        "toy-state-fingerprints-equal": "yes",
        "toy-liveness-under-fairness": "green",
        "fairness-drop-liveness": "red",
        "model-safety-mutants-caught": "5/5",
        "spec-weakening-mutants-caught": "1/1",
        "renderer-golden-mutants-caught": "2/2",
        "renderer-differential-mutants-caught": "2/2",
        "case-count": "200",
        "safety-violating-count": "95",
        "constraint-boundary-count": "200",
    }
    exact.update({f"coverage-{name}": "100%" for name in (
        "BoolLiteral", "ArithmeticComparison", "Implication", "Subtraction", "FiniteSetMembership",
        "SetUnion", "SetDifference", "Cardinality", "FiniteQuantifier", "FunctionLiteral",
        "FunctionUpdate", "FunctionApplication", "Conditional", "WeakFair", "StrongFair",
        "Always", "Eventually", "LeadsTo",
    )})
    for key, expected in exact.items():
        actual = rows.get(key)
        if actual != expected:
            raise GateFailure(f"recorded result {key!r}: {actual!r} != {expected!r}")


def derive_ledger(rows: dict[str, str]) -> dict[str, object]:
    safety_green = rows["toy-safety-explorer"] == rows["toy-safety-tlc"] == "green"
    liveness_green = rows["toy-liveness-under-fairness"] == "green"
    all_differential = rows["case-count"] == "200" and rows["toy-state-fingerprints-equal"] == "yes"
    return {
        "phase": 2,
        "gate_command": "python3 tools/phase2_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested" if all_differential else "UNVERIFIED"},
            {"name": "Protocol", "status": "proven-for-the-model" if safety_green and liveness_green else "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": [
            {"surface": "formal-model-edsl", "status": "tested"},
            {"surface": "interpret-hand-oracle", "status": "tested"},
            {"surface": "toy-safety", "status": "proven-for-the-model" if safety_green else "UNVERIFIED"},
            {"surface": "toy-liveness-under-fairness", "status": "proven-for-the-model" if liveness_green else "UNVERIFIED"},
            {"surface": "fairness-sensitivity", "status": "tested" if rows["fairness-drop-liveness"] == "red" else "UNVERIFIED"},
            {"surface": "tla-renderer-golden", "status": "tested" if rows["renderer-golden-mutants-caught"] == "2/2" else "UNVERIFIED"},
            {"surface": "mechanical-model-mutants", "status": "tested" if rows["model-safety-mutants-caught"] == "5/5" else "UNVERIFIED"},
            {"surface": "renderer-mutants", "status": "tested" if rows["renderer-differential-mutants-caught"] == "2/2" else "UNVERIFIED"},
            {"surface": "differential-fragment-200", "status": "tested" if all_differential else "UNVERIFIED"},
            {"surface": "constraint-boundary-semantics", "status": "tested" if rows["constraint-boundary-count"] == "200" else "UNVERIFIED"},
            {"surface": "generated-artifact-discipline", "status": "tested"},
            {"surface": "phase-3-code-correspondence", "status": "UNVERIFIED"},
            {"surface": "runtime-fidelity", "status": "UNVERIFIED"},
        ],
    }


def verify_ledger(rows: dict[str, str]) -> str:
    derived = derive_ledger(rows)
    derived["ledger_hash"] = canonical_hash(derived)
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure(
            "committed Phase-2 ledger differs from machine-derived outcomes:\n"
            + json.dumps(derived, indent=2)
        )
    run([
        sys.executable,
        str(ROOT / "tools" / "ledger_lint.py"),
        str(LEDGER),
        "--enumeration",
        str(ENUMERATION),
    ])
    return str(derived["ledger_hash"])


def retain_evidence(gate_output: str, toolchain_output: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(gate_output, encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(toolchain_output, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    toy_log = ROOT / "gen" / "tla" / "formal-model-spec" / "ToyModel-correct" / "ToyModel.tlc.log"
    shutil.copyfile(toy_log, EVIDENCE / "ToyModel.tlc.log")


def main() -> int:
    try:
        pins = json.loads(PINS_PATH.read_text(encoding="utf-8"))
        java, jar, toolchain_output = ensure_toolchain(pins)
        env = dict(os.environ)
        env.update({
            "AMOEBIUS_JAVA": str(java),
            "AMOEBIUS_TLA2TOOLS": str(jar),
            })
        cabal = str(pins["cabal"]["path"])
        gate = run([
            cabal,
            "test",
            "formal-model-spec",
            "--offline",
            "--test-show-details=direct",
        ], env=env)
        print(gate.stdout, end="", flush=True)
        rows = parse_results(RESULTS)
        require_results(rows)
        ledger_hash = verify_ledger(rows)
        retain_evidence(gate.stdout, toolchain_output)
        print(f"phase2-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, tarfile.TarError) as problem:
        print(f"phase2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
