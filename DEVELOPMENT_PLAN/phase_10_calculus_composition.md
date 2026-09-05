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

✅ Done.

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

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-10 semantic payload, package-hidden serial
supervisor, Haskell-owned exhaustive oracle, scope compile pair, and three changed-production subjects are
complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The pure base operator composes all five closed calculus arms at one request scope while preserving order, payloads, names, and the exact Phase-9 resource index. |
| `Subject` | `Amoebius.Calculus.Composition` is acquired only through package-hidden `Amoebius.Validation.CalculusCompositionRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 10`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly and synchronously. |
| `Oracle` | `CalculusCompositionSpec.hs` owns a closed 25-row expectation, 125 triples, both identities, payload/transform checks, and three coverage-bound properties without reading behavioral data. |
| `Positive controls` | The clean oracle and same-scope compiler twin succeed; all five constructors and every ordered pair occur. |
| `Paired negatives` | The minimally different nested-request twin fails at the rigid scope mismatch while its same-scope twin compiles. |
| `Mutants` | Resource saturation and transform-index loss compile but turn the unchanged oracle red; scope widening compiles the unchanged illegal twin. |
| `Discovery` | One production module, one oracle module, and two compiler twins are discovered from the Git snapshot and equal the fixed four-file inventory bidirectionally. |
| `Challenge` | All three production mutations execute after source acquisition and must be distinguished at their assigned independent observations. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | Pure-source and closed-model scans pass; `pb`, network, hardware, live services, compiler substitution, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-10/work/**` root and the dispatcher requires equal opening/closing source identities. |
| `Qualification` | Clean controls, the exact compiler pair, source discipline, and all three changed-production subjects pass together. |
| `Cleanroom` | Every binary, interface, object, stub, and transcript is generated lazily beneath the fresh run root. |
| `Legacy closure` | Phase 10 owns no legacy-debt identifier; all non-circular prerequisites pass while later-owned source debt remains residue. |
| `Predecessor` | Consume exactly one durable Phase-9 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Formal models, extension declarations and laws, decode, effects, runtimes, hardware, and cleanup remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-ten-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

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

## Sprint 10.1: Index-preserving five-calculus composition ✅

**Status**: Done
**Implementation**: `src/calculus-composition/Amoebius/Calculus/Composition.hs`; package-hidden supervisor `src/validation-kernel/Amoebius/Validation/CalculusCompositionRun/Internal.hs`
**Blocked by**: [Phase 9](phase_09_resource_index.md) gate pass
**Independent Validation**: 25 ordered pairs, 125 triples, three 500-case properties, one exact compiler pair, and three applied production mutations
**Oracle**: `test/spec/calculus/CalculusCompositionSpec.hs`, separately authored in Haskell against public production interfaces
**Legacy IDs**: none; later-owned tracked-source debt remains in the typed central registry
**Docs to update**: this phase file, `extension_conformance_doctrine.md`, `extension_conformance_laws.md`, `testing_doctrine.md`, and `system_components.md`

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

Run the complete integrated gate and apply only its authorized mechanical status projection. Formal models,
extension declarations and laws, decode, effect, runtime, hardware, and cleanup claims remain assigned to later owners.

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
