# Phase 20: The extension declaration

> **Purpose**: An extension is a value declaring one component per calculus, inspectable before anything runs.
> **Read this if**: an extension is being written, or its obligation surface has to be read, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make an extension a value that declares one component per calculus, inspectable before it runs.
Its first deliverable is a declaration type with exactly five components and no optional arm, and this phase sits where the vocabulary it consumes first exists.
The rule behind the extension declaration is owned by [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 20.1: The extension declaration 📋](#sprint-201-the-extension-declaration-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-19 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Make an extension a value that declares one component per calculus, inspectable before it runs.

**Phase scope:** one cohesive claim — *an extension that has said what it does in five places has said everything the core needs*. One value, one component per calculus, and no informal second surface beside it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 10](phase_10_calculus_composition.md) — the five calculi and both indices, composed. A declaration carries one component per calculus, so it cannot be typed before all five exist and compose.
**Gate:** `python3 tools/extension_declaration_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored inventory for two extensions, written from their doctrine rather than from their code.
- **Committed mutants.** Mutants make a component optional, drop an index, and derive an artifact set that omits a declared recipe.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a reader that derives the extension's artifact, budget, layer, workflow and evidence sets.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored inventory for two extensions, written from their doctrine rather than from their code.


- **Extension conformance (§M.13).** Not applicable: this phase builds the contract.

## Doctrine adopted

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the rule behind the extension declaration.

## Sprints

## Sprint 20.1: The extension declaration 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored inventory for two extensions, written from their doctrine rather than from their code.
**Docs to update**: `documents/engineering/extension_conformance_doctrine.md`

### Objective

Make an extension a value that declares one component per calculus, inspectable before it runs.

### Deliverables

- A declaration type with exactly five components and no optional arm.
- The resource and scope indices threaded through each component.
- A digest over the declaration, so an extension has an identity.
- A reader that derives the extension's artifact, budget, layer, workflow and evidence sets.

### Validation

A declaration missing a component must not construct, and the derived sets must match an independently authored inventory.

### Remaining Work

Everything. No declaration type exists, and nothing has yet been expressed as an extension value.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the rule behind the extension declaration.
