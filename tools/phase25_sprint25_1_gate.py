#!/usr/bin/env python3
"""Run and seal the complete Sprint-25.1 validation surface."""

from __future__ import annotations

import argparse
import functools
import hashlib
import importlib.util
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"module-load:{path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


SOURCE = _load("phase25_source_probe", Path(__file__).resolve().parent / "phase25_source_probe.py")


ROOT = Path(__file__).resolve().parents[1]
BUILDKIT_CONFIG = ROOT / "test/fixtures/phase25/buildkitd.toml"


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


@functools.cache
def catalog_capacities() -> dict[str, Any]:
    """The scratch and cache provisions this run's catalog declares."""
    return SOURCE.decode_dhall(SOURCE.CATALOG)


@functools.cache
def build_tools() -> tuple[str, str]:
    """Resolve cabal and the compiler per run from the authored requirements.

    A bare `cabal` is a PATH lookup, and a `cabal test` without `--with-compiler` inherits
    whichever GHC the host's PATH offers — which need not satisfy the authored range.
    """
    resolved = toolchain.resolve(["cabal", "ghc"])
    return resolved["cabal"]["path"], resolved["ghc"]["path"]


def seal(
    evidence: Path, builder_image: str, artifact: Path, cache: Path, scratch: Path
) -> tuple[list[dict[str, str]], dict[str, Any]]:
    python = sys.executable
    cabal, compiler = build_tools()
    final_amd64 = evidence / "final-probes-amd64.tsv"
    final_arm64 = evidence / "final-probes-arm64.tsv"
    rows = [
        invoke(
            "haskell-image-spec",
            (
                cabal, f"--with-compiler={compiler}", "test", "phase25-image-spec",
                "--test-show-details=direct", "-j1",
            ),
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
                "--builder-image", builder_image,
                "--cache-root", str(cache.parent),
                "--scratch-root", str(scratch),
                "--config", str(BUILDKIT_CONFIG),
                "--evidence", str(evidence / "builder-boundary-gate.json"),
            ),
        ),
        invoke(
            "cpu-memory-overruns",
            (
                python, "tools/phase25_cgroup_overrun_probe.py",
                "--evidence", str(evidence / "builder-cgroup-overruns.json"),
            ),
        ),
        invoke(
            "scratch-cache-enospc",
            (
                python, "tools/phase25_enospc_probe.py",
                "--builder-image", builder_image,
                "--evidence", str(evidence / "builder-enospc.json"),
            ),
        ),
        invoke(
            "oci-object-audit",
            (
                python, "tools/phase25_oci_probe.py", str(artifact),
                "--bounds", "test/fixtures/phase25/image_artifact_bounds.json",
                "--evidence", str(evidence / "image-artifact.json"),
            ),
            timeout=1800,
        ),
        invoke(
            "official-file-execution-join",
            (
                python, "tools/phase25_oci_file_probe.py", str(artifact),
                "--executed-probes", str(final_amd64),
                "--executed-probes", str(final_arm64),
                "--evidence", str(evidence / "official-file-execution-join.json"),
            ),
            timeout=1800,
        ),
        invoke(
            "spdx-file-inventory",
            (
                python, "tools/phase25_sbom.py",
                "--probe", str(final_amd64), "--probe", str(final_arm64),
                "--output", str(evidence / "file-sbom.spdx.json"),
            ),
        ),
        invoke(
            "seeded-mutants",
            (
                python, "tools/phase25_mutation_gate.py",
                "--official-file-join", str(evidence / "official-file-execution-join.json"),
                "--evidence", str(evidence / "sprint-25.1-mutants.json"),
            ),
        ),
    ]

    preflight = json_file(evidence / "build-preflight-corrected.json")
    measured = json_file(evidence / "image-artifact.json")
    file_join = json_file(evidence / "official-file-execution-join.json")
    mutants = json_file(evidence / "sprint-25.1-mutants.json")
    enospc = json_file(evidence / "builder-enospc.json")
    cgroups = json_file(evidence / "builder-cgroup-overruns.json")
    sbom = json_file(evidence / "file-sbom.spdx.json")
    # The provisions the build was admitted against come from the catalog this run
    # decoded, not from constants typed in here. The retired form pinned 96 GiB of
    # scratch and 64 GiB of cache — sized for a base image that no longer exists,
    # and larger than the free space on the substrate the linux-cpu lane runs on,
    # so the assertion could only ever have been satisfied by a host nobody had.
    scratch_provision = int(catalog_capacities()["scratchCapacityBytes"])
    cache_provision = int(catalog_capacities()["cacheCapacityBytes"])
    # One join and one SBOM row per authored binary per architecture. Derived from
    # the oracle's own length, so adding a binary cannot leave the count behind.
    expected_rows = 2 * len(SOURCE.oracle_inventory())
    if preflight["scratchCapacityBytes"] != scratch_provision:
        raise GateFailure(
            f"preflight-scratch-capacity:{preflight['scratchCapacityBytes']}!={scratch_provision}"
        )
    if measured["imageIndexDigest"] != file_join["imageIndexDigest"]:
        raise GateFailure("artifact-file-join-index-mismatch")
    if len(measured["platforms"]) != 2 or len(measured["registryObjects"]) < 5:
        raise GateFailure("artifact-domain")
    if len(file_join["rows"]) != expected_rows or len(sbom["files"]) != expected_rows:
        raise GateFailure(
            f"file-inventory-domain:{len(file_join['rows'])}/{len(sbom['files'])}!={expected_rows}"
        )
    if any(row["result"] != "RED" for row in mutants["results"]):
        raise GateFailure("mutant-survived")
    if len(enospc["results"]) != 2 or any(row["exit"] == 0 for row in enospc["results"]):
        raise GateFailure("enospc-domain")
    if cgroups["cpuThrottleDelta"] <= 0 or cgroups["oomKillDelta"] <= 0:
        raise GateFailure("cgroup-overrun-domain")
    cache_bytes = directory_bytes(cache)
    if cache_bytes > cache_provision:
        raise GateFailure("cache-capacity-overrun")
    scratch_stats = os.statvfs(scratch)
    scratch_used = (scratch_stats.f_blocks - scratch_stats.f_bfree) * scratch_stats.f_frsize
    if scratch_used > scratch_provision:
        raise GateFailure("scratch-capacity-overrun")
    receipt = {
        "schema": "amoebius.phase25.sprint25.1-receipt.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "preflightFingerprint": preflight["observedBuildFingerprint"],
        "artifactArchiveBytes": artifact.stat().st_size,
        "artifactArchiveSha256": sha256(artifact),
        "imageIndexDigest": measured["imageIndexDigest"],
        "platforms": [f"{row['os']}/{row['architecture']}" for row in measured["platforms"]],
        "registryObjectCount": len(measured["registryObjects"]),
        "officialFileExecutionJoins": len(file_join["rows"]),
        "sbomFiles": len(sbom["files"]),
        "seededMutantsRed": len(mutants["results"]),
        "scratchFilesystemUsedBytes": scratch_used,
        "scratchProvisionBytes": scratch_provision,
        "cacheFilesystemUsedBytes": cache_bytes,
        "cacheProvisionBytes": cache_provision,
        "result": "PASS",
    }
    return rows, receipt


