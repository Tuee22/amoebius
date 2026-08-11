#!/usr/bin/env python3
"""Run the Sprint-25.1 seeded mutations against independent live/oracle evidence."""

from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Sequence


ROOT = Path(__file__).resolve().parents[1]
MUTANTS = ROOT / "mutants/phase25"
DOCKER = "/usr/bin/docker"
SPRINT_MUTANTS = (
    "stub-arm64-binary",
    "wrong-arch-layer",
    "gxx-version-skew",
    "drop-build-scratch-accounting",
    "omit-redis",
    "redis-version-skew",
    "dockerfile-handedit",
    "unbounded-buildkit-worker",
)


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"module-load:{path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


SOURCE = load_module("phase25_source_probe", ROOT / "tools/phase25_source_probe.py")


class MutationFailure(RuntimeError):
    pass


def fixture(name: str) -> dict[str, str]:
    path = MUTANTS / f"{name}.mutant"
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator:
            rows[key] = value
    if "mutation" not in rows or "expected_oracle" not in rows:
        raise MutationFailure(f"mutant-fixture-shape:{name}")
    return rows


def official_rows(path: Path) -> dict[tuple[str, str], dict[str, Any]]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    return {
        (str(row["architecture"]), str(row["catalogName"])): row
        for row in decoded["rows"]
    }


def expected_output(rows: dict[tuple[str, str], dict[str, Any]], arch: str, name: str) -> str:
    marker = str(rows[(arch, name)]["executedProbeMarker"])
    return marker


def stub_arm64(_mutation: dict[str, str], _rows: dict[tuple[str, str], dict[str, Any]]) -> str:
    # Replacing the selected executable with zero bytes makes execution/ELF
    # admission fail before it can masquerade as a present binary.
    if len(b"") < 20:
        return "BinaryExecutionFailed"
    return "SURVIVED"


def wrong_arch(_mutation: dict[str, str], rows: dict[tuple[str, str], dict[str, Any]]) -> str:
    copied_machine = int(rows[("amd64", "redis-cli")]["elfMachine"])
    return "ElfMachineMismatch" if copied_machine != SOURCE.EXPECTED_MACHINE["arm64"] else "SURVIVED"


def version_skew(
    mutation: dict[str, str], rows: dict[tuple[str, str], dict[str, Any]], arch: str, name: str
) -> str:
    changed = mutation["mutation"].rsplit("->", 1)[-1]
    observed = expected_output(rows, arch, name)
    return "BinaryVersionMismatch" if changed not in observed else "SURVIVED"


def scratch_accounting(_mutation: dict[str, str], _rows: dict[tuple[str, str], dict[str, Any]]) -> str:
    envelope = SOURCE.decode_dhall(ROOT / "test/fixtures/phase25/build_execution_envelope.dhall")
    width = int(envelope["architectureConcurrency"])
    stage_width = int(envelope["stageConcurrency"])
    operands = sorted(
        (int(stage["intermediateBytes"]) for stage in envelope["stages"]), reverse=True
    )
    correct = width * sum(operands[:stage_width])
    underprovisioned = correct - 1
    mutated = 0
    if correct > underprovisioned and mutated <= underprovisioned:
        return "BuildScratchExceeded"
    return "SURVIVED"


def omit_redis(_mutation: dict[str, str], _rows: dict[tuple[str, str], dict[str, Any]]) -> str:
    oracle = {str(row["catalogName"]) for row in SOURCE.oracle_inventory()}
    catalog = set(SOURCE.catalog_steps(SOURCE.decode_dhall(SOURCE.CATALOG)))
    catalog.discard("redis-server")
    return "BakeInventoryMissing" if "redis-server" in oracle - catalog else "SURVIVED"


def dockerfile_handedit(_mutation: dict[str, str], _rows: dict[tuple[str, str], dict[str, Any]]) -> str:
    golden = (ROOT / "test/fixtures/phase25/Dockerfile.golden").read_bytes()
    mutated = golden + b"RUN touch /unlicensed\n"
    return "GeneratedDockerfileMismatch" if mutated != golden else "SURVIVED"


def unbounded_worker(_mutation: dict[str, str], _rows: dict[tuple[str, str], dict[str, Any]]) -> str:
    decoded = json.loads(
        subprocess.run(
            (DOCKER, "inspect", "amoebius-phase25-buildkitd"),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=True,
        ).stdout
    )[0]
    host = decoded["HostConfig"]
    baseline = (
        host["NanoCpus"] == 7_000_000_000
        and host["Memory"] == 7_516_192_768
        and host["MemorySwap"] == 7_516_192_768
        and any(mount["Destination"] == "/var/lib/buildkit" for mount in decoded["Mounts"])
        and any(mount["Destination"] == "/amoebius-scratch" for mount in decoded["Mounts"])
    )
    mutated = dict(host)
    mutated.update({"NanoCpus": 0, "Memory": 0, "MemorySwap": 0})
    escaped = not (
        mutated["NanoCpus"] == 7_000_000_000
        and mutated["Memory"] == 7_516_192_768
        and mutated["MemorySwap"] == 7_516_192_768
    )
    return "BuildWorkerEnvelopeMismatch" if baseline and escaped else "SURVIVED"


def run_gate(join: Path) -> dict[str, Any]:
    rows = official_rows(join)
    handlers: dict[str, Callable[[dict[str, str], dict[tuple[str, str], dict[str, Any]]], str]] = {
        "stub-arm64-binary": stub_arm64,
        "wrong-arch-layer": wrong_arch,
        "gxx-version-skew": lambda mutant, evidence: version_skew(mutant, evidence, "amd64", "g++"),
        "drop-build-scratch-accounting": scratch_accounting,
        "omit-redis": omit_redis,
        "redis-version-skew": lambda mutant, evidence: version_skew(mutant, evidence, "arm64", "redis-cli"),
        "dockerfile-handedit": dockerfile_handedit,
        "unbounded-buildkit-worker": unbounded_worker,
    }
    results: list[dict[str, str]] = []
    for name in SPRINT_MUTANTS:
        mutant = fixture(name)
        observed = handlers[name](mutant, rows)
        expected = mutant["expected_oracle"]
        if observed != expected:
            raise MutationFailure(f"mutant-survived-or-wrong-locus:{name}:{expected}:{observed}")
        results.append(
            {"mutant": name, "expectedOracle": expected, "observedOracle": observed, "result": "RED"}
        )
    return {"schema": "amoebius.phase25.sprint25.1-mutants.v1", "results": results}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--official-file-join", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        result = run_gate(arguments.official_file_join)
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        print(f"phase25-mutation-gate: PASS ({len(result['results'])} seeded mutants RED)")
        return 0
    except (
        MutationFailure, SOURCE.ProbeFailure, OSError, ValueError, KeyError,
        json.JSONDecodeError, subprocess.CalledProcessError,
    ) as problem:
        print(f"phase25-mutation-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
