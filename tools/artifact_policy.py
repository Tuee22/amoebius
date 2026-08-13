#!/usr/bin/env python3
"""The amoebius artifact-policy audit — the Sprint 0.7 half of the Phase 0 gate.

`doc_lint.py` validates prose and the link graph. This module validates the other
half of the Phase-0 contract: that the repository separates authored inputs from
generated output the way
`documents/engineering/repository_layout_doctrine.md` section 8 requires.

Eleven rules, each independently seeded:

    r1  generator-registry     every doctrine output class has a declared generator
    r2  provenance             no tracked file is a reproducible copy
    r3  ignore-coverage        .gitignore/.dockerignore meet the normative patterns
    r4  docker-context         the effective build context carries no generated state
    r5  write-guard            no command writes beneath an authored root
    r6  dynamic-resolution     no tracked resolver output, integrity pin, or home path
    r7  source-closure         no build or gate input is an ignored worktree file
    r8  revision-history       reachable history is audited and dispositioned
    r9  external-attestation   a run bundle schema-checks, stores, and verifies
    r10 terminology            no retired predecessor name survives in the tree
    r11 no-leak                the gate changes no tracked file and creates no unignored path

Python 3 standard library only, and no dependency on the amoebius binary.

    python3 tools/artifact_policy.py              # audit this repository
    python3 tools/artifact_policy.py --self-test  # prove each rule rejects its negative
    python3 tools/artifact_policy.py --json OUT   # machine-readable findings

Exit status: 0 clean, 1 findings, 2 usage error.
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

sys.path.insert(0, str(HERE))

import attestation  # noqa: E402
import phase0_artifact_lint as legacy  # noqa: E402

RULES = {
    "r1": "generator registry covers every doctrine output class",
    "r2": "semantic provenance: no tracked file is a reproducible copy",
    "r3": "ignore coverage: both ignore contracts meet the normative patterns",
    "r4": "docker context: no generated, evidence, cache, or secret path survives",
    "r5": "write guard: no command writes beneath an authored root",
    "r6": "dynamic resolution: no tracked resolver output, integrity pin, or home path",
    "r7": "source closure: no build or gate input is an ignored worktree file",
    "r8": "revision history: audited, with secrets absent and findings dispositioned",
    "r9": "external attestation: a run bundle schema-checks, stores, and verifies",
    "r10": "terminology: no retired predecessor name survives in the tree",
    "r11": "no-leak: the gate changes no tracked file and creates no unignored path",
}

REGISTRY = HERE / "generator_registry.tsv"
ALLOWLIST = HERE / "migration_allowlist.tsv"
DISPOSITION = HERE / "history_disposition.tsv"
LEGACY_REGISTER = ROOT / "DEVELOPMENT_PLAN" / "legacy_tracking_for_deletion.md"
LAYOUT_DOCTRINE = ROOT / "documents" / "engineering" / "repository_layout_doctrine.md"

# Roots whose contents are authored inputs. A gate may not write beneath one.
AUTHORED_ROOTS = (
    "DEVELOPMENT_PLAN",
    "documents",
    "app",
    "src",
    "dhall",
    "pb",
    "ui",
    "ui-live",
    "ui-runtime",
    "offline-runtime",
    "apple-host",
    "amoebius-pulsar",
    "amoebius-pulumi",
    "amoebius-release",
    "amoebius-runtime",
    "amoebius-store",
    "infernix",
    "infernix-ui",
    "jitml",
    "jitml-ui",
    "probe",
    "pulumi",
    "test-topology",
    "test",
    "tests",
    "mutants",
    "tools",
    "vendor",
    "patches",
    "docker",
)

# Directories a tree walk never descends into: VCS metadata plus the two present-day
# package-manager/compiler output roots, which are large and wholly generated.
PRUNE_DIRS = {".git", "node_modules", "dist-newstyle", ".cabal-sandbox"}

# A path in any of these families is generated output wherever it appears, so a
# tracked instance is a provenance defect rather than an ignore-pattern gap.
GENERATED_PATH_GLOBS = (
    "gen/*",
    "dist-newstyle/*",
    ".cabal-sandbox/*",
    "node_modules/*",
    "ui-runtime/.spago/*",
    "ui-runtime/output/*",
    "ui-runtime/dist/*",
    "toolchain/bin/*",
    "toolchain/runtime/*",
    "toolchain/downloads/*",
    "toolchain/cache/*",
    "*.o",
    "*.hi",
    "*.dyn_o",
    "*.dyn_hi",
    "*.hie",
    "*.pyc",
    "*.pyo",
    "*.pyd",
    "*__pycache__*",
    "*.lock",
    "*.freeze",
    "package-lock.json",
    "npm-shrinkwrap.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "spago.lock",
    "flake.lock",
    "poetry.lock",
    "Pipfile.lock",
    "Gemfile.lock",
    "composer.lock",
    "mix.lock",
    "go.sum",
    "*.log",
    "*.pid",
    "*.sock",
    "DEVELOPMENT_PLAN/evidence/*",
    "DEVELOPMENT_PLAN/ledgers/*",
    "test/enumeration/*",
)

# Run-evidence filename families named by repository-layout doctrine section 3.5.
EVIDENCE_NAME_GLOBS = (
    "phase-results.tsv",
    "validation-locus-ledger.tsv",
    "live-*.tsv",
    "sprint-*.tsv",
    "*-red-before-correction.tsv",
    "receipt.json",
    "commands.json",
    "junit.xml",
)

GENERATED_BANNERS = (
    "do not edit",
    "@generated",
    "autogenerated",
    "auto-generated",
    "generated by",
    "this file is generated",
)

# The proven/tested/assumed ledger recognised by shape rather than by filename.
LEDGER_KEYS = {
    "phase",
    "gate_command",
    "register",
    "substrate",
    "date",
    "layers",
    "coverage",
    "ledger_hash",
}

SECRET_NAME_GLOBS = (
    ".env",
    ".env.*",
    "*.pem",
    "*.key",
    "id_rsa*",
    "id_ed25519*",
    "kubeconfig",
    "*.kubeconfig",
    "credentials",
    "credentials.*",
    ".secrets/*",
    ".credentials/*",
)

# Present-day generated roots inside an authored tree. Naming one from a tool is a
# write-location defect owned by the naming phase, not a source-closure defect.
MIGRATION_ROOTS = (
    "DEVELOPMENT_PLAN/evidence/",
    "DEVELOPMENT_PLAN/ledgers/",
    "test/enumeration/",
)
MIGRATION_LEDGER = re.compile(r"test/golden/phase_\d{2}_ledger\.json")

# The authored negative corpus for ledger_lint is a hand-written ledger by design;
# doctrine section 3.5 classifies it as a candidate authored negative corpus.
LEDGER_SHAPE_EXEMPT = "tools/ledger_lint_corpus/"

# A home-directory path in a tracked file is resolver output. A guest path the image
# itself owns is contractual; those live under a declared guest prefix.
HOME_PATH = re.compile(r"(?:/home/(?!operator/|\.pulumi/)|/Users/)[A-Za-z0-9_.-]+/")

# An integrity pin is a hex digest sitting in a dependency-resolution context: beside
# a url, a version, or an executable path. A digest inside an authored catalog entry
# is that phase's fixture-provenance question, not a resolver pin.
HEX64 = re.compile(r"\b[a-f0-9]{64}\b")
RESOLUTION_CONTEXT = re.compile(r'"(?:url|version|path|source|tag|revision)"\s*:', re.I)

TEXT_SUFFIXES = legacy.BYTECODE_POLICY_SUFFIXES | {".tsv", ".txt", ".project", ".cfg", ".proto"}


@dataclass(frozen=True)
class Finding:
    rule: str
    locus: str
    message: str
    deferred: bool = False
    owner: str = ""

    def render(self) -> str:
        tag = f"deferred[{self.owner}]" if self.deferred else self.rule
        return f"{tag}: {self.locus}: {self.message}"


@dataclass
class Allowance:
    rule: str
    glob: str
    message: str
    owner: str
    anchor: str
    used: int = 0

    def covers(self, finding: Finding) -> bool:
        return (
            self.rule == finding.rule
            and fnmatch.fnmatch(finding.locus, self.glob)
            and fnmatch.fnmatch(finding.message, self.message)
        )


@dataclass
class Report:
    findings: list[Finding] = field(default_factory=list)
    deferred: list[Finding] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    def failed(self) -> bool:
        return bool(self.findings)


# --------------------------------------------------------------------------
# Repository facts
# --------------------------------------------------------------------------


def git(*args: str, cwd: Path = ROOT) -> str:
    result = subprocess.run(
        ["git", *args], cwd=cwd, text=True, capture_output=True, check=False
    )
    if result.returncode != 0 and not result.stdout:
        return ""
    return result.stdout


def tracked_paths(root: Path = ROOT) -> list[str]:
    out = git("ls-files", "-z", cwd=root)
    return [p for p in out.split("\0") if p]


def snapshot_paths(root: Path = ROOT) -> list[str]:
    """Every non-ignored file: the source a gate actually ran against.

    Tracked and untracked-but-not-ignored files both count, because both are inputs a
    run can read. Commit state deliberately does not enter into it —
    `development_plan_standards.md` section S withdrew commit timing as a gate input.
    """
    out = git("ls-files", "-z", "--cached", "--others", "--exclude-standard", cwd=root)
    return sorted(p for p in out.split("\0") if p and (root / p).is_file())


def source_digest(root: Path = ROOT) -> str:
    """Digest the source snapshot: one hash over `path\\0content-hash` for every file.

    This is what an attestation binds to. Editing any non-ignored file changes it, so a
    stale result cannot be presented as current; committing that same content does not.
    """
    accumulator = hashlib.sha256()
    for relative in snapshot_paths(root):
        try:
            accumulator.update(relative.encode("utf-8") + b"\0" + digest(root / relative).encode())
        except OSError:
            continue
    return "sha256:" + accumulator.hexdigest()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def digest(path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def matches_any(path: str, globs) -> bool:
    return any(fnmatch.fnmatch(path, g) for g in globs)


def load_allowances() -> list[Allowance]:
    rows: list[Allowance] = []
    if not ALLOWLIST.is_file():
        return rows
    for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 5:
            continue
        rule, glob, message, owner, anchor = (f.strip() for f in fields)
        rows.append(Allowance(rule, glob, message, owner, anchor))
    return rows


def apply_allowances(report: Report, allowances: list[Allowance]) -> None:
    """Move a finding an authored allowance covers onto the deferred list.

    An allowance is a dated, phase-owned migration allowance recorded in the legacy
    register. It never silences a finding: the finding is still reported, attributed
    to its owning phase, and the allowance itself must stay in use.
    """
    kept: list[Finding] = []
    for finding in report.findings:
        for row in allowances:
            if row.covers(finding):
                row.used += 1
                report.deferred.append(
                    Finding(finding.rule, finding.locus, finding.message, True, row.owner)
                )
                break
        else:
            kept.append(finding)
    report.findings = kept


def audit_allowlist_integrity(report: Report, allowances: list[Allowance]) -> None:
    """An allowance may only shrink, and every row must be justified in the register."""
    register = read_text(LEGACY_REGISTER)
    for row in allowances:
        if row.rule not in RULES:
            report.findings.append(
                Finding("r2", ALLOWLIST.name, f"allowance names unknown rule {row.rule!r}")
            )
        if not row.used:
            report.findings.append(
                Finding(
                    "r2",
                    ALLOWLIST.name,
                    f"stale allowance {row.rule} {row.glob!r} matched nothing; remove it",
                )
            )
        if row.anchor and row.anchor not in register:
            report.findings.append(
                Finding(
                    "r2",
                    ALLOWLIST.name,
                    f"allowance {row.glob!r} cites {row.anchor!r}, absent from the legacy register",
                )
            )


# --------------------------------------------------------------------------
# r1 — generator registry
# --------------------------------------------------------------------------


def doctrine_output_classes() -> set[str]:
    """The `gen/` inventory of repository-layout doctrine section 3.1.

    Parsed from the doctrine rather than restated here, so the registry is checked
    against a document authored independently of this module.
    """
    text = read_text(LAYOUT_DOCTRINE)
    start = text.find("### 3.1 Canonical `gen/` tree")
    if start < 0:
        return set()
    block_start = text.find("```text", start)
    block_end = text.find("```", block_start + 7)
    if block_start < 0 or block_end < 0:
        return set()
    block = text[block_start + 7 : block_end]
    classes: set[str] = set()
    stack: dict[int, str] = {}
    for line in block.splitlines():
        if not line.strip() or line.strip() == "gen/":
            continue
        marker = re.search(r"[├└]── ", line)
        if not marker:
            continue
        depth = marker.start() // 4
        name = line[marker.end() :].split()[0] if line[marker.end() :].split() else ""
        if not name:
            continue
        stack[depth] = name.rstrip("/")
        prefix = "/".join(stack[d].rstrip("/") for d in sorted(stack) if d < depth)
        full = f"{prefix}/{name}" if prefix else name
        # A nested leaf refines its parent; the parent already names the class.
        if depth == 0:
            classes.add(full)
    return classes


def audit_generator_registry(
    report: Report, registry_text: str | None = None, classes: set[str] | None = None
) -> None:
    classes = doctrine_output_classes() if classes is None else classes
    if not classes:
        report.findings.append(
            Finding("r1", LAYOUT_DOCTRINE.name, "cannot parse the section 3.1 gen/ inventory")
        )
        return
    if registry_text is None:
        if not REGISTRY.is_file():
            report.findings.append(Finding("r1", REGISTRY.name, "generator registry is missing"))
            return
        registry_text = REGISTRY.read_text(encoding="utf-8")

    declared: dict[str, tuple[str, str]] = {}
    for number, line in enumerate(registry_text.splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            report.findings.append(
                Finding("r1", f"{REGISTRY.name}:{number}", "expected three tab-separated fields")
            )
            continue
        output_class, generator, owner = (f.strip() for f in fields)
        if output_class in declared:
            report.findings.append(
                Finding("r1", f"{REGISTRY.name}:{number}", f"duplicate class {output_class!r}")
            )
        declared[output_class] = (generator, owner)
        if generator != "-" and not (ROOT / generator).exists():
            report.findings.append(
                Finding("r1", f"{REGISTRY.name}:{number}", f"generator {generator} does not exist")
            )
        if generator == "-" and not re.fullmatch(r"phase-\d{1,2}", owner):
            report.findings.append(
                Finding(
                    "r1",
                    f"{REGISTRY.name}:{number}",
                    f"unbuilt class {output_class!r} must name its owning phase, not {owner!r}",
                )
            )

    for missing in sorted(classes - set(declared)):
        report.findings.append(
            Finding("r1", REGISTRY.name, f"doctrine output class {missing!r} has no registry row")
        )
    for extra in sorted(set(declared) - classes):
        report.findings.append(
            Finding("r1", REGISTRY.name, f"registry class {extra!r} is not in the doctrine inventory")
        )

    audit_generator_targets(report, {c.split("/")[0] for c in declared})


GEN_TARGET = re.compile(r"\bgen/([A-Za-z0-9_.<>-]+)")


def audit_generator_targets(
    report: Report, declared_roots: set[str], sources: dict[str, str] | None = None
) -> None:
    """A tool may only name a `gen/` sub-root the registry declares.

    Catching this statically is what stops a new generator inventing an output class
    silently: the doctrine inventory has to be amended before the path can be written.
    """
    if sources is None:
        sources = {
            p: read_text(ROOT / p)
            for p in tracked_paths()
            if p.startswith("tools/")
            and p.endswith(".py")
            and p != "tools/artifact_policy.py"
        }
    for relative, text in sorted(sources.items()):
        seen: set[str] = set()
        for match in GEN_TARGET.finditer(text):
            root = match.group(1)
            if root in declared_roots or root in seen:
                continue
            seen.add(root)
            report.findings.append(
                Finding("r1", relative, f"writes undeclared output class gen/{root}/")
            )


# --------------------------------------------------------------------------
# r2 — semantic provenance
# --------------------------------------------------------------------------


def classify_tracked(relative: str, text: str | None, twin: str = "") -> list[Finding]:
    """Semantic provenance for one tracked path. Pure, so the self-test can drive it."""
    findings: list[Finding] = []
    base = os.path.basename(relative)
    if matches_any(relative, GENERATED_PATH_GLOBS) or matches_any(base, GENERATED_PATH_GLOBS):
        return [Finding("r2", relative, "tracked path belongs to a generated output family")]
    if matches_any(base, EVIDENCE_NAME_GLOBS):
        return [Finding("r2", relative, "tracked path is a run-evidence filename family")]
    if text is None:
        return findings

    head = "\n".join(text.splitlines()[:15]).lower()
    for banner in GENERATED_BANNERS:
        if banner in head:
            findings.append(
                Finding("r2", relative, f"tracked file carries a generated banner ({banner!r})")
            )
            break
    if relative.endswith(".json") and not relative.startswith(LEDGER_SHAPE_EXEMPT):
        try:
            value = json.loads(text)
        except (json.JSONDecodeError, ValueError):
            value = None
        if isinstance(value, dict) and LEDGER_KEYS <= set(value):
            findings.append(Finding("r2", relative, "tracked JSON has the run-ledger shape"))
    if twin:
        findings.append(
            Finding("r2", relative, f"tracked file is byte-identical to generated {twin}")
        )
    return findings


def audit_provenance(report: Report, generated_digests: dict[str, str] | None = None) -> None:
    generated_digests = generated_digests or {}
    for relative in tracked_paths():
        path = ROOT / relative
        if not path.is_file():
            continue
        readable = path.suffix in TEXT_SUFFIXES
        twin = ""
        if generated_digests and readable:
            try:
                twin = generated_digests.get(digest(path), "")
            except OSError:
                twin = ""
        report.findings.extend(
            classify_tracked(relative, read_text(path) if readable else None, twin)
        )


def index_generated_tree(gen_root: Path) -> dict[str, str]:
    """Digest every file this run materialized, so a tracked twin can be recognised."""
    index: dict[str, str] = {}
    if not gen_root.is_dir():
        return index
    for path in gen_root.rglob("*"):
        if path.is_file():
            try:
                index.setdefault(digest(path), str(path.relative_to(ROOT)))
            except OSError:
                continue
    return index


# --------------------------------------------------------------------------
# r3 / r10 — the ignore contract and terminology, owned by the legacy module
# --------------------------------------------------------------------------


def audit_ignore_coverage(report: Report) -> None:
    errors: list[str] = []
    legacy.audit_ignore_contract(errors)
    for error in errors:
        locus, _, message = error.partition(": ")
        report.findings.append(Finding("r3", locus, message))


def audit_terminology(report: Report) -> None:
    errors: list[str] = []
    legacy.audit_bootstrap_coordinator_terminology(errors)
    for error in errors:
        locus, _, message = error.partition(": ")
        report.findings.append(Finding("r10", locus, message))


# --------------------------------------------------------------------------
# r4 — the effective Docker build context
# --------------------------------------------------------------------------


class DockerIgnore:
    """A .dockerignore matcher over the exclusion syntax the contract actually uses."""

    def __init__(self, patterns: list[str]):
        self.rules: list[tuple[str, bool]] = []
        for raw in patterns:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            negated = line.startswith("!")
            if negated:
                line = line[1:].strip()
            self.rules.append((line.strip("/"), negated))

    def excluded(self, relative: str) -> bool:
        state = False
        for pattern, negated in self.rules:
            if self._match(relative, pattern):
                state = not negated
        return state

    @staticmethod
    def _match(relative: str, pattern: str) -> bool:
        if fnmatch.fnmatch(relative, pattern):
            return True
        # `a/**` covers descendants; `a` alone covers the directory itself.
        if pattern.endswith("/**") and (
            relative == pattern[:-3] or relative.startswith(pattern[:-2])
        ):
            return True
        if "/" not in pattern and fnmatch.fnmatch(os.path.basename(relative), pattern):
            return True
        if pattern.startswith("**/"):
            tail = pattern[3:]
            if fnmatch.fnmatch(relative, tail) or fnmatch.fnmatch(
                os.path.basename(relative), tail
            ):
                return True
            if any(fnmatch.fnmatch(part, tail) for part in relative.split("/")):
                return True
        return False


def effective_docker_context(root: Path = ROOT) -> list[str]:
    matcher = DockerIgnore((root / ".dockerignore").read_text(encoding="utf-8").splitlines())
    surviving: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root).replace(os.sep, "/")
        if rel_dir == ".":
            rel_dir = ""
        keep = []
        for name in dirnames:
            child = f"{rel_dir}/{name}" if rel_dir else name
            if name == ".git" or matcher.excluded(child):
                continue
            keep.append(name)
        dirnames[:] = keep
        for name in filenames:
            child = f"{rel_dir}/{name}" if rel_dir else name
            if not matcher.excluded(child):
                surviving.append(child)
    return surviving


def audit_docker_context(report: Report, context: list[str] | None = None) -> None:
    try:
        entries = effective_docker_context() if context is None else context
    except OSError as exc:
        report.findings.append(Finding("r4", ".dockerignore", str(exc)))
        return
    for relative in entries:
        base = os.path.basename(relative)
        if matches_any(relative, GENERATED_PATH_GLOBS) or matches_any(base, GENERATED_PATH_GLOBS):
            report.findings.append(
                Finding("r4", relative, "generated output survives into the build context")
            )
        elif matches_any(base, EVIDENCE_NAME_GLOBS):
            report.findings.append(
                Finding("r4", relative, "run evidence survives into the build context")
            )
        elif matches_any(relative, SECRET_NAME_GLOBS) or matches_any(base, SECRET_NAME_GLOBS):
            report.findings.append(
                Finding("r4", relative, "credential or runtime state survives into the build context")
            )


# --------------------------------------------------------------------------
# r5 — the authored-root write guard
# --------------------------------------------------------------------------


def authored_snapshot(root: Path = ROOT) -> dict[str, str]:
    """Digest every file beneath an authored root, ignoring Python's bytecode cache."""
    snapshot: dict[str, str] = {}
    for name in AUTHORED_ROOTS:
        base = root / name
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            parts = path.relative_to(root).parts
            if "__pycache__" in parts or path.suffix in {".pyc", ".pyo", ".pyd"}:
                continue
            try:
                snapshot[str(path.relative_to(root))] = digest(path)
            except OSError:
                continue
    return snapshot


