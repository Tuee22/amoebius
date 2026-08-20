# Phase 21: The per-extension laws L1-L5

> **Purpose**: Totality, determinism, budget honesty, scope propagation and evidence, each mechanically discharged.
> **Read this if**: one extension's obligations have to be stated or discharged, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: discharge the five per-extension laws mechanically, so conformance is decided rather than reviewed.
Its first deliverable is a property suite per law, instantiated over the extension's own declared vocabulary, and this phase sits where the vocabulary it consumes first exists.
The rule behind the per-extension laws L1-L5 is owned by [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, DEVELOPMENT_PLAN/phase_23_extension_security_laws.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 21.1: The per-extension laws L1-L5 📋](#sprint-211-the-per-extension-laws-l1-l5-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-20 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Discharge the five per-extension laws mechanically, so conformance is decided rather than reviewed.

**Phase scope:** one cohesive claim — *each law names one way a single extension fails to be a function of its declared inputs, and each has a mechanical discharge*. A law whose discharge is a reading does not belong in this set.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 20](phase_20_extension_declaration.md) — the declaration each law is instantiated over.
**Gate:** `python3 tools/extension_laws_per_extension_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A per-law expected-verdict table authored from the law text, over extensions written to violate exactly one law each.
- **Committed mutants.** Mutants weaken one law's property, skip an inapplicable-marked clause, and pass a partial function under L1.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a claim-to-fixture join for L5, reusing the compile-fail harness.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a per-law expected-verdict table authored from the law text, over extensions written to violate exactly one law each.


- **Extension conformance (§M.13).** Not applicable: this phase builds the contract.

## Doctrine adopted

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the per-extension laws L1-L5.

## Sprints

## Sprint 21.1: The per-extension laws L1-L5 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A per-law expected-verdict table authored from the law text, over extensions written to violate exactly one law each.
**Docs to update**: `documents/engineering/extension_conformance_laws.md`

### Objective

Discharge the five per-extension laws mechanically, so conformance is decided rather than reviewed.

### Deliverables

- A property suite per law, instantiated over the extension's own declared vocabulary.
- A wildcard-arm scan and an ambient-source scan for L1 and L2.
- A budget reachability check for L3 and a flow relation for L4.
- A claim-to-fixture join for L5, reusing the compile-fail harness.

### Validation

Each law must fail for an extension seeded to violate it, and pass for one that does not.

### Remaining Work

Everything. No law is stated as a property, and nothing instantiates one over a declaration.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the per-extension laws L1-L5.
