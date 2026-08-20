# Phase 46: Generated browser contracts and bundle

> **Purpose**: PureScript contracts, codecs and the one generic bundle become recipes rather than authored source.
> **Read this if**: a browser contract, codec, or bundle is being changed, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make the browser contract surface a recipe rather than authored source.
Its first deliverable is contracts and codecs rendered from the checked public boundary, and this phase sits where the vocabulary it consumes first exists.
The rule behind generated browser contracts and bundle is owned by [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md), which this contract implements rather than restates.

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
- [Sprint 46.1: Generated browser contracts and bundle 📋](#sprint-461-generated-browser-contracts-and-bundle-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-45 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Make the browser contract surface a recipe rather than authored source.

**Phase scope:** one cohesive claim — *the browser surface is rendered from the UI types rather than authored beside them*. What stays authored is the oracle each rendered contract is checked against.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 40](phase_40_ui_plan_compiler.md) — the UI plan compiler, whose emitted plan is the declaration these contracts are rendered from, and through it the bounded UI-program schema. The encrypted browser runtime at its numeric predecessor is a consumer of this phase, not a supplier to it.
**Gate:** `python3 tools/ui_contract_generation_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored contract inventory derived from the Haskell boundary types, written apart from the renderer.
- **Committed mutants.** Mutants add a raw sink to the catalog, serialize a server handle, and emit a codec the boundary does not declare.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in an artifact scanner independent of the generator.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored contract inventory derived from the Haskell boundary types, written apart from the renderer.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md) — the rule behind generated browser contracts and bundle.

## Sprints

## Sprint 46.1: Generated browser contracts and bundle 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: A hand-authored contract inventory derived from the Haskell boundary types, written apart from the renderer.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Make the browser contract surface a recipe rather than authored source.

### Deliverables

- Contracts and codecs rendered from the checked public boundary.
- One generic bundle per runtime ABI, addressed by content.
- A build that writes only beneath the ignored build tree.
- An artifact scanner independent of the generator.

### Validation

Two renders must agree byte for byte, and the scanner must find no executable inline content or provider coordinate.

### Remaining Work

Everything. No contract, codec or bundle is emitted from a declaration.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md) — the rule behind generated browser contracts and bundle.