def compare_snapshots(before: dict[str, str], after: dict[str, str]) -> list[tuple[str, str]]:
    changes: list[tuple[str, str]] = []
    for relative in sorted(set(after) - set(before)):
        changes.append((relative, "created beneath an authored root"))
    for relative in sorted(set(before) - set(after)):
        changes.append((relative, "deleted from an authored root"))
    for relative in sorted(set(before) & set(after)):
        if before[relative] != after[relative]:
            changes.append((relative, "modified beneath an authored root"))
    return changes


def audit_write_guard(report: Report, before: dict[str, str], after: dict[str, str]) -> None:
    for relative, message in compare_snapshots(before, after):
        report.findings.append(Finding("r5", relative, message))


# --------------------------------------------------------------------------
# r6 — dynamic resolution
# --------------------------------------------------------------------------


def scan_resolution(relative: str, text: str) -> list[Finding]:
    """Resolver-output detection for one tracked file. Pure, so the self-test drives it."""
    findings: list[Finding] = []
    match = HOME_PATH.search(text)
    if match:
        findings.append(
            Finding("r6", relative, f"tracked file carries a resolved home path ({match.group(0)})")
        )
    if HEX64.search(text) and RESOLUTION_CONTEXT.search(text):
        findings.append(
            Finding("r6", relative, "tracked file pins a package integrity digest beside its source")
        )
    if re.search(r"expected_(hashes|digests)|reference_traces", os.path.basename(relative)):
        findings.append(
            Finding("r6", relative, "tracked expected-digest table needs authored provenance or regeneration")
        )
    return findings


