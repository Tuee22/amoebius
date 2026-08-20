#!/usr/bin/env python3
"""The Phase-2 gate — the authored tree is the target tree, and every consumer resolves at it.

Phase 2 makes one cohesive claim across six seams, and the gate runs each seam as its own
side over one enumeration of the source snapshot:

  collision    no two enumerated paths differ only by case
  map          the authored relocation map parses, every destination the section 2 target
               tree admits, and every row cites the license that permits the move
  relocation   no old prefix the map names survives, and every destination is populated
  reference    no tracked text file names a path the tree no longer has
  resolution   every `hs-source-dirs` and `main-is` in the one authored package resolves,
               and no root outside the target tree carries a package declaration
  registry     one mutant registry covers every committed body and every build flag
  partition    rules r13 and r15 report zero findings, and the migration allowlist carries
               no r13 or r15 row left to defer
  mutant       each of six committed seeded mutants reddens its own check and no other
  surface      what the run enumerated joins completely to the authored expectation
  ledger       the proven/tested/assumed ledger is schema-clean inside the run bundle
  attestation  the run bundle verifies against the source-snapshot digest
  write-guard  nothing beneath an authored root was created, changed, or removed

The independent oracle is deliberately **not this phase's code**: `parse_target_tree` and
`offending_prefix` in `tools/artifact_policy.py` read the target tree out of
`documents/engineering/repository_layout_doctrine.md` section 2, a document Phase 0 owns
and this phase does not edit. The authored fixture is `tools/layout_relocation_map.tsv`,
written before the move, so the gate compares the tree against a plan rather than against
itself.

    python3 tools/repository_conformance_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import mutant_registry  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

GATE_COMMAND = "python3 tools/repository_conformance_gate.py"
CONTRACT = "DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md"
EXPECTATIONS = "test/oracle/repository_conformance_surfaces.tsv"

RELOCATION_MAP = "tools/layout_relocation_map.tsv"
ALLOWLIST = "tools/migration_allowlist.tsv"
LAYOUT_DOCTRINE = "documents/engineering/repository_layout_doctrine.md"
PACKAGE = "amoebius.cabal"
PROJECT = "cabal.project"
MUTANT_DIR = "test/mutant/repository_conformance"

SIDES = ("collision", "map", "relocation", "reference", "resolution", "registry",
         "partition", "mutant")

SCRATCH = ROOT / ".build" / "tmp" / "repository_conformance"

# The seven singular role nouns, asserted here only so the failure message can name them.
# The decidable form is the target tree's own fixed second level, which the oracle parses.
ROLE_NOUNS = ("spec", "fixture", "golden", "negative", "oracle", "mutant", "harness")

# Units doctrine section 2.1 admits as separately resolvable: foreign resolution and
# foreign provenance. Every other package declaration is a defect.
ADMITTED_PACKAGES = ("amoebius.cabal", "probe/probe.cabal", "vendor/dual/dual.cabal")

SEVEN_NOUN_LICENSE = "seven-noun-rule"

PRUNE = {".git", ".build", ".data", ".test_data", "node_modules", "dist-newstyle",
         ".cabal-sandbox", "__pycache__", ".venv"}

BINARY_SUFFIXES = {".png", ".jpg", ".gif", ".bin", ".cbor", ".hex", ".pdf", ".zip",
                   ".gz", ".class", ".jar", ".ico", ".woff", ".woff2", ".sha256"}

CHECKS = (
    "collision-free-tree",
    "no-empty-authored-directory",
    "map-parses",
    "map-destination-admitted",
    "map-license-cited",
    "relocation-complete",
    "no-dangling-reference",
    "source-dirs-resolve",
    "one-package-declaration",
    "registry-covers-bodies",
    "registry-covers-flags",
    "registry-no-unreachable",
    "target-tree-clean",
    "de-phased-naming",
    "allowlist-shrunk",
)


class GateFailure(RuntimeError):
    """An authored input is missing — the gate cannot decide, rather than deciding no."""


# ---------------------------------------------------------------------------
# the enumeration every check reads
# ---------------------------------------------------------------------------


def walk(root: Path) -> list[str]:
    """Every file beneath `root`, minus the generated and contained roots."""
    out: list[str] = []
    for base, directories, files in os.walk(root):
        directories[:] = sorted(d for d in directories if d not in PRUNE)
        for name in sorted(files):
            out.append(os.path.relpath(os.path.join(base, name), root))
    return sorted(out)


def enumerate_snapshot() -> list[str]:
    """The source snapshot as the audit sees it: tracked plus untracked-not-ignored."""
    return artifact_policy.snapshot_paths()


def read(root: Path, relative: str) -> str:
    try:
        return (root / relative).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


# ---------------------------------------------------------------------------
# the authored relocation map
# ---------------------------------------------------------------------------


def map_rows(root: Path) -> list[tuple[int, str, str, str]]:
    text = read(root, RELOCATION_MAP)
    if not text:
        raise GateFailure(f"the authored relocation map {RELOCATION_MAP} is missing")
    rows = []
    for number, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise GateFailure(f"{RELOCATION_MAP}:{number}: expected three tab-separated fields")
        rows.append((number, *(field.strip() for field in fields)))
    return rows


def section_22_cells(root: Path) -> set[str]:
    """The first-column cells of the doctrine's present-day-roots table.

    Read out of the doctrine rather than restated, for the same reason the target tree is:
    a license this module transcribed could drift from the one under review.
    """
    text = read(root, LAYOUT_DOCTRINE)
    start = text.find("### 2.2 Present-day roots")
    if start < 0:
        return set()
    end = text.find("\n### ", start + 1)
    cells = set()
    for line in text[start: end if end > 0 else len(text)].splitlines():
        if not line.startswith("|") or line.startswith("|---") or "Present path" in line:
            continue
        cell = line.split("|")[1].strip().replace("`", "")
        if cell:
            cells.add(cell)
    return cells


# ---------------------------------------------------------------------------
# the checks, each decidable against any root
# ---------------------------------------------------------------------------


def check_collision(paths: list[str]) -> list[str]:
    """No two enumerated paths — or their directory prefixes — differ only by case.

    The enumeration is the honest input rather than the filesystem: two of the four
    substrates reach the tree case-insensitively, so the pair the index can hold is
    precisely the pair the disk cannot, and a check that asked the disk would always pass.
    """
    seen: dict[str, str] = {}
    problems: list[str] = []
    names: set[str] = set()
    for path in paths:
        parts = path.split("/")
        for index in range(1, len(parts) + 1):
            names.add("/".join(parts[:index]))
    for name in sorted(names):
        lowered = name.lower()
        if lowered in seen and seen[lowered] != name:
            problems.append(f"{seen[lowered]} and {name} differ only by case")
        seen.setdefault(lowered, name)
    return problems


def check_empty_directories(root: Path) -> list[str]:
    """No directory beneath an authored root holds nothing.

    Git cannot track an empty directory, so a leftover one is invisible to every rule that
    enumerates files — which is how six of them survived a gate that passed on fourteen
    sides. They cannot reach a clone, but they can mislead a reader about what roots the
    tree has, and a later move into one silently resurrects a root the target tree retired.
    """
    problems: list[str] = []
    for base, directories, files in os.walk(root, topdown=True):
        directories[:] = sorted(d for d in directories if d not in PRUNE)
        if base == str(root):
            continue
        relative = os.path.relpath(base, root)
        if relative.split(os.sep)[0] in PRUNE:
            continue
        if not files and not directories:
            problems.append(f"{relative}/ holds no file at any depth")
    return problems


def check_map(root: Path, tree) -> tuple[list[str], list[str], list[str]]:
    """(parse problems, destination problems, license problems)."""
    try:
        rows = map_rows(root)
    except GateFailure as error:
        return [str(error)], [], []
    if not rows:
        return [f"{RELOCATION_MAP} carries no row"], [], []

    destinations: list[str] = []
    licenses: list[str] = []
    cells = section_22_cells(root)
    for number, old, new, license_ in rows:
        probe = new if not new.endswith("/") else new + "probe"
        offending = artifact_policy.offending_prefix(probe, tree)
        if offending is not None:
            destinations.append(
                f"{RELOCATION_MAP}:{number}: destination {new!r} is outside the target tree"
            )
        if license_ != SEVEN_NOUN_LICENSE and license_.replace("`", "") not in cells:
            licenses.append(
                f"{RELOCATION_MAP}:{number}: license {license_!r} is neither the seven-noun "
                "rule nor a section 2.2 present-path cell"
            )
    return [], destinations, licenses


def check_relocation(root: Path, paths: list[str], reported: set[str], rejected: set[str]) -> list[str]:
    """Every old prefix the map names is gone, and every destination carries something.

    Two precedences keep one defect from reddening two checks, which is what makes a
    seeded mutant attributable. A prefix the target-tree rule already names is a
    target-tree defect, not a relocation that failed to happen; and a destination the map
    check already rejected is a defect in the map, so its emptiness says nothing further.
    """
    problems: list[str] = []
    try:
        rows = map_rows(root)
    except GateFailure as error:
        return [str(error)]
    for _number, old, new, _license in rows:
        if old not in reported and any(path == old or path.startswith(old) for path in paths):
            problems.append(f"{old} survives the relocation the map plans")
        if new in rejected:
            continue
        if new.endswith("/"):
            if not any(path.startswith(new) for path in paths):
                problems.append(f"{new} is a planned destination the tree never received")
        elif new not in paths:
            problems.append(f"{new} is a planned destination the tree never received")
    return problems


def check_reference(root: Path, paths: list[str]) -> list[str]:
    """No tracked text file names a path the tree no longer has.

    A relocation is a rename plus its reference update performed as one edit, so a
    surviving mention of the old path is the half that did not happen. The scan is
    deliberately narrow — the old prefixes the map itself names — because a broad
    path-shaped-token scan reports every planned-but-unbuilt path in the plan suite.
    """
    try:
        rows = map_rows(root)
    except GateFailure as error:
        return [str(error)]
    present = set(paths)
    # The map, the register, the allowlist, and doctrine 2.2 record the pre-move tree as
    # history: their subject *is* the old path, and rewriting one destroys the record.
    history = {RELOCATION_MAP, ALLOWLIST, LAYOUT_DOCTRINE,
               "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md",
               "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md",
               "DEVELOPMENT_PLAN/phase_00_documentation_suite.md",
               "DEVELOPMENT_PLAN/phase_01_toolchain_spike.md",
               "DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md"}
    patterns = []
    for _number, old, _new, _license in rows:
        # A single-component prefix keeps its slash: `mutants` is also an English word, and
        # a check that reported every sentence containing it would report nothing usable.
        body = old if old.strip("/").count("/") == 0 else old.rstrip("/")
        patterns.append((old, re.compile(r"(?<![\w./\-])" + re.escape(body) + r"(?![\w.\-])")))
    problems: list[str] = []
    for relative in paths:
        if relative in history or relative.startswith("tools/doc_lint_corpus/"):
            continue
        if relative.startswith(MUTANT_DIR + "/"):
            # A seeded mutant names the defect it reintroduces; that is its whole content.
            continue
        if Path(relative).suffix in BINARY_SUFFIXES:
            continue
        text = read(root, relative)
        if not text:
            continue
        for old, pattern in patterns:
            if pattern.search(text) and old.rstrip("/") not in present:
                problems.append(f"{relative} names the departed path {old}")
                break
    return problems


SOURCE_DIRS = re.compile(r"^\s+hs-source-dirs:\s*(.*)$", re.M)
MAIN_IS = re.compile(r"^\s+main-is:\s*(\S+)\s*$", re.M)
STANZA = re.compile(r"^(library|executable|test-suite|benchmark)\b(.*)$", re.M)


def stanza_source_dirs(text: str) -> list[tuple[str, list[str]]]:
    """(stanza header, source dirs) for every component in the package description."""
    out: list[tuple[str, list[str]]] = []
    header = "<preamble>"
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        line = lines[index]
        match = STANZA.match(line)
        if match:
            header = line.strip()
            index += 1
            continue
        stripped = line.strip()
        if stripped.startswith("hs-source-dirs:"):
            rest = stripped.partition(":")[2].strip()
            entries = [e.strip() for e in rest.split(",") if e.strip()]
            index += 1
            while not entries and index < len(lines) and lines[index].startswith("      "):
                candidate = lines[index].strip()
                if not candidate or ":" in candidate:
                    break
                out.append((header, [candidate]))
                index += 1
            if entries:
                out.append((header, entries))
            continue
        index += 1
    return out


def check_resolution(root: Path, paths: list[str]) -> tuple[list[str], list[str]]:
    """(source-dir problems, package-declaration problems)."""
    text = read(root, PACKAGE)
    if not text:
        return [f"{PACKAGE} is missing"], []
    directories: set[str] = set()
    for path in paths:
        parts = path.split("/")
        for index in range(1, len(parts)):
            directories.add("/".join(parts[:index]))
    problems: list[str] = []
    for header, entries in stanza_source_dirs(text):
        for entry in entries:
            if entry not in directories:
                problems.append(f"{PACKAGE}: {header}: hs-source-dirs {entry!r} resolves to nothing")
    for match in MAIN_IS.finditer(text):
        name = match.group(1)
        if not any(path.endswith("/" + name) or path == name for path in paths):
            problems.append(f"{PACKAGE}: main-is {name!r} resolves to nothing")

    declarations = sorted(path for path in paths if path.endswith(".cabal"))
    stray = [path for path in declarations if path not in ADMITTED_PACKAGES]
    package_problems = [
        f"{path} is a package declaration outside the units section 2.1 admits apart"
        for path in stray
    ]
    project = read(root, PROJECT)
    for line in project.splitlines():
        candidate = line.strip().lstrip("./")
        if candidate.endswith(".cabal") and candidate not in ADMITTED_PACKAGES:
            package_problems.append(f"{PROJECT} names the package {candidate}")
    return problems, package_problems


def check_registry(root: Path, paths: list[str]) -> tuple[list[str], list[str], list[str]]:
    """(bodies uncovered, flags uncovered, mutations nothing can reach)."""
    registry = root / "test" / "mutant" / "registry.tsv"
    try:
        rows = mutant_registry.rows(registry)
    except mutant_registry.RegistryError as error:
        return [str(error)], [], []
    bodies = mutant_registry.bodies(registry)
    flags = mutant_registry.flags(registry)

    committed = [
        path for path in paths
        if path.startswith("test/mutant/") and path != "test/mutant/registry.tsv"
    ]
    uncovered = [f"{path} is a mutant body no registry row names" for path in committed
                 if path not in bodies]
    missing = [f"the registry names the body {path}, which the tree does not have"
               for path in bodies if path not in set(paths)]

    declared = set(re.findall(r"^flag (\S+)", read(root, PACKAGE), re.M))
    flag_problems = [
        f"{flag} is a `*-mutant` build flag no registry row names"
        for flag in sorted(declared) if flag.endswith("-mutant") and flag not in flags
    ]
    flag_problems += [
        f"the registry names the flag {flag}, which {PACKAGE} does not declare"
        for flag in sorted(flags) if flag not in declared
    ]

    unreachable = [
        f"{row['capability']}/{row['mutant']} has neither a committed body nor a build flag"
        for row in rows
        if row["body"] == mutant_registry.ABSENT and row["flag"] == mutant_registry.ABSENT
    ]
    return uncovered + missing, flag_problems, unreachable


def check_partition(root: Path, paths: list[str], tree) -> tuple[list[str], list[str], list[str]]:
    """(r13 findings, r15 findings, allowlist rows this phase should have retired)."""
    thirteen = artifact_policy.Report()
    artifact_policy.audit_target_tree(thirteen, paths, tree)

    fifteen = artifact_policy.Report()
    rules = [] if root != ROOT else artifact_policy.ignore_rules()
    artifact_policy.audit_phase_ordinals(fifteen, paths, read(root, PACKAGE), rules)
    corpora = artifact_policy.load_corpora()
    artifact_policy.apply_corpora(fifteen, corpora)

    deferred = [
        line for line in read(root, ALLOWLIST).splitlines()
        if line.startswith("r13\t") or line.startswith("r15\t")
    ]
    return (
        [finding.render() for finding in thirteen.findings],
        [finding.render() for finding in fifteen.findings],
        [f"{ALLOWLIST} still defers {line.split(chr(9))[0]} for {line.split(chr(9))[1]}"
         for line in deferred],
    )


def decide(root: Path, paths: list[str], tree) -> dict[str, list[str]]:
    """Every check, over one enumeration, as check id -> problems."""
    parse, destinations, licenses = check_map(root, tree)
    source_dirs, packages = check_resolution(root, paths)
    bodies, flags, unreachable = check_registry(root, paths)
    thirteen, fifteen, allowlist = check_partition(root, paths, tree)
    reported = {finding.split(":")[1].strip() for finding in thirteen if ":" in finding}
    rejected = {line.split("destination ")[1].split(" is outside")[0].strip("'")
                for line in destinations if "destination " in line}
    return {
        "collision-free-tree": check_collision(paths),
        "no-empty-authored-directory": check_empty_directories(root),
        "map-parses": parse,
        "map-destination-admitted": destinations,
        "map-license-cited": licenses,
        "relocation-complete": check_relocation(root, paths, reported, rejected),
        "no-dangling-reference": check_reference(root, paths),
        "source-dirs-resolve": source_dirs,
        "one-package-declaration": packages,
        "registry-covers-bodies": bodies,
        "registry-covers-flags": flags,
        "registry-no-unreachable": unreachable,
        "target-tree-clean": thirteen,
        "de-phased-naming": fifteen,
        "allowlist-shrunk": allowlist,
    }


# ---------------------------------------------------------------------------
# the seeded mutants
# ---------------------------------------------------------------------------


def load_mutants(root: Path) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    directory = root / MUTANT_DIR
    if not directory.is_dir():
        raise GateFailure(f"the committed mutants under {MUTANT_DIR} are missing")
    for path in sorted(directory.glob("*.mutant")):
        record: dict[str, str] = {"name": path.stem, "statement": ""}
        for line in path.read_text(encoding="utf-8").splitlines():
            key, _, value = line.partition("=")
            if key == "statement":
                record["statement"] = (record["statement"] + " " + value).strip()
            elif key:
                record[key] = value
        for required in ("check", "operator", "mutation"):
            if required not in record:
                raise GateFailure(f"{path.name}: no {required} field")
        out.append(record)
    if not out:
        raise GateFailure(f"{MUTANT_DIR} carries no mutant")
    return out


def materialize(paths: list[str]) -> Path:
    """A scratch copy of the source snapshot, beneath the contained build root."""
    base = SCRATCH / "base"
    if base.exists():
        shutil.rmtree(base)
    for relative in paths:
        source = ROOT / relative
        if not source.is_file():
            continue
        target = base / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    return base


def apply(record: dict[str, str], root: Path, paths: list[str]) -> list[str]:
    """Apply one mutation to a scratch tree, returning its enumeration.

    Fields are separated by ` | ` and never by `:`, because half the payloads are cabal
    fields and repository paths that carry a colon of their own.
    """
    fields = [field.replace("\\n", "\n") for field in record["mutation"].split(" | ")]
    verb, arguments = fields[0].strip(), fields[1:]
    if verb == "create":
        relative, body = arguments
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body + "\n", encoding="utf-8")
        return sorted([*paths, relative])
    if verb == "append":
        relative, line = arguments
        target = root / relative
        target.write_text(target.read_text(encoding="utf-8") + line + "\n", encoding="utf-8")
        return paths
    if verb == "rename":
        old, new = arguments
        (root / new).parent.mkdir(parents=True, exist_ok=True)
        (root / old).rename(root / new)
        return sorted([path for path in paths if path != old] + [new])
    if verb == "replace":
        relative, old, new = arguments
        target = root / relative
        text = target.read_text(encoding="utf-8")
        if old not in text:
            raise GateFailure(f"{record['name']}: {relative} does not contain {old!r}")
        target.write_text(text.replace(old, new, 1), encoding="utf-8")
        return paths
    if verb == "mkdir":
        (root / arguments[0]).mkdir(parents=True, exist_ok=True)
        return paths
    if verb == "enumerate":
        return sorted([*paths, arguments[0]])
    raise GateFailure(f"{record['name']}: unknown mutation verb {verb!r}")


def mutant_side(paths: list[str], tree, clean: dict[str, list[str]]) -> tuple[bool, list[dict[str, str]]]:
    print("\nmutant side — six seeded defects, each red at its own check\n")
    ok = True
    outcomes: list[dict[str, str]] = []
    records = load_mutants(ROOT)
    base = materialize(paths)
    for record in records:
        scratch = SCRATCH / record["name"]
        if scratch.exists():
            shutil.rmtree(scratch)
        shutil.copytree(base, scratch)
        try:
            mutated = apply(record, scratch, paths)
            verdict = decide(scratch, mutated, tree)
        except GateFailure as error:
            print(f"  FAIL  {record['name']:26} could not be applied: {error}")
            outcomes.append({"name": record["name"], "status": "unapplied"})
            ok = False
            continue
        finally:
            shutil.rmtree(scratch, ignore_errors=True)

        target = record["check"]
        reddened = sorted(check for check, problems in verdict.items() if problems)
        expected = sorted(set(reddened) & {target})
        collateral = [check for check in reddened if check != target and not clean[check]]
        if target not in reddened:
            print(f"  FAIL  {record['name']:26} did not redden {target}")
            outcomes.append({"name": record["name"], "status": "survived"})
            ok = False
        elif collateral:
            print(f"  FAIL  {record['name']:26} also reddened {', '.join(collateral)}")
            outcomes.append({"name": record["name"], "status": "imprecise"})
            ok = False
        else:
            print(f"  ok    {record['name']:26} reddens {target} and no other check")
            outcomes.append({"name": record["name"], "status": "red"})
        del expected
    shutil.rmtree(base, ignore_errors=True)
    return ok, outcomes


# ---------------------------------------------------------------------------
# reporting
# ---------------------------------------------------------------------------


SIDE_CHECKS = {
    "collision": ("collision-free-tree", "no-empty-authored-directory"),
    "map": ("map-parses", "map-destination-admitted", "map-license-cited"),
    "relocation": ("relocation-complete",),
    "reference": ("no-dangling-reference",),
    "resolution": ("source-dirs-resolve", "one-package-declaration"),
    "registry": ("registry-covers-bodies", "registry-covers-flags", "registry-no-unreachable"),
    "partition": ("target-tree-clean", "de-phased-naming", "allowlist-shrunk"),
}

SIDE_HEADLINE = {
    "collision": "no case-collision pair, and no directory holding nothing",
    "map": "the authored relocation map against the section 2 target tree",
    "relocation": "every planned move happened, and nothing was left behind",
    "reference": "no tracked file names a departed path",
    "resolution": "the one authored package resolves at the new names",
    "registry": "one mutant registry over every body and every build flag",
    "partition": "rules r13 and r15, and what the allowlist still defers",
}


def report_side(name: str, verdict: dict[str, list[str]]) -> bool:
    print(f"\n{name} side — {SIDE_HEADLINE[name]}\n")
    ok = True
    for check in SIDE_CHECKS[name]:
        problems = verdict[check]
        if problems:
            ok = False
            for problem in problems[:12]:
                print(f"  FAIL  {check:26} {problem}")
            if len(problems) > 12:
                print(f"  FAIL  {check:26} … and {len(problems) - 12} more")
        else:
            print(f"  ok    {check}")
    return ok


def role_nouns(paths: list[str]) -> list[str]:
    return sorted({path.split("/")[1] for path in paths
                   if path.startswith("test/") and "/" in path[5:]})


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=2, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    tree = artifact_policy.load_target_tree()
    if not tree.directories:
        print("repository-conformance-gate: FAIL: cannot parse the section 2 target tree",
              file=sys.stderr)
        return 1

    paths = enumerate_snapshot()
    print(f"\nenumerated {len(paths)} source-snapshot path(s)")
    print(f"  test/ second level: {', '.join(role_nouns(paths))}")
    if role_nouns(paths) != sorted(ROLE_NOUNS):
        print(f"  note  the seven role nouns are {', '.join(sorted(ROLE_NOUNS))}")

    try:
        verdict = decide(ROOT, paths, tree)
    except GateFailure as error:
        print(f"repository-conformance-gate: FAIL: {error}", file=sys.stderr)
        return 1

    for name in SIDE_CHECKS:
        results[name] = report_side(name, verdict)

    try:
        results["mutant"], outcomes = mutant_side(paths, tree, verdict)
    except GateFailure as error:
        print(f"repository-conformance-gate: FAIL: {error}", file=sys.stderr)
        return 1

    implemented = {
        "checks": set(CHECKS),
        "mutants": {record["name"] for record in load_mutants(ROOT)},
        "roles": set(role_nouns(paths)),
    }
    rows = {check: ("clean" if not problems else "findings")
            for check, problems in verdict.items()}
    rows.update({f"mutant:{outcome['name']}": outcome["status"] for outcome in outcomes})

    evidence = {}
    for surface, check in SURFACE_EVIDENCE.items():
        evidence[surface] = (check, "clean" if check in verdict else "red")
    for outcome in outcomes:
        evidence[f"mutant.{outcome['name']}"] = (f"mutant:{outcome['name']}", "red")

    layers = {
        "Decision": "tested" if all(results[name] for name in SIDE_CHECKS) else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented=implemented,
        rows=rows,
        evidence=evidence,
        layers=layers,
        toolchain={},
        dependencies={"amoebius": "one authored package"},
        mutants=outcomes,
        observations={"relocation_map": "sha256:" + artifact_policy.digest(str(ROOT / RELOCATION_MAP))},
    )


# Each ledger row is decided by a recorded check outcome, never by an assertion.
SURFACE_EVIDENCE = {
    "layout.case_collision": "collision-free-tree",
    "layout.no_empty_directory": "no-empty-authored-directory",
    "layout.map_parses": "map-parses",
    "layout.map_destination": "map-destination-admitted",
    "layout.map_license": "map-license-cited",
    "layout.relocation_complete": "relocation-complete",
    "layout.no_dangling_reference": "no-dangling-reference",
    "package.source_dirs_resolve": "source-dirs-resolve",
    "package.one_declaration": "one-package-declaration",
    "mutant_registry.bodies": "registry-covers-bodies",
    "mutant_registry.flags": "registry-covers-flags",
    "mutant_registry.reachable": "registry-no-unreachable",
    "partition.target_tree": "target-tree-clean",
    "partition.de_phased_naming": "de-phased-naming",
    "partition.allowlist_shrunk": "allowlist-shrunk",
}


if __name__ == "__main__":
    raise SystemExit(main())
