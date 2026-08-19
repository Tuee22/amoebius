#!/usr/bin/env python3
"""Emit the doc_lint seeded-negative corpus beneath the generated root.

`_positive/` is a small conforming documentation tree that `doc_lint.py` passes
clean. Each mutation below is that tree with **exactly one** hand-specified defect
seeded into **one** file — the minimal single-defect mutation the gate-integrity
discipline requires, so a materialized negative differs from a passing positive only
in the flaw it seeds, and the lint must name the check that flaw trips rather than
recognising the fixture itself.

The authored inputs are `_positive/` and the mutation list below. The materialized
negative trees are reproducible projections of those two, so under
`generated_artifacts_doctrine.md` they are generated output: this script writes them
to `gen/test-corpora/doc_lint/`, never back beside the source.

    python3 tools/doc_lint_corpus/_build.py         # materialize every negative
    python3 tools/doc_lint_corpus/_build.py --dest DIR
"""

import argparse
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
POSITIVE = os.path.join(HERE, "_positive")
ROOT = os.path.dirname(os.path.dirname(HERE))
DEST = os.path.join(ROOT, "gen", "test-corpora", "doc_lint")

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
         "**Purpose**: One sentence describing the example doctrine.\n>\n", "")]),

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
    ("f2_gate_without_command", "f2", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "`cabal test example-spec` is green — the committed golden corpus",
         "the committed golden corpus")]),
    # -- section L / section F: substrate and environment-precondition discipline --
    ("f4_blocked_by_later_sprint", "f4", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "Bound shapes are owned by",
         "**Blocked by**: Sprint 1.1\nBound shapes are owned by")]),
    ("f5_self_equal_pair", "f5", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "The seam is recorded tested against a modeled environment.",
         "The seam is recorded tested against a modeled environment. Phases 1 and 1 own it.")]),
    ("u3_slug_ordinal_mismatch", "u3", {"b1"}, [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "Bound shapes are owned by",
         "See [the example](phase_00_example.md).\nBound shapes are owned by")]),
    ("f4_blocked_by_later_phase", "f4", {"f5"}, [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "Bound shapes are owned by",
         "**Blocked by**: Phase 9 gate.\nBound shapes are owned by")]),
    ("f5_self_referential_ordinal", "f5", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "The seam is recorded tested against a modeled environment.",
         "The seam is recorded tested against a modeled environment. "
         "Server replay is deferred to Phase 1.")]),
    ("f3_forward_gate_unmarked", "f3", {"f5"}, [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "(Gate; 1.2 V1).",
         "(Gate; 1.2 V1). The Phase 10 reconciler must be Ready before this gate runs.")]),
    # a substrate the lane cannot belong to is also a lane its substrate cannot run:
    # the two names disagree in one direction or the other whichever is read first
    ("s1_two_specialized_substrates", "s1", {"s3"}, [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "**Substrate:** none", "**Substrate:** apple and linux-cuda")]),
    ("s2_requires_unknown_token", "s2", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "**Requires**: `host-floor`", "**Requires**: `a-precondition-nobody-declared`")]),
    # section F: the table and the declarations join both ways, so a row that stops
    # naming its declaring phase is as much a defect as an undeclared token
    ("s2_requires_row_omits_declarer", "s2", set(), [
        ("DEVELOPMENT_PLAN/development_plan_standards.md",
         "| `host-floor` | The per-substrate floor the operator supplies | Phases 1 |",
         "| `host-floor` | The per-substrate floor the operator supplies | Phases 8 |")]),
    # section S clause 15: a substrate-none gate claiming an architecture-bearing lane
    ("s3_lane_off_its_substrate", "s3", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "**Lane:** none", "**Lane:** linux-cpu/amd64")]),

    # -- (p5/p6) the section P.3 gate cap and the section P.2 field cap ------
    ("p5_gate_over_cap", "p5", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "(Gate; 1.2 V1).",
         "(Gate; 1.2 V1). The apparatus is restated inline here rather than delegated by "
         "anchor: the paired positives, the negative catalog entries and their expected "
         "tags, the coverage floors, the independent reference table, and each committed "
         "mutant with the assertion it must redden.")]),
    ("p6_field_over_cap", "p6", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "**Register:** 1",
         "**Register:** 1\n**Blocked by**: nothing, and the whole justification is restated "
         "in the field rather than moved into a numbered Validation list: no cluster is "
         "stood up, no host is touched, no credential is read, no external service is "
         "contacted, no registry is pulled from, and every artifact the run consumes is "
         "committed beforehand and then re-read from the working tree on each and every "
         "run, so that the whole justification sits in one field instead of a list.")]),

    # -- (g) catalog integrity, one negative per sub-check -------------------
    ("g1_entry_without_locus", "g1", set(), [
        ("documents/illegal_state/illegal_state_storage.md",
         "**Validation-locus:** `gadt-decode`\n", "")]),
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
        ("documents/engineering/example_doctrine.md",
         "- [the plan](../../DEVELOPMENT_PLAN/README.md)\n", ""),
        ("DEVELOPMENT_PLAN/README.md",
         "**Referenced by**: documents/engineering/example_doctrine.md, documents/engineering/long_doctrine.md",
         "**Referenced by**: documents/engineering/long_doctrine.md")]),

    # -- (i) a section ref inside a cross-file link, resolving locally -------
    ("i_nested_link_local_anchor", "i", {"b1"}, [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "[example_doctrine.md §2](../documents/engineering/example_doctrine.md#2-the-bound-shape)",
         "[example_doctrine.md [§2](#2-the-bound-shape)](../documents/engineering/example_doctrine.md)")]),

    # -- (j) a sprint reference naming another phase -------------------------
    ("j_stale_sprint_reference", "j", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md", "(Gate; 1.2 V1)", "(Gate; 8.2 V1)")]),

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
    # -- (o) document shape and the orientation block -------------------------
    ("o1_contents_block_missing", "o1", set(), [
        ("documents/engineering/long_doctrine.md", "## Contents\n", "## Overview\n")]),
    ("o2_contents_out_of_sync", "o2", set(), [
        ("documents/engineering/long_doctrine.md",
         "- [3. The declared ceiling](#3-the-declared-ceiling)",
         "- [3. The declared ceilings](#3-the-declared-ceiling)")]),
    ("o3_metadata_before_purpose", "o3", set(), [
        ("documents/engineering/example_doctrine.md",
         "# Example Doctrine\n\n>\n**Purpose**:",
         "# Example Doctrine\n\n**Status**: Authoritative source\n\n>\n**Purpose**:")]),
    ("o4_read_this_if_missing", "o4", set(), [
        ("documents/engineering/example_doctrine.md",
         ">\n**Read this if**: a bound shape has to be rendered.\n", "")]),
    ("o5_noncanonical_link_section", "o5", set(), [
        ("documents/engineering/example_doctrine.md",
         "## Related Documents", "## Cross-references")]),

    # -- (q) the diagram quota and per-register conformance -------------------
    ("q1_diagram_quota_unmet", "q1", {"q3"}, [
        ("documents/engineering/long_doctrine.md",
         "```mermaid\nflowchart LR\n  %% register: algebra\n", "```text\nno diagram here\n"),
        ("documents/engineering/long_doctrine.md",
         "```mermaid\nflowchart LR\n  %% register: orientation\n", "```text\nno diagram here\n")]),
    ("q3_orientation_diagram_missing", "q3", set(), [
        ("documents/engineering/long_doctrine.md",
         "```mermaid\nflowchart LR\n  %% register: orientation\n", "```text\nno diagram here\n")]),
    ("q4_register_directive_missing", "q4", set(), [
        ("documents/engineering/long_doctrine.md", "  %% register: algebra\n", "")]),
    ("q5_caption_missing", "q5", set(), [
        ("documents/engineering/long_doctrine.md",
         "*Design intent, Tier-1. The specimen gate, drawn in the algebra register.*\n", "")]),
    # -- (t) commit independence ---------------------------------------------
    # The seeded text below deliberately spells the withdrawn precondition. It is the
    # mutation, not a policy statement, and it lives in a mutation recipe rather than a
    # governed document, which is why check `t` does not flag this file.
    ("t_committed_tree_precondition", "t", set(), [
        ("DEVELOPMENT_PLAN/phase_01_example.md",
         "**Gate:** `cabal test example-spec` is green",
         "**Gate:** from a clean committed tree, `cabal test example-spec` is green")]),

    # -- (p) the section, document and sentence caps --------------------------
    ("p1_section_over_cap", "p1", set(), [
        ("documents/engineering/long_doctrine.md",
         "Rule 390 of the specimen constrains stage 3 exactly.",
         "Rule 390 of the specimen constrains stage 3 exactly.\nRule 901 of the specimen constrains stage 3 exactly.\nRule 902 of the specimen constrains stage 3 exactly.\nRule 903 of the specimen constrains stage 3 exactly.\nRule 904 of the specimen constrains stage 3 exactly.\nRule 905 of the specimen constrains stage 3 exactly.\nRule 906 of the specimen constrains stage 3 exactly.\nRule 907 of the specimen constrains stage 3 exactly.\nRule 908 of the specimen constrains stage 3 exactly.\nRule 909 of the specimen constrains stage 3 exactly.\nRule 910 of the specimen constrains stage 3 exactly.\nRule 911 of the specimen constrains stage 3 exactly.")]),
    ("p3_sentence_over_cap", "p3", set(), [
        ("documents/engineering/long_doctrine.md",
         "Rule 200 of the specimen constrains stage 2 exactly.",
         "A single sentence may not run past the stated word cap, because a reader has to hold every clause of it\nopen at once, and once the clause count passes a handful the sentence stops being parseable in one pass\nand becomes something the reader must scan twice to find the subject it started from, which is exactly\nthe defect the cap exists to prevent; this specimen is deliberately hard-wrapped across several physical\nlines, because the rule measures a sentence over the paragraph it sits in rather than over the line it\nhappens to occupy, and a checker that reads single lines sees only about eighteen words at a time and so\ncan never observe a sentence longer than one wrapped line, which is precisely the blindness that let\nthis rule go unenforced across the whole corpus until a paragraph-level reading was written for it.")]),
        ("p4_document_over_cap", "p4", set(), [
        ("documents/engineering/long_doctrine.md",
         "Rule 625 of the specimen constrains stage 5 exactly.",
         "Rule 625 of the specimen constrains stage 5 exactly.\n\n### An added subsection\n\nRule 950 of the specimen constrains stage 5 exactly.\nRule 951 of the specimen constrains stage 5 exactly.\nRule 952 of the specimen constrains stage 5 exactly.\nRule 953 of the specimen constrains stage 5 exactly.\nRule 954 of the specimen constrains stage 5 exactly.\nRule 955 of the specimen constrains stage 5 exactly.\nRule 956 of the specimen constrains stage 5 exactly.\nRule 957 of the specimen constrains stage 5 exactly.\nRule 958 of the specimen constrains stage 5 exactly.\nRule 959 of the specimen constrains stage 5 exactly.\nRule 960 of the specimen constrains stage 5 exactly.\nRule 961 of the specimen constrains stage 5 exactly.\nRule 962 of the specimen constrains stage 5 exactly.\nRule 963 of the specimen constrains stage 5 exactly.\nRule 964 of the specimen constrains stage 5 exactly.\nRule 965 of the specimen constrains stage 5 exactly.\nRule 966 of the specimen constrains stage 5 exactly.\nRule 967 of the specimen constrains stage 5 exactly.\nRule 968 of the specimen constrains stage 5 exactly.\nRule 969 of the specimen constrains stage 5 exactly.\nRule 970 of the specimen constrains stage 5 exactly.\nRule 971 of the specimen constrains stage 5 exactly.\nRule 972 of the specimen constrains stage 5 exactly.\nRule 973 of the specimen constrains stage 5 exactly.\nRule 974 of the specimen constrains stage 5 exactly.\nRule 975 of the specimen constrains stage 5 exactly.\nRule 976 of the specimen constrains stage 5 exactly.\nRule 977 of the specimen constrains stage 5 exactly.\nRule 978 of the specimen constrains stage 5 exactly.\nRule 979 of the specimen constrains stage 5 exactly.\nRule 980 of the specimen constrains stage 5 exactly.\nRule 981 of the specimen constrains stage 5 exactly.\nRule 982 of the specimen constrains stage 5 exactly.\nRule 983 of the specimen constrains stage 5 exactly.\nRule 984 of the specimen constrains stage 5 exactly.\nRule 985 of the specimen constrains stage 5 exactly.\nRule 986 of the specimen constrains stage 5 exactly.\nRule 987 of the specimen constrains stage 5 exactly.\nRule 988 of the specimen constrains stage 5 exactly.\nRule 989 of the specimen constrains stage 5 exactly.\nRule 990 of the specimen constrains stage 5 exactly.\nRule 991 of the specimen constrains stage 5 exactly.\nRule 992 of the specimen constrains stage 5 exactly.\nRule 993 of the specimen constrains stage 5 exactly.\nRule 994 of the specimen constrains stage 5 exactly.\nRule 995 of the specimen constrains stage 5 exactly.\nRule 996 of the specimen constrains stage 5 exactly.\nRule 997 of the specimen constrains stage 5 exactly.\nRule 998 of the specimen constrains stage 5 exactly.\nRule 999 of the specimen constrains stage 5 exactly.")]),
        ("p2_list_item_over_cap", "p2", set(), [
        ("documents/engineering/long_doctrine.md",
         "- The third item is the one a fixture grows past the cap.",
         "- The third item is the one a fixture grows past the cap.\n  Continuation line 1 of the seeded item.\n  Continuation line 2 of the seeded item.\n  Continuation line 3 of the seeded item.\n  Continuation line 4 of the seeded item.\n  Continuation line 5 of the seeded item.\n  Continuation line 6 of the seeded item.\n  Continuation line 7 of the seeded item.\n  Continuation line 8 of the seeded item.\n  Continuation line 9 of the seeded item.\n  Continuation line 10 of the seeded item.\n  Continuation line 11 of the seeded item.\n  Continuation line 12 of the seeded item.\n  Continuation line 13 of the seeded item.\n  Continuation line 14 of the seeded item.\n  Continuation line 15 of the seeded item.\n  Continuation line 16 of the seeded item.\n  Continuation line 17 of the seeded item.\n  Continuation line 18 of the seeded item.\n  Continuation line 19 of the seeded item.\n  Continuation line 20 of the seeded item.\n  Continuation line 21 of the seeded item.\n  Continuation line 22 of the seeded item.\n  Continuation line 23 of the seeded item.\n  Continuation line 24 of the seeded item.\n  Continuation line 25 of the seeded item.")]),
]

