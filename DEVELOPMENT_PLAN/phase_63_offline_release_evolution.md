# Phase 63: Offline release and schema evolution

> **Purpose**: Prevent a rollout from stranding or discarding persisted offline state by requiring migrations
> or retained decoders and replay handlers for the full declared compatibility horizon.
> **Read this if**: phase 63 is next in the queue, or a later phase depends on what its gate establishes.

Phase 63 delivers the offline release and schema evolution; its design is owned by [browser_offline_runtime_doctrine.md](../documents/engineering/browser_offline_runtime_doctrine.md), [release_lifecycle_doctrine.md](../documents/engineering/release_lifecycle_doctrine.md), [generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live, on the `linux-cpu` substrate.
The scoped gate passed on 2026-08-11; live platform rollout/provider observations remain `UNVERIFIED`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

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
- [Resource provision — compatibility overlap](#resource-provision--compatibility-overlap)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 63.1: Gate offline-compatible rollout and rollback ⏸️](#sprint-631-gate-offline-compatible-rollout-and-rollback-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish external evidence without changing an authored path.

**Invalidated historical record:**

🟡 Scoped gate passed. Promotion/horizon/compatibility checks, atomic crash-resumable migration, retained
current-authority replay, real Chrome A→staged-B crash→B→A, append-only release/effect observers, and six
mutants pass. Real platform observers remain `UNVERIFIED`.

## Phase Summary

This phase extends `UiProgramRelease` and `PromotionGate` with the offline storage/replay horizon. A release may
become current only when every admitted old record kind has a total tested migration or a retained decoder and
current-authority replay handler. Browser migration is atomic, crash-resumable, and single-leader. A
`ReloadRequired` event can replace executable assets but cannot clear outbox or blob dependencies.

**Session scope:** Gate one A→B schema migration, one retained-old-handler path, rollback B→A, and one rejected
incompatible release.

**Substrate:** `linux-cpu`. Every hardware substrate can always run this lane. For pristine Linux, use Incus
on Linux/Linux-CUDA, Lima on Apple, and WSL2 on Windows.

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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 63.1: Gate offline-compatible rollout and rollback ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Release/OfflineCompatibility.hs`,
`ui/src/Amoebius/Ui/Offline/Migration.purs`, `test/live/Phase63OfflineReleaseSpec.hs`,
`tools/phase63_release_live.py`, and `tools/phase63_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `python3 tools/phase63_gate.py` against pinned A/B
artifacts, contract tests, separate Chrome processes at crash points, local release/effect observers, mutants
**Docs to update**:
`documents/engineering/browser_offline_runtime_doctrine.md`,
`documents/engineering/release_lifecycle_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Roll forward and back without losing or silently invalidating queued offline intent.

### Deliverables

- Offline compatibility witness and promotion-gate extension.
- Atomic crash-resumable browser migrations under the active-tab fence.
- Retained old codecs/handlers that always reauthorize current identity and policy.
- Live rollout/rollback and incompatible-release mutants.

### Validation

1. Run `python3 tools/phase63_gate.py`; require the scoped canonical trace green
   and every compatibility mutant red.

### Remaining Work

Repeat with real Gateway rollout, Pulsar/provider effects, Keycloak current authority, production PureScript,
Kubernetes, and CNI. Those observations remain `UNVERIFIED` here.

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
