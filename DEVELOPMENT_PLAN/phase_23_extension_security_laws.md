# Phase 23: The security laws S1-S6

> **Purpose**: Attestation as an index, the skolem scope, refusal by default, and injective derived namespaces.
> **Read this if**: an extension touches identity, tenancy, or a secret, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make the insecure states of a real multi-tenant application unrepresentable rather than checked for.
Its first deliverable is an attested-versus-claimed identity index whose only introduction is verification, and this phase sits where the vocabulary it consumes first exists.
The rule behind the security laws S1-S6 is owned by [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 23.1: The security laws S1-S6 📋](#sprint-231-the-security-laws-s1-s6-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-22 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Make the insecure states of a real multi-tenant application unrepresentable rather than checked for.

**Phase scope:** one cohesive claim — *an insecure state has no inhabitant, rather than a check that catches one*. Three of the six sharpen an existing law and three do not, so this phase also owes the compositional residue that follows.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 21](phase_21_extension_laws_per_extension.md) — L1–L5, which S2, S3 and S5 sharpen at a particular seam. The other three add obligations no per-extension law reaches, so this phase is not a corollary of its predecessor.
**Gate:** `python3 tools/extension_security_laws_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A two-tenant two-subject oracle authored independently, exercising read, update, delete, replay and cache lookup across scopes.
- **Committed mutants.** Mutants drop the subject predicate, trust a caller-supplied scope, key a cache by resource id alone, and distinguish the two refusals.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in one injective renderer for every scope-derived keyspace.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a two-tenant two-subject oracle authored independently, exercising read, update, delete, replay and cache lookup across scopes.


- **Extension conformance (§M.13).** Not applicable: this phase builds the contract.

## Doctrine adopted

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the security laws S1-S6.

## Sprints

## Sprint 23.1: The security laws S1-S6 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A two-tenant two-subject oracle authored independently, exercising read, update, delete, replay and cache lookup across scopes.
**Docs to update**: `documents/engineering/extension_conformance_security.md`

### Objective

Make the insecure states of a real multi-tenant application unrepresentable rather than checked for.

### Deliverables

- An attested-versus-claimed identity index whose only introduction is verification.
- A rank-2 request-scope eliminator minting a fresh scope variable per request.
- A refusal value indistinguishable between a foreign and an absent resource.
- One injective renderer for every scope-derived keyspace.

### Validation

Cross-scope probes must return byte-identical refusals with no mutation, and every transposition fixture must fail to compile.

### Remaining Work

Everything. No skolem combinator, attested index, or indistinguishable refusal envelope exists.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the security laws S1-S6.
