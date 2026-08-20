# Phase 24: The generated conformance gate

> **Purpose**: A gate derived from an extension declaration, and the content-addressed verdict that admits it.
> **Read this if**: an extension has to be admitted to a link set, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: derive an extension's gate from its declaration, so an author cannot weaken what they never wrote.
Its first deliverable is an emitter producing the property, composition and compile-fail suites from a declaration, and this phase sits where the vocabulary it consumes first exists.
The rule behind the generated conformance gate is owned by [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 24.1: The generated conformance gate 📋](#sprint-241-the-generated-conformance-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-23 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

## Phase Summary

Derive an extension's gate from its declaration, so an author cannot weaken what they never wrote.

**Phase scope:** one cohesive claim — *the gate is derived from the declaration, so its author has no file to weaken*. The content-addressed verdict is what makes that derivation load-bearing rather than advisory.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 23](phase_23_extension_security_laws.md) — the last of the law families. The generator emits an instance of every law, so it opens only once the law set is complete.
**Gate:** `python3 tools/conformance_gate_generator_gate.py` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** An expected-suite inventory authored from the law text for one declaration, compared against what the emitter produces.
- **Committed mutants.** Mutants emit a suite missing one law, accept a verdict whose suite digest differs, and admit an unsealed extension.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in a coverage grid generated from the declared axes.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: an expected-suite inventory authored from the law text for one declaration, compared against what the emitter produces.


- **Extension conformance (§M.13).** Not applicable: this phase builds the contract.

## Doctrine adopted

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the rule behind the generated conformance gate.

## Sprints

## Sprint 24.1: The generated conformance gate 📋

**Status**: Planned
**Implementation**: planned module path; concrete when Done
**Blocked by**: None.
**Independent Validation**: An expected-suite inventory authored from the law text for one declaration, compared against what the emitter produces.
**Docs to update**: `documents/engineering/extension_conformance_doctrine.md`

### Objective

Derive an extension's gate from its declaration, so an author cannot weaken what they never wrote.

### Deliverables

- An emitter producing the property, composition and compile-fail suites from a declaration.
- A verdict sealing declaration digest, core version, suite digest and result.
- A link-set admission that has no constructor without a verdict.
- A coverage grid generated from the declared axes.

### Validation

A hand-modified suite must produce a different verdict, and an extension without a verdict must not enter the link set.

### Remaining Work

Everything. Nothing emits a suite from a declaration, and no verdict has been sealed.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the rule behind the generated conformance gate.
