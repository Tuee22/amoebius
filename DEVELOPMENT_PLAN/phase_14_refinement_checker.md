# Phase 14: The amoebius refinement checker

> **Purpose**: Refinement types over the fragment the model defines, so a property holds of the implementation.
> **Read this if**: a property proved of a model has to be carried into the code implementing it, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: put the obligations on the functions themselves, so a property holds of the implementation and not only of its abstraction.
Its first deliverable is refinement annotations over the fragment the model defines, and this phase sits where the vocabulary it consumes first exists.
The rule behind the amoebius refinement checker is owned by [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md), which this contract implements rather than restates.

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
- [Sprint 14.1: The amoebius refinement checker 📋](#sprint-141-the-amoebius-refinement-checker-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-13 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Put the obligations on the functions themselves, so a property holds of the implementation and not only of its abstraction.

**Phase scope:** one cohesive claim — *a property established of the model constrains the implementation of it*. The refinement fragment, the types over it, and the correspondence obligation are the three parts of that carry.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — the model whose fragment this phase refines. The two checkers before it decide the model; this one decides an implementation against it.
**Gate:** `python3 tools/refinement_checker_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored correspondence table from model invariants to the functions that must carry them.
- **Committed mutants.** Mutants weaken a refinement, remove a correspondence row, and accept an unproven obligation.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a diagnostic naming the unproven obligation and its location.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored correspondence table from model invariants to the functions that must carry them.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md) — the rule behind the amoebius refinement checker.

## Sprints

## Sprint 14.1: The amoebius refinement checker 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored correspondence table from model invariants to the functions that must carry them.
**Docs to update**: `documents/engineering/formal_model_doctrine.md`

### Objective

Put the obligations on the functions themselves, so a property holds of the implementation and not only of its abstraction.

### Deliverables

- Refinement annotations over the fragment the model defines.
- A checker rejecting a function whose body cannot discharge its refinement.
- Correspondence between a refinement and the model invariant it mirrors.
- A diagnostic naming the unproven obligation and its location.

### Validation

A function violating its refinement must be rejected with the obligation named, and every model invariant must have a corresponding refinement.

### Remaining Work

Everything. No fragment is delimited and no refinement obligation is discharged.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md) — the rule behind the amoebius refinement checker.
