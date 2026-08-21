#!/usr/bin/env python3
"""The illegal-state covering: the declared taxonomy, its cells, and what occupies them.

`documentation_standards.md` section 16 makes the catalogue a **covering over a declared
taxonomy** rather than a list: every cell of the product of the declared axes either holds
an entry or carries a one-line statement of why no illegal state lives there, and an
unjustified empty cell is a defect. Section S clause 16 makes that a gate postcondition.

One implementation serves both readers. The grid is *generated* — widening an axis reports
its own new empty cells rather than waiting to be noticed — while the entries, the
admissibility relation, and the justifications stay authored, because each is an
independent expectation and deriving one from the thing it checks would turn a test into a
description.

    python3 tools/covering_grid.py            # report occupancy and any unjustified cell
    python3 tools/covering_grid.py --emit     # also write the grid to .build/docs/

**Occupancy is read from each entry's `**Cells:**` line, and that is the whole point.**
Until 2026-08-20 it was credited as the *product* of every foreclosure layer the entry's
prose named with every locus it named, because the pairing lived in sentences no parser
could split. Fifty-eight of the ninety-seven entries name more than one of each, so the
grid credited 143 cells where the entries assert 64: occupancy was an upper bound, the
unjustified count a floor, and eleven cells were left owing a reason nobody could write
because the cell was *unknown* rather than empty. Pairing a layer to a locus in the entry
replaces that estimate with a measurement.

A cell is foreclosed three ways, and they are reported apart. **Inadmissible** cells hold
no illegal state because the layer cannot be observed at that locus at all — the relation
is authored in the catalogue router and read here. **Justified** cells are admissible and
empty for a reason the router states. **Unjustified** cells are the defect.

The limit worth stating: the check that binds a cell to prose runs cells→text, requiring
every layer and locus a cell names to appear in the entry. The reverse — that no locus the
prose asserts is missing from the cells — is not mechanical, because an entry may name a
locus in order to *disclaim* it (3.23 does exactly that for `live-effect`). The cells line
is therefore authored, and the registry cross-check below is what keeps it honest.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRID = ROOT / ".build" / "docs" / "covering.tsv"
TEMP_ROOT = ROOT / ".build" / "tmp" / "covering-grid"


def catalogue(root: Path = ROOT) -> Path:
    return root / "documents" / "illegal_state"


def router(root: Path = ROOT) -> Path:
    return catalogue(root) / "README.md"

ENTRY_RE = re.compile(r"^### (3\.\d+) (.*)$", re.M)
FAMILY_RE = re.compile(r"\*\*Case-family:\*\*\s*`([^`]+)`")
CELLS_RE = re.compile(r"^\*\*Cells:\*\*\s*(.+)$", re.M)
PAIR_RE = re.compile(r"`([a-z-]+)`×`([a-z-]+)`")
JUSTIFY_RE = re.compile(r"^\|\s*`([^`]+)`\s*×\s*`([^`]+)`\s*×\s*`([^`]+)`\s*\|\s*(.+?)\s*\|\s*$", re.M)
ADMIT_RE = re.compile(r"^\|\s*`([a-z-]+)`\s*\|\s*((?:`[a-z-]+`(?:\s*·\s*)?)+)\s*\|\s*(.+?)\s*\|\s*$", re.M)

# The registry the Phase-0 surface join enumerates. A check absent from here is invisible
# to that join, which is the same failure the join exists to stop.
CHECKS = {
    "c1": "covering cells: every entry pairs each foreclosure it makes to one locus",
    "c2": "covering admissibility: no pairing the layer/locus relation forbids",
    "c3": "covering completeness: every admissible empty cell carries a reason",
    "c4": "covering teeth: each seeded defect turns the covering red",
}


def axes(root: Path = ROOT) -> tuple[list[str], list[str], list[str]]:
    """The three closed axes, read from the router that declares them.

    All three member lists are quoted in the router's own bullets. The family axis is read
    from the declaration and never from the entries: deriving it from the catalogue would
    mean a family nothing declares produces no cells, so the grid could never report a
    missing domain -- which is the one failure the covering exists to detect. It would also
    be the same defect the covering obligation names, a check derived from its own subject.
    """
    text = router(root).read_text(encoding="utf-8")
    def members(after: str) -> list[str]:
        # A bullet ends at the next bullet or the next blank line, whichever comes first.
        # Bounding only on the blank line reads the following bullet's members as this
        # one's, which silently multiplies the cell set instead of failing. The family
        # bullet carries explanatory paragraphs after its member list, so it is bounded on
        # the first blank line and its members are all on the leading lines.
        i = text.index(after)
        rest = text[i + len(after):]
        ends = [x for x in (rest.find("\n- **"), rest.find("\n\n")) if x != -1]
        chunk = rest[:min(ends)] if ends else rest
        return [m.group(1) for m in re.finditer(r"`([a-z-]+)`", chunk)]
    layers = members("- **Foreclosure layer**")
    loci = members("- **Validation locus**")
    declared = members("- **Case family**")
    # An entry naming a family the router does not declare is a typo, not a new member,
    # and it is reported rather than silently widening the grid.
    undeclared = sorted(families(root) - set(declared))
    if undeclared:
        print(f"covering_grid: entries name undeclared families: {', '.join(undeclared)}",
              file=sys.stderr)
    return layers, loci, sorted(declared)


def admissible(root: Path = ROOT) -> dict[str, set[str]]:
    """Layer -> the loci that can observe it, read from the router's authored relation.

    The two axes classify different questions, but their product is not inhabited: a locus
    downstream of the check that forecloses a state never sees that state, and a locus
    upstream of the effect a residue is about cannot settle it. Eleven of the eighteen
    pairs are empty for that structural reason rather than for want of an entry, and the
    grid reports them as `inadmissible` rather than asking the router for fourteen
    identical sentences apiece.
    """
    text = router(root).read_text(encoding="utf-8")
    start = text.index("### Which locus can observe which layer")
    end = text.index("###", start + 4)
    return {m.group(1): set(re.findall(r"`([a-z-]+)`", m.group(2)))
            for m in ADMIT_RE.finditer(text[start:end])}


def entries(root: Path = ROOT) -> list[tuple[str, str, str, list[tuple[str, str]], str]]:
    """(id, title, family, authored cells, body) for every catalogue entry."""
    out = []
    for path in sorted(catalogue(root).glob("illegal_state_*.md")):
        if path.name in ("illegal_state_catalog.md", "illegal_state_techniques.md"):
            continue
        text = path.read_text(encoding="utf-8")
        found = list(ENTRY_RE.finditer(text))
        for i, m in enumerate(found):
            end = found[i + 1].start() if i + 1 < len(found) else len(text)
            body = text[m.start():end]
            fam = FAMILY_RE.search(body)
            cells = CELLS_RE.search(body)
            out.append((m.group(1), m.group(2), fam.group(1) if fam else "",
                        PAIR_RE.findall(cells.group(1)) if cells else [], body))
    return out


def families(root: Path = ROOT) -> set[str]:
    return {e[2] for e in entries(root) if e[2]}


def occupancy(root: Path = ROOT) -> set[tuple[str, str, str]]:
    """Every cell at least one entry's authored `Cells:` line places it in."""
    return {(layer, locus, fam)
            for _id, _title, fam, cells, _body in entries(root)
            for layer, locus in cells}


