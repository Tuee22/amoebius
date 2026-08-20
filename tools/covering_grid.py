#!/usr/bin/env python3
"""The illegal-state covering: the declared taxonomy, its cells, and what occupies them.

`documentation_standards.md` section 16 makes the catalogue a **covering over a declared
taxonomy** rather than a list: every cell of the product of the declared axes either holds
an entry or carries a one-line statement of why no illegal state lives there, and an
unjustified empty cell is a defect. Section S clause 16 makes that a gate postcondition.

One implementation serves both readers. The grid is *generated* — widening an axis reports
its own new empty cells rather than waiting to be noticed — while the entries and the
justifications stay authored, because each is an independent expectation and deriving one
from the thing it checks would turn a test into a description.

    python3 tools/covering_grid.py            # report occupancy and any unjustified cell
    python3 tools/covering_grid.py --emit     # also write the grid to .build/docs/

A justification may cover a whole row or column where the reason is structural rather than
particular: a locus a layer cannot reach names that once, not once per family.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "documents" / "illegal_state"
ROUTER = CATALOGUE / "README.md"
GRID = ROOT / ".build" / "docs" / "covering.tsv"

ENTRY_RE = re.compile(r"^### (3\.\d+) (.*)$", re.M)
FAMILY_RE = re.compile(r"\*\*Case-family:\*\*\s*`([^`]+)`")
JUSTIFY_RE = re.compile(r"^\|\s*`([^`]+)`\s*×\s*`([^`]+)`\s*×\s*`([^`]+)`\s*\|\s*(.+?)\s*\|\s*$", re.M)


def axes() -> tuple[list[str], list[str], list[str]]:
    """The three closed axes, read from the router that declares them.

    All three member lists are quoted in the router's own bullets. The family axis is read
    from the declaration and never from the entries: deriving it from the catalogue would
    mean a family nothing declares produces no cells, so the grid could never report a
    missing domain -- which is the one failure the covering exists to detect. It would also
    be the same defect the covering obligation names, a check derived from its own subject.
    """
    text = ROUTER.read_text(encoding="utf-8")
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
    undeclared = sorted(families() - set(declared))
    if undeclared:
        print(f"covering_grid: entries name undeclared families: {', '.join(undeclared)}",
              file=sys.stderr)
    return layers, loci, sorted(declared)


def entries() -> list[tuple[str, str, set[str], set[str], str]]:
    """(id, title, layers, loci, family) for every catalogue entry."""
    layers = ["type-foreclosed", "decode-foreclosed", "runtime-checked"]
    loci = ["dhall-typecheck", "gadt-decode", "extension-astcheck", "provision-seal",
            "rendered-artifact-oracle", "live-effect"]
    out = []
    for path in sorted(CATALOGUE.glob("illegal_state_*.md")):
        if path.name in ("illegal_state_catalog.md", "illegal_state_techniques.md"):
            continue
        text = path.read_text(encoding="utf-8")
        found = list(ENTRY_RE.finditer(text))
        for i, m in enumerate(found):
            end = found[i + 1].start() if i + 1 < len(found) else len(text)
            body = text[m.start():end]
            fam = FAMILY_RE.search(body)
            out.append((m.group(1), m.group(2),
                        {x for x in layers if x in body},
                        {x for x in loci if f"`{x}`" in body},
                        fam.group(1) if fam else ""))
    return out


def families() -> set[str]:
    return {e[4] for e in entries() if e[4]}


def occupancy() -> set[tuple[str, str, str]]:
    """Every cell at least one entry occupies.

    **This over-credits, and the direction matters.** An entry naming several layers and
    several loci is credited with the product of them, because section 16 defines the cell
    set as the product of the axes and the entry's prose pairs a layer with a locus in
    sentences no parser can reliably split. Fifty-eight of the ninety-seven entries name
    more than one of each, so some credited cells are pairings the entry never asserts.

    The consequence is that occupancy is an upper bound and the unjustified count is a
    **floor**: the covering is at least as incomplete as this reports, never less. That is
    the wrong direction for a defect count to be wrong in, and it is stated here rather
    than left for a reader to infer. Closing it needs the entries to pair a layer with a
    locus explicitly, which is authoring work on the catalogue, not a better regex.
    """
    cells = set()
    for _id, _title, layers, loci, fam in entries():
        for layer in layers:
            for locus in loci:
                cells.add((layer, locus, fam))
    return cells


def justifications() -> list[tuple[str, str, str, str]]:
    """Authored (layer, locus, family, reason) rows; `*` is a wildcard over that axis."""
    return [(m.group(1), m.group(2), m.group(3), m.group(4))
            for m in JUSTIFY_RE.finditer(ROUTER.read_text(encoding="utf-8"))]


def covered(cell: tuple[str, str, str], rows: list[tuple[str, str, str, str]]) -> str | None:
    for layer, locus, fam, reason in rows:
        if ((layer in ("*", cell[0])) and (locus in ("*", cell[1])) and (fam in ("*", cell[2]))):
            return reason
    return None


def unjustified() -> list[tuple[str, str, str]]:
    """Empty cells no authored justification covers — the defects section 16 names."""
    layers, loci, fams = axes()
    occ, rows = occupancy(), justifications()
    return [(a, b, c) for a in layers for b in loci for c in fams
            if (a, b, c) not in occ and covered((a, b, c), rows) is None]


def emit() -> Path:
    layers, loci, fams = axes()
    occ, rows = occupancy(), justifications()
    lines = ["layer\tlocus\tfamily\tstate\tdetail"]
    for a in layers:
        for b in loci:
            for c in fams:
                if (a, b, c) in occ:
                    lines.append(f"{a}\t{b}\t{c}\toccupied\t—")
                else:
                    why = covered((a, b, c), rows)
                    lines.append(f"{a}\t{b}\t{c}\t"
                                 + ("justified\t" + why if why else "UNJUSTIFIED\t—"))
    GRID.parent.mkdir(parents=True, exist_ok=True)
    GRID.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return GRID


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--emit", action="store_true", help="write the grid to .build/docs/")
    args = ap.parse_args(argv)
    layers, loci, fams = axes()
    occ = occupancy()
    total = len(layers) * len(loci) * len(fams)
    bad = unjustified()
    if args.emit:
        print(f"covering: grid written to {emit().relative_to(ROOT)}")
    print(f"covering: {len(entries())} entries, {len(occ)} of {total} cells occupied, "
          f"{total - len(occ)} empty, {len(bad)} unjustified")
    for cell in bad[:20]:
        print(f"  UNJUSTIFIED  {cell[0]} × {cell[1]} × {cell[2]}", file=sys.stderr)
    if bad:
        print(f"covering: FAIL ({len(bad)} unjustified cell(s))", file=sys.stderr)
        return 1
    print("covering: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
