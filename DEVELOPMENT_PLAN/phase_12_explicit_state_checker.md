# Phase 12: The amoebius explicit-state checker

> **Purpose**: An amoebius-owned explicit-state model checker over the Model value, replacing an external one.
> **Read this if**: a model has to be checked without trusting a tool amoebius does not maintain, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: own the explicit-state checker, so a recorded proof cannot be invalidated by somebody else's release.
Its first deliverable is a reachability search over the `Model` value with a declared bound, and this phase sits where the vocabulary it consumes first exists.
The rule behind the amoebius explicit-state checker is owned by [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md), which this contract implements rather than restates.

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
- [Sprint 12.1: The amoebius explicit-state checker 📋](#sprint-121-the-amoebius-explicit-state-checker-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-11 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Own the explicit-state checker, so a recorded proof cannot be invalidated by somebody else's release.

**Phase scope:** one cohesive claim — *amoebius owns the checker its own proofs rest on*. Enumeration, the counterexample trace, and the retirement of the external tool are one claim about who maintains the thing the evidence depends on.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 11](phase_11_formal_model_kernel.md) — the `Model` value this checker enumerates.
**Gate:** `python3 tools/explicit_state_checker_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored expected-verdict table over small models whose reachable sets were enumerated by hand.
- **Committed mutants.** Mutants weaken a guard, drop an invariant clause, and truncate the frontier early.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in parity with the in-process explorer on every fixture model.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored expected-verdict table over small models whose reachable sets were enumerated by hand.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md) — the rule behind the amoebius explicit-state checker.

## Sprints

## Sprint 12.1: The amoebius explicit-state checker 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored expected-verdict table over small models whose reachable sets were enumerated by hand.
**Docs to update**: `documents/engineering/formal_model_doctrine.md`

### Objective

Own the explicit-state checker, so a recorded proof cannot be invalidated by somebody else's release.

### Deliverables

- A reachability search over the `Model` value with a declared bound.
- Invariant and deadlock reporting with a minimal counterexample trace.
- A verdict value binding the model digest, the bound, and the result.
- Parity with the in-process explorer on every fixture model.

### Validation

The checker and the in-process explorer must reach the same verdict on every fixture, and a violating model must yield a replayable trace.

### Remaining Work

Everything. Nothing enumerates a state space inside amoebius, and no trace is replayable from one.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`formal_model_doctrine.md`](../documents/engineering/formal_model_doctrine.md) — the rule behind the amoebius explicit-state checker.
