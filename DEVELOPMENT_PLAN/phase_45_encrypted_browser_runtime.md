# Phase 45: Haskell offline-state semantics and runtime projection

> **Purpose**: Define encrypted, identity-partitioned offline-state and fenced-ownership semantics in Haskell
> and lazily project the generic browser runtime without executing a browser before the Phase-49 barrier.
> **Read this if**: phase 45 is next in the queue, or a later phase depends on what its gate establishes.

This plan owns the hardware-free encrypted offline-state and generated-runtime projection gate.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 45.1: Build the encrypted local interpreter](#sprint-451-build-the-encrypted-local-interpreter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 44 and every earlier numerical predecessor have passed. The Haskell state model, typed cases,
independent oracle, seven production-mutant seams, lazy runtime projection, and acquired serial supervisor are
implemented; the complete integrated gate has not yet passed.

## Phase Summary

This phase defines the offline state machine, encryption envelope, identity partitioning, quota/eviction
outcomes, replay ordering, and fenced ownership as Haskell values. Haskell also declares the projection that
will lazily generate IndexedDB/OPFS/service-worker/Web-Locks/BroadcastChannel runtime source beneath
`.build/**`. Credentials, refresh tokens, private plans, and cross-partition records have no admitted state
constructor.

The target gate is to exercise the pure transition and cryptographic-format contracts against separately authored
Haskell oracles. It does not start Chrome or another browser and cannot claim browser storage, Web Locks,
service-worker, or WebCrypto fidelity; those are post-Phase-49 live-browser obligations.

**Phase scope:** one cohesive claim — Haskell semantics foreclose invalid offline-state transitions and deterministically project the generic runtime; browser fidelity remains UNVERIFIED.

**Substrate:** `none` — pure Haskell state/envelope semantics and lazy projection only; no browser debugging protocol or browser engine.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure Haskell semantic, property, and generator checks.

**Depends on:** [Phase 44](phase_44_ui_local_composition.md)
**Gate:** `pb validate phase 45`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `haskell-encrypted-offline-state-and-runtime-projection` |
| `Subject` | `acquired-encrypted-browser-runtime-supervisor` |
| `Command` | `pb validate phase 45` (future public spelling); before Phase 50, invoke the exact source-bound Haskell executable directly and let its acquired supervisor run the offline serial matrix. |
| `Oracle` | `independent-encrypted-browser-runtime-oracle` |
| `Positive controls` | `encrypted-browser-runtime-positive-controls` |
| `Paired negatives` | `exact-encrypted-browser-runtime-paired-negatives` |
| `Mutants` | `applied-encrypted-browser-runtime-production-mutants` |
| `Discovery` | `exact-encrypted-browser-runtime-source-discovery` |
| `Challenge` | `post-acquisition-encrypted-browser-runtime-challenge` |
| `Observer` | `encrypted-browser-runtime-process-observation` |
| `Authority/bypass` | `no-pb-browser-node-purescript-javascript-dhall-network-live-host-hardware-or-parallelism` |
| `Freshness` | `fresh-encrypted-browser-runtime-build-root-and-stable-source` |
| `Qualification` | `qualified-encrypted-browser-runtime-harness` |
| `Cleanroom` | `encrypted-browser-runtime-products-contained-below-build` |
| `Legacy closure` | `retired-encrypted-browser-runtime-authorities-absent` |
| `Predecessor` | `exact-phase-forty-four-receipt` |
| `Residue` | `live-browser-storage-crypto-lock-service-worker-replay-release-ha-and-hardware-owners-explicit` |
| `Pass criterion` | `qualified-phase-forty-five-gate-pass` |

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §6 — Closed browser facilities and encrypted storage](../documents/engineering/browser_offline_runtime_doctrine.md#6-closed-browser-facilities-and-encrypted-storage): Haskell models closed facilities and encrypted envelopes; live browser fidelity is deferred.
- Adopt [`browser_offline_runtime_doctrine.md` §7 — Offline identity and partitioning](../documents/engineering/browser_offline_runtime_doctrine.md#7-offline-identity-and-partitioning): Haskell models opaque partitions that are not credentials or authority.
- Adopt [`browser_offline_runtime_doctrine.md` §8 — One active tab owns connection and replay](../documents/engineering/browser_offline_runtime_doctrine.md#8-one-active-tab-owns-connection-and-replay): Haskell models one fenced owner; actual cross-tab behavior is deferred.

## Sprints

## Sprint 45.1: Build the encrypted local interpreter ✅

**Status**: Done
**Implementation**: the six `src/Amoebius/Ui/Offline/Browser/*.hs` phase modules, typed cases, production CPP seams, and package-hidden acquired Phase-45 supervisor.
**Blocked by**: [Phase 44](phase_44_ui_local_composition.md) gate pass
**Independent Validation**: fourteen actions; storage, asset, quota, access, migration, replay, facility, deterministic-projection, calculus, and seven changed-production observations.
**Oracle**: `test/spec/browser/OfflineRuntimeReference.hs`, importing no production or case module.
**Legacy IDs**: exact 26-path Python/PureScript/JavaScript/serialized/materialized-mutant inventory in `EncryptedBrowserRuntimeRun.Internal`.
**Docs to update**: this plan, tracker/component/substrate maps, browser-offline, testing, and generated-artifact doctrine owners.

### Objective

Model bounded offline-state persistence and recovery without disclosing protected records or admitting
multiple replay owners.

### Deliverables

- Closed Haskell values for encrypted structured/blob records, public asset-cache metadata, identity
  partitions, local-unlock outcomes, and supported-facility declarations.
- Pure Haskell transitions for quota, eviction, crash recovery, migration, replay ordering, and single-fenced
  ownership, including an explicit unsupported-facility outcome.
- A Haskell projection that lazily materializes IndexedDB, OPFS, service-worker, Web-Locks,
  BroadcastChannel, and WebCrypto runtime source beneath `.build/**`; no projected code executes in this phase.
- A closed Haskell case corpus, separately authored Haskell expectations, paired negatives, and witnessed
  changed-subject mutations for the state and projection boundaries.

### Validation

1. Compare every declared state transition with a separately authored Haskell expectation. The corpus must
   cover envelope identity, partition switching, quota, eviction, recovery, migration, replay ordering, and
   fence acquisition, renewal, expiry, and takeover.
2. Exercise minimally different Haskell pairs for plaintext protected records, credential persistence,
   cross-partition access, stale fences, dual owners, replay reordering, and unsupported facilities. Each pair
   must return its pinned refusal and produce no forbidden transition.
3. Generate the runtime projection twice from clean Haskell input beneath `.build/**`. A separately authored
   Haskell structure oracle must constrain the closed facility set, partition-key use, fencing hooks, and
   absence of credential-bearing storage while accepting the unchanged control.
4. Witness every changed production Haskell locus before running its state, envelope, fencing, and projection
   mutant. Each mutant must produce its distinct named Haskell-oracle mismatch, while the unaffected control
   remains equal to its independently declared observation.
5. Record IndexedDB, OPFS, Web Locks, BroadcastChannel, service-worker, WebCrypto, cross-tab, and storage
   fidelity in an actual browser as post-barrier UNVERIFIED residue.

### Remaining Work

Run the complete integrated gate and apply only its emitted status projection after a qualified pass. Server
replay remains owned by Phase 85, and live multi-zone continuity remains owned by Phase 88; neither is inferred
from this local browser boundary.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/browser_offline_runtime_doctrine.md` — record the modeled facility set, pure state
  semantics, and deferred live-browser fidelity obligations.
- `documents/engineering/testing_doctrine.md` — link the Haskell transition, partition, and fencing evidence
  without claiming raw browser-storage or two-tab observation.
- `documents/engineering/generated_artifacts_doctrine.md` — record the lazy `.build/**` service-worker and
  runtime projection boundary.

**Cross-references to add:**

- The tracker, substrate map, and component inventory must identify the Haskell offline-state semantics and
  lazy browser-runtime projection.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
