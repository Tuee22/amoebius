# Phase 86: Offline blobs and partition isolation

> **Purpose**: Add bounded encrypted local blobs and prove that upload, dependency replay, quota handling, and
> tenant/subject partition switching cannot expose or orphan them.
> **Read this if**: phase 86 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 86.1: Gate encrypted blob replay and isolation ⏸️](#sprint-861-gate-encrypted-blob-replay-and-isolation-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 85, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and reviewer-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase's target contract adds `LocalBlobClass` to the browser and server plans: encrypted local bytes, opaque local
identity, bounded chunk upload under a fresh authorized server handle, server content-identity verification,
and dependency release only after verification. Partition changes never re-tag blobs. Quota pressure yields a
typed refusal or explicit safe eviction, never silent removal of a blob referenced by pending intent.

The bounded campaign must gate one bounded blob class and one dependent command; background media processing and
peer-to-peer transfer are out of scope.

**Phase scope:** one cohesive claim — *a local blob cannot be exposed across a partition switch, and cannot be orphaned by one*. Quota handling and dependency replay are the two ways that goes wrong.

**Substrate:** `linux-cpu` — the baseline lane every hardware substrate reaches
([`substrate_doctrine.md` §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule)).

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure.

**Depends on:** [Phase 85](phase_85_offline_replay_receipts.md)
**Gate:** `pb validate phase 86`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *a local blob cannot be exposed across a partition switch, and cannot be orphaned by one*. Quota handling and dependency replay are the two ways that goes wrong. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 86` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 85; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

Provisioning accounts for upload staging, chunk concurrency, WebSocket control messages, Redis routing,
content verification, MinIO object and metadata demand, receipt retention, retries, and the declared reconnect
storm. Browser quota remains runtime-observed and cannot masquerade as cluster capacity.

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`, `S1`–`S6`; Haskell negative declarations
  materialize serialized cases lazily under `.build/test-corpora/offline_blobs_isolation/`.

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — offline blobs and partition isolation carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- Adopt [`browser_offline_runtime_doctrine.md` §10 — Offline blobs](../documents/engineering/browser_offline_runtime_doctrine.md#10-offline-blobs): encrypted local identity, verified upload, and dependency ordering.
- Adopt [`tenancy_doctrine.md` §7 — Two isolation layers, and the honest limit](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit): runtime provider denial complements typed partitioning.
- Adopt [`resource_capacity_doctrine.md` §2 — The load-bearing honesty limit: a capacity sum is a decode-foreclosed check, never type-foreclosed](../documents/engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed): browser quota is not provisioned supply.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and an authorized-reviewer tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 86.1: Gate encrypted blob replay and isolation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 85](phase_85_offline_replay_receipts.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Move one offline blob to durable content storage without plaintext leakage, cross-scope reach, or dependency races.

### Deliverables

- Encrypted local blob store and bounded metadata.
- Resumable authorized chunk-upload protocol with server content verification.
- Dependency and quota/eviction state transitions.
- A Haskell-authored live isolation, bypass, and changed-subject harness.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-86 supporting suite must run; require the scoped canonical model and live
   trace green and all six Haskell changed subjects red.

### Remaining Work

Repeat the gate with real MinIO audit/content, Keycloak/Gateway authority, Kubernetes/CNI bypass observation,
and the production PureScript bundle lazily generated from reviewed Haskell beneath `.build/**`. Those surfaces
remain `UNVERIFIED` here.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

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
