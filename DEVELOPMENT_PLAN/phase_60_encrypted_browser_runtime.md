# Phase 60: Encrypted browser offline runtime

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Implement the generic browser facilities that persist bounded offline state encrypted at rest,
> partition it by identity and scope, and give one fenced tab ownership of migration, connection, and replay.

## Phase Status

📋 Planned. No browser persistence, encryption, service worker, or cross-tab leader exists.

## Phase Summary

This phase implements the trusted interpreter for `ClientPlan.offline`: encrypted IndexedDB structured state,
encrypted IndexedDB/OPFS blobs, immutable public service-worker assets, explicit quota/eviction results, local
unlock and offline-auth states, and a Web Locks/BroadcastChannel leader with a durable fencing generation.
Credentials, refresh tokens, private plans, and cross-partition records cannot be stored. A browser lacking the
required coordination primitives takes the safe single-tab/refuse-concurrency path.

**Session scope:** Implement and browser-test local facilities only; server replay and accepted receipts remain
out of scope until Phase 61.

**Substrate:** `none` — Playwright drives a hermetic Chromium runtime.

**Register:** 2 — hermetic browser boundary tests with controlled fakes.

**Gate:** `cabal test offline-browser-runtime-spec` drives fresh browser profiles through queue, restart,
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

## Doctrine adopted

- Adopt [Browser Offline Runtime §6](../documents/engineering/browser_offline_runtime_doctrine.md#6-closed-browser-facilities-and-encrypted-storage): closed facilities and encrypted local data.
- Adopt [Browser Offline Runtime §7](../documents/engineering/browser_offline_runtime_doctrine.md#7-offline-identity-and-partitioning): opaque partitions are not credentials or authority.
- Adopt [Browser Offline Runtime §8](../documents/engineering/browser_offline_runtime_doctrine.md#8-one-active-tab-owns-connection-and-replay): one fenced active tab.

## Sprints

## Sprint 60.1: Build the encrypted local interpreter 📋

**Status**: Planned
**Implementation**: `ui/src/Amoebius/Ui/Offline/{Store,Crypto,Partition,Leader,ServiceWorker}.purs`, `test/browser/Phase60OfflineRuntimeSpec.hs` (planned; not built)
**Blocked by**: Phase 59
**Independent Validation**: `cabal test offline-browser-runtime-spec` with raw browser-storage inspection and seeded mutants
**Docs to update**: `documents/engineering/browser_offline_runtime_doctrine.md`, `documents/engineering/testing_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Persist and recover bounded offline state without disclosing protected records or creating multiple replay owners.

### Deliverables

- Encrypted structured/blob stores and immutable public asset cache.
- Offline auth/partition state machine and local-unlock binding.
- Fenced cross-tab ownership with a safe unsupported-browser posture.
- Quota, eviction, crash-recovery, and migration transactions plus browser tests.

### Validation

1. Run `cabal test offline-browser-runtime-spec`; require every canonical trace green and every mutant red.

### Remaining Work

The whole sprint is planned.

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
