# Phase 84: Initial online UI multi-zone high availability

> **Purpose**: Establish genuine end-to-end UI availability across provider failure domains with redundant
> stateless UI servers, redundant projectors, resumable streams, and an externally observed live fault.
> **Read this if**: phase 84 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_69_spa_live_deploy.md (HA/failover portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 84.1: Run the multi-zone UI failure campaign](#sprint-841-run-the-multi-zone-ui-failure-campaign-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 83, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase is the only initial UI phase allowed to claim high availability. It deploys at least three
UI-server replicas across independent zones and at least three projector replicas across the same zones, with the authenticated edge
and required identity/data/workflow services in admitted redundant shapes. An external client continues a
fresh read, idempotent mutation, workflow start, and subscription while a provider-native fault isolates every
node and serving endpoint in one selected availability zone. Killing one Pod or node does not satisfy this
gate. The gate observes that declared whole-zone fault only; it is not a proof against every correlated
provider failure.
Redis follows its distributed one-primary/two-replica/three-Sentinel topology across the admitted zones. The
fault removes the selected-zone Redis/Sentinel members as well as application members; surviving UI servers
reconnect through Sentinel, and any lost Pub/Sub hint repairs from Pulsar/projection cursors. This is the
online HA gate. Offline outbox/blob continuity is not claimed until Phase 87.

Supporting observation: a phase-number-neutral Haskell multi-zone suite may drive the provider campaign;
the sole acceptance command is `pb validate phase 84`. Split if validation adds another provider, substrate,
simultaneous-zone loss model, or disaster-recovery claim.

**Phase scope:** one cohesive claim — *availability survives the loss of a provider failure domain, observed from outside*. Redundancy is only a claim until an externally injected fault exercises it.

**Substrate:** `linux-cpu` — the parent runs the single baseline hardware substrate and drives one managed
provider target ([§L](development_plan_standards.md#l-one-substrate-discipline)). Every hardware substrate can always run
`linux-cpu`. When pristine Linux is needed, use Incus on Linux or Linux-CUDA, Lima on Apple, and WSL2 on
Windows.

**Lane:** provider — the canonical managed-provider target lane driven from the linux-cpu parent
([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 83](phase_83_ui_rollout_reconnect.md)
**Gate:** `pb validate phase 84`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *availability survives the loss of a provider failure domain, observed from outside*. Redundancy is only a claim until an externally injected fault exercises it. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 84` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 83; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

Before mutation, the provision seal accounts for all UI-server/projector replicas, topology and disruption
constraints, post-fault Keycloak login/membership observation, gateway/auth/data/workflow dependency survival
after removal of every selected-zone member, fault overlap, retry/idempotency buffers, subscription catch-up,
Redis/Sentinel members, connection/key/client/output-buffer demand, failover and reconnect storms, cursor
repair reads, and the external operation matrix. An
unschedulable third zone, one-short post-fault dependency, one-short disruption budget, or unbounded replay
buffer refuses before the first provider or Kubernetes mutation.

## Doctrine adopted

- Adopt [`low_code_ui_runtime_doctrine.md` §14 — Runtime role, deployment, and high availability](../documents/engineering/low_code_ui_runtime_doctrine.md#14-runtime-role-deployment-and-high-availability): stateless replicas and resumable subscriptions, with no leader election.
- Adopt [`daemon_topology_doctrine.md` §4 — Worker daemons — N, unelected](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected): scale UI workers without granting control-plane authority.
- Adopt [`platform_services_doctrine.md` §2 — HA always — including `replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1): distinguish an HA-capable shape from an observed HA outcome.
- Adopt [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): bind the claim to an off-cluster challenge and provider-observed fault.
- Adopt [`ui_realtime_coordination_doctrine.md` §5 — Redis is ephemeral platform-internal coordination](../documents/engineering/ui_realtime_coordination_doctrine.md#5-redis-is-ephemeral-platform-internal-coordination),
  [`ui_realtime_coordination_doctrine.md` §6 — Durable commands, receipts, and replay](../documents/engineering/ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay),
  [`ui_realtime_coordination_doctrine.md` §7 — Replicas, drain, rollout, and gateway migration](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration),
  and [`ui_realtime_coordination_doctrine.md` §8 — Resource, observability, and failure obligations](../documents/engineering/ui_realtime_coordination_doctrine.md#8-resource-observability-and-failure-obligations): survive one-zone Redis/Sentinel and UI-server loss through bounded reconnect plus durable cursor/receipt repair.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 84.1: Run the multi-zone UI failure campaign ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 83](phase_83_ui_rollout_reconnect.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Deliver one externally observed provider-zone failure result for the complete UI path.

### Deliverables

- Provisioned multi-zone UI-server/projector topology with PDB and hard spread.
- Multi-zone Redis primary/replicas/Sentinel with bounded client reconnect and durable cursor/receipt repair;
  no Redis persistence or sticky-session dependency.
- Off-cluster three-principal/two-tenant OIDC challenge probe, cookie-empty post-fault login/current-membership
  check, and provider-driven whole-zone isolation.
- Read, idempotent mutation, workflow-start, reconnect, exactly-once accepted-action, cursor-resume, and
  same-owner/same-tenant/foreign-tenant denial observations.
- Named Haskell-authored structural, behavioral, and security changed subjects that independently defeat the HA claim.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-84 supporting suite must run; require the scoped canonical run green and
   every named Haskell changed subject red. The ledger must not classify unavailable provider observations above `UNVERIFIED`.

### Remaining Work

Run the campaign against at least three real provider zones with provider-confirmed whole-zone isolation,
off-cluster fresh OIDC, Gateway/Keycloak, Redis/Sentinel, Pulsar/SQL/MinIO, Kubernetes, CNI, and provider audit
observers. Until then, no provider HA claim exists.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the exact tested fault and bounds.
- `documents/engineering/platform_services_doctrine.md` — distinguish topology parity from observed HA.
- `documents/engineering/daemon_topology_doctrine.md` — record worker failover behavior without election.
- `documents/engineering/testing_doctrine.md` — link the off-cluster challenge and raw observer digests.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record the precise tested Redis/UI-server
  zone-fault envelope and retain the lossy-routing/durable-repair boundary.

**Cross-references to add:**

- The phase tracker, substrate map, and component inventory must identify this as the first UI HA claim.

## Related Documents

- [Development Plan](README.md)
- [Phase 83 — UI rollout and reconnect](phase_83_ui_rollout_reconnect.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