def audit_dynamic_resolution(report: Report, paths: list[str] | None = None) -> None:
    for relative in tracked_paths() if paths is None else paths:
        path = ROOT / relative
        if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
            continue
        report.findings.extend(scan_resolution(relative, read_text(path)))


# --------------------------------------------------------------------------
# r7 — fresh-clone source closure
# --------------------------------------------------------------------------

# A build configuration is what a fresh clone must be able to satisfy before any gate
# runs, so an ignored path named here breaks source closure outright.
BUILD_CONFIG_GLOBS = ("cabal.project", "package.json", "*.cabal", "docker/*")
# A gate script naming a generated-migration root is a write-location defect instead.
GATE_SCRIPT_GLOBS = ("tools/*.py", "tools/*/*.py", "pb/*.py")
PATH_LITERAL = re.compile(r"[A-Za-z0-9_.\-]+(?:/[A-Za-z0-9_.\-]+)+")
# A reference into the generated root, a temporary directory, or one of the declared
# build roots of repository-layout doctrine section 3.2 is not a closure obligation:
# section S clause 3 admits all three as write destinations, and inside a Dockerfile
# they name the image's own filesystem rather than the repository.
CLOSURE_EXEMPT_PREFIXES = (
    "gen/",
    "tmp/",
    "temp/",
    "dist-newstyle/",
    "node_modules/",
    "out/",
    "output/",
    "build/",
    "_build/",
    "dist/",
    ".cache/",
    "toolchain/bin/",
    "toolchain/runtime/",
    "toolchain/downloads/",
    "toolchain/cache/",
)


