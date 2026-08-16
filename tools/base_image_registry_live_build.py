#!/usr/bin/env python3
"""Drive the Sprint-25.1 live build and produce the inputs its gate audits.

`tools/base_image_registry_bake_gate.py` audits four things it does not create: the host
snapshot the build was admitted against, the OCI export, and one executed-probe table
per architecture. Nothing produced them, so the gate could not be invoked at all.
This is what produces them, in the order the claim requires:

  render -> compare against the committed golden -> observe the host -> admit ->
  build -> load each architecture -> execute every baked binary by absolute path

The render happens first and is compared to `test/fixture/base_image_registry/Dockerfile.golden`
before anything is built, so a build cannot proceed from a Dockerfile the catalog did
not produce. The admission is `amoebius admitted-buildx-oci`, which mints a
single-use token from the observed snapshot and refuses to start BuildKit without it;
this tool passes the observation through and never decides admission itself.
"""

from __future__ import annotations

import argparse
import gzip
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path
from typing import Any, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "dhall/amoebius/BakeCatalog.dhall"
GOLDEN = ROOT / "test/fixture/base_image_registry/Dockerfile.golden"
BUILDKIT_CONFIG = ROOT / "test/fixture/base_image_registry/buildkitd.toml"
BUILDER_NAME = "amoebius-base-image-registry-bounded"
BUILDKIT_CONTAINER = "amoebius-base-image-registry-buildkitd"
STATE_VOLUME = "amoebius-base-image-registry-buildkit-state"
DOCKER = "/usr/bin/docker"
PLATFORMS = ("amd64", "arm64")


class BuildFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, timeout: int = 14400, check: bool = True) -> str:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=timeout, check=False,
    )
    if check and result.returncode:
        raise BuildFailure(f"{arguments[0]}:exit-{result.returncode}\n{result.stdout[-6000:]}")
    return result.stdout


def amoebius(subcommand: Sequence[str], *, timeout: int = 14400) -> str:
    resolved = toolchain.resolve(["cabal", "ghc"])
    return run(
        (resolved["cabal"]["path"],
         f"--builddir={ROOT / '.build/dist-newstyle/base-image-registry'}",
         f"--store-dir={ROOT / '.build/cabal-store'}", "--jobs=1",
         f"--with-compiler={resolved['ghc']['path']}",
         "run", "-v0", "amoebius", "--", *subcommand),
        timeout=timeout,
    )


def render(context: Path) -> Path:
    """Render the Dockerfile, and refuse to build one the catalog did not produce."""
    rendered = amoebius(("render-bake-dockerfile", str(CATALOG)), timeout=1800)
    if rendered != GOLDEN.read_text(encoding="utf-8"):
        raise BuildFailure(
            "rendered-dockerfile-differs-from-golden: the committed golden is the "
            "renderer's pinned behaviour, so a build must not proceed past it"
        )
    target = context / "Dockerfile"
    target.write_text(rendered, encoding="utf-8")
    print(f"  ok    rendered Dockerfile matches {GOLDEN.relative_to(ROOT)}")
    return target


def clear_builder(docker_config: Path, scratch_root: Path) -> None:
    """Remove any previous builder, so the snapshot observes no unknown commitment.

    The preflight rejects a host that already carries one; this is the cleanup that
    makes the rejection mean "somebody else's build" rather than "our own last run".

    The state directory goes with it. `volume rm` removes docker's record of a bind
    volume without touching what it binds to, so BuildKit's content store survived
    every previous run and grew monotonically on the named scratch backing until it
    exceeded the provision — a build refused for space a previous build is holding.
    A builder declared fresh whose content store is not is neither.
    """
    run((DOCKER, "--config", str(docker_config), "buildx", "rm", "--force", BUILDER_NAME),
        timeout=300, check=False)
    run((DOCKER, "--config", str(docker_config), "rm", "--force", BUILDKIT_CONTAINER),
        timeout=300, check=False)
    run((DOCKER, "--config", str(docker_config), "volume", "rm", "--force", STATE_VOLUME),
        timeout=300, check=False)
    state = scratch_root / "buildkit-state"
    if state.is_dir():
        # Root-owned by the privileged worker, so it is removed by one too.
        run(("/usr/bin/sudo", "-n", "/usr/bin/rm", "-rf", str(state)), timeout=1800, check=False)
    state.mkdir(parents=True, exist_ok=True)


