#!/usr/bin/env python3
"""Audit the pre-implementation oracles and mutants sealed by Phase 0."""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "test" / "oracle" / "preimplementation_artifacts.tsv"
# The one enumerable surface this module owns, declared so the run-time enumeration can
# discover it rather than the expectation file asserting it unilaterally.
CHECKS = {"manifest": "every pre-implementation oracle and mutant resolves and is owned"}
PHASES = {2, *range(16, 24), 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, *range(55, 65)}
PHASE_LOCAL_ROOTS = (
    ROOT / "test" / "manifest" / "golden",
    ROOT / "test" / "kernel" / "fixtures",
    ROOT / "test" / "kernel" / "mutants",
    ROOT / "test" / "boundary" / "golden",
    ROOT / "test" / "boundary" / "mutants",
    ROOT / "test" / "fixtures" / "phase14",
    ROOT / "test" / "fixtures" / "phase24",
    ROOT / "test" / "host" / "mutants",
    ROOT / "test" / "sim" / "mutants",
)
PHASE_MARKER = re.compile(r"(?:^|[/_.-])phase[_-]?(\d{1,2})(?=[/_.-]|$)", re.IGNORECASE)
LEDGER_PATH = re.compile(r"test/golden/phase_\d{2}_ledger\.json$")
PLAN_DOCS = [
    ROOT / "DEVELOPMENT_PLAN" / f"phase_{phase:02d}_"
    for phase in sorted(PHASES)
]
GITIGNORE_BYTECODE_PATTERNS = {"__pycache__/", "*.py[cod]"}
DOCKERIGNORE_BYTECODE_PATTERNS = {
    "**/__pycache__",
    "**/__pycache__/**",
    "**/*.pyc",
    "**/*.pyo",
    "**/*.pyd",
}
LAYOUT_DOCTRINE = ROOT / "documents" / "engineering" / "repository_layout_doctrine.md"
IGNORE_FENCE = re.compile(r"```(gitignore|dockerignore)\n(.*?)```", re.S)


def declared_ignore_patterns() -> dict[str, set[str]]:
    """The two contracts as repository-layout doctrine sections 6 and 7 declare them.

    Parsed, not restated. Doctrine calls both blocks exhaustive in both directions, and a
    second copy of an exhaustive list is how a pattern comes to exist that no reviewer
    ever approved: the copies agree on the day they are written and nothing rechecks them.
    """
    declared: dict[str, set[str]] = {"gitignore": set(), "dockerignore": set()}
    try:
        text = LAYOUT_DOCTRINE.read_text(encoding="utf-8")
    except OSError:
        return declared
    for kind, block in IGNORE_FENCE.findall(text):
        for line in block.splitlines():
            pattern = line.strip()
            if pattern and not pattern.startswith("#"):
                declared[kind].add(pattern)
    return declared


_DECLARED = declared_ignore_patterns()
GITIGNORE_REQUIRED_PATTERNS = _DECLARED["gitignore"]
DOCKERIGNORE_REQUIRED_PATTERNS = _DECLARED["dockerignore"]

BYTECODE_POLICY_SUFFIXES = {
    ".cabal",
    ".dhall",
    ".hs",
    ".js",
    ".json",
    ".lhs",
    ".md",
    ".mjs",
    ".nix",
    ".ps1",
    ".purs",
    ".py",
    ".sh",
    ".toml",
    ".ts",
    ".yaml",
    ".yml",
}
GENERATED_MIGRATION_PREFIXES = (
    "DEVELOPMENT_PLAN/evidence/",
    "DEVELOPMENT_PLAN/ledgers/",
)


def phase_doc(prefix: Path) -> Path:
    matches = list(prefix.parent.glob(prefix.name + "*.md"))
    if len(matches) != 1:
        raise ValueError(f"expected one phase document for {prefix.name}, found {len(matches)}")
    return matches[0]


