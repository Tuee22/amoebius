# Phase 72: Atomic immutable UI-program release

> **Purpose**: Atomically release an immutable bound UI program as a content-addressed `ClientPlan` /
> `UiServerPlan` pair plus public-contract artifacts, without rebuilding the amoebius runtime image,
> and reject stale, missing, or mixed plan identities before any action executes.
> **Read this if**: phase 72 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 72.1: Release immutable UI plans without rebuilding the runtime](#sprint-721-release-immutable-ui-plans-without-rebuilding-the-runtime-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 71, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL gate barrier is independently
satisfied and gate-passed.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase owns the release projection from one bound UI program into an immutable paired `ClientPlan` and
serializable `UiServerPlan` manifest, public-contract objects, and content manifests carried atomically by the
Phase-71 release ledger. The server-plan object contains dispatch/policy/handler identities and codecs, not
serialized Haskell functions; its named handlers must exist in the linked runtime. The generic PureScript
runtime is a **baked asset of the one amoebius runtime image** — the UI server is a worker responsibility of
the same amoebius executable ([`low_code_ui_runtime_doctrine.md §13`](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server)),
so that image carries its ABI/component-catalog identity. Changing an app program changes
content artifacts and the release hash, never an app-specific image layer or a handwritten frontend bundle.

Every effect request carries the exact current program, content, contract, policy, and scope identities.
Without a checked compatibility witness, a stale authority or content digest returns `ReloadRequired` before
dispatch; the browser's digest is an observation, not a capability.
The pair also pins the WebSocket subprotocol, routing-envelope schema, and cursor codec. A rolling deployment
cannot admit a frame whose program/ABI/routing epoch does not exact-match an active compatible plan.

Supporting observation: the `ui-program-release-live-gate` Haskell component suite may exercise the seam, but the
sole acceptance command is `pb validate phase 72`. Split if the work requires a new rollout engine, durable
schema migration, amoebius runtime image build, or independently useful second claim.
**Phase scope:** one cohesive claim — *a UI program is released atomically by content address, without rebuilding the runtime image*. A stale or mixed plan identity is refused before any action executes.

**Substrate:** linux-cpu
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Depends on:** [Phase 71](phase_71_release_lifecycle.md)
**Gate:** `pb validate phase 72`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *a UI program is released atomically by content address, without rebuilding the runtime image*. A stale or mixed plan identity is refused before any action executes. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 72` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 71; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every artifact atomic immutable UI-program release emits is a recipe over a content address, never an authored file.
- [Low-Code UI Runtime §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts):
  bind exact identities, immutable plans, compatibility witnesses, and pre-dispatch stale rejection.
- [Generated Artifacts Doctrine §2 — What is generated and from what](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  generate plans, contract manifests, dispatch tables, and the generic bundle lazily beneath ignored
  `.build/**`; retain only their Haskell declarations and generators.
- [`release_lifecycle_doctrine.md` §2 — `Release` and the immutable release ledger (`releaseHash`)](../documents/engineering/release_lifecycle_doctrine.md#2-release-and-the-immutable-release-ledger-releasehash):
  carry UI content under the existing immutable release identity.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence):
  observe the fresh authorized action outside the UI server.
- [UI Realtime Coordination §7 — replicas, drain, rollout, and gateway migration](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): pin the WebSocket/routing/cursor ABI needed during rolling overlap.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint result below is historical context. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor gate pass, owned legacy closure, and a complete gate pass.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 72.1: Release immutable UI plans without rebuilding the runtime ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 71](phase_71_release_lifecycle.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [Low-Code UI Runtime §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts):
make a UI program an atomic immutable client/server-plan release with exact authority identities and no
per-app frontend image, half-published plan, mixed-plan execution, or stale-plan execution path.

### Deliverables

- Deterministic paired client/server plan objects, UI release manifests, and exact source-key equality from
  `BoundUiProgram`.
- Compatibility checking and fail-closed `ReloadRequired` admission before handler lookup.
- One amoebius runtime image identity shared by the two gate releases.
- Phase-0 Haskell declarations and independent expectations for manifests, plan-pair/stale-digest matrices, the
  fresh action, and three named Haskell mutation operators; serialized forms are lazy `.build/**` outputs.
- A Register-3 ledger recording authenticated challenge and repository-local evidence digests.

### Validation

1. Rejected historical observation: the `ui-program-release-live-gate` Cabal suite recorded a linux-cpu path
   through Keycloak and Envoy.
2. Publish both program revisions and compare both immutable plan objects, release hashes, source keys, and
   atomic pointer history with the independent Haskell expectations.
3. Send matching, stale-authority, stale-content, missing-half, A-client/B-server, and B-client/A-server
   requests; require the two matching canary actions and zero invalid-pair actions.
4. Assert one unchanged generic client image and no per-program image or repository-retained generated plan.
5. Re-run each named Haskell changed-subject mutation and require the same command to fail on its owned assertion.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED. Future compatibility-witness coverage and rolling overlap/reconnect remain owned by
their later phases and are not claimed by this gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the tested stale-plan rejection and
  one-generic-runtime-image boundary.
- `documents/engineering/generated_artifacts_doctrine.md` — record plans, codecs, dispatch tables, and app
  manifests as content-addressed outputs generated lazily beneath ignored `.build/**` and absent from version
  control.
- `documents/engineering/release_lifecycle_doctrine.md` — record the immutable UI objects and two-release
  pointer history under the release hash.
- `documents/engineering/testing_doctrine.md` — record the fresh action, repository-local evidence, independent
  Haskell manifest expectations, and killed Haskell stale-digest/image-rebuild changed subjects.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and flip status only after
  its linux-cpu Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register the release modules and generic-runtime ownership.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 70 — UI projection runtime](phase_70_ui_projection_runtime.md)
- [Phase 71 — release lifecycle](phase_71_release_lifecycle.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md)
- [Release Lifecycle Doctrine](../documents/engineering/release_lifecycle_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
