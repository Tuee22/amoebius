# Phase 46: Haskell offline-state semantics and runtime projection

> **Purpose**: Define encrypted, identity-partitioned offline-state and fenced-ownership semantics in Haskell
> and lazily project the generic browser runtime without executing a browser before the Phase-50 barrier.
> **Read this if**: phase 46 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_calculus_composition.md, DEVELOPMENT_PLAN/phase_47_ui_contract_generation.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 46.1: Build the encrypted local interpreter ⏸️](#sprint-461-build-the-encrypted-local-interpreter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 45, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

This phase defines the offline state machine, encryption envelope, identity partitioning, quota/eviction
outcomes, replay ordering, and fenced ownership as Haskell values. Haskell also declares the projection that
will lazily generate IndexedDB/OPFS/service-worker/Web-Locks/BroadcastChannel runtime source beneath
`.build/**`. Credentials, refresh tokens, private plans, and cross-partition records have no admitted state
constructor.

The target gate is to exercise the pure transition and cryptographic-format contracts against separately reviewed
Haskell oracles. It does not start Chrome or another browser and cannot claim browser storage, Web Locks,
service-worker, or WebCrypto fidelity; those are post-Phase-50 live-browser obligations.

**Phase scope:** one cohesive claim — Haskell semantics foreclose invalid offline-state transitions and deterministically project the generic runtime; browser fidelity remains UNVERIFIED.

**Substrate:** `none` — pure Haskell state/envelope semantics and lazy projection only; no browser debugging protocol or browser engine.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure Haskell semantic, property, and generator checks.

**Depends on:** [Phase 45](phase_45_ui_local_composition.md)
**Gate:** `pb validate phase 46`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — the pure Haskell state model admits only encrypted-envelope, identity-partitioned, single-fenced-owner transitions and lazily projects runtime source beneath `.build/**`. Actual browser storage, locks, crypto, service-worker, and replay behavior is not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 46` is future public spelling only. Before current human approval of Phase 51, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 45; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §6 — Closed browser facilities and encrypted storage](../documents/engineering/browser_offline_runtime_doctrine.md#6-closed-browser-facilities-and-encrypted-storage): Haskell models closed facilities and encrypted envelopes; live browser fidelity is deferred.
- Adopt [`browser_offline_runtime_doctrine.md` §7 — Offline identity and partitioning](../documents/engineering/browser_offline_runtime_doctrine.md#7-offline-identity-and-partitioning): Haskell models opaque partitions that are not credentials or authority.
- Adopt [`browser_offline_runtime_doctrine.md` §8 — One active tab owns connection and replay](../documents/engineering/browser_offline_runtime_doctrine.md#8-one-active-tab-owns-connection-and-replay): Haskell models one fenced owner; actual cross-tab behavior is deferred.

## Sprints

> **Reset validation review.** This sprint remains REJECTED — NOT VALIDATED until its fixed Haskell
> subject/oracle/reviewer/mutant/legacy contract is complete and independently reviewed. The target boundaries
> below are Haskell-only and authorize no browser, OS, storage-service, network, or hardware process.

## Sprint 46.1: Build the encrypted local interpreter ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 45](phase_45_ui_local_composition.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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
- A closed Haskell case corpus, separately reviewed Haskell expectations, paired negatives, and witnessed
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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Server replay remains owned by Phase 86, and live multi-zone continuity remains owned by Phase 89;
neither is inferred from this local browser boundary.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