def entry_violations(root: Path = ROOT) -> list[tuple[str, str]]:
    """Every way an entry's authored cells can be wrong, as (entry, message)."""
    layers, loci, _fams = axes(root)
    admit = admissible(root)
    problems = []
    for entry, _title, fam, cells, body in entries(root):
        if not cells:
            problems.append((entry, "no **Cells:** line, so it occupies nothing"))
            continue
        if not fam:
            problems.append((entry, "no **Case-family:** tag"))
        # The cells line is part of the section, and it names its own layers and loci. A
        # containment test that reads it proves only that the line equals itself, so the
        # prose it is checked against is the section with that line removed.
        prose = CELLS_RE.sub("", body)
        for layer, locus in cells:
            if layer not in layers:
                problems.append((entry, f"unknown foreclosure layer {layer}"))
                continue
            if locus not in loci:
                problems.append((entry, f"unknown validation locus {locus}"))
                continue
            if locus not in admit.get(layer, set()):
                problems.append((entry, f"{layer}×{locus} is not an admissible pair"))
            if layer not in prose:
                problems.append((entry, f"cell names {layer}, which the entry never states"))
            if f"`{locus}`" not in prose:
                problems.append((entry, f"cell names {locus}, which the entry never states"))
    return problems


def justifications(root: Path = ROOT) -> list[tuple[str, str, str, str]]:
    """Authored (layer, locus, family, reason) rows; `*` is a wildcard over that axis."""
    return [(m.group(1), m.group(2), m.group(3), m.group(4))
            for m in JUSTIFY_RE.finditer(router(root).read_text(encoding="utf-8"))]


