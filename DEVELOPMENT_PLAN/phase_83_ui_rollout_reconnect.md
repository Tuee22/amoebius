# Phase 83: UI rollout, projection catch-up, and reconnect

> **Purpose**: Prove a checked UI program can roll from release A to B and roll back without stale-plan
> effects, premature traffic shift, lost owner-scoped projections, or discarded reconnect cursors.
> **Read this if**: phase 83 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_69_spa_live_deploy.md (rollout/reconnect portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 83.1: Execute and verify the coherent UI release transition ⏸️](#sprint-831-execute-and-verify-the-coherent-ui-release-transition-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 82, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase owns one live release transition: projectors catch up to B's recorded watermark, the gateway shifts
traffic only afterward, old and new plan/ABI identities coexist only under a checked compatibility witness,
subscriptions resume from owner-scoped cursors, and rollback returns to A's immutable release. It does not
claim replica or zone failure tolerance; Phase 84 owns that fault boundary.
Connection registrations and routed envelopes carry the admitted program/ABI epoch. Draining replicas stop
accepting sockets, remove or expire Redis registrations, issue a bounded reconnect control frame, and retain
old decoders until their compatibility window closes.

Supporting observation: a phase-number-neutral Haskell rollout/reconnect suite may exercise the single
`A → B → A` transition; the sole acceptance command is `pb validate phase 83`. Split if the work introduces
another rollout algorithm, substrate, or infrastructure-failure injection.

**Phase scope:** one cohesive claim — *a release rolls forward and back without stale-plan effects or discarded cursors*. Catch-up is what makes a projection survive the rollout that interrupted it.

**Substrate:** `linux-cpu` ([§L](development_plan_standards.md#l-one-substrate-discipline)). Every hardware
substrate can always run `linux-cpu`. When the gate needs a pristine Linux host, use Incus on Linux or
Linux-CUDA, Lima on Apple, and WSL2 on Windows.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 82](phase_82_ui_multi_tenant_live.md)
**Gate:** `pb validate phase 83`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *a release rolls forward and back without stale-plan effects or discarded cursors*. Catch-up is what makes a projection survive the rollout that interrupted it. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 83` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 82; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- Adopt [`release_lifecycle_doctrine.md` §5 — `RolloutPlan` / `RolloutPhase`: the readiness-gated apply](../documents/engineering/release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply): move only immutable release pointers and ordered gateway weights.
- Adopt [`low_code_ui_runtime_doctrine.md` §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): enforce exact plan/contract epochs or checked compatibility.
- Adopt [`pulsar_client_doctrine.md` §5.1 — Two derived capabilities (read-model), and two deliberately absent ones](../documents/engineering/pulsar_client_doctrine.md#51-two-derived-capabilities-read-model-and-two-deliberately-absent-ones): catch up and resume owner-scoped projections.
- Adopt [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): observe the transition through independent live observers.
- Adopt [`ui_realtime_coordination_doctrine.md` §7 — Replicas, drain, rollout, and gateway migration](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): drain connection ownership and preserve cursor/ABI compatibility without sticky sessions.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 83.1: Execute and verify the coherent UI release transition ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 82](phase_82_ui_multi_tenant_live.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Deliver one coherent, reversible UI release transition with scope-preserving reconnect.

### Deliverables

- Release-A/B compatibility and projector-watermark admission.
- Ordered Gateway API shift, stale-client handling, cursor resume, and CAS rollback.
- Real three-principal/two-tenant authority plus external API/Gateway/Pulsar/browser/CNI traces with fresh
  nonces.
- Haskell-authored early-shift, cursor-discard, and tenant-cursor-key changed-subject mutations.
- Draining connection-registration lifecycle and a Haskell-authored stale-registration changed subject.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-83 supporting suite must run on `linux-cpu`; the scoped canonical
   transition must match the pinned custody and local timeline/cursor/scope predicates, all four Haskell changed subjects must
   fail at their pinned loci, and unsupported provider observations must remain `UNVERIFIED`.

### Remaining Work

Run the same transition through real Keycloak sessions, Gateway API/Envoy access logs, a native Pulsar
watermark observer, a browser-network proxy, Kubernetes audit, and CNI/provider zero-effect observations.
Those surfaces are deliberately `UNVERIFIED`; the scoped local gate does not substitute for them.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/release_lifecycle_doctrine.md` — record the coherent rollout/rollback evidence.
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record stale-plan and compatibility behavior.
- `documents/engineering/pulsar_client_doctrine.md` — record watermark and cursor-resume evidence.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record program/ABI-bound connection drain
  and non-sticky reconnect behavior.

**Cross-references to add:**

- The phase tracker, substrate map, and component inventory must link this transition and ledger.

## Related Documents

- [Development Plan](README.md)
- [Phase 72 — atomic UI program release](phase_72_ui_program_release.md)
- [Phase 82 — multi-tenant UI](phase_82_ui_multi_tenant_live.md)
- [Release Lifecycle Doctrine](../documents/engineering/release_lifecycle_doctrine.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
