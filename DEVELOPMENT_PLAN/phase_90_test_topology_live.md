# Phase 90: The live test topology and elevated harness

> **Purpose**: A self-tearing-down topology runs against the live platform under the elevated harness.
> **Read this if**: a test has to run against the live platform and leave nothing behind, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: run a self-tearing-down topology against the live platform under the elevated harness.
Its first deliverable is a topology value spinning resources up, running a workflow, and tearing them down, and this phase sits where the vocabulary it consumes first exists.
The rule behind the live test topology and elevated harness is owned by [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 90.1: The live test topology and elevated harness 📋](#sprint-901-the-live-test-topology-and-elevated-harness-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-89 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Run a self-tearing-down topology against the live platform under the elevated harness.

**Phase scope:** one cohesive claim — *the topology tears itself down, and the harness is the only thing permitted to delete test-owned durable storage*. Each generated test is locked to one substrate chosen when it is generated.
**Substrate:** `linux-cpu`
**Lane:** `linux-cpu/amd64`
**Register:** 3
**Depends on:** [Phase 48](phase_48_test_workflow_algebra.md) — the pure topology values this phase runs, and the live platform they are run against. It cannot precede the platform it exercises, which is what moved it here.
**Gate:** `python3 tools/test_topology_live_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** An independent provider inventory collector, authenticated separately from the harness under test.
- **Committed mutants.** Mutants skip a teardown arm, delete unflagged state, and report success from an incomplete cycle.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a suggest-test derivation from the declared surface.
- **Fresh challenge.** A harness-issued nonce crosses a topology value spinning resources up, running a workflow, and tearing them down, and is recovered from an observer outside the system under test.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the rule behind the live test topology and elevated harness.

## Sprints

## Sprint 90.1: The live test topology and elevated harness 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: An independent provider inventory collector, authenticated separately from the harness under test.
**Docs to update**: `documents/engineering/testing_doctrine.md`

### Objective

Run a self-tearing-down topology against the live platform under the elevated harness.

### Deliverables

- A topology value spinning resources up, running a workflow, and tearing them down.
- The elevated harness as the only actor permitted to delete test-flagged state.
- A leak check over provider inventory before and after each cycle.
- A suggest-test derivation from the declared surface.

### Validation

Repeated cycles must leave provider inventory byte-identical, observed by a collector outside the harness.

### Remaining Work

Everything. No topology has been generated, and no elevated harness exists to run one.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the rule behind the live test topology and elevated harness.
