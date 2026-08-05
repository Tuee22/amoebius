# Phase 52: jitML UI lift

> **Purpose**: Lift jitML training, checkpoint, and ready-model contracts into the generic UI runtime and test
> only an owned, committed, Ready model can be invoked from the authenticated application, with the terminal
> training receipt recoverable across UI-server, Redis, and WebSocket loss.
> **Read this if**: phase 52 is next in the queue, or a later phase depends on what its gate establishes.

Phase 52 does for jitML's numerics-facing surface what phase 50 did for infernix, and is the second and last such lift; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), [lift_and_compose_doctrine.md](../documents/engineering/lift_and_compose_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cuda` substrate.
No gate has run.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_51_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — bounded jitML realtime envelope](#resource-provision--bounded-jitml-realtime-envelope)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 52.1: Bind the jitML training-to-ready-model UI adapter 📋](#sprint-521-bind-the-jitml-training-to-ready-model-ui-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. The jitML UI adapter and its live readiness/scope evidence are not implemented; the sibling demo
SPA remains UX evidence rather than amoebius proof or executable input.

## Phase Summary

This phase owns one adapter seam: the Phase-51 training/checkpoint/model contracts become typed UI workflow and
artifact ports consumed by the generic runtime and released through Phase 40. The linked Haskell adapter
projects bounded progress, checkpoint provenance, readiness, model input/output, and public errors. It cannot
mint readiness from a path, digest, progress label, or client claim.

An authenticated user starts a jitML training run, observes bounded progress, and receives a subject-owned
`ReadyArtifactHandle Model` only after the adopted checkpoint is committed, provenance-verified,
owner/scope-authorized, and compatible with its serving engine. A failed or in-flight checkpoint has no
conversion to that handle. The browser receives neither checkpoint storage coordinates nor GPU/provider
authority.

`JitML.UiAdapter` cannot mint request or workflow identity. The generic server first admits the browser's
opaque `RequestId` against current app, tenant, owner, and port authority, then deterministically qualifies it
as the `CommandId` supplied to Phase 51. That value remains the work-id in all native-CBOR training events.
Phase 38 projects a terminal event into an owner/command-keyed receipt containing the normalized training
digest, `WorkflowHandle`, checkpoint disposition, and ready-model result. Replicas read that durable projection;
Redis fanout and the authenticated socket merely accelerate presentation. The jitML training-start port is
eligible for the explicitly bounded offline queue
contract in
[Low-Code UI Runtime §12](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux);
progress is a cursor-backed cached projection, while training signals,
cancellation, and model invocation remain online-only in the initial adapter contract.

**Session scope:** In one uninterrupted engineering session, implement only the jitML UI adapter/program and
accept it with `cabal test jitml-ui-lift-live-gate`. Split if the work changes Phase-51 training/commit,
reopens Phase-37 failover, adds a generic UI
constructor, introduces another runtime image, or needs a second acceptance command.
**Substrate:** linux-cuda
**Register:** 3 (live infrastructure)
**Gate:** `cabal test jitml-ui-lift-live-gate` drives an authenticated training/checkpoint flow to an owned
Ready jitML model and invokes it through the generic UI with a fresh challenge; same-tenant non-owner,
foreign-tenant/scope, and non-Ready/failed checkpoint twins must be denied before inference dispatch with zero
forbidden effect. It also pins the browser WebSocket to UI replica A, causes the terminal receipt notification
to originate through replica B, flushes Redis and drops the socket after durable commit but before delivery,
then requires reconnect and authoritative receipt recovery with no duplicate training effect. The fixtures,
observers, oracle, and mutants are delegated to
[Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Before implementation, Phase 0 commits
  `test/dhall/phase_52/jitml_ui.dhall`,
  `test/fixtures/phase_52/readiness_owner_scope_matrix.tsv`,
  `test/fixtures/phase_52/public_contract.golden`,
  `test/fixtures/phase_52/expected_interaction.tsv`,
  `test/fixtures/phase_52/cross_pod_receipt_timeline.tsv`, and fixed bounded training/model-input fixtures. The
  UI uses trusted `WorkflowProgress`, `ArtifactProvenance`, and `ModelInteractor` components.
- **Fresh authority and challenge.** After Keycloak/Envoy, at least two UI-server replicas, Redis, and the
  Phase-51 jitML workers are Ready, the harness obtains least-privilege sessions for tenant A's artifact owner,
  a tenant-A non-owner, and tenant B's foreign owner, then generates an unpredictable client request id and
  model input. The server-derived scoped command id, command, progress/terminal events, durable receipt,
  training result, and model invocation must retain the command/workflow identities and carry the challenge to
  the external execution/result evidence.
- **Cross-pod receipt routing and repair.** The harness proves from edge/backend identity that the authenticated
  socket is owned by replica A while replica B handles the terminal receipt notification. It then flushes Redis
  and drops the socket between durable receipt materialization and delivery. Reconnect to a current replica
  must recover the exact scoped receipt and terminal model handle from Phase 38 once, without sticky routing,
  pod-local truth, a second Pulsar start, another trainer/CUDA execution, or another pointer advance.
- **Paired ready/owner/scope cases.** The subject-owned committed Ready model succeeds. The exact same handle
  and input under tenant A's non-owner and tenant B's owner differ only by authenticated authority and must be
  denied. Under the owning subject, handles referring to an in-flight checkpoint and a failed checkpoint differ
  only by readiness state and must also be denied.
- **Zero forbidden effect and bypass check.** Each denial produces no inference dispatch, GPU execution,
  Pulsar command, checkpoint/object read, cache materialization, or result write. A direct browser-origin probe
  to the jitML worker must fail at the platform boundary.
- **Observer outside the SUT.** Playwright observes the browser; Envoy and Keycloak establish request/session
  provenance and backend identity; Pulsar offsets, MinIO audit/manifests, the checkpoint pointer history, and
  the accelerator-owner device-hold/kernel-launch trace establish training and invocation. A Redis-side
  observer establishes route loss only; adapter/UI-server/Redis self-report cannot establish the receipt or
  accepted effect.
- **Committed mutants.** Phase 0 commits
  `test/mutants/phase_52/mut-52-mint-ready-from-checkpoint-path.patch` (guard weakening) and
  `test/mutants/phase_52/mut-52-ignore-artifact-scope.patch`, plus
  `test/mutants/phase_52/mut-52-ignore-artifact-owner.patch`,
  `test/mutants/phase_52/mut-52-local-only-websocket-route.patch`, and
  `test/mutants/phase_52/mut-52-redis-as-receipt.patch`. Each must turn its readiness, tenant-scope,
  same-tenant-owner, cross-pod route, or durable-repair row red.
- **Independent oracle.** The readiness/owner/scope matrix and public result are hand-authored from the public model
  contract and an off-adapter reference computation. They do not call the adapter, UI renderer, checkpoint
  pointer helper, or serving handler under test.
- **Information-flow check.** Model output remains untrusted tenant-scoped presentation. A committed
  authority-shaped output string must render escaped and cannot become a route, port, grant, policy, or model
  handle.
- **Honesty.** This gate tests one bounded linux-cuda workflow, one ready model, two readiness failures, one
  same-tenant non-owner, one foreign tenant, and one Redis/socket-loss timeline across two UI replicas. It
  inherits Phase-51 training/commit and Phase-37 failover evidence without retesting either boundary or
  claiming general noninterference, Redis availability, or multi-zone HA.

## Resource provision — bounded jitML realtime envelope

The live provision seal includes at least two UI-server replicas, their WebSocket/frame/heartbeat buffers,
Redis connections/keys/fanout, receipt retention and lookup concurrency, cursor repair, reconnect overlap, the
Phase-51 trainer/accelerator demand, and the pinned fault window. A one-replica, sticky-only, pod-local receipt,
unbounded Redis/output-buffer, or one-short post-fault lookup shape refuses before the gate starts.

## Doctrine adopted

- [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux):
  admit invocation only through a server-issued ready-model handle.
- [Low-Code UI Runtime §10.3 — Information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels):
  constrain checkpoint, model, input, and output flow by derived tenant/audience/integrity witnesses.
- [Low-Code UI Runtime §18 — Honesty boundary](../documents/engineering/low_code_ui_runtime_doctrine.md#18-honesty-boundary):
  keep runtime readiness, provider enforcement, and tested isolation explicit.
- [UI Realtime Coordination §§3–6](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract):
  preserve the scoped command receipt outside Redis, route across UI replicas, and repair delivery after
  Redis/socket loss.
- [Lift and Compose Doctrine §2 — What lifts (the reuse map)](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map):
  reuse jitML training/model substance through the linked adapter while replacing its envelope.
- [Tenancy Doctrine §7 — Two isolation layers and the honest limit](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit):
  pair scope-indexed handles with live provider denial.

## Sprints

## Sprint 52.1: Bind the jitML training-to-ready-model UI adapter 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/UiAdapter.hs`, `dhall/ui/jitml.dhall`, and
`test/live/Phase52JitMLUiLift.hs` (target paths; not yet built)
**Blocked by**: Phase 31 gate; Phase 40
gate; Phase 51 gate.
**Independent Validation**: the live harness checks the
ready/failed/in-flight/non-owner/foreign matrix against Keycloak, Envoy, Pulsar, MinIO, checkpoint, GPU,
Redis-route, durable-receipt, and browser evidence; all five committed mutants must turn red.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/lift_and_compose_doctrine.md`, `documents/engineering/tenancy_doctrine.md`, and
`documents/engineering/ui_realtime_coordination_doctrine.md`.

### Objective

Adopt [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux):
adapt linked jitML training and model contracts to the generic runtime without importing the sibling SPA,
reimplementing training, or turning a checkpoint identifier into browser authority.

### Deliverables

- A linked Haskell jitML UI adapter with typed training, progress, readiness, model-invocation, and error ports,
  preserving the original command/workflow identity into the durable terminal receipt.
- One Dhall UI module released as Phase-40 content under the unchanged amoebius runtime image.
- Phase-0 public-contract, interaction, readiness/owner/scope, and hostile-output fixtures.
- Committed readiness, tenant-scope, same-tenant-owner, local-only-route, and Redis-as-receipt mutants.
- A Register-3 ledger with challenge, authority provenance, external observer digests, and teardown evidence.

### Validation

1. Run `cabal test jitml-ui-lift-live-gate` through Keycloak/Envoy on linux-cuda.
2. Drive training to a committed successful checkpoint, verify Ready-handle issuance, invoke it, and compare
   the UI result and external GPU execution with the independent oracle; require the durable receipt to retain
   the exact original command/workflow identities.
3. Pin the socket to replica A and originate receipt delivery through replica B; flush Redis and drop the
   socket after durable commit, then require reconnect/receipt lookup to return the outcome once with no second
   training, CUDA, Pulsar-start, object, or pointer effect.
4. Replay the exact handle/input under tenant A's non-owner and tenant B's owner, then replay in-flight and
   failed checkpoint handles under the owning subject; require pinned denials and zero forbidden effects.
5. Assert model output remains escaped presentation and creates no authority-bearing follow-on request.
6. Apply all five named mutants and require the unchanged gate command to fail on their exact matrix rows.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record only the tested
  training/checkpoint-to-ready-model UI interaction and exact denial matrix.
- `documents/engineering/lift_and_compose_doctrine.md` — keep the sibling SPA a UX fixture and Phase-51's
  numerical/training core an inherited dependency.
- `documents/engineering/tenancy_doctrine.md` — record live scope/readiness denial without claiming general
  noninterference.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record the exact tested two-replica
  jitML receipt-routing and Redis/socket-repair envelope without promoting it to an HA claim.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and flip status only after
  the linux-cuda Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register the jitML UI adapter and Dhall module under Phase 52.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 38 — UI projection runtime](phase_38_ui_projection_runtime.md)
- [Phase 40 — atomic UI program release](phase_40_ui_program_release.md)
- [Phase 51 — jitML lift and CUDA](phase_51_jitml_lift_cuda.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