def belongs_to_pin_owner(path: Path) -> bool:
    """Limit discovery to paths that identify one of the declared pin owners.

    Later implementation gates also use directories named fixtures, golden, and
    mutants.  They are not retroactively Phase-0 inputs.  Manifested generic
    paths are still checked directly above; this predicate governs only the
    search for *unmanifested* phase-attributed pins.
    """
    relative = str(path.relative_to(ROOT))
    return any(int(match.group(1)) in PHASES for match in PHASE_MARKER.finditer(relative))


def policy_lines(path: Path) -> set[str]:
    return {
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }


def authored_repository_paths() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    paths: list[Path] = []
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        relative = raw.decode("utf-8", errors="surrogateescape")
        if relative.startswith(GENERATED_MIGRATION_PREFIXES):
            continue
        if relative.startswith("test/enumeration/"):
            continue
        if re.fullmatch(r"test/golden/phase_\d{2}_ledger\.json", relative):
            continue
        path = ROOT / relative
        if path.is_file():
            paths.append(path)
    return paths


def authored_policy_paths() -> list[Path]:
    return [path for path in authored_repository_paths() if path.suffix in BYTECODE_POLICY_SUFFIXES]


def audit_ignore_contract(
    errors: list[str],
    *,
    gitignore: set[str] | None = None,
    dockerignore: set[str] | None = None,
) -> None:
    gitignore = policy_lines(ROOT / ".gitignore") if gitignore is None else gitignore
    dockerignore = policy_lines(ROOT / ".dockerignore") if dockerignore is None else dockerignore
    for pattern in sorted(GITIGNORE_REQUIRED_PATTERNS - gitignore):
        errors.append(f".gitignore: missing generated-artifact pattern {pattern!r}")
    for pattern in sorted(DOCKERIGNORE_REQUIRED_PATTERNS - dockerignore):
        errors.append(f".dockerignore: missing generated-artifact pattern {pattern!r}")
    # The other direction, which doctrine claims and nothing checked: a pattern the file
    # carries and section 6 or 7 does not name is a class no reviewer approved.
    for pattern in sorted(gitignore - GITIGNORE_REQUIRED_PATTERNS):
        errors.append(f".gitignore: undeclared pattern {pattern!r}; doctrine section 6 must name it")
    for pattern in sorted(dockerignore - DOCKERIGNORE_REQUIRED_PATTERNS):
        errors.append(f".dockerignore: undeclared pattern {pattern!r}; doctrine section 7 must name it")
    for pattern in sorted(GITIGNORE_BYTECODE_PATTERNS - GITIGNORE_REQUIRED_PATTERNS):
        errors.append(f".gitignore: doctrine section 6 drops bytecode pattern {pattern!r}")
    for pattern in sorted(DOCKERIGNORE_BYTECODE_PATTERNS - DOCKERIGNORE_REQUIRED_PATTERNS):
        errors.append(f".dockerignore: doctrine section 7 drops bytecode pattern {pattern!r}")


def audit_bytecode_policy(
    errors: list[str],
    *,
    paths: list[Path] | None = None,
) -> None:
    environment_switch = "PYTHON" + "DONTWRITEBYTECODE"
    no_cache_flag = "-" + "B"
    command_flag = re.compile(
        r"(?:\bpython|\bpython3|/usr/bin/python3|\{sys\.executable\}|sys\.executable)\s+"
        + re.escape(no_cache_flag)
        + r"(?:\s|$)"
    )
    quoted_flags = {f'"{no_cache_flag}"', f"'{no_cache_flag}'"}
    for path in authored_policy_paths() if paths is None else paths:
        text = path.read_text(encoding="utf-8", errors="replace")
        relative = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path.name
        if environment_switch in text:
            errors.append(f"{relative}: suppresses ignored Python bytecode through the environment")
        if command_flag.search(text) or any(flag in text for flag in quoted_flags):
            errors.append(f"{relative}: suppresses ignored Python bytecode through a Python command flag")


