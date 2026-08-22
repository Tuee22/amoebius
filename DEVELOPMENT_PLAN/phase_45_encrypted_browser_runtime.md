# Phase 45: Encrypted browser offline runtime

> **Purpose**: Implement the generic browser facilities that persist bounded offline state encrypted at rest,
> partition it by identity and scope, and give one fenced tab ownership of migration, connection, and replay.
> **Read this if**: phase 45 is next in the queue, or a later phase depends on what its gate establishes.

Phase 45 delivers the encrypted browser offline runtime; its design is owned by [browser_offline_runtime_doctrine.md](../documents/engineering/browser_offline_runtime_doctrine.md), and the plan for reaching it is owned here.
Register 2: a real boundary against fake tools.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 45.1: Build the encrypted local interpreter ✅](#sprint-451-build-the-encrypted-local-interpreter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-22. `python3 tools/encrypted_browser_runtime_gate.py` passes all fourteen sides on
natural `arm64`, untranslated. The production PureScript graph and generic bundle compile with all offline
modules; two real Chrome processes pass the fourteen-action trace and all twelve WebCrypto, IndexedDB,
partition, Web Locks, BroadcastChannel, Service Worker, cache, restart, and quota observations. Three storage
rows, two immutable assets, three quota rows, three access rows, and all six production-reference mutants pass.
The real five-calculus projection accounts for 50 units, all 17 metrics match, and 66 surfaces join completely.
Attestation `sha256:ae246b901d94b7b2013812e71af9de8d9f65676fdb8346e75b4e1ef4b9c8d8ef` binds source
`sha256:593e71d60584b02e…` over 2,274 files. Server replay and live multi-zone behavior remain UNVERIFIED.

## Phase Summary

This phase implements the trusted interpreter for `ClientPlan.offline`: encrypted IndexedDB structured state,
encrypted IndexedDB/OPFS blobs, immutable public service-worker assets, explicit quota/eviction results, local
unlock and offline-auth states, and a Web Locks/BroadcastChannel leader with a durable fencing generation.
Credentials, refresh tokens, private plans, and cross-partition records cannot be stored. A browser lacking the
required coordination primitives takes the safe single-tab/refuse-concurrency path.

**Phase scope:** one cohesive claim — *offline state at rest is encrypted, partitioned by identity, and owned by exactly one fenced tab*. Ownership is what makes replay safe rather than merely ordered.

**Substrate:** `none` — the gate drives a hermetic Chrome runtime through the browser debugging protocol.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 2 — hermetic browser boundary tests with controlled fakes.

**Depends on:** [Phase 44](phase_44_ui_local_composition.md) — local UI composition, which this phase consumes rather than rebuilds.

**Gate:** `python3 tools/run_phase_gate.py 45` drives fresh browser profiles through queue, restart,
unlock, quota, tenant/subject switch, two-tab handoff, service-worker upgrade, and storage inspection; it finds
no prohibited plaintext or cross-partition disclosure and turns every named mutant red.

## Gate integrity

Phase 0 pins a browser action trace, ciphertext/storage-key inventory, allowed asset manifest, quota outcomes,
and two-partition access table. The external observer reads raw browser storage and service-worker caches after
fresh random canaries. Mutants store plaintext, retain credentials/private-plan fields, allow two replay
leaders, omit fencing, silently evict a depended-on record, and reuse a partition key across tenants. Observer
failure fails the gate; runtime self-report is not evidence.

**Committed fixtures/goldens:** the pinned trace, storage inventory, asset manifest, quota table, and access
table. **Independent oracle:** raw Chromium storage/cache inspection plus the separately authored access table;
neither calls the runtime under test.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- Adopt [Browser Offline Runtime §6](../documents/engineering/browser_offline_runtime_doctrine.md#6-closed-browser-facilities-and-encrypted-storage): closed facilities and encrypted local data.
- Adopt [Browser Offline Runtime §7](../documents/engineering/browser_offline_runtime_doctrine.md#7-offline-identity-and-partitioning): opaque partitions are not credentials or authority.
- Adopt [Browser Offline Runtime §8](../documents/engineering/browser_offline_runtime_doctrine.md#8-one-active-tab-owns-connection-and-replay): one fenced active tab.

## Sprints

## Sprint 45.1: Build the encrypted local interpreter ✅

**Status**: Done
**Implementation**:
`ui/src/Amoebius/Ui/Offline/{Store,Crypto,Partition,Leader,ServiceWorker,Runtime}.{purs,js}`,
`src/Amoebius/Ui/Offline/Browser/{Store,Crypto,Partition,Leader,ServiceWorker}.hs`,
`test/spec/browser/OfflineRuntimeSpec.hs`, `tools/encrypted_browser_runtime_live.py`, and `tools/encrypted_browser_runtime_gate.py`
**Blocked by**: [Phase 44](phase_44_ui_local_composition.md) gate
**Independent Validation**: `python3 tools/encrypted_browser_runtime_gate.py` with a two-process
Chrome profile, raw browser-storage/cache inspection, model contracts, and six compile-time mutants
**Docs to update**: `documents/engineering/browser_offline_runtime_doctrine.md`,
`documents/engineering/testing_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Persist and recover bounded offline state without disclosing protected records or creating multiple replay owners.

### Deliverables

- Encrypted structured/blob stores and immutable public asset cache.
- Offline auth/partition state machine and local-unlock binding.
- Fenced cross-tab ownership with a safe unsupported-browser posture.
- Quota, eviction, crash-recovery, and migration transactions plus browser tests.

### Validation

1. Run `python3 tools/encrypted_browser_runtime_gate.py`; require the canonical model and real Chrome
   traces green and every mutant red.

### Remaining Work

None. Server replay remains owned by Phase 85, and live multi-zone continuity remains owned by Phase 88;
neither is inferred from this local browser boundary.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/browser_offline_runtime_doctrine.md` — record supported facilities and tested assumptions.
- `documents/engineering/testing_doctrine.md` — link raw-storage and two-tab evidence.
- `documents/engineering/generated_artifacts_doctrine.md` — record the emitted service-worker manifest.

**Cross-references to add:**
- The tracker, substrate map, and component inventory must identify the browser runtime.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
