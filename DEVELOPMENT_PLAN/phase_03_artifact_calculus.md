# Phase 3: The artifact calculus

> **Purpose**: Targets, recipes, the content-derived address, and the materialize-consume-reap region.
> **Read this if**: an artifact's name, region, or recipe has to be reasoned about, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: give every artifact amoebius emits a type, a recipe, and a name that is a total function of what it contains.
Its first deliverable is a closed `Target` set indexing artifact kinds, so a consumer expecting one kind cannot be handed another, and this phase sits where the vocabulary it consumes first exists.
The rule behind the artifact calculus is owned by [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 3.1: The artifact calculus 📋](#sprint-31-the-artifact-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-2 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Give every artifact amoebius emits a type, a recipe, and a name that is a total function of what it contains.

**Phase scope:** one cohesive claim — *an artifact cannot exist without a recipe that produced it and a name that is a function of its content*. The kind index, the pure renderer, the address and the region that ends are one claim seen at four points.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 2](phase_02_repository_layout_conformance.md) — the target tree, which fixes the paths a recipe renders into. This is the first of the five calculi and consumes no algebra beneath it.
**Gate:** `python3 tools/artifact_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** An address table authored from the doctrine, listing the digest inputs each target folds, written before the renderer exists.
- **Committed mutants.** Mutants drop the rendered bytes from the address, admit a clock into a recipe, and let a handle escape its region.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a region whose exit reaps every artifact materialized inside it and not promoted to retained.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: an address table authored from the doctrine, listing the digest inputs each target folds, written before the renderer exists.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind the artifact calculus.

## Sprints

## Sprint 3.1: The artifact calculus 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: An address table authored from the doctrine, listing the digest inputs each target folds, written before the renderer exists.
**Docs to update**: `documents/engineering/jit_artifact_doctrine.md`

### Objective

Give every artifact amoebius emits a type, a recipe, and a name that is a total function of what it contains.

### Deliverables

- A closed `Target` set indexing artifact kinds, so a consumer expecting one kind cannot be handed another.
- A `Recipe` as a pure function from a declaration to rendered content, with no clock, environment or directory read.
- An address digesting target, recipe identity, declaration and the rendered bytes together.
- A region whose exit reaps every artifact materialized inside it and not promoted to retained.

### Validation

Two independently seeded processes render each target and must agree byte for byte; an artifact referenced after its region ends fails to compile.

### Remaining Work

Everything. No `Target`, no `Recipe`, no address and no region exists, and nothing yet refuses to name an artifact it did not render.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — the rule behind the artifact calculus.
