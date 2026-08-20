# Phase 36: The closed transaction vocabulary

> **Purpose**: The relational data plane as a closed union, with schema and row policy emitted from one declaration.
> **Read this if**: relational storage is being added, or the absence of an ORM has to be justified, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: replace the query surface with a closed union of the transactions the domain actually has.
Its first deliverable is transaction arms taking the scope witness as a required field, with no predicate combinator, and this phase sits where the vocabulary it consumes first exists.
The rule behind the closed transaction vocabulary is owned by [`extension_conformance_transactions.md`](../documents/engineering/extension_conformance_transactions.md), which this contract implements rather than restates.

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
- [Sprint 36.1: The closed transaction vocabulary 📋](#sprint-361-the-closed-transaction-vocabulary-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-35 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Replace the query surface with a closed union of the transactions the domain actually has.

**Phase scope:** one cohesive claim — *only a declared transaction has a constructor, and its schema and row policy are emitted from that one declaration*. There is no general query surface left over to secure afterwards.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 26](phase_26_gadt_decode_ir.md) — the GADT-indexed IR and its total decoder, which is the shape a closed transaction union is expressed in. The image recipe at its numeric predecessor supplies nothing this phase consumes.
**Gate:** `python3 tools/transaction_vocabulary_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored DDL and policy expectation per row type, written from the tenancy doctrine.
- **Committed mutants.** Mutants make the scope field optional, default it to a match-all comparison, and emit a policy for a different column.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in generation transitions with no destructive verb.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored DDL and policy expectation per row type, written from the tenancy doctrine.


- **Extension conformance (§M.13).** Not applicable: this phase builds the contract.

## Doctrine adopted

- [`extension_conformance_transactions.md`](../documents/engineering/extension_conformance_transactions.md) — the rule behind the closed transaction vocabulary.

## Sprints

## Sprint 36.1: The closed transaction vocabulary 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored DDL and policy expectation per row type, written from the tenancy doctrine.
**Docs to update**: `documents/engineering/extension_conformance_transactions.md`

### Objective

Replace the query surface with a closed union of the transactions the domain actually has.

### Deliverables

- Transaction arms taking the scope witness as a required field, with no predicate combinator.
- Schema, constraints, composite keys and row policies emitted from the same declaration.
- Results indexed by the scope that produced them.
- Generation transitions with no destructive verb.

### Validation

An un-scoped statement must have no inhabitant, and the emitted policy predicate must be the same term as the statement predicate.

### Remaining Work

Everything. No transaction union, emitted DDL, or row policy exists.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_transactions.md`](../documents/engineering/extension_conformance_transactions.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_transactions.md`](../documents/engineering/extension_conformance_transactions.md) — the rule behind the closed transaction vocabulary.