def covered(cell: tuple[str, str, str], rows: list[tuple[str, str, str, str]]) -> str | None:
    for layer, locus, fam, reason in rows:
        if ((layer in ("*", cell[0])) and (locus in ("*", cell[1])) and (fam in ("*", cell[2]))):
            return reason
    return None


def state(cell: tuple[str, str, str], occ, admit, rows) -> tuple[str, str]:
    if cell in occ:
        return "occupied", "—"
    if cell[1] not in admit.get(cell[0], set()):
        return "inadmissible", "the layer cannot be observed at this locus"
    why = covered(cell, rows)
    return ("justified", why) if why else ("UNJUSTIFIED", "—")


def unjustified(root: Path = ROOT) -> list[tuple[str, str, str]]:
    """Empty admissible cells no authored justification covers — section 16's defect."""
    layers, loci, fams = axes(root)
    occ, admit, rows = occupancy(root), admissible(root), justifications(root)
    return [(a, b, c) for a in layers for b in loci for c in fams
            if state((a, b, c), occ, admit, rows)[0] == "UNJUSTIFIED"]


def census(root: Path = ROOT) -> dict[str, int]:
    """How many cells each state holds — the covering's whole result in four numbers."""
    layers, loci, fams = axes(root)
    occ, admit, rows = occupancy(root), admissible(root), justifications(root)
    counts = {"occupied": 0, "inadmissible": 0, "justified": 0, "UNJUSTIFIED": 0}
    for a in layers:
        for b in loci:
            for c in fams:
                counts[state((a, b, c), occ, admit, rows)[0]] += 1
    return counts


def emit() -> Path:
    layers, loci, fams = axes()
    occ, admit, rows = occupancy(), admissible(), justifications()
    lines = ["layer\tlocus\tfamily\tstate\tdetail"]
    for a in layers:
        for b in loci:
            for c in fams:
                kind, detail = state((a, b, c), occ, admit, rows)
                lines.append(f"{a}\t{b}\t{c}\t{kind}\t{detail}")
    GRID.parent.mkdir(parents=True, exist_ok=True)
    GRID.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return GRID


# Each seeded defect below is one way the covering can be wrong, paired with the state it
# must produce. A covering that reports 0 unjustified cells says nothing until a cell that
# *should* be unjustified turns it red, and the same holds for every other authored input:
# the entries' pairings, the admissibility relation, and the justification rows.
MUTANTS = {
    "cells_line_removed": "an entry that declares no cells occupies nothing",
    "cell_pair_inadmissible": "a pairing the layer/locus relation forbids",
    "cell_layer_unknown": "a pairing naming a layer outside the closed axis",
    "cell_absent_from_prose": "a pairing the entry's own text never states",
    "justification_removed": "an empty admissible cell whose reason was deleted",
    "family_axis_widened": "a declared family no entry reaches",
}


