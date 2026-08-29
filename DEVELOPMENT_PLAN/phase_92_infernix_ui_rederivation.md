# Phase 92: The infernix workflow and artifact contracts, re-derived

> **Purpose**: Re-derive infernix's workflow and ready-artifact contracts against the generic amoebius UI runtime and
> test that an authenticated own-tenant interaction succeeds while a tenant/scope-mismatched artifact handle
> produces no inference effect, with workflow acceptance recoverable from the original durable command
> receipt rather than a WebSocket or Redis acknowledgement.
> **Read this if**: phase 92 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 92.1: Bind the infernix workflow-to-interaction UI adapter ⏸️](#sprint-921-bind-the-infernix-workflow-to-interaction-ui-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 91, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and reviewer-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**What this phase re-derives, and what it must add.** The seed's workflow and artifact contracts become amoebius's own, indexed by the request scope so a receipt cannot be read under an identity that did not produce it. The seed's SPA is read as evidence that the interaction is realizable; none of it is imported.

This phase owns one adapter seam: the scoped Phase-91 `ReadyArtifactHandle` and Phase-70 durable-receipt fold
become a typed UI module and bound ports consumed by the generic runtime. The adapter is a leaf package linked
one way to `amoebius:dsl-core` and `infernix-lift`; the sibling handwritten SPA remains an external, untracked
UX reference only — never repository source, executable gate input, a second frontend, or an authority source.

An authenticated user starts an infernix workflow, observes its bounded progress, receives a server-issued
`ReadyArtifactHandle` only after successful committed/provenance-compatible completion, and invokes the
artifact through a typed `ModelInteractor`. The browser receives no model path, digest authority, engine
address, tenant identifier, provider credential, or raw response.

The adapter validates one opaque `RequestId`, derives a scope-qualified `CommandId` from the current trusted
app/tenant/owner/port context, and makes that command identity the work identity. Its Phase-70 fold produces a
durable receipt keyed by `(AppId, TenantId, Owner, CommandId)` and carrying the same work-id,
`WorkflowHandle`, normalized input digest, and typed outcome. The scoped live harness has a second server
origin recover that receipt from MinIO. Redis may eventually wake a socket-owning replica and an authenticated
WebSocket may deliver the outcome, but neither mechanism establishes acceptance. The
infernix start port is eligible for the explicitly bounded offline queue contract in
[Low-Code UI Runtime §12](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux);
progress is a cursor-backed cached projection, while signals, cancellation, and artifact invocation remain
online-only in the initial adapter contract.

The public computation used here is the Phase-0 `reference-uppercase` interactor. The live result therefore
does not establish correspondence with the complete Phase-91 inference chain, production TinyLlama, or the
full sibling inference engine.

The bounded campaign covers one adapter/program, one pure suite, one evidence reader, and one aggregate
command; it excludes a new generic UI constructor, Phase-91 compute change, or second client runtime.
**Phase scope:** one cohesive claim — *a scope-mismatched artifact handle produces no inference effect at all*. Workflow acceptance stays recoverable from the durable command that requested it.

**Substrate:** linux-cpu
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Depends on:** [Phase 91](phase_91_infernix_rederivation.md)
**Gate:** `pb validate phase 92`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *a scope-mismatched artifact handle produces no inference effect at all*. Workflow acceptance stays recoverable from the durable command that requested it. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 92` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 91; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux):
  introduce only a server-issued ready handle and typed infernix ports.
- [Low-Code UI Runtime §10.3 — Information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels):
  keep artifact/result values within their derived tenant, audience, and integrity sinks.
- [Low-Code UI Runtime §18 — Honesty boundary](../documents/engineering/low_code_ui_runtime_doctrine.md#18-honesty-boundary):
  distinguish checked shape from live provider/tenant enforcement.
- [UI Realtime Coordination §3 — One browser transport contract](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract),
  [UI Realtime Coordination §4 — Typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope),
  [UI Realtime Coordination §5 — Redis is ephemeral platform-internal coordination](../documents/engineering/ui_realtime_coordination_doctrine.md#5-redis-is-ephemeral-platform-internal-coordination),
  and [UI Realtime Coordination §6 — Durable commands, receipts, and replay](../documents/engineering/ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay):
  carry typed results over the same-origin WebSocket, use Redis only for cross-pod wake-up/routing, and derive
  workflow acceptance from a durable scope-qualified receipt.
- [Lift and Compose Doctrine §5 — The re-derivation map](../documents/engineering/lift_and_compose_doctrine.md#5-the-re-derivation-map):
  reuse infernix's computational substance through the linked adapter while replacing its envelope.
- [Tenancy Doctrine §7 — Two isolation layers and the honest limit](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit):
  pair typed scope with provider-enforced live denial.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and an authorized-reviewer tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 92.1: Bind the infernix workflow-to-interaction UI adapter ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 91](phase_91_infernix_rederivation.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux):
adapt the linked infernix workflow and artifact contracts to the generic UI runtime without importing the
sibling SPA's code, transport, credentials, or authority assumptions.

### Deliverables

- A linked Haskell infernix UI adapter with typed workflow, ready-artifact, invocation, and public-error ports,
  preserving the original command/workflow identity into the durable terminal receipt.
- One Haskell-declared UI module using only trusted catalog components and the Phase-72 release path; any Dhall
  projection is generated lazily beneath ignored `.build/**` and remains untracked.
- The Phase-0 Haskell public-contract, interaction, scope, and hostile-output oracle corpus.
- The Haskell-authored changed-subject scope and terminal-command-correlation mutants.
- A Register-3 evidence ledger with challenge, credential provenance, external observer digests, and teardown.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-92 supporting suite must run on `linux-cpu`.
2. Require the pure contract to cover opaque handles, trusted-scope command derivation, durable identity,
   exact resend, changed-input conflict, foreign-owner/tenant and stale-scope denial, and hostile output.
3. Require the fresh live record to bind browser, tenant sessions, retained providers, reference worker,
   ready-last artifact, one-message topics, second-origin receipt recovery, denial, and exact cleanup.
4. Compile each named Haskell changed subject independently, require its exact marker to fail, then restore and rerun both
   Haskell suites before sealing the enumeration ledger.

### Remaining Work

No remaining work inside the scoped deliverable. Full browser-through-Envoy routing, Kubernetes UI-server
replicas, Phase-92 native CBOR, full Phase-91 inference-output correspondence, production TinyLlama,
Redis/WebSocket recovery, direct-service NetworkPolicy, and the wider live scope matrix remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record only the tested workflow-to-ready-artifact
  UI interaction and exact tenant/scope matrix.
- `documents/engineering/lift_and_compose_doctrine.md` — keep the sibling SPA an external, untracked UX
  reference only and name only the linked Haskell adapter and generic runtime as trusted implementation.
- `documents/engineering/tenancy_doctrine.md` — record the live provider denial without claiming general
  noninterference.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record only the tested infernix
  terminal-event-to-receipt correlation; cross-pod Redis/socket fault behavior remains Phase 84's claim.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and report its scoped
  `linux-cpu` Register-3 seal.
- `DEVELOPMENT_PLAN/system_components.md` — register the Haskell infernix UI adapter and Haskell projection
  emitter under Phase 92; its generated Dhall output remains untracked and is not a component-inventory row.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 70 — UI projection runtime](phase_70_ui_projection_runtime.md)
- [Phase 72 — atomic UI program release](phase_72_ui_program_release.md)
- [Phase 91 — infernix lift](phase_91_infernix_rederivation.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
