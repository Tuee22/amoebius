#!/usr/bin/env python3
"""Run and seal the complete Sprint-25.1 validation surface."""

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
ARTIFACT = Path("/var/tmp/amoebius-phase25-scratch/oci/amoebius-phase25.oci.tar")
CACHE = Path("/var/tmp/amoebius-phase25-cache/buildx-cache")
SCRATCH = Path("/var/tmp/amoebius-phase25-scratch")
BUILDKIT_CONFIG = ROOT / "test/fixtures/phase25/buildkitd.toml"
FINAL_AMD64 = EVIDENCE / "final-probes-amd64.tsv"
FINAL_ARM64 = EVIDENCE / "final-probes-arm64.tsv"


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 900) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=timeout, check=False,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {
        "name": name,
        "command": shlex.join(arguments),
        "result": "PASS",
        "output": result.stdout.strip(),
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def directory_bytes(path: Path) -> int:
    result = subprocess.run(
        ("/usr/bin/sudo", "-n", "/usr/bin/du", "--summarize", "--bytes", str(path)),
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if result.returncode:
        raise GateFailure(f"cache-measure:{result.stdout}")
    return int(result.stdout.split()[0])


def json_file(path: Path) -> dict[str, Any]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, dict):
        raise GateFailure(f"json-object:{path}")
    return decoded


def seal() -> tuple[list[dict[str, str]], dict[str, Any]]:
    python = sys.executable
    rows = [
        invoke(
            "haskell-image-spec",
            ("cabal", "test", "phase25-image-spec", "--test-show-details=direct", "-j1"),
        ),
        invoke(
            "python-image-specs",
            (python, "-m", "unittest", "discover", "-s", "test/image", "-p", "test_phase25*.py", "-v"),
        ),
        invoke(
            "catalog-oracle-reconciliation",
            (python, "tools/phase25_source_probe.py", "--reconcile-only"),
        ),
        invoke(
            "builder-boundary",
            (
                python, "tools/phase25_builder_probe.py",
                "--container", "amoebius-phase25-buildkitd",
                "--cache-root", "/var/tmp/amoebius-phase25-cache",
                "--scratch-root", str(SCRATCH),
                "--config", str(BUILDKIT_CONFIG),
                "--evidence", str(EVIDENCE / "builder-boundary-gate.json"),
            ),
        ),
        invoke(
            "cpu-memory-overruns",
            (
                python, "tools/phase25_cgroup_overrun_probe.py",
                "--evidence", str(EVIDENCE / "builder-cgroup-overruns.json"),
            ),
        ),
        invoke(
            "scratch-cache-enospc",
            (
                python, "tools/phase25_enospc_probe.py",
                "--evidence", str(EVIDENCE / "builder-enospc.json"),
            ),
        ),
        invoke(
            "oci-object-audit",
            (
                python, "tools/phase25_oci_probe.py", str(ARTIFACT),
                "--bounds", "test/fixtures/phase25/image_artifact_bounds.json",
                "--evidence", str(EVIDENCE / "image-artifact.json"),
            ),
            timeout=1800,
        ),
        invoke(
            "official-file-execution-join",
            (
                python, "tools/phase25_oci_file_probe.py", str(ARTIFACT),
                "--executed-probes", str(FINAL_AMD64),
                "--executed-probes", str(FINAL_ARM64),
                "--evidence", str(EVIDENCE / "official-file-execution-join.json"),
            ),
            timeout=1800,
        ),
        invoke(
            "spdx-file-inventory",
            (
                python, "tools/phase25_sbom.py",
                "--probe", str(FINAL_AMD64), "--probe", str(FINAL_ARM64),
                "--output", str(EVIDENCE / "file-sbom.spdx.json"),
            ),
        ),
        invoke(
            "seeded-mutants",
            (
                python, "tools/phase25_mutation_gate.py",
                "--official-file-join", str(EVIDENCE / "official-file-execution-join.json"),
                "--evidence", str(EVIDENCE / "sprint-25.1-mutants.json"),
            ),
        ),
    ]

    preflight = json_file(EVIDENCE / "build-preflight-corrected.json")
    artifact = json_file(EVIDENCE / "image-artifact.json")
    file_join = json_file(EVIDENCE / "official-file-execution-join.json")
    mutants = json_file(EVIDENCE / "sprint-25.1-mutants.json")
    enospc = json_file(EVIDENCE / "builder-enospc.json")
    cgroups = json_file(EVIDENCE / "builder-cgroup-overruns.json")
    sbom = json_file(EVIDENCE / "file-sbom.spdx.json")
    if preflight["scratchCapacityBytes"] != 103_079_215_104:
        raise GateFailure("corrected-preflight-scratch-capacity")
    if artifact["imageIndexDigest"] != file_join["imageIndexDigest"]:
        raise GateFailure("artifact-file-join-index-mismatch")
    if len(artifact["platforms"]) != 2 or len(artifact["registryObjects"]) < 5:
        raise GateFailure("artifact-domain")
    if len(file_join["rows"]) != 46 or len(sbom["files"]) != 46:
        raise GateFailure("file-inventory-domain")
    if any(row["result"] != "RED" for row in mutants["results"]):
        raise GateFailure("mutant-survived")
    if len(enospc["results"]) != 2 or any(row["exit"] == 0 for row in enospc["results"]):
        raise GateFailure("enospc-domain")
    if cgroups["cpuThrottleDelta"] <= 0 or cgroups["oomKillDelta"] <= 0:
        raise GateFailure("cgroup-overrun-domain")
    cache_bytes = directory_bytes(CACHE)
    if cache_bytes > 68_719_476_736:
        raise GateFailure("cache-capacity-overrun")
    scratch_stats = os.statvfs(SCRATCH)
    scratch_used = (scratch_stats.f_blocks - scratch_stats.f_bfree) * scratch_stats.f_frsize
    if scratch_used > 103_079_215_104:
        raise GateFailure("scratch-capacity-overrun")
    receipt = {
        "schema": "amoebius.phase25.sprint25.1-receipt.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "preflightFingerprint": preflight["observedBuildFingerprint"],
        "artifactArchiveBytes": ARTIFACT.stat().st_size,
        "artifactArchiveSha256": sha256(ARTIFACT),
        "imageIndexDigest": artifact["imageIndexDigest"],
        "platforms": [f"{row['os']}/{row['architecture']}" for row in artifact["platforms"]],
        "registryObjectCount": len(artifact["registryObjects"]),
        "officialFileExecutionJoins": len(file_join["rows"]),
        "sbomFiles": len(sbom["files"]),
        "seededMutantsRed": len(mutants["results"]),
        "scratchFilesystemUsedBytes": scratch_used,
        "scratchProvisionBytes": 103_079_215_104,
        "cacheFilesystemUsedBytes": cache_bytes,
        "cacheProvisionBytes": 68_719_476_736,
        "result": "PASS",
    }
    return rows, receipt


def write_results(rows: list[dict[str, str]], receipt: dict[str, Any]) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "sprint-25.1-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    with (EVIDENCE / "sprint-25.1-phase-results.tsv").open("w", encoding="utf-8") as handle:
        handle.write("check\tresult\n")
        for row in rows:
            handle.write(f"{row['name']}\t{row['result']}\n")
    log = []
    for row in rows:
        log.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
    log.append(f"SPRINT-25.1-GATE PASS {receipt['imageIndexDigest']}")
    (EVIDENCE / "sprint-25.1-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    argparse.ArgumentParser(description=__doc__).parse_args(argv)
    try:
        rows, receipt = seal()
        write_results(rows, receipt)
        print(
            "phase25-sprint25.1-gate: PASS "
            f"({len(rows)} checks; {receipt['imageIndexDigest']})"
        )
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase25-sprint25.1-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
