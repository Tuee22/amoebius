#!/usr/bin/env python3
"""Emit the doc_lint seeded-negative corpus.

`_positive/` is a small conforming documentation tree that `doc_lint.py` passes
clean. Every other directory here is that tree with **exactly one** hand-specified
defect seeded into **one** file — the minimal single-defect mutation the gate-integrity
discipline requires, so a fixture differs from a passing positive only in the flaw it
seeds, and the lint must name the check that flaw trips rather than recognising the
fixture itself.

The mutation list below is the authored artifact; this script only copies the tree and
applies it, so the seeded defects stay auditable in one place.

    python3 tools/doc_lint_corpus/_build.py         # regenerate every fixture
"""

import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
POSITIVE = os.path.join(HERE, "_positive")

# (fixture, check the lint must name, co-implied checks, [(file, find, replace), ...])
#
# A defect can legitimately trip more than one check: a dangling catalog index
# anchor IS also an unresolved link. Those co-implications are declared, not
# suppressed. Edits are a list because seeding one defect sometimes requires
# coordinated edits — renumbering an entry without also moving its index bullet
# and matrix row would seed three defects, not one.
MUTATIONS = [
    # -- (a) header metadata, one negative per facet ------------------------
    ("a1_status_not_in_enum", "a1", set(), [
        ("documents/engineering/example_doctrine.md",
         "**Status**: Authoritative source", "**Status**: doctrine / notes")]),
    ("a2_supersedes_missing", "a2", set(), [
        ("documents/engineering/example_doctrine.md", "**Supersedes**: N/A\n", "")]),
    ("a3_referenced_by_missing", "a3", set(), [
        ("documents/engineering/example_doctrine.md",
         "**Referenced by**: DEVELOPMENT_PLAN/phase_01_example.md, documents/engineering/README.md\n", "")]),
    ("a4_generated_sections_mismatch", "a4", set(), [
        ("documents/engineering/example_doctrine.md",
         "**Generated sections**: none", "**Generated sections**: capability_table")]),
    ("a5_purpose_missing", "a5", set(), [
        ("documents/engineering/example_doctrine.md",
         "> **Purpose**: One sentence describing the example doctrine.\n", "")]),

    # -- (b) links and section references ------------------------------------
    ("b1_dangling_anchor", "b1", set(), [
        ("documents/engineering/example_doctrine.md",
         "[§2](#2-the-bound-shape)", "[§2](#2-the-unbound-shape)")]),
    ("b2_bare_section_ref", "b2", set(), [
        ("documents/engineering/example_doctrine.md",
         "described by [§2](#2-the-bound-shape)", "described by §2")]),

    # -- (c) one-way Referenced by -------------------------------------------
    ("c_one_way_referenced_by", "c", set(), [
        ("documents/engineering/example_doctrine.md",
         "**Referenced by**: DEVELOPMENT_PLAN/phase_01_example.md, documents/engineering/README.md",
         "**Referenced by**: documents/engineering/README.md")]),

    # -- (d) near-duplicate normative content --------------------------------
    ("d_near_duplicate", "d", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "The reconciler observes the live shape and enacts only the typed actions its stage admits.",
         "A bound shape carries the identity, the revision and the ceiling that the provisioning fold consumes before it renders.")]),

    # -- (e) drifted status marker -------------------------------------------
    ("e_status_marker_drift", "e", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "📋 Planned. Specified before implementation.", "🔄 Active. Specified before implementation.")]),

    # -- (f) gate missing its committed apparatus ----------------------------
    ("f_gate_without_mutant", "f", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         " and one committed seeded mutant turns it red", "")]),

    # -- (g) catalog integrity, one negative per sub-check -------------------
    ("g1_entry_without_locus", "g1", set(), [
        ("documents/illegal_state/illegal_state_storage.md",
         "**Validation-locus:** `Gate-2-decoder`\n", "")]),
    # renumbering 3.2 to 3.4 moves its index bullet and matrix row with it, so the
    # only surviving defect is the gap in the sequence
    ("g2_numbering_gap", "g2", set(), [
        ("documents/illegal_state/illegal_state_storage.md",
         "### 3.2 A volume without a ceiling", "### 3.4 A volume without a ceiling"),
        ("documents/illegal_state/illegal_state_catalog.md",
         "[§3.2](./illegal_state_storage.md#32-a-volume-without-a-ceiling)",
         "[§3.4](./illegal_state_storage.md#34-a-volume-without-a-ceiling)"),
        ("documents/illegal_state/illegal_state_techniques.md",
         "| 3.2 | closed union |", "| 3.4 | closed union |")]),
    ("g3_index_anchor_dangling", "g3", {"b1"}, [
        ("documents/illegal_state/illegal_state_catalog.md",
         "#31-a-claim-without-a-backing-volume", "#31-a-claim-without-any-backing-volume")]),
    ("g4_entry_without_matrix_row", "g4", set(), [
        ("documents/illegal_state/illegal_state_techniques.md",
         "| 3.2 | closed union | decode-foreclosed |\n", "")]),

    # -- (h) doctrine doc without its plan back-link -------------------------
    # the tracker's Referenced by follows the removed link, so the only surviving
    # defect is the absent back-link
    ("h_missing_plan_backlink", "h", set(), [
        ("documents/engineering/example_doctrine.md",
         "Status and sequencing live in [the plan](../../DEVELOPMENT_PLAN/README.md).",
         "Status and sequencing live in the plan."),
        ("DEVELOPMENT_PLAN/README.md",
         "**Referenced by**: documents/engineering/example_doctrine.md",
         "**Referenced by**: N/A")]),

    # -- (i) a section ref inside a cross-file link, resolving locally -------
    ("i_nested_link_local_anchor", "i", {"b1"}, [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "[example_doctrine.md §2](../documents/engineering/example_doctrine.md#2-the-bound-shape)",
         "[example_doctrine.md [§2](#2-the-bound-shape)](../documents/engineering/example_doctrine.md)")]),

    # -- (j) a sprint reference naming another phase -------------------------
    ("j_stale_sprint_reference", "j", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md", "(Gate; 1.2 V1)", "(Gate; 7.2 V1)")]),

    # -- (k) the product name capitalised in body prose ----------------------
    ("k_capitalised_product_name", "k", set(), [
        ("documents/engineering/example_doctrine.md",
         "amoebius binds the shape before it renders.", "Amoebius binds the shape before it renders.")]),

    # -- (l) a token claiming proof at a tested layer ------------------------
    ("l_overclaimed_honesty_token", "l", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "seam is recorded tested", "seam is recorded live-proven")]),

    # -- (m) a type declared in two doctrine documents -----------------------
    ("m_duplicate_type_declaration", "m", set(), [
        ("documents/illegal_state/illegal_state_techniques.md",
         "| 3.1 | required field | type-foreclosed |",
         "| 3.1 | required field | type-foreclosed |\n\n```haskell\ndata BoundShape = BoundShape\n```")]),

    # -- (n) a link label naming a different file than its target ------------
    ("n_label_target_mismatch", "n", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "[example_doctrine.md §2](../documents/engineering/example_doctrine.md#2-the-bound-shape)",
         "[other_doctrine.md §2](../documents/engineering/example_doctrine.md#2-the-bound-shape)")]),
]

EXPECTED = {name: (check, co) for name, check, co, _ in MUTATIONS}


def main():
    if not os.path.isdir(POSITIVE):
        print(f"missing {POSITIVE}", file=sys.stderr)
        return 2

    for name, check, _co, edits in MUTATIONS:
        dest = os.path.join(HERE, name)
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        shutil.copytree(POSITIVE, dest)
        for rel, find, repl in edits:
            target = os.path.join(dest, rel)
            with open(target, encoding="utf-8") as fh:
                text = fh.read()
            if find not in text:
                print(f"FIXTURE {name}: seed text not found in {rel}", file=sys.stderr)
                return 2
            with open(target, "w", encoding="utf-8") as fh:
                fh.write(text.replace(find, repl, 1))
        print(f"{name:38s} {len(edits)} edit(s) (expects {check})")

    print(f"\n{len(MUTATIONS)} fixtures written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
