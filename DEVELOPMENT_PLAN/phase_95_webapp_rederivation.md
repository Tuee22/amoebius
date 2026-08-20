# Phase 95: The multi-tenant web application re-derived

> **Purpose**: The web seed re-derived as a conforming extension whose insecure states have no inhabitant.
> **Read this if**: a multi-tenant application is being built on amoebius, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: re-derive the multi-tenant web application as a conforming extension whose insecure states have no inhabitant.
Its first deliverable is the gateway, identity, intent queue, cached socket tier and data plane as declared components, and this phase sits where the vocabulary it consumes first exists.
The rule behind the multi-tenant web application re-derived is owned by [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md), which this contract implements rather than restates.

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
- [Sprint 95.1: The multi-tenant web application re-derived 📋](#sprint-951-the-multi-tenant-web-application-re-derived-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-94 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Re-derive the multi-tenant web application as a conforming extension whose insecure states have no inhabitant.

**Phase scope:** one cohesive claim — *the cross-tenant states the seed can express have no inhabitant here*. The re-derivation is admissible only because that is a guarantee the seed's version does not carry.
**Substrate:** `linux-cpu`
**Lane:** `linux-cpu/amd64`
**Register:** 3
**Depends on:** [Phase 24](phase_24_conformance_gate_generator.md) — the generated gate and its verdict, without which this phase's conformance claim is its own author's reading, and [Phase 23](phase_23_extension_security_laws.md), whose S-laws are what foreclose the states this re-derivation exists to remove.
**Gate:** `python3 tools/webapp_rederivation_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** The seed survey's own findings, restated as an independently authored probe suite run against the re-derived application.
- **Committed mutants.** Mutants restore a caller-supplied tenant, a match-all filter default, and a locally rebuilt session.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a sealed conformance verdict discharging S1 through S6.
- **Fresh challenge.** A harness-issued nonce crosses the gateway, identity, intent queue, cached socket tier and data plane as declared components, and is recovered from an observer outside the system under test.


- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`, `S1`–`S6`; negatives under `test/negative/webapp_rederivation/`.

## Doctrine adopted

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the multi-tenant web application re-derived.

## Sprints

## Sprint 95.1: The multi-tenant web application re-derived 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: The seed survey's own findings, restated as an independently authored probe suite run against the re-derived application.
**Docs to update**: `documents/engineering/extension_conformance_security.md`

### Objective

Re-derive the multi-tenant web application as a conforming extension whose insecure states have no inhabitant.

### Deliverables

- The gateway, identity, intent queue, cached socket tier and data plane as declared components.
- Every route's handler typed at a scope obtained by authenticating.
- Every keyspace rendered by the one injective renderer.
- A sealed conformance verdict discharging S1 through S6.

### Validation

Each of the insecure states the seed survey found representable must have no inhabitant, witnessed by a compile-fail fixture.

### Remaining Work

Everything. No component of the web seed has been re-derived, and no verdict has been sealed for it.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the multi-tenant web application re-derived.
