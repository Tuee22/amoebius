#!/usr/bin/env python3
"""Run and seal the complete Sprint-25.4 no-public-pull gate."""

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
    original = json_object(EVIDENCE / "sprint-25.4-no-public-pull.json")
    current = json_object(EVIDENCE / "sprint-25.4-current-verification.json")
    mutants = json_object(EVIDENCE / "sprint-25.4-mutants.json")
    standup = json_object(EVIDENCE / "sprint-25.2-receipt.json")
    publication = json_object(EVIDENCE / "sprint-25.3-receipt.json")

    if original["indexDigest"] != INDEX_DIGEST or current["indexDigest"] != INDEX_DIGEST:
        raise GateFailure("index-digest")
    endpoint_names = set(original["resolvedEndpoints"])
    fixture_names = {
        line.strip()
        for line in (ROOT / original["endpointFixture"]).read_text(encoding="utf-8").splitlines()
        if line.strip()
    }
    if endpoint_names != fixture_names:
        raise GateFailure("endpoint-fixture-domain")
    addresses = {
        address
        for resolved in original["resolvedEndpoints"].values()
        for address in resolved
    }
    if not addresses:
        raise GateFailure("resolved-address-domain")

    for label, observed in (("original", original), ("current", current)):
        enforced = observed["enforced"]
        firewall = enforced["firewall"]
        if firewall["mechanism"] != "node-iptables-ip-cidr-drop":
            raise GateFailure(f"{label}-non-enforcing-mechanism")
        if firewall["ruleCount"] <= 0 or firewall["droppedPackets"] <= 0:
            raise GateFailure(f"{label}-firewall-unexercised")
        negative = enforced["negative"]
        if negative["waitingReason"] not in {"ErrImagePull", "ImagePullBackOff"}:
            raise GateFailure(f"{label}-negative-reason")
        if not negative["containerdTimeoutObserved"]:
            raise GateFailure(f"{label}-negative-wrong-locus")
        observer = enforced["observer"]
        if observer["publicEstablishedConnections"] != 0:
            raise GateFailure(f"{label}-public-connection")
        positive = enforced["positive"]
        if (
            positive["phase"] != "Succeeded"
            or not positive["registryReadObserved"]
            or INDEX_DIGEST not in positive["image"]
            or INDEX_DIGEST not in positive["imageId"]
        ):
            raise GateFailure(f"{label}-in-cluster-positive")
        if (
            observed["standupPublicRegistryTcpConnections"] != 0
            or observed["publicationPublicRegistryTcpConnections"] != 0
            or observed["publicationRerunMutatingRequests"] != 0
        ):
            raise GateFailure(f"{label}-prior-flow-boundary")

    live_mutant = original["mutant"]
    if (
        live_mutant["mechanism"] != "kindnet-NetworkPolicy"
        or live_mutant["podPhase"] != "Succeeded"
        or live_mutant["result"] != "RED"
    ):
        raise GateFailure("live-mutant-survived")
    if not mutants.get("baselineRestored") or len(mutants.get("results", [])) != 1:
        raise GateFailure("mutant-domain")
    if mutants["results"][0].get("result") != "RED":
        raise GateFailure("cpp-mutant-survived")
    if standup["publicRegistryTcpConnections"] != 0:
        raise GateFailure("standup-public-connection")
    if publication["publicRegistryTcpConnections"] != 0 or publication["rerunMutatingRequests"] != 0:
        raise GateFailure("publication-public-or-rerun")

    stable = {
        "schema": "amoebius.phase25.sprint25.4-receipt.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "endpointCount": len(endpoint_names),
        "resolvedAddressCount": len(addresses),
        "denialMechanism": original["enforced"]["firewall"]["mechanism"],
        "firewallRuleCount": original["enforced"]["firewall"]["ruleCount"],
        "firewallDroppedPackets": original["enforced"]["firewall"]["droppedPackets"],
        "negativePullReason": original["enforced"]["negative"]["waitingReason"],
        "positivePullPhase": original["enforced"]["positive"]["phase"],
        "imageIndexDigest": INDEX_DIGEST,
        "publicEstablishedConnections": original["enforced"]["observer"]["publicEstablishedConnections"],
        "standupPublicRegistryTcpConnections": original["standupPublicRegistryTcpConnections"],
        "publicationPublicRegistryTcpConnections": original["publicationPublicRegistryTcpConnections"],
        "publicationRerunMutatingRequests": original["publicationRerunMutatingRequests"],
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
        "-f-phase25-noop-egress-policy-mutant",
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
            "live-enforced-paired-canaries",
            (
                python,
                "tools/phase25_no_public_pull_gate.py",
                "--verify-only",
                "--output",
                str(EVIDENCE / "sprint-25.4-current-verification.json"),
            ),
            timeout=600,
        ),
        invoke(
            "seeded-mutant",
            (
                python,
                "tools/phase25_sprint25_4_mutation_gate.py",
                "--evidence",
                str(EVIDENCE / "sprint-25.4-mutants.json"),
            ),
            timeout=1800,
        ),
        invoke("documentation-lint", (python, "tools/doc_lint.py")),
    ]
    return rows, validate_evidence()


def write_results(rows: list[dict[str, str]], receipt: dict[str, Any]) -> None:
    (EVIDENCE / "sprint-25.4-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (EVIDENCE / "sprint-25.4-phase-results.tsv").write_text(
        "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows),
        encoding="utf-8",
    )
    log: list[str] = []
    for row in rows:
        log.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
    log.append(f"SPRINT-25.4-GATE PASS {receipt['receiptFingerprint']}")
    (EVIDENCE / "sprint-25.4-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")


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
        print(f"phase25-sprint25.4-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})")
        return 0
    except (
        GateFailure,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-sprint25.4-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