def preflight(evidence: Path, cache_root: Path, scratch_root: Path, docker_config: Path) -> dict[str, Any]:
    target = evidence / "build-preflight-corrected.json"
    run((sys.executable, "tools/base_image_registry_build_preflight.py",
         "--cache-root", str(cache_root), "--scratch-root", str(scratch_root),
         "--docker-config", str(docker_config), "--evidence", str(target)), timeout=1800)
    observed = json.loads(target.read_text(encoding="utf-8"))
    print(f"  ok    host snapshot {observed['observedBuildFingerprint'][:23]}…")
    return observed


def build(
    observed: dict[str, Any], dockerfile: Path, context: Path, artifact: Path,
    cache_root: Path, scratch_root: Path, docker_config: Path, builder_image: str,
) -> None:
    docker_host = os.environ.get("DOCKER_HOST", "")
    test_root = os.environ.get("AMOEBIUS_TEST_ROOT", "")
    if not docker_host.startswith("unix://") or not Path(test_root).is_absolute():
        raise BuildFailure("project-docker-boundary-absent")
    artifact.parent.mkdir(parents=True, exist_ok=True)
    amoebius(
        (
            "admitted-buildx-oci",
            str(CATALOG),
            observed["observedBuildFingerprint"],
            str(observed["residualCpuMillis"]),
            str(observed["residualMemoryBytes"]),
            str(observed["scratchCapacityBytes"]),
            str(observed["cacheCapacityBytes"]),
            str(observed["cacheResidentBytes"]),
            DOCKER,
            docker_host,
            test_root,
            str(docker_config),
            BUILDER_NAME,
            str(dockerfile),
            str(context),
            str(artifact),
            str(cache_root),
            str(scratch_root),
            str(BUILDKIT_CONFIG),
            builder_image,
            BUILDKIT_CONTAINER,
            STATE_VOLUME,
        ),
        timeout=86400,
    )
    print(f"  ok    admitted build exported {artifact.name} ({artifact.stat().st_size} bytes)")


def index_digest_of(archive: tarfile.TarFile) -> str:
    """The manifest-list digest this run's export advertises.

    Read out of the archive rather than accepted from the caller: the digest the
    four sprint receipts must agree on is a property of the bytes on disk, and an
    argument would let a caller assert one the export does not have.
    """
    member = archive.extractfile("index.json")
    if member is None:
        raise BuildFailure("oci-export-has-no-index")
    manifests = json.loads(member.read()).get("manifests", [])
    if len(manifests) != 1:
        raise BuildFailure(f"oci-export-index-entries:{len(manifests)}")
    return str(manifests[0]["digest"])


def index_digest(artifact: Path) -> str:
    with tarfile.open(artifact) as archive:
        return index_digest_of(archive)


def oci_blob(archive: tarfile.TarFile, digest: str) -> bytes:
    member = archive.extractfile("blobs/" + digest.replace(":", "/"))
    if member is None:
        raise BuildFailure(f"oci-blob-absent:{digest}")
    return member.read()


def platform_manifest(archive: tarfile.TarFile, arch: str) -> dict[str, Any]:
    """The child manifest the export advertises for one architecture."""
    index = json.loads(oci_blob(archive, index_digest_of(archive)))
    matches = [
        row for row in index.get("manifests", [])
        if row.get("platform", {}).get("os") == "linux"
        and row.get("platform", {}).get("architecture") == arch
    ]
    if len(matches) != 1:
        raise BuildFailure(f"oci-index-platform-count:{arch}:{len(matches)}")
    return json.loads(oci_blob(archive, matches[0]["digest"]))


