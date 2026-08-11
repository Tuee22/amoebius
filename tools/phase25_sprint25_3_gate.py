#!/usr/bin/env python3
"""Run and seal the complete Sprint-25.3 validation surface."""

from __future__ import annotations

import argparse
import hashlib
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_25"
INDEX_DIGEST = "sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 900) -> dict[str, str]:
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
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


def json_object(path: Path) -> dict[str, Any]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, dict):
        raise GateFailure(f"json-object:{path}")
    return decoded


def fingerprint(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def validate_evidence() -> dict[str, Any]:
    publication = json_object(EVIDENCE / "sprint-25.3-publication.json")
    current = json_object(EVIDENCE / "sprint-25.3-current-verification.json")
    mutants = json_object(EVIDENCE / "sprint-25.3-mutants.json")
    if publication["indexDigest"] != INDEX_DIGEST:
        raise GateFailure("publication-index-digest")
    tag = str(publication["immutableTag"])
    if tag == "latest" or "latest" in str(publication["digestReference"]):
        raise GateFailure("mutable-reference")
    fault = publication["fault"]
    if fault["status"] != 502 or fault["tagAdvertised"] or fault["manifestStatus"] != 404:
        raise GateFailure("partial-failure-advertised")
    if fault["residueBytes"] <= 0 or publication["residueAfterSuccess"]["bytes"] < fault["residueBytes"]:
        raise GateFailure("partial-residue-not-retained")
    published = publication["publication"]
    if not published["tagAdvertised"] or published["manifestStatus"] != 200:
        raise GateFailure("final-tag-not-advertised")
    if published["manifestDigest"] != INDEX_DIGEST or published["manifestBodySha256"] != INDEX_DIGEST:
        raise GateFailure("final-index-byte-identity")
    if sorted(published["platforms"]) != ["linux/amd64", "linux/arm64"]:
        raise GateFailure("published-platform-domain")
    if published["finalAdvertisementRequests"] != 1 or publication["rerunMutatingRequests"] != 0:
        raise GateFailure("atomic-or-idempotent-publication")
    if publication["unprovisionedMutationStatus"] != 403:
        raise GateFailure("unprovisioned-mutation-admitted")
    if publication["dockerLoginInvocations"] != 0 or publication["environmentCredentialVariables"] != 0:
        raise GateFailure("ambient-publication-credential")
    if publication["containerdPublicRegistryLines"] != 0 or publication["publicRegistryTcpConnections"] != 0:
        raise GateFailure("publication-public-registry-observation")
    if current["manifestDigest"] != INDEX_DIGEST or current["manifestBodySha256"] != INDEX_DIGEST:
        raise GateFailure("current-index-byte-identity")
    if current["rerunMutatingRequests"] != 0:
        raise GateFailure("current-rerun-mutated")
    docker_config = current["ephemeralDockerConfig"]
    if (
        docker_config["dockerExecutable"] != "/usr/bin/docker"
        or docker_config["configFlag"] != "--config"
        or docker_config["environmentEntries"] != 0
        or docker_config["dockerLoginInvocations"] != 0
        or not docker_config["scrubbed"]
    ):
        raise GateFailure("ephemeral-docker-config-boundary")
    firewall = current["backendFirewall"]
    if firewall["ruleCount"] != 3 or firewall["proxyPrivateReadStatus"] != 200 or firewall["nodeDirectReadExit"] == 0:
        raise GateFailure("private-backend-firewall")
    if not mutants.get("baselineRestored") or len(mutants.get("results", [])) != 1:
        raise GateFailure("mutant-domain")
    if mutants["results"][0].get("result") != "RED":
        raise GateFailure("record-before-push-mutant-survived")
    stable = {
        "schema": "amoebius.phase25.sprint25.3-receipt.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "preflightFingerprint": publication["preflightFingerprint"],
        "immutableTag": tag,
        "digestReference": publication["digestReference"],
        "indexDigest": INDEX_DIGEST,
        "childDigests": publication["childDigests"],
        "partialFaultStatus": fault["status"],
        "partialTagManifestStatus": fault["manifestStatus"],
        "partialResidueBytes": fault["residueBytes"],
        "finalAdvertisementRequests": published["finalAdvertisementRequests"],
        "rerunMutatingRequests": publication["rerunMutatingRequests"],
        "publicRegistryTcpConnections": publication["publicRegistryTcpConnections"],
        "containerdPublicRegistryLines": publication["containerdPublicRegistryLines"],
        "seededMutantsRed": len(mutants["results"]),
        "result": "PASS",
    }
    return {**stable, "receiptFingerprint": fingerprint(stable)}


def seal() -> tuple[list[dict[str, str]], dict[str, Any]]:
    python = sys.executable
    baseline_flags = (
        "-f-phase25-bootstrap-domain-expansion-mutant",
        "-f-phase25-handoff-without-equality-mutant",
        "-f-phase25-record-before-push-mutant",
    )
    rows = [
        invoke(
            "haskell-image-spec",
            (
                "/home/matthewnowak/.ghcup/bin/cabal",
                "test",
                "phase25-image-spec",
                *baseline_flags,
                "--test-show-details=direct",
                "-j1",
            ),
        ),
        invoke(
            "python-image-specs",
            (python, "-m", "unittest", "discover", "-s", "test/image", "-p", "test_phase25*.py", "-v"),
        ),
        invoke(
            "live-current-publication",
            (
                python,
                "tools/phase25_registry_publish.py",
                "--verify-only",
                "--output",
                str(EVIDENCE / "sprint-25.3-current-verification.json"),
            ),
        ),
        invoke(
            "seeded-mutant",
            (
                python,
                "tools/phase25_sprint25_3_mutation_gate.py",
                "--evidence",
                str(EVIDENCE / "sprint-25.3-mutants.json"),
            ),
            timeout=1800,
        ),
        invoke("documentation-lint", (python, "tools/doc_lint.py")),
    ]
    return rows, validate_evidence()


def write_results(rows: list[dict[str, str]], receipt: dict[str, Any]) -> None:
    (EVIDENCE / "sprint-25.3-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (EVIDENCE / "sprint-25.3-phase-results.tsv").write_text(
        "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows),
        encoding="utf-8",
    )
    log: list[str] = []
    for row in rows:
        log.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
    log.append(f"SPRINT-25.3-GATE PASS {receipt['receiptFingerprint']}")
    (EVIDENCE / "sprint-25.3-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-receipt", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_receipt:
            print(json.dumps(validate_evidence(), indent=2, sort_keys=True))
            return 0
        rows, receipt = seal()
        write_results(rows, receipt)
        print(f"phase25-sprint25.3-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})")
        return 0
    except (
        GateFailure,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-sprint25.3-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
