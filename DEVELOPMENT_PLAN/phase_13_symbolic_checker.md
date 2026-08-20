# Phase 13: The amoebius symbolic checker

> **Purpose**: An SMT-backed symbolic checker over the same Model value, unbounded where induction admits it.
> **Read this if**: a state space is too large to enumerate, or an unbounded property is wanted, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: answer the bound the explicit-state checker leaves, by discharging the same invariants to a solver.
Its first deliverable is a translation from the `Model` fragment to solver assertions, total over the fragment, and this phase sits where the vocabulary it consumes first exists.
The rule behind the amoebius symbolic checker is owned by [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md), which this contract implements rather than restates.

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
- [Sprint 13.1: The amoebius symbolic checker 📋](#sprint-131-the-amoebius-symbolic-checker-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-12 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Answer the bound the explicit-state checker leaves, by discharging the same invariants to a solver.

**Phase scope:** one cohesive claim — *the same `Model` is discharged to a solver instead of enumerated, and the two routes agree on every fixture*. Agreement is what makes the second route usable rather than merely faster.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — the `Model` value, discharged here to a solver rather than enumerated. The edge is deliberately to the kernel and not to the explicit-state checker: the two are independent routes to one verdict, and chaining them would make each depend on the other's bugs.
**Gate:** `python3 tools/symbolic_checker_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored table of models with known inductive invariants, and of models where induction provably fails.
- **Committed mutants.** Mutants drop an induction hypothesis, translate a guard with the wrong polarity, and report unbounded from a bounded run.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in agreement with the explicit-state checker wherever both are applicable.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored table of models with known inductive invariants, and of models where induction provably fails.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md) — the rule behind the amoebius symbolic checker.

## Sprints

## Sprint 13.1: The amoebius symbolic checker 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored table of models with known inductive invariants, and of models where induction provably fails.
**Docs to update**: `documents/engineering/formal_model_doctrine.md`

### Objective

Answer the bound the explicit-state checker leaves, by discharging the same invariants to a solver.

### Deliverables

- A translation from the `Model` fragment to solver assertions, total over the fragment.
- Inductive invariant checking, so a proof can be unbounded where induction admits it.
- A verdict sharing the explicit-state checker's shape, over the same model digest.
- Agreement with the explicit-state checker wherever both are applicable.

### Validation

Both checkers must agree on every fixture within the bound, and an unbounded claim must carry its induction witness.

### Remaining Work

Everything. No solver encoding exists, and no induction schema has been stated.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md) — the rule behind the amoebius symbolic checker.
