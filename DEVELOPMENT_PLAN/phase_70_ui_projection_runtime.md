# Phase 70: Owner-scoped UI projection runtime

> **Purpose**: Materialize bounded workflow events into owner-qualified UI read models and durable command
> receipts, then test on live infrastructure that projection keys, receipt keys, subscriptions, and query
> handles cannot collapse command, subject, or tenant scope.
> **Read this if**: phase 70 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_capability_messaging.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 70.1: Build and independently verify the owner-scoped live projection](#sprint-701-build-and-independently-verify-the-owner-scoped-live-projection-)
- [Sprint 70.2: The generic browser interpreter as pure Haskell semantics](#sprint-702-the-generic-browser-interpreter-as-pure-haskell-semantics-)
- [Sprint 70.3: The UI-server boundary as pure Haskell policy](#sprint-703-the-ui-server-boundary-as-pure-haskell-policy-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Gate execution is held shut by the predecessor's receipt in certification generation 2; the generation-2 reset is
recorded in [DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice).

Gate execution remains blocked by the qualified Phase-69 predecessor and its compatible evidence chain.
Live effects also require the preceding named barriers in [the phase model](development_plan_phase_model.md#l-one-substrate-discipline).

## Phase Summary

The target `UiProjectionWorker` — an arm of `WorkerKind`, so the role reaches the pod carrying the `AppId` and `ProgramDigest` it serves ([daemon_topology_doctrine.md §4](../documents/engineering/daemon_topology_doctrine.md#4-worker-daemons--n-unelected)) — consumes canonical CBOR workflow events through the native Phase-67 Pulsar client and
builds a compacted latest-value projection plus a compacted durable command-receipt projection. Every
read-model message key, subscription, stored row, watermark, opaque query handle, and audit identity retains
`(AppId, TenantId, Owner, ProjectionId)`. Every receipt retains
`(AppId, TenantId, Owner, CommandId)`, the Phase-69 workflow work-id and `WorkflowHandle`, the normalized input
digest, and the typed accepted/terminal outcome. The original scope-qualified `CommandId` survives UI
admission, Pulsar command publication, consumer redelivery, every derived workflow event, and receipt
materialization; no adapter or UI-server replica may regenerate or substitute it. The worker receives a
private `UiServerPlan` projection and server-held capabilities; the browser or caller never supplies a topic,
subscription, tenant, owner, provider coordinate, or provider credential.

Only the effect owner's accepted or terminal event can advance a receipt. Re-observing the same command and
normalized input folds to the same receipt; the same scoped `CommandId` with a different normalized input is a
typed idempotency conflict and cannot start or acknowledge another effect. A progress event, Redis publish
acknowledgement, WebSocket write, or UI-server memory entry cannot mint `Accepted`.
Every owner stream also carries a monotonic `StreamCursor` and program/scope epochs suitable for WebSocket
delivery. Redis may later wake a connection owner, but only this Pulsar-backed sequence/watermark can detect a
gap and repair it.

The future live gate must drive equal-shaped workflows for two subjects in one tenant and a third subject in a second
tenant. It verifies current values and resume watermarks through a scoped server query while a separately
authenticated native client and broker-admin observer inspect the underlying compacted topic. Same-tenant
foreign-owner and foreign-tenant handles yield the same public denial and cannot disclose the other challenge.

**Phase scope:** one owner-keyed workflow-event-to-query/receipt projection. The
`ui-projection-runtime-live` Haskell component suite can supply supporting observations only; the sole acceptance command is `pb
validate phase 70`. Split if work adds a browser interaction, release transition, ML adapter, another
substrate, HA fault, or a second independently useful claim.
**Substrate:** `linux-cpu` — future live cluster observation only after the DSL barrier (Phase 4) and every predecessor gate pass.
**Lane:** `linux-cpu/amd64`.
**Register:** 3 — live Pulsar/provider projection and independent readback; NOT VALIDATED.

**Depends on:** [Phase 69](phase_69_content_store_workflow.md)
**Gate:** `pb validate phase 70`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — the replacement certification generation, protected accepted baseline,
authenticated phase receipt, and current compatibility closure are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: one cohesive claim — *a projection key, a receipt key and a query handle cannot collapse command, subject or tenant scope*. The read model is owner-qualified by construction. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | `Amoebius.Ui.Runtime.Projection`, `Amoebius.Ui.Runtime.Interpreter`, and `Amoebius.Ui.Runtime.Server` under `src/Amoebius/Ui/Runtime/`, consuming the checked program of Phase 8; every subject is inside the closure of `executable amoebius`. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `pb validate phase 70` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Legacy closure` | `LTD-UI-001` closes here for the browser interpreter and the server boundary through the compiled inventory; the generated bundle share closes at Phase 72. The due-count for every other identifier is zero. |
| `Predecessor` | UNRESOLVED — blocks validation: the typed generation/compatibility binding still requires implementation. Require authenticated `ImmediatePredecessorPass` for Phase 69 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. Before check this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

- Projection demand is finite per `(AppId, TenantId, Owner, ProjectionId)` and receipt demand is finite per
  `(AppId, TenantId, Owner, CommandId)`: event rate and size, compacted key count/value bound, receipt retention
  and lookup concurrency, cursor and replay window, consumer buffer, worker concurrency, old/new overlap,
  failed compaction/replay retention, audit bytes, and query-handler envelope all enter whole-deployment
  provision.
- Owner-qualified projection messages are the only input to the private fold. A compacted `TableView` is a
  read model, never an authorization decision or source of membership truth.
- Worker and query handler use distinct least-authority service identities. Browser/user credentials carry no
  Pulsar permission, and the public plan contains no topic or subscription coordinate.
- A projection cannot be served until caught up to the release-required watermark. Phase 72 pins that
  watermark/ABI in the immutable UI release; this phase's target must establish the live primitive only.

- **Extension conformance.** `L1`–`L5`, `C1`–`C7`, `S1`–`S6`, as defined by
  [`extension_conformance_laws.md` §3 — L1–L5: the per-extension laws](../documents/engineering/extension_conformance_laws.md#3-l1l5-the-per-extension-laws),
  [§4 — C1–C7: the compositional laws](../documents/engineering/extension_conformance_laws.md#4-c1c7-the-compositional-laws), and
  [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6); negatives under `.build/test-corpora/ui_projection_runtime/`.

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — owner-scoped UI projection runtime carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- [`pulsar_client_doctrine.md` §5.1 — Two derived capabilities (read-model), and two deliberately absent ones](../documents/engineering/pulsar_client_doctrine.md#51-two-derived-capabilities-read-model-and-two-deliberately-absent-ones): use the native client for a bounded
  read model without making it an authority source.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): derive current identity and scope at the trusted server edge.
- [`low_code_ui_runtime_doctrine.md` §11 — data, forms, and storage](../documents/engineering/low_code_ui_runtime_doctrine.md#11-data-forms-and-storage): expose only scoped public contracts and opaque handles.
- [`tenancy_doctrine.md` §4 — The typed shapes: `TenantSpec` / `SubjectSpec` / `Membership` / `Owner` / `RoleBinding`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding): retain app, tenant, and owner identity in every read-model coordinate.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): require fresh challenges, real authority,
  external raw observation, paired negatives, direct bypass probes, and killed mutants.
- [`ui_realtime_coordination_doctrine.md §4 — typed routing and resume envelope`](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): produce the authoritative sequenced cursor stream from which lossy WebSocket fanout repairs gaps.
- [`ui_realtime_coordination_doctrine.md §6 — durable commands, receipts, and replay`](../documents/engineering/ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay): key workflow receipts by the original scoped command identity and derive acceptance from the effect owner rather than Redis or a socket write.

## Sprints

The sprint requirements below remain part of the target acceptance scope. Each owner must bind them in
Haskell and qualify the mechanism that first admits their result; component observations cannot close a sprint.

>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in checked Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 70.1: Build and independently verify the owner-scoped live projection ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Ui/Runtime/Projection.hs`
**Blocked by**: [Phase 69](phase_69_content_store_workflow.md) gate pass
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: `test/oracle/ui/Main.hs`, which imports no `amoebius` library.
**Legacy IDs**: `LTD-UI-001`
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Establish the one live event-to-read-model/receipt seam needed by composable low-code workflows while
preserving command, issuer-qualified subject, tenant, and owner scope end to end.

### Deliverables

- Private owner-qualified projection and receipt keys, subscription identities, watermarks, and opaque scoped
  handles.
- Bounded compacted-topic worker and sealed scoped projection/receipt query adapter over server-held
  capabilities.
- Phase-0 matrices/oracles, real-identity fixture, post-ready challenge protocol, native/broker/edge observers,
  bypass corpus, teardown inventory, generated run ledger, and all three Haskell-authored changed-subject mutants.

### Validation

1. Rejected historical observation: the `ui-projection-runtime-live` Cabal suite expected exact recovery of
   the pinned latest value, original scoped
   command/workflow identities, terminal receipt, and watermark for each own-owner session after update,
   tombstone, recreate, exact-command redelivery, disconnect, and resume.
2. Require foreign-owner, foreign-tenant, forged-scope, guessed-id, direct-Pulsar, and stale-epoch attempts to
   expose no foreign nonce and cause no foreign subscription/key/watermark change.
3. Run `drop_owner_key`, `drop_owner_subscription`, and `drop_receipt_command_id`; require the unchanged
   external oracle to fail on the intended overwrite/leak, duplicate-receipt, or cursor-crossing row.
4. Tear down to the authenticated preflight inventories and persist a Register-3 ledger that leaves browser,
   release, ML-lift, and HA claims UNVERIFIED.

### Remaining Work

The pre-reset `None` claim is permanently invalid; Sprint 70.1 remains blocked and NOT VALIDATED. Browser/reconnect, release, ML-lift, HA, and cross-cluster claims remain with their named
later phases.
## Sprint 70.2: The generic browser interpreter as pure Haskell semantics ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Ui/Runtime/Interpreter.hs` and `src/Amoebius/Ui/Runtime/Projection.hs`
**Blocked by**: Sprint 70.1
**Independent Validation**: The interpreter's state, event, route, focus, freshness, trusted-text, challenge, and same-origin request-plan semantics over the checked program of Phase 8 equal an independent Haskell reference on the corpus traces; the deterministic projection to browser-language source is byte-stable; a plan with no routes admits no workflow route; runner-generated mutants in the interpreter are killed by the differential.
**Oracle**: `test/oracle/ui/Main.hs`, which imports no `amoebius` library and states the reference traces from literals.
**Legacy IDs**: `LTD-UI-001` — the browser runtime re-homed from the pre-barrier plan
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Interpret the checked program Phase 8 produces as pure Haskell semantics before any browser executes it, and project that runtime as generated source beneath `.build/ui/**`.

### Deliverables

- The pure interpreter over `BoundUiProgram` and its client plan.
- The deterministic projection of the runtime as PureScript beneath `.build/ui/**`, rendered lazily and never tracked.

### Validation

Run the corpus traces through the interpreter and the reference; compare; refuse a plan with no routes that admits a workflow route.

### Remaining Work

Implement the interpreter and the projection. Browser execution remains a later-owned claim of this phase's live gate.

## Sprint 70.3: The UI-server boundary as pure Haskell policy ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Ui/Runtime/Server.hs`
**Blocked by**: Sprint 70.2
**Independent Validation**: Authenticated request, current-epoch authorization, authorization-before-dispatch, exact handler-registry admission, public-only asset, idempotent retry, and WebSocket registration are pure Haskell policy values equal to the oracle's; a request dispatched before authorization is refused; runner-generated mutants in the server policy are killed.
**Oracle**: `test/oracle/ui/Main.hs` states the policy table from literals.
**Legacy IDs**: `LTD-UI-001`
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Make the server side of the checked program a pure policy the live projection runtime consumes.

### Deliverables

- The server policy values and their dispatch order.
- The handler-registry admission over the effect-port catalog of Phase 8.

### Validation

Compare the policy table with the oracle; refuse authorization-after-dispatch by name.

### Remaining Work

Implement the policy module. Live identity, browser and operating-system enforcement, provider dispatch, deployment, and high availability remain this phase's live claims.


## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/pulsar_client_doctrine.md`, `low_code_ui_runtime_doctrine.md`, and
  `ui_realtime_coordination_doctrine.md` attach the tested live owner-key/subscription/receipt/watermark evidence.
- `documents/engineering/tenancy_doctrine.md` records the live owner-qualified projection residue.
- `documents/engineering/testing_doctrine.md` registers the broker/native/edge multi-observer pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — index the live seam.
- `DEVELOPMENT_PLAN/phase_72_ui_program_release.md`, `phase_92_infernix_ui_rederivation.md`, and
  `phase_94_jitml_ui_rederivation.md` — consume its caught-up watermark/read-model/receipt result without expanding its
  claim.

## Related Documents

- [Phase 70](phase_70_ui_projection_runtime.md)
- [Phase 68 — live subject/tenant isolation](phase_68_user_tenant_isolation_live.md)
- [Phase 69 — content store and workflow runtime](phase_69_content_store_workflow.md)
- [Phase 72 — atomic UI-program release](phase_72_ui_program_release.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