def load_platform(artifact: Path, arch: str, docker_config: Path, staging: Path) -> str:
    """Load one architecture out of the multi-platform export and tag it.

    Loaded rather than rebuilt: the claim is about the bytes this run exported, and a
    second build would produce a second artifact to make the claim about. `docker
    load` will not read an OCI layout on a classic image store — it wants a
    docker-format archive with a `manifest.json` — so the layout's own config and
    layer blobs are repackaged into that shape. Nothing is recompressed or
    recomputed: each layer is this export's blob, decompressed, and the config is
    copied byte for byte, so the loaded image is the exported one in a different
    envelope.
    """
    reference = f"amoebius-base-image-registry-final:{arch}"
    staging.mkdir(parents=True, exist_ok=True)
    converted = staging / f"docker-{arch}.tar"
    with tarfile.open(artifact) as archive:
        manifest = platform_manifest(archive, arch)
        config_digest = manifest["config"]["digest"]
        config = oci_blob(archive, config_digest)
        layer_names: list[str] = []
        with tarfile.open(converted, "w") as out:
            entry = tarfile.TarInfo(f"{config_digest.split(':', 1)[1]}.json")
            entry.size = len(config)
            out.addfile(entry, io.BytesIO(config))
            for layer in manifest["layers"]:
                blob = oci_blob(archive, layer["digest"])
                plain = gzip.decompress(blob) if layer["mediaType"].endswith("gzip") else blob
                name = f"{layer['digest'].split(':', 1)[1]}/layer.tar"
                member = tarfile.TarInfo(name)
                member.size = len(plain)
                out.addfile(member, io.BytesIO(plain))
                layer_names.append(name)
            document = json.dumps([{
                "Config": f"{config_digest.split(':', 1)[1]}.json",
                "RepoTags": [reference],
                "Layers": layer_names,
            }]).encode()
            entry = tarfile.TarInfo("manifest.json")
            entry.size = len(document)
            out.addfile(entry, io.BytesIO(document))
    run((DOCKER, "--config", str(docker_config), "load", "--input", str(converted)), timeout=7200)
    converted.unlink()
    # The repackaging is only honest if the result is the same image. A docker image
    # id *is* its config digest, so comparing it against the digest the export's
    # index advertises for this platform proves the probes below run against the
    # bytes this build exported — not against something assembled beside them.
    loaded = run(
        (DOCKER, "--config", str(docker_config), "image", "inspect", reference, "--format", "{{.Id}}"),
        timeout=300,
    ).strip()
    if loaded != config_digest:
        raise BuildFailure(
            f"loaded-image-is-not-the-exported-one:{arch}:{loaded}!={config_digest}"
        )
    print(
        f"  ok    linux/{arch} loaded as {reference}: {len(layer_names)} layer(s), "
        f"id equals the export's config digest"
    )
    return reference


def probe(reference: str, arch: str, evidence: Path, emulator: Path) -> None:
    run((sys.executable, "tools/base_image_registry_source_probe.py",
         "--final-image", reference, "--platform", arch,
         "--emulator", str(emulator),
         "--evidence", str(evidence / f"final-probes-{arch}.tsv")), timeout=14400)
    print(f"  ok    linux/{arch} probes executed into final-probes-{arch}.tsv")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    parser.add_argument("--context", type=Path, required=True, help="the build context carrying out/")
    parser.add_argument("--artifact", type=Path, required=True, help="where this run exports its OCI archive")
    parser.add_argument("--cache-root", type=Path, required=True)
    parser.add_argument("--scratch-root", type=Path, required=True)
    parser.add_argument("--docker-config", type=Path, required=True)
    parser.add_argument("--builder-image", required=True, help="the resolved BuildKit builder image reference")
    parser.add_argument(
        "--emulator",
        type=Path,
        required=True,
        help="the extracted BuildKit emulator for the host's non-native platform",
    )
    arguments = parser.parse_args(argv)
    arguments.evidence.mkdir(parents=True, exist_ok=True)
    arguments.docker_config.mkdir(parents=True, exist_ok=True)
    try:
        print("phase25 live build — render, admit, build, load, probe\n")
        dockerfile = render(arguments.context)
        clear_builder(arguments.docker_config, arguments.scratch_root)
        if arguments.artifact.exists():
            # A previous export at this path would be audited as this run's.
            arguments.artifact.unlink()
        observed = preflight(
            arguments.evidence, arguments.cache_root, arguments.scratch_root, arguments.docker_config
        )
        build(
            observed, dockerfile, arguments.context, arguments.artifact,
            arguments.cache_root, arguments.scratch_root, arguments.docker_config,
            arguments.builder_image,
        )
        staging = arguments.scratch_root / "docker-format"
        for arch in PLATFORMS:
            probe(
                load_platform(arguments.artifact, arch, arguments.docker_config, staging),
                arch, arguments.evidence, arguments.emulator,
            )
        digest = index_digest(arguments.artifact)
        (arguments.evidence / "live-build.json").write_text(
            json.dumps(
                {
                    "schema": "amoebius.phase25.live-build.v1",
                    "imageIndexDigest": digest,
                    "artifact": str(arguments.artifact),
                    "artifactBytes": arguments.artifact.stat().st_size,
                    "observedBuildFingerprint": observed["observedBuildFingerprint"],
                    "builderImage": arguments.builder_image,
                },
                indent=2, sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )
        print(f"  ok    index digest {digest}")
        print("\nphase25-live-build: PASS (the Sprint-25.1 gate's inputs are this run's)")
        return 0
    except (BuildFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase25-live-build: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
