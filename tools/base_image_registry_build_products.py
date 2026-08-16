#!/usr/bin/env python3
"""Produce every rung-3 build product the bake catalog declares, for both arches.

The acquisition ladder's top two rungs are rendered into the Dockerfile and happen
inside the image build. Rung 3 cannot be: building from source needs a toolchain the
runtime image has no reason to carry, so the rendered Dockerfile consumes each build
product from `out/<arch>/<name>` in the build context and this tool is what puts it
there.

Every source coordinate comes from `dhall/amoebius/BakeCatalog.dhall` — repository,
reference, package path, linker stamp, cgo requirement, distribution and interpreter
version. None is written here. A build product whose source lived in this file would
be exactly the "advice the type cannot express" that the 2026-08-13 amendment removed
from the other rungs.

The three builder images are caller-supplied resolved references, for the same reason
`tools/base_image_registry_bake_gate.py` takes `--builder-image`: which image a run used is
a run-local observation, and a default here would name one.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "dhall/amoebius/BakeCatalog.dhall"
PLATFORMS = ("amd64", "arm64")
EXPECTED_MACHINE = {"amd64": 62, "arm64": 183}
# Debian's cross toolchain triples, keyed by the architecture being built *for*.
CROSS_TRIPLE = {"arm64": "aarch64-linux-gnu", "amd64": "x86_64-linux-gnu"}
QEMU_ARCH = {"arm64": "aarch64", "amd64": "x86_64"}


class BuildFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, timeout: int = 7200) -> str:
    result = subprocess.run(
        list(arguments), cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=timeout, check=False,
    )
    if result.returncode:
        raise BuildFailure(f"{arguments[0]}:exit-{result.returncode}\n{result.stdout[-4000:]}")
    return result.stdout


def require_executable(name: str) -> str:
    found = shutil.which(name)
    if not found:
        raise BuildFailure(f"missing-executable:{name}")
    return str(Path(found).resolve())


def decode_catalog() -> dict[str, Any]:
    decoded = json.loads(run((require_executable("dhall-to-json"), "--file", str(CATALOG)), timeout=300))
    if not isinstance(decoded, dict):
        raise BuildFailure("catalog-not-a-record")
    return decoded


def build_products(catalog: dict[str, Any]) -> list[dict[str, Any]]:
    """Every step carrying a build source, in catalog order.

    `dhall-to-json` drops the union arm name, so a build product is recognised by the
    field only it has. The same structural recovery `tools/base_image_registry_source_probe.py`
    uses, for the same reason: a new arm without a distinguishing field must fail
    rather than be silently classified.
    """
    rows = []
    for stage in catalog["stages"]:
        content = stage["content"]
        for step in [content["head"], *content["tail"]]:
            if "source" in step:
                rows.append(step)
    return rows


def elf_machine(path: Path) -> int:
    with path.open("rb") as handle:
        header = handle.read(20)
    if len(header) < 20 or header[:4] != b"\x7fELF":
        raise BuildFailure(f"not-elf:{path}")
    byte_order = "<" if header[5] == 1 else ">"
    return int(struct.unpack(byte_order + "H", header[18:20])[0])


def checkout(work: Path, go: dict[str, Any]) -> Path:
    """One shallow checkout per repository and reference, reused across arches."""
    slug = go["repository"].rsplit("/", 1)[-1] + "@" + go["reference"]
    target = work / "src" / slug
    if target.is_dir():
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    run((require_executable("git"), "clone", "--quiet", "--depth", "1",
         "--branch", go["reference"], go["repository"], str(target)), timeout=3600)
    return target


def go_directive(source: Path) -> str:
    for line in (source / "go.mod").read_text(encoding="utf-8").splitlines():
        if line.startswith("go "):
            return line.split()[1]
    raise BuildFailure(f"go-mod-has-no-go-directive:{source}")


def version_at_least(observed: str, required: str) -> bool:
    def parts(value: str) -> list[int]:
        return [int(piece) for piece in value.split(".") if piece.isdigit()]
    return parts(observed) >= parts(required)


def build_go(step: dict[str, Any], work: Path, out: Path, image: str, platforms: Sequence[str]) -> None:
    go = step["source"]
    source = checkout(work, go)
    # The upstream module states the Go it needs; that is a reference side the
    # catalog does not have to duplicate and cannot drift from.
    required = go_directive(source)
    docker = require_executable("docker")
    cache = work / "gocache"
    cache.mkdir(parents=True, exist_ok=True)
    ldflags = (
        f'-X {go["versionSymbol"]}={go["versionValue"]}' if go["versionSymbol"] else ""
    )
    script = ["set -eu", 'observed="$(go env GOVERSION)"', 'echo "GOVERSION=${observed}"']
    if go["requiresCgo"]:
        # pg_query is a C library, so the non-native arch needs a cross compiler and
        # that architecture's libc headers. Declared by the catalog, not discovered.
        script += [
            "apt-get update -qq >/dev/null 2>&1",
            "apt-get install -y -qq --no-install-recommends "
            + " ".join(f"gcc-{CROSS_TRIPLE[arch]} libc6-dev-{arch}-cross" for arch in platforms
                       if arch != os.uname().machine.replace("x86_64", "amd64"))
            + " >/dev/null 2>&1",
        ]
    for arch in platforms:
        cgo = "1" if go["requiresCgo"] else "0"
        compiler = (
            f'CC={CROSS_TRIPLE[arch]}-gcc '
            if go["requiresCgo"] and arch != os.uname().machine.replace("x86_64", "amd64")
            else ""
        )
        stamp = f'-ldflags "{ldflags}" ' if ldflags else ""
        script.append(
            f'(cd /src && CGO_ENABLED={cgo} {compiler}GOOS=linux GOARCH={arch} '
            f'go build -trimpath {stamp}-o /out/{arch}/{step["name"]} {go["packagePath"]})'
        )
    output = run(
        (docker, "run", "--rm",
         "-v", f"{source}:/src", "-v", f"{out}:/out", "-v", f"{cache}:/gocache",
         "-e", "GOPATH=/gocache/gopath", "-e", "GOCACHE=/gocache/build",
         "-e", "GOFLAGS=-mod=mod -buildvcs=false",
         "-w", "/src", image, "bash", "-eu", "-c", "\n".join(script)),
        timeout=7200,
    )
    observed = next(
        (line.split("=", 1)[1].removeprefix("go") for line in output.splitlines()
         if line.startswith("GOVERSION=")),
        "",
    )
    if not version_at_least(observed, required):
        raise BuildFailure(
            f"go-toolchain-too-old:{step['name']}:builder-{observed}:module-needs-{required}"
        )
    print(f"  ok    {step['name']:<32} go {observed} >= {required} (module directive)")


def build_python(
    step: dict[str, Any],
    work: Path,
    out: Path,
    image: str,
    emulator_image: str,
    platforms: Sequence[str],
) -> None:
    """Resolve the distribution's dependency closure once per architecture.

    The application wheel is architecture-independent; its closure is not, so the
    resolution runs under each architecture rather than being copied between them.
    The installed tree is flattened so one directory carries the application and the
    closure it imports — the layout `/pgadmin4` has in the image.
    """
    python = step["source"]
    docker = require_executable("docker")
    native = os.uname().machine.replace("x86_64", "amd64").replace("aarch64", "arm64")
    requirement = f'{python["distribution"]}=={python["distributionVersion"]}'
    for arch in platforms:
        target = out / arch / step["name"]
        if target.exists():
            shutil.rmtree(target)
        script = "\n".join([
            "set -eu",
            'observed="$(python3 -c \'import sys; print("%d.%d" % sys.version_info[:2])\')"',
            f'test "${{observed}}" = "{python["interpreterVersion"]}" '
            f'|| {{ echo "interpreter-mismatch:${{observed}}"; exit 1; }}',
            f'T=/out/{arch}/{step["name"]}',
            # The image carries the Python sources.  Precompiling more than eleven
            # thousand cache files under a foreign-architecture emulator adds no
            # runtime capability and makes a clean validation spend minutes on
            # disposable bytecode.
            f'pip install --quiet --no-compile --target "$T" {requirement} >/dev/null',
            # pgAdmin's application modules must sit at /pgadmin4 for the authored
            # probe and entrypoint, while its dependencies remain importable beside
            # them.  Flatten only the pgadmin4 distribution package.  Flattening
            # every dependency would copy vendored enum.py, typing.py, ast.py, and
            # similar names over Python's standard-library imports.
            f'cp -a "$T/{python["distribution"]}/." "$T"/',
            f'rm -rf "$T/{python["distribution"]}"',
            'test -f "$T/config.py"',
            'echo INSTALLED',
        ])
        home = work / f"home-python-{arch}"
        home.mkdir(parents=True, exist_ok=True)
        command = [
            docker, "run", "--rm", "--platform", f"linux/{arch}",
            "--user", f"{os.getuid()}:{os.getgid()}",
            "-e", f"HOME=/work/home-python-{arch}",
            "-v", f"{work}:/work", "-v", f"{out}:/out",
        ]
        if arch == native:
            command += [image, "/usr/bin/bash", "-eu", "-c", script]
        else:
            emulator = extract_emulator(work, emulator_image, arch, native)
            emulator_in_container = f"/usr/bin/qemu-{QEMU_ARCH[arch]}"
            command += [
                "-v", f"{emulator}:{emulator_in_container}:ro",
                "--entrypoint", emulator_in_container,
                image, "/usr/bin/bash", "-eu", "-c", script,
            ]
        run(command, timeout=7200)
        print(f"  ok    {step['name']:<32} {requirement} on linux/{arch}")
        if arch != platforms[-1]:
            # The deliberately selected classic image store gives the final-image
            # probe a config-digest ImageInspect.Id, but it cannot retain two
            # platform variants beneath one manifest-list digest.  This source
            # image has finished producing the current platform's copied tree, so
            # discard only its exact immutable reference before pulling the next
            # platform.  No product or cache beneath .build is removed.
            run((docker, "image", "rm", "--force", image), timeout=600)


def extract_emulator(work: Path, image: str, arch: str, native: str) -> Path:
    """Extract BuildKit's static emulator without registering host-global binfmt state."""
    if not image:
        raise BuildFailure(f"amoebius-{arch}-needs-an-emulator-image")
    docker = require_executable("docker")
    target = work / "emulators" / f"qemu-{QEMU_ARCH[arch]}"
    if target.is_file():
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    run((docker, "pull", image), timeout=1800)
    created = run((docker, "create", image), timeout=300)
    container = created.strip().splitlines()[-1] if created.strip() else ""
    if not re.fullmatch(r"[0-9a-f]{64}", container):
        raise BuildFailure(f"emulator-container-id-invalid:{arch}:{container}")
    try:
        run(
            (
                docker, "cp",
                f"{container}:/usr/bin/buildkit-qemu-{QEMU_ARCH[arch]}",
                str(target),
            ),
            timeout=1800,
        )
    finally:
        run((docker, "rm", "--force", container), timeout=300)
    target.chmod(0o755)
    observed = elf_machine(target)
    if observed != EXPECTED_MACHINE[native]:
        raise BuildFailure(
            f"emulator-wrong-host-arch:{arch}:expected-{EXPECTED_MACHINE[native]}:got-{observed}"
        )
    return target


