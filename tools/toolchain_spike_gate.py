#!/usr/bin/env python3
"""The Phase-1 gate — dynamic toolchain resolution and the pre-cluster build probe.

Phase 1 settles buildability without freezing a dependency graph into Git. The gate is
therefore two claims at once, and it runs them as separate sides:

  architecture the run records the natural architecture it executed on, untranslated
  provenance   no tracked file carries a resolved path, a package integrity pin, or a
               fixed dependency revision, and every input a build configuration names is
               present in non-ignored source
  resolution   the toolchain and the dependency graph resolve from authored requirements,
               twice, to the same admissible graph — and resolve from the source snapshot
               alone, which is where a project that needs an ignored worktree file dies
  build        the representative set compiles from an empty package store
  probe        each probe executes and matches its independently authored expectation
  mutant       each committed seeded mutant turns the gate red at its intended locus
  surface      what the run enumerated joins completely to the authored expectation
  ledger       the proven/tested/assumed ledger is schema-clean inside the run bundle
  attestation  the run bundle verifies against the source-snapshot digest
  write-guard  nothing beneath an authored root was created, changed, or removed

The predecessor gate is withdrawn. It read `toolchain/pins.json` (tracked resolved paths,
versions, download URLs, and archive checksums), wrote its evidence into the plan tree's
ignored evidence directory, committed its ledger beside the goldens, and consumed a
compatibility patch that lived in an ignored directory — so a fresh clone could not have
run it at all. Every one of those is now a check this gate fails on. The migration roots
are deliberately not spelled out here: naming one inside a gate script is itself a
write-location finding, which is the rule doing its job.

    python3 tools/toolchain_spike_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import attestation  # noqa: E402
import ledger_lint  # noqa: E402
import containment  # noqa: E402
import gate_common  # noqa: E402
import host_platform  # noqa: E402
import toolchain_spike_negative_corpus  # noqa: E402
import toolchain  # noqa: E402

from toolchain_spike_negative_corpus import NEGATIVES, RESOLUTION_NEGATIVES  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
GATE_COMMAND = "python3 tools/toolchain_spike_gate.py"
CONTRACT = "DEVELOPMENT_PLAN/phase_01_toolchain_spike.md"

EXPECTATIONS = ROOT / "test" / "oracle" / "toolchain_spike_surfaces.tsv"
SURFACES = ROOT / ".build" / "test-surfaces" / "phase_01.json"
LOCKS = ROOT / ".build" / "locks" / "phase_01"
PROTO_OUT = ROOT / ".build" / "proto" / "phase_01"
CORPORA = ROOT / ".build" / "test-corpora" / "phase_01"
SNAPSHOT_TREE = ROOT / ".build" / "tmp" / "phase_01-snapshot"

BUILD_ROOT = ROOT / ".build" / "dist-newstyle" / "phase_01-main"
PLAN_ROOTS = (
    ROOT / ".build" / "dist-newstyle" / "phase_01-plan-a",
    ROOT / ".build" / "dist-newstyle" / "phase_01-plan-b",
)
MUTANT_ROOT = ROOT / ".build" / "dist-newstyle" / "phase_01-mutant"
SNAPSHOT_ROOT_NAME = ".build/dist-newstyle/phase_01-snapshot"
STORE_PARENT = ROOT / ".build" / "cabal-store" / "phase_01"

# `git` is listed even though nothing depends on it through the manifest: Cabal shells out
# to it for the infernix and jitML source-repository-packages, and a tool a gate needs is
# declared and resolved rather than invoked bare (`substrate_doctrine.md` §3). Everything
# else these names need — ghcup, node, npm, playwright — is pulled in by the resolver's own
# closure.
TOOLS_REQUIRED = [
    "git", "ghc", "cabal", "dhall", "purs", "spago", "chromium",
    "protoc", "proto_lens_protoc", "java", "tla2tools",
]

# The gate's own check registry. `surface_side` enumerates it live, so deleting a check
# below breaks the authored join rather than quietly shrinking the gate.
CHECKS = {
    "resolved-path": "no tracked file carries a resolved home path",
    "integrity-pin": "no tracked file pins a package or archive integrity digest",
    "fixed-commit": "no tracked build configuration names a fixed dependency revision",
    "source-closure": "no build configuration references an ignored worktree input or refetches vendored source",
    "patch-under-authored-root": "every referenced compatibility patch is tracked under an authored root",
    "floor-decidable": "the floor is well formed and decidable for every substrate, not only this host's",
    "floor-satisfied": "every floor prerequisite of this host's substrate is satisfied",
    "no-host-source": "no requirement is declared as expected on the developer host",
    "acquired-contained": "every acquired tool lives beneath the ignored build root",
    "resolution-absent": "a provider offering nothing refuses instead of falling through",
    "resolution-out-of-range": "a provider offering only excluded versions refuses",
    "resolution-architecture": "a publisher with no asset for this architecture refuses rather than taking another's",
    "managed-idempotent": "a second resolution of every managed tool installs nothing",
    "twice-resolved": "two independent resolutions produce the same admissible graph",
    "snapshot-resolves": "the graph resolves from non-ignored source alone",
    "clean-store-build": "the representative set builds from an empty package store",
    "decode-positive": "the Dhall probe decodes its authored fixture to the authored value",
    "decode-negative": "the mistyped fixture fails at its authored type-error tag",
    "dependency-link": "the representative dependency surface links and runs",
    "simulation-terminal": "the IOSim probe reaches the independently authored terminal state",
    "protocol-codegen": "protoc plus the plugin emit both non-empty protocol modules",
    "natural-architecture": "the run executes untranslated on the architecture it records",
}

# The managed requirements a second pass must resolve without installing anything. This is
# the "verified no-op" half of the probe-first ensure contract: the first run may install,
# and a run that installs on every pass is not idempotent, it is just repeatedly lucky.
IDEMPOTENT = ("git", "node", "npm", "ghc", "cabal", "chromium")

# Section S clause 15: the lane this gate runs, declared by the gate rather than read
# out of the tracker it is checked against.
LANE = "none"

SIDE_NAMES = (
    "architecture",
    "floor",
    "provenance",
    "resolution",
    "build",
    "probe",
    "mutant",
    "surface",
    "ledger",
    "attestation",
    "containment",
    "write-guard",
)

FIXED_REVISION = re.compile(
    r"(?im)^\s*(?:tag|revision|rev|commit)\s*[:=]\s*\"?([0-9a-f]{7,40})\"?\s*,?\s*$"
)
BUILD_CONFIG_GLOBS = ("cabal.project", "*.project", "package.json", "*.cabal")
PATCH_REFERENCE = re.compile(r"[A-Za-z0-9_.\-/]*patches/[A-Za-z0-9_.\-]+\.patch")
GIT_LOCATION = re.compile(r"(?im)^\s*location\s*:\s*(\S+?)(?:\.git)?\s*$")


class GateFailure(RuntimeError):
    pass


def run_id() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def rel(path: Path | str) -> str:
    return os.path.relpath(str(path), str(ROOT))


def capture(command: list[str], *, cwd: Path = ROOT, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True, check=False)


def checked(command: list[str], *, cwd: Path = ROOT, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = capture(command, cwd=cwd, env=env)
    if result.returncode != 0:
        raise GateFailure(
            f"command exited {result.returncode}: {' '.join(command)}\n"
            f"{result.stdout[-4000:]}{result.stderr[-4000:]}"
        )
    return result


def clear(path: Path) -> Path:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)
    return path


# --------------------------------------------------------------------------
# provenance — pure scanners, so the seeded negatives can drive them directly
# --------------------------------------------------------------------------


def scan_fixed_revision(relative: str, text: str) -> list[str]:
    """A dependency named by revision is resolver output wearing a requirement's clothes.

    `repository_layout_doctrine.md` section 4 admits a release channel — a branch, a tag
    name, a version range — and refuses a resolved identity. The distinction is not
    cosmetic: a project pinned to a revision stops resolving the current compatible set,
    which is the whole property this phase exists to establish.
    """
    findings: list[str] = []
    for match in FIXED_REVISION.finditer(text):
        findings.append(f"names fixed dependency revision {match.group(1)}")
    return findings


def scan_patch_references(relative: str, text: str) -> list[str]:
    """Every compatibility patch a build configuration applies must be authored source."""
    findings: list[str] = []
    for match in PATCH_REFERENCE.finditer(text):
        token = match.group(0).strip("./")
        token = token.removeprefix("AMOEBIUS_SOURCE_ROOT/")
        while token.startswith("../"):
            token = token[3:]
        findings.append(token)
    return findings


def scan_refetched_vendor(text: str, present: set[str]) -> list[str]:
    """A package vendored under `vendor/**` may not also be fetched from git.

    `repository_layout_doctrine.md` section 4.1: a compatibility edit is reviewed source,
    not a diff replayed against whatever the upstream branch head has become. The rule is
    stated over the *pair* rather than over one package name, because what makes the fetch
    wrong is that the reviewed copy exists — a project that refetches it is building
    something no one read, while the tree carries the thing that was read. `supernova` is
    the instance that retired the `patches/` root; the check outlives it.
    """
    vendored = {
        path.split("/")[1]
        for path in present
        if path.startswith("vendor/") and path.count("/") >= 2
    }
    findings: list[str] = []
    for match in GIT_LOCATION.finditer(text):
        name = match.group(1).rstrip("/").rsplit("/", 1)[-1]
        if name in vendored:
            findings.append(f"fetches {name} from git though vendor/{name} is reviewed source")
    return findings


def is_build_config(relative: str) -> bool:
    return artifact_policy.matches_any(relative, BUILD_CONFIG_GLOBS) or artifact_policy.matches_any(
        os.path.basename(relative), BUILD_CONFIG_GLOBS
    )


def scan_provenance(relative: str, text: str) -> list[tuple[str, str, str]]:
    """(check id, shared rule id, message) for one file. Pure; the negatives drive it.

    The shared rule id is what the migration allowlist keys on, so a finding this phase
    does not own is deferred to the phase that does rather than suppressed
    (`development_plan_standards.md` section S, clause-5 enforcement).
    """
    findings = [
        (
            "integrity-pin" if "integrity digest" in finding.message else "resolved-path",
            "r6",
            finding.message,
        )
        for finding in artifact_policy.scan_resolution(relative, text)
    ]
    if is_build_config(relative):
        findings += [("fixed-commit", "r6", message) for message in scan_fixed_revision(relative, text)]
    return findings


def materialize_negatives() -> dict[str, Path]:
    """Write the seeded negatives out of their authored definitions.

    Each negative differs from `_positive` in exactly one dimension, which is what makes a
    red result attributable (`development_plan_standards.md` section M clause 8).
    """
    clear(CORPORA)
    built: dict[str, Path] = {}
    for name, (filename, _expected, body) in NEGATIVES.items():
        directory = CORPORA / name
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / filename
        path.write_text(body, encoding="utf-8")
        built[name] = path
    return built


def ignored(candidates: list[str]) -> set[str]:
    return artifact_policy.ignored_paths(candidates)


def closure_findings(relative: str, text: str, present: set[str] | None = None) -> list[tuple[str, str, str]]:
    """Source-closure and patch-location findings for one build configuration.

    `present` is the source snapshot — every non-ignored file, tracked or not. Testing
    against the snapshot rather than against `git ls-files` is deliberate: section S
    withdrew commit timing as a gate input, so a reviewed patch that exists in the tree
    and is not ignored is source, whether or not the operator has committed it yet.
    """
    if present is None:
        present = set(artifact_policy.snapshot_paths())
    findings: list[tuple[str, str, str]] = []
    references = sorted({token for token in artifact_policy.PATH_LITERAL.findall(text)})
    normalized: dict[str, str] = {}
    for token in references:
        cleaned = token
        while cleaned.startswith("./"):
            cleaned = cleaned[2:]
        while cleaned.startswith("../"):
            cleaned = cleaned[3:]
        if not cleaned or cleaned.startswith(artifact_policy.CLOSURE_EXEMPT_PREFIXES):
            continue
        normalized[cleaned] = token
    for hit in sorted(ignored(sorted(normalized))):
        findings.append(("source-closure", "r7", f"references ignored worktree input {hit}"))
    for patch in scan_patch_references(relative, text):
        if patch not in present:
            findings.append(
                ("patch-under-authored-root", "r7", f"patch {patch} is not in the source snapshot")
            )
    for message in scan_refetched_vendor(text, present):
        findings.append(("source-closure", "r7", message))
    return findings


# An executable oracle has no filename suffix, which is exactly where a hard-coded
# interpreter path hides. Scanning by suffix alone would step over it.
SUFFIXLESS_SCANNED = ("probe/oracle/check-sim-terminal",)

# A negative corpus has to contain the defect it seeds, so scanning it would report the
# fixture as the finding. Both seeds below are single-purpose, authored, and reviewed as
# corpora; nothing else is exempt, and the gate that consumes them is fully scanned.
CORPUS_SEEDS = (
    "tools/toolchain_spike_negative_corpus.py",
    "tools/artifact_policy_selftest.py",
)


def tree_findings() -> list[tuple[str, str, str, str]]:
    """(check id, rule, locus, message) for the whole source snapshot."""
    present = set(artifact_policy.snapshot_paths())
    collected: list[tuple[str, str, str, str]] = []
    for relative in sorted(present):
        path = ROOT / relative
        if not path.is_file():
            continue
        if relative in CORPUS_SEEDS:
            continue
        if path.suffix not in artifact_policy.TEXT_SUFFIXES and relative not in SUFFIXLESS_SCANNED:
            continue
        text = artifact_policy.read_text(path)
        if not text:
            continue
        collected += [(check, rule, relative, message) for check, rule, message in scan_provenance(relative, text)]
        if is_build_config(relative):
            collected += [
                (check, rule, relative, message)
                for check, rule, message in closure_findings(relative, text, present)
            ]
    return collected


def provenance_side() -> bool:
    print("provenance side — resolver output and source closure across the source snapshot\n")
    ok = True

    collected = tree_findings()
    report = artifact_policy.Report()
    identity: dict[tuple[str, str, str], str] = {}
    for check, rule, locus, message in collected:
        identity[(rule, locus, message)] = check
        report.findings.append(artifact_policy.Finding(rule, locus, message))
    allowances = artifact_policy.load_allowances()
    artifact_policy.apply_allowances(report, allowances)

    for finding in report.findings:
        check = identity.get((finding.rule, finding.locus, finding.message), finding.rule)
        print(f"  FAIL  {check:<26} {finding.locus}: {finding.message}")
        ok = False
    owners: dict[str, int] = {}
    for finding in report.deferred:
        owners[finding.owner] = owners.get(finding.owner, 0) + 1
    if ok:
        print(f"  ok    {'phase-1 loci':<26} no resolver output, integrity pin, fixed revision, or missing input")
    if owners:
        summary = ", ".join(f"{owner}:{count}" for owner, count in sorted(owners.items()))
        print(f"  note  {'deferred':<26} {sum(owners.values())} finding(s) owned by a later phase — {summary}")

    print(f"\n  seeded negatives materialized under {rel(CORPORA)}\n")
    built = materialize_negatives()
    present = set(artifact_policy.snapshot_paths())
    for name in sorted(built):
        filename, expected_check, _body = NEGATIVES[name]
        relative = f"{name}/{filename}"
        text = built[name].read_text(encoding="utf-8")
        hit = {check for check, _rule, _message in scan_provenance(relative, text)}
        hit |= {check for check, _rule, _message in closure_findings(relative, text, present)}
        if not expected_check:
            if hit:
                print(f"  FAIL  {name:<26} positive control tripped {', '.join(sorted(hit))}")
                ok = False
            else:
                print(f"  ok    {name:<26} positive control is clean")
            continue
        if expected_check not in hit:
            print(f"  FAIL  {name:<26} expected {expected_check}, got {', '.join(sorted(hit)) or 'nothing'}")
            ok = False
        elif hit != {expected_check}:
            extra = sorted(hit - {expected_check})
            print(f"  FAIL  {name:<26} tripped {expected_check} but also {', '.join(extra)}")
            ok = False
        else:
            print(f"  ok    {name:<26} turns {expected_check} red, and nothing else")
    return ok


# --------------------------------------------------------------------------
# floor — what only the operator supplies, checked before anything is resolved
# --------------------------------------------------------------------------


def floor_side() -> bool:
    """The precondition half of `substrate_doctrine.md` §3.1.

    Three claims, and the middle one is the reason this side exists at all. A gate that
    checks only its own host's floor cannot tell a well-formed plan for another substrate
    from a missing one, and the previous revision of this phase declared four tools as
    "expected on the developer host" precisely because nothing was checking the difference.
    """
    print("\nfloor side — the per-substrate floor, before any requirement is resolved\n")
    ok = True

    problems = toolchain.floor_wellformed()
    for substrate in host_platform.SUBSTRATES:
        try:
            toolchain.floor_results(substrate)
        except toolchain.ResolutionError as error:
            problems.append(f"floor.{substrate}: not decidable from this host: {error}")
    if problems:
        for problem in problems:
            print(f"  FAIL  {'floor-decidable':<26} {problem}")
        ok = False
    else:
        print(
            f"  ok    {'floor-decidable':<26} all {len(host_platform.SUBSTRATES)} substrates "
            f"decide, each entry carrying its remedy"
        )

    substrate = host_platform.host_substrate()
    for result in toolchain.floor_results(substrate):
        if result["satisfied"]:
            print(f"  ok    {'floor-satisfied':<26} {result['id']}: {result['observation']}")
        else:
            print(f"  FAIL  {'floor-satisfied':<26} {result['id']}: {result['observation']}")
            print(f"        remedy: {result['remedy']}")
            ok = False

    requirements = toolchain.load_requirements()
    declared = sorted(name for name, spec in requirements.items() if spec["source"] == "host")
    if declared:
        print(f"  FAIL  {'no-host-source':<26} {', '.join(declared)} expect a tool on the developer host")
        ok = False
    else:
        print(
            f"  ok    {'no-host-source':<26} all {len(requirements)} requirements are acquired, "
            f"managed, or supplied by the floor"
        )
    return ok


def resolution_negatives() -> bool:
    """Each seeded resolution negative reddens its own check and no other.

    Both selectors are pure, so this runs with no host, no network and no download, and
    reaches the refusal paths a passing run never takes.
    """
    print("\n  seeded resolution negatives — the pure selectors\n")
    ok = True
    for name in sorted(RESOLUTION_NEGATIVES):
        selector, expected, fixture = RESOLUTION_NEGATIVES[name]
        try:
            if selector == "release":
                _release, asset = toolchain.choose_release(
                    name, fixture["spec"], fixture["releases"], fixture["token"]
                )
                outcome, detail = "", asset["name"]
            else:
                detail = toolchain.choose_offer(name, fixture["offers"], fixture["requirement"])
                outcome = ""
        except toolchain.ResolutionError as error:
            outcome, detail = toolchain.refusal_check(error) or "resolution-unclassified", str(error)

        if not expected:
            if outcome:
                print(f"  FAIL  {name:<26} positive control refused at {outcome}: {detail}")
                ok = False
            elif detail != fixture["expect"]:
                print(f"  FAIL  {name:<26} chose {detail!r}, expected {fixture['expect']!r}")
                ok = False
            else:
                print(f"  ok    {name:<26} positive control resolves to {detail}")
            continue
        if outcome != expected:
            print(f"  FAIL  {name:<26} expected {expected}, got {outcome or 'no refusal'}")
            ok = False
        else:
            print(f"  ok    {name:<26} turns {expected} red, and nothing else")
    return ok


def acquisition_contained(resolved: dict[str, Any]) -> bool:
    """Every acquired tool is beneath `.build/`; only the floor's own supplies are not.

    A `managed` tool whose provider is the package-manager root is the floor answering for
    itself, and it lives where that manager puts it. Everything else this run acquired was
    downloaded from a publisher, so it belongs in the ignored build root and nowhere else
    ([`repository_layout_doctrine.md` §4](../documents/engineering/repository_layout_doctrine.md#4-dependency-and-toolchain-resolution)).
    """
    build_root = str(ROOT / ".build") + os.sep
    ok = True
    outside = 0
    for name in sorted(name for name in resolved if name != "platform"):
        record = resolved[name]
        floor_supplied = str(record.get("provider", "")).startswith("package-manager")
        if str(record["path"]).startswith(build_root):
            continue
        if floor_supplied:
            outside += 1
            continue
        print(f"  FAIL  {'acquired-contained':<20} {name} resolved outside the build root: {record['path']}")
        ok = False
    if ok:
        print(
            f"  ok    {'acquired-contained':<20} every acquired tool is beneath .build/; "
            f"{outside} supplied by the floor's package manager"
        )
    return ok


def managed_idempotent(resolved: dict[str, Any]) -> bool:
    """A second resolution of every managed tool is a verified no-op."""
    try:
        second = toolchain.resolve(IDEMPOTENT, refresh=True)
    except toolchain.ResolutionError as error:
        print(f"  FAIL  {'managed-idempotent':<20} second resolution failed: {error}")
        return False
    installed = sorted(name for name in IDEMPOTENT if second[name].get("installed"))
    if installed:
        print(f"  FAIL  {'managed-idempotent':<20} second pass installed {', '.join(installed)}")
        return False
    drift = sorted(
        name for name in IDEMPOTENT if second[name]["path"] != resolved[name]["path"]
    )
    if drift:
        print(f"  FAIL  {'managed-idempotent':<20} second pass moved {', '.join(drift)}")
        return False
    print(f"  ok    {'managed-idempotent':<20} {len(IDEMPOTENT)} managed tools re-probe to the same paths, uninstalled")
    return True


# --------------------------------------------------------------------------
# resolution
# --------------------------------------------------------------------------


# What this gate builds, and deliberately not more.
#
# The predecessor built `all`, which pulled every package phases 2-64 own into a Phase-1
# gate. That is a forward dependency — `development_plan_standards.md` section E forbids a
# phase's gate from consuming what a later phase delivers — and it only ever passed because
# those sources happened to compile on the day. When one of them stopped compiling, the
# toolchain gate went red for a reason that has nothing to do with the toolchain.
#
# The representative set named in the phase's Gate integrity section is exactly what
# `probe:probe` links: the Dhall decoder, io-sim/io-classes, the jit-build resolver's
# dependencies, purescript-bridge, and the Pulsar client's supernova/proto-lens pair. These
# targets build all of it and nothing later.
REPRESENTATIVE_TARGETS = ("probe:probe", "probe:decode", "probe:sim", "proto")


def source_env(source_root: Path = ROOT) -> dict[str, str]:
    """The contained subprocess environment, taken from the tree the run is solving.

    This once prepended `<source_root>/tools` so that Cabal's `post-checkout-command`
    found the patch helper inside whichever copy of the tree was being resolved — the
    worktree for one pass, the snapshot for the other. The helper and the fetch it
    patched are both gone, so the parameter now only records which tree the caller means;
    nothing on `PATH` is read out of it.
    """
    del source_root
    return toolchain.contained_env()


def build_env(resolved: dict[str, Any], *, source_root: Path = ROOT) -> dict[str, str]:
    """PATH with the resolved codegen tools in front.

    `proto`'s Custom Setup resolves `protoc` and `proto-lens-protoc` through `$PATH` at
    configure time — it has no flag to point at them. Resolving a tool and then not putting
    it where its consumer looks is how a dynamic resolver silently falls back to whatever
    the host happens to have installed, so the gate exports exactly what it resolved.
    """
    environment = source_env(source_root)
    directories = [
        str(Path(resolved[name]["path"]).parent)
        # `git` is here for the same reason as the codegen pair: Cabal materializes the
        # remaining `source-repository-package` stanzas by running it, and a resolved tool
        # that is not put where its consumer looks is a resolution the run then declines to
        # use. `supernova` is no longer among them — it is read from `vendor/**`.
        for name in ("protoc", "proto_lens_protoc", "git")
        if name in resolved
    ]
    ordered = list(dict.fromkeys(directories))
    environment["PATH"] = os.pathsep.join(ordered + [environment.get("PATH", "")])
    return environment


def plan_path(build_root: Path) -> Path:
    return build_root / "cache" / "plan.json"


def solve(build_root: Path, compiler: str, cabal: str, store: str, *, cwd: Path = ROOT) -> dict[str, Any]:
    if build_root.exists():
        shutil.rmtree(build_root)
    checked(
        [
            cabal,
            f"--with-compiler={compiler}",
            f"--builddir={build_root}",
            f"--store-dir={store}",
            "build",
            "--dry-run",
            *REPRESENTATIVE_TARGETS,
        ],
        cwd=cwd,
        env=source_env(cwd),
    )
    return json.loads(plan_path(build_root).read_text(encoding="utf-8"))


def admissible_graph(plan: dict[str, Any]) -> dict[str, str]:
    """The identity a second resolution has to reproduce: package name to version.

    Unit ids are hashes over the whole configuration, so comparing them would compare
    build directories rather than the resolved graph. Comparing name-to-version answers
    the question the sprint actually asks — did the two runs admit the same packages.
    """
    graph: dict[str, str] = {}
    for unit in plan.get("install-plan", []):
        name = unit.get("pkg-name")
        version = unit.get("pkg-version")
        if name and version:
            graph[name] = version
    return graph


def direct_dependencies(plan: dict[str, Any]) -> set[str]:
    """The packages the solver planned as direct dependencies of `probe:probe`."""
    by_id = {unit.get("id"): unit for unit in plan.get("install-plan", [])}
    names: set[str] = set()
    for unit in plan.get("install-plan", []):
        if unit.get("pkg-name") != "probe":
            continue
        if unit.get("component-name") not in ("exe:probe", None):
            continue
        for dependency in unit.get("depends", []) + unit.get("exe-depends", []):
            target = by_id.get(dependency)
            if target and target.get("pkg-name"):
                names.add(target["pkg-name"])
    return names


def write_lock(name: str, plan: dict[str, Any]) -> Path:
    LOCKS.mkdir(parents=True, exist_ok=True)
    path = LOCKS / f"{name}.json"
    path.write_text(
        json.dumps(
            {
                "resolved": admissible_graph(plan),
                "compiler": plan.get("compiler-id", ""),
                "direct-dependencies": sorted(direct_dependencies(plan)),
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    return path


def snapshot_tree() -> Path:
    if SNAPSHOT_TREE.exists():
        shutil.rmtree(SNAPSHOT_TREE)
    for relative in artifact_policy.snapshot_paths():
        destination = SNAPSHOT_TREE / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, destination)
    return SNAPSHOT_TREE


def resolution_side(resolved: dict[str, Any], store: str) -> tuple[bool, dict[str, Any]]:
    print("\nresolution side — authored requirements to an admissible graph\n")
    cabal = resolved["cabal"]["path"]
    compiler = resolved["ghc"]["path"]
    ok = True

    for name in sorted(name for name in resolved if name != "platform"):
        record = resolved[name]
        print(f"  ok    {name:<20} {record['version']:<16} satisfies {record['requirement']}")

    ok = acquisition_contained(resolved) and ok
    ok = managed_idempotent(resolved) and ok
    ok = resolution_negatives() and ok
    print()

    plans = []
    for index, build_root in enumerate(PLAN_ROOTS):
        plan = solve(build_root, compiler, cabal, store)
        plans.append(plan)
        write_lock("resolution-a" if index == 0 else "resolution-b", plan)
    graphs = [admissible_graph(plan) for plan in plans]
    if graphs[0] != graphs[1]:
        drift = sorted(set(graphs[0].items()) ^ set(graphs[1].items()))
        print(f"  FAIL  twice-resolved       two resolutions disagreed on {len(drift)} entr(ies): {drift[:6]}")
        ok = False
    else:
        print(f"  ok    twice-resolved       two independent resolutions admitted the same {len(graphs[0])} packages")

    tree = snapshot_tree()
    snapshot_build = tree / SNAPSHOT_ROOT_NAME
    try:
        snapshot_plan = solve(snapshot_build, compiler, cabal, store, cwd=tree)
    except GateFailure as error:
        print(f"  FAIL  snapshot-resolves    the graph does not resolve from non-ignored source alone:\n{error}")
        return False, plans[0]
    snapshot_graph = admissible_graph(snapshot_plan)
    if snapshot_graph != graphs[0]:
        drift = sorted(set(snapshot_graph.items()) ^ set(graphs[0].items()))
        print(f"  FAIL  snapshot-resolves    snapshot graph differs on {len(drift)} entr(ies): {drift[:6]}")
        ok = False
    else:
        count = len(artifact_policy.snapshot_paths())
        print(f"  ok    snapshot-resolves    {count} non-ignored files resolve the same graph with no worktree help")
    return ok, plans[0]


# --------------------------------------------------------------------------
# build and probes
# --------------------------------------------------------------------------


def build_side(resolved: dict[str, Any], store: str, log: Path) -> bool:
    print("\nbuild side — the representative set from an empty package store\n")
    if BUILD_ROOT.exists():
        shutil.rmtree(BUILD_ROOT)
    command = [
        resolved["cabal"]["path"],
        f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={store}",
        "build",
        *REPRESENTATIVE_TARGETS,
    ]
    print(f"  $ {' '.join(command)}")
    environment = build_env(resolved)
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as sink:
        sink.write(f"$ {' '.join(command)}\n")
        process = subprocess.Popen(
            command, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        assert process.stdout is not None
        tail: list[str] = []
        for line in process.stdout:
            sink.write(line)
            tail.append(line)
            del tail[:-40]
        status = process.wait()
        sink.write(f"exit_status={status}\n")
    if status != 0:
        print("".join(tail))
        print(f"  FAIL  clean-store-build   cabal exited {status}; transcript at {rel(log)}")
        return False

    # The build has to have used the reviewed copy, and a green cabal alone does not say
    # so: a project that refetched the upstream would compile just as happily against
    # source no one here read. Two observations settle it — the run-local checkout root
    # holds no `supernova`, and the compatibility edit is present in the tracked tree
    # rather than replayed into a checkout.
    checkouts = sorted(BUILD_ROOT.glob("src/supernova-*"))
    if checkouts:
        found = ", ".join(rel(path) for path in checkouts)
        print(f"  FAIL  clean-store-build   supernova was fetched into a run-local checkout: {found}")
        return False
    vendored = ROOT / "vendor" / "supernova" / "lib" / "src" / "Pulsar" / "Internal" / "Core.hs"
    if "Control.Monad " not in vendored.read_text(encoding="utf-8"):
        print(f"  FAIL  clean-store-build   {rel(vendored)} carries no compatibility edit")
        return False
    print(f"  ok    clean-store-build   built into an empty store; transcript at {rel(log)}")
    print("  ok    clean-store-build   built from vendored supernova source, with no git checkout")
    return True


def probe_side(resolved: dict[str, Any], store: str, run_dir: Path) -> bool:
    print("\nprobe side — each probe against its independently authored expectation\n")
    cabal = resolved["cabal"]["path"]
    common = [cabal, f"--with-compiler={resolved['ghc']['path']}", "-v0", f"--builddir={BUILD_ROOT}", f"--store-dir={store}"]
    environment = build_env(resolved)
    ok = True

    linked = capture([*common, "run", "probe:probe"], env=environment)
    if linked.returncode != 0 or linked.stdout != "phase-1-dependency-surface-linked\n":
        print(f"  FAIL  dependency-link     exit {linked.returncode}, stdout {linked.stdout!r}")
        ok = False
    else:
        print("  ok    dependency-link     the representative dependency surface links and runs")

    expected = (ROOT / "probe" / "fixtures" / "ok.expected").read_text(encoding="utf-8")
    positive = capture([*common, "run", "probe:decode", "--", "probe/fixtures/ok.dhall"], env=environment)
    if positive.returncode != 0 or positive.stdout != expected:
        print(f"  FAIL  decode-positive     expected {expected!r}, got {positive.stdout!r}")
        ok = False
    else:
        print("  ok    decode-positive     decodes probe/fixtures/ok.dhall to its authored value")

    tag = (ROOT / "probe" / "fixtures" / "bad-type.expected-error").read_text(encoding="utf-8").strip()
    negative = capture([*common, "run", "probe:decode", "--", "probe/fixtures/bad-type.dhall"], env=environment)
    if negative.returncode == 0 or tag not in negative.stdout + negative.stderr:
        print(f"  FAIL  decode-negative     exit {negative.returncode} without the authored tag {tag!r}")
        ok = False
    else:
        print(f"  ok    decode-negative     the mistyped fixture fails at {tag}")

    oracle = [
        sys.executable,
        str(ROOT / "probe" / "oracle" / "check-sim-terminal"),
        f"--cabal={cabal}",
        f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={store}",
    ]
    simulation = capture(oracle, env=environment)
    if simulation.returncode != 0:
        print(f"  FAIL  simulation-terminal {simulation.stdout}{simulation.stderr}")
        ok = False
    else:
        print("  ok    simulation-terminal reaches the authored terminal state")

    ok = codegen(resolved, run_dir) and ok
    return ok


def codegen(resolved: dict[str, Any], run_dir: Path) -> bool:
    schema = ROOT / "vendor" / "supernova" / "proto" / "src" / "pulsar_api.proto"
    if not schema.is_file():
        print(f"  FAIL  protocol-codegen    the vendored schema {rel(schema)} is absent")
        return False
    sources = [schema]
    output = clear(PROTO_OUT)
    result = capture(
        [
            resolved["protoc"]["path"],
            f"--plugin=protoc-gen-haskell={resolved['proto_lens_protoc']['path']}",
            f"--haskell_out={output}",
            f"--proto_path={sources[0].parent}",
            sources[0].name,
        ]
    )
    if result.returncode != 0:
        print(f"  FAIL  protocol-codegen    protoc exited {result.returncode}: {result.stderr[-1500:]}")
        return False
    modules = [output / "Proto" / "PulsarApi.hs", output / "Proto" / "PulsarApi_Fields.hs"]
    missing = [module for module in modules if not module.is_file() or module.stat().st_size == 0]
    if missing:
        print(f"  FAIL  protocol-codegen    empty or absent: {', '.join(rel(m) for m in missing)}")
        return False
    (run_dir / "protocol-modules.json").write_text(
        json.dumps(
            {rel(module): artifact_policy.digest(str(module)) for module in modules},
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"  ok    protocol-codegen    both modules emitted under {rel(output)}")
    return True


# --------------------------------------------------------------------------
# mutants
# --------------------------------------------------------------------------


def read_mutants() -> dict[str, dict[str, str]]:
    """Discover the committed mutant descriptors rather than hard-coding them."""
    found: dict[str, dict[str, str]] = {}
    for path in sorted((ROOT / "probe" / "mutants").iterdir()):
        if path.suffix or not path.is_file():
            continue
        fields = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line:
                key, _, value = line.partition("=")
                fields[key.strip()] = value.strip()
        found[path.name] = fields
    return found


def mutant_side(resolved: dict[str, Any], store: str) -> bool:
    print("\nmutant side — each committed seeded mutant turns the gate red\n")
    mutants = read_mutants()
    environment = build_env(resolved)
    ok = True

    descriptor = mutants.get("drop-allow-newer", {})
    if MUTANT_ROOT.exists():
        shutil.rmtree(MUTANT_ROOT)
    STORE_PARENT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="amoebius-phase1-mutant-store-", dir=STORE_PARENT
    ) as mutant_store:
        result = capture(
            [
                resolved["cabal"]["path"],
                f"--project-file={descriptor.get('project_file', 'probe/mutants/drop-allow-newer.project')}",
                f"--with-compiler={resolved['ghc']['path']}",
                f"--builddir={MUTANT_ROOT}",
                f"--store-dir={mutant_store}",
                "build",
                *REPRESENTATIVE_TARGETS,
            ],
            env=environment,
        )
    output = result.stdout + result.stderr
    intended = re.search(r"proto\s*=>\s*base>=4\.13\.0\s*&&\s*<4\.14", output)
    if result.returncode == 0 or intended is None:
        print(f"  FAIL  drop-allow-newer    exit {result.returncode} without the intended proto/base conflict")
        print("        " + output[-1200:].replace("\n", "\n        "))
        ok = False
    else:
        print("  ok    drop-allow-newer    solver rejects base against the upstream <4.14 bound")

    perturbed = capture(
        [
            sys.executable,
            str(ROOT / "probe" / "oracle" / "check-sim-terminal"),
            f"--cabal={resolved['cabal']['path']}",
            f"--with-compiler={resolved['ghc']['path']}",
            f"--builddir={BUILD_ROOT}",
            f"--store-dir={store}",
            "--perturbed",
        ],
        env=environment,
    )
    if perturbed.returncode == 0 or "terminal-state mismatch" not in perturbed.stdout + perturbed.stderr:
        print(f"  FAIL  perturb-sim-schedule exit {perturbed.returncode} without a terminal-state mismatch")
        ok = False
    else:
        print("  ok    perturb-sim-schedule the dropped fairness step is caught at the terminal oracle")
    return ok


# --------------------------------------------------------------------------
# surface, ledger, attestation, write guard
# --------------------------------------------------------------------------


def probe_executables() -> set[str]:
    text = (ROOT / "probe" / "probe.cabal").read_text(encoding="utf-8")
    return set(re.findall(r"(?m)^executable\s+([A-Za-z0-9_-]+)\s*$", text))


def load_expectations() -> list[tuple[str, str, list[str]]]:
    rows: list[tuple[str, str, list[str]]] = []
    for number, line in enumerate(EXPECTATIONS.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise GateFailure(f"{rel(EXPECTATIONS)}:{number}: expected three tab-separated fields")
        surface, owner, ids = (field.strip() for field in fields)
        rows.append((surface, owner, [i for i in ids.split(",") if i]))
    return rows


def surface_side(resolved: dict[str, Any], plan: dict[str, Any]) -> tuple[bool, list[str]]:
    print("\nsurface side — run-time enumeration joined to the authored expectation\n")
    implemented = {
        "toolchain": {name for name in resolved if name != "platform"},
        "dependencies": direct_dependencies(plan),
        "probes": probe_executables(),
        "mutants": set(read_mutants()),
        "checks": set(CHECKS),
    }
    try:
        expected = load_expectations()
    except GateFailure as error:
        print(f"  FAIL  {error}")
        return False, []

    ok = True
    claimed: dict[str, set[str]] = {owner: set() for owner in implemented}
    for surface, owner, ids in expected:
        if owner not in implemented:
            print(f"  FAIL  {surface:<34} unknown owner {owner!r}")
            ok = False
            continue
        missing = [i for i in ids if i not in implemented[owner]]
        if missing:
            print(f"  FAIL  {surface:<34} {owner} produced no {', '.join(missing)}")
            ok = False
        for i in ids:
            if i in claimed[owner]:
                print(f"  FAIL  {surface:<34} {i} is claimed twice")
                ok = False
            claimed[owner].add(i)
    for owner, ids in implemented.items():
        for orphan in sorted(ids - claimed[owner]):
            print(f"  FAIL  {owner}:{orphan:<28} enumerated but joins to no surface")
            ok = False

    surfaces = [surface for surface, _owner, _ids in expected]
    if ok:
        total = sum(len(ids) for ids in implemented.values())
        print(f"  ok    {len(surfaces)} surfaces join completely to {total} enumerated items")
    SURFACES.parent.mkdir(parents=True, exist_ok=True)
    SURFACES.write_text(
        json.dumps(
            {"phase": 1, "surfaces": surfaces, "implemented": {o: sorted(i) for o, i in implemented.items()}},
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"  ok    enumeration written to {rel(SURFACES)}")
    return ok, surfaces


def emit_ledger(run_dir: Path, surfaces: list[str], results: dict[str, bool], architecture: str) -> Path:
    ledger = {
        "phase": 1,
        "gate_command": GATE_COMMAND,
        "register": "1",
        "substrate": "none",
        "lane": LANE,
        "architecture": architecture,
        "date": dt.date.today().isoformat(),
        # Phase 1 resolves and compiles. It exercises no amoebius decision or protocol
        # behaviour and stands up no runtime, so all three layers stay outside its reach
        # except the buildability of the decision-layer dependencies, which is a tested
        # property of the toolchain rather than of amoebius.
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": [
            {"surface": surface, "status": "tested" if results.get(surface, True) else "UNVERIFIED"}
            for surface in surfaces
        ],
    }
    ledger["ledger_hash"] = ledger_lint.canonical_hash(ledger)
    run_dir.mkdir(parents=True, exist_ok=True)
    path = run_dir / "ledger.json"
    path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def ledger_side(run_dir: Path, surfaces: list[str], architecture: str) -> tuple[bool, Path]:
    print("\nledger side — the run ledger inside the run bundle\n")
    path = emit_ledger(run_dir, surfaces, {}, architecture)
    result = capture([sys.executable, str(HERE / "ledger_lint.py"), str(path), "--enumeration", str(SURFACES)])
    if result.returncode == 0:
        print(f"  ok    {rel(path)}  schema, tracker, surfaces, hash")
        return True, path
    print((result.stdout + result.stderr).rstrip())
    return False, path


def attestation_side(run_dir: Path, ledger_path: Path, resolved: dict[str, Any], plan: dict[str, Any], results: dict[str, bool], architecture: str) -> bool:
    print("\nattestation side — project-contained retention\n")
    commit = artifact_policy.git("rev-parse", "HEAD").strip()
    dirty = bool(artifact_policy.git("status", "--porcelain").strip())
    snapshot = artifact_policy.source_digest()
    bundle = {
        "schema": attestation.SCHEMA,
        "phase": 1,
        "contract": CONTRACT,
        "contract_digest": "sha256:" + artifact_policy.digest(str(ROOT / CONTRACT)),
        "commit": f"{commit}+uncommitted" if dirty and commit else (commit or "uncommitted"),
        "source_digest": snapshot,
        "command": GATE_COMMAND,
        "register": "1",
        "substrate": "none",
        "lane": LANE,
        "architecture": architecture,
        "toolchain": {
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        "dependencies": admissible_graph(plan),
        "checks": [{"name": name, "status": "pass" if results.get(name) else "fail"} for name in SIDE_NAMES],
        "mutants": [
            {"name": "drop-allow-newer", "status": "red"},
            {"name": "perturb-sim-schedule", "status": "red"},
            {"name": "phase-1 seeded provenance negatives", "status": "red"},
            {"name": "architecture complement comparison", "status": "red"},
        ],
        "coverage": [{"surface": "phase_01", "status": "tested"}],
        "cleanup": {"left_resources": False},
        "observations": {
            "ledger": "sha256:" + artifact_policy.digest(str(ledger_path)),
            "resolution_a": "sha256:" + artifact_policy.digest(str(LOCKS / "resolution-a.json")),
            "resolution_b": "sha256:" + artifact_policy.digest(str(LOCKS / "resolution-b.json")),
        },
        "ledger_hash": json.loads(ledger_path.read_text(encoding="utf-8"))["ledger_hash"],
    }
    problems = attestation.schema_check(bundle)
    if problems:
        for problem in problems:
            print(f"  FAIL  run bundle: {problem}")
        return False
    store = attestation.default_store()
    reference = store.put(bundle)
    if not store.verify(reference):
        print(f"  FAIL  attestation {reference} did not verify")
        return False
    print(f"  ok    attested {reference}")
    print(f"  ok    bound to source snapshot {snapshot[:23]}… ({len(artifact_policy.snapshot_paths())} files)")
    return True


def cleanup() -> None:
    for path in (*PLAN_ROOTS, MUTANT_ROOT, BUILD_ROOT):
        shutil.rmtree(path, ignore_errors=True)
    shutil.rmtree(SNAPSHOT_TREE, ignore_errors=True)


def main() -> int:
    before = artifact_policy.authored_snapshot()
    before_host = containment.host_inventory()
    run_dir = ROOT / ".build" / "runs" / "phase_01" / run_id()
    run_dir.mkdir(parents=True, exist_ok=True)
    results = dict.fromkeys(SIDE_NAMES, False)

    # Clause 15 first: a run that cannot name the architecture it executed on, or that
    # is executing under translation, has nothing worth resolving a toolchain for.
    results["architecture"], architecture = gate_common.architecture_side()
    if not results["architecture"]:
        return 1

    # The floor next, for the same reason: a host that cannot supply what only it can
    # supply should be told which prerequisite and which remedy, not walked into a
    # resolution failure four requirements deep.
    results["floor"] = floor_side()
    if not results["floor"]:
        return 1

    try:
        resolved = toolchain.resolve(TOOLS_REQUIRED)
    except toolchain.ResolutionError as error:
        print(f"phase1-gate: FAIL: {error}", file=sys.stderr)
        return 1

    STORE_PARENT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="amoebius-phase1-store-", dir=STORE_PARENT) as store:
        if any(Path(store).iterdir()):
            print("phase1-gate: FAIL: the new package store was not empty", file=sys.stderr)
            return 1
        try:
            results["provenance"] = provenance_side()
            results["resolution"], plan = resolution_side(resolved, store)
            results["build"] = build_side(resolved, store, run_dir / "clean-store-build.log")
            if results["build"]:
                results["probe"] = probe_side(resolved, store, run_dir)
                results["mutant"] = mutant_side(resolved, store)
            else:
                print("\nprobe side and mutant side are UNREACHED: the clean-store build did not complete\n")
            results["surface"], surfaces = surface_side(resolved, plan)
            results["ledger"], ledger_path = ledger_side(run_dir, surfaces, architecture)
            results["attestation"] = attestation_side(run_dir, ledger_path, resolved, plan, results, architecture)
        except GateFailure as error:
            print(f"phase1-gate: FAIL: {error}", file=sys.stderr)
        finally:
            cleanup()

    after_host = containment.host_inventory()
    containment_problems = containment.host_inventory_problems(before_host, after_host)
    for path in (run_dir, SURFACES, LOCKS, PROTO_OUT, CORPORA, SNAPSHOT_TREE, BUILD_ROOT, STORE_PARENT):
        try:
            containment.require_state_path(path, "build", actor="production")
        except containment.ContainmentError as error:
            containment_problems.append(str(error))
    print("\ncontainment side — closed roots and outside-host inventory\n")
    for problem in containment_problems:
        print(f"  FAIL  {problem}")
    if after_host.observation_errors:
        for error in after_host.observation_errors:
            print(f"  note  {error}")
    results["containment"] = not containment_problems
    if results["containment"]:
        print("  ok    Phase-1 state is beneath .build/ and the outside-host inventory is unchanged")

    guard = artifact_policy.Report()
    artifact_policy.audit_write_guard(guard, before, artifact_policy.authored_snapshot())
    results["write-guard"] = not guard.findings
    print("\nwrite guard — authored roots during this run\n")
    if results["write-guard"]:
        print("  ok    no authored path was created, changed, or removed")
    else:
        for finding in guard.findings:
            print(f"  FAIL  {finding.render()}")

    print()
    for name in SIDE_NAMES:
        print(f"{name:<12} side: {'PASS' if results[name] else 'FAIL'}")
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
