#!/usr/bin/env python3
"""Join official OCI file bytes to the already executed per-architecture probes."""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import posixpath
import struct
import sys
import tarfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, BinaryIO, Sequence


ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"module-load:{path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


OCI = load_module("phase25_oci_probe", ROOT / "tools/phase25_oci_probe.py")
SOURCE = load_module("phase25_source_probe", ROOT / "tools/phase25_source_probe.py")


class FileProbeFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class Entry:
    layer_digest: str
    member_name: str
    kind: str
    link_name: str


def normalized(value: str) -> str:
    result = posixpath.normpath(value.lstrip("/"))
    if result in ("", ".") or result == ".." or result.startswith("../"):
        raise FileProbeFailure(f"unsafe-layer-path:{value}")
    return result


def apply_whiteout(files: dict[str, Entry], name: str) -> bool:
    base = posixpath.basename(name)
    if not base.startswith(".wh."):
        return False
    parent = posixpath.dirname(name)
    if base == ".wh..wh..opq":
        prefix = parent.rstrip("/") + "/"
        for path in [path for path in files if path.startswith(prefix)]:
            del files[path]
    else:
        target = posixpath.join(parent, base[4:])
        files.pop(target, None)
        prefix = target.rstrip("/") + "/"
        for path in [path for path in files if path.startswith(prefix)]:
            del files[path]
    return True


def file_map(layout: Any, layers: list[dict[str, Any]]) -> dict[str, Entry]:
    files: dict[str, Entry] = {}
    for descriptor in layers:
        digest = str(descriptor["digest"])
        with layout.open(OCI.blob_name(digest)) as handle:
            with tarfile.open(fileobj=handle, mode="r|*") as archive:
                for member in archive:
                    name = normalized(member.name)
                    if apply_whiteout(files, name):
                        continue
                    if member.isfile():
                        files[name] = Entry(digest, member.name, "file", "")
                    elif member.issym():
                        files[name] = Entry(digest, member.name, "symlink", member.linkname)
                    elif member.islnk():
                        files[name] = Entry(digest, member.name, "hardlink", member.linkname)
    return files


def resolve(files: dict[str, Entry], path: str) -> tuple[str, Entry]:
    current = normalized(path)
    seen: set[str] = set()
    while True:
        if current in seen:
            raise FileProbeFailure(f"layer-link-cycle:{path}")
        seen.add(current)
        entry = files.get(current)
        if entry is None:
            raise FileProbeFailure(f"official-file-missing:/{current}")
        if entry.kind == "file":
            return current, entry
        if entry.kind == "symlink":
            target = entry.link_name
            current = normalized(
                target if target.startswith("/") else posixpath.join(posixpath.dirname(current), target)
            )
        elif entry.kind == "hardlink":
            current = normalized(entry.link_name)
        else:
            raise FileProbeFailure(f"official-file-kind:{current}:{entry.kind}")


def digest_members(
    layout: Any, selected: dict[str, set[str]]
) -> dict[tuple[str, str], tuple[str, bytes]]:
    measured: dict[tuple[str, str], tuple[str, bytes]] = {}
    for layer_digest, names in selected.items():
        with layout.open(OCI.blob_name(layer_digest)) as handle:
            with tarfile.open(fileobj=handle, mode="r|*") as archive:
                for member in archive:
                    if member.name not in names:
                        continue
                    source: BinaryIO | None = archive.extractfile(member)
                    if source is None:
                        raise FileProbeFailure(f"official-file-unreadable:{member.name}")
                    digest = hashlib.sha256()
                    header = bytearray()
                    for chunk in iter(lambda: source.read(1024 * 1024), b""):
                        if len(header) < 20:
                            header.extend(chunk[: 20 - len(header)])
                        digest.update(chunk)
                    measured[(layer_digest, member.name)] = (
                        "sha256:" + digest.hexdigest(), bytes(header)
                    )
        absent = names - {name for digest, name in measured if digest == layer_digest}
        if absent:
            raise FileProbeFailure(f"official-layer-members-missing:{layer_digest}:{sorted(absent)}")
    return measured


