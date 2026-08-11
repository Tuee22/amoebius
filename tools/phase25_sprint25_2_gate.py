#!/usr/bin/env python3
"""Run and seal the complete Sprint-25.2 validation surface."""

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
NODE = "amoebius-phase24-control-plane"
IMAGE_DIGEST = "sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
IMAGE = f"amoebius.invalid/amoebius-base@{IMAGE_DIGEST}"
EXPECTED_DOMAIN = sorted(
    (
        "Namespace/amoebius-bootstrap",
        "ConfigMap/amoebius-bootstrap/registry-config",
        "Deployment/amoebius-bootstrap/distribution",
        "Service/amoebius-bootstrap/distribution-read",
        "Deployment/amoebius-bootstrap/registry-mutation-proxy",
        "Service/amoebius-bootstrap/registry-mutation-proxy",
    )
)


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


def validate_export_boundary() -> None:
    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    exposed, separator, remainder = cabal.partition("  other-modules:\n")
    if not separator or "      Amoebius.Manifest.Render\n" not in remainder:
        raise GateFailure("package-private-bootstrap-renderer-absent")
    if "      Amoebius.Manifest.Render\n" in exposed:
        raise GateFailure("bootstrap-renderer-publicly-exposed")
    render = (ROOT / "src/Amoebius/Manifest/Render.hs").read_text(encoding="utf-8")
    if "renderBootstrapSourcePrivate" not in render:
        raise GateFailure("private-bootstrap-source-serializer-absent")


def validate_evidence() -> dict[str, Any]:
    preflight = json_object(EVIDENCE / "sprint-25.2-preflight.json")
    standup = json_object(EVIDENCE / "sprint-25.2-standup.json")
    current = json_object(EVIDENCE / "sprint-25.2-current-verification.json")
    mutants = json_object(EVIDENCE / "sprint-25.2-mutants.json")
    sprint251 = json_object(EVIDENCE / "sprint-25.1-receipt.json")

    if preflight["artifact"]["imageIndexDigest"] != IMAGE_DIGEST:
        raise GateFailure("preflight-image-digest")
    if preflight["archiveSha256"] != sprint251["artifactArchiveSha256"].removeprefix("sha256:"):
        raise GateFailure("preflight-archive-identity")
    if preflight["pullPolicy"] != "Never":
        raise GateFailure("preflight-pull-policy")
    if preflight["artifact"]["peakBytes"] > preflight["filesystem"]["availableBytes"]:
        raise GateFailure("node-import-overdraw")
    for axis in ("cpuMillis", "memoryBytes"):
        if preflight["plannedRequests"][axis] > preflight["nodeCgroupResidual"][axis]:
            raise GateFailure(f"node-cgroup-overdraw:{axis}")
    if preflight["plannedRequests"]["ephemeralBytes"] > preflight["requestResidual"]["ephemeralBytes"]:
        raise GateFailure("registry-ephemeral-overdraw")
    if preflight["registry"]["peakBytes"] != (
        preflight["registry"]["storedBytes"]
        + preflight["registry"]["workspaceBytes"]
        + preflight["registry"]["failedUploadBytes"]
    ):
        raise GateFailure("registry-transition-arithmetic")

    for label, observed in (("standup", standup), ("current", current)):
        if sorted(observed["domain"]) != EXPECTED_DOMAIN:
            raise GateFailure(f"{label}-domain")
        if observed["image"] != IMAGE or any(IMAGE_DIGEST not in value for value in observed["imageIds"]):
            raise GateFailure(f"{label}-image-byte-identity")
        if observed["registryRead"]["status"] != 200 or observed["directMutation"]["status"] != 405:
            raise GateFailure(f"{label}-read-only-boundary")
        if observed["proxy"]["deniedStatus"] != 403 or observed["proxy"]["admittedButDeferredStatus"] != 409:
            raise GateFailure(f"{label}-mutation-capability-boundary")
        if observed["containerdPublicRegistryLines"] != 0 or observed["publicRegistryTcpConnections"] != 0:
            raise GateFailure(f"{label}-public-registry-observation")
        firewall = observed.get("backendFirewall", {})
        if firewall.get("ruleCount") != 3 or firewall.get("proxyPrivateReadStatus") != 200 or firewall.get("nodeDirectReadExit") == 0:
            raise GateFailure(f"{label}-private-backend-firewall")
    if current["preflightFingerprint"] != preflight["fingerprint"]:
        raise GateFailure("current-preflight-fingerprint")
    if not mutants.get("baselineRestored") or len(mutants.get("results", [])) != 2:
        raise GateFailure("mutant-domain")
    if any(row.get("result") != "RED" for row in mutants["results"]):
        raise GateFailure("mutant-survived")

    image_rows = invoke(
        "containerd-image-readback",
        (
            "/usr/bin/docker", "exec", NODE, "/usr/local/bin/ctr", "--namespace", "k8s.io",
            "images", "list", "--quiet",
        ),
    )["output"].splitlines()
    if IMAGE not in image_rows:
        raise GateFailure("side-loaded-image-absent")
    validate_export_boundary()

    stable = {
        "schema": "amoebius.phase25.sprint25.2-receipt.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "preflightFingerprint": preflight["fingerprint"],
        "imageIndexDigest": IMAGE_DIGEST,
        "selectedPlatform": "linux/amd64",
        "selectedContentBytes": preflight["artifact"]["contentBytes"],
        "selectedSnapshotBytes": preflight["artifact"]["snapshotBytes"],
        "selectedImportPeakBytes": preflight["artifact"]["peakBytes"],
        "registryObjectCount": preflight["registry"]["objectCount"],
        "registryPeakBytes": preflight["registry"]["peakBytes"],
        "bootstrapObjectCount": len(EXPECTED_DOMAIN),
        "containerImageCount": len(current["imageIds"]),
        "directMutationStatus": current["directMutation"]["status"],
        "unauthorizedMutationStatus": current["proxy"]["deniedStatus"],
        "admittedPublicationDeferredStatus": current["proxy"]["admittedButDeferredStatus"],
        "containerdPublicRegistryLines": current["containerdPublicRegistryLines"],
        "publicRegistryTcpConnections": current["publicRegistryTcpConnections"],
        "seededMutantsRed": len(mutants["results"]),
        "result": "PASS",
    }
    return {**stable, "receiptFingerprint": fingerprint(stable)}


