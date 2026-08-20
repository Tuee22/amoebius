# Phase 10: Composition across the five calculi

> **Purpose**: The resource and scope indices thread through all five calculi, and composition stays total.
> **Read this if**: two calculi have to be used together, or an index has to survive a composition, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: show the resource and scope indices survive every composition the five calculi admit.
Its first deliverable is index-preserving composition operators for each pairing of the five calculi, and this phase sits where the vocabulary it consumes first exists.
The rule behind composition across the five calculi is owned by [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 10.1: Composition across the five calculi 📋](#sprint-101-composition-across-the-five-calculi-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-9 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Show the resource and scope indices survive every composition the five calculi admit.

**Phase scope:** one cohesive claim — *the resource and scope indices survive every composition the five calculi admit*. This phase adds no vocabulary of its own; it establishes that the vocabulary already added composes.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 9](phase_09_resource_index.md) — the resource index, and through it every phase from 3 onward. The gate is stated over all five calculi and both indices at once, so it opens only once the last of them exists.
**Gate:** `python3 tools/calculus_composition_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** An index-algebra table authored from the doctrine, giving expected result indices for argument pairs.
- **Committed mutants.** Mutants widen a scope on composition, sum budgets with saturation, and drop an index through a transform.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a property suite instantiating the obligations over generated compositions.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: an index-algebra table authored from the doctrine, giving expected result indices for argument pairs.


- **Extension conformance (§M.13).** Not applicable: this phase builds the contract.

## Doctrine adopted

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the rule behind composition across the five calculi.

## Sprints

## Sprint 10.1: Composition across the five calculi 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: An index-algebra table authored from the doctrine, giving expected result indices for argument pairs.
**Docs to update**: `documents/engineering/extension_conformance_doctrine.md`

### Objective

Show the resource and scope indices survive every composition the five calculi admit.

### Deliverables

- Index-preserving composition operators for each pairing of the five calculi.
- A proof obligation that composing at one scope cannot produce a value at a wider scope.
- A budget fold over a composition equal to the sum of its parts.
- A property suite instantiating the obligations over generated compositions.

### Validation

Generated compositions must preserve both indices, and a widening composition must have no inhabitant.

### Remaining Work

Everything. No property has yet been stated over more than one calculus at a time.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the rule behind composition across the five calculi.