def audit_bootstrap_coordinator_terminology(
    errors: list[str], *, paths: list[Path] | None = None
) -> None:
    retired_term = "mid" + "wife"
    retired_bytes = retired_term.encode("ascii")
    for path in authored_repository_paths() if paths is None else paths:
        relative = path.relative_to(ROOT) if path.is_relative_to(ROOT) else Path(path.name)
        if retired_term in str(relative).lower():
            errors.append(f"{relative}: retired predecessor term in Bootstrap Coordinator pathname")
        content = path.read_bytes()
        if b"\0" not in content and retired_bytes in content.lower():
            errors.append(f"{relative}: retired predecessor term for Bootstrap Coordinator")


def verify_artifact_policy() -> list[str]:
    failures: list[str] = []
    missing_errors: list[str] = []
    audit_ignore_contract(missing_errors, gitignore=set(), dockerignore=set())
    if len(missing_errors) != len(GITIGNORE_REQUIRED_PATTERNS) + len(DOCKERIGNORE_REQUIRED_PATTERNS):
        failures.append("artifact-policy negative: missing ignore patterns were not all rejected")

    with tempfile.TemporaryDirectory(prefix="amoebius-bytecode-policy-") as directory:
        fixture = Path(directory) / "suppression.py"
        environment_switch = "PYTHON" + "DONTWRITEBYTECODE"
        no_cache_flag = "-" + "B"
        fixture.write_text(
            f"{environment_switch}=1 python3 gate.py\npython3 {no_cache_flag} gate.py\n",
            encoding="utf-8",
        )
        suppression_errors: list[str] = []
        audit_bytecode_policy(
            suppression_errors,
            paths=[fixture],
        )
    if len(suppression_errors) != 2:
        failures.append("bytecode-policy negative: command suppression was not rejected at both loci")

    with tempfile.TemporaryDirectory(prefix="amoebius-terminology-policy-") as directory:
        retired_term = "mid" + "wife"
        fixture = Path(directory) / f"legacy-{retired_term}.py"
        fixture.write_text(retired_term + "\n", encoding="utf-8")
        terminology_errors: list[str] = []
        audit_bootstrap_coordinator_terminology(terminology_errors, paths=[fixture])
    if len(terminology_errors) != 2:
        failures.append("terminology-policy negative: pathname and content were not both rejected")
    return failures


