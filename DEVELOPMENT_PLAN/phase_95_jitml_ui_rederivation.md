# Phase 95: The jitML training and checkpoint contracts, re-derived

> **Purpose**: Re-derive jitML's training, checkpoint, and ready-model contracts against the generic UI runtime and test
> only an owned, pointer-committed, Ready model can be invoked from the authenticated application, with the terminal
> training receipt recoverable across UI-server, Redis, and WebSocket loss.
> **Read this if**: phase 95 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_94_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_96_webapp_rederivation.md, documents/engineering/content_addressing_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 95.1: Bind the jitML training-to-ready-model UI adapter ⏸️](#sprint-951-bind-the-jitml-training-to-ready-model-ui-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 94, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

**What this phase re-derives, and what it must add.** The seed's training and checkpoint contracts become
scope-indexed values, so a model handle cannot cross from the tenant that trained it. The seed's own numerics
remain an external reference implementation, never a linked dependency or repository vector source;
independent expectations are authored in Haskell.

This phase owns one adapter seam: the Phase-94 training/checkpoint/model contracts become typed UI workflow and
artifact ports consumed by the generic runtime and released through Phase 72. The linked Haskell adapter
projects bounded progress, checkpoint provenance, readiness, model input/output, and public errors. It cannot
mint readiness from a path, digest, progress label, or client claim.

An authenticated user starts a jitML training run, observes bounded progress, and receives a subject-owned
`ReadyArtifactHandle Model` only after the adopted checkpoint is committed, provenance-verified,
owner/scope-authorized, and compatible with its serving engine. A failed or in-flight checkpoint has no
conversion to that handle. The browser receives neither checkpoint storage coordinates nor GPU/provider
authority.

`JitML.UiAdapter` cannot mint request or workflow identity. The generic server first admits the browser's
opaque `RequestId` against current app, tenant, owner, and port authority, then deterministically qualifies it
as the `CommandId` supplied to Phase 94. That value remains the work-id in all native-CBOR training events.
Phase 71 projects a terminal event into an owner/command-keyed receipt containing the normalized training
digest, `WorkflowHandle`, checkpoint disposition, and ready-model result. Replicas read that durable projection;
Redis fanout and the authenticated socket merely accelerate presentation. The jitML training-start port is
eligible for the explicitly bounded offline queue
contract in
[Low-Code UI Runtime §12](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux);
progress is a cursor-backed cached projection, while training signals,
cancellation, and model invocation remain online-only in the initial adapter contract.

Supporting observation: the `jitml-ui-lift-live-gate` Haskell component suite may exercise the Haskell adapter/program, but
the sole acceptance command is `pb validate phase 95`. Split if the work changes Phase-94 training/commit,
reopens Phase-70 failover, adds a generic UI
constructor, introduces another runtime image, or needs a second independently useful claim.
**Phase scope:** one cohesive claim — *only an owned, pointer-committed, Ready model can be invoked*. Here,
"committed" names observed content-store pointer state, never a version-control operation or repository
artifact. The terminal receipt survives the loss of the UI server, the cache and the socket that delivered it.

**Substrate:** linux-cuda
**Lane:** cuda ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Depends on:** [Phase 94](phase_94_jitml_rederivation.md)
**Gate:** `pb validate phase 95`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *only an owned, pointer-committed, Ready model can be invoked*. The terminal receipt survives the loss of the UI server, the cache and the socket that delivered it. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 95` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 94; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

The live provision seal includes at least two UI-server replicas, their WebSocket/frame/heartbeat buffers,
Redis connections/keys/fanout, receipt retention and lookup concurrency, cursor repair, reconnect overlap, the
Phase-94 trainer/accelerator demand, and the pinned fault window. A one-replica, sticky-only, pod-local receipt,
unbounded Redis/output-buffer, or one-short post-fault lookup shape refuses before the gate starts.

## Doctrine adopted

- [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux):
  admit invocation only through a server-issued ready-model handle.
- [Low-Code UI Runtime §10.3 — Information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels):
  constrain checkpoint, model, input, and output flow by derived tenant/audience/integrity witnesses.
- [Low-Code UI Runtime §18 — Honesty boundary](../documents/engineering/low_code_ui_runtime_doctrine.md#18-honesty-boundary):
  keep runtime readiness, provider enforcement, and tested isolation explicit.
- [UI Realtime Coordination §3 — One browser transport contract](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract),
  [UI Realtime Coordination §4 — Typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope),
  [UI Realtime Coordination §5 — Redis is ephemeral platform-internal coordination](../documents/engineering/ui_realtime_coordination_doctrine.md#5-redis-is-ephemeral-platform-internal-coordination),
  and [UI Realtime Coordination §6 — Durable commands, receipts, and replay](../documents/engineering/ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay):
  preserve the scoped command receipt outside Redis, route across UI replicas, and repair delivery after
  Redis/socket loss.
- [Lift and Compose Doctrine §5 — The re-derivation map](../documents/engineering/lift_and_compose_doctrine.md#5-the-re-derivation-map):
  reuse jitML training/model substance through the linked adapter while replacing its envelope.
- [Tenancy Doctrine §7 — Two isolation layers and the honest limit](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit):
  pair scope-indexed handles with live provider denial.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 95.1: Bind the jitML training-to-ready-model UI adapter ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 94](phase_94_jitml_rederivation.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux):
adapt linked jitML training and model contracts to the generic runtime without importing the sibling SPA,
reimplementing training, or turning a checkpoint identifier into browser authority.

### Deliverables

- A linked Haskell jitML UI adapter with typed training, progress, readiness, model-invocation, and error ports,
  preserving the original command/workflow identity into the durable terminal receipt.
- One Haskell-declared UI module released as Phase-73 content under the unchanged amoebius runtime image; any
  Dhall projection is generated lazily beneath ignored `.build/**` and remains untracked.
- Phase-0 Haskell public-contract, interaction, readiness/owner/scope, and hostile-output cases and expectations.
- Haskell-authored changed-subject readiness, tenant-scope, same-tenant-owner, local-only-route, and
  Redis-as-receipt operators.
- A Register-3 ledger with challenge, authority provenance, external observer digests, and teardown evidence.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-95 supporting suite must run on linux-cuda.
2. Drive training to a successful checkpoint observed through its content-store pointer, verify Ready-handle issuance, invoke it, and compare
   the UI result and external GPU execution with the independent Haskell oracle; require the durable receipt to retain
   the exact original command/workflow identities.
3. Pin the socket to replica A and originate receipt delivery through replica B; flush Redis and drop the
   socket after durable commit, then require reconnect/receipt lookup to return the outcome once with no second
   training, CUDA, Pulsar-start, object, or pointer effect.
4. Replay the exact handle/input under tenant A's non-owner and tenant B's owner, then replay in-flight and
   failed checkpoint handles under the owning subject; require pinned denials and zero forbidden effects.
5. Assert model output remains escaped presentation and creates no authority-bearing follow-on request.
6. Apply all five named Haskell changed subjects and require the unchanged gate command to fail on their exact matrix rows.

### Remaining Work

No remaining work inside the scoped deliverable. Fresh Keycloak/Envoy authority, Kubernetes UI replicas,
retained MinIO/Pulsar/Redis receipt routing, the full sibling serving engine, same-flow Phase-94 training and
commit, direct-worker policy, general noninterference, and multi-zone availability remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record only the tested
  training/checkpoint-to-ready-model UI interaction and exact denial matrix.
- `documents/engineering/lift_and_compose_doctrine.md` — keep the sibling SPA an external, untracked UX
  reference only and Phase-94's numerical/training core an inherited dependency.
- `documents/engineering/tenancy_doctrine.md` — record live scope/readiness denial without claiming general
  noninterference.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record the exact tested two-replica
  jitML receipt-routing and Redis/socket-repair envelope without promoting it to an HA claim.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and flip status only after
  the linux-cuda Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register the Haskell jitML UI adapter and Haskell projection emitter
  under Phase 95; generated Dhall output remains untracked and is not a component-inventory row.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 71 — UI projection runtime](phase_71_ui_projection_runtime.md)
- [Phase 73 — atomic UI program release](phase_73_ui_program_release.md)
- [Phase 94 — jitML lift and CUDA](phase_94_jitml_rederivation.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