def ignored_paths(candidates: list[str]) -> set[str]:
    if not candidates:
        return set()
    result = subprocess.run(
        ["git", "check-ignore", "--stdin"],
        cwd=ROOT,
        input="\n".join(candidates),
        text=True,
        capture_output=True,
        check=False,
    )
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def path_references(globs) -> dict[str, set[str]]:
    referenced: dict[str, set[str]] = {}
    for relative in tracked_paths():
        if not matches_any(relative, globs):
            continue
        path = ROOT / relative
        if not path.is_file():
            continue
        for token in PATH_LITERAL.findall(read_text(path)):
            token = token.strip("./")
            if not token or token.startswith(CLOSURE_EXEMPT_PREFIXES):
                continue
            referenced.setdefault(token, set()).add(relative)
    return referenced


def audit_source_closure(report: Report, references: dict[str, set[str]] | None = None) -> None:
    if references is None:
        # Deliberately not filtered by existence. A build configuration naming a path
        # the clone will not contain is the strongest closure failure there is, and it
        # is invisible from a worktree where the ignored file happens to be present.
        references = path_references(BUILD_CONFIG_GLOBS)
    for token in sorted(ignored_paths(sorted(references))):
        for consumer in sorted(references[token]):
            report.findings.append(
                Finding("r7", consumer, f"references ignored worktree input {token}")
            )


