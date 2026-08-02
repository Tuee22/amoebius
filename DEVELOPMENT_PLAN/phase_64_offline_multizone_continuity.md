# Phase 64: Offline multi-zone continuity

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Establish the complete offline-capable UI claim across disconnection, a provider-zone fault,
> Redis/UI-server failover, current reauthentication, blob upload, and effectively-once authoritative replay
> under each effect owner's declared idempotency contract.

## Phase Status

📋 Planned. This is the first phase permitted to claim provider multi-zone offline continuity.

## Phase Summary

This phase composes the Phase-58 online HA topology with encrypted offline projections, outbox, blobs, release
compatibility, and durable receipts. A browser disconnects and queues bounded intent, one provider zone is
isolated including its UI-server and Redis/Sentinel members, a release advances, and the browser reconnects to
a surviving replica. Current OIDC/membership/policy gates replay; cursor repair and durable receipts recover
across lost Redis Pub/Sub. The gate claims only the pinned single-zone/disconnection envelope.

**Session scope:** Run one provider campaign for one offline projection, scalar command, infernix workflow
start, and blob-dependent command; additional providers, live offline jitML/CUDA training, or
simultaneous-zone/disaster recovery require later phases.

**Substrate:** `linux-cpu → provider` — the parent drives one managed provider target.

**Register:** 3 — live infrastructure.

**Gate:** `cabal test offline-multizone-continuity` runs the pinned disconnection/queue/zone-isolation/release/
reauth/reconnect/replay campaign and externally proves current-scope reads, one accepted durable effect per
command, verified blob content, cursor continuity, and zero same-tenant-non-owner or foreign-tenant effect. Its
workflow row preserves the infernix start's scoped command/work-id into the recovered durable receipt; the gate
does not promote Phase 59's structurally queueable jitML start to a tested offline CUDA claim.

## Gate integrity

Phase 0 pins the zone inventory and fault, offline action trace, release transition, reconnect/receipt/cursor
budgets, and two-tenant authority matrix. Provider API proves the whole selected zone isolated; raw browser
storage, Keycloak, Gateway, Kubernetes, Redis, Pulsar, SQL, MinIO, and workflow observers recover distinct
fresh challenges. Mutants isolate one pod only, depend on sticky routing, persist Redis receipts, skip cursor
repair, use pre-fault authority, drop tenant/scope from the outbox, clear state on release, and duplicate blob
dependency replay. Direct Service/Pod/provider bypass probes remain denied.

**Committed fixtures/goldens:** the zone inventory/fault, offline trace, release transition, budgets, and
authority matrix. **Independent oracle:** provider/Kubernetes/browser/identity/data observations evaluated by
the separately authored continuity timeline and command-to-effect table.

## Resource provision — offline multi-zone fault envelope

Before mutation the seal accounts for post-fault UI, Redis/Sentinel, Keycloak, gateway, Pulsar, SQL, MinIO,
projector, receipt, compatibility-handler, upload, cursor-repair, reconnect-storm, retry, and observer capacity
after removal of every selected-zone member. Unschedulable spread, one-short quorum/service availability, or
unbounded replay/fanout/upload demand refuses the campaign.

## Doctrine adopted

- Adopt [Browser Offline Runtime §12](../documents/engineering/browser_offline_runtime_doctrine.md#12-deployment-policy-resources-and-honesty): bound the full offline deployment envelope and its honest limits.
- Adopt [UI Realtime Coordination §7](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): reconnect never depends on stickiness or one pod's memory.
- Adopt [Testing Doctrine §12](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): external observers bind the composite claim.

## Sprints

## Sprint 64.1: Run the offline multi-zone campaign 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Offline/Ha/MultiZone.hs`, `test/live/Phase64OfflineMultiZoneSpec.hs` (planned; not built)
**Blocked by**: Phases 47, 58, and 63
**Independent Validation**: `cabal test offline-multizone-continuity` from an off-cluster probe against provider-confirmed zone isolation and independent browser/identity/data observers
**Docs to update**: `documents/engineering/browser_offline_runtime_doctrine.md`, `documents/engineering/ui_realtime_coordination_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Deliver one externally observed provider-zone failure result for the complete offline-capable UI path.

### Deliverables

- Provisioned redundant UI/Redis/dependency topology and declared fault envelope.
- Offline queue/blob/release trace with post-fault current-authority reconnect.
- Durable receipt, cursor repair, verified upload, one observable effect per accepted command, and
  paired-denial observations.
- Structural, routing, persistence, authority, isolation, and duplicate-effect mutants.

### Validation

1. Run `cabal test offline-multizone-continuity`; require the canonical campaign green and every named mutant red.

### Remaining Work

The whole sprint is planned.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/browser_offline_runtime_doctrine.md` — record the precise tested continuity envelope.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record Redis/UI-server failure and repair behavior.
- `documents/engineering/resource_capacity_doctrine.md` — record the post-fault resource envelope.
- `documents/engineering/testing_doctrine.md` — link off-cluster challenge and raw observer digests.

**Cross-references to add:**
- The tracker, substrate map, and component inventory must identify this as the first offline HA claim.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
