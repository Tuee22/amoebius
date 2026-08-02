# Phase 62: Offline blobs and partition isolation

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Add bounded encrypted local blobs and prove that upload, dependency replay, quota handling, and
> tenant/subject partition switching cannot expose or orphan them.

## Phase Status

📋 Planned. Offline local-blob persistence and upload are unimplemented.

## Phase Summary

This phase implements `LocalBlobClass` in the browser and server plans: encrypted local bytes, opaque local
identity, bounded chunk upload under a fresh authorized server handle, server content-identity verification,
and dependency release only after verification. Partition changes never re-tag blobs. Quota pressure yields a
typed refusal or explicit safe eviction, never silent removal of a blob referenced by pending intent.

**Session scope:** Gate one bounded blob class and one dependent command; background media processing and
peer-to-peer transfer are out of scope.

**Substrate:** `linux-cpu`.

**Register:** 3 — live infrastructure.

**Gate:** `cabal test offline-blobs-isolation-live` queues an encrypted fresh blob offline, restarts and
switches partitions, reconnects, resumes a faulted chunk upload, verifies content identity, and externally
proves that only the owning tenant/subject can release the dependent effect.

## Gate integrity

Phase 0 pins blob/chunk/aggregate bounds, encrypted-storage inventory, upload-resume trace, content digest, and
three-principal access matrix. Browser raw-storage, gateway, MinIO audit/content, and effect-owner observers
recover a fresh challenge. Mutants persist plaintext, expose an OPFS handle, omit tenant/subject from the
partition, replay the dependent command before content verification, silently evict a depended-on blob, and
trust a caller-supplied digest. Direct MinIO and UI-pod routes remain denied.

**Committed fixtures/goldens:** blob/chunk bounds, encrypted-storage inventory, resume trace, digest, and
access matrix. **Independent oracle:** raw browser storage plus MinIO content/audit and the separately authored
dependency/effect table.

## Resource provision — bounded local-blob upload

Provisioning accounts for upload staging, chunk concurrency, WebSocket control messages, Redis routing,
content verification, MinIO object and metadata demand, receipt retention, retries, and the declared reconnect
storm. Browser quota remains runtime-observed and cannot masquerade as cluster capacity.

## Doctrine adopted

- Adopt [Browser Offline Runtime §10](../documents/engineering/browser_offline_runtime_doctrine.md#10-offline-blobs): encrypted local identity, verified upload, and dependency ordering.
- Adopt [Tenancy Doctrine §7](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit): runtime provider denial complements typed partitioning.
- Adopt [Resource Capacity Doctrine §2](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed): browser quota is not provisioned supply.

## Sprints

## Sprint 62.1: Gate encrypted blob replay and isolation 📋

**Status**: Planned
**Implementation**: `ui/src/Amoebius/Ui/Offline/BlobStore.purs`, `src/Amoebius/Ui/Offline/BlobUpload.hs`, `test/live/Phase62OfflineBlobSpec.hs` (planned; not built)
**Blocked by**: Phase 61
**Independent Validation**: `cabal test offline-blobs-isolation-live` with raw browser storage, MinIO audit/content, and tenant-effect observers
**Docs to update**: `documents/engineering/browser_offline_runtime_doctrine.md`, `documents/engineering/tenancy_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Move one offline blob to durable content storage without plaintext leakage, cross-scope reach, or dependency races.

### Deliverables

- Encrypted local blob store and bounded metadata.
- Resumable authorized chunk-upload protocol with server content verification.
- Dependency and quota/eviction state transitions.
- Live isolation, bypass, and mutant harness.

### Validation

1. Run `cabal test offline-blobs-isolation-live`; require the canonical run green and all mutants red.

### Remaining Work

The whole sprint is planned.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/browser_offline_runtime_doctrine.md` — record supported blob and quota behavior.
- `documents/engineering/tenancy_doctrine.md` — record tested local-partition/provider isolation.
- `documents/engineering/resource_capacity_doctrine.md` — record upload and object demand.
- `documents/engineering/testing_doctrine.md` — link raw-storage and provider observations.

**Cross-references to add:**
- The tracker, substrate map, and component inventory must identify the blob modules.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
