# Phase 5: The lift calculus

> **Purpose**: A closed layer set, a total transition relation, and a witness for each transition.
> **Read this if**: the layer an effect runs at matters, or a transition needs a witness, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make where an effect runs part of its type, and make the relation between layers total.
Its first deliverable is a closed layer set: on the host, inside a frame, inside a container, with no `Other` arm, and this phase sits where the vocabulary it consumes first exists.
The rule behind the lift calculus is owned by [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 5.1: The lift calculus 📋](#sprint-51-the-lift-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-4 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Make where an effect runs part of its type, and make the relation between layers total.

**Phase scope:** one cohesive claim — *where an effect runs is part of its type, and no pair of layers is left undecided*. A closed set, a total relation over it, and a witness consumed by each transition are exactly what that requires.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, which supplies the first effects a layer has to place. This phase is independent of the budget calculus; the ordinal between them is sequence, not dependency.
**Gate:** `python3 tools/lift_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A layer-pair table authored from the substrate doctrine, naming which pairs have a constructor and which have none.
- **Committed mutants.** Mutants add a fallback arm, forge a witness without an observation, and compose two lifts whose layers do not meet.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in composition typed so two lifts compose exactly when the inner target layer is the outer source layer.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a layer-pair table authored from the substrate doctrine, naming which pairs have a constructor and which have none.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — the rule behind the lift calculus.

## Sprints

## Sprint 5.1: The lift calculus 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A layer-pair table authored from the substrate doctrine, naming which pairs have a constructor and which have none.
**Docs to update**: `documents/engineering/lift_and_compose_doctrine.md`

### Objective

Make where an effect runs part of its type, and make the relation between layers total.

### Deliverables

- A closed layer set: on the host, inside a frame, inside a container, with no `Other` arm.
- A transition relation that is total — every pair either has a constructor or has no inhabitant.
- A witness type per transition, produced only by observation and never by assertion.
- Composition typed so two lifts compose exactly when the inner target layer is the outer source layer.

### Validation

A wildcard-arm scan over the dispatch must find no fallback, and an asserted witness must fail to compile.

### Remaining Work

Everything. No layer set is closed, no transition relation is total, and no witness type exists.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md) — the rule behind the lift calculus.