def build_amoebius(
    step: dict[str, Any],
    work: Path,
    out: Path,
    image: str,
    emulator_image: str,
    platforms: Sequence[str],
) -> None:
    """The one product amoebius builds from its own source.

    The host architecture builds with the resolved compiler directly. The other
    architecture builds inside a matching-architecture image, because GHC does not
    cross-compile this project's dependency closure.
    """
    native = os.uname().machine.replace("x86_64", "amd64").replace("aarch64", "arm64")
    resolved = toolchain.resolve(["cabal", "ghc"])
    target = step["source"]["cabalTarget"]
    for arch in platforms:
        destination = out / arch / step["name"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        if arch == native:
            # Keep compiler and store output under the closed build root. The
            # source-repository-package helper resolves its authored patch from
            # its own repository location, independent of Cabal's build depth.
            builddir = ROOT / ".build/dist-newstyle" / f"base-image-registry-products-{arch}"
            common = (
                resolved["cabal"]["path"],
                f"--builddir={builddir}",
                f"--store-dir={ROOT / '.build/cabal-store'}",
                "--jobs=1",
                f"--with-compiler={resolved['ghc']['path']}",
            )
            run((*common, "build", target), timeout=14400)
            built = run((*common, "list-bin", target), timeout=600).strip()
            shutil.copy2(built, destination)
        else:
            if not image:
                raise BuildFailure(
                    f"amoebius-{arch}-needs-a-builder-image: GHC does not cross-compile this closure"
                )
            emulator = extract_emulator(work, emulator_image, arch, native)
            # The source is copied rather than mounted, and built at the default
            # `dist-newstyle`. The copied repository carries the path-independent
            # patch helper; a writable mount of the authored worktree would put a
            # foreign architecture's build products under an authored root.
            docker = require_executable("docker")
            tree = work / f"repo-{arch}"
            tree.mkdir(parents=True, exist_ok=True)
            # A caller may deliberately supply a prior run's generated work root as
            # a warm cache.  Refresh every authored input on every invocation while
            # retaining only excluded compiler output; otherwise a cached checkout
            # could silently compile yesterday's source and still satisfy the ELF
            # probes below.
            run((require_executable("rsync"), "-a", "--delete",
                 "--exclude=/.build/", "--exclude=/.data/", "--exclude=/.test_data/",
                 "--exclude=dist-newstyle", "--exclude=.git", "--exclude=gen",
                 "--exclude=node_modules", "--exclude=dist-amoebius-*",
                 f"{ROOT}/", f"{tree}/"), timeout=3600)
            script = "\n".join([
                "set -eu",
                "cd /work/repo",
                "export PATH=/work/repo/tools:$PATH",
                "cabal update >/dev/null 2>&1 || true",
                # Bounded parallelism: every compile in here is emulated, and one
                # GHC per core would put the host's memory, not the emulator, on
                # the critical path.
                (
                    f"cabal --store-dir=/work/store-{arch} build -j2 "
                    "--disable-optimization --disable-shared --enable-static "
                    "--disable-executable-dynamic --disable-library-for-ghci "
                    f"{target}"
                ),
                f'cp "$(cabal --store-dir=/work/store-{arch} list-bin {target})" /out/{arch}/{step["name"]}',
            ])
            emulator_in_container = f"/usr/bin/qemu-{QEMU_ARCH[arch]}"
            home = work / f"home-{arch}"
            home.mkdir(parents=True, exist_ok=True)
            run((docker, "run", "--rm", "--platform", f"linux/{arch}",
                 "--user", f"{os.getuid()}:{os.getgid()}", "-e", f"HOME=/work/home-{arch}",
                 "-v", f"{tree}:/work/repo", "-v", f"{work}:/work", "-v", f"{out}:/out",
                 "-v", f"{emulator}:{emulator_in_container}:ro",
                 "--entrypoint", emulator_in_container,
                 image, "/usr/bin/bash", "-eu", "-c", script), timeout=86400)
        print(f"  ok    {step['name']:<32} {target} on linux/{arch}")


def verify(steps: Sequence[dict[str, Any]], out: Path, platforms: Sequence[str]) -> None:
    for step in steps:
        for arch in platforms:
            produced = out / arch / step["name"]
            if not produced.exists():
                raise BuildFailure(f"missing-product:{arch}:{step['name']}")
            if step["kind"] != "Elf":
                continue
            observed = elf_machine(produced)
            if observed != EXPECTED_MACHINE[arch]:
                raise BuildFailure(
                    f"product-wrong-arch:{arch}:{step['name']}:"
                    f"expected-{EXPECTED_MACHINE[arch]}:got-{observed}"
                )
    print(f"  ok    {len(steps)} product(s) present for {', '.join(platforms)}, each of its own architecture")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", type=Path, required=True, help="the build context to write out/ into")
    parser.add_argument("--work", type=Path, required=True, help="checkout and build-cache root (generated output)")
    parser.add_argument("--go-image", required=True, help="the resolved Go builder image reference")
    parser.add_argument("--python-image", required=True, help="the resolved Python builder image reference")
    parser.add_argument("--haskell-image", default="", help="the resolved non-native GHC builder image reference")
    parser.add_argument(
        "--emulator-image",
        default="",
        help="the resolved BuildKit image carrying static non-native emulators",
    )
    parser.add_argument("--platform", action="append", choices=PLATFORMS)
    parser.add_argument(
        "--only", action="append",
        help="build just this product; repeatable. The verification pass still covers every product,\nso a partial run cannot report a complete set.",
    )
    arguments = parser.parse_args(argv)
    platforms = tuple(arguments.platform or PLATFORMS)
    out = (arguments.context / "out").resolve()
    for arch in platforms:
        (out / arch).mkdir(parents=True, exist_ok=True)
    arguments.work.mkdir(parents=True, exist_ok=True)
    try:
        steps = build_products(decode_catalog())
        selected = [step for step in steps if not arguments.only or step["name"] in arguments.only]
        unknown = sorted(set(arguments.only or []) - {step["name"] for step in steps})
        if unknown:
            raise BuildFailure(f"no-such-build-product:{','.join(unknown)}")
        print(f"build products — {len(selected)}/{len(steps)} rung-3 step(s) for {', '.join(platforms)}\n")
        for step in selected:
            source = step["source"]
            if "repository" in source:
                build_go(step, arguments.work, out, arguments.go_image, platforms)
            elif "distribution" in source:
                build_python(
                    step,
                    arguments.work,
                    out,
                    arguments.python_image,
                    arguments.emulator_image,
                    platforms,
                )
            elif "cabalTarget" in source:
                build_amoebius(
                    step,
                    arguments.work,
                    out,
                    arguments.haskell_image,
                    arguments.emulator_image,
                    platforms,
                )
            else:
                raise BuildFailure(f"unclassifiable-build-source:{step['name']}")
        # Every product, not just the selected ones: a partial run that reported a
        # complete set is how a missing binary reaches the image build.
        verify(steps, out, platforms)
        print(f"\nphase25-build-products: PASS ({len(steps)} product(s) x {len(platforms)} architecture(s))")
        return 0
    except (BuildFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase25-build-products: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
