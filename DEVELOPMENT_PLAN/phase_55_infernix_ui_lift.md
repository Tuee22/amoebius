# Phase 55: infernix UI lift

> **Purpose**: Lift infernix workflow and ready-artifact contracts into the generic amoebius UI runtime and
> test that an authenticated own-tenant interaction succeeds while a tenant/scope-mismatched artifact handle
> produces no inference effect, with workflow acceptance recoverable from the original durable command
> receipt rather than a WebSocket or Redis acknowledgement.
> **Read this if**: phase 55 is next in the queue, or a later phase depends on what its gate establishes.

Phase 55 re-homes infernix's existing operator surface onto the bounded application language, replacing a bespoke front end rather than adding one; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), [lift_and_compose_doctrine.md](../documents/engineering/lift_and_compose_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live evidence, on the `linux-cpu` substrate.
The scoped aggregate gate passed 14 checks on 2026-08-11: ledger
`external-run-reference`; receipt fingerprint
`dynamically-resolved`.
Phase 54 supplies only a scoped ready-artifact/core boundary: its pinned micro-decoder, linked sibling
compacted-topic module, native-CBOR evidence, and typed facade are available, while production TinyLlama and
full sibling-engine linkage remain UNVERIFIED. This phase remains the sole owner of infernix UI projection and
interaction and must not upgrade those compute surfaces by implication. `linux-cpu` remains selectable on all
four hardware classes. A clean Linux guest comes from Incus for Linux/Linux-CUDA, Lima for Apple, and WSL2 for
Windows.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_54_infernix_lift.md, DEVELOPMENT_PLAN/phase_57_ui_single_tenant_live.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 55.1: Bind the infernix workflow-to-interaction UI adapter ⏸️](#sprint-551-bind-the-infernix-workflow-to-interaction-ui-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-54 revalidation — **reopened 2026-08-16 by the natural-architecture amendment.**
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

🟡 Scoped gate passed 2026-08-11. The typed adapter, bounded Dhall program, pure contract, compiled mutation
checks, real-browser/retained-provider evidence, cleanup audit, and 120-surface ledger pass; ten explicitly
enumerated production-chain surfaces remain UNVERIFIED. The sibling SPA remains UX evidence only.

## Phase Summary

This phase owns one adapter seam: the scoped Phase-54 `ReadyArtifactHandle` and Phase-43 durable-receipt fold
become a typed UI module and bound ports consumed by the generic runtime. The adapter is a leaf package linked
one way to `amoebius:dsl-core` and `infernix-lift`; the sibling handwritten SPA is an interaction/UX fixture,
not executable input, a second frontend, or an authority source.

An authenticated user starts an infernix workflow, observes its bounded progress, receives a server-issued
`ReadyArtifactHandle` only after successful committed/provenance-compatible completion, and invokes the
artifact through a typed `ModelInteractor`. The browser receives no model path, digest authority, engine
address, tenant identifier, provider credential, or raw response.

The adapter validates one opaque `RequestId`, derives a scope-qualified `CommandId` from the current trusted
app/tenant/owner/port context, and makes that command identity the work identity. Its Phase-43 fold produces a
durable receipt keyed by `(AppId, TenantId, Owner, CommandId)` and carrying the same work-id,
`WorkflowHandle`, normalized input digest, and typed outcome. The scoped live harness has a second server
origin recover that receipt from MinIO. Redis may eventually wake a socket-owning replica and an authenticated
WebSocket may deliver the outcome, but neither mechanism establishes acceptance. The
infernix start port is eligible for the explicitly bounded offline queue contract in
[Low-Code UI Runtime §12](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux);
progress is a cursor-backed cached projection, while signals, cancellation, and artifact invocation remain
online-only in the initial adapter contract.

The public computation used here is the Phase-0 `reference-uppercase` interactor. The live result therefore
does not establish correspondence with the complete Phase-54 inference chain, production TinyLlama, or the
full sibling inference engine.

**Session scope:** One adapter/program, one pure suite, one evidence reader, and one aggregate command; no new
generic UI constructor, Phase-54 compute change, or second client runtime was required.
**Substrate:** linux-cpu
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Gate:** `python3 tools/phase50_gate.py --reuse-fresh-live` checks custody,
package/program contracts, live evidence and cleanup, compiled mutants, documentation, and the ledger. The
Haskell live suite independently reads evidence; it does not drive infrastructure.

## Gate integrity

- **Phase-0 representative set.** Phase 0 commits
  `test/dhall/phase_51/infernix_ui.dhall`,
  `test/fixtures/phase_51/scope_matrix.tsv`,
  `test/fixtures/phase_51/public_contract.golden`,
  `test/fixtures/phase_51/expected_interaction.tsv`,
  `test/fixtures/phase_51/terminal_receipt_identity.tsv`, and a fixed public model/input corpus. The program
  uses `WorkflowProgress`, `ArtifactProvenance`, and `ModelInteractor` from the trusted catalog.
- **Fresh authority and challenge.** The scoped driver creates a fresh Keycloak realm, active tenant-A and
  tenant-B sessions, unpredictable client request id, and nonce-bearing public input; a real browser exercises
  two distinct loopback server origins while the retained providers and one fresh Kubernetes reference-worker
  Job carry the challenge into the independently recomputed `reference-uppercase` result.
- **Durable receipt chain.** The terminal receipt is written to MinIO and read through the second loopback
  server origin that did not admit the start. Its scope, command id, work-id, handle, input digest, and accepted
  terminal outcome agree with the one-message Pulsar observations and ready-last artifact objects. A progress
  response cannot satisfy this row.
- **Paired scope cases.** Tenant A's current `ReadyArtifactHandle` succeeds. The identical invocation replayed
  under tenant B differs only in authenticated scope and must return the pinned non-enumerating denial. The
  handle bytes, port, program digest, and public input are otherwise unchanged.
- **Zero forbidden effect.** On the live foreign-tenant denial, retained Pulsar, MinIO, and worker observations
  retain the same effect count. The pure suite separately covers same-tenant foreign-owner, stale scope, and
  changed-input conflict. A direct bound-service NetworkPolicy probe is not claimed here.
- **Observer outside the adapter.** Playwright observes a real Chrome browser; Keycloak token introspection,
  retained Pulsar/MinIO observations, and the fresh Kubernetes Job witness establish the scoped effect. The
  Envoy endpoint is token-probed, but browser-through-Envoy-to-UI-server and Kubernetes UI-server replicas are
  not claimed.
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
- **Honesty.** The gate tests one `linux-cpu` reference interaction and one live tenant pair. Loopback UI
  origins stand in for replicas; Phase-55 native CBOR, the full edge-to-UI route, Redis/WebSocket recovery,
  same-tenant foreign-owner and changed-input live cases, the full Phase-54 output path, production TinyLlama,
  direct service isolation, and general noninterference remain UNVERIFIED. The CPU execution lane is available
  from every hardware class. For an uncontaminated Linux environment, select Incus on Linux/Linux-CUDA, Lima
  on Apple, or WSL2 on Windows.

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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 55.1: Bind the infernix workflow-to-interaction UI adapter ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Infernix/UiAdapter.hs`, `infernix-ui/infernix-ui-lift.cabal`,
`dhall/ui/infernix.dhall`, `test/ui/InfernixUiContractSpec.hs`,
`test/live/InfernixUiLift.hs`, `tools/phase50_infernix_ui_live.py`, and
`test/ui/live/phase50_browser.mjs`
**Blocked by**: reopened numeric predecessor gates.
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
- One Dhall UI module using only trusted catalog components and the Phase-45 release path.
- The Phase-0 public-contract, interaction, scope, and hostile-output oracle corpus.
- The committed scope and terminal-command-correlation mutants.
- A Register-3 evidence ledger with challenge, credential provenance, external observer digests, and teardown.

### Validation

1. Run `python3 tools/phase50_gate.py --reuse-fresh-live` on `linux-cpu`.
2. Require the pure contract to cover opaque handles, trusted-scope command derivation, durable identity,
   exact resend, changed-input conflict, foreign-owner/tenant and stale-scope denial, and hostile output.
3. Require the fresh live record to bind browser, tenant sessions, retained providers, reference worker,
   ready-last artifact, one-message topics, second-origin receipt recovery, denial, and exact cleanup.
4. Compile each named mutant independently, require its exact marker to fail, then restore and rerun both
   Haskell suites before sealing the enumeration ledger.

### Remaining Work

No remaining work inside the scoped deliverable. Full browser-through-Envoy routing, Kubernetes UI-server
replicas, Phase-55 native CBOR, full Phase-54 inference-output correspondence, production TinyLlama,
Redis/WebSocket recovery, direct-service NetworkPolicy, and the wider live scope matrix remain UNVERIFIED.

## Documentation Requirements

**Engineering docs updated for the sealed scoped result:**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record only the tested workflow-to-ready-artifact
  UI interaction and exact tenant/scope matrix.
- `documents/engineering/lift_and_compose_doctrine.md` — keep the sibling SPA a UX fixture and name only the
  linked Haskell adapter and generic runtime as trusted implementation.
- `documents/engineering/tenancy_doctrine.md` — record the live provider denial without claiming general
  noninterference.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — record only the tested infernix
  terminal-event-to-receipt correlation; cross-pod Redis/socket fault behavior remains Phase 57's claim.

**Cross-references completed:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and report its scoped
  `linux-cpu` Register-3 seal.
- `DEVELOPMENT_PLAN/system_components.md` — register the infernix UI adapter and Dhall module under Phase 54.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 43 — UI projection runtime](phase_43_ui_projection_runtime.md)
- [Phase 45 — atomic UI program release](phase_45_ui_program_release.md)
- [Phase 54 — infernix lift](phase_54_infernix_lift.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
