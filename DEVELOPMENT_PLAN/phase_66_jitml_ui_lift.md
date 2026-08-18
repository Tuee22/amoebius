# Phase 66: jitML UI lift

> **Purpose**: Lift jitML training, checkpoint, and ready-model contracts into the generic UI runtime and test
> only an owned, committed, Ready model can be invoked from the authenticated application, with the terminal
> training receipt recoverable across UI-server, Redis, and WebSocket loss.
> **Read this if**: phase 66 is next in the queue, or a later phase depends on what its gate establishes.

Phase 66 does for jitML's numerics-facing surface what phase 55 did for infernix, and is the second and last such lift; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), [lift_and_compose_doctrine.md](../documents/engineering/lift_and_compose_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live evidence, on the `linux-cuda` substrate. The typed adapter, bounded Dhall program,
pure denial/idempotency/repair contract, five compiled mutants, Chrome/physical-CUDA record, and sealed reader
passed their 17-check scoped gate on 2026-08-11. The ledger is
`external-run-reference`; the receipt is
`dynamically-resolved`. Retained-provider and
Kubernetes/Envoy paths remain UNVERIFIED.
Every hardware substrate can always execute `linux-cpu`. For a pristine Linux host, use Incus on Linux or
Linux-CUDA hardware, Lima on Apple hardware, and WSL2 on Windows hardware.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_65_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — bounded jitML realtime envelope](#resource-provision--bounded-jitml-realtime-envelope)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 66.1: Bind the jitML training-to-ready-model UI adapter ⏸️](#sprint-661-bind-the-jitml-training-to-ready-model-ui-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-65 revalidation — **reopened 2026-08-16 by the natural-architecture amendment.**
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. This phase's last gate recorded no
architecture, so its seal is invalidated as a current result and stands only as history; the rerun differs from
it by naming the lane and architecture the run actually used. A sprint marker below records what that sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

🟡 Scoped gate passed 2026-08-11. The constructor-hidden adapter accepts only a scope- and
owner-matched Phase-65 committed artifact, preserves command/work identity into the Phase-43 receipt shape,
and models durable repair independently of the transient route. Pure and browser cases cover Ready,
in-flight, failed, same-tenant non-owner, and foreign-tenant outcomes with five red mutants. The live record
uses Chrome, two loopback origins, three scoped identity fixtures, an independent temporary durable-file
observer, and physical host CUDA. Fresh Keycloak sessions, retained MinIO/Pulsar/Redis, Envoy, Kubernetes UI
replicas, the full sibling serving engine, and the same-flow Phase-65 train/commit chain remain UNVERIFIED.

## Phase Summary

This phase owns one adapter seam: the Phase-65 training/checkpoint/model contracts become typed UI workflow and
artifact ports consumed by the generic runtime and released through Phase 44. The linked Haskell adapter
projects bounded progress, checkpoint provenance, readiness, model input/output, and public errors. It cannot
mint readiness from a path, digest, progress label, or client claim.

An authenticated user starts a jitML training run, observes bounded progress, and receives a subject-owned
`ReadyArtifactHandle Model` only after the adopted checkpoint is committed, provenance-verified,
owner/scope-authorized, and compatible with its serving engine. A failed or in-flight checkpoint has no
conversion to that handle. The browser receives neither checkpoint storage coordinates nor GPU/provider
authority.

`JitML.UiAdapter` cannot mint request or workflow identity. The generic server first admits the browser's
opaque `RequestId` against current app, tenant, owner, and port authority, then deterministically qualifies it
as the `CommandId` supplied to Phase 55. That value remains the work-id in all native-CBOR training events.
Phase 43 projects a terminal event into an owner/command-keyed receipt containing the normalized training
digest, `WorkflowHandle`, checkpoint disposition, and ready-model result. Replicas read that durable projection;
Redis fanout and the authenticated socket merely accelerate presentation. The jitML training-start port is
eligible for the explicitly bounded offline queue
contract in
[Low-Code UI Runtime §12](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux);
progress is a cursor-backed cached projection, while training signals,
cancellation, and model invocation remain online-only in the initial adapter contract.

**Session scope:** In one uninterrupted engineering session, implement only the jitML UI adapter/program and
accept it with `cabal test jitml-ui-lift-live-gate`. Split if the work changes Phase-65 training/commit,
reopens Phase-42 failover, adds a generic UI
constructor, introduces another runtime image, or needs a second acceptance command.
**Substrate:** linux-cuda
**Lane:** cuda ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Gate:** `python3 tools/jitml_ui_lift_gate.py --reuse-fresh-live` passes on linux-cuda: a browser reaches an owned,
committed, Ready jitML model and recovers its terminal training receipt across replica, Redis, and socket
loss. Its denial matrix, fixtures, observers, oracle, and mutants are delegated to
[Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Before implementation, Phase 0 commits
  `test/fixture/dhall/apple_metal_host_daemon/jitml_ui.dhall`,
  `test/fixture/jitml_ui_lift/readiness_owner_scope_matrix.tsv`,
  `test/fixture/jitml_ui_lift/public_contract.golden`,
  `test/fixture/jitml_ui_lift/expected_interaction.tsv`,
  `test/fixture/jitml_ui_lift/cross_pod_receipt_timeline.tsv`, and fixed bounded training/model-input fixtures. The
  UI uses trusted `WorkflowProgress`, `ArtifactProvenance`, and `ModelInteractor` components.
- **Fresh authority and challenge.** After Keycloak/Envoy, at least two UI-server replicas, Redis, and the
  Phase-65 jitML workers are Ready, the harness obtains least-privilege sessions for tenant A's artifact owner,
  a tenant-A non-owner, and tenant B's foreign owner, then generates an unpredictable client request id and
  model input. The server-derived scoped command id, command, progress/terminal events, durable receipt,
  training result, and model invocation must retain the command/workflow identities and carry the challenge to
  the external execution/result evidence.
- **Cross-pod receipt routing and repair.** The harness proves from edge/backend identity that the authenticated
  socket is owned by replica A while replica B handles the terminal receipt notification. It then flushes Redis
  and drops the socket between durable receipt materialization and delivery. Reconnect to a current replica
  must recover the exact scoped receipt and terminal model handle from Phase 43 once, without sticky routing,
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
  `test/mutant/jitml_ui_lift/mut-52-mint-ready-from-checkpoint-path.patch` (guard weakening) and
  `test/mutant/jitml_ui_lift/mut-52-ignore-artifact-scope.patch`, plus
  `test/mutant/jitml_ui_lift/mut-52-ignore-artifact-owner.patch`,
  `test/mutant/jitml_ui_lift/mut-52-local-only-websocket-route.patch`, and
  `test/mutant/jitml_ui_lift/mut-52-redis-as-receipt.patch`. Each must turn its readiness, tenant-scope,
  same-tenant-owner, cross-pod route, or durable-repair row red.
- **Independent oracle.** The readiness/owner/scope matrix and public result are hand-authored from the public model
  contract and an off-adapter reference computation. They do not call the adapter, UI renderer, checkpoint
  pointer helper, or serving handler under test.
- **Information-flow check.** Model output remains untrusted tenant-scoped presentation. A committed
  authority-shaped output string must render escaped and cannot become a route, port, grant, policy, or model
  handle.
- **Honesty.** This gate tests one bounded linux-cuda workflow, one ready model, two readiness failures, one
  same-tenant non-owner, one foreign tenant, and one Redis/socket-loss timeline across two UI replicas. It
  inherits Phase-65 training/commit and Phase-42 failover evidence without retesting either boundary or
  claiming general noninterference, Redis availability, or multi-zone HA.

## Resource provision — bounded jitML realtime envelope

The live provision seal includes at least two UI-server replicas, their WebSocket/frame/heartbeat buffers,
Redis connections/keys/fanout, receipt retention and lookup concurrency, cursor repair, reconnect overlap, the
Phase-65 trainer/accelerator demand, and the pinned fault window. A one-replica, sticky-only, pod-local receipt,
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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 66.1: Bind the jitML training-to-ready-model UI adapter ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/JitML/UiAdapter.hs`, `jitml-ui/jitml-ui-lift.cabal`,
`dhall/ui/jitml.dhall`, `test/spec/ui/JitMLUiContractSpec.hs`,
`test/spec/live/JitMLUiLift.hs`, and `tools/phase52_{jitml_ui_live,gate}.py`
**Blocked by**: reopened numeric predecessor gates.
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
- One Dhall UI module released as Phase-45 content under the unchanged amoebius runtime image.
- Phase-0 public-contract, interaction, readiness/owner/scope, and hostile-output fixtures.
- Committed readiness, tenant-scope, same-tenant-owner, local-only-route, and Redis-as-receipt mutants.
- A Register-3 ledger with challenge, authority provenance, external observer digests, and teardown evidence.

### Validation

1. Run `python3 tools/jitml_ui_lift_gate.py --reuse-fresh-live` on linux-cuda.
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

No remaining work inside the scoped deliverable. Fresh Keycloak/Envoy authority, Kubernetes UI replicas,
retained MinIO/Pulsar/Redis receipt routing, the full sibling serving engine, same-flow Phase-65 training and
commit, direct-worker policy, general noninterference, and multi-zone availability remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record only the tested
  training/checkpoint-to-ready-model UI interaction and exact denial matrix.
- `documents/engineering/lift_and_compose_doctrine.md` — keep the sibling SPA a UX fixture and Phase-65's
  numerical/training core an inherited dependency.
- `documents/engineering/tenancy_doctrine.md` — record live scope/readiness denial without claiming general
  noninterference.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record the exact tested two-replica
  jitML receipt-routing and Redis/socket-repair envelope without promoting it to an HA claim.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and flip status only after
  the linux-cuda Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register the jitML UI adapter and Dhall module under Phase 65.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 43 — UI projection runtime](phase_43_ui_projection_runtime.md)
- [Phase 45 — atomic UI program release](phase_45_ui_program_release.md)
- [Phase 65 — jitML lift and CUDA](phase_65_jitml_lift_cuda.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
