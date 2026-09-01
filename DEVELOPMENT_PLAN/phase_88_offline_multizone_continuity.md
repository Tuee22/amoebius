# Phase 88: Offline multi-zone continuity

> **Purpose**: Establish the complete offline-capable UI claim across disconnection, a provider-zone fault,
> Redis/UI-server failover, current reauthentication, blob upload, and effectively-once authoritative replay
> under each effect owner's declared idempotency contract.
> **Read this if**: phase 88 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 88.1: Run the offline multi-zone campaign](#sprint-881-run-the-offline-multi-zone-campaign-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 87, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase's target contract composes the future gate-passed Phase-84 online HA topology with encrypted offline projections, outbox, blobs, release
compatibility, and durable receipts. A browser disconnects and queues bounded intent, one provider zone is
isolated including its UI-server and Redis/Sentinel members, a release advances, and the browser reconnects to
a surviving replica. Current OIDC/membership/policy gates replay; cursor repair and durable receipts recover
across lost Redis Pub/Sub. The gate claims only the pinned single-zone/disconnection envelope.

The bounded campaign must cover one provider run for one offline projection, scalar command, infernix workflow
start, and blob-dependent command; additional providers, live offline jitML/CUDA training, or
simultaneous-zone/disaster recovery require later phases.

**Phase scope:** one cohesive claim — *the offline claim survives disconnection, a zone fault, a failover, reauthentication and replay together*. Each effect owner's idempotency contract is what makes replay effectively-once.

**Substrate:** `linux-cpu` — the parent runs the single baseline hardware substrate and targets a provider it
does not itself run ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Lane:** provider — the canonical managed-provider target lane driven from the linux-cpu parent
([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 3 — live infrastructure.

**Depends on:** [Phase 87](phase_87_offline_release_evolution.md)
**Gate:** `pb validate phase 88`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *the offline claim survives disconnection, a zone fault, a failover, reauthentication and replay together*. Each effect owner's idempotency contract is what makes replay effectively-once. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 88` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 87; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

Before mutation the seal accounts for post-fault UI, Redis/Sentinel, Keycloak, gateway, Pulsar, SQL, MinIO,
projector, receipt, compatibility-handler, upload, cursor-repair, reconnect-storm, retry, and observer capacity
after removal of every selected-zone member. Unschedulable spread, one-short quorum/service availability, or
unbounded replay/fanout/upload demand refuses the campaign.

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §12 — Deployment policy, resources, and honesty](../documents/engineering/browser_offline_runtime_doctrine.md#12-deployment-policy-resources-and-honesty): bound the full offline deployment envelope and its honest limits.
- Adopt [`ui_realtime_coordination_doctrine.md` §7 — Replicas, drain, rollout, and gateway migration](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): reconnect never depends on stickiness or one pod's memory.
- Adopt [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): external observers bind the composite claim.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 88.1: Run the offline multi-zone campaign ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 87](phase_87_offline_release_evolution.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Deliver one scoped, externally observed continuity result for the complete offline-capable UI path without
misrepresenting a host-local role stop as a provider-zone failure.

### Deliverables

- Provisioned redundant UI/Redis/dependency topology and declared fault envelope.
- Offline queue/blob/release trace with post-fault current-authority reconnect.
- Durable receipt, cursor repair, verified upload, one observable effect per accepted command, and
  paired-denial observations.
- Haskell-authored structural, routing, persistence, authority, isolation, and duplicate-effect changed subjects.

### Validation

1. Rejected historical observation: the `offline-multizone-continuity` Cabal suite expected the canonical
   campaign green and every named Haskell changed subject red.

### Remaining Work

Repeat the campaign with provider-confirmed whole-zone isolation, managed multi-zone placement, real
Redis/Sentinel, Keycloak/Gateway current authority, Pulsar/SQL/MinIO/workflow observers, Kubernetes/CNI,
production PureScript generated lazily from checked Haskell beneath `.build/**`, and the separately scoped
offline jitML/CUDA path. Those surfaces remain `UNVERIFIED`.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/browser_offline_runtime_doctrine.md` — record the precise tested continuity envelope.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record Redis/UI-server failure and repair behavior.
- `documents/engineering/resource_capacity_doctrine.md` — record the post-fault resource envelope.
- `documents/engineering/testing_doctrine.md` — link off-cluster challenge and raw observer digests.

**Cross-references to add:**

- The tracker, substrate map, and component inventory must distinguish this scoped continuity result from the
  still-unverified provider offline-HA claim.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
