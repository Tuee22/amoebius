# Phase 4: The budget calculus

> **Purpose**: The storage grant, a ceiling inseparable from its concurrency, admission, and the reaper.
> **Read this if**: a byte has to be accounted for before it is written, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make a byte unable to exist without a grant that carries both its ceiling and the concurrency it is shared across.
Its first deliverable is a `Grant` value issued from a finite pool, specific to a location and purpose, with no unbounded constructor, and this phase sits where the vocabulary it consumes first exists.
The rule behind the budget calculus is owned by [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 4.1: The budget calculus 📋](#sprint-41-the-budget-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-3 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Make a byte unable to exist without a grant that carries both its ceiling and the concurrency it is shared across.

**Phase scope:** one cohesive claim — *no byte exists without an authority that bounded it in advance*. The grant, the concurrency inseparable from its ceiling, admission and the reaper are four faces of that single authority.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, whose materialize step is the operation a grant authorises.
**Gate:** `python3 tools/budget_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A capacity table authored from the resource-capacity family, giving expected admission verdicts for demand vectors the implementation never sees.
- **Committed mutants.** Mutants separate the ceiling from its concurrency, default a grant to unbounded, and admit after a partial write.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a retention grant that has no constructor without a reaper.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a capacity table authored from the resource-capacity family, giving expected admission verdicts for demand vectors the implementation never sees.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — the rule behind the budget calculus.

## Sprints

## Sprint 4.1: The budget calculus 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A capacity table authored from the resource-capacity family, giving expected admission verdicts for demand vectors the implementation never sees.
**Docs to update**: `documents/engineering/jit_budget_doctrine.md`

### Objective

Make a byte unable to exist without a grant that carries both its ceiling and the concurrency it is shared across.

### Deliverables

- A `Grant` value issued from a finite pool, specific to a location and purpose, with no unbounded constructor.
- A ceiling and a concurrency bound that share one constructor, so neither can be stated alone.
- `admit` and `admitFirst` returning a reservation or a refusal, writing nothing on the refusal path.
- A retention grant that has no constructor without a reaper.

### Validation

Driving a grant to its ceiling must refuse at admission with the store byte-identical to its prior state, never mid-write.

### Remaining Work

Everything. No grant is issued, no demand is admitted, and nothing yet refuses a write for want of authority.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — the rule behind the budget calculus.