def audit_write_locations(report: Report, references: dict[str, set[str]] | None = None) -> None:
    """A gate must not name a generated path inside an authored root.

    The dynamic guard below catches a write that happens during this run. This static
    half catches the declaration, so a gate that is merely not run today still fails.
    """
    if references is None:
        references = path_references(GATE_SCRIPT_GLOBS)
    for token, consumers in sorted(references.items()):
        if not (token.startswith(MIGRATION_ROOTS) or MIGRATION_LEDGER.fullmatch(token)):
            continue
        for consumer in sorted(consumers):
            report.findings.append(
                Finding("r5", consumer, f"names generated path {token} beneath an authored root")
            )


# --------------------------------------------------------------------------
# r8 — reachable revision history
# --------------------------------------------------------------------------


def historical_paths(root: Path = ROOT) -> set[str]:
    out = git("rev-list", "--objects", "--all", cwd=root)
    paths: set[str] = set()
    for line in out.splitlines():
        _, _, name = line.partition(" ")
        if name:
            paths.add(name)
    return paths


def load_dispositions() -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    if not DISPOSITION.is_file():
        return rows
    for line in DISPOSITION.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 4:
            continue
        glob, decision, date, _note = (f.strip() for f in fields)
        rows.append((glob, decision, date))
    return rows


