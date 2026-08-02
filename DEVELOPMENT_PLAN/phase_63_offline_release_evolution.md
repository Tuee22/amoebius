# Phase 63: Offline release and schema evolution

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Prevent a rollout from stranding or discarding persisted offline state by requiring migrations
> or retained decoders and replay handlers for the full declared compatibility horizon.

## Phase Status

📋 Planned. No offline compatibility promotion gate or browser-storage migration exists.

## Phase Summary

This phase extends `UiProgramRelease` and `PromotionGate` with the offline storage/replay horizon. A release may
become current only when every admitted old record kind has a total tested migration or a retained decoder and
current-authority replay handler. Browser migration is atomic, crash-resumable, and single-leader. A
`ReloadRequired` event can replace executable assets but cannot clear outbox or blob dependencies.

**Session scope:** Gate one A→B schema migration, one retained-old-handler path, rollback B→A, and one rejected
incompatible release.

**Substrate:** `linux-cpu`.

**Register:** 3 — live infrastructure.

**Gate:** `cabal test offline-release-evolution-live` queues A-version records offline, deploys B, reconnects
through both migration and retained-handler cases, rolls back, and externally proves one authorized outcome
per command; the gate rejects a release that removes its last compatible path before the horizon.

## Gate integrity

Phase 0 pins A/B plans and schemas, migration tables, release-horizon arithmetic, crash points, typed outcomes,
and provider-effect oracle. A fresh browser profile is taken offline before rollout. Independent browser raw
storage, release ledger, gateway, Pulsar, and provider observers establish preservation and effects. Mutants
clear state on reload, omit an old decoder, bypass the promotion check, run two migrations, apply a partial
migration, and preserve an old authorization decision. Observer failure is red, not UNVERIFIED green.

**Committed fixtures/goldens:** A/B plans and schemas, migration table, horizon arithmetic, crash points, and
outcome table. **Independent oracle:** raw browser/release/provider observations evaluated by the separately
authored migration and effect tables.

## Resource provision — compatibility overlap

The provision seal includes concurrent old/new codecs and handlers, migration scratch/peak local records,
receipt retention for the full replay horizon, rollout/reconnect fanout, and provider rollback overlap. A
horizon with no finite server or storage demand is rejected.

## Doctrine adopted

- Adopt [Browser Offline Runtime §11](../documents/engineering/browser_offline_runtime_doctrine.md#11-release-schema-and-compatibility-horizon): old records remain readable and replayable within a finite horizon.
- Adopt [Release Lifecycle §5](../documents/engineering/release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply): offline compatibility is a promotion/readiness condition.
- Adopt [Generated Artifacts §3](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule): migrations and compatibility manifests are emitted, not a second committed truth.

## Sprints

## Sprint 63.1: Gate offline-compatible rollout and rollback 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Release/OfflineCompatibility.hs`, `ui/src/Amoebius/Ui/Offline/Migration.purs`, `test/live/Phase63OfflineReleaseSpec.hs` (planned; not built)
**Blocked by**: Phase 62
**Independent Validation**: `cabal test offline-release-evolution-live` against pinned A/B artifacts, crash points, provider observations, and seeded mutants
**Docs to update**: `documents/engineering/browser_offline_runtime_doctrine.md`, `documents/engineering/release_lifecycle_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Roll forward and back without losing or silently invalidating queued offline intent.

### Deliverables

- Offline compatibility witness and promotion-gate extension.
- Atomic crash-resumable browser migrations under the active-tab fence.
- Retained old codecs/handlers that always reauthorize current identity and policy.
- Live rollout/rollback and incompatible-release mutants.

### Validation

1. Run `cabal test offline-release-evolution-live`; require canonical green and every compatibility mutant red.

### Remaining Work

The whole sprint is planned.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
