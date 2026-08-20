# Phase 47: Generated checking tools and mutants

> **Purpose**: The repository's checking tools and its mutant corpus are emitted from the declarations they check.
> **Read this if**: a checking tool or a mutant has to be added, changed, or trusted, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: emit the repository's own checking tools and mutant corpus from the declarations they check.
Its first deliverable is a tool recipe per checking concern, rendered from the declaration it enforces, and this phase sits where the vocabulary it consumes first exists.
The rule behind generated checking tools and mutants is owned by [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 47.1: Generated checking tools and mutants 📋](#sprint-471-generated-checking-tools-and-mutants-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-46 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Emit the repository's own checking tools and mutant corpus from the declarations they check.

**Phase scope:** one cohesive claim — *the repository's own checkers are rendered from the declarations they check, while every expectation they assert stays authored*. Getting that split wrong turns each tool from a test into a description.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, which is what a tool becomes an instance of, and [Phase 7](phase_07_evidence_calculus.md), which fixes which half of a checker may be generated at all.
**Gate:** `python3 tools/tool_and_mutant_generation_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** The existing authored tools serve as the independent expectation, retained under test until the equivalence holds.
- **Committed mutants.** Mutants emit a tool missing one rule, drop an operator from the corpus, and commit an emitted artifact.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in an equivalence check between an emitted tool and the authored one it replaces.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: the existing authored tools serve as the independent expectation, retained under test until the equivalence holds.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind generated checking tools and mutants.

## Sprints

## Sprint 47.1: Generated checking tools and mutants 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: The existing authored tools serve as the independent expectation, retained under test until the equivalence holds.
**Docs to update**: `documents/engineering/jit_artifact_doctrine.md`

### Objective

Emit the repository's own checking tools and mutant corpus from the declarations they check.

### Deliverables

- A tool recipe per checking concern, rendered from the declaration it enforces.
- The mutant corpus rendered from positive seeds and declared operators.
- A tracked-corpus assertion that no emitted tool or mutant is committed.
- An equivalence check between an emitted tool and the authored one it replaces.

### Validation

An emitted tool must reach the same verdicts as the authored tool it replaces over the whole existing corpus.

### Remaining Work

Everything. Every tool under `tools/` and every mutant under `test/mutant/` is still authored and tracked.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind generated checking tools and mutants.