def seal() -> tuple[list[dict[str, str]], dict[str, Any]]:
    python = sys.executable
    rows = [
        invoke(
            "haskell-image-spec",
            (
                "/home/matthewnowak/.ghcup/bin/cabal", "test", "phase25-image-spec",
                "-f-phase25-bootstrap-domain-expansion-mutant",
                "-f-phase25-handoff-without-equality-mutant",
                "-f-phase25-record-before-push-mutant",
                "--test-show-details=direct", "-j1",
            ),
        ),
        invoke(
            "python-image-specs",
            (python, "-m", "unittest", "discover", "-s", "test/image", "-p", "test_phase25*.py", "-v"),
        ),
        invoke(
            "live-current-verification",
            (
                python, "tools/phase25_registry_standup.py", "--verify-only", "--output",
                str(EVIDENCE / "sprint-25.2-current-verification.json"),
            ),
        ),
        invoke(
            "seeded-mutants",
            (
                python, "tools/phase25_sprint25_2_mutation_gate.py", "--evidence",
                str(EVIDENCE / "sprint-25.2-mutants.json"),
            ),
            timeout=1800,
        ),
        invoke("documentation-lint", (python, "tools/doc_lint.py")),
    ]
    return rows, validate_evidence()


def write_results(rows: list[dict[str, str]], receipt: dict[str, Any]) -> None:
    (EVIDENCE / "sprint-25.2-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (EVIDENCE / "sprint-25.2-phase-results.tsv").write_text(
        "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows),
        encoding="utf-8",
    )
    log: list[str] = []
    for row in rows:
        log.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
    log.append(f"SPRINT-25.2-GATE PASS {receipt['receiptFingerprint']}")
    (EVIDENCE / "sprint-25.2-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")


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
        print(f"phase25-sprint25.2-gate: PASS ({len(rows)} checks; {receipt['receiptFingerprint']})")
        return 0
    except (
        GateFailure,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-sprint25.2-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
