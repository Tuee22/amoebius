# Phase 87: Offline release and schema evolution

> **Purpose**: Prevent a rollout from stranding or discarding persisted offline state by requiring migrations
> or retained decoders and replay handlers for the full declared compatibility horizon.
> **Read this if**: phase 87 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 87.1: Gate offline-compatible rollout and rollback](#sprint-871-gate-offline-compatible-rollout-and-rollback-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 86, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase's target contract extends `UiProgramRelease` and `PromotionGate` with the offline storage/replay horizon. A release may
become current only when every admitted old record kind has a total tested migration or a retained decoder and
current-authority replay handler. Browser migration is atomic, crash-resumable, and single-leader. A
`ReloadRequired` event can replace executable assets but cannot clear outbox or blob dependencies.

The bounded campaign must gate one A→B schema migration, one retained-old-handler path, rollback B→A, and one rejected
incompatible release.

**Phase scope:** one cohesive claim — *no rollout strands persisted offline state inside its declared compatibility horizon*. A migration or a retained decoder is required; discarding the state is not an option.

**Substrate:** `linux-cpu` — the baseline lane every hardware substrate reaches
([`substrate_doctrine.md` §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule)).

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure.

**Depends on:** [Phase 86](phase_86_offline_blobs_isolation.md)
**Gate:** `pb validate phase 87`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *no rollout strands persisted offline state inside its declared compatibility horizon*. A migration or a retained decoder is required; discarding the state is not an option. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 87` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 86; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

The provision seal includes concurrent old/new codecs and handlers, migration scratch/peak local records,
receipt retention for the full replay horizon, rollout/reconnect fanout, and provider rollback overlap. A
horizon with no finite server or storage demand is rejected.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every artifact offline release and schema evolution emits is a recipe over a content address, never an authored file.
- Adopt [`browser_offline_runtime_doctrine.md` §11 — Release, schema, and compatibility horizon](../documents/engineering/browser_offline_runtime_doctrine.md#11-release-schema-and-compatibility-horizon): old records remain readable and replayable within a finite horizon.
- Adopt [`release_lifecycle_doctrine.md` §5 — `RolloutPlan` / `RolloutPhase`: the readiness-gated apply](../documents/engineering/release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply): offline compatibility is a promotion/readiness condition.
- Adopt [`generated_artifacts_doctrine.md` §3 — The rule](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule): migrations and compatibility manifests are emitted lazily from checked Haskell beneath ignored
  `.build/**` and remain untracked; only the Haskell declaration is repository source.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 87.1: Gate offline-compatible rollout and rollback ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 86](phase_86_offline_blobs_isolation.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Roll forward and back without losing or silently invalidating queued offline intent.

### Deliverables

- Offline compatibility witness and promotion-gate extension.
- Atomic crash-resumable browser migrations under the active-tab fence.
- Retained old codecs/handlers that always reauthorize current identity and policy.
- Haskell-authored live rollout/rollback and incompatible-release changed subjects.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-87 supporting suite must run; require the scoped canonical trace green
   and every Haskell compatibility changed subject red.

### Remaining Work

Repeat with real Gateway rollout, Pulsar/provider effects, Keycloak current authority, production PureScript
generated lazily from checked Haskell beneath `.build/**`,
Kubernetes, and CNI. Those observations remain `UNVERIFIED` here.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/browser_offline_runtime_doctrine.md` — record tested schema/horizon behavior.
- `documents/engineering/release_lifecycle_doctrine.md` — record the promotion witness and rollout evidence.
- `documents/engineering/generated_artifacts_doctrine.md` — record emitted migration/compatibility artifacts.
- `documents/engineering/resource_capacity_doctrine.md` — record compatibility-overlap demand.
- `documents/engineering/testing_doctrine.md` — link raw migration and provider evidence.

**Cross-references to add:**

- The tracker, substrate map, and component inventory must identify release-evolution ownership.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [Release Lifecycle](../documents/engineering/release_lifecycle_doctrine.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
