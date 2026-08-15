#!/usr/bin/env python3
"""Build the Phase-25 SPDX file SBOM from independently probed image bytes."""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
PROBE_SPEC = importlib.util.spec_from_file_location(
    "phase25_source_probe", ROOT / "tools/phase25_source_probe.py"
)
if PROBE_SPEC is None or PROBE_SPEC.loader is None:
    raise RuntimeError("cannot-load-phase25-source-probe")
SOURCE_PROBE = importlib.util.module_from_spec(PROBE_SPEC)
PROBE_SPEC.loader.exec_module(SOURCE_PROBE)
EXPECTED_PLATFORMS = {"linux/amd64", "linux/arm64"}


class SbomFailure(RuntimeError):
    pass


def read_rows(paths: Sequence[Path]) -> dict[tuple[str, str], dict[str, str]]:
    rows: dict[tuple[str, str], dict[str, str]] = {}
    for path in paths:
        with path.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle, delimiter="\t"):
                key = (row["catalog_name"], row["platform"])
                if key in rows:
                    raise SbomFailure(f"duplicate-probe-row:{key[0]}:{key[1]}")
                if not re.fullmatch(r"sha256:[0-9a-f]{64}", row["sha256"]):
                    raise SbomFailure(f"invalid-file-digest:{key[0]}:{key[1]}")
                rows[key] = row
    return rows


def make_sbom(probe_paths: Sequence[Path]) -> dict[str, Any]:
    oracle = SOURCE_PROBE.oracle_inventory()
    rows = read_rows(probe_paths)
    expected_keys = {
        (str(item["catalogName"]), platform)
        for item in oracle
        for platform in EXPECTED_PLATFORMS
    }
    if set(rows) != expected_keys:
        missing = sorted(expected_keys - set(rows))
        extra = sorted(set(rows) - expected_keys)
        raise SbomFailure(f"probe-inventory-mismatch:missing-{missing}:extra-{extra}")
    oracle_by_name = {str(item["catalogName"]): item for item in oracle}
    files: list[dict[str, Any]] = []
    relationships: list[dict[str, str]] = []
    identity_rows: list[str] = []
    for (name, platform), row in sorted(rows.items()):
        pinned = oracle_by_name[name]
        architecture = platform.removeprefix("linux/")
        identifier = "SPDXRef-File-" + re.sub(r"[^A-Za-z0-9.-]", "-", f"{architecture}-{name}")
        checksum = row["sha256"].removeprefix("sha256:")
        identity_rows.append(f"{name}\t{platform}\t{pinned['binary']}\t{checksum}")
        files.append(
            {
                "SPDXID": identifier,
                "fileName": str(pinned["binary"]),
                "checksums": [{"algorithm": "SHA256", "checksumValue": checksum}],
                "fileTypes": ["BINARY"],
                # `acquisition`/`integrity` replace the retired `sourceImage`/`sourceDigest`
                # pair of the pre-amendment oracle. Those two named a scavenged image, and
                # once every binary sits on a rung above scavenging there is no source image
                # to record: what the row carries is the identity the rung acquires from and
                # where the integrity value is resolved, never a digest an author typed.
                "comment": (
                    f"catalog={name}; platform={platform}; version={pinned['version']}; "
                    f"acquisition={pinned['acquisition']}; integrity={pinned['integrity']}; "
                    f"probe-exit={row['exit']}; elf-machine={row['elf_machine']}"
                ),
            }
        )
        relationships.append(
            {
                "spdxElementId": "SPDXRef-DOCUMENT",
                "relationshipType": "DESCRIBES",
                "relatedSpdxElement": identifier,
            }
        )
    namespace_digest = hashlib.sha256("\n".join(identity_rows).encode()).hexdigest()
    return {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": "amoebius-phase25-multiarch-file-inventory",
        "documentNamespace": f"urn:amoebius:phase25:sha256:{namespace_digest}",
        "creationInfo": {
            "created": "2026-08-09T00:00:00Z",
            "creators": ["Tool: amoebius-tools-phase25-sbom"],
        },
        "files": files,
        "relationships": relationships,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args(argv)
    try:
        sbom = make_sbom(arguments.probe)
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(
            json.dumps(sbom, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(
            f"phase25-sbom: PASS ({len(sbom['files'])} independently executed platform files)"
        )
        return 0
    except (SbomFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase25-sbom: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
