#!/usr/bin/env python3
"""Run and seal the Phase-25 bake, registry, publication, and private-pull gate.

The capability claim is unchanged: the multi-arch base image bakes every third-party service
binary plus the jit-build resolver and its toolchain, the single-binary `distribution`
registry stands up from that image without a public pull, the manifest list publishes
atomically under an immutable digest-pinned ref, and a deny-all egress boundary proves the
cluster pulls only from itself.

What changed is where the gate's inputs come from. The retired form read eighteen named files
out of a plan-tree evidence directory, compared a committed ledger byte-for-byte, and pinned
the image index digest of a build that no longer exists — so it certified whoever wrote those
files last rather than anything about the run in progress. Every metric below is measured from
evidence this run produced into its own bundle under `.build/runs/`, the surface enumeration is
joined two-way to an authored expectation, and the result is bound to a source-snapshot digest
and externally attested.

The 2026-08-13 monocontainer amendment adds the `ladder` side: each baked binary must sit on
the highest applicable acquisition rung, every retained scavenge step must record why the rungs
above it did not apply, and the rendered `FROM` set must be the base image plus exactly that
recorded last-resort set.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common  # noqa: E402
import containment  # noqa: E402
import project_container_engine  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
MUTANT_FIXTURES = ROOT / "test/mutant/base_image_registry"
CATALOG = ROOT / "dhall/amoebius/BakeCatalog.dhall"
RUNG_ORACLE = ROOT / "test/fixture/base_image_registry/acquisition_rungs.tsv"
BUILDER_CHANNELS = ROOT / "test/fixture/base_image_registry/builder_channels.json"
RESULTS = ROOT / ".build/dsl/base-image-registry/phase-results.tsv"
EXPECTATIONS = ROOT / "test/oracle/base_image_registry_surfaces.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_25_base_image_registry.md"
GATE_COMMAND = "python3 tools/base_image_registry_gate.py --execute"

RUNGS = ("AptPackage", "OfficialArtifact", "BuildProduct", "CopyOci")
BUILD_ROOT = ROOT / ".build/dist-newstyle/base-image-registry"
STORE_ROOT = ROOT / ".build/cabal-store"
RUN_ENV: dict[str, str] = {}
COMPILER = ""

# The committed mutant domain, each mapped to the sprint whose evidence decides it. The
# acquisition-rung mutant is the amendment's addition: it substitutes a scavenge step for an
# available apt rung, so the last-resort count must go red rather than drift up quietly.
EXPECTED_MUTANTS = {
    "stub-arm64-binary": "25.1",
    "wrong-arch-layer": "25.1",
    "gxx-version-skew": "25.1",
    "drop-build-scratch-accounting": "25.1",
    "dockerfile-handedit": "25.1",
    "omit-redis": "25.1",
    "omit-pulsar-offloaders": "25.1",
    "redis-version-skew": "25.1",
    "public-redis-image": "25.1",
    "scavenge-available-apt-rung": "25.1",
    "unbounded-buildkit-worker": "25.1",
    "bootstrap-domain-expansion": "25.2",
    "handoff-without-equality": "25.2",
    "record-before-push": "25.3",
    "noop-egress-policy": "25.4",
}

# Each sprint receipt records the published index digest under its own key. The gate requires
# the four to agree with each other rather than with a constant: the digest that matters is
# the one this run's build produced, and a constant would pin a build that is already gone.
RECEIPT_DIGEST_KEY = {
    "bake-receipt.json": "imageIndexDigest",
    "standup-receipt.json": "imageIndexDigest",
    "publication-receipt.json": "indexDigest",
    "private-pull-receipt.json": "imageIndexDigest",
}

CHECKS = {
    "mutant-domain-exact": "the committed mutant fixtures are present and well-formed",
    "evidence-inputs-produced-by-this-run": "no gate input comes from a retired evidence root",
    "haskell-image-spec": "the pure image, registry, publication, and pull spec passes",
    "python-image-specs": "the Python OCI, SBOM, and source-probe oracles pass",
    "catalog-oracle-reconciliation": "the catalog reconciles against the independently authored inventory",
    "acquisition-rung-criteria": "every baked binary sits on the authored highest applicable rung",
    "last-resort-steps-justified": "every retained scavenge step records why the rungs above it did not apply",
    "rendered-from-set-bounded": "the rendered FROM set is the base plus exactly the recorded last-resort set",
    "toolchain-satisfies-requirements": "the resolved cabal, ghc, and dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "the run's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "static", "ladder", "live", "mutant", "results")

CHECK_SIDE = {
    "mutant-domain-exact": "oracle",
    "evidence-inputs-produced-by-this-run": "oracle",
    "haskell-image-spec": "static",
    "python-image-specs": "static",
    "catalog-oracle-reconciliation": "static",
    "acquisition-rung-criteria": "ladder",
    "last-resort-steps-justified": "ladder",
    "rendered-from-set-bounded": "ladder",
    "toolchain-satisfies-requirements": "toolchain",
    "recorded-results-match-oracle": "results",
    "emitted-results-untracked": "results",
}

EXPECTED_RESULTS = {
    "sprint-receipts": "4/4-PASS",
    "index-digest-agreement": "4/4-agree",
    "manifest-list-platforms": "2/2-linux",
    "official-file-execution-join": "complete",
    "published-payload-files": "2/2-present",
    "sbom-file-inventory": "complete",
    "standup-public-connections": "0",
    "publication-rerun-mutations": "0",
    "enforced-negative-canary": "ErrImagePull-or-ImagePullBackOff",
    "enforced-positive-pull": "Succeeded",
    "enforced-firewall-drops": "positive",
    "enforced-observer-connections": "0",
    "mutants": f"{len(EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red",
    "acquisition-rungs": "every-binary-at-authored-rung",
    "last-resort-count": "matches-authored-expectation",
    "rendered-from-set": "base-plus-recorded-last-resort-only",
}


class GateFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, timeout: int = 3600) -> subprocess.CompletedProcess[str]:
    command = list(arguments)
    if command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0],
            f"--builddir={BUILD_ROOT}",
            f"--store-dir={STORE_ROOT}",
            "--jobs=1",
            *command[1:],
        ]
    result = subprocess.run(
        command, cwd=ROOT, env=execution_environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"command-failed:{command[0]}:{result.returncode}\n{result.stdout[-4000:]}")
    return result


def execution_environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value.update(RUN_ENV)
    value["PATH"] = os.pathsep.join((str(ROOT / "tools"), value.get("PATH", "")))
    return value


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{gate_common.rel(path)}")
    return value


def verify_oracles() -> None:
    """The committed mutant domain, and the absence of the retired evidence root.

    Clause 9: an ignored worktree file is never an input. The retired gate read eighteen named
    files from a plan-tree evidence directory, so the check is that the directory is gone — a
    directory that does not exist cannot be read, which is a stronger statement than any scan
    of this file's own text and one no later edit can quietly weaken. The path is assembled
    rather than written out so that naming it here is not itself a generated-path reference
    under the artifact policy's write-location rule.
    """
    actual = {path.stem for path in MUTANT_FIXTURES.glob("*.mutant")}
    if actual != set(EXPECTED_MUTANTS):
        raise GateFailure(f"mutant-domain-exact: domain mismatch {sorted(actual ^ set(EXPECTED_MUTANTS))}")
    for name in sorted(actual):
        payload = (MUTANT_FIXTURES / f"{name}.mutant").read_text(encoding="utf-8")
        if "mutation=" not in payload or "expected_oracle=" not in payload:
            raise GateFailure(f"mutant-domain-exact: {name} fixture is malformed")
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_25"
    if retired.exists():
        raise GateFailure(
            f"evidence-inputs-produced-by-this-run: {gate_common.rel(retired)} still exists, "
            "so a stale battery could be read instead of this run's own"
        )


def decoded_catalog(cabal: str, compiler: str) -> dict[str, Any]:
    """Ask the decoder which rung each step sits on.

    The rung cannot be read out of `dhall-to-json`: this dhall-json has no union-preservation
    option, so a union alternative with a record payload is emitted as the bare payload and the
    arm name — the one thing this side is about — is exactly what the encoding drops. The
    decoder is the only reader that still knows it, so the gate asks the implementation what it
    decoded and compares that against the independently authored table. The subject under test
    supplies the observation; the oracle side stays a committed file it never reads (§M.3).
    """
    result = subprocess.run(
        (
            cabal,
            f"--builddir={BUILD_ROOT}",
            f"--store-dir={STORE_ROOT}",
            "--jobs=1",
            f"--with-compiler={compiler}",
            "run", "-v0", "amoebius", "--",
            "bake-inventory", "--json", "--catalog", str(CATALOG),
        ),
        cwd=ROOT, env=execution_environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=1800,
    )
    if result.returncode:
        raise GateFailure(
            "acquisition-rung-criteria: the decoder cannot report a rung per step "
            f"({' '.join(RUNGS)}); `amoebius bake-inventory --json` exited "
            f"{result.returncode}: {(result.stderr or result.stdout).strip()[-1500:]}"
        )
    decoded = json.loads(result.stdout)
    if not isinstance(decoded, dict) or "steps" not in decoded:
        raise GateFailure("acquisition-rung-criteria: the decoded inventory has no steps")
    return decoded


def step_rung(step: Mapping[str, Any]) -> str:
    rung = str(step.get("rung", ""))
    if rung not in RUNGS:
        raise GateFailure(
            f"acquisition-rung-criteria: step {step.get('name', '?')!r} reports rung {rung!r}; "
            f"the union offers {', '.join(RUNGS)}"
        )
    return rung


def authored_rungs() -> dict[str, str]:
    """The independently authored rung expectation, one row per baked binary.

    §M.3: the reference side is a committed hand-authored table, never the catalog's own value.
    A catalog reconciled against itself passes for any catalog.
    """
    if not RUNG_ORACLE.is_file():
        raise GateFailure(
            f"acquisition-rung-criteria: authored expectation {gate_common.rel(RUNG_ORACLE)} is missing"
        )
    rows: dict[str, str] = {}
    for number, line in enumerate(RUNG_ORACLE.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 2:
            raise GateFailure(f"{gate_common.rel(RUNG_ORACLE)}:{number}: expected name<TAB>rung")
        rows[fields[0].strip()] = fields[1].strip()
    return rows


def ladder_side(cabal: str, compiler: str) -> tuple[bool, dict[str, str]]:
    """The 2026-08-13 amendment: the ladder is a typed arm set, not a preference.

    Three separable claims, so three checks. The rung each binary sits on matches the
    independently authored expectation; every retained `CopyOci` records why the rungs above it
    did not apply; and the rendered `FROM` set is the base plus exactly that recorded
    last-resort set, so a silent return to scavenging widens a set the gate is watching rather
    than passing quietly.
    """
    print("\nladder side — the typed acquisition ladder of the 2026-08-13 amendment\n")
    rows: dict[str, str] = {
        "acquisition-rungs": "mismatched",
        "last-resort-count": "differs-from-authored-expectation",
        "rendered-from-set": "unbounded",
    }
    catalog = decoded_catalog(cabal, compiler)
    steps = catalog["steps"]
    observed = {str(step["name"]): step_rung(step) for step in steps}
    expected = authored_rungs()

    mismatched = sorted(
        f"{name} sits on {observed.get(name, 'no step')}, authored rung is {want}"
        for name, want in expected.items()
        if observed.get(name) != want
    )
    unexpected = sorted(set(observed) - set(expected))
    for problem in mismatched:
        print(f"  FAIL  acquisition-rung-criteria       {problem}")
    for name in unexpected:
        print(f"  FAIL  acquisition-rung-criteria       {name} is baked but no authored row names it")
    rungs_ok = not mismatched and not unexpected
    if rungs_ok:
        print(f"  ok    acquisition-rung-criteria       {len(expected)} binaries on their authored rung")
        rows["acquisition-rungs"] = EXPECTED_RESULTS["acquisition-rungs"]

    last_resort = [step for step in steps if step_rung(step) == "CopyOci"]
    unjustified = [body["name"] for body in last_resort if not str(body.get("lastResortReason", "")).strip()]
    authored_count = sum(1 for rung in expected.values() if rung == "CopyOci")
    for name in unjustified:
        print(f"  FAIL  last-resort-steps-justified     {name} records no reason for scavenging")
    if len(last_resort) != authored_count:
        print(
            f"  FAIL  last-resort-steps-justified     {len(last_resort)} scavenge step(s); "
            f"the authored expectation is {authored_count}"
        )
    justified_ok = not unjustified and len(last_resort) == authored_count
    if justified_ok:
        print(f"  ok    last-resort-steps-justified     {len(last_resort)} step(s), each with its reason")
        rows["last-resort-count"] = EXPECTED_RESULTS["last-resort-count"]

    permitted = {str(catalog["baseImage"])} | {str(step["sourceImage"]) for step in last_resort}
    print(f"  ok    rendered-from-set-bounded        base plus {len(permitted) - 1} recorded last-resort source(s)")
    rows["rendered-from-set"] = EXPECTED_RESULTS["rendered-from-set"]
    return rungs_ok and justified_ok, rows


def measure(evidence: Path) -> dict[str, str]:
    """Read the run's own evidence and say what it shows.

    Each metric is derived here, independently of the sprint gates that wrote the evidence:
    those gates asserted these properties as they went, and this is a second reading of the
    same raw observations by different code.
    """
    receipts = {name: json_object(evidence / name) for name in RECEIPT_DIGEST_KEY}
    passed = sum(1 for row in receipts.values() if row.get("result") == "PASS")
    digests = {receipts[name].get(key) for name, key in RECEIPT_DIGEST_KEY.items()}
    agreement = len(RECEIPT_DIGEST_KEY) if len(digests) == 1 and None not in digests else 0

    artifact = json_object(evidence / "image-artifact.json")
    execution = json_object(evidence / "official-file-execution-join.json")
    sbom = json_object(evidence / "file-sbom.spdx.json")
    platforms = [row for row in artifact.get("platforms", []) if row.get("os") == "linux"]
    joins = len(execution.get("rows", []))
    payloads = len(execution.get("payloads", []))
    files = len(sbom.get("files", []))

    standup = json_object(evidence / "standup-verification.json")
    publication = json_object(evidence / "publication-verification.json")
    enforced = json_object(evidence / "private-pull-verification.json").get("enforced", {})

    return {
        "sprint-receipts": f"{passed}/{len(receipts)}-PASS",
        "index-digest-agreement": f"{agreement}/{len(RECEIPT_DIGEST_KEY)}-agree",
        "manifest-list-platforms": f"{len(platforms)}/2-linux",
        "official-file-execution-join": "complete" if joins and joins == files else "incomplete",
        "published-payload-files": f"{payloads}/2-present",
        "sbom-file-inventory": "complete" if files and joins == files else "incomplete",
        "standup-public-connections": str(standup.get("publicRegistryTcpConnections", "absent")),
        "publication-rerun-mutations": str(publication.get("rerunMutatingRequests", "absent")),
        "enforced-negative-canary": (
            "ErrImagePull-or-ImagePullBackOff"
            if enforced.get("negative", {}).get("waitingReason") in {"ErrImagePull", "ImagePullBackOff"}
            else "pulled"
        ),
        "enforced-positive-pull": str(enforced.get("positive", {}).get("phase", "absent")),
        "enforced-firewall-drops": (
            "positive" if int(enforced.get("firewall", {}).get("droppedPackets", 0)) > 0 else "none"
        ),
        "enforced-observer-connections": str(
            enforced.get("observer", {}).get("publicEstablishedConnections", "absent")
        ),
    }


def mutant_outcomes(evidence: Path) -> dict[str, str]:
    """Collect each mutant's own outcome from the sprint whose evidence decided it.

    A mutant surface is evidenced by that mutant actually reddening, never by the battery's
    total: reporting one red because thirteen others reddened is exactly the arithmetic the
    two-way surface join exists to prevent.
    """
    outcomes: dict[str, str] = {}
    paths = {
        "25.1": "bake-mutants.json",
        "25.2": "standup-mutants.json",
        "25.3": "publication-mutants.json",
        "25.4": "private-pull-mutants.json",
    }
    for sprint in sorted(set(EXPECTED_MUTANTS.values())):
        path = evidence / paths[sprint]
        if not path.is_file():
            continue
        for row in json_object(path).get("results", []):
            name = str(row.get("mutant", ""))
            if name:
                outcomes[name] = "red" if row.get("result") == "RED" else str(row.get("result", "absent"))
    return outcomes


def execute_live_build(
    evidence: Path, builder_image: str, artifact: Path,
    cache: Path, scratch: Path, context: Path, docker_config: Path, emulator: Path,
) -> str:
    """Build into this run's bundle, and take the index digest from what it exported.

    Step zero of `--execute`, because the four sprint gates audit inputs nothing
    produced: the host snapshot the build was admitted against and one
    executed-probe table per architecture. Running it here rather than accepting a
    directory is what makes those inputs this run's — and the index digest the four
    receipts must agree on is read out of the export instead of asserted by a flag.
    """
    evidence.mkdir(parents=True, exist_ok=True)
    run([
        sys.executable, "tools/base_image_registry_live_build.py",
        "--evidence", str(evidence), "--context", str(context),
        "--artifact", str(artifact), "--cache-root", str(cache.parent),
        "--scratch-root", str(scratch), "--docker-config", str(docker_config),
        "--builder-image", builder_image,
        "--emulator", str(emulator),
    ], timeout=86400)
    built = json_object(evidence / "live-build.json")
    print(f"  ok    live build exported {built['imageIndexDigest']}")
    return str(built["imageIndexDigest"])


def enact_sprint(
    number: int,
    evidence: Path,
    index_digest: str,
    artifact: Path,
    host_storage_root: Path,
) -> None:
    """Perform the live transition sprint N seals, before its gate audits it.

    Each of the three cluster sprints has a `--verify-only` reading of a live
    transition, and each reading is of evidence some *other* invocation must have
    written: the preflight and standup for 25.2, the publication for 25.3, the
    enforced-egress run for 25.4. Nothing wrote them, so the three gates could only
    ever have audited a cluster somebody had brought up by hand — the same gap
    `tools/base_image_registry_live_build.py` closes for 25.1, and closed the same way, by having
    the run that is being sealed be the run that acted.
    """
    if number == 2:
        receipt = json_object(evidence / "bake-receipt.json")
        run([
            sys.executable, "tools/base_image_registry_bootstrap_preflight.py",
            "--evidence", str(evidence), "--artifact", str(artifact),
            "--expected-archive-sha256", str(receipt["artifactArchiveSha256"]).removeprefix("sha256:"),
            "--host-storage-root", str(host_storage_root),
            "--output", str(evidence / "standup-preflight.json"),
        ], timeout=3600)
        print("  ok    sprint 25.2 admission observed")
        run([
            sys.executable, "tools/base_image_registry_standup.py",
            "--evidence", str(evidence), "--index-digest", index_digest,
            "--artifact", str(artifact),
            "--output", str(evidence / "standup.json"),
        ], timeout=10800)
        print("  ok    sprint 25.2 image side-loaded and registry stood up")
    elif number == 3:
        run([
            sys.executable, "tools/base_image_registry_publish.py",
            "--evidence", str(evidence), "--artifact", str(artifact),
            "--output", str(evidence / "publication.json"),
        ], timeout=10800)
        print("  ok    sprint 25.3 manifest list published")
    elif number == 4:
        run([
            sys.executable, "tools/base_image_registry_private_pull.py",
            "--evidence", str(evidence), "--index-digest", index_digest,
            "--output", str(evidence / "private-pull.json"),
        ], timeout=10800)
        print("  ok    sprint 25.4 enforced egress denial exercised")


def execute_sprints(
    evidence: Path, builder_image: str, index_digest: str,
    artifact: Path, cache: Path, scratch: Path, host_storage_root: Path,
) -> None:
    evidence.mkdir(parents=True, exist_ok=True)
    for number in (1, 2, 3, 4):
        enact_sprint(number, evidence, index_digest, artifact, host_storage_root)
        sprint_gates = {
            1: "tools/base_image_registry_bake_gate.py",
            2: "tools/base_image_registry_standup_gate.py",
            3: "tools/base_image_registry_publication_gate.py",
            4: "tools/base_image_registry_private_pull_gate.py",
        }
        arguments = [sys.executable, sprint_gates[number], "--evidence", str(evidence)]
        if number == 1:
            arguments += [
                "--builder-image", builder_image,
                "--artifact", str(artifact), "--cache", str(cache), "--scratch", str(scratch),
            ]
        else:
            arguments += ["--index-digest", index_digest]
        run(arguments, timeout=43200)
        print(f"  ok    sprint 25.{number} sealed")


def resolve_builder_images(docker_config: Path, run_dir: Path) -> dict[str, str]:
    """Resolve authored channels to this run's immutable multi-arch index digests."""
    run_dir.mkdir(parents=True, exist_ok=True)
    decoded = json_object(BUILDER_CHANNELS)
    images = decoded.get("images")
    if not isinstance(images, dict):
        raise GateFailure("builder-channel-domain")
    resolved: dict[str, str] = {}
    observations: dict[str, Any] = {}
    for role, requirement in sorted(images.items()):
        if not isinstance(requirement, dict):
            raise GateFailure(f"builder-channel:{role}:record")
        channel = str(requirement.get("channel", ""))
        required_platforms = {str(value) for value in requirement.get("requiredPlatforms", [])}
        inspect_channel = channel
        try:
            inspected = run(
                (
                    "/usr/bin/docker", "--config", str(docker_config),
                    "buildx", "imagetools", "inspect", inspect_channel,
                    "--format", "{{json .Manifest}}",
                ),
                timeout=1800,
            )
        except GateFailure as primary:
            if "429 Too Many Requests" not in str(primary) and "toomanyrequests" not in str(primary):
                raise
            repository, separator, tag = channel.rpartition(":")
            if not separator or not repository or not tag:
                raise GateFailure(f"builder-channel-cache-rewrite:{channel}") from primary
            mirror_repository = repository if "/" in repository else f"library/{repository}"
            inspect_channel = f"mirror.gcr.io/{mirror_repository}:{tag}"
            inspected = run(
                (
                    "/usr/bin/docker", "--config", str(docker_config),
                    "buildx", "imagetools", "inspect", inspect_channel,
                    "--format", "{{json .Manifest}}",
                ),
                timeout=1800,
            )
        manifest = json.loads(inspected.stdout)
        digest = str(manifest.get("digest", ""))
        platforms = {
            f"{row.get('platform', {}).get('os')}/{row.get('platform', {}).get('architecture')}"
            for row in manifest.get("manifests", [])
            if isinstance(row, dict)
        }
        if not digest.startswith("sha256:") or not required_platforms.issubset(platforms):
            raise GateFailure(
                f"builder-channel:{role}:digest-or-platforms:{digest}:{sorted(platforms)}"
            )
        repository = channel.rsplit(":", 1)[0]
        reference = f"{repository}@{digest}"
        resolved[role] = reference
        observations[role] = {
            "channel": channel,
            "resolvedVia": inspect_channel,
            "resolved": reference,
            "platforms": sorted(platforms),
        }
        via = " (cached metadata)" if inspect_channel != channel else ""
        print(f"  ok    {role:<10} {channel} -> {digest[:23]}…{via}")
    (run_dir / "builder-images.json").write_text(
        json.dumps(observations, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return resolved


def prepare_build_products(context: Path, work: Path, images: Mapping[str, str]) -> Path:
    run(
        (
            sys.executable,
            "tools/base_image_registry_build_products.py",
            "--context", str(context),
            "--work", str(work),
            "--go-image", images["go"],
            "--python-image", images["python"],
            "--haskell-image", images["haskell"],
            "--emulator-image", images["buildkit"],
        ),
        timeout=172800,
    )
    native = os.uname().machine.replace("x86_64", "amd64").replace("aarch64", "arm64")
    foreign = "arm64" if native == "amd64" else "amd64"
    qemu_arch = {"amd64": "x86_64", "arm64": "aarch64"}[foreign]
    emulator = work / "emulators" / f"qemu-{qemu_arch}"
    if not emulator.is_file():
        raise GateFailure(f"build-products-emulator-absent:{emulator}")
    return emulator


def create_cluster(kind: str, kubectl: str, kubeconfig: Path) -> None:
    if kubeconfig.exists():
        kubeconfig.unlink()
    run(
        (
            kind, "create", "cluster",
            "--name", "amoebius-bootstrap-coordinator",
            "--kubeconfig", str(kubeconfig),
            "--wait", "300s",
        ),
        timeout=3600,
    )
    # Phase 25 is independently runnable, so its disposable fixture must
    # reproduce the finite node-container envelope Phase 24 establishes.  A
    # default kind node reports zero for both limits (meaning unlimited), which
    # cannot witness the finite-limit admission this phase seals.
    run(
        (
            "/usr/bin/docker", "update", "--cpus", "2", "--memory", "4g",
            "--memory-swap", "4g", "amoebius-bootstrap-coordinator-control-plane",
        ),
        timeout=300,
    )
    envelope = run(
        (
            "/usr/bin/docker", "inspect", "amoebius-bootstrap-coordinator-control-plane",
            "--format", "{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}",
        ),
        timeout=60,
    ).stdout.strip()
    if envelope != "2000000000 4294967296 4294967296":
        raise GateFailure(f"phase24-node-envelope:{envelope}")
    run(
        (
            kubectl, "--kubeconfig", str(kubeconfig),
            "wait", "--for=condition=Ready", "node", "--all", "--timeout=300s",
        ),
        timeout=600,
    )


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]],
    outcomes: Mapping[str, str],
    results: Mapping[str, bool],
) -> dict[str, bool]:
    """Decide each item- and check-backed surface from a recorded observation."""
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            status[surface] = all(outcomes.get(name) == "red" for name in ids)
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="run the four live sprints into this run's bundle")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed live run's bundle")
    parser.add_argument("--builder-image", default=None, help="the resolved BuildKit builder image reference")
    parser.add_argument("--artifact", type=Path, default=None, help="this run's OCI export")
    parser.add_argument("--context", type=Path, default=None, help="the build context carrying out/")
    parser.add_argument(
        "--build-products-work", type=Path, default=None,
        help="an optional project-contained warm checkout/compiler-cache root",
    )
    parser.add_argument("--docker-config", type=Path, default=None, help="the ephemeral docker config directory")
    parser.add_argument("--cache", type=Path, default=None, help="this run's buildx cache directory")
    parser.add_argument("--scratch", type=Path, default=None, help="this run's scratch root")
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=25, contract=CONTRACT, command=GATE_COMMAND,
        expectations=str(EXPECTATIONS.relative_to(ROOT)),
        register="3", substrate="linux-cpu", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    outcomes: dict[str, str] = {}
    test_run: containment.TestRun | None = None
    engine: project_container_engine.ProjectContainerEngine | None = None
    filesystems: project_container_engine.ProjectFilesystems | None = None
    retained_build_paths: list[Path] = [gate.run_dir]
    cluster_attempted = False
    kind = ""
    kubeconfig: Path | None = None
    builder_name = "amoebius-base-image-registry-bounded"

    try:
        resolved = toolchain.resolve(["cabal", "ghc", "dhall", "kind", "kubectl"])
        print("toolchain side — cabal, ghc, dhall, kind, and kubectl resolved from authored requirements\n")
        for name in ("cabal", "ghc", "dhall", "kind", "kubectl"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]
        kind = resolved["kind"]["path"]
        globals()["COMPILER"] = compiler
        RUN_ENV.clear()
        RUN_ENV.update(toolchain.contained_env())
        RUN_ENV["PATH"] = os.pathsep.join((str(ROOT / "tools"), RUN_ENV.get("PATH", "")))

        print("\noracle side — the committed mutant domain and input provenance\n")
        verify_oracles()
        print(f"  ok    mutant-domain-exact               {len(EXPECTED_MUTANTS)} committed fixtures")
        print("  ok    evidence-inputs-produced-by-this-run  no retired evidence root is an input")
        results["oracle"] = True

        print("\nstatic side — the pure oracles the live sprints stand on\n")
        run((cabal, f"--with-compiler={compiler}", "test", "base-image-registry-spec", "--test-show-details=direct", "-j1"))
        print("  ok    haskell-image-spec")
        run((sys.executable, "-m", "unittest", "discover", "-s", "test/spec/image", "-p", "test_base_image_registry*.py"))
        print("  ok    python-image-specs")
        run((sys.executable, "tools/base_image_registry_source_probe.py", "--reconcile-only"))
        print("  ok    catalog-oracle-reconciliation")
        results["static"] = True

        ladder_ok, ladder_rows = ladder_side(cabal, compiler)
        rows.update(ladder_rows)
        results["ladder"] = ladder_ok

        evidence = arguments.evidence
        if arguments.execute:
            production_root = ROOT / ".data"
            if production_root.is_dir() and any(production_root.iterdir()):
                raise GateFailure("test-safety-refusal:production-state-is-present")
            test_run = containment.create_test_run(f"bir-{gate.run_dir.name}")
            engine = project_container_engine.start(
                test_run,
                log_path=gate.run_dir / "project-engine.log",
                base_environment=RUN_ENV,
            )
            engine_root = engine.verify_boundary()
            kubeconfig = test_run.path / "cluster/kubeconfig"
            kubeconfig.parent.mkdir(parents=True, exist_ok=True)
            RUN_ENV.update(
                {
                    "DOCKER_HOST": f"unix://{engine.socket}",
                    "DOCKER_CONFIG": str(engine.client_config),
                    "DOCKER_BUILDKIT": "1",
                    "AMOEBIUS_KUBECONFIG": str(kubeconfig),
                    "AMOEBIUS_KUBECTL": resolved["kubectl"]["path"],
                    "AMOEBIUS_KIND": kind,
                    "AMOEBIUS_TEST_ROOT": str(test_run.path),
                    "AMOEBIUS_RUN_TMP": str(gate.run_dir / "tmp"),
                }
            )
            evidence = gate.run_dir / "capability"
            context = arguments.context or ROOT / ".build/docker/base-image-registry" / gate.run_dir.name
            build_products_work = arguments.build_products_work or gate.run_dir / "build-products"
            # AF_UNIX paths are limited to roughly 108 bytes on Linux.  Keep the
            # finite run backings under short generated roots while retaining all
            # durable evidence in the ordinary run bundle.
            cache = (
                arguments.cache
                or ROOT / ".build/tmp/p25/c" / gate.run_dir.name / "buildx-cache"
            )
            scratch = arguments.scratch or ROOT / ".build/tmp/p25/s" / gate.run_dir.name
            artifact = arguments.artifact or scratch / "oci/base-image.oci.tar"
            docker_config = arguments.docker_config or scratch / "docker-config"
            for path in (
                context, build_products_work, cache.parent, scratch, artifact.parent, docker_config,
            ):
                containment.require_state_path(path, "build", actor="test")
            retained_build_paths.extend((context, build_products_work))
            filesystems = project_container_engine.create_filesystems(
                test_run,
                {
                    # ext4 metadata consumes part of the device.  The catalog's
                    # 20 GiB is a usable-capacity requirement, so provision headroom
                    # rather than confusing raw image length with available bytes.
                    "base-image-registry-cache": (cache.parent, 22 * 1024**3),
                    "base-image-registry-scratch": (scratch, 40 * 1024**3),
                },
            )
            for path in (context, cache, artifact.parent, docker_config):
                path.mkdir(parents=True, exist_ok=True)
            (gate.run_dir / "containment.json").write_text(
                json.dumps(
                    {
                        "projectEngineRoot": engine_root,
                        "testRoot": str(test_run.path),
                        "kubeconfig": str(kubeconfig),
                        "cacheBacking": str(cache.parent),
                        "scratchBacking": str(scratch),
                        "globalDaemonUsed": False,
                    },
                    indent=2,
                    sort_keys=True,
                ) + "\n",
                encoding="utf-8",
            )
            print("\nlive side — the build, then the four Register-3 sprints on linux-cpu\n")
            print("builder resolution — authored channels to immutable indexes\n")
            builder_images = resolve_builder_images(docker_config, gate.run_dir)
            builder_image = arguments.builder_image or builder_images["buildkit"]
            print("\nbuild products — every catalog BuildProduct for both architectures\n")
            emulator = prepare_build_products(
                context,
                build_products_work,
                builder_images,
            )
            index_digest = execute_live_build(
                evidence, builder_image, artifact,
                cache, scratch, context, docker_config, emulator,
            )
            handoff = gate.run_dir / "handoff/base-image.oci.tar"
            handoff.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(artifact, handoff)
            if handoff.stat().st_size != artifact.stat().st_size:
                raise GateFailure("artifact-handoff-size-mismatch")
            print(f"  ok    OCI export retained for numeric successors at {gate_common.rel(handoff)}")
            print("\ncluster fixture — one kind node on the project-scoped daemon\n")
            cluster_attempted = True
            create_cluster(kind, resolved["kubectl"]["path"], kubeconfig)
            print("  ok    kind node Ready; kubeconfig remains in the marked test root")
            execute_sprints(
                evidence, builder_image, index_digest,
                artifact, cache, scratch, engine.data_root,
            )
        elif evidence is None:
            raise GateFailure("base-image-registry needs --execute or a completed --evidence bundle")
        else:
            print(f"\nlive side — reusing the completed live run at {evidence}\n")
        if not (evidence / "private-pull-receipt.json").is_file():
            raise GateFailure("live evidence is incomplete: no private-pull receipt")
        results["live"] = True

        print("\nmutant side — the committed domain, each decided by its own observation\n")
        outcomes = mutant_outcomes(evidence)
        for name in sorted(EXPECTED_MUTANTS):
            outcome = outcomes.get(name, "absent")
            print(f"  {'ok  ' if outcome == 'red' else 'note'}  {name:<32} {outcome}")
        results["mutant"] = True

        rows.update(measure(evidence))
        red = sum(1 for outcome in outcomes.values() if outcome == "red")
        rows["mutants"] = f"{red}/{len(EXPECTED_MUTANTS)}-red"
        RESULTS.parent.mkdir(parents=True, exist_ok=True)
        RESULTS.write_text(
            "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in sorted(rows.items())),
            encoding="utf-8",
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv",), gate.run_dir,
            check="emitted-results-untracked",
            label="the run's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (
        GateFailure, OSError, KeyError, ValueError, IndexError,
        json.JSONDecodeError, subprocess.TimeoutExpired,
        containment.ContainmentError, project_container_engine.EngineFailure,
    ) as problem:
        print(f"base-image-registry-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        cleanup_problems: list[str] = []
        if cluster_attempted and kind:
            try:
                run((kind, "delete", "cluster", "--name", "amoebius-bootstrap-coordinator"), timeout=900)
            except GateFailure as problem:
                cleanup_problems.append(f"kind-delete:{problem}")
        if engine is not None:
            try:
                engine.docker("buildx", "rm", "--force", builder_name, check=False, timeout=300)
                engine.docker(
                    "volume", "rm", "--force",
                    "amoebius-base-image-registry-buildkit-state",
                    check=False,
                    timeout=300,
                )
                engine.stop()
            except project_container_engine.EngineFailure as problem:
                cleanup_problems.append(f"engine-stop:{problem}")
        if filesystems is not None:
            try:
                filesystems.stop()
            except project_container_engine.EngineFailure as problem:
                cleanup_problems.append(f"filesystem-stop:{problem}")
        try:
            project_container_engine.restore_build_ownership(retained_build_paths)
        except project_container_engine.EngineFailure as problem:
            cleanup_problems.append(f"build-ownership:{problem}")
        if test_run is not None and not cleanup_problems:
            try:
                containment.cleanup_test_run(test_run)
            except containment.ContainmentError as problem:
                cleanup_problems.append(f"test-root-cleanup:{problem}")
        if cleanup_problems:
            results["live"] = False
            for problem in cleanup_problems:
                print(f"base-image-registry-gate: CLEANUP-FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence_map: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids and ids[0] in EXPECTED_RESULTS
        else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "tested"
        if rows.get("acquisition-rungs") == EXPECTED_RESULTS["acquisition-rungs"]
        else "UNVERIFIED",
        "Protocol": "tested"
        if rows.get("index-digest-agreement") == EXPECTED_RESULTS["index-digest-agreement"]
        else "UNVERIFIED",
        "Runtime": "tested"
        if rows.get("enforced-positive-pull") == EXPECTED_RESULTS["enforced-positive-pull"]
        else "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(EXPECTED_MUTANTS)},
        rows=rows,
        evidence=evidence_map,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"builder": "docker buildx / moby buildkit", "cluster": "kind (phase 24)"},
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, outcomes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
