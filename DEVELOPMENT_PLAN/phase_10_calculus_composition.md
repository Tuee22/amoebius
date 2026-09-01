# Phase 10: Composition across the five calculi

> **Purpose**: Specify the target Haskell capability to provide a total Haskell composition boundary
> that preserves the Phase 8 request-scope index and combines the Phase 9 resource index across all
> five core calculi.
> **Read this if**: two calculus components must be combined, a component transform must retain its indices,
> or the boundary between base composition and later extension-law conformance must be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 10.1: Index-preserving five-calculus composition](#sprint-101-index-preserving-five-calculus-composition-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 9, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to provide a total Haskell composition boundary that preserves the Phase 8
request-scope index and combines the Phase 9 resource index across all five core calculi.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — provide a total Haskell composition boundary that
preserves the Phase 8 request-scope index and combines the Phase 9 resource index across all five
core calculi. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 9](phase_09_resource_index.md)
**Gate:** `pb validate phase 10`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target capability only — provide a total Haskell composition boundary that preserves the Phase 8 request-scope index and combines the Phase 9 resource index across all five core calculi. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 10` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 09; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

**This phase owns its compile-negative evidence.** Each illegal twin below requires a phase-local, source-bound
GHC invocation, a minimally different positive control, and a separately authored exact-diagnostic oracle.
[Phase 15](phase_15_compile_fail_harness.md) later consolidates reusable compile-fail machinery; it is not a
prerequisite of this earlier gate. Until the local runner and oracle exist, these rows remain `UNRESOLVED`.

## Doctrine adopted

- [`extension_conformance_laws.md` C2 — Identity](../documents/engineering/extension_conformance_laws.md#c2-identity): the request-indexed empty composition is a two-sided identity.
- [`extension_conformance_laws.md` C3 — Associativity](../documents/engineering/extension_conformance_laws.md#c3-associativity): grouping never changes component order, names, or the derived resource fold.
- [`extension_conformance_laws.md` C5 — Budget additivity](../documents/engineering/extension_conformance_laws.md#c5-budget-additivity): the base resource requirement is the exact sum of its components.
- [`extension_conformance_laws.md` C6 — Scope conjunction](../documents/engineering/extension_conformance_laws.md#c6-scope-conjunction): composition accepts one request-scope index and never widens it.
- [`extension_conformance_doctrine.md` §7 — Link-time union closure](../documents/engineering/extension_conformance_doctrine.md#7-link-time-union-closure): pair/triple tests remain evidence rather than the missing universal C1 proof.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): run-time surfaces and generated cases join to independent expectations.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 10.1: Index-preserving five-calculus composition ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 9](phase_09_resource_index.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

### Objective

Adopt C2, C3, C5, and C6 at the base calculus/index boundary: compose any two of the five component arms only
at one request scope, preserve their payloads and order, and derive the exact resource sum.

### Deliverables

- A closed `Calculus` enumeration and private five-arm `Component scope` over real calculus payloads.
- Scope-requiring constructors, same-scope `compose`, identity, associative `append`, and index-preserving
  label transform operations.
- An exact `Natural` resource fold over the Phase-9 four-axis vector.
- A 25-row independent ordered-pair oracle and exhaustive 125-triple composition corpus.
- Three 500-case coverage-bound generated properties.
- One same-scope/different-scope compiler pair pinned to the rank-2 mismatch.
- Three registry-backed real mutants for scope, arithmetic, and transform weakening.
- A contained Register-1 gate with architecture, surface, ledger, and source-bound evidence.

### Validation

1. Require the oracle to enumerate each ordered calculus pair exactly once and the suite to construct every
   pair in the stated order with its exact four-axis sum.
2. Exhaust all 125 kind triples for associativity and both identity directions for every component.
3. Run 500 generated cases per numeric additivity, associativity, and transform property with declared
   constructor coverage.
4. Compile the same-scope twin, reject the different-scope twin at the rigid type mismatch, and require the
   weakened signature to make that negative compile.
5. Require the saturation and transform mutants to fail at their named property loci, then restore and rerun
   the clean build.
6. Join all metrics and checks to 18 authored surfaces, keep outputs generated, and bind the result to the
   natural architecture and complete source snapshot.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `extension_conformance_doctrine.md` — distinguish the built base operator from the unbuilt extension
  declaration, generated gate, verdict, and C1 proof.
- `extension_conformance_laws.md` — record the finite Phase-10 instances of C2, C3, C5, and C6 without
  claiming the Phase-22 extension-law discharge.
- `testing_doctrine.md` — record finite exhaustion, sampled numeric properties, the compiler barrier, and the
  runtime residue.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile status, sequence,
  component paths, and evidence.
- `DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md` — consume the sealed algebra before the proof stack.
- `DEVELOPMENT_PLAN/phase_20_extension_declaration.md` and Phase 22 — retain the later declaration and
  arbitrary-extension law boundaries.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — the phase and gate contract.
- [Gate Integrity](development_plan_gate_integrity.md) and [Phase Model](development_plan_phase_model.md) — universal gate and sequencing rules.
- [Development Plan Tracker](README.md) — numeric order and current status.
- [Overview](overview.md) and [System Components](system_components.md) — algebra placement and concrete inventory.
- [Artifact](phase_03_artifact_calculus.md), [Budget](phase_04_budget_calculus.md), [Lift](phase_05_lift_calculus.md), [Workflow](phase_06_workflow_calculus.md), and [Evidence](phase_07_evidence_calculus.md) — the five payload owners.
- [Scope Index](phase_08_scope_index.md) and [Resource Index](phase_09_resource_index.md) — the two indices composition preserves.
- [Extension Declaration](phase_20_extension_declaration.md) and [Compositional Laws](phase_22_extension_laws_compositional.md) — later open-extension consumers.
- [Generic Browser Interpreter](phase_42_ui_browser_interpreter.md) — later pure Haskell interpreter semantics
  and a lazy `.build/**` browser-language projection; no browser process is part of its claim.
- [UI-Server Boundary](phase_43_ui_server_boundary.md) — a later Haskell protocol and authorization boundary
  observed through Haskell-owned fakes, with browser and live-service behavior deferred.
- [Local UI Composition](phase_44_ui_local_composition.md) — later composition of the Haskell client/server
  semantics across fake data, workflow, artifact, and coordination boundaries only.
- [Encrypted Browser Offline Runtime](phase_45_encrypted_browser_runtime.md) — later pure Haskell offline-state
  and envelope semantics with a lazy `.build/**` runtime projection; Chrome and all browser fidelity remain
  explicitly unverified.
- [Extension Conformance Doctrine](../documents/engineering/extension_conformance_doctrine.md) and [Laws](../documents/engineering/extension_conformance_laws.md) — normative composition claims and honesty boundary.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — Register-1, finite exhaustion, and sampled-property discipline.