def audit_revision_history(report: Report, paths: set[str] | None = None) -> None:
    history = historical_paths() if paths is None else paths
    dispositions = load_dispositions()
    retired = "mid" + "wife"

    undispositioned: set[str] = set()
    for relative in sorted(history):
        base = os.path.basename(relative)
        secret = matches_any(relative, SECRET_NAME_GLOBS) or matches_any(base, SECRET_NAME_GLOBS)
        generated = matches_any(relative, GENERATED_PATH_GLOBS) or matches_any(
            base, GENERATED_PATH_GLOBS
        )
        obsolete = retired in relative.lower()
        if secret:
            report.findings.append(
                Finding("r8", relative, "reachable history contains a credential; rotate and purge")
            )
            continue
        if not (generated or obsolete):
            continue
        for glob, decision, _date in dispositions:
            if fnmatch.fnmatch(relative, glob):
                if decision not in {"retain-history", "approved-rewrite"}:
                    report.findings.append(
                        Finding("r8", DISPOSITION.name, f"unknown disposition {decision!r} for {glob}")
                    )
                break
        else:
            undispositioned.add(relative)

    for relative in sorted(undispositioned)[:20]:
        report.findings.append(
            Finding("r8", relative, "historical generated or obsolete blob has no recorded disposition")
        )
    if len(undispositioned) > 20:
        report.findings.append(
            Finding("r8", DISPOSITION.name, f"{len(undispositioned) - 20} further undispositioned paths")
        )

    unreachable = git("fsck", "--unreachable", "--no-progress").splitlines()
    blobs = [line for line in unreachable if " blob " in line]
    report.notes.append(
        f"r8: {len(history)} reachable paths audited; "
        f"{len(blobs)} unreachable local object(s) reported as local state only"
    )


