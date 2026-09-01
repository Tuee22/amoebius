# Phase 45: Haskell offline-state semantics and runtime projection

> **Purpose**: Define encrypted, identity-partitioned offline-state and fenced-ownership semantics in Haskell
> and lazily project the generic browser runtime without executing a browser before the Phase-49 barrier.
> **Read this if**: phase 45 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

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

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 44, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

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

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Target only — the pure Haskell state model admits only encrypted-envelope, identity-partitioned, single-fenced-owner transitions and lazily projects runtime source beneath `.build/**`. Actual browser storage, locks, crypto, service-worker, and replay behavior is not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 45` is future public spelling only. Before current gate pass of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an pinned, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance have been established. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not yet been demonstrated by a passing gate for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not yet been demonstrated by a passing gate. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not yet been demonstrated by a passing gate. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a checked pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or checked non-applicability have not yet been demonstrated by a passing gate. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 44; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §6 — Closed browser facilities and encrypted storage](../documents/engineering/browser_offline_runtime_doctrine.md#6-closed-browser-facilities-and-encrypted-storage): Haskell models closed facilities and encrypted envelopes; live browser fidelity is deferred.
- Adopt [`browser_offline_runtime_doctrine.md` §7 — Offline identity and partitioning](../documents/engineering/browser_offline_runtime_doctrine.md#7-offline-identity-and-partitioning): Haskell models opaque partitions that are not credentials or authority.
- Adopt [`browser_offline_runtime_doctrine.md` §8 — One active tab owns connection and replay](../documents/engineering/browser_offline_runtime_doctrine.md#8-one-active-tab-owns-connection-and-replay): Haskell models one fenced owner; actual cross-tab behavior is deferred.

## Sprints

> **Reset validation check.** This sprint remains REJECTED — NOT VALIDATED until its fixed Haskell
> subject/oracle/mutant/legacy contract is complete and separately authored. The target boundaries
> below are Haskell-only and authorize no browser, OS, storage-service, network, or hardware process.

## Sprint 45.1: Build the encrypted local interpreter ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 44](phase_44_ui_local_composition.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, and its provenance have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been checked for this sprint.

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate. Server replay remains owned by Phase 85, and live multi-zone continuity remains owned by Phase 88;
neither is inferred from this local browser boundary.

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
