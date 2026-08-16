#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import tarfile
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TEMP_ROOT = ROOT / ".build/tmp/base-image-registry-specs"
TEMP_ROOT.mkdir(parents=True, exist_ok=True)
SPEC = importlib.util.spec_from_file_location("base_image_registry_oci_probe", ROOT / "tools/base_image_registry_oci_probe.py")
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)


def digest(payload: bytes) -> str:
    return "sha256:" + hashlib.sha256(payload).hexdigest()


class OciProbeTest(unittest.TestCase):
    def test_chain_ids_match_containerd_definition(self) -> None:
        first = "sha256:" + "1" * 64
        second = "sha256:" + "2" * 64
        self.assertEqual(first, PROBE.chain_ids([first, second])[0])
        self.assertEqual(
            "sha256:" + hashlib.sha256(f"{first} {second}".encode()).hexdigest(),
            PROBE.chain_ids([first, second])[1],
        )

    def test_two_platform_layout_is_measured_and_hashed(self) -> None:
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as temporary:
            layout = Path(temporary)
            (layout / "blobs/sha256").mkdir(parents=True)
            layer = self.layer_tar()
            layer_descriptor = self.store(layout, layer, "application/vnd.oci.image.layer.v1.tar")
            children = []
            for architecture in ("amd64", "arm64"):
                config = json.dumps(
                    {
                        "architecture": architecture,
                        "rootfs": {"type": "layers", "diff_ids": [digest(layer)]},
                    },
                    separators=(",", ":"),
                ).encode()
                config_descriptor = self.store(layout, config, "application/vnd.oci.image.config.v1+json")
                manifest = json.dumps(
                    {"schemaVersion": 2, "config": config_descriptor, "layers": [layer_descriptor]},
                    separators=(",", ":"),
                ).encode()
                child = self.store(layout, manifest, "application/vnd.oci.image.manifest.v1+json")
                child["platform"] = {"os": "linux", "architecture": architecture}
                children.append(child)
            (layout / "index.json").write_text(
                json.dumps({"schemaVersion": 2, "manifests": children}), encoding="utf-8"
            )
            bounds = {
                "schema": PROBE.EXPECTED_BOUNDS_SCHEMA,
                "indexBytes": 1048576,
                "childManifestBytes": 1048576,
                "configBytes": 1048576,
                "compressedLayerBytes": 1048576,
                "unpackedLayerBytes": 1048576,
                "importWorkspaceBytes": 2097152,
            }
            result = PROBE.measure(layout, bounds)
        self.assertEqual(["amd64", "arm64"], [row["architecture"] for row in result["platforms"]])
        self.assertEqual(6, len(result["registryObjects"]))
        self.assertEqual(5, result["platforms"][0]["layers"][0]["unpackedTarBytes"])
        self.assertGreater(result["layoutIndexBytes"], 0)
        self.assertEqual(result["layoutRootIdentity"], result["imageIndexDigest"])
        self.assertEqual(PROBE.EXPECTED_BOUNDS_SCHEMA, result["bounds"]["schema"])

    def test_one_byte_under_bound_is_rejected(self) -> None:
        result = {
            "imageIndexBytes": 8,
            "platforms": [
                {
                    "os": "linux",
                    "architecture": "amd64",
                    "childManifestBytes": 4,
                    "configBytes": 3,
                    "derivedPeakImportWorkspaceBytes": 9,
                    "layers": [
                        {
                            "digest": "sha256:" + "1" * 64,
                            "compressedBytes": 5,
                            "unpackedTarBytes": 7,
                        }
                    ],
                }
            ],
        }
        bounds = {
            "schema": PROBE.EXPECTED_BOUNDS_SCHEMA,
            "indexBytes": 7,
            "childManifestBytes": 4,
            "configBytes": 3,
            "compressedLayerBytes": 5,
            "unpackedLayerBytes": 7,
            "importWorkspaceBytes": 9,
        }
        with self.assertRaisesRegex(PROBE.OciFailure, "artifact-bound-exceeded:index"):
            PROBE.validate_bounds(result, bounds)

    def test_registry_digest_kind_collision_is_rejected_in_both_orders(self) -> None:
        identity = "sha256:" + "a" * 64
        for first, second in (("layer", "config-amd64"), ("config-amd64", "layer")):
            objects: dict[str, dict[str, object]] = {}
            PROBE.add_registry_object(objects, identity, first, 7)
            with self.assertRaisesRegex(PROBE.OciFailure, "registry-digest-kind-conflict"):
                PROBE.add_registry_object(objects, identity, second, 7)

    def test_registry_layer_deduplication_remains_valid(self) -> None:
        identity = "sha256:" + "b" * 64
        objects: dict[str, dict[str, object]] = {}
        PROBE.add_registry_object(objects, identity, "layer", 7)
        PROBE.add_registry_object(objects, identity, "layer", 7)
        self.assertEqual(1, len(objects))

    def test_unmodeled_manifest_platform_is_rejected(self) -> None:
        root = {
            "manifests": [
                {
                    "mediaType": "application/vnd.oci.image.manifest.v1+json",
                    "digest": "sha256:" + "c" * 64,
                    "size": 1,
                    "platform": {"os": "unknown", "architecture": "unknown"},
                }
            ]
        }

        class UnreadLayout:
            pass

        with self.assertRaisesRegex(PROBE.OciFailure, "manifest-platform-unexpected"):
            PROBE.platform_descriptors(UnreadLayout(), root)

    def test_layout_wrapper_resolves_the_registry_index_blob(self) -> None:
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as temporary:
            layout_root = Path(temporary)
            (layout_root / "blobs/sha256").mkdir(parents=True)
            registry_index = json.dumps(
                {"schemaVersion": 2, "manifests": []}, separators=(",", ":")
            ).encode()
            descriptor = self.store(
                layout_root, registry_index, "application/vnd.oci.image.index.v1+json"
            )
            wrapper = json.dumps(
                {"schemaVersion": 2, "manifests": [descriptor]}, separators=(",", ":")
            ).encode()
            layout = PROBE.Layout(layout_root)
            try:
                identity, size, decoded = PROBE.image_index(
                    layout, wrapper, json.loads(wrapper)
                )
            finally:
                layout.close()
        self.assertEqual(descriptor["digest"], identity)
        self.assertEqual(len(registry_index), size)
        self.assertEqual([], decoded["manifests"])

    @staticmethod
    def layer_tar() -> bytes:
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w") as archive:
            info = tarfile.TarInfo("file")
            info.size = 5
            archive.addfile(info, io.BytesIO(b"hello"))
        return output.getvalue()

    @staticmethod
    def store(layout: Path, payload: bytes, media_type: str) -> dict[str, object]:
        identity = digest(payload)
        (layout / PROBE.blob_name(identity)).write_bytes(payload)
        return {"mediaType": media_type, "digest": identity, "size": len(payload)}


if __name__ == "__main__":
    unittest.main()