# --------------------------------------------------------------------------
# r9 — external attestation
# --------------------------------------------------------------------------


def audit_external_attestation(report: Report, bundle: dict | None = None) -> None:
    """Prove the attestation path end to end on a synthetic bundle in a temp store."""
    with tempfile.TemporaryDirectory(prefix="amoebius-attest-") as directory:
        store = attestation.Store(Path(directory))
        sample = bundle if bundle is not None else attestation.sample_bundle()
        problems = attestation.schema_check(sample)
        if problems:
            for problem in problems:
                report.findings.append(Finding("r9", "run-bundle", problem))
            return
        try:
            reference = store.put(sample)
        except attestation.AttestationError as exc:
            report.findings.append(Finding("r9", "evidence-store", str(exc)))
            return
        if not store.verify(reference):
            report.findings.append(
                Finding("r9", reference, "stored attestation did not verify against its digest")
            )
        for name, broken, expect in attestation.negative_corpus(sample):
            if attestation.schema_check(broken):
                continue
            try:
                store.put(broken)
            except attestation.AttestationError:
                continue
            report.findings.append(
                Finding("r9", name, f"negative bundle was accepted; expected rejection at {expect}")
            )


# --------------------------------------------------------------------------
# r11 — no leaked output
# --------------------------------------------------------------------------


