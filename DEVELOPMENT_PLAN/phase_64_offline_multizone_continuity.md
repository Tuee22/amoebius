# Phase 64: Offline multi-zone continuity

> **Purpose**: Establish the complete offline-capable UI claim across disconnection, a provider-zone fault,
> Redis/UI-server failover, current reauthentication, blob upload, and effectively-once authoritative replay
> under each effect owner's declared idempotency contract.
> **Read this if**: phase 64 is next in the queue, or a later phase depends on what its gate establishes.

Phase 64 delivers the offline multi-zone continuity; its design is owned by [browser_offline_runtime_doctrine.md](../documents/engineering/browser_offline_runtime_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live, on the `linux-cpu → provider` substrate.
The scoped gate passed on 2026-08-11; provider multi-zone continuity remains `UNVERIFIED`.


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
- [Resource provision — offline multi-zone fault envelope](#resource-provision--offline-multi-zone-fault-envelope)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 64.1: Run the offline multi-zone campaign ⏸️](#sprint-641-run-the-offline-multi-zone-campaign-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-63 revalidation — **reopened 2026-08-16 by the natural-architecture amendment.**
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. This phase's last gate recorded no
architecture, so its seal is invalidated as a current result and stands only as history; the rerun differs from
it by naming the lane and architecture the run actually used. A sprint marker below records what that sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

🟡 Scoped gate passed. The composite contract, real Chrome offline/release/blob trace, three local endpoint
roles with one stopped, SQLite receipt/effect/cursor observer, content readback, route loss, paired denial, and
eight mutants pass. Provider multi-zone continuity remains `UNVERIFIED`; this is not a live HA claim.

## Phase Summary

This phase composes the Phase-60 online HA topology with encrypted offline projections, outbox, blobs, release
compatibility, and durable receipts. A browser disconnects and queues bounded intent, one provider zone is
isolated including its UI-server and Redis/Sentinel members, a release advances, and the browser reconnects to
a surviving replica. Current OIDC/membership/policy gates replay; cursor repair and durable receipts recover
across lost Redis Pub/Sub. The gate claims only the pinned single-zone/disconnection envelope.

**Session scope:** Run one provider campaign for one offline projection, scalar command, infernix workflow
start, and blob-dependent command; additional providers, live offline jitML/CUDA training, or
simultaneous-zone/disaster recovery require later phases.

**Substrate:** `linux-cpu → provider`. The tested parent-side slice ran on `linux-cpu`; no managed provider
target participated. Every hardware substrate can always run `linux-cpu`. When a pristine Linux host is
needed, use Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows.

**Lane:** linux-cpu/amd64 → provider ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure.

**Gate:** `python3 tools/offline_multizone_continuity_gate.py` runs the contract, scoped live campaign,
eight mutants, docs, and evidence ledger. Its infernix row preserves command/work identity in the durable
receipt; offline jitML/CUDA remains unclaimed.

## Gate integrity

Phase 0 pins the zone inventory and fault, offline action trace, release transition, reconnect/receipt/cursor
budgets, and two-tenant authority matrix. The scoped campaign uses raw browser storage, stopped host-local
endpoint roles, SQLite, and filesystem content as distinct fresh observers. Provider API, Keycloak, Gateway,
Kubernetes, Redis/Sentinel, Pulsar, SQL, MinIO, and workflow observations remain `UNVERIFIED`. Mutants isolate
one pod only, depend on sticky routing, persist Redis receipts, skip cursor
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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 64.1: Run the offline multi-zone campaign ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Ui/Offline/Ha/MultiZone.hs`,
`test/spec/live/OfflineMultiZoneSpec.hs`, `tools/offline_multizone_continuity_live.py`, and `tools/offline_multizone_continuity_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Requires**: `cloud-account` — the credentialed account whose zones this continuity gate partitions and heals.
**Independent Validation**: `python3 tools/offline_multizone_continuity_gate.py` against pinned
artifacts, contract tests, real Chrome, stopped endpoint, SQLite/filesystem observers, and eight mutants
**Docs to update**:
`documents/engineering/browser_offline_runtime_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Deliver one scoped, externally observed continuity result for the complete offline-capable UI path without
misrepresenting a host-local role stop as a provider-zone failure.

### Deliverables

- Provisioned redundant UI/Redis/dependency topology and declared fault envelope.
- Offline queue/blob/release trace with post-fault current-authority reconnect.
- Durable receipt, cursor repair, verified upload, one observable effect per accepted command, and
  paired-denial observations.
- Structural, routing, persistence, authority, isolation, and duplicate-effect mutants.

### Validation

1. Run `cabal test offline-multizone-continuity`; require the canonical campaign green and every named mutant red.

### Remaining Work

Repeat the campaign with provider-confirmed whole-zone isolation, managed multi-zone placement, real
Redis/Sentinel, Keycloak/Gateway current authority, Pulsar/SQL/MinIO/workflow observers, Kubernetes/CNI,
production PureScript, and the separately scoped offline jitML/CUDA path. Those surfaces remain `UNVERIFIED`.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/browser_offline_runtime_doctrine.md` — record the precise tested continuity envelope.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record Redis/UI-server failure and repair behavior.
- `documents/engineering/resource_capacity_doctrine.md` — record the post-fault resource envelope.
- `documents/engineering/testing_doctrine.md` — link off-cluster challenge and raw observer digests.

**Cross-references to add:**
- The tracker, substrate map, and component inventory must distinguish this scoped continuity result from the
  still-unverified provider offline-HA claim.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