def selftest() -> list[str]:
    """Seed each defect into a scratch copy and require the reported state to change."""
    failures = []
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="seed-", dir=TEMP_ROOT) as directory:
        scratch = Path(directory) / "repo"
        (scratch / "documents").mkdir(parents=True)
        shutil.copytree(catalogue(), catalogue(scratch))
        entry_file = catalogue(scratch) / "illegal_state_storage.md"
        route = router(scratch)
        clean_entry, clean_route = entry_file.read_text(encoding="utf-8"), route.read_text(encoding="utf-8")
        if entry_violations(scratch) or unjustified(scratch):
            return ["the unmutated copy is not clean, so nothing below discriminates"]

        def restore() -> None:
            entry_file.write_text(clean_entry, encoding="utf-8")
            route.write_text(clean_route, encoding="utf-8")

        def expect(name: str, condition: bool) -> None:
            if not condition:
                failures.append(f"{name}: the seeded defect did not turn the covering red")
            restore()

        line = next(v for v in clean_entry.splitlines() if v.startswith("**Cells:**"))
        entry_file.write_text(clean_entry.replace(line + "\n\n", "", 1), encoding="utf-8")
        expect("cells_line_removed", bool(entry_violations(scratch)))

        entry_file.write_text(
            clean_entry.replace(line, "**Cells:** `type-foreclosed`×`live-effect`", 1), encoding="utf-8")
        expect("cell_pair_inadmissible", bool(entry_violations(scratch)))

        entry_file.write_text(
            clean_entry.replace(line, "**Cells:** `not-a-layer`×`dhall-typecheck`", 1), encoding="utf-8")
        expect("cell_layer_unknown", bool(entry_violations(scratch)))

        entry_file.write_text(
            clean_entry.replace(line, "**Cells:** `decode-foreclosed`×`provision-seal`", 1), encoding="utf-8")
        expect("cell_absent_from_prose", bool(entry_violations(scratch)))

        victim = next(v for v in clean_route.splitlines()
                      if v.startswith("| `*` × `rendered-artifact-oracle` × `storage`"))
        route.write_text(clean_route.replace(victim + "\n", "", 1), encoding="utf-8")
        expect("justification_removed", bool(unjustified(scratch)))

        route.write_text(clean_route.replace("`ui`. It answers", "`ui` · `nothing-uses-this`. It answers", 1),
                         encoding="utf-8")
        expect("family_axis_widened", bool(unjustified(scratch)))
    return failures


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--emit", action="store_true", help="write the grid to .build/docs/")
    ap.add_argument("--selftest", action="store_true", help="prove each seeded defect turns it red")
    args = ap.parse_args(argv)
    layers, loci, fams = axes()
    total = len(layers) * len(loci) * len(fams)
    counts = census()
    bad = unjustified()
    broken = entry_violations()
    seeded = selftest() if args.selftest else []
    if args.emit:
        print(f"covering: grid written to {emit().relative_to(ROOT)}")
    print(f"covering: {len(entries())} entries, {total} cells — "
          + ", ".join(f"{v} {k}" for k, v in counts.items()))
    for entry, message in broken[:20]:
        print(f"  BAD CELL     {entry}: {message}", file=sys.stderr)
    for cell in bad[:20]:
        print(f"  UNJUSTIFIED  {cell[0]} × {cell[1]} × {cell[2]}", file=sys.stderr)
    for message in seeded:
        print(f"  BLIND SPOT   {message}", file=sys.stderr)
    if args.selftest and not seeded:
        print(f"covering: {len(MUTANTS)} seeded defects each turned the covering red")
    if bad or broken or seeded:
        print(f"covering: FAIL ({len(bad)} unjustified cell(s), "
              f"{len(broken)} malformed entry cell(s), {len(seeded)} blind spot(s))", file=sys.stderr)
        return 1
    print("covering: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
