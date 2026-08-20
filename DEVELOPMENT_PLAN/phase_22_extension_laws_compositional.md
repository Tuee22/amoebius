# Phase 22: The compositional laws C1-C7

> **Purpose**: Closure, identity, associativity, non-interference, budget additivity, scope conjunction, name disjointness.
> **Read this if**: two extensions have to occupy one binary, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: prove that composing two conforming extensions yields a conforming extension, over the whole link set.
Its first deliverable is a composition operator over declarations, with identity and associativity checked by value, and this phase sits where the vocabulary it consumes first exists.
The rule behind the compositional laws C1-C7 is owned by [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md), which this contract implements rather than restates.

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
- [Sprint 22.1: The compositional laws C1-C7 📋](#sprint-221-the-compositional-laws-c1-c7-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-21 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Prove that composing two conforming extensions yields a conforming extension, over the whole link set.

**Phase scope:** one cohesive claim — *composition does not destroy a property its parts had*. C1 is that claim; the remaining six each close one identified way it could fail, and together they are not known to establish it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 21](phase_21_extension_laws_per_extension.md) — L1–L5, whose conjunction over a composite is exactly what C1 asserts.
**Gate:** `python3 tools/extension_laws_compositional_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored composition table giving expected composite declarations for argument pairs.
- **Committed mutants.** Mutants make composition order-sensitive, share state between parts, and collide two artifact addresses.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in name disjointness derived from the injective address rendering.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored composition table giving expected composite declarations for argument pairs.


- **Extension conformance (§M.13).** Not applicable: this phase builds the contract.

## Doctrine adopted

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the compositional laws C1-C7.

## Sprints

## Sprint 22.1: The compositional laws C1-C7 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored composition table giving expected composite declarations for argument pairs.
**Docs to update**: `documents/engineering/extension_conformance_laws.md`

### Objective

Prove that composing two conforming extensions yields a conforming extension, over the whole link set.

### Deliverables

- A composition operator over declarations, with identity and associativity checked by value.
- A non-interference check running each part's own suite against the composite.
- Budget additivity and scope conjunction as folds over the composite.
- Name disjointness derived from the injective address rendering.

### Validation

Every pair in the link set must satisfy C1 through C7, and a seeded interfering pair must redden C4.

### Remaining Work

Everything. No composition operator exists, and no law has been stated over a pair.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the compositional laws C1-C7.
