# Phase 85: Offline replay and durable receipts

> **Purpose**: Reconnect an encrypted browser outbox to current authority and prove that an accepted offline
> command is established by its durable effect owner, never merely by Redis delivery.
> **Read this if**: phase 85 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 85.1: Gate durable replay across replicas ⏸️](#sprint-851-gate-durable-replay-across-replicas-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 84, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase's target contract covers current-session reauthentication, scope/program compatibility checks, bounded ordered
replay, typed outcomes, and durable idempotency/receipt lookup for SQL, object, and workflow effects. The
browser reconnects by authenticated WebSocket; any UI-server replica can recover an outcome from durable
provider/Pulsar projections. Redis routes live outcomes only. Flushing Redis or dropping a socket may delay a
result but cannot lose, invent, or duplicate an accepted effect.

The bounded campaign must gate scalar commands and one infernix ready-artifact workflow start with a small result
payload; offline blob transfer is deferred to Phase 86. Phase 41 structurally admits jitML training starts,
but this linux-cpu gate does not claim a live offline CUDA training result.

**Phase scope:** one cohesive claim — *an accepted offline command is established by its durable effect owner*. Delivery through Redis is transport, and transport is never acceptance.

**Substrate:** `linux-cpu` — the baseline lane every hardware substrate reaches
([`substrate_doctrine.md` §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule)).

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure.

**Depends on:** [Phase 84](phase_84_ui_ha_multizone.md)
**Gate:** `pb validate phase 85`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *an accepted offline command is established by its durable effect owner*. Delivery through Redis is transport, and transport is never acceptance. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 85` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 84; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

The provision seal includes at least two UI-server replicas, WebSocket connections and buffers, Redis
connections/keys/fanout, replay concurrency, receipt retention/lookups, provider transaction overlap, cursor
repair, and the declared reconnect storm. No unbounded outbox, output buffer, or retry queue is admitted.

## Doctrine adopted

- Adopt [`browser_offline_runtime_doctrine.md` §9 — Authoritative replay and typed outcomes](../documents/engineering/browser_offline_runtime_doctrine.md#9-authoritative-replay-and-typed-outcomes): replay always revalidates current authority.
- Adopt [`ui_realtime_coordination_doctrine.md` §6 — Durable commands, receipts, and replay](../documents/engineering/ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay): Redis is never durable acceptance evidence.
- Adopt [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): external fresh-effect observation.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 85.1: Gate durable replay across replicas ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 84](phase_84_ui_ha_multizone.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Prove that every accepted replay has one recoverable durable receipt and current authorization.

### Deliverables

- Typed replay session and outcomes with current-authority validation.
- Scope-qualified idempotency and durable receipt adapters.
- One infernix queued-start adapter preserving its original command/work-id into the ready-artifact receipt;
  no offline jitML live claim on this substrate.
- Cross-replica outcome routing and cursor repair after Redis/socket loss.
- A Haskell-authored live challenge, denial, and changed-subject harness.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-85 supporting suite must run; require the scoped canonical trace green,
   the dropped response repaired from the durable owner, and all six Haskell changed subjects red.

### Remaining Work

Repeat the campaign with real OIDC, Redis loss, Pulsar/MinIO/PostgreSQL observers, the infernix worker,
Gateway/Kubernetes/CNI, and direct-service denial. Offline jitML/CUDA is not claimed by this CPU-only phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/browser_offline_runtime_doctrine.md` — record tested replay outcomes and limits.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record receipt repair across Redis loss.
- `documents/engineering/resource_capacity_doctrine.md` — record exact live demand operands.
- `documents/engineering/testing_doctrine.md` — link provider-observed fresh-effect evidence.

**Cross-references to add:**

- The tracker, substrate map, and component inventory must identify replay and receipt modules.

## Related Documents

- [Development Plan](README.md)
- [Development Plan Standards](development_plan_standards.md)
- [Browser Offline Runtime](../documents/engineering/browser_offline_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