def main() -> int:
    errors: list[str] = []
    audit_ignore_contract(errors)
    audit_bytecode_policy(errors)
    audit_bootstrap_coordinator_terminology(errors)
    errors.extend(verify_artifact_policy())
    rows: dict[str, tuple[int, str, str]] = {}
    by_phase: dict[int, set[str]] = defaultdict(set)
    for number, line in enumerate(MANIFEST.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 4:
            errors.append(f"manifest:{number}: expected four tab-separated fields")
            continue
        phase_raw, kind, path_raw, expectation = fields
        try:
            phase = int(phase_raw)
        except ValueError:
            errors.append(f"manifest:{number}: invalid phase {phase_raw!r}")
            continue
        if phase not in PHASES:
            errors.append(f"manifest:{number}: phase {phase} is not a Phase-0 pin owner")
        if kind not in {"oracle", "mutant"}:
            errors.append(f"manifest:{number}: invalid kind {kind!r}")
        if path_raw in rows:
            errors.append(f"manifest:{number}: duplicate path {path_raw}")
        rows[path_raw] = (phase, kind, expectation)
        by_phase[phase].add(kind)
        path = ROOT / path_raw
        if not path.is_file():
            errors.append(f"manifest:{number}: missing file {path_raw}")
        elif path.stat().st_size == 0:
            errors.append(f"manifest:{number}: empty file {path_raw}")
        prefix = "gate-red:" if kind == "mutant" else "independent-pin:"
        if not expectation.startswith(prefix) or len(expectation) == len(prefix):
            errors.append(f"manifest:{number}: expectation must begin {prefix!r} and name its locus")
        if kind == "mutant" and "/mutants/" not in path_raw:
            errors.append(f"manifest:{number}: mutant must live under a mutants directory")

    for phase in sorted(PHASES):
        missing = {"oracle", "mutant"} - by_phase.get(phase, set())
        if missing:
            errors.append(f"phase {phase}: missing {', '.join(sorted(missing))} manifest row")

    # Phase 0 governs authored pre-implementation inputs, not later executable
    # test implementations. Keep auditing the fixture/oracle/mutant namespaces
    # while allowing phase suites (for example RoundTripSpec.hs) to appear as
    # their owning phase is completed. Phase-2 byte goldens are the one explicit
    # deferred exception named by the Phase-2.3 plan.
    artifact_namespaces = {"oracle", "mutants", "fixtures", "golden", "dhall"}
    # An ignored path is generated output, so it is never a Phase-0 authored artifact.
    # Filtering by ignore status rather than by filename keeps this agreeing with
    # .gitignore instead of drifting from it, and makes the local worktree and a fresh
    # clone reach the same verdict.
    candidates = sorted(
        str(path.relative_to(ROOT))
        for path in (ROOT / "test").rglob("*")
        if path.is_file()
    )
    ignored = set()
    if candidates:
        lookup = subprocess.run(
            ["git", "check-ignore", "--stdin"],
            cwd=ROOT,
            input="\n".join(candidates),
            text=True,
            capture_output=True,
            check=False,
        )
        ignored = {line.strip() for line in lookup.stdout.splitlines() if line.strip()}
    actual = {
        str(path.relative_to(ROOT))
        for path in (ROOT / "test").rglob("*")
        if path.is_file()
        and path != MANIFEST
        and "__pycache__" not in path.parts
        and path.suffix not in {".pyc", ".pyo", ".pyd"}
        and artifact_namespaces.intersection(path.relative_to(ROOT / "test").parts)
        and not (
            path.parent == ROOT / "test" / "formal" / "golden"
            and path.name.endswith(".golden")
        )
        and not (ROOT / "test" / "formal" / "gateway") in path.parents
        and str(path.relative_to(ROOT)) not in ignored
        and not any(root == path.parent or root in path.parents for root in PHASE_LOCAL_ROOTS)
        and belongs_to_pin_owner(path)
    }
    for path in sorted(actual - set(rows)):
        errors.append(f"unmanifested Phase-0 artifact: {path}")
    # Concrete paths delegated to Phase 0 by their owning gate must resolve and be
    # listed.  Brace/glob forms, directories, and Phase-2 byte goldens are excluded:
    # Phase 2.3 deliberately pins those only after fixing the rendering convention.
    explicit_re = re.compile(r"`(test/(?:fixtures|golden|mutants|dhall)/[^` ]+)`")
    for prefix in PLAN_DOCS:
        doc = phase_doc(prefix)
        document = doc.read_text(encoding="utf-8")
        for match in explicit_re.finditer(document):
            path = match.group(1).rstrip(".,;:")
            if path.endswith("/") or "phase_NN" in path or any(char in path for char in "{}*"):
                continue
            if LEDGER_PATH.fullmatch(path):
                continue
            paragraph_start = document.rfind("\n\n", 0, match.start()) + 2
            paragraph_end = document.find("\n\n", match.end())
            if paragraph_end == -1:
                paragraph_end = len(document)
            paragraph = document[paragraph_start:paragraph_end]
            if "generated artifact" in paragraph and "never committed" in paragraph:
                continue
            if path not in rows:
                errors.append(f"{doc.name}: concrete Phase-0 pin is absent from manifest: {path}")

    if errors:
        for error in errors:
            print(f"phase0-artifacts: {error}", file=sys.stderr)
        return 1
    print(
        f"  ok   {len(rows)} artifacts across {len(PHASES)} owning gates; "
        "complete ignore/terminology contract plus four seeded negative classes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
