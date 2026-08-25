#!/usr/bin/env python3
"""Measure and verify a two-platform Phase-31 OCI image layout."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import tarfile
from pathlib import Path
from typing import Any, BinaryIO, Iterator, Sequence


EXPECTED_PLATFORMS = {("linux", "amd64"), ("linux", "arm64")}
EXPECTED_BOUNDS_SCHEMA = "amoebius.phase25.image-artifact-bounds.v1"
INDEX_MEDIA_TYPES = {
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
}
MANIFEST_MEDIA_TYPES = {
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
}


class OciFailure(RuntimeError):
    pass


class Layout:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.archive = None if path.is_dir() else tarfile.open(path, "r:*")

    def close(self) -> None:
        if self.archive is not None:
            self.archive.close()

    @contextlib.contextmanager
    def open(self, name: str) -> Iterator[BinaryIO]:
        if self.archive is None:
            with (self.path / name).open("rb") as handle:
                yield handle
            return
        try:
            member = self.archive.getmember(name)
        except KeyError as problem:
            raise OciFailure(f"missing-layout-object:{name}") from problem
        handle = self.archive.extractfile(member)
        if handle is None:
            raise OciFailure(f"layout-object-not-a-file:{name}")
        try:
            yield handle
        finally:
            handle.close()

    def json(self, name: str) -> dict[str, Any]:
        decoded = json.loads(self.read(name))
        if not isinstance(decoded, dict):
            raise OciFailure(f"json-object-required:{name}")
        return decoded

    def read(self, name: str) -> bytes:
        with self.open(name) as handle:
            return handle.read()


def blob_name(digest: str) -> str:
    algorithm, separator, value = digest.partition(":")
    if separator != ":" or algorithm != "sha256" or len(value) != 64:
        raise OciFailure(f"invalid-digest:{digest}")
    if any(character not in "0123456789abcdef" for character in value):
        raise OciFailure(f"invalid-digest:{digest}")
    return f"blobs/sha256/{value}"


def verify_descriptor(layout: Layout, descriptor: dict[str, Any]) -> tuple[str, int]:
    digest = str(descriptor.get("digest", ""))
    expected_size = int(descriptor.get("size", -1))
    measured_size = 0
    measured_digest = hashlib.sha256()
    with layout.open(blob_name(digest)) as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            measured_size += len(chunk)
            measured_digest.update(chunk)
    if measured_size != expected_size:
        raise OciFailure(f"descriptor-size:{digest}:expected-{expected_size}:got-{measured_size}")
    actual_digest = "sha256:" + measured_digest.hexdigest()
    if actual_digest != digest:
        raise OciFailure(f"descriptor-digest:{digest}:got-{actual_digest}")
    return digest, measured_size


def descriptor_json(layout: Layout, descriptor: dict[str, Any]) -> dict[str, Any]:
    verify_descriptor(layout, descriptor)
    return layout.json(blob_name(str(descriptor["digest"])))


def chain_ids(diff_ids: list[str]) -> list[str]:
    if not diff_ids:
        return []
    result = [diff_ids[0]]
    for diff_id in diff_ids[1:]:
        parent = result[-1]
        result.append("sha256:" + hashlib.sha256(f"{parent} {diff_id}".encode()).hexdigest())
    return result


def unpacked_tar_bytes(layout: Layout, descriptor: dict[str, Any]) -> int:
    with layout.open(blob_name(str(descriptor["digest"]))) as handle:
        try:
            with tarfile.open(fileobj=handle, mode="r|*") as layer:
                return sum(member.size for member in layer if member.isfile())
        except tarfile.TarError as problem:
            raise OciFailure(f"layer-not-tar:{descriptor['digest']}:{problem}") from problem


def platform_descriptors(layout: Layout, root: dict[str, Any]) -> dict[tuple[str, str], dict[str, Any]]:
    observed: dict[tuple[str, str], dict[str, Any]] = {}

    def descend(descriptor: dict[str, Any], inherited: dict[str, Any] | None = None) -> None:
        media_type = str(descriptor.get("mediaType", ""))
        platform = descriptor.get("platform") or inherited
        if media_type in INDEX_MEDIA_TYPES:
            nested = descriptor_json(layout, descriptor)
            for child in nested.get("manifests", []):
                descend(child, platform)
            return
        if media_type not in MANIFEST_MEDIA_TYPES:
            return
        if not isinstance(platform, dict):
            raise OciFailure(f"manifest-platform-absent:{descriptor.get('digest', '')}")
        key = (str(platform.get("os", "")), str(platform.get("architecture", "")))
        if key not in EXPECTED_PLATFORMS:
            raise OciFailure(f"manifest-platform-unexpected:{key[0]}/{key[1]}")
        if key in observed:
            raise OciFailure(f"manifest-platform-duplicate:{key[0]}/{key[1]}")
        observed[key] = descriptor

    for descriptor in root.get("manifests", []):
        descend(descriptor)
    if set(observed) != EXPECTED_PLATFORMS:
        rendered = ",".join(f"{os}/{arch}" for os, arch in sorted(observed))
        raise OciFailure(f"manifest-platform-set:{rendered}")
    return observed


def image_index(
    layout: Layout, root_payload: bytes, root: dict[str, Any]
) -> tuple[str, int, dict[str, Any]]:
    """Return the registry index, not the OCI-layout index.json wrapper."""
    manifests = root.get("manifests")
    if not isinstance(manifests, list) or not manifests:
        raise OciFailure("layout-index-manifests")
    if len(manifests) == 1 and isinstance(manifests[0], dict):
        descriptor = manifests[0]
        if str(descriptor.get("mediaType", "")) in INDEX_MEDIA_TYPES:
            digest, size = verify_descriptor(layout, descriptor)
            return digest, size, layout.json(blob_name(digest))
    # A directory-form fixture may use index.json itself as the image index.
    # Its bytes remain independently hashed even though an exported BuildKit
    # archive normally wraps the registry index in one OCI-layout descriptor.
    return "sha256:" + hashlib.sha256(root_payload).hexdigest(), len(root_payload), root


def measure(path: Path, bounds: dict[str, Any] | None = None) -> dict[str, Any]:
    layout = Layout(path)
    try:
        root_payload = layout.read("index.json")
        root = json.loads(root_payload)
        if not isinstance(root, dict):
            raise OciFailure("json-object-required:index.json")
        index_digest, index_bytes, registry_index = image_index(layout, root_payload, root)
        descriptors = platform_descriptors(layout, registry_index)
        root_identity = "sha256:" + hashlib.sha256(root_payload).hexdigest()
        platforms: list[dict[str, Any]] = []
        registry_objects: dict[str, dict[str, Any]] = {}
        add_registry_object(registry_objects, index_digest, "index", index_bytes)
        for (operating_system, architecture), child in sorted(descriptors.items()):
            child_digest, child_bytes = verify_descriptor(layout, child)
            manifest = layout.json(blob_name(child_digest))
            config_descriptor = manifest.get("config")
            layers = manifest.get("layers")
            if not isinstance(config_descriptor, dict) or not isinstance(layers, list) or not layers:
                raise OciFailure(f"manifest-shape:{operating_system}/{architecture}")
            config_digest, config_bytes = verify_descriptor(layout, config_descriptor)
            config = layout.json(blob_name(config_digest))
            diff_ids = config.get("rootfs", {}).get("diff_ids", [])
            if not isinstance(diff_ids, list) or len(diff_ids) != len(layers):
                raise OciFailure(f"diff-id-count:{operating_system}/{architecture}")
            chains = chain_ids([str(value) for value in diff_ids])
            measured_layers: list[dict[str, Any]] = []
            for layer_descriptor, chain_id in zip(layers, chains, strict=True):
                if not isinstance(layer_descriptor, dict):
                    raise OciFailure(f"layer-descriptor-shape:{operating_system}/{architecture}")
                layer_digest, compressed_bytes = verify_descriptor(layout, layer_descriptor)
                unpacked_bytes = unpacked_tar_bytes(layout, layer_descriptor)
                measured_layers.append(
                    {
                        "digest": layer_digest,
                        "compressedBytes": compressed_bytes,
                        "chainId": chain_id,
                        "unpackedTarBytes": unpacked_bytes,
                    }
                )
                add_registry_object(registry_objects, layer_digest, "layer", compressed_bytes)
            add_registry_object(registry_objects, config_digest, f"config-{architecture}", config_bytes)
            add_registry_object(registry_objects, child_digest, f"manifest-{architecture}", child_bytes)
            platforms.append(
                {
                    "os": operating_system,
                    "architecture": architecture,
                    "childDigest": child_digest,
                    "childManifestBytes": child_bytes,
                    "configDigest": config_digest,
                    "configBytes": config_bytes,
                    "layers": measured_layers,
                    "derivedPeakImportWorkspaceBytes": max(
                        row["compressedBytes"] + row["unpackedTarBytes"] for row in measured_layers
                    ),
                }
            )
        # index.json is the OCI-layout root and may not itself be a registry blob.
        # The publication stage records the registry manifest-list descriptor after push.
        result = {
            "schema": "amoebius.phase25.oci-measurement.v1",
            "layoutRootIdentity": root_identity,
            "layoutIndexBytes": len(root_payload),
            "imageIndexDigest": index_digest,
            "imageIndexBytes": index_bytes,
            "platforms": platforms,
            "registryObjects": [
                registry_objects[digest] for digest in sorted(registry_objects)
            ],
        }
        if bounds is not None:
            validate_bounds(result, bounds)
            result["bounds"] = bounds
        return result
    finally:
        layout.close()


def add_registry_object(objects: dict[str, dict[str, Any]], digest: str, kind: str, size: int) -> None:
    prior = objects.get(digest)
    value = {"digest": digest, "kind": kind, "storedBytes": size}
    if prior is None:
        objects[digest] = value
    elif prior["storedBytes"] != size:
        raise OciFailure(f"registry-digest-size-conflict:{digest}")
    elif prior["kind"] != kind:
        raise OciFailure(f"registry-digest-kind-conflict:{digest}:{prior['kind']}:{kind}")


def validate_bounds(result: dict[str, Any], bounds: dict[str, Any]) -> None:
    if bounds.get("schema") != EXPECTED_BOUNDS_SCHEMA:
        raise OciFailure("artifact-bounds-schema")
    require_bound("index", int(result["imageIndexBytes"]), int(bounds["indexBytes"]))
    for platform in result["platforms"]:
        identity = f"{platform['os']}/{platform['architecture']}"
        require_bound(
            f"child-manifest:{identity}",
            int(platform["childManifestBytes"]),
            int(bounds["childManifestBytes"]),
        )
        require_bound(
            f"config:{identity}",
            int(platform["configBytes"]),
            int(bounds["configBytes"]),
        )
        require_bound(
            f"import-workspace:{identity}",
            int(platform["derivedPeakImportWorkspaceBytes"]),
            int(bounds["importWorkspaceBytes"]),
        )
        for layer in platform["layers"]:
            require_bound(
                f"compressed-layer:{layer['digest']}",
                int(layer["compressedBytes"]),
                int(bounds["compressedLayerBytes"]),
            )
            require_bound(
                f"unpacked-layer:{layer['digest']}",
                int(layer["unpackedTarBytes"]),
                int(bounds["unpackedLayerBytes"]),
            )


def require_bound(identity: str, measured: int, bound: int) -> None:
    if measured <= 0:
        raise OciFailure(f"artifact-object-empty:{identity}")
    if measured > bound:
        raise OciFailure(f"artifact-bound-exceeded:{identity}:measured-{measured}:bound-{bound}")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("layout", type=Path)
    parser.add_argument("--bounds", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    arguments = parser.parse_args(argv)
    try:
        bounds = json.loads(arguments.bounds.read_text(encoding="utf-8"))
        if not isinstance(bounds, dict):
            raise OciFailure("artifact-bounds-object-required")
        result = measure(arguments.layout, bounds)
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.evidence:
            arguments.evidence.parent.mkdir(parents=True, exist_ok=True)
            arguments.evidence.write_text(encoded, encoding="utf-8")
        else:
            print(encoded, end="")
        print("phase25-oci-probe: PASS (linux/amd64 + linux/arm64, descriptor hashes and sizes verified)")
        return 0
    except (OciFailure, OSError, ValueError, json.JSONDecodeError, tarfile.TarError) as problem:
        print(f"phase25-oci-probe: FAIL: {problem}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