def write_results(evidence: Path, rows: list[dict[str, str]], receipt: dict[str, Any]) -> None:
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "sprint-25.1-receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    with (evidence / "sprint-25.1-phase-results.tsv").open("w", encoding="utf-8") as handle:
        handle.write("check\tresult\n")
        for row in rows:
            handle.write(f"{row['name']}\t{row['result']}\n")
    log = []
    for row in rows:
        log.extend((f"CHECK {row['name']}", f"COMMAND {row['command']}", row["output"], "RESULT PASS"))
    log.append(f"SPRINT-25.1-GATE PASS {receipt['imageIndexDigest']}")
    (evidence / "sprint-25.1-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # The bundle this run writes into is supplied by the caller. There is deliberately no
    # default: a default names a location, and whatever a previous run left there would
    # decide this gate instead of the run in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    # Passed straight through to the two builder probes, for the same reason they refuse a
    # default: the boundary has to be proven against the image this run actually started.
    parser.add_argument(
        "--builder-image", required=True, help="the resolved BuildKit builder image reference"
    )
    # The OCI export, the cache directory, and the scratch root are this run's, not a
    # location. The retired form read the artifact from a fixed path, so whatever a
    # previous build left there decided the gate -- and a sixteen-gigabyte export of a
    # catalog that no longer exists was sitting at exactly that path.
    parser.add_argument("--artifact", type=Path, required=True, help="this run's OCI export")
    parser.add_argument("--cache", type=Path, required=True, help="this run's buildx cache directory")
    parser.add_argument("--scratch", type=Path, required=True, help="this run's scratch root")
    arguments = parser.parse_args(argv)
    try:
        rows, receipt = seal(
            arguments.evidence, arguments.builder_image,
            arguments.artifact, arguments.cache, arguments.scratch,
        )
        write_results(arguments.evidence, rows, receipt)
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
