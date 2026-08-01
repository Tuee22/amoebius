# Phase 52: jitML UI lift

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_51_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Lift jitML training, checkpoint, and ready-model contracts into the generic UI runtime and test
> only an owned, committed, Ready model can be invoked from the authenticated application.

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

**Session scope:** In one uninterrupted engineering session, implement only the jitML UI adapter/program and
accept it with `cabal test jitml-ui-lift-live-gate`. Split if the work changes Phase-51 training/commit,
reopens Phase-37 failover, adds a generic UI
constructor, introduces another runtime image, or needs a second acceptance command.
**Substrate:** linux-cuda
**Register:** 3 (live infrastructure)
**Gate:** `cabal test jitml-ui-lift-live-gate` drives an authenticated training/checkpoint flow to an owned
Ready jitML model and invokes it through the generic UI with a fresh challenge; same-tenant non-owner,
foreign-tenant/scope, and non-Ready/failed checkpoint twins must be denied before inference dispatch with zero
forbidden effect. The fixtures, observers, oracle, and mutants are delegated to
[Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Before implementation, Phase 0 commits
  `test/dhall/phase_52/jitml_ui.dhall`,
  `test/fixtures/phase_52/readiness_owner_scope_matrix.tsv`,
  `test/fixtures/phase_52/public_contract.golden`,
  `test/fixtures/phase_52/expected_interaction.tsv`, and fixed bounded training/model-input fixtures. The UI
  uses trusted `WorkflowProgress`, `ArtifactProvenance`, and `ModelInteractor` components.
- **Fresh authority and challenge.** After Keycloak/Envoy, the UI server, and the Phase-51 jitML workers are
  Ready, the harness obtains least-privilege sessions for tenant A's artifact owner, a tenant-A non-owner, and
  tenant B's foreign owner, then generates an unpredictable model input. The owning subject's live training
  result and model invocation must carry the challenge to the external execution/result evidence.
- **Paired ready/owner/scope cases.** The subject-owned committed Ready model succeeds. The exact same handle
  and input under tenant A's non-owner and tenant B's owner differ only by authenticated authority and must be
  denied. Under the owning subject, handles referring to an in-flight checkpoint and a failed checkpoint differ
  only by readiness state and must also be denied.
- **Zero forbidden effect and bypass check.** Each denial produces no inference dispatch, GPU execution,
  Pulsar command, checkpoint/object read, cache materialization, or result write. A direct browser-origin probe
  to the jitML worker must fail at the platform boundary.
- **Observer outside the SUT.** Playwright observes the browser; Envoy and Keycloak establish request/session
  provenance; Pulsar offsets, MinIO audit/manifests, the checkpoint pointer history, and the accelerator-owner
  device-hold/kernel-launch trace establish training and invocation. Adapter/UI-server self-report is ignored.
- **Committed mutants.** Phase 0 commits
  `test/mutants/phase_52/mut-52-mint-ready-from-checkpoint-path.patch` (guard weakening) and
  `test/mutants/phase_52/mut-52-ignore-artifact-scope.patch`, plus
  `test/mutants/phase_52/mut-52-ignore-artifact-owner.patch`. Each must turn its readiness, tenant-scope, or
  same-tenant-owner row red.
- **Independent oracle.** The readiness/owner/scope matrix and public result are hand-authored from the public model
  contract and an off-adapter reference computation. They do not call the adapter, UI renderer, checkpoint
  pointer helper, or serving handler under test.
- **Information-flow check.** Model output remains untrusted tenant-scoped presentation. A committed
  authority-shaped output string must render escaped and cannot become a route, port, grant, policy, or model
  handle.
- **Honesty.** This gate tests one bounded linux-cuda workflow, one ready model, two readiness failures, one
  same-tenant non-owner, and one foreign tenant. It inherits Phase-51 training/commit and Phase-37 failover
  evidence without retesting either boundary or claiming general
  noninterference.

## Doctrine adopted

- [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux):
  admit invocation only through a server-issued ready-model handle.
- [Low-Code UI Runtime §10.3 — Information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels):
  constrain checkpoint, model, input, and output flow by derived tenant/audience/integrity witnesses.
- [Low-Code UI Runtime §18 — Honesty boundary](../documents/engineering/low_code_ui_runtime_doctrine.md#18-honesty-boundary):
  keep runtime readiness, provider enforcement, and tested isolation explicit.
- [Lift and Compose Doctrine §2 — What lifts (the reuse map)](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map):
  reuse jitML training/model substance through the linked adapter while replacing its envelope.
- [Tenancy Doctrine §7 — Two isolation layers and the honest limit](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit):
  pair scope-indexed handles with live provider denial.

## Sprints

## Sprint 52.1: Bind the jitML training-to-ready-model UI adapter 📋

**Status**: Planned
**Implementation**: `src/Amoebius/JitML/UiAdapter.hs`,
`dhall/ui/jitml.dhall`, and `test/live/Phase52JitMLUiLift.hs`
(target paths; not yet built)
**Blocked by**: Phase 40 gate; Phase 51 gate.
**Independent Validation**: the live harness checks the ready/failed/in-flight/non-owner/foreign matrix against
Keycloak, Envoy, Pulsar, MinIO, checkpoint, GPU, and browser evidence; all three committed mutants must turn red.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/lift_and_compose_doctrine.md`,
and `documents/engineering/tenancy_doctrine.md`.

### Objective

Adopt [Low-Code UI Runtime §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux):
adapt linked jitML training and model contracts to the generic runtime without importing the sibling SPA,
reimplementing training, or turning a checkpoint identifier into browser authority.

### Deliverables

- A linked Haskell jitML UI adapter with typed training, progress, readiness, model-invocation, and error ports.
- One Dhall UI module released as Phase-40 content under the unchanged generic runtime image.
- Phase-0 public-contract, interaction, readiness/owner/scope, and hostile-output fixtures.
- Committed readiness, tenant-scope, and same-tenant-owner mutants.
- A Register-3 ledger with challenge, authority provenance, external observer digests, and teardown evidence.

### Validation

1. Run `cabal test jitml-ui-lift-live-gate` through Keycloak/Envoy on linux-cuda.
2. Drive training to a committed successful checkpoint, verify Ready-handle issuance, invoke it, and compare
   the UI result and external GPU execution with the independent oracle.
3. Replay the exact handle/input under tenant A's non-owner and tenant B's owner, then replay in-flight and
   failed checkpoint handles under the owning subject; require pinned denials and zero forbidden effects.
4. Assert model output remains escaped presentation and creates no authority-bearing follow-on request.
5. Apply all three named mutants and require the unchanged gate command to fail on their exact matrix rows.

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

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and flip status only after
  the linux-cuda Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register the jitML UI adapter and Dhall module under Phase 52.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 40 — atomic UI program release](phase_40_ui_program_release.md)
- [Phase 51 — jitML lift and CUDA](phase_51_jitml_lift_cuda.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
