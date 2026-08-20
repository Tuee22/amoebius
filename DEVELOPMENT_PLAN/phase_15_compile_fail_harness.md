# Phase 15: The compile-fail fixture harness

> **Purpose**: Every unrepresentability claim names a fixture that fails to compile for its pinned reason.
> **Read this if**: an unrepresentability claim has to be made checkable, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make a claim of unrepresentability carry the fixture that proves it, failing for its pinned reason.
Its first deliverable is a fixture format pairing a source that must not compile with the exact diagnostic it must produce, and this phase sits where the vocabulary it consumes first exists.
The rule behind the compile-fail fixture harness is owned by [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 15.1: The compile-fail fixture harness 📋](#sprint-151-the-compile-fail-fixture-harness-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-14 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Make a claim of unrepresentability carry the fixture that proves it, failing for its pinned reason.

**Phase scope:** one cohesive claim — *a fixture failing for the wrong reason is worse than no fixture at all*. Pinning each failure to its reason is the deliverable; collecting the fixtures is the easy half of it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 7](phase_07_evidence_calculus.md) — the evidence calculus, which states the claim-to-fixture binding this harness mechanises for the compile-fail kind.
**Gate:** `python3 tools/compile_fail_harness_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored fixture set whose expected diagnostics were written before the surfaces they probe.
- **Committed mutants.** Mutants accept any compile failure, drop a positive counterpart, and pin a diagnostic that cannot occur.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a positive counterpart per fixture, differing only in the foreclosed dimension.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored fixture set whose expected diagnostics were written before the surfaces they probe.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the rule behind the compile-fail fixture harness.

## Sprints

## Sprint 15.1: The compile-fail fixture harness 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored fixture set whose expected diagnostics were written before the surfaces they probe.
**Docs to update**: `documents/engineering/testing_doctrine.md`

### Objective

Make a claim of unrepresentability carry the fixture that proves it, failing for its pinned reason.

### Deliverables

- A fixture format pairing a source that must not compile with the exact diagnostic it must produce.
- A runner asserting failure for the pinned reason rather than any failure.
- A registry joining each fixture to the claim it discharges.
- A positive counterpart per fixture, differing only in the foreclosed dimension.

### Validation

A fixture that fails for a different reason must be reported as a defect, not a pass.

### Remaining Work

Everything. Nothing pins a fixture's failure reason, and no claim is bound to one.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the rule behind the compile-fail fixture harness.
