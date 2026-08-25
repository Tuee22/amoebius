# Phase 38: Bounded UI-program schema

> **Purpose**: Admit bounded declarative UI programs through a total checker and expose only a
> constructor-private `CheckedUiProgram` to later UI phases.
> **Read this if**: the UI source algebra, graph checker, Haskell program-case corpus, or checked-program boundary
> has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_35_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_39_ui_authorization_kernel.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 38.1: Closed source algebra and total checker ⏸️](#sprint-381-closed-source-algebra-and-total-checker-)
- [Sprint 38.2: Independent semantics and rejection coverage ⏸️](#sprint-382-independent-semantics-and-rejection-coverage-)
- [Sprint 38.3: Calculus projection and phase seal ⏸️](#sprint-383-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 37, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

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

**Depends on:** [Phase 37](phase_37_transaction_vocabulary.md)
**Gate:** `pb validate phase 38`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — Haskell declarations admit bounded UI data before authorization, binding, planning, or effects; any Dhall projection or negative bytes are generated beneath `.build/**`. Browser and server behavior are not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 38` is future public spelling only. Before current human approval of Phase 51, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 37; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

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

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 38.1: Closed source algebra and total checker ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 37](phase_37_transaction_vocabulary.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 38.2: Independent semantics and rejection coverage ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 38.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 38.3: Calculus projection and phase seal ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 38.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Seal the bounded admission claim with the re-baselined calculus, natural-architecture proof, complete surface
join, and repository-local attestation.

### Deliverables

- One five-calculus composition over the phase's actual bounded counts.
- A gate with Darwin/Linux network observers, exact Haskell changed-subject mutant loci, generated-output containment, and lane
  declaration.
- A complete surface map retaining runtime and provider residues as UNVERIFIED.

### Validation

1. The calculus kind order, component names, counts, and resource vector match the separately authored Haskell oracle.
2. Normal and network-isolated executions pass; all six explicit Haskell changed-subject mutant executions fail exactly.
3. The universal surface, ledger, containment, write-guard, architecture, and attestation sides pass.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
