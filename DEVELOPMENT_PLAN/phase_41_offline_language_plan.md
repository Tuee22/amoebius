# Phase 41: Offline language and paired plans

> **Purpose**: Make offline continuity an explicit bounded application contract and compile it into matching
> public-client and private-server replay plans without exposing browser or Redis mechanisms in the DSL.
> **Read this if**: the Phase-41 language boundary or a later offline-runtime dependency must be understood.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
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
- [Sprint 41.1: Author the continuity language](#sprint-411-author-the-continuity-language-)
- [Sprint 41.2: Compile paired offline plans](#sprint-412-compile-paired-offline-plans-)
- [Sprint 41.3: Seal the pure boundary](#sprint-413-seal-the-pure-boundary-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 40 and every earlier numerical predecessor have passed. The typed Phase-41 subject, independent oracle,
production-mutant seams, and acquired serial supervisor are implemented; the complete integrated gate has not
yet passed.

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
**Depends on:** [Phase 40](phase_40_ui_plan_compiler.md)
**Gate:** `pb validate phase 41`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-bounded-offline-continuity-language` |
| `Subject` | `acquired-offline-language-plan-supervisor` |
| `Command` | `pb validate phase 41` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-offline-language-plan-oracle` |
| `Positive controls` | `offline-language-plan-positive-controls` |
| `Paired negatives` | `exact-offline-language-plan-paired-negatives` |
| `Mutants` | `applied-offline-language-plan-production-mutants` |
| `Discovery` | `exact-offline-language-plan-source-discovery` |
| `Challenge` | `post-acquisition-offline-language-plan-challenge` |
| `Observer` | `offline-language-plan-process-observation` |
| `Authority/bypass` | `no-pb-network-browser-storage-replay-host-hardware-or-parallelism` |
| `Freshness` | `fresh-offline-language-plan-build-root-and-stable-source` |
| `Qualification` | `qualified-offline-language-plan-harness` |
| `Cleanroom` | `offline-language-plan-products-contained-below-build` |
| `Legacy closure` | `retired-offline-language-plan-authorities-absent` |
| `Predecessor` | `exact-phase-forty-receipt` |
| `Residue` | `browser-storage-server-replay-and-publication-owners-explicit` |
| `Pass criterion` | `qualified-phase-forty-one-gate-pass` |

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §3 — The external continuity surface](../documents/engineering/browser_offline_runtime_doctrine.md#3-the-external-continuity-surface): applications name offline semantics, not mechanisms.
- Adopt [`browser_offline_runtime_doctrine.md` §4 — Queueable ports are a stricter port class](../documents/engineering/browser_offline_runtime_doctrine.md#4-queueable-ports-are-a-stricter-port-class): queueability requires the complete bounded replay contract.
- Adopt [`browser_offline_runtime_doctrine.md` §5 — One bound program, paired online and offline plans](../documents/engineering/browser_offline_runtime_doctrine.md#5-one-bound-program-paired-online-and-offline-plans): public and private plan key sets cannot drift.

## Sprints

## Sprint 41.1: Author the continuity language ✅

**Status**: Done
**Implementation**: `src/offline-language-types/Amoebius/Ui/Offline/Types.hs`, `src/Amoebius/Ui/Offline/Decode.hs`, and typed subjects in `test/spec/ui/OfflinePlanCases.hs`.
**Blocked by**: [Phase 40](phase_40_ui_plan_compiler.md) gate pass
**Independent Validation**: three exact continuity rows and thirteen exact refusal tags in `offline-plan-spec`.
**Oracle**: `test/spec/ui/OfflinePlanReference.hs`, independently authored and importing no production or case module.
**Legacy IDs**: two serialized fixture tables formerly under `test/fixture/offline_language_plan/`.
**Docs to update**: this plan, `DEVELOPMENT_PLAN/{substrates,system_components}.md`, and `documents/engineering/{browser_offline_runtime_doctrine,low_code_ui_runtime_doctrine,generated_artifacts_doctrine}.md`.

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

The complete integrated Phase-41 gate and mechanical status projection remain. Browser persistence and server replay remain later-owned.

## Sprint 41.2: Compile paired offline plans ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Offline/Plan.hs` and typed subject cases in `test/spec/ui/OfflinePlanCases.hs`.
**Blocked by**: Sprint 41.1
**Independent Validation**: eight exact plan rows, three paired key sets, determinism, private-field/mechanism exclusions, and two artifact commands in `offline-plan-spec`.
**Oracle**: `test/spec/ui/OfflinePlanReference.hs` supplies the independent plan relation.
**Legacy IDs**: `test/golden/offline_language_plan/plan_keys.tbl`.
**Docs to update**: the paired-plan and generated-artifact owners named by Sprint 41.1.

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

The complete integrated Phase-41 gate and mechanical status projection remain. Generated plans remain lazy `.build/**` products.

## Sprint 41.3: Seal the pure boundary ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/OfflineLanguagePlanRun/Internal.hs`, dispatcher/evidence integration, compiled Phase-41 semantic contract, and serial Cabal matrix.
**Blocked by**: Sprint 41.2
**Independent Validation**: exact source discovery, five serial production-mutant rows, source stability, cleanroom containment, legacy absence, and the eighteen-row acquired gate.
**Oracle**: the Phase-41 runner binds `OfflinePlanReference`, typed cases, process observations, and changed-production failures.
**Legacy IDs**: exact twelve-path retired inventory in `OfflineLanguagePlanRun.Internal` and zero Phase-41 entries in `test/mutant/registry.tsv`.
**Docs to update**: this plan and the tracker/component/substrate/doctrine cross-references before integrated validation.

### Objective

Seal the Register-1 claim with current gate infrastructure and no repository-resident generated evidence.

### Deliverables

- An independently authored Haskell 38-locus validation inventory and 52-surface expectation.
- Five central-registry build flags wired to five distinct production CPP loci.
- A project-contained run bundle, natural-architecture record, and exact source-snapshot binding.

### Validation

1. Require all twelve gate sides, all 17 metrics, all five mutation reds, and the restored baseline to pass.
2. Require generated results to remain beneath `.build/**` and the authored-root and host inventories to remain
   unchanged.

### Remaining Work

The complete integrated Phase-41 gate and mechanical status projection remain. Runtime, network, service, and hardware layers remain explicitly unverified.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

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
