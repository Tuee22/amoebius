#!/usr/bin/env python3
"""The amoebius documentation lint — the Phase 0 acceptance gate.

A pure text/link checker over the governed documentation tree. Python 3 standard
library only: no third-party packages, and no dependency on the amoebius binary,
which does not exist until the pre-cluster implementation band (Phase 2+).

Run two-sided:

  clean side    python3 tools/doc_lint.py
  fixture side  python3 tools/doc_lint.py --root tools/doc_lint_corpus/<fixture>

Every fixture under tools/doc_lint_corpus/ must exit non-zero naming its own
seeded check. A checker that keys on fixture identity rather than on the seeded
defect cannot pass both sides.

Checks (a)-(h) are specified by DEVELOPMENT_PLAN/phase_00_documentation_suite.md
Sprint 0.5. Checks (i)-(n) extend it with defect classes a full review of the
suite found unenforced.

Exit status: 0 clean, 1 violations found, 2 usage error.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict

# --------------------------------------------------------------------------
# Check registry
# --------------------------------------------------------------------------

CHECKS = {
    "a1": "header metadata: Status drawn from the enum",
    "a2": "header metadata: Supersedes present",
    "a3": "header metadata: Referenced by present",
    "a4": "header metadata: Generated sections keys match in-body markers",
    "a5": "header metadata: one-sentence Purpose present",
    "b1": "anchored relative link resolves under the section-4 slug rule",
    "b2": "no bare section reference outside the five sanctioned forms",
    "c": "Referenced by reconciled in both directions from the link graph",
    "d": "near-duplicate normative content between two governed documents",
    "e": "status consistency: tracker marker equals the phase doc's Phase Status",
    "f": "gate integrity: gate names fixtures, a mutant, and an independent oracle",
    "g1": "catalog integrity: every entry carries a Validation-locus field",
    "g2": "catalog integrity: entry numbering contiguous, no gaps or duplicates",
    "g3": "catalog integrity: every index bullet anchor resolves",
    "g4": "catalog integrity: every entry has a technique-matrix row",
    "h": "plan back-link: every engineering doctrine doc links to the tracker",
    "i": "a section ref inside a cross-file link must resolve into that file",
    "j": "sprint and gate-module references must name their owning phase",
    "k": "the product name is lowercase amoebius outside titles and code",
    "l": "honesty vocabulary: no coined tokens, no proven at a tested layer",
    "m": "a type is declared in exactly one doctrine document",
    "n": "a link label must not name a different file than its target",
}

LEGAL_STATUS = {"Authoritative source", "Reference only", "Deprecated"}
HDR_FIELDS = ["Status", "Supersedes", "Referenced by", "Generated sections"]

# Files that carry no header block by design.
EXEMPT_BASENAMES = {"CLAUDE.md", "AGENTS.md"}

# Sanctioned honesty tokens. Anything else hyphenated onto "proven" is coined.
# A hyphenated "proven" token that claims proof at a layer the three-token grammar
# fixes as *tested*. Scoped tokens naming a type/model layer (decode-proven,
# proven-for-the-model, prodbox-proven) are the grammar working as intended.
OVERCLAIMING_TOKENS = {
    "live-proven",
    "runtime-proven",
    "production-proven",
    "prod-proven",
    "chaos-proven",
    "drill-proven",
    "e2e-proven",
    "cluster-proven",
    "integration-proven",
}

# The ledger artifact's own name; not a proof claim.
LEDGER_NAME_RE = re.compile(r"proven\s*/\s*tested\s*/\s*assumed|proven,\s*tested,\s*assumed", re.I)

# A bare section ref naming an external sibling project is sanctioned prose.
EXTERNAL_PROJECT_MARKERS = (
    "config_doctrine",
    "vault_doctrine",
    "chaos_hardening_doctrine",
    "determinism_contract",
    "prodbox",
    "hostbootstrap",
    "infernix",
    "jitml",
    "supernova",
)


class Violation:
    __slots__ = ("check", "path", "line", "message")

    def __init__(self, check, path, line, message):
        self.check = check
        self.path = path
        self.line = line
        self.message = message

    def render(self):
        loc = f"{self.path}:{self.line}" if self.line else self.path
        return f"{self.check:<3} {loc}: {self.message}"

    def sort_key(self):
        return (self.check, self.path, self.line or 0)


# --------------------------------------------------------------------------
# Markdown primitives
# --------------------------------------------------------------------------

LINK_RE = re.compile(r"\[([^\]\n]*)\]\(([^)\s]+)\)")
NESTED_LINK_RE = re.compile(r"\[[^\[\]]*\[([^\]]*)\]\(#([^)]*)\)[^\[\]]*\]\(([^)\s]+)\)")
ANCHOR_TAG_RE = re.compile(r"<a\s+id=[\"']([^\"']+)[\"']")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
CODE_SPAN_RE = re.compile(r"`[^`\n]*`")


def slug(heading: str) -> str:
    """GitHub's heading-id rule, as restated in documentation_standards section 4.

    Lowercase the heading text, drop every character that is not a letter, digit,
    space, hyphen or underscore, then turn each remaining space into a hyphen.

    The trailing whitespace left behind by a dropped character is NOT trimmed: a
    heading ending in an emoji legitimately yields a trailing hyphen, and a
    spaced em-dash legitimately yields a double hyphen. Trimming here produces
    false positives on real, working anchors.
    """
    h = heading.strip()
    h = h.replace("`", "")
    h = re.sub(r"\*\*|\*|__|~~", "", h)
    h = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", h)
    h = h.lower()
    kept = [c for c in h if c.isalnum() or c in (" ", "-", "_")]
    return "".join(kept).replace(" ", "-")


def strip_fences(text: str):
    """Blank out fenced blocks, preserving line numbering.

    Returns (stripped_text, fence_language_by_line).
    """
    out = []
    langs = {}
    in_fence = False
    lang = ""
    for i, line in enumerate(text.split("\n"), 1):
        m = re.match(r"^\s*```(.*)$", line)
        if m:
            if not in_fence:
                in_fence = True
                lang = m.group(1).strip()
            else:
                in_fence = False
                lang = ""
            out.append("")
            continue
        if in_fence:
            langs[i] = lang
            out.append("")
        else:
            out.append(line)
    return "\n".join(out), langs


def strip_code_spans(line: str) -> str:
    return CODE_SPAN_RE.sub(" ", line)


def strip_links(line: str) -> str:
    return LINK_RE.sub(" ", line)


class Doc:
    def __init__(self, path, root):
        self.path = path
        self.rel = os.path.relpath(path, root).replace(os.sep, "/")
        with open(path, encoding="utf-8") as fh:
            self.text = fh.read()
        self.lines = self.text.split("\n")
        self.stripped, self.fence_langs = strip_fences(self.text)
        self.stripped_lines = self.stripped.split("\n")
        self.headings = []          # (line, raw, anchor)
        self.anchors = set()
        self._index_headings()
        self.header = "\n".join(self.lines[:40])
        self.section_of = self._index_sections()
        self.task_note_lines = self._index_task_notes()
        self.non_normative_lines = self._index_non_normative_lines()

    def _index_non_normative_lines(self):
        """Index structural plan metadata that is repeated by the required skeleton."""
        if not self.is_plan:
            return set()
        marked = set()
        count = len(self.stripped_lines)

        i = 0
        while i < count:
            if re.match(r"^\s*\*\*(Substrate|Register):\*\*", self.stripped_lines[i]):
                end = i + 1
                while end < count and self.stripped_lines[end].strip():
                    end += 1
                marked.update(range(i + 1, end + 1))
                i = end
                continue
            i += 1

        i = 0
        while i < count:
            if not re.match(r"^###\s+Remaining Work\s*$", self.stripped_lines[i]):
                i += 1
                continue
            end = i + 1
            while end < count and not self.stripped_lines[end].lstrip().startswith("#"):
                end += 1
            marked.update(range(i + 1, end + 1))
            i = end
        return marked

    def _index_task_notes(self):
        """Index complete multi-line task-note entries sanctioned by section 4.

        A Docs-to-update field and a Documentation Requirements bullet routinely
        wrap across lines. The exemption belongs to the whole entry, not only the
        physical line that happens to contain the `.md` owner name.
        """
        marked = set()
        count = len(self.stripped_lines)

        i = 0
        while i < count:
            line = self.stripped_lines[i]
            if re.match(r"^\s*\*\*Docs to update\*\*\s*:", line):
                end = i + 1
                while end < count and self.stripped_lines[end].strip():
                    end += 1
                if any(".md" in self.stripped_lines[j] for j in range(i, end)):
                    marked.update(range(i + 1, end + 1))
                i = end
                continue
            i += 1

        i = 0
        while i < count:
            section = self.section_of.get(i + 1, "")
            if not section.startswith(("Documentation Requirements", "Docs to update")):
                i += 1
                continue
            if not re.match(r"^\s*[-*]\s+", self.stripped_lines[i]):
                i += 1
                continue
            end = i + 1
            while end < count:
                candidate = self.stripped_lines[end]
                if not candidate.strip() or candidate.lstrip().startswith("#"):
                    break
                if re.match(r"^\s*[-*]\s+", candidate):
                    break
                end += 1
            if any(".md" in self.stripped_lines[j] for j in range(i, end)):
                marked.update(range(i + 1, end + 1))
            i = end

        return marked

    def _index_sections(self):
        """Map each line number to the nearest preceding H2 heading text."""
        current = ""
        out = {}
        for i, line in enumerate(self.stripped_lines, 1):
            m = re.match(r"^##\s+(.*?)\s*$", line)
            if m:
                current = m.group(1)
            out[i] = current
        return out

    def in_task_note(self, i):
        """True where documentation_standards section 4's plan-suite shorthand applies.

        A section ref inside a `Docs to update` entry, a `Documentation Requirements`
        bullet, or a `(section-N backlink)` parenthetical is build-task shorthand, not a
        reader cross-reference — provided the owning document is named in that same entry.
        """
        if i in self.task_note_lines:
            return True
        section = self.section_of.get(i, "")
        line = self.stripped_lines[i - 1] if 0 < i <= len(self.stripped_lines) else ""
        names_doc = ".md" in line
        if not names_doc:
            return False
        if section.startswith(("Documentation Requirements", "Docs to update")):
            return True
        if re.search(r"^\s*\**Docs to update\**\s*:", line):
            return True
        if "backlink" in line.lower():
            return True
        return False

    def _index_headings(self):
        seen = defaultdict(int)
        for i, line in enumerate(self.stripped_lines, 1):
            m = HEADING_RE.match(line)
            if not m:
                continue
            base = slug(m.group(2))
            n = seen[base]
            seen[base] += 1
            anchor = base if n == 0 else f"{base}-{n}"
            self.headings.append((i, m.group(2), anchor))
            self.anchors.add(anchor)
        # explicit <a id="..."> targets are valid anchors
        for m in ANCHOR_TAG_RE.finditer(self.text):
            self.anchors.add(m.group(1))

    def field(self, name):
        m = re.search(rf"^\*\*{re.escape(name)}\*\*:\s*(.*?)\s*$", self.header, re.M)
        return m.group(1) if m else None

    @property
    def is_engineering(self):
        return self.rel.startswith("documents/engineering/")

    @property
    def is_plan(self):
        return self.rel.startswith("DEVELOPMENT_PLAN/")

    @property
    def is_catalog_slice(self):
        return (
            self.rel.startswith("documents/illegal_state/illegal_state_")
            and not self.rel.endswith(("illegal_state_catalog.md", "illegal_state_techniques.md"))
        )


# --------------------------------------------------------------------------
# Checks
# --------------------------------------------------------------------------


def check_a_header(doc, v):
    if os.path.basename(doc.rel) in EXEMPT_BASENAMES:
        return
    status = doc.field("Status")
    if status is None:
        v.append(Violation("a1", doc.rel, 1, "missing **Status** header field"))
    elif status not in LEGAL_STATUS:
        v.append(Violation("a1", doc.rel, 1, f"Status {status!r} is not one of {sorted(LEGAL_STATUS)}"))

    if doc.field("Supersedes") is None:
        v.append(Violation("a2", doc.rel, 1, "missing **Supersedes** header field"))
    if doc.field("Referenced by") is None:
        v.append(Violation("a3", doc.rel, 1, "missing **Referenced by** header field"))

    gen = doc.field("Generated sections")
    if gen is None:
        v.append(Violation("a4", doc.rel, 1, "missing **Generated sections** header field"))
    else:
        declared = set()
        if gen.strip() not in ("none", "N/A"):
            declared = {x.strip().strip("`") for x in gen.split(",") if x.strip()}
        actual = set(re.findall(r"<!--\s*generated:([A-Za-z0-9_.-]+)\s*-->", doc.text))
        if declared != actual:
            v.append(
                Violation(
                    "a4",
                    doc.rel,
                    1,
                    f"Generated sections {sorted(declared)} do not match in-body markers {sorted(actual)}",
                )
            )

    pm = re.search(r"^>\s*\*\*Purpose\*\*:\s*(.+)$", doc.text, re.M)
    if not pm:
        v.append(Violation("a5", doc.rel, 1, "missing one-sentence > **Purpose**: line"))


def check_b_links(doc, docs_by_path, root, v):
    for i, line in enumerate(doc.stripped_lines, 1):
        for m in LINK_RE.finditer(line):
            target = m.group(2)
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            if target.startswith("#"):
                anchor = target[1:]
                if anchor and anchor not in doc.anchors:
                    v.append(Violation("b1", doc.rel, i, f"same-document anchor {target} resolves to no heading"))
                continue
            path_part, _, anchor = target.partition("#")
            if not path_part:
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(doc.path), path_part))
            if not os.path.exists(resolved):
                v.append(Violation("b1", doc.rel, i, f"relative link {target} resolves to no file"))
                continue
            if resolved.endswith(".md") and anchor:
                other = docs_by_path.get(resolved)
                if other is not None and anchor not in other.anchors:
                    v.append(
                        Violation("b1", doc.rel, i, f"link {target} resolves to no heading in the target file")
                    )

    # b2: a bare section reference outside the five sanctioned forms.
    for i, line in enumerate(doc.stripped_lines, 1):
        if line.lstrip().startswith("#"):
            continue                      # inside a heading: sanctioned
        if doc.fence_langs.get(i) is not None:
            continue                      # inside a fenced/Mermaid block: sanctioned
        if doc.in_task_note(i):
            continue                      # plan-suite build-task shorthand: sanctioned
        bare = strip_code_spans(strip_links(line))
        for m in re.finditer(r"§\s*([A-Z0-9]\w*(?:\.\d+)*)", bare):
            ref = m.group(1)
            if "." in ref:
                continue                  # section-M.N list-clause shorthand: sanctioned
            low = line.lower()
            if any(marker in low for marker in EXTERNAL_PROJECT_MARKERS):
                continue                  # external sibling project: sanctioned
            v.append(
                Violation("b2", doc.rel, i, f"bare section reference §{ref} must be a Markdown anchor link")
            )


def check_c_referenced_by(docs, docs_by_path, v):
    inbound = defaultdict(set)
    for doc in docs:
        for line in doc.stripped_lines:
            for m in LINK_RE.finditer(line):
                target = m.group(2)
                if target.startswith(("http://", "https://", "mailto:", "#")):
                    continue
                path_part, _, _ = target.partition("#")
                if not path_part.endswith(".md"):
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(doc.path), path_part))
                other = docs_by_path.get(resolved)
                if other is not None and other.path != doc.path:
                    inbound[other.path].add(doc.rel)

    for doc in docs:
        if os.path.basename(doc.rel) in EXEMPT_BASENAMES:
            continue
        raw = doc.field("Referenced by")
        if raw is None:
            continue
        declared = set()
        if raw.strip() not in ("N/A", "none", "None"):
            declared = {x.strip() for x in raw.split(",") if x.strip()}
        actual = inbound.get(doc.path, set())
        for missing in sorted(actual - declared):
            v.append(Violation("c", doc.rel, 1, f"{missing} links here but is absent from Referenced by"))
        for stale in sorted(declared - actual):
            v.append(Violation("c", doc.rel, 1, f"Referenced by names {stale}, which contains no link here"))


SENT_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")


# Link-list and task-metadata sections carry no normative content, so repetition
# across documents there is the cross-reference discipline working, not duplication.
NON_NORMATIVE_SECTIONS = (
    "Related Documents",
    "Cross-references",
    "Cross-References",
    "Documentation Requirements",
    "Docs to update",
    "Document index",
    "Phase Status",         # the mandated section-D template line, repeated by design
    "Doctrine adopted",     # citation boilerplate the skeleton prescribes
    "Planning ownership",   # tracker/status ownership boilerplate, never subsystem doctrine
)

PLAN_TEMPLATE_PREFIXES = (
    "This phase instantiates the canonical resource matrix and sealed whole-deployment provision boundary",
    "This section carries this sub-phase's **slice** of the provider gate apparatus",
    "Independent reference predicates (§M.3).",
)


def _section_is_non_normative(section):
    """Recognize a structural section whether or not its heading is numbered."""
    name = re.sub(r"^\d+(?:\.\d+)*\.\s+", "", section)
    return name.startswith(NON_NORMATIVE_SECTIONS)


def _prose_units(line):
    """Yield the prose spans of a line.

    A table row is not exempt — the suite states normative invariants in table
    cells — so each sufficiently long cell is yielded as its own unit.
    """
    s = line.strip()
    if s.startswith("|"):
        for cell in s.split("|"):
            cell = cell.strip()
            if cell and not set(cell) <= set("-: "):
                yield cell
    else:
        yield s


def _normalized_sentences(doc):
    """Yield (line_number, normalized_words) for governed prose sentences."""
    for i, raw in enumerate(doc.stripped_lines, 1):
        if i in doc.non_normative_lines:
            continue
        section = doc.section_of.get(i, "")
        if _section_is_non_normative(section):
            continue
        if doc.is_catalog_slice and section.startswith("1. Scope"):
            continue
        for s in _prose_units(raw):
            if not s or s.startswith((">", "#")):
                continue                  # quotations and headings are exempt
            if re.match(r"^\*\*(Status|Supersedes|Referenced by|Generated sections|Substrate|Register)(?:\*\*:|:\*\*)", s):
                continue
            if doc.is_plan and s.lstrip("-* ").startswith(PLAN_TEMPLATE_PREFIXES):
                continue
            if re.match(r"^[-*]\s*\[", s):
                continue                  # a bullet that is a link citation
            if len(LINK_RE.sub(" ", strip_code_spans(s)).split()) < 12:
                continue                  # mostly a citation: DRY linking, not prose
            s = strip_code_spans(s)
            s = LINK_RE.sub(r"\1", s)
            s = re.sub(r"[^\w\s]", " ", s.lower())
            for sentence in SENT_SPLIT_RE.split(s):
                words = sentence.split()
                if len(words) >= 12:
                    yield i, words


def check_d_near_duplicate(docs, v, shingle=8, threshold=0.6):
    index = defaultdict(set)
    units = {}
    uid = 0
    for doc in docs:
        for line, words in _normalized_sentences(doc):
            grams = {tuple(words[j:j + shingle]) for j in range(len(words) - shingle + 1)}
            if not grams:
                continue
            units[uid] = (doc.rel, line, grams)
            for g in grams:
                index[g].add(uid)
            uid += 1

    candidates = set()
    for g, owners in index.items():
        if len(owners) < 2:
            continue
        owners = sorted(owners)
        for x in range(len(owners)):
            for y in range(x + 1, len(owners)):
                if units[owners[x]][0] != units[owners[y]][0]:
                    candidates.add((owners[x], owners[y]))

    reported = set()
    for a, b in sorted(candidates):
        ra, la, ga = units[a]
        rb, lb, gb = units[b]
        jaccard = len(ga & gb) / len(ga | gb)
        if jaccard < threshold:
            continue
        key = (ra, rb)
        if key in reported:
            continue
        reported.add(key)
        v.append(
            Violation(
                "d",
                ra,
                la,
                f"near-duplicate normative content (shingle overlap {jaccard:.2f}) with {rb}:{lb}",
            )
        )


STATUS_MARKERS = ["✅", "🔄", "📋", "⏸️", "🧪"]


def _first_marker(text):
    for mk in STATUS_MARKERS:
        if mk in text:
            return mk
    return None


def check_e_status(docs_by_rel, v):
    tracker = docs_by_rel.get("DEVELOPMENT_PLAN/README.md")
    if tracker is None:
        return
    for line in tracker.stripped_lines:
        cells = [c.strip() for c in line.split("|")]
        if len(cells) < 8:
            continue
        if not re.fullmatch(r"\d+", cells[1]):
            continue
        phase, status_cell, doc_cell = cells[1], cells[6], cells[7]
        tracker_marker = _first_marker(status_cell)
        m = re.search(r"\((phase_\d+[a-z0-9_]*\.md)\)", doc_cell)
        if not m or tracker_marker is None:
            continue
        target = docs_by_rel.get("DEVELOPMENT_PLAN/" + m.group(1))
        if target is None:
            continue
        pm = re.search(r"^##\s+Phase Status\s*$", target.text, re.M)
        if not pm:
            v.append(Violation("e", target.rel, 1, "missing a ## Phase Status section"))
            continue
        tail = target.text[pm.end():]
        doc_marker = _first_marker(tail.split("\n##")[0])
        if doc_marker != tracker_marker:
            v.append(
                Violation(
                    "e",
                    target.rel,
                    1,
                    f"Phase Status {doc_marker} disagrees with the tracker row for phase {phase} ({tracker_marker})",
                )
            )


def check_f_gate_integrity(docs, docs_by_rel, v):
    tracker = docs_by_rel.get("DEVELOPMENT_PLAN/README.md")

    for doc in docs:
        if not re.match(r"DEVELOPMENT_PLAN/phase_\d+", doc.rel):
            continue
        gm = re.search(r"^\*\*Gate:\*\*\s*(.+?)(?=\n\n|\n##)", doc.text, re.M | re.S)
        if not gm:
            v.append(Violation("f", doc.rel, 1, "no **Gate:** line"))
            continue
        gate_line = doc.text.count("\n", 0, gm.start()) + 1
        # One anchor hop: section D orders the skeleton Phase Summary -> [Gate
        # integrity] -> [Resource provision] -> Doctrine adopted, and section M
        # permits the apparatus inline in the Gate paragraph or in its own
        # section. Either way it lies between the Gate line and Doctrine adopted.
        tail = doc.text[gm.start():]
        stop = re.search(r"^##\s+(Doctrine adopted|Sprints)\s*$", tail, re.M)
        scope = tail[: stop.start()] if stop else tail

        low = scope.lower()
        if "mutant" not in low:
            v.append(Violation("f", doc.rel, gate_line, "gate names no committed seeded mutant"))
        if "oracle" not in low and "independent" not in low:
            v.append(Violation("f", doc.rel, gate_line, "gate names no independent oracle"))
        if not any(t in low for t in ("golden", "fixture", "corpus", "committed")):
            v.append(Violation("f", doc.rel, gate_line, "gate names no committed fixtures or goldens"))

    if tracker is None:
        return
    for i, line in enumerate(tracker.stripped_lines, 1):
        if "✅" not in line or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")]
        if len(cells) < 8 or not re.fullmatch(r"\d+", cells[1]):
            continue
        row = line.lower()
        if not re.search(r"\d{4}-\d{2}-\d{2}", row):
            v.append(Violation("f", tracker.rel, i, "a Done row records no run date"))
        if "ledger" not in row:
            v.append(Violation("f", tracker.rel, i, "a Done row records no ledger hash"))


ENTRY_RE = re.compile(r"^#{2,4}\s+(\d+)\.(\d+)\s+(.*)$")


def check_g_catalog(docs, docs_by_rel, v):
    slices = [d for d in docs if d.is_catalog_slice]
    if not slices:
        return
    numbers = {}
    for doc in slices:
        current = None
        has_locus = False
        for i, line in enumerate(doc.stripped_lines, 1):
            m = ENTRY_RE.match(line)
            if m:
                if current and not has_locus:
                    v.append(Violation("g1", doc.rel, current[1], f"entry §{current[0]} carries no **Validation-locus:**"))
                key = f"{m.group(1)}.{m.group(2)}"
                if key in numbers:
                    v.append(Violation("g2", doc.rel, i, f"entry §{key} duplicates {numbers[key]}"))
                numbers[key] = f"{doc.rel}:{i}"
                current = (key, i)
                has_locus = False
            elif current and "**Validation-locus" in line:
                has_locus = True
        if current and not has_locus:
            v.append(Violation("g1", doc.rel, current[1], f"entry §{current[0]} carries no **Validation-locus:**"))

    # g2 contiguity, per major group
    groups = defaultdict(list)
    for key in numbers:
        major, minor = key.split(".")
        groups[major].append(int(minor))
    for major, minors in sorted(groups.items()):
        minors.sort()
        for expected, actual in zip(range(minors[0], minors[0] + len(minors)), minors):
            if expected != actual:
                v.append(
                    Violation(
                        "g2",
                        "documents/illegal_state/",
                        None,
                        f"§{major}.N numbering is not contiguous: expected §{major}.{expected}, found §{major}.{actual}",
                    )
                )
                break

    index = docs_by_rel.get("documents/illegal_state/illegal_state_catalog.md")
    if index is not None:
        for i, line in enumerate(index.stripped_lines, 1):
            for m in LINK_RE.finditer(line):
                target = m.group(2)
                if target.startswith(("http", "mailto:")):
                    continue
                path_part, _, anchor = target.partition("#")
                if not anchor:
                    continue
                if path_part:
                    resolved = os.path.normpath(os.path.join(os.path.dirname(index.path), path_part))
                    other = next((d for d in docs if d.path == resolved), None)
                else:
                    other = index
                if other is not None and anchor not in other.anchors:
                    v.append(Violation("g3", index.rel, i, f"index bullet anchor {target} resolves to no heading"))

    techniques = docs_by_rel.get("documents/illegal_state/illegal_state_techniques.md")
    if techniques is not None and numbers:
        matrix = set(re.findall(r"§?(\d+\.\d+)", techniques.text))
        for key in sorted(numbers, key=lambda k: (int(k.split(".")[0]), int(k.split(".")[1]))):
            if key not in matrix:
                loc = numbers[key]
                path, _, line = loc.rpartition(":")
                v.append(Violation("g4", path, int(line), f"entry §{key} has no technique-matrix row"))


def check_h_backlink(docs, v):
    for doc in docs:
        if not doc.is_engineering or os.path.basename(doc.rel) == "README.md":
            continue
        if doc.field("Status") == "Deprecated":
            continue                      # a redirect stub points at its successors, not the tracker
        if "DEVELOPMENT_PLAN/README.md" not in doc.text:
            v.append(Violation("h", doc.rel, 1, "no link back to DEVELOPMENT_PLAN/README.md"))


def check_i_nested_links(doc, v):
    for i, line in enumerate(doc.stripped_lines, 1):
        for m in NESTED_LINK_RE.finditer(line):
            inner_anchor, outer_target = m.group(2), m.group(3)
            if outer_target.startswith("#"):
                continue
            v.append(
                Violation(
                    "i",
                    doc.rel,
                    i,
                    f"section ref #{inner_anchor} sits inside a link to {outer_target} "
                    f"but resolves into this file",
                )
            )


GATE_MODULE_RE = re.compile(r"\bPhase(\d{2})([A-Z]\w*)\.hs\b")
SPRINT_RE = re.compile(r"\bSprint\s+(\d{1,2})\.\d+")
SPRINT_V_RE = re.compile(r"\((?:Gate;\s*)?(\d{1,2})\.\d+\s+V\d")


def check_j_sprint_locality(doc, v):
    m = re.match(r"DEVELOPMENT_PLAN/phase_(\d+)_", doc.rel)
    if not m:
        return
    own = int(m.group(1))
    for i, line in enumerate(doc.stripped_lines, 1):
        qualified = {int(x) for x in re.findall(r"\bPhase[- ](\d{1,2})\b", line)}
        qualified |= {int(x) for x in re.findall(r"\bphase_(\d+)", line)}
        for rx, what in ((SPRINT_RE, "sprint"), (SPRINT_V_RE, "validation-item")):
            for mm in rx.finditer(line):
                n = int(mm.group(1))
                if n != own and n not in qualified:
                    v.append(
                        Violation(
                            "j",
                            doc.rel,
                            i,
                            f"unqualified {what} reference {mm.group(0).strip()} names phase {n}, "
                            f"not this phase ({own})",
                        )
                    )
        for mm in GATE_MODULE_RE.finditer(line):
            n = int(mm.group(1))
            if n != own and n not in qualified:
                v.append(
                    Violation(
                        "j", doc.rel, i, f"gate module {mm.group(0)} names phase {n}, not this phase ({own})"
                    )
                )


def check_k_product_name(doc, v):
    for i, line in enumerate(doc.stripped_lines, 1):
        if line.startswith("# "):
            continue                      # a document title takes title case
        if re.match(r"^\*\*(Status|Supersedes|Referenced by|Generated sections)\*\*:", line):
            continue
        if doc.fence_langs.get(i) is not None:
            continue
        probe = strip_code_spans(line)
        probe = re.sub(r"\bAmoebius[./]\w+", " ", probe)     # Haskell module namespace
        probe = re.sub(r"src/Amoebius\S*", " ", probe)
        probe = LINK_RE.sub(" ", probe)                      # a link label citing a document title
        probe = re.sub(r"[\"“][^\"”]*[\"”]", " ", probe)     # verbatim quotation
        for _ in re.finditer(r"\bAmoebius\b", probe):
            v.append(Violation("k", doc.rel, i, "the product name is lowercase `amoebius` outside a title"))


NEGATED_PROVEN_RE = re.compile(
    r"(not|never|rather than|instead of|cannot be|is not)\s+(\*\*)?proven", re.I
)


def check_l_honesty(doc, v):
    for i, line in enumerate(doc.stripped_lines, 1):
        if doc.fence_langs.get(i) is not None:
            continue
        probe = LINK_RE.sub(r"\1", strip_code_spans(line))   # keep labels, drop anchor slugs
        for m in re.finditer(r"\b([\w]+(?:-[\w]+)*-proven)\b", probe):
            if m.group(1).lower() in OVERCLAIMING_TOKENS:
                v.append(
                    Violation(
                        "l",
                        doc.rel,
                        i,
                        f"token {m.group(1)!r} claims proof at a layer the honesty grammar fixes as tested",
                    )
                )
        probe = LEDGER_NAME_RE.sub(" ", probe)               # the ledger's name is not a claim
        if re.search(r"\bRegister[- ](2\.5|2|3)\b", probe) and re.search(r"\bprove[sn]?\b|\bproving\b", probe):
            if not NEGATED_PROVEN_RE.search(probe):
                v.append(
                    Violation(
                        "l",
                        doc.rel,
                        i,
                        "a Register-2/2.5/3 claim uses 'prove'; those layers are tested, never proven",
                    )
                )


DECL_RE = re.compile(r"^\s*(?:data|newtype|type)\s+([A-Z]\w*)")


def check_m_type_uniqueness(docs, v):
    owners = defaultdict(set)
    where = {}
    for doc in docs:
        if not doc.rel.startswith("documents/"):
            continue                      # doctrine SSoT only; the plan sketches types by design
        for i, line in enumerate(doc.lines, 1):
            if doc.fence_langs.get(i) is None:
                continue                  # declarations live in fenced blocks
            m = DECL_RE.match(line)
            if m:
                name = m.group(1)
                owners[name].add(doc.rel)
                where.setdefault((name, doc.rel), i)
    for name, docs_with in sorted(owners.items()):
        if len(docs_with) < 2:
            continue
        for rel in sorted(docs_with):
            others = sorted(d for d in docs_with if d != rel)
            v.append(
                Violation("m", rel, where[(name, rel)], f"type {name} is also declared in {', '.join(others)}")
            )


def check_n_label_target(doc, v):
    for i, line in enumerate(doc.stripped_lines, 1):
        for m in LINK_RE.finditer(line):
            label, target = m.group(1), m.group(2)
            if target.startswith(("http", "mailto:", "#")):
                continue
            path_part, _, _ = target.partition("#")
            if not path_part.endswith(".md"):
                continue
            base = os.path.basename(path_part)
            named = re.findall(r"\b([a-z0-9_]+\.md)\b", label)
            named += [f"{p}.md" for p in re.findall(r"\b(phase_\d+)[_\b]", label)]
            for n in named:
                if n == base:
                    continue
                if n.startswith("phase_") and base.startswith(n.rstrip(".md").rstrip("_")):
                    continue
                # the catalog index is cited by name while the link targets its themed slice
                if n == "illegal_state_catalog.md" and base.startswith("illegal_state_"):
                    continue
                v.append(
                    Violation("n", doc.rel, i, f"link label names {n} but the target is {base}")
                )


# --------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------

GOVERNED_DIRS = ("documents", "DEVELOPMENT_PLAN")


def collect(root):
    docs = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "doc_lint_corpus", "node_modules")]
        for fn in sorted(filenames):
            if not fn.endswith(".md"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if rel.startswith(GOVERNED_DIRS) or rel == "README.md":
                docs.append(Doc(full, root))
    return docs


def run(root, only=None):
    docs = collect(root)
    if not docs:
        print(f"doc_lint: no governed documents found under {root}", file=sys.stderr)
        return 2, []

    docs_by_path = {d.path: d for d in docs}
    docs_by_rel = {d.rel: d for d in docs}
    v = []

    for doc in docs:
        check_a_header(doc, v)
        check_b_links(doc, docs_by_path, root, v)
        check_i_nested_links(doc, v)
        check_j_sprint_locality(doc, v)
        check_k_product_name(doc, v)
        check_l_honesty(doc, v)
        check_n_label_target(doc, v)

    check_c_referenced_by(docs, docs_by_path, v)
    check_d_near_duplicate(docs, v)
    check_e_status(docs_by_rel, v)
    check_f_gate_integrity(docs, docs_by_rel, v)
    check_g_catalog(docs, docs_by_rel, v)
    check_h_backlink(docs, v)
    check_m_type_uniqueness(docs, v)

    if only:
        v = [x for x in v if x.check in only or x.check.rstrip("12345") in only]
    return (1 if v else 0), v


def main(argv):
    ap = argparse.ArgumentParser(description="The amoebius documentation lint (Phase 0 gate).")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--only", help="comma-separated check ids to report")
    ap.add_argument("--summary", action="store_true", help="counts per check instead of each violation")
    ap.add_argument("--list-checks", action="store_true")
    args = ap.parse_args(argv)

    if args.list_checks:
        for cid, desc in CHECKS.items():
            print(f"{cid:<3} {desc}")
        return 0

    only = {x.strip() for x in args.only.split(",")} if args.only else None
    code, violations = run(args.root, only)
    if code == 2:
        return 2

    if args.summary:
        counts = defaultdict(int)
        for x in violations:
            counts[x.check] += 1
        for cid in CHECKS:
            if counts[cid]:
                print(f"{counts[cid]:6d}  {cid:<3} {CHECKS[cid]}")
        print(f"{sum(counts.values()):6d}  TOTAL")
    else:
        for x in sorted(violations, key=Violation.sort_key):
            print(x.render())

    if violations:
        checks_hit = sorted({x.check for x in violations})
        print(f"\ndoc_lint: FAIL — {len(violations)} violation(s) across checks {', '.join(checks_hit)}", file=sys.stderr)
    else:
        print("doc_lint: clean", file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