def elf_machine(header: bytes) -> int:
    if len(header) < 20 or header[:4] != b"\x7fELF":
        raise FileProbeFailure("official-binary-not-elf")
    byte_order = "<" if header[5] == 1 else ">" if header[5] == 2 else ""
    if not byte_order:
        raise FileProbeFailure("official-elf-byte-order")
    return int(struct.unpack(byte_order + "H", header[18:20])[0])


def probe_rows(path: Path) -> dict[tuple[str, str], dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    return {(row["platform"].split("/")[1], row["catalog_name"]): row for row in rows}


def verify(layout_path: Path, evidence_paths: list[Path]) -> dict[str, Any]:
    executed: dict[tuple[str, str], dict[str, str]] = {}
    for path in evidence_paths:
        for key, row in probe_rows(path).items():
            if key in executed:
                raise FileProbeFailure(f"executed-probe-duplicate:{key}")
            executed[key] = row
    oracle = {str(row["catalogName"]): row for row in SOURCE.oracle_inventory()}
    expected_keys = {(arch, name) for arch in SOURCE.EXPECTED_MACHINE for name in oracle}
    if set(executed) != expected_keys:
        raise FileProbeFailure("executed-probe-domain-mismatch")

    layout = OCI.Layout(layout_path)
    try:
        root_payload = layout.read("index.json")
        root = json.loads(root_payload)
        index_digest, index_bytes, registry_index = OCI.image_index(layout, root_payload, root)
        descriptors = OCI.platform_descriptors(layout, registry_index)
        results: list[dict[str, Any]] = []
        for (_operating_system, architecture), descriptor in sorted(descriptors.items()):
            manifest = OCI.descriptor_json(layout, descriptor)
            layers = manifest.get("layers")
            if not isinstance(layers, list):
                raise FileProbeFailure(f"official-layer-list:{architecture}")
            files = file_map(layout, layers)
            selected: dict[str, set[str]] = {}
            resolved: dict[str, tuple[str, Entry]] = {}
            for name, row in oracle.items():
                actual_path, entry = resolve(files, str(row["binary"]))
                resolved[name] = (actual_path, entry)
                selected.setdefault(entry.layer_digest, set()).add(entry.member_name)
            measured = digest_members(layout, selected)
            for name, row in sorted(oracle.items()):
                actual_path, entry = resolved[name]
                digest, header = measured[(entry.layer_digest, entry.member_name)]
                prior = executed[(architecture, name)]
                if prior["sha256"] != digest:
                    raise FileProbeFailure(
                        f"executed-official-digest-mismatch:{architecture}:{name}:"
                        f"{prior['sha256']}:{digest}"
                    )
                machine: int | str = "launcher"
                if row["kind"] == "Elf":
                    machine = elf_machine(header)
                    if machine != SOURCE.EXPECTED_MACHINE[architecture]:
                        raise FileProbeFailure(
                            f"official-elf-machine:{architecture}:{name}:{machine}"
                        )
                results.append(
                    {
                        "architecture": architecture,
                        "catalogName": name,
                        "path": row["binary"],
                        "resolvedPath": "/" + actual_path,
                        "layerDigest": entry.layer_digest,
                        "sha256": digest,
                        "elfMachine": machine,
                        "executedProbeMarker": prior["marker"],
                    }
                )
        return {
            "schema": "amoebius.phase25.oci-file-execution-join.v1",
            "imageIndexDigest": index_digest,
            "imageIndexBytes": index_bytes,
            "rows": results,
        }
    finally:
        layout.close()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("layout", type=Path)
    parser.add_argument("--executed-probes", type=Path, action="append", required=True)
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        result = verify(arguments.layout, arguments.executed_probes)
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        print(f"phase25-oci-file-probe: PASS ({len(result['rows'])} official-file/execution joins)")
        return 0
    except (
        FileProbeFailure, OCI.OciFailure, SOURCE.ProbeFailure, OSError,
        ValueError, KeyError, json.JSONDecodeError, tarfile.TarError,
    ) as problem:
        print(f"phase25-oci-file-probe: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