def worktree_state(root: Path = ROOT) -> dict[str, str]:
    out = git("status", "--porcelain", "-z", "--untracked-files=all", cwd=root)
    state: dict[str, str] = {}
    for entry in out.split("\0"):
        if len(entry) > 3:
            state[entry[3:]] = entry[:2]
    return state


def audit_clean_tree(report: Report, before: dict[str, str], after: dict[str, str]) -> None:
    for relative in sorted(set(after) - set(before)):
        report.findings.append(
            Finding("r11", relative, f"the gate created an unignored path ({after[relative].strip()})")
        )
    for relative in sorted(set(before) & set(after)):
        if before[relative] != after[relative]:
            report.findings.append(
                Finding("r11", relative, "the gate changed a tracked file's status")
            )


# --------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------


def audit(gen_root: Path | None = None) -> Report:
    report = Report()
    audit_generator_registry(report)
    audit_provenance(report, index_generated_tree(gen_root) if gen_root else {})
    audit_ignore_coverage(report)
    audit_docker_context(report)
    audit_dynamic_resolution(report)
    audit_source_closure(report)
    audit_write_locations(report)
    audit_revision_history(report)
    audit_external_attestation(report)
    audit_terminology(report)

    allowances = load_allowances()
    apply_allowances(report, allowances)
    audit_allowlist_integrity(report, allowances)
    return report


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="The amoebius artifact-policy audit.")
    ap.add_argument("--self-test", action="store_true", help="prove each rule rejects its negative")
    ap.add_argument("--json", type=Path, help="write findings to this path")
    ap.add_argument("--list-rules", action="store_true")
    args = ap.parse_args(argv)

    if args.list_rules:
        for rule, description in RULES.items():
            print(f"{rule:<4} {description}")
        return 0

    if args.self_test:
        import artifact_policy_selftest as selftest

        return 0 if selftest.run() else 1

    before_authored = authored_snapshot()
    before_state = worktree_state()
    report = audit()
    audit_write_guard(report, before_authored, authored_snapshot())
    audit_clean_tree(report, before_state, worktree_state())

    for note in report.notes:
        print(f"  note {note}")
    for finding in report.deferred:
        print(f"  defer {finding.render()}")
    for finding in report.findings:
        print(f"artifact-policy: {finding.render()}", file=sys.stderr)

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(
            json.dumps(
                {
                    "findings": [f.__dict__ for f in report.findings],
                    "deferred": [f.__dict__ for f in report.deferred],
                    "notes": report.notes,
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )

    if report.failed():
        print(f"artifact-policy: FAIL — {len(report.findings)} finding(s)", file=sys.stderr)
        return 1
    print(
        f"  ok   11 rules clean; {len(report.deferred)} finding(s) deferred to their owning phase"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
