#!/usr/bin/env python3
"""Execute every pinned Phase-25 binary in its source or assembled image."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
ORACLE = ROOT / "test/fixtures/phase25/bake_inventory_expected.dhall"
CATALOG = ROOT / "dhall/amoebius/BakeCatalog.dhall"
EXCEPTIONS = ROOT / "test/fixtures/phase25/nonstandard_binary_probes.tsv"
EXPECTED_MACHINE = {"amd64": 62, "arm64": 183}
FORBIDDEN_PAYLOAD_PATTERNS = (
    "*llama*", "*whisper*", "*onnxruntime*", "*audiveris*",
    "*infernix-adapter*", "*jitml-adapter*",
)


class ProbeFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(arguments), cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=timeout, check=False,
    )


def require_executable(name: str) -> str:
    found = shutil.which(name)
    if not found:
        raise ProbeFailure(f"missing-executable:{name}")
    return str(Path(found).resolve())


def decode_dhall(path: Path) -> Any:
    result = run((require_executable("dhall-to-json"), "--file", str(path)), timeout=60)
    if result.returncode:
        raise ProbeFailure(f"dhall-decode:{path.name}:{result.stdout}")
    return json.loads(result.stdout)


def catalog_steps(catalog: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    for stage in catalog["stages"]:
        content = stage["content"]
        for row in [content["head"], *content["tail"]]:
            name = str(row["name"])
            if name in rows:
                raise ProbeFailure(f"duplicate-catalog-row:{name}")
            rows[name] = row
    return rows


def acquisition_identity(row: dict[str, Any]) -> tuple[str, str]:
    """What this step acquires from, and where its integrity value comes from.

    `dhall-to-json` drops the union arm name, so the rung is recovered from the
    fields the arm carries: a package name is rung 1, a publisher is rung 2, a
    source image is the scavenge rung, and a step with none of the three is built
    from source. That recovery is deliberately structural rather than a name
    lookup — a new arm without a distinguishing field would fail here rather than
    be silently classified as a build product.

    None of the three returns a digest. Repository-layout doctrine section 4 makes
    an integrity value resolver output: rung 1 resolves it from the archive and
    rung 2 from the publisher's own manifest, both during the build, so what an
    authored file can carry is the provenance and not the value.
    """
    if "package" in row:
        return f"apt:{row['package']}={row['packageVersion']}", "sha256:resolved-from-the-archive-at-build"
    if "publisher" in row:
        return f"{row['publisher']}@{row['releaseVersion']}", "sha256:resolved-from-the-publisher-manifest"
    if "sourceImage" in row:
        return str(row["sourceImage"]), str(row["sourceDigest"])
    source = row.get("source")
    if isinstance(source, dict):
        if "repository" in source:
            return (
                f"{source['repository']}@{source['reference']}",
                "sha256:resolved-from-the-module-checksum-database-at-build",
            )
        if "distribution" in source:
            return (
                f"pypi:{source['distribution']}=={source['distributionVersion']}",
                "sha256:resolved-from-the-package-index-at-build",
            )
        if "cabalTarget" in source:
            return "amoebius-source", "sha256:source-bound-at-build"
    raise ProbeFailure(f"unclassifiable-step:{row.get('name', '?')}")


def load_exceptions() -> dict[str, tuple[int, str]]:
    with EXCEPTIONS.open(encoding="utf-8", newline="") as handle:
        rows = csv.DictReader(handle, delimiter="\t")
        return {
            row["catalog_name"]: (int(row["expected_exit"]), row["expected_output"])
            for row in rows
        }


def reconcile() -> list[tuple[dict[str, Any], dict[str, Any]]]:
    """Join the independently authored oracle to the catalog, both ways.

    Both directions, because one direction is not a reconciliation: a catalog that
    dropped a binary would satisfy an oracle-driven loop for every row it still
    had, and a catalog that added one would satisfy a catalog-driven loop for
    every row the oracle happened to name.
    """
    oracle_rows = decode_dhall(ORACLE)
    catalog_rows = catalog_steps(decode_dhall(CATALOG))
    pairs: list[tuple[dict[str, Any], dict[str, Any]]] = []
    named = {str(row["catalogName"]) for row in oracle_rows}
    unauthored = sorted(set(catalog_rows) - named)
    if unauthored:
        raise ProbeFailure(f"catalog-step-no-oracle-row:{','.join(unauthored)}")
    for oracle in oracle_rows:
        name = str(oracle["catalogName"])
        catalog = catalog_rows.get(name)
        if catalog is None:
            raise ProbeFailure(f"oracle-row-missing-from-catalog:{name}")
        acquisition, integrity = acquisition_identity(catalog)
        expected = (
            oracle["acquisition"], oracle["integrity"], oracle["version"],
            oracle["arguments"], oracle["kind"],
        )
        actual = (
            acquisition, integrity, catalog["expectedVersion"],
            catalog["arguments"], catalog["kind"],
        )
        if expected != actual:
            raise ProbeFailure(f"oracle-catalog-drift:{name}:{expected!r}:{actual!r}")
        pairs.append((oracle, catalog))
    return pairs


def oracle_inventory() -> list[dict[str, Any]]:
    rows = decode_dhall(ORACLE)
    if not isinstance(rows, list):
        raise ProbeFailure("oracle-inventory-not-a-list")
    return rows


def copy_binary(docker: str, reference: str, platform: str, path: str, destination: Path) -> None:
    created = run((docker, "create", "--platform", f"linux/{platform}", reference), timeout=300)
    if created.returncode:
        raise ProbeFailure(f"docker-create:{reference}:{platform}:{created.stdout}")
    container = created.stdout.strip()
    try:
        copied = run((docker, "cp", "-L", f"{container}:{path}", str(destination)), timeout=300)
        if copied.returncode:
            raise ProbeFailure(f"docker-cp:{reference}:{platform}:{path}:{copied.stdout}")
    finally:
        removed = run((docker, "rm", container), timeout=60)
        if removed.returncode:
            raise ProbeFailure(f"docker-rm:{container}:{removed.stdout}")


def elf_machine(path: Path) -> int:
    with path.open("rb") as handle:
        header = handle.read(20)
    if len(header) < 20 or header[:4] != b"\x7fELF":
        raise ProbeFailure(f"not-elf:{path.name}")
    byte_order = "<" if header[5] == 1 else ">" if header[5] == 2 else ""
    if not byte_order:
        raise ProbeFailure(f"invalid-elf-byte-order:{path.name}:{header[5]}")
    return int(struct.unpack(byte_order + "H", header[18:20])[0])


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def probe_final_one(
    docker: str,
    oracle: dict[str, Any],
    reference: str,
    platform: str,
    exceptions: dict[str, tuple[int, str]],
) -> dict[str, str]:
    name = str(oracle["catalogName"])
    executable = str(oracle["binary"])
    expected_exit, marker = exceptions.get(name, (0, str(oracle["version"])))
    executed = run(
        (docker, "run", "--rm", "--platform", f"linux/{platform}",
         "--entrypoint", executable, reference, *map(str, oracle["arguments"])),
        timeout=600,
    )
    if executed.returncode != expected_exit:
        raise ProbeFailure(
            f"final-probe-exit:{name}:{platform}:expected-{expected_exit}:"
            f"got-{executed.returncode}:{executed.stdout}"
        )
    if marker not in executed.stdout:
        raise ProbeFailure(
            f"final-probe-output:{name}:{platform}:missing-{marker!r}:{executed.stdout}"
        )
    machine = "launcher"
    with tempfile.TemporaryDirectory(prefix="amoebius-phase25-final-elf-") as temporary:
        local = Path(temporary) / "binary"
        copy_binary(docker, reference, platform, executable, local)
        binary_digest = sha256_file(local)
        if oracle["kind"] == "Elf":
            observed = elf_machine(local)
            expected = EXPECTED_MACHINE[platform]
            if observed != expected:
                raise ProbeFailure(
                    f"final-elf-machine:{name}:{platform}:expected-{expected}:got-{observed}"
                )
            machine = str(observed)
    return {
        "catalog_name": name,
        "platform": f"linux/{platform}",
        "exit": str(executed.returncode),
        "marker": marker,
        "elf_machine": machine,
        "sha256": binary_digest,
        "output": " ".join(executed.stdout.split())[-240:],
    }


def probe_forbidden_payloads(docker: str, reference: str, platform: str) -> None:
    for pattern in FORBIDDEN_PAYLOAD_PATTERNS:
        inspected = run(
            (
                docker, "run", "--rm", "--platform", f"linux/{platform}",
                "--user", "0:0", "--entrypoint", "/usr/bin/find", reference,
                "/", "-xdev", "-iname", pattern, "-print",
            ),
            timeout=600,
        )
        if inspected.returncode:
            raise ProbeFailure(
                f"forbidden-payload-scan-exit:{platform}:{pattern}:"
                f"{inspected.returncode}:{inspected.stdout}"
            )
        matches = [line for line in inspected.stdout.splitlines() if line.strip()]
        if matches:
            raise ProbeFailure(
                f"forbidden-payload-present:{platform}:{pattern}:{','.join(matches[:10])}"
            )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", action="append", choices=sorted(EXPECTED_MACHINE))
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--reconcile-only", action="store_true")
    parser.add_argument(
        "--final-image",
        help="probe the assembled image reference instead of each immutable source image",
    )
    parser.add_argument(
        "--keep-going",
        action="store_true",
        help="report every per-binary failure instead of stopping at the first one",
    )
    arguments = parser.parse_args(argv)
    try:
        pairs = reconcile()
        if arguments.reconcile_only:
            print(f"phase25-source-probe: RECONCILE-PASS ({len(pairs)} baked binaries)")
            return 0
        docker = require_executable("docker")
        exceptions = load_exceptions()
        platforms = arguments.platform or ["amd64", "arm64"]
        results: list[dict[str, str]] = []
        failures: list[str] = []
        if not arguments.final_image:
            # The pre-assembly probe went with the scavenge rung it belonged to.
            # It executed a binary inside the public image the catalog copied it
            # out of; no rung above that has an image to enter, and the assembled
            # monocontainer is in any case the artifact the claim is about.
            raise ProbeFailure("probe-needs-final-image: no rung above CopyOci has a source image to probe")
        if arguments.final_image:
            for platform in platforms:
                print(
                    f"phase25-final-probe: forbidden-payload absence linux/{platform}",
                    file=sys.stderr,
                    flush=True,
                )
                probe_forbidden_payloads(docker, arguments.final_image, platform)
            for oracle in oracle_inventory():
                for platform in platforms:
                    print(
                        f"phase25-final-probe: {oracle['catalogName']} linux/{platform}",
                        file=sys.stderr,
                        flush=True,
                    )
                    try:
                        results.append(
                            probe_final_one(
                                docker, oracle, arguments.final_image, platform, exceptions
                            )
                        )
                    except ProbeFailure as problem:
                        if not arguments.keep_going:
                            raise
                        failures.append(str(problem))
                        print(f"phase25-final-probe: FAIL: {problem}", file=sys.stderr)
        if failures:
            print(
                f"phase25-final-probe: FAIL ({len(failures)} failures; "
                f"{len(results)} executions passed)",
                file=sys.stderr,
            )
            return 1
        fieldnames = ["catalog_name", "platform", "exit", "marker", "elf_machine", "sha256", "output"]
        output = arguments.evidence
        if output:
            output.parent.mkdir(parents=True, exist_ok=True)
            handle = output.open("w", encoding="utf-8", newline="")
        else:
            handle = sys.stdout
        try:
            writer = csv.DictWriter(handle, delimiter="\t", fieldnames=fieldnames, lineterminator="\n")
            writer.writeheader()
            writer.writerows(results)
        finally:
            if output:
                handle.close()
        mode = "final" if arguments.final_image else "source"
        print(f"phase25-{mode}-probe: PASS ({len(results)} executions)")
        return 0
    except (ProbeFailure, OSError, ValueError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        mode = "final" if arguments.final_image else "source"
        print(f"phase25-{mode}-probe: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
