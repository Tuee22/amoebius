# Phase 62: Offline blobs and partition isolation

> **Purpose**: Add bounded encrypted local blobs and prove that upload, dependency replay, quota handling, and
> tenant/subject partition switching cannot expose or orphan them.
> **Read this if**: phase 62 is next in the queue, or a later phase depends on what its gate establishes.

Phase 62 delivers the offline blobs and partition isolation; its design is owned by [browser_offline_runtime_doctrine.md](../documents/engineering/browser_offline_runtime_doctrine.md), [tenancy_doctrine.md](../documents/engineering/tenancy_doctrine.md), [resource_capacity_doctrine.md](../documents/engineering/resource_capacity_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live, on the `linux-cpu` substrate.
The scoped gate passed on 2026-08-11; real MinIO/Gateway/Kubernetes/CNI and production PureScript remain
`UNVERIFIED`.


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
- [Resource provision — bounded local-blob upload](#resource-provision--bounded-local-blob-upload)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 62.1: Gate encrypted blob replay and isolation ⏸️](#sprint-621-gate-encrypted-blob-replay-and-isolation-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

⏸️ Blocked by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

🟡 Scoped gate passed. The blob state machine, real Chrome encryption/restart/raw inspection, opaque handle,
two-chunk resume, server hash, independent content readback, dependency ordering, isolation, quota, and six
mutants pass. Real platform-provider observations remain `UNVERIFIED`.

## Phase Summary

This phase implements `LocalBlobClass` in the browser and server plans: encrypted local bytes, opaque local
identity, bounded chunk upload under a fresh authorized server handle, server content-identity verification,
and dependency release only after verification. Partition changes never re-tag blobs. Quota pressure yields a
typed refusal or explicit safe eviction, never silent removal of a blob referenced by pending intent.

**Session scope:** Gate one bounded blob class and one dependent command; background media processing and
peer-to-peer transfer are out of scope.

**Substrate:** `linux-cpu`. Every hardware substrate can always run this lane. For pristine Linux, use Incus
on Linux/Linux-CUDA, Lima on Apple, and WSL2 on Windows.

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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 62.1: Gate encrypted blob replay and isolation ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `ui/src/Amoebius/Ui/Offline/BlobStore.purs`,
`src/Amoebius/Ui/Offline/BlobUpload.hs`, `test/live/Phase62OfflineBlobSpec.hs`,
`tools/phase62_blob_live.py`, and `tools/phase62_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `python3 tools/phase62_gate.py` with model tests, two
Chrome processes, raw storage, resumable local upload, independent content readback, six mutants, docs, ledger
**Docs to update**:
`documents/engineering/browser_offline_runtime_doctrine.md`, `documents/engineering/tenancy_doctrine.md`,
`documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Move one offline blob to durable content storage without plaintext leakage, cross-scope reach, or dependency races.

### Deliverables

- Encrypted local blob store and bounded metadata.
- Resumable authorized chunk-upload protocol with server content verification.
- Dependency and quota/eviction state transitions.
- Live isolation, bypass, and mutant harness.

### Validation

1. Run `python3 tools/phase62_gate.py`; require the scoped canonical model and live
   trace green and all six mutants red.

### Remaining Work

Repeat the gate with real MinIO audit/content, Keycloak/Gateway authority, Kubernetes/CNI bypass observation,
and the production PureScript bundle. Those surfaces remain `UNVERIFIED` here.

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
