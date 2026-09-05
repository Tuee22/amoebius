# Phase 37: Bounded UI-program schema

> **Purpose**: Admit bounded declarative UI programs through a total checker and expose only a
> constructor-private `CheckedUiProgram` to later UI phases.
> **Read this if**: the UI source algebra, graph checker, Haskell program-case corpus, or checked-program boundary
> has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 37.1: Closed source algebra and total checker](#sprint-371-closed-source-algebra-and-total-checker-)
- [Sprint 37.2: Independent semantics and rejection coverage](#sprint-372-independent-semantics-and-rejection-coverage-)
- [Sprint 37.3: Calculus projection and phase seal](#sprint-373-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 36, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

## Phase Summary

**Target capability — NOT VALIDATED.** A Haskell `UiSource` model is to project a closed Dhall input shape
beneath `.build/**` for external application values. It carries tenant mode, finite modules/nodes, and named
external-link requirements; no tracked Dhall, JavaScript, HTML, CSS, raw URL, provider coordinate, or
credential is repository-owned UI source. Haskell decoding feeds one total Haskell checker.

The target checker qualifies node identities, refuses duplicate or missing references, detects graph cycles, enforces
finite collection bounds, unifies port types, checks exhaustive event branches, and prevents server-private
values from entering a public projection. Successful checking produces a normalized, constructor-private
`CheckedUiProgram`; later phases can inspect its bounded graph but cannot forge it.

**Phase scope:** one target claim — an application UI is bounded declarative data whose complete structural
admission precedes every scope, authorization, binding, plan, and runtime effect. Any request identity,
authorization decision, handler binding, plan emission, browser interpretation, or server dispatch splits out.

**Substrate:** `none` — Haskell decode, graph checking, compiler barriers, properties, and calculus
composition are pure; the canonical Haskell gate contacts no browser, provider, credential, or cluster
([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `none` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure/generative: semantic tables and negative controls constrain the decision boundary;
browser, server, identity-provider, and storage-provider enforcement remain UNVERIFIED
([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 36](phase_36_transaction_vocabulary.md)
**Gate:** `pb validate phase 37`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-bounded-ui-program-schema` |
| `Subject` | `acquired-ui-program-schema-supervisor` |
| `Command` | `pb validate phase 37` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-ui-program-schema-oracle` |
| `Positive controls` | `ui-program-schema-positive-controls` |
| `Paired negatives` | `exact-ui-program-schema-negatives` |
| `Mutants` | `applied-ui-program-schema-production-mutants` |
| `Discovery` | `exact-ui-program-schema-source-discovery` |
| `Challenge` | `post-acquisition-ui-program-schema-challenge` |
| `Observer` | `ui-program-schema-process-observation` |
| `Authority/bypass` | `no-pb-network-browser-host-hardware-or-parallelism` |
| `Freshness` | `fresh-ui-program-schema-build-root-and-stable-source` |
| `Qualification` | `qualified-ui-program-schema-harness` |
| `Cleanroom` | `ui-program-schema-products-contained-below-build` |
| `Legacy closure` | `retired-ui-program-schema-authorities-absent` |
| `Predecessor` | `exact-phase-thirty-six-receipt` |
| `Residue` | `ui-runtime-and-provider-owners-explicit` |
| `Pass criterion` | `qualified-phase-thirty-seven-gate-pass` |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4 — The external Dhall surface](../documents/engineering/low_code_ui_runtime_doctrine.md#4-the-external-dhall-surface):
  the UI language is finite external/untracked data with no arbitrary browser or network language; Haskell
  generates every repository-owned example beneath `.build/**`.
- [`low_code_ui_runtime_doctrine.md` §5 — gadt-decode and the checked Haskell IR](../documents/engineering/low_code_ui_runtime_doctrine.md#5-gadt-decode-and-the-checked-haskell-ir):
  checking is total and only successful admission creates the private checked value.
- [`low_code_ui_runtime_doctrine.md` §6 — Modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition):
  qualified identities and deterministic merge replace textual inclusion.
- [`low_code_ui_runtime_doctrine.md` §7 — State, events, and deterministic updates](../documents/engineering/low_code_ui_runtime_doctrine.md#7-state-events-and-deterministic-updates):
  event tables and collections are finite and exhaustive.
- [`dsl_doctrine.md` §2 — Two languages, one system: Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
  Dhall describes the program while Haskell owns the admission logic.
- [`generated_artifacts_doctrine.md` §5 — Authored vs generated](../documents/engineering/generated_artifacts_doctrine.md):
  Haskell-authored semantic inputs constrain per-run derived output; rendered wire bytes are not repository authority.

---

## Sprints

> **Historical sprint results.** Earlier completion statements in sprint prose are capability inventory only; current completion remains owned by the integrated gate.

## Sprint 37.1: Closed source algebra and total checker ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/{Source,Check}.hs`, `test/spec/ui/{UiProgramSchemaCases,UiProgramSchemaSpec,UiProgramSchemaOracle}.hs`, the compiler twins, and the package-hidden Phase-37 supervisor own this sprint surface.
**Blocked by**: [Phase 36](phase_36_transaction_vocabulary.md) gate pass
**Independent Validation**: one clean Haskell semantic suite, two compiler-barrier rows, and six production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/UiProgramSchemaOracle.hs` independently fixes thirteen exact case outcomes, three program projections, three graph projections, four calculus rows, two compiler outcomes, six mutant loci, and thirty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, five serialized oracle/fixture tables, and six materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/DSL/generated-artifact doctrines.

### Objective

Adopt the bounded source and checked-IR doctrines; make executable escape hatches absent and structural
admission total.

### Deliverables

- Closed tenant, node-kind, and value-type unions plus finite module/node records.
- A deterministic decoder and normalizer with no raw browser or authority arm.
- A private checked-program constructor and total graph/type/bounds/event/projection folds.

### Validation

1. All three positives decode/check and all ten negatives reject at their exact layer, tag, and span.
2. The forbidden-arm, totality-token, and constructor-export scans pass.
3. The legal compiler twin builds and the illegal construction fails for the pinned reason.

### Remaining Work

The complete integrated Phase-37 gate and its mechanical status projection remain. Authorization, binding, planning, browser/server execution, provider enforcement, and hardware remain later-owned residue.

## Sprint 37.2: Independent semantics and rejection coverage ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/{Source,Check}.hs`, `test/spec/ui/{UiProgramSchemaCases,UiProgramSchemaSpec,UiProgramSchemaOracle}.hs`, the compiler twins, and the package-hidden Phase-37 supervisor own this sprint surface.
**Blocked by**: Sprint 37.1
**Independent Validation**: one clean Haskell semantic suite, two compiler-barrier rows, and six production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/UiProgramSchemaOracle.hs` independently fixes thirteen exact case outcomes, three program projections, three graph projections, four calculus rows, two compiler outcomes, six mutant loci, and thirty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, five serialized oracle/fixture tables, and six materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/DSL/generated-artifact doctrines.

### Objective

Constrain the admission meaning with independent semantic facts and falsifiable negative controls rather than a
snapshot of derived bytes.

### Deliverables

- Three authored program-semantic rows and three independent graph rows.
- Ten exact diagnostics and eight generated rejection classes with coverage floors.
- Six Haskell-registered paired changed-subject mutants and a complete 30-entry validation-locus inventory.

### Validation

1. Program and graph projections join their authored tables in both directions.
2. Two repeated decodes/checks agree without becoming the semantic oracle.
3. The retired normalized-wire golden is absent and every paired Haskell changed-subject mutant reaches only
   its named locus; any serialized mutation is generated lazily beneath `.build/**`.

### Remaining Work

The complete integrated Phase-37 gate and its mechanical status projection remain. Authorization, binding, planning, browser/server execution, provider enforcement, and hardware remain later-owned residue.

## Sprint 37.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/{Source,Check}.hs`, `test/spec/ui/{UiProgramSchemaCases,UiProgramSchemaSpec,UiProgramSchemaOracle}.hs`, the compiler twins, and the package-hidden Phase-37 supervisor own this sprint surface.
**Blocked by**: Sprint 37.2
**Independent Validation**: one clean Haskell semantic suite, two compiler-barrier rows, and six production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/UiProgramSchemaOracle.hs` independently fixes thirteen exact case outcomes, three program projections, three graph projections, four calculus rows, two compiler outcomes, six mutant loci, and thirty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, five serialized oracle/fixture tables, and six materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/DSL/generated-artifact doctrines.

### Objective

Seal the bounded admission claim with the re-baselined calculus, natural-architecture proof, complete surface
join, and repository-local run record.

### Deliverables

- One five-calculus composition over the phase's actual bounded counts.
- A gate with Darwin/Linux network observers, exact Haskell changed-subject mutant loci, generated-output containment, and lane
  declaration.
- A complete surface map retaining runtime and provider residues as UNVERIFIED.

### Validation

1. The calculus kind order, component names, counts, and resource vector match the separately authored Haskell oracle.
2. Normal and network-isolated executions pass; all six explicit Haskell changed-subject mutant executions fail exactly.
3. The universal surface, ledger, containment, write-guard, architecture, and run-record sides pass.

### Remaining Work

The complete integrated Phase-37 gate and its mechanical status projection remain. Authorization, binding, planning, browser/server execution, provider enforcement, and hardware remain later-owned residue.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the bounded checked-graph evidence while
  retaining runtime claims as UNVERIFIED.
- `documents/engineering/dsl_doctrine.md` — record the checked `UiSource` specialization of Gate 1/2.
- `documents/engineering/generated_artifacts_doctrine.md` — replace the wire-table language with the semantic
  Haskell program oracle and retain the no-generated-output rule.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — record the seal, `none` substrate/lane, concrete gate, and honest
  live residues.

---

## Related Documents

- [Development Plan Tracker](README.md) — the phase order and current status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, one-substrate discipline, and gate integrity.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the source algebra and checked IR.
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the shared Dhall/Haskell admission discipline.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — semantic-oracle and generated-output ownership.
- [Illegal-State Techniques](../documents/illegal_state/illegal_state_techniques.md) — closed sums, private constructors, bounded values, and total folds.
