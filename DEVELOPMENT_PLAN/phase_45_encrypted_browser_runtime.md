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

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-44 predecessor and its compatible evidence chain.

## Phase Summary

This phase must generate a complete offline runtime whose operations mean the same thing as the Haskell state machine. A skeleton containing facility names and fencing hook strings does not meet that requirement. Hardware-free compilation and isolated execution of those generated operations belong to the immediate generated-bundle owner, Phase 46; actual browser fidelity remains later-owned.

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

**Contract check**: UNRESOLVED — NOT VALIDATED; the replacement certification-generation and accepted-baseline
binding has not been authored in Haskell. Retained rows specify intended scope and supply no execution evidence.

| Key | Contract |
|---|---|
| `Claim` | The Haskell offline runtime consumes actual checked continuity plans, preserves encrypted-envelope/partition/fence/quota/replay semantics and generates complete runtime implementations whose software correspondence is executable under isolated fake browser facilities in Phase 46. |
| `Subject` | `acquired-encrypted-browser-runtime-supervisor` |
| `Command` | `pb validate phase 45` (future public spelling); before Phase 50, invoke the exact source-bound Haskell executable directly and let its acquired supervisor run the offline serial matrix. |
| `Oracle` | `test/spec/browser/OfflineRuntimeReference.hs` independently specifies full envelope bytes/fields, record operations, partition ownership, replay/fencing and facility requests; stub declarations, names and source substrings cannot satisfy runtime meaning. |
| `Positive controls` | Exercise every declared plan/state transition, persistence/encryption operation and facility adapter with actual input/output values, and emit a complete callable generated runtime for the next phase to compile and execute. |
| `Paired negatives` | Tampered envelope, wrong partition/key context, quota boundary, stale fence, dual owner, crash/recovery and unsupported facility pairs must fail at exact transitions or requests while matched legal controls pass. |
| `Mutants` | Mutate actual envelope, partition, fence, quota/replay semantics and generated operation bodies; an independently literal exact-case registry must detect each without relying on expected tokens or hook names. |
| `Discovery` | Join actual continuity-plan/state/facility constructors, generated exports/operations, independent semantic cases and mutation assignments in both directions. |
| `Challenge` | `post-acquisition-encrypted-browser-runtime-challenge` |
| `Observer` | `encrypted-browser-runtime-process-observation` |
| `Authority/bypass` | `no-pb-browser-node-purescript-javascript-dhall-network-live-host-hardware-or-parallelism` |
| `Freshness` | `fresh-encrypted-browser-runtime-build-root-and-stable-source` |
| `Qualification` | Require real Haskell semantic observations and complete generated-operation structure plus all assigned changed subjects. Missing implementation bodies or constant no-op adapters refuse even if required facility names are present. |
| `Cleanroom` | `encrypted-browser-runtime-products-contained-below-build` |
| `Legacy closure` | `retired-encrypted-browser-runtime-authorities-absent` |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 44 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | Actual browser storage durability, WebCrypto implementation fidelity, cross-tab scheduling and service-worker lifecycle remain unverified until their live owners. Phase 46 owns generated-runtime compilation and isolated fake-facility execution. |
| `Pass criterion` | `qualified-gate-pass` |

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §6 — Closed browser facilities and encrypted storage](../documents/engineering/browser_offline_runtime_doctrine.md#6-closed-browser-facilities-and-encrypted-storage): Haskell models closed facilities and encrypted envelopes; live browser fidelity is deferred.
- Adopt [`browser_offline_runtime_doctrine.md` §7 — Offline identity and partitioning](../documents/engineering/browser_offline_runtime_doctrine.md#7-offline-identity-and-partitioning): Haskell models opaque partitions that are not credentials or authority.
- Adopt [`browser_offline_runtime_doctrine.md` §8 — One active tab owns connection and replay](../documents/engineering/browser_offline_runtime_doctrine.md#8-one-active-tab-owns-connection-and-replay): Haskell models one fenced owner; actual cross-tab behavior is deferred.

## Sprints

## Sprint 45.1: Build the encrypted local interpreter ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: the six `src/Amoebius/Ui/Offline/Browser/*.hs` phase modules, typed cases, production CPP seams, and package-hidden acquired Phase-45 supervisor.
**Blocked by**: [Phase 44](phase_44_ui_local_composition.md) gate pass
**Independent Validation**: Check full actual continuity-plan state/envelope/facility outputs against independent expectations; tamper, wrong-partition and stale-fence pairs fail exactly; assigned state and generated-body mutants are rejected; real browser fidelity remains unverified.
**Oracle**: `test/spec/browser/OfflineRuntimeReference.hs`, importing no production or case module.
**Legacy IDs**: exact 26-path Python/PureScript/JavaScript/serialized/materialized-mutant inventory in `EncryptedBrowserRuntimeRun.Internal`.
**Docs to update**: this plan, tracker/component/substrate maps, browser-offline, testing, and generated-artifact doctrine owners.

### Objective

Model bounded offline-state persistence and recovery without disclosing protected records or admitting
multiple replay owners.

### Deliverables

- Make each generated storage, crypto, worker, lock and channel operation implement its typed Haskell semantics with explicit inputs, results, errors and facility calls. Empty declarations, placeholder returns and unused hook names are rejected as incomplete source generation.
- Provide a Haskell-authored independent operation/ABI/case registry and deterministic fake browser-facility semantics for the Phase-46 generated software execution contract; no tracked foreign-language fixture or implementation is introduced.

- Closed Haskell values for encrypted structured/blob records, public asset-cache metadata, identity
  partitions, local-unlock outcomes, and supported-facility declarations.
- Pure Haskell transitions for quota, eviction, crash recovery, migration, replay ordering, and single-fenced
  ownership, including an explicit unsupported-facility outcome.
- A Haskell projection that lazily materializes IndexedDB, OPFS, service-worker, Web-Locks,
  BroadcastChannel, and WebCrypto runtime source beneath `.build/**`; no projected code executes in this phase.
- A closed Haskell case corpus, separately authored Haskell expectations, paired negatives, and witnessed
  changed-subject mutations for the state and projection boundaries.

### Validation

- Compare actual envelope fields and bytes, partition keys, fence generations, requested operations and failure outcomes. Replacing an operation body with a no-op while preserving source names must fail its assigned projection case.
- Retain all declared quota, crash, migration, ownership and replay boundaries; a fixture count or same generated source hash cannot discharge one of these semantic obligations.

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
