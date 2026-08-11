#!/usr/bin/env python3
"""Re-run and verify the complete Register-3 Phase-25 acceptance gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_25"
ENUMERATION = ROOT / "test/enumeration/phase_25_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_25_ledger.json"
INDEX_DIGEST = "sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
UNVERIFIED = {
    "reconciler-owned-rendering-correspondence",
    "minio-backed-registry-storage-correspondence",
}


class GateFailure(RuntimeError):
    pass


def run(name: str, arguments: Sequence[str], timeout: int = 1800) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {
        "name": name,
        "command": shlex.join(arguments),
        "result": "PASS",
        "output": result.stdout.strip(),
    }


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [
        line.strip()
        for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    ledger: dict[str, Any] = {
        "phase": 25,
        "gate_command": "python3 tools/phase25_gate.py",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [
            {
                "surface": surface,
                "status": "UNVERIFIED" if surface in UNVERIFIED else "tested",
            }
            for surface in surfaces
        ],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{path}")
    return value


def validate_evidence() -> None:
    required = {
        "sprint-25.1-receipt.json",
        "sprint-25.1-mutants.json",
        "sprint-25.1-phase-results.tsv",
        "sprint-25.2-receipt.json",
        "sprint-25.2-mutants.json",
        "sprint-25.2-phase-results.tsv",
        "sprint-25.2-standup.json",
        "sprint-25.2-current-verification.json",
        "sprint-25.3-receipt.json",
        "sprint-25.3-mutants.json",
        "sprint-25.3-phase-results.tsv",
        "sprint-25.3-publication.json",
        "sprint-25.3-current-verification.json",
        "sprint-25.4-receipt.json",
        "sprint-25.4-mutants.json",
        "sprint-25.4-phase-results.tsv",
        "sprint-25.4-no-public-pull.json",
        "sprint-25.4-current-verification.json",
    }
    missing = sorted(name for name in required if not (EVIDENCE / name).is_file())
    if missing:
        raise GateFailure(f"evidence-missing:{missing}")

    receipts = [json_object(EVIDENCE / f"sprint-25.{number}-receipt.json") for number in range(1, 5)]
    if any(row.get("result") != "PASS" for row in receipts):
        raise GateFailure("sprint-receipt-not-pass")
    if any(row.get("register") != 3 or row.get("substrate") != "linux-cpu" for row in receipts):
        raise GateFailure("sprint-register-or-substrate")
    digest_keys = ("imageIndexDigest", "imageIndexDigest", "indexDigest", "imageIndexDigest")
    for receipt, key in zip(receipts, digest_keys, strict=True):
        if receipt.get(key) != INDEX_DIGEST:
            raise GateFailure(f"sprint-index-digest:{key}:{receipt.get(key)}")

    expected_mutants = (8, 2, 1, 1)
    for number, expected in enumerate(expected_mutants, start=1):
        evidence = json_object(EVIDENCE / f"sprint-25.{number}-mutants.json")
        results = evidence.get("results", [])
        if len(results) != expected or any(row.get("result") != "RED" for row in results):
            raise GateFailure(f"sprint-mutant-domain:25.{number}")

    for number in range(1, 5):
        results = (EVIDENCE / f"sprint-25.{number}-phase-results.tsv").read_text(encoding="utf-8")
        if "\tUNVERIFIED" in results or "\tFAIL" in results:
            raise GateFailure(f"sprint-results-not-green:25.{number}")

    artifact = json_object(EVIDENCE / "image-artifact.json")
    execution = json_object(EVIDENCE / "official-file-execution-join.json")
    sbom = json_object(EVIDENCE / "file-sbom.spdx.json")
    if artifact.get("imageIndexDigest") != INDEX_DIGEST or execution.get("imageIndexDigest") != INDEX_DIGEST:
        raise GateFailure("bake-artifact-byte-identity")
    if len(execution.get("rows", [])) != 46 or len(sbom.get("files", [])) != 46:
        raise GateFailure("official-file-or-sbom-domain")

    standup = json_object(EVIDENCE / "sprint-25.2-current-verification.json")
    publication = json_object(EVIDENCE / "sprint-25.3-current-verification.json")
    pull = json_object(EVIDENCE / "sprint-25.4-current-verification.json")
    if standup.get("publicRegistryTcpConnections") != 0:
        raise GateFailure("standup-public-registry-connection")
    if publication.get("manifestDigest") != INDEX_DIGEST or publication.get("rerunMutatingRequests") != 0:
        raise GateFailure("publication-current-verification")
    enforced = pull.get("enforced", {})
    if (
        enforced.get("negative", {}).get("waitingReason") not in {"ErrImagePull", "ImagePullBackOff"}
        or enforced.get("positive", {}).get("phase") != "Succeeded"
        or enforced.get("firewall", {}).get("droppedPackets", 0) <= 0
        or enforced.get("observer", {}).get("publicEstablishedConnections") != 0
    ):
        raise GateFailure("no-public-pull-current-verification")


def verify_ledger() -> str:
    derived = derive_ledger()
    committed = json_object(LEDGER)
    if committed != derived:
        raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
    run(
        "ledger-lint",
        (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION)),
    )
    return str(derived["ledger_hash"])


def execute() -> list[dict[str, str]]:
    python = sys.executable
    flags = (
        "-f-phase25-bootstrap-domain-expansion-mutant",
        "-f-phase25-handoff-without-equality-mutant",
        "-f-phase25-record-before-push-mutant",
        "-f-phase25-noop-egress-policy-mutant",
    )
    return [
        run(
            "haskell-image-spec",
            (
                "/home/matthewnowak/.ghcup/bin/cabal",
                "test",
                "phase25-image-spec",
                *flags,
                "--test-show-details=direct",
                "-j1",
            ),
        ),
        run(
            "python-image-specs",
            (python, "-m", "unittest", "discover", "-s", "test/image", "-p", "test_phase25*.py", "-v"),
        ),
        run("catalog-oracle-reconciliation", (python, "tools/phase25_source_probe.py", "--reconcile-only")),
        run(
            "live-registry-standup",
            (
                python,
                "tools/phase25_registry_standup.py",
                "--verify-only",
                "--output",
                str(EVIDENCE / "sprint-25.2-current-verification.json"),
            ),
        ),
        run(
            "live-atomic-publication",
            (
                python,
                "tools/phase25_registry_publish.py",
                "--verify-only",
                "--output",
                str(EVIDENCE / "sprint-25.3-current-verification.json"),
            ),
        ),
        run(
            "live-enforced-private-pull",
            (
                python,
                "tools/phase25_no_public_pull_gate.py",
                "--verify-only",
                "--output",
                str(EVIDENCE / "sprint-25.4-current-verification.json"),
            ),
            timeout=600,
        ),
        run(
            "sprint-25.2-mutants",
            (
                python,
                "tools/phase25_sprint25_2_mutation_gate.py",
                "--evidence",
                str(EVIDENCE / "sprint-25.2-mutants.json"),
            ),
        ),
        run(
            "sprint-25.3-mutant",
            (
                python,
                "tools/phase25_sprint25_3_mutation_gate.py",
                "--evidence",
                str(EVIDENCE / "sprint-25.3-mutants.json"),
            ),
        ),
        run(
            "sprint-25.4-mutant",
            (
                python,
                "tools/phase25_sprint25_4_mutation_gate.py",
                "--evidence",
                str(EVIDENCE / "sprint-25.4-mutants.json"),
            ),
        ),
        run("documentation-lint", (python, "tools/doc_lint.py")),
    ]


def write_results(rows: list[dict[str, str]], ledger_hash: str) -> None:
    (EVIDENCE / "phase-results.tsv").write_text(
        "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows),
        encoding="utf-8",
    )
    lines: list[str] = []
    for row in rows:
        lines.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
    lines.append(f"PHASE-25-GATE PASS {ledger_hash}")
    (EVIDENCE / "phase-gate.log").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        rows = execute()
        validate_evidence()
        ledger_hash = verify_ledger()
        write_results(rows, ledger_hash)
        print(f"phase25-gate: PASS ({len(rows)} checks; {ledger_hash})")
        return 0
    except (
        GateFailure,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
