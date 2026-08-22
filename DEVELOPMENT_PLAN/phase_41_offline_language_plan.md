# Phase 41: Offline language and paired plans

> **Purpose**: Make offline continuity an explicit bounded application contract and compile it into matching
> public-client and private-server replay plans without exposing browser or Redis mechanisms in the DSL.
> **Read this if**: the Phase-41 language boundary or a later offline-runtime dependency must be understood.

Phase 41 owns the pure offline language, its validation relation, and deterministic paired-plan projection.
Browser persistence, encryption, and authoritative replay are later runtime claims and remain UNVERIFIED here.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 41.1: Author the continuity language ✅](#sprint-411-author-the-continuity-language-)
- [Sprint 41.2: Compile paired offline plans ✅](#sprint-412-compile-paired-offline-plans-)
- [Sprint 41.3: Seal the pure boundary ✅](#sprint-413-seal-the-pure-boundary-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21 on natural `darwin/arm64`. The twelve-sided Register-1 gate passes 17 exact
metrics, 52 surfaces joined to 76 enumerated items, normal and network-denied execution, a 40-unit real
five-calculus projection, and five distinct production mutants. Attestation
`sha256:7944511e6443a31dc21930a6709f44eaf88f80c75a1ff485f72aa0ab979c7cb8` binds source snapshot
`sha256:0ef61fb8294d82f1…` over 2,266 files. Browser persistence and live replay authority remain UNVERIFIED.

## Phase Summary

This phase adds `UiSource.continuity = OnlineOnly | Offline OfflineSource`. Its closed source types name cached
projections, queueable ports, local blob classes, and an offline view. Every queueable port carries finite
count, byte, and age bounds plus local validation, idempotency, conflict, ordering, dependency, and current
authority validation semantics. The compiler retains equal queue, projection, and blob key sets in the public
client and private replay plans while keeping private policy and browser mechanisms out of authored source.

The representative product declarations permit only infernix workflow start and jitML training start to
queue. Workflow progress is a cached projection; ML signals, workflow cancellation, and model invocation
remain online-only.

**Phase scope:** one cohesive claim — offline continuity is a bounded application contract compiled into
deterministic paired plans, not a browser or server-storage mechanism.
**Substrate:** `none` — the gate is pure and provisions no runtime resource.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/type-level validation.
**Depends on:** [Phase 40](phase_40_ui_plan_compiler.md) — the sealed UI plan compiler boundary extended here.
**Gate:** `python3 tools/run_phase_gate.py 41` passes committed
`test/fixture/offline_language_plan/`, `test/golden/offline_language_plan/`, and the calculus, isolation, and
exact-locus mutation batteries in [Gate integrity](#gate-integrity).

## Gate integrity

Phase 0 pins three positive continuity rows, thirteen exact refusal rows, eight independent client/replay key
rows, and five mutation bodies. A separate calculus oracle names all five real components and their exact
resource projection. The run joins 38 validation loci plus five central registry entries to an independently
authored surface expectation in both directions.

The gate decodes one online-only and two offline Dhall products, compiles both products separately and together,
and compares queue, cached-projection, and local-blob key sets. It repeats the pure compilation, asserts zero
private fields and mechanism constructors, runs again under Darwin network denial, then requires each
compile-time mutant to fail at its own token before restoring the all-flags-off baseline.

- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.
- **Honesty boundary.** Decision semantics are proven for the model. Protocol and runtime layers are
  UNVERIFIED; no browser persistence or live replay authority is inferred from this gate.

## Doctrine adopted

- Adopt [Browser Offline Runtime §3 — the authored continuity surface](../documents/engineering/browser_offline_runtime_doctrine.md#3-the-authored-continuity-surface): applications name offline semantics, not mechanisms.
- Adopt [Browser Offline Runtime §4 — queueable ports are a stricter port class](../documents/engineering/browser_offline_runtime_doctrine.md#4-queueable-ports-are-a-stricter-port-class): queueability requires the complete bounded replay contract.
- Adopt [Browser Offline Runtime §5 — one bound program, paired online and offline plans](../documents/engineering/browser_offline_runtime_doctrine.md#5-one-bound-program-paired-online-and-offline-plans): public and private plan key sets cannot drift.

## Sprints

## Sprint 41.1: Author the continuity language ✅

**Status**: Done
**Implementation**: `dhall/amoebius/UiOffline.dhall`, `dhall/amoebius/ui/Types.dhall`,
`src/offline-language-types/Amoebius/Ui/Offline/Types.hs`, `src/Amoebius/Ui/Source.hs`,
`dhall/ui/{infernix,jitml}.dhall`
**Blocked by**: [Phase 40](phase_40_ui_plan_compiler.md) gate
**Independent Validation**: `offline-plan-spec` decodes three independently authored product rows and checks
the exact six-operation, two-arm, four-field continuity shape.
**Docs to update**: `documents/engineering/browser_offline_runtime_doctrine.md`,
`documents/engineering/low_code_ui_runtime_doctrine.md`

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

None.

## Sprint 41.2: Compile paired offline plans ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Offline/{Decode,Plan}.hs`,
`test/spec/ui/OfflinePlanSpec.hs`, `test/golden/offline_language_plan/plan_keys.tbl`
**Blocked by**: Sprint 41.1
**Independent Validation**: the test compiles each product and their combined source, then compares eight
authored rows and three independent key-set equalities.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`

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

None.

## Sprint 41.3: Seal the pure boundary ✅

**Status**: Done
**Implementation**: `test/oracle/offline_language_plan/**`, `test/mutant/offline_language_plan/**`,
`test/mutant/registry.tsv`, `tools/offline_language_plan_gate.py`
**Blocked by**: Sprint 41.2
**Independent Validation**: `python3 tools/offline_language_plan_gate.py` runs the clean, isolated, calculus,
surface-join, artifact-hygiene, and five-mutant batteries.
**Docs to update**: `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`,
`DEVELOPMENT_PLAN/system_components.md`

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

None.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
