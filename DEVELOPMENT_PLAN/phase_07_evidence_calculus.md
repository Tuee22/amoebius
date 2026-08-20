# Phase 7: The evidence calculus

> **Purpose**: A claim is bound to the fixture that discharges it, and a mutant record is a value.
> **Read this if**: a claim has to be tied to something that could falsify it, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: bind every claim a phase makes to the fixture that discharges it, so an unchecked claim is not expressible.
Its first deliverable is a claim type carrying its discharge, so a claim with no fixture has no constructor, and this phase sits where the vocabulary it consumes first exists.
The rule behind the evidence calculus is owned by [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 7.1: The evidence calculus 📋](#sprint-71-the-evidence-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-6 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Bind every claim a phase makes to the fixture that discharges it, so an unchecked claim is not expressible.

**Phase scope:** one cohesive claim — *a claim that names no fixture is not expressible*. The claim value, the closed set of fixture kinds, and the mutant record are what make that binding mechanical rather than editorial.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 3](phase_03_artifact_calculus.md) — the artifact calculus, because a fixture and a mutant are both artifacts something has to address and reap. No obligation from the workflow calculus is consumed here.
**Gate:** `python3 tools/evidence_calculus_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored claim inventory for one existing phase, compared against the registry the implementation derives.
- **Committed mutants.** Mutants register a claim with no fixture, point a mutant at the wrong locus, and add a second mutant registry.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in the register model as a value, so a gate declares which register its evidence reaches.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored claim inventory for one existing phase, compared against the registry the implementation derives.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — the rule behind the evidence calculus.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the register model a declared fixture runs at.

## Sprints

## Sprint 7.1: The evidence calculus 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored claim inventory for one existing phase, compared against the registry the implementation derives.
**Docs to update**: `documents/engineering/evidence_calculus_doctrine.md`

### Objective

Bind every claim a phase makes to the fixture that discharges it, so an unchecked claim is not expressible.

### Deliverables

- A claim type carrying its discharge, so a claim with no fixture has no constructor.
- A mutant record naming its operator, its change, and the locus the gate must redden.
- One registry for the mutant corpus, with a carrier field rather than a second registry.
- The register model as a value, so a gate declares which register its evidence reaches.

### Validation

A claim without a fixture reference must fail to construct, and every registered mutant must redden its named locus.

### Remaining Work

Everything. No claim value binds a fixture, and no mutant is recorded as a value.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — the rule behind the evidence calculus.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the register model a declared fixture runs at.
