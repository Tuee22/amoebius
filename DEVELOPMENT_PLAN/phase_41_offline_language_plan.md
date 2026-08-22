# Phase 41: Offline language and paired plans

> **Purpose**: Make offline continuity an explicit bounded application contract and compile it into matching
> public-client and private-server replay plans without exposing browser or Redis mechanisms in the DSL.
> **Read this if**: the Phase-41 language boundary or a later offline-runtime dependency must be understood.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 41.1: Author the continuity language ⏸️](#sprint-411-author-the-continuity-language-)
- [Sprint 41.2: Compile paired offline plans ⏸️](#sprint-412-compile-paired-offline-plans-)
- [Sprint 41.3: Seal the pure boundary ⏸️](#sprint-413-seal-the-pure-boundary-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 40, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** Haskell is to add
`UiSource.continuity = OnlineOnly | Offline OfflineSource`. Its closed source types name cached
projections, queueable ports, local blob classes, and an offline view. Every queueable port carries finite
count, byte, and age bounds plus local validation, idempotency, conflict, ordering, dependency, and current
authority semantics. The target compiler retains equal queue, projection, and blob key sets in the public
client and private replay plans. Any browser-language projection is generated beneath `.build/**`; it is not
tracked source.

The target Haskell declarations permit only infernix workflow start and jitML training start to
queue. Workflow progress is a cached projection; ML signals, workflow cancellation, and model invocation
remain online-only.

**Phase scope:** one target claim — offline continuity is a bounded Haskell application contract compiled into
deterministic paired plans, not a browser or server-storage mechanism.
**Substrate:** `none` — the gate is pure and provisions no runtime resource.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure Haskell/type-level target only.
**Depends on:** [Phase 40](phase_40_ui_plan_compiler.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 41`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — offline continuity is a bounded Haskell application contract compiled into deterministic paired plans; generated browser-language bytes remain beneath `.build/**`, and no browser/storage behavior is claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 41` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 40 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §3 — The external continuity surface](../documents/engineering/browser_offline_runtime_doctrine.md#3-the-external-continuity-surface): applications name offline semantics, not mechanisms.
- Adopt [`browser_offline_runtime_doctrine.md` §4 — Queueable ports are a stricter port class](../documents/engineering/browser_offline_runtime_doctrine.md#4-queueable-ports-are-a-stricter-port-class): queueability requires the complete bounded replay contract.
- Adopt [`browser_offline_runtime_doctrine.md` §5 — One bound program, paired online and offline plans](../documents/engineering/browser_offline_runtime_doctrine.md#5-one-bound-program-paired-online-and-offline-plans): public and private plan key sets cannot drift.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 41.1: Author the continuity language ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt the authored continuity surface and make its complete bounded queue terms part of every decoded source.

### Deliverables

- One closed Dhall/Haskell continuity mirror shared by the DSL and offline compiler components.
- Product declarations for one online-only case and the initial infernix/jitML offline cases.
- Thirteen structured refusal cases covering every missing bound or semantic term and every online-only arm.

### Validation

1. Decode all three product declarations and compare their normalized contract rows with the authored table.
2. Require every malformed or forbidden queue case to return its exact structured tag.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 41.2: Compile paired offline plans ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt paired offline-plan projection so a public queued/cached/blob key cannot exist without its private replay
counterpart.

### Deliverables

- A total validator for finite queue bounds, complete semantics, and the closed operation classification.
- Deterministic client and replay plans retaining queue contracts, projections, blob classes, and offline view.
- Exact client/replay artifact commands and explicit exclusion of private fields and browser mechanisms.

### Validation

1. Compare the compiler result with all eight independent plan rows and all three paired key sets.
2. Repeat compilation and require equal results, zero private fields, zero mechanism constructors, and two
   exact artifact commands.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 41.3: Seal the pure boundary ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Seal the Register-1 claim with current gate infrastructure and no repository-resident generated evidence.

### Deliverables

- An independently authored 38-locus validation inventory and 52-surface expectation.
- Five central-registry build flags wired to five distinct production CPP loci.
- A project-contained run bundle, natural-architecture record, and source-snapshot attestation.

### Validation

1. Require all twelve gate sides, all 17 metrics, all five mutation reds, and the restored baseline to pass.
2. Require generated results to remain beneath `.build/**` and the authored-root and host inventories to remain
   unchanged.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/browser_offline_runtime_doctrine.md` — record the concrete Register-1 language mirror.
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record continuity and paired-plan evidence.
- `documents/engineering/generated_artifacts_doctrine.md` — record the two deterministic artifact commands.

**Cross-references to add:**

- The tracker, substrate map, component inventory, and calculus backlink identify the sealed compiler surface.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Calculus Composition](phase_10_calculus_composition.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
