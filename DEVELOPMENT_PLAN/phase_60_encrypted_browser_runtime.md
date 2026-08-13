# Phase 60: Encrypted browser offline runtime

> **Purpose**: Implement the generic browser facilities that persist bounded offline state encrypted at rest,
> partition it by identity and scope, and give one fenced tab ownership of migration, connection, and replay.
> **Read this if**: phase 60 is next in the queue, or a later phase depends on what its gate establishes.

Phase 60 delivers the encrypted browser offline runtime; its design is owned by [browser_offline_runtime_doctrine.md](../documents/engineering/browser_offline_runtime_doctrine.md), and the plan for reaching it is owned here.
Register 2: a real boundary against fake tools.
The scoped gate passed on 2026-08-11 against real Chrome; the production PureScript bundle remains
`UNVERIFIED` because no PureScript compiler is installed.


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
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 60.1: Build the encrypted local interpreter ⏸️](#sprint-601-build-the-encrypted-local-interpreter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish external evidence without changing an authored path.

**Invalidated historical record:**

🟡 Scoped gate passed. A fresh real Chrome profile exercises WebCrypto, IndexedDB, process restart, raw
storage inspection, partitions, Web Locks, BroadcastChannel, Service Worker/cache state, quota results, and
all six mutants. Production PureScript compilation and server replay remain `UNVERIFIED`.

## Phase Summary

This phase implements the trusted interpreter for `ClientPlan.offline`: encrypted IndexedDB structured state,
encrypted IndexedDB/OPFS blobs, immutable public service-worker assets, explicit quota/eviction results, local
unlock and offline-auth states, and a Web Locks/BroadcastChannel leader with a durable fencing generation.
Credentials, refresh tokens, private plans, and cross-partition records cannot be stored. A browser lacking the
required coordination primitives takes the safe single-tab/refuse-concurrency path.

**Session scope:** Implement and browser-test local facilities only; server replay and accepted receipts remain
out of scope until Phase 61.

**Substrate:** `none` — the gate drives a hermetic Chrome runtime through the browser debugging protocol.
Every hardware substrate can always run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on
Apple, or WSL2 on Windows.

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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 60.1: Build the encrypted local interpreter ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**:
`ui/src/Amoebius/Ui/Offline/{Store,Crypto,Partition,Leader,ServiceWorker}.purs`,
`src/Amoebius/Ui/Offline/Browser/{Store,Crypto,Partition,Leader,ServiceWorker}.hs`,
`test/browser/Phase60OfflineRuntimeSpec.hs`, `tools/phase60_browser_live.py`, and `tools/phase60_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `python3 tools/phase60_gate.py` with a two-process
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

1. Run `python3 tools/phase60_gate.py`; require the canonical model and real Chrome
   traces green and every mutant red.

### Remaining Work

Compile and link the PureScript modules into the production generic client bundle once the PureScript toolchain
is available. Server replay remains owned by Phase 61. Neither surface is inferred from the Chrome harness.

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
