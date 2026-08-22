# Phase 88: Offline multi-zone continuity

> **Purpose**: Establish the complete offline-capable UI claim across disconnection, a provider-zone fault,
> Redis/UI-server failover, current reauthentication, blob upload, and effectively-once authoritative replay
> under each effect owner's declared idempotency contract.
> **Read this if**: phase 88 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
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
- [Sprint 88.1: Run the offline multi-zone campaign ⏸️](#sprint-881-run-the-offline-multi-zone-campaign-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 87, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase's target contract composes the future human-approved Phase-84 online HA topology with encrypted offline projections, outbox, blobs, release
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

**Depends on:** [Phase 87](phase_87_offline_release_evolution.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 88`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | one cohesive claim — *the offline claim survives disconnection, a zone fault, a failover, reauthentication and replay together*. Each effect owner's idempotency contract is what makes replay effectively-once. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 88` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 87 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

Before mutation the seal accounts for post-fault UI, Redis/Sentinel, Keycloak, gateway, Pulsar, SQL, MinIO,
projector, receipt, compatibility-handler, upload, cursor-repair, reconnect-storm, retry, and observer capacity
after removal of every selected-zone member. Unschedulable spread, one-short quorum/service availability, or
unbounded replay/fanout/upload demand refuses the campaign.

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §12 — Deployment policy, resources, and honesty](../documents/engineering/browser_offline_runtime_doctrine.md#12-deployment-policy-resources-and-honesty): bound the full offline deployment envelope and its honest limits.
- Adopt [`ui_realtime_coordination_doctrine.md` §7 — Replicas, drain, rollout, and gateway migration](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): reconnect never depends on stickiness or one pod's memory.
- Adopt [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): external observers bind the composite claim.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.

## Sprint 88.1: Run the offline multi-zone campaign ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Deliver one scoped, externally observed continuity result for the complete offline-capable UI path without
misrepresenting a host-local role stop as a provider-zone failure.

### Deliverables

- Provisioned redundant UI/Redis/dependency topology and declared fault envelope.
- Offline queue/blob/release trace with post-fault current-authority reconnect.
- Durable receipt, cursor repair, verified upload, one observable effect per accepted command, and
  paired-denial observations.
- Structural, routing, persistence, authority, isolation, and duplicate-effect mutants.

### Validation

1. Rejected historical observation: the `offline-multizone-continuity` Cabal suite expected the canonical
   campaign green and every named mutant red.

### Remaining Work

Repeat the campaign with provider-confirmed whole-zone isolation, managed multi-zone placement, real
Redis/Sentinel, Keycloak/Gateway current authority, Pulsar/SQL/MinIO/workflow observers, Kubernetes/CNI,
production PureScript, and the separately scoped offline jitML/CUDA path. Those surfaces remain `UNVERIFIED`.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
