# Phase 50: infernix UI lift

> **Purpose**: Lift infernix workflow and ready-artifact contracts into the generic amoebius UI runtime and
> test that an authenticated own-tenant interaction succeeds while a tenant/scope-mismatched artifact handle
> produces no inference effect, with workflow acceptance recoverable from the original durable command
> receipt rather than a WebSocket or Redis acknowledgement.
> **Read this if**: phase 50 is next in the queue, or a later phase depends on what its gate establishes.

Phase 50 re-homes infernix's existing operator surface onto the bounded application language, replacing a bespoke front end rather than adding one; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), [lift_and_compose_doctrine.md](../documents/engineering/lift_and_compose_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cpu` substrate.
No gate has run.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_49_infernix_lift.md, DEVELOPMENT_PLAN/phase_55_ui_single_tenant_live.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 50.1: Bind the infernix workflow-to-interaction UI adapter 📋](#sprint-501-bind-the-infernix-workflow-to-interaction-ui-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. The infernix UI adapter, program, and live isolation evidence do not exist; sibling SPA behavior is
UX evidence only and is never reported as an amoebius result.

## Phase Summary

This phase owns one adapter seam: the already-lifted Phase-49 infernix workflow/artifact contracts become a
typed UI module and bound ports consumed by the generic runtime. The trusted Haskell adapter remains linked
into amoebius. The sibling handwritten SPA is an interaction/UX fixture, not executable input, a second
frontend, or an authority source.

An authenticated user starts an infernix workflow, observes its bounded progress, receives a server-issued
`ReadyArtifactHandle` only after successful committed/provenance-compatible completion, and invokes the
artifact through a typed `ModelInteractor`. The browser receives no model path, digest authority, engine
address, tenant identifier, provider credential, or raw response.

The UI server validates one opaque `RequestId`, derives a scope-qualified `CommandId` from the current trusted
app/tenant/owner/port context, and preserves it through Phase 49's native CBOR command/event chain. The
terminal event is folded by Phase 38 into the durable receipt keyed by
`(AppId, TenantId, Owner, CommandId)` and carrying the same work-id, `WorkflowHandle`, normalized input digest,
and typed outcome. Any UI-server replica may query that receipt. Redis may wake the socket-owning replica and
the authenticated WebSocket may deliver the outcome, but neither mechanism establishes acceptance. The
infernix start port is eligible for the explicitly bounded offline queue contract in
[Low-Code UI Runtime §12](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux);
progress is a cursor-backed cached projection, while signals, cancellation, and artifact invocation remain
online-only in the initial adapter contract.

**Session scope:** In one uninterrupted engineering session, implement only the infernix UI adapter/program
and accept it with `cabal test infernix-ui-lift-live-gate`. Split if the adapter needs a new generic UI constructor, changes the
Phase-49 compute workflow, adds a second client runtime, or requires another acceptance command.
**Substrate:** linux-cpu
**Register:** 3 (live infrastructure)
**Gate:** `cabal test infernix-ui-lift-live-gate` authenticates an own-tenant user through Keycloak/Envoy,
drives a fresh inference workflow to a ready infernix artifact, invokes it from the generic UI, and observes
the typed result; replaying the same handle under a tenant/scope-mismatched session must be denied before
inference dispatch with zero forbidden effect. The complete apparatus is delegated to
[Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Phase 0 commits
  `test/dhall/phase_50/infernix_ui.dhall`,
  `test/fixtures/phase_50/scope_matrix.tsv`,
  `test/fixtures/phase_50/public_contract.golden`,
  `test/fixtures/phase_50/expected_interaction.tsv`,
  `test/fixtures/phase_50/terminal_receipt_identity.tsv`, and a fixed public model/input corpus. The program
  uses `WorkflowProgress`, `ArtifactProvenance`, and `ModelInteractor` from the trusted catalog.
- **Fresh authority and challenge.** After the edge, UI server, and infernix worker are Ready, the harness
  obtains real least-privilege Keycloak sessions for tenant A and tenant B and generates an unpredictable
  client request id and nonce-bearing public input. The server-derived scoped command id, workflow command,
  progress/terminal events, durable receipt, ready handle, and inference must retain the resulting
  command/workflow identity and carry the nonce to the independently recomputed typed result.
- **Durable receipt chain.** The compacted receipt is queried through a UI-server replica that did not admit
  the start. Its scope, command id, work-id, handle, input digest, and accepted terminal outcome must agree with
  the independent Pulsar/artifact observations. A progress event, WebSocket response, or Redis publish
  acknowledgement cannot satisfy this row.
- **Paired scope cases.** Tenant A's current `ReadyArtifactHandle` succeeds. The identical invocation replayed
  under tenant B differs only in authenticated scope and must return the pinned non-enumerating denial. The
  handle bytes, port, program digest, and public input are otherwise unchanged.
- **Zero forbidden effect and bypass check.** On denial, external observers must see no infernix dispatch,
  Pulsar command, artifact read, cache materialization, or result object. The harness also probes the bound
  infernix service directly and requires the platform policy to deny that bypass.
- **Observer outside the SUT.** Playwright observes the browser, while Envoy access/audit records, Keycloak
  token provenance, Pulsar topic statistics, MinIO audit/object history, and the infernix worker execution
  witness establish the effect. UI-server and adapter self-reports are not evidence.
- **Committed mutants.** Phase 0 commits
  `test/mutants/phase_50/mut-50-trust-client-artifact-scope.patch` (guard weakening) and
  `test/mutants/phase_50/mut-50-drop-command-id-from-terminal.patch` (receipt-correlation weakening). The first
  accepts the foreign-scope handle and must turn the zero-effect/scope matrix red; the second cannot satisfy
  the independent terminal-event-to-receipt identity row.
- **Independent oracle.** The public result and scope matrix are hand-authored from the fixed model contract
  and an off-adapter reference computation; they do not call the UI adapter, generic renderer, or infernix
  handler under test.
- **Information-flow check.** Inference output remains untrusted presentation data. A port-like string in the
  committed output corpus is escaped and produces no route, policy, grant, or follow-on effect.
- **Honesty.** The gate tests one linux-cpu infernix interaction and tenant pair; it does not prove general
  noninterference or infernix correctness beyond the inherited Phase-49 evidence.

## Doctrine adopted

- [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux):
  introduce only a server-issued ready handle and typed infernix ports.
- [Low-Code UI Runtime §10.3 — Information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels):
  keep artifact/result values within their derived tenant, audience, and integrity sinks.
- [Low-Code UI Runtime §18 — Honesty boundary](../documents/engineering/low_code_ui_runtime_doctrine.md#18-honesty-boundary):
  distinguish checked shape from live provider/tenant enforcement.
- [UI Realtime Coordination §§3–6](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract):
  carry typed results over the same-origin WebSocket, use Redis only for cross-pod wake-up/routing, and derive
  workflow acceptance from a durable scope-qualified receipt.
- [Lift and Compose Doctrine §2 — What lifts (the reuse map)](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map):
  reuse infernix's computational substance through the linked adapter while replacing its envelope.
- [Tenancy Doctrine §7 — Two isolation layers and the honest limit](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit):
  pair typed scope with provider-enforced live denial.

## Sprints

## Sprint 50.1: Bind the infernix workflow-to-interaction UI adapter 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Infernix/UiAdapter.hs`, `dhall/ui/infernix.dhall`, and
`test/live/Phase50InfernixUiLift.hs` (target paths; not yet built)
**Blocked by**: Phase 38 gate; Phase 40
gate; Phase 49 gate.
**Independent Validation**: the live harness checks the own/foreign scope matrix
against Keycloak, Envoy, Pulsar, MinIO, worker, durable-receipt, and browser observations and requires both
committed mutants to fail.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/lift_and_compose_doctrine.md`, `documents/engineering/tenancy_doctrine.md`, and
`documents/engineering/ui_realtime_coordination_doctrine.md`.

### Objective

Adopt [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux):
adapt the linked infernix workflow and artifact contracts to the generic UI runtime without importing the
sibling SPA's code, transport, credentials, or authority assumptions.

### Deliverables

- A linked Haskell infernix UI adapter with typed workflow, ready-artifact, invocation, and public-error ports,
  preserving the original command/workflow identity into the durable terminal receipt.
- One Dhall UI module using only trusted catalog components and the Phase-40 release path.
- The Phase-0 public-contract, interaction, scope, and hostile-output oracle corpus.
- The committed scope and terminal-command-correlation mutants.
- A Register-3 evidence ledger with challenge, credential provenance, external observer digests, and teardown.

### Validation

1. Run `cabal test infernix-ui-lift-live-gate` through the authenticated edge on linux-cpu.
2. Start the nonce-bound workflow, wait for committed success, verify ready-handle issuance, invoke it, and
   compare browser output with the independent result oracle; require an uninvolved UI-server replica to query
   the receipt carrying the exact original command/workflow identities and terminal outcome.
3. Require exact-command resend to return that receipt without a duplicate workflow; changed input under the
   same command id must produce the typed idempotency conflict before effects.
4. Replay the exact handle/input under tenant B and assert the pinned denial plus zero external effect.
5. Assert the hostile output remains escaped presentation and cannot select any authority-bearing value.
6. Apply both named mutants and require the unchanged command to fail before the ledger can be green.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record only the tested workflow-to-ready-artifact
  UI interaction and exact tenant/scope matrix.
- `documents/engineering/lift_and_compose_doctrine.md` — keep the sibling SPA a UX fixture and name only the
  linked Haskell adapter and generic runtime as trusted implementation.
- `documents/engineering/tenancy_doctrine.md` — record the live provider denial without claiming general
  noninterference.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record only the tested infernix
  terminal-event-to-receipt correlation; cross-pod Redis/socket fault behavior remains Phase 55's claim.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and flip status only after
  the linux-cpu Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register the infernix UI adapter and Dhall module under Phase 50.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 38 — UI projection runtime](phase_38_ui_projection_runtime.md)
- [Phase 40 — atomic UI program release](phase_40_ui_program_release.md)
- [Phase 49 — infernix lift](phase_49_infernix_lift.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
