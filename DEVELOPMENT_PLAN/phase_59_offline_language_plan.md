# Phase 59: Offline language and paired plans

> **Purpose**: Make offline continuity an explicit bounded application contract and compile it into exactly
> matching public-client and private-server replay plans without exposing browser or Redis mechanisms in the DSL.
> **Read this if**: phase 59 is next in the queue, or a later phase depends on what its gate establishes.

Phase 59 delivers the offline language and paired plans; its design is owned by [browser_offline_runtime_doctrine.md](../documents/engineering/browser_offline_runtime_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
No gate has run.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 59.1: Compile the offline contract 📋](#sprint-591-compile-the-offline-contract-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. No offline DSL or plan projection is implemented.

## Phase Summary

This phase adds `UiSource.continuity = OnlineOnly | Offline OfflineSource`, the closed offline projection,
queueable-port, and local-blob source types, and the Gate-2 relations that require every queueable action to
have finite count/byte/age bounds, idempotency, conflict, order, dependency, and authoritative-validation
semantics. Binding emits matching `ClientPlan.offline` and `UiServerPlan.replay` projections; browser APIs,
Redis, WebSocket routes, credentials, private policy, and provider coordinates remain unnameable in authored
application source. The representative catalog fixes the initial ML classification: infernix workflow start
and jitML training start may opt into `QueuedPort`; workflow progress is a cached cursor projection; ML
signals, cancellation, and artifact/model invocation are `OnlineOnly`.

**Session scope:** Add and test only the language, decoder, binder, and generated-plan projection; browser
persistence and live replay belong to later phases.

**Substrate:** `none`.

**Register:** 1 — pure/type-level validation.

**Gate:** `cabal test offline-plan-spec` accepts the independently authored positive corpus, rejects each
boundedness/plan-equality/security negative with its pinned tag, emits deterministic paired plans, and turns
red for every named plan-compiler mutant. The corpus includes queueable infernix/jitML starts with complete
identity/conflict/order/dependency/count/byte/age contracts and rejects attempts to queue any initial
online-only ML operation.

## Gate integrity

Phase 0 pins positive `OnlineOnly` and `Offline` programs, positive infernix-start and jitML-training queue
contracts, negative Dhall/Gate-2 fixtures for every online-only ML operation and missing queue-contract field,
expected error tags, and an independently authored public/private key-set table. Mutants remove a queue bound,
omit the server handler for a client codec, make model invocation queueable, persist a forbidden private field,
and add a browser/Redis product constructor. The oracle parses normalized plan values without invoking the
compiler under test; no live authority or fresh challenge is applicable at Register 1.

## Doctrine adopted

- Adopt [Browser Offline Runtime §3](../documents/engineering/browser_offline_runtime_doctrine.md#3-the-authored-continuity-surface): applications name offline semantics, not mechanisms.
- Adopt [Browser Offline Runtime §4](../documents/engineering/browser_offline_runtime_doctrine.md#4-queueable-ports-are-a-stricter-port-class): queueability requires complete bounded replay semantics.
- Adopt [Browser Offline Runtime §5](../documents/engineering/browser_offline_runtime_doctrine.md#5-one-bound-program-paired-online-and-offline-plans): the two plan projections have exact-key equality.

## Sprints

## Sprint 59.1: Compile the offline contract 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/UiOffline.dhall`,
`src/Amoebius/Ui/Offline/{Types,Decode,Plan}.hs`, `test/Ui/OfflinePlanSpec.hs` (planned; not built)
**Blocked by**: Phase 22
**Independent Validation**: `cabal test offline-plan-spec` against authored
fixtures, an independent key-set oracle, and seeded mutants
**Docs to update**:
`documents/engineering/browser_offline_runtime_doctrine.md`,
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`

### Objective

Compile one bounded authored offline contract into coherent public and private plans.

### Deliverables

- Closed continuity, projection, queued-port, blob-class, and queue-contract source/IR types.
- Closed infernix/jitML operation classification plus paired-plan entries only for the two eligible start ports.
- Structured Gate-1/Gate-2 errors for unbounded, mismatched, or forbidden fields.
- Deterministic offline plan projections and generated-artifact commands.
- Independent fixtures, expected tags, and mutants.

### Validation

1. Run `cabal test offline-plan-spec`; require the canonical corpus green, each attempt to queue progress,
   signal, cancellation, or invocation to fail at its pinned tag, and every named mutant to turn red.

### Remaining Work

The whole sprint is planned.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/browser_offline_runtime_doctrine.md` — record the exact implemented source and plan types.
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the continuity field and compiler evidence.
- `documents/engineering/generated_artifacts_doctrine.md` — record emitted offline-plan artifact commands.

**Cross-references to add:**
- The tracker, substrate map, and component inventory must identify the new compiler surface.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
