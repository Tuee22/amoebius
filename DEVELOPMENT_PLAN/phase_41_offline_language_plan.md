# Phase 41: Offline language and paired plans

> **Purpose**: Make offline continuity an explicit bounded application contract and compile it into exactly
> matching public-client and private-server replay plans without exposing browser or Redis mechanisms in the DSL.
> **Read this if**: phase 41 is next in the queue, or a later phase depends on what its gate establishes.

Phase 41 delivers the offline language and paired plans; its design is owned by [browser_offline_runtime_doctrine.md](../documents/engineering/browser_offline_runtime_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
The gate passed on 2026-08-11; runtime behavior remains `UNVERIFIED` by construction.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 41.1: Compile the offline contract ⏸️](#sprint-411-compile-the-offline-contract-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-40 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

Done (invalidated). The closed offline source types, validation tags, deterministic paired projections, generated-artifact
commands, independent fixtures, and five compiler mutation loci pass at Register 1.

## Phase Summary

This phase adds `UiSource.continuity = OnlineOnly | Offline OfflineSource`, the closed offline projection,
queueable-port, and local-blob source types, and the gadt-decode relations that require every queueable action to
have finite count/byte/age bounds, idempotency, conflict, order, dependency, and authoritative-validation
semantics. Binding emits matching `ClientPlan.offline` and `UiServerPlan.replay` projections; browser APIs,
Redis, WebSocket routes, credentials, private policy, and provider coordinates remain unnameable in authored
application source. The representative catalog fixes the initial ML classification: infernix workflow start
and jitML training start may opt into `QueuedPort`; workflow progress is a cached cursor projection; ML
signals, cancellation, and artifact/model invocation are `OnlineOnly`.

**Session scope:** Add and test only the language, decoder, binder, and generated-plan projection; browser
persistence and live replay belong to later phases.

**Phase scope:** one cohesive claim — *offline is a declared application contract, not a browser mechanism leaking into the DSL*. The two replay plans are paired so neither can drift from the other.

**Substrate:** `none` — this pure gate is decidable on any detected hardware, so it names no catalog member
([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/type-level validation.

**Depends on:** [Phase 40](phase_40_ui_plan_compiler.md) — the UI plan compiler, whose paired plans this phase extends with an offline contract.

**Gate:** `cabal test offline-plan-spec` accepts the independently authored positive corpus, rejects each
boundedness/plan-equality/security negative with its pinned tag, emits deterministic paired plans, and turns
red for every named plan-compiler mutant. Its apparatus is [Gate integrity](#gate-integrity).

## Gate integrity

Phase 0 pins positive `OnlineOnly` and `Offline` programs, positive infernix-start and jitML-training queue
contracts, negative Dhall/gadt-decode fixtures for every online-only ML operation and missing queue-contract field,
expected error tags, and an independently authored public/private key-set table. Mutants remove a queue bound,
omit the server handler for a client codec, make model invocation queueable, persist a forbidden private field,
and add a browser/Redis product constructor. The oracle parses normalized plan values without invoking the
compiler under test; no live authority or fresh challenge is applicable at Register 1.


The pinned queue contracts are the complete ones, because an incomplete one is exactly what the language is
meant to make unrepresentable: each queueable infernix or jitML start carries identity, conflict, order,
dependency, count, byte, and age terms. Alongside them the corpus carries the refusals — an attempt to queue
any operation the classification holds online-only is a negative fixture, not an omission.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- Adopt [Browser Offline Runtime §3](../documents/engineering/browser_offline_runtime_doctrine.md#3-the-authored-continuity-surface): applications name offline semantics, not mechanisms.
- Adopt [Browser Offline Runtime §4](../documents/engineering/browser_offline_runtime_doctrine.md#4-queueable-ports-are-a-stricter-port-class): queueability requires complete bounded replay semantics.
- Adopt [Browser Offline Runtime §5](../documents/engineering/browser_offline_runtime_doctrine.md#5-one-bound-program-paired-online-and-offline-plans): the two plan projections have exact-key equality.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 41.1: Compile the offline contract ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `dhall/amoebius/UiOffline.dhall`,
`src/Amoebius/Ui/Offline/{Types,Decode,Plan}.hs`, `test/spec/ui/OfflinePlanSpec.hs`, and
`tools/offline_language_plan_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `python3 tools/offline_language_plan_gate.py` against authored
fixtures, the independent key-set oracle, five compile-time mutants, documentation, and the coverage ledger
**Docs to update**:
`documents/engineering/browser_offline_runtime_doctrine.md`,
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`

### Objective

Compile one bounded authored offline contract into coherent public and private plans.

### Deliverables

- Closed continuity, projection, queued-port, blob-class, and queue-contract source/IR types.
- Closed infernix/jitML operation classification plus paired-plan entries only for the two eligible start ports.
- Structured dhall-typecheck/gadt-decode errors for unbounded, mismatched, or forbidden fields.
- Deterministic offline plan projections and generated-artifact commands.
- Independent fixtures, expected tags, and mutants.

### Validation

1. Run `python3 tools/offline_language_plan_gate.py`; require the canonical corpus green, each attempt to queue progress,
   signal, cancellation, or invocation to fail at its pinned tag, and every named mutant to turn red.

### Remaining Work

Browser persistence, encryption, tab ownership, live authority, and replay are not Register-1 claims. They
remain `UNVERIFIED` here and belong to Phases 34–69.

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
