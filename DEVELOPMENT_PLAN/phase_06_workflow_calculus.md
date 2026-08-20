# Phase 6: The workflow calculus

> **Purpose**: Provision, build, deploy, observe and teardown as one algebra, with teardown a type obligation.
> **Read this if**: something has to happen to a running system, or teardown has to be reasoned about, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make teardown an obligation the type system tracks rather than a step somebody remembers.
Its first deliverable is five arms — provision, build, deploy, observe, teardown — over one vocabulary, and this phase sits where the vocabulary it consumes first exists.
The rule behind the workflow calculus is owned by [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 6.1: The workflow calculus 📋](#sprint-61-the-workflow-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-5 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Make teardown an obligation the type system tracks rather than a step somebody remembers.

**Phase scope:** one cohesive claim — *a workflow cannot end while it still owes a teardown*. Five arms share one vocabulary precisely so that obligation can be stated across them at all.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 5](phase_05_lift_calculus.md) — the lift calculus, whose layers and witnesses each arm is placed at, and through it the budget calculus the build arm spends against.
**Gate:** `python3 tools/workflow_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A resource-ledger oracle authored independently, replaying a workflow trace and requiring the provisioned and released sets to be equal.
- **Committed mutants.** Mutants drop an obligation, discharge one twice, and transfer without a stated condition.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in sequential and parallel composition typed by the witnesses each arm consumes.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a resource-ledger oracle authored independently, replaying a workflow trace and requiring the provisioned and released sets to be equal.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — the rule behind the workflow calculus.

## Sprints

## Sprint 6.1: The workflow calculus 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A resource-ledger oracle authored independently, replaying a workflow trace and requiring the provisioned and released sets to be equal.
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`

### Objective

Make teardown an obligation the type system tracks rather than a step somebody remembers.

### Deliverables

- Five arms — provision, build, deploy, observe, teardown — over one vocabulary.
- Provision returning a handle and a teardown obligation together.
- Discharge by teardown or by explicit transfer to a longer-lived declaration, with no way to drop it.
- Sequential and parallel composition typed by the witnesses each arm consumes.

### Validation

A workflow ending while holding an undischarged obligation must fail to compile; a transferred obligation must name its condition.

### Remaining Work

Everything. No workflow value, no teardown obligation and no explicit transfer exists.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — the rule behind the workflow calculus.