EXPECTED = {name: (check, co) for name, check, co, _ in MUTATIONS}


class SeedError(Exception):
    """A mutation's find-text no longer occurs in the positive seed."""


def materialize(dest=DEST, verbose=False):
    """Write every seeded negative under `dest` and return {name: path}.

    Raises SeedError when a mutation's anchor text has drifted out of the positive
    seed — a silently skipped mutation would leave the gate one-sided.
    """
    if not os.path.isdir(POSITIVE):
        raise SeedError(f"missing positive seed {POSITIVE}")

    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)

    built = {}
    for name, check, _co, edits in MUTATIONS:
        target_root = os.path.join(dest, name)
        shutil.copytree(POSITIVE, target_root)
        for rel, find, repl in edits:
            target = os.path.join(target_root, rel)
            with open(target, encoding="utf-8") as fh:
                text = fh.read()
            if find not in text:
                raise SeedError(f"{name}: seed text not found in {rel}")
            with open(target, "w", encoding="utf-8") as fh:
                fh.write(text.replace(find, repl, 1))
        built[name] = target_root
        if verbose:
            print(f"{name:38s} {len(edits)} edit(s) (expects {check})")
    return built


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dest", default=DEST, help="generated root for the negatives")
    args = ap.parse_args(argv)
    try:
        built = materialize(args.dest, verbose=True)
    except SeedError as exc:
        print(f"FIXTURE {exc}", file=sys.stderr)
        return 2
    print(f"\n{len(built)} negatives materialized under {args.dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
