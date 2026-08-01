# Phase 40: Atomic UI program release

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_38_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_52_jitml_ui_lift.md, DEVELOPMENT_PLAN/phase_57_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Atomically release an immutable bound UI program as a content-addressed `ClientPlan` /
> `UiServerPlan` pair plus public-contract artifacts, without rebuilding the generic PureScript runtime image,
> and reject stale, missing, or mixed plan identities before any action executes.

---

## Phase Status

📋 Planned. No UI release artifacts or live gate evidence exist; the generic-runtime and stale-plan claims
remain design intent until the Register-3 gate passes.

## Phase Summary

This phase owns the release projection from one bound UI program into an immutable paired `ClientPlan` and
serializable `UiServerPlan` manifest, public-contract objects, and content manifests carried atomically by the
Phase-39 release ledger. The server-plan object contains dispatch/policy/handler identities and codecs, not
serialized Haskell functions; its named handlers must exist in the linked runtime. The generic PureScript
runtime has one immutable OCI image for its ABI/component-catalog identity. Changing an app program changes
content artifacts and the release hash, never an app-specific image layer or a handwritten frontend bundle.

Every effect request carries the exact current program, content, contract, policy, and scope identities.
Without a checked compatibility witness, a stale authority or content digest returns `ReloadRequired` before
dispatch; the browser's digest is an observation, not a capability.

**Session scope:** In one uninterrupted engineering session, implement the UI-to-release artifact projection
and stale-digest admission boundary, accepted only by `cabal test ui-program-release-live-gate`. Split if the work requires a new rollout engine, durable
schema migration, generic-runtime image build, or second acceptance command.
**Substrate:** linux-cpu
**Register:** 3 (live infrastructure)
**Gate:** `cabal test ui-program-release-live-gate` publishes two atomic paired-plan UI releases over one
generic runtime image, externally observes each matching pair carrying a fresh challenge through one
authorized action, and establishes that stale, missing, or mixed client/server identities return
`ReloadRequired` with zero action effect. The concrete
fixtures, observers, oracle, and mutants are delegated to [Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Phase 0 commits
  `test/dhall/phase_40/ui_program_release.dhall`,
  `test/fixtures/phase_40/release_content_manifest.golden`,
  `test/fixtures/phase_40/plan_pair_matrix.tsv`,
  `test/fixtures/phase_40/source_key_set.txt`, and
  `test/fixtures/phase_40/stale_digest_matrix.tsv` before implementation. The two source revisions differ in
  one visible label and one authority-policy epoch while retaining the same runtime ABI/catalog identity.
- **Fresh authorized challenge.** After the live UI server and edge are Ready, the harness obtains a
  least-privilege Keycloak session and generates an unpredictable canary. The current plan submits it through
  the sole test action; the external action journal must recover it exactly.
- **Paired positive and negatives.** Matching A-client/A-server and B-client/B-server identities succeed. The
  same session, port, and canary with only the authority digest stale, only the content digest stale, the
  A-client/B-server pair, the B-client/A-server pair, or either plan object absent must return the pinned
  `ReloadRequired` response before dispatch and create zero journal entry. No release pointer can name only one
  half of a plan pair.
- **Bypass probes.** With the same valid session, the harness calls the bound UI-server action endpoint without
  the browser, first omitting a digest and then supplying a hand-authored plan/action tuple. Both attempts must
  fail before handler lookup and leave the external action journal unchanged; a browser-side reload screen is
  never accepted as evidence of rejection.
- **Observer outside the SUT.** The elevated harness reads Envoy access records, the Phase-39 release-ledger
  pointer history, both MinIO plan-object identities and bytes for each release, the action service's
  append-only journal, and the containerd image digest. UI-server self-report is not evidence; any missing or
  challenge-mismatched source fails the gate.
- **Single generic image.** The independent containerd/registry observer must see one unchanged generic
  PureScript runtime image digest across both releases and no app-specific UI image. Per-app plans/contracts
  are immutable release/content objects.
- **Committed mutants.** Phase 0 commits
  `test/mutants/phase_40/mut-40-accept-stale-authority-digest.patch` (guard weakening) and
  `test/mutants/phase_40/mut-40-publish-mixed-plan-pair.patch` (effect swap), plus
  `test/mutants/phase_40/mut-40-rebuild-runtime-per-program.patch` (effect swap). Each must turn its
  corresponding assertion red.
- **Independent oracle.** The source-key set, release manifest, expected two-release pointer history, stale
  response matrix, exact client/server pair matrix, and expected one-image set are hand-authored and never
  emitted by the release projector.
- **Teardown and honesty.** The test namespace and gate-only release/content objects are swept after evidence
  capture. The gate tests this release shape; it does not prove all future release compatibility.

## Doctrine adopted

- [Low-Code UI Runtime §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts):
  bind exact identities, immutable plans, compatibility witnesses, and pre-dispatch stale rejection.
- [Generated Artifacts Doctrine §2 — What is generated and from what](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  keep plans, contract manifests, dispatch tables, and the generic bundle generated and uncommitted.
- [Release Lifecycle Doctrine §2 — Release and the immutable ledger](../documents/engineering/release_lifecycle_doctrine.md#2-release-and-the-immutable-release-ledger-releasehash):
  carry UI content under the existing immutable release identity.
- [Testing Doctrine §12 — Spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect):
  observe the fresh authorized action outside the UI server.

## Sprints

## Sprint 40.1: Release immutable UI plans without rebuilding the runtime 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Release/{Projection,PlanPair,Compatibility,ArtifactManifest}.hs` and
`test/live/Phase40UiProgramRelease.hs` (target paths; not yet built)
**Blocked by**: Phase 20 gate; Phase 38 gate; Phase 39 gate.
**Independent Validation**: the live gate compares both plan objects, release-ledger, action-journal, and
containerd observations with Phase-0 hand-authored manifests; all three committed mutants must fail the
unchanged command.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`,
`documents/engineering/release_lifecycle_doctrine.md`, and
`documents/engineering/testing_doctrine.md`.

### Objective

Adopt [Low-Code UI Runtime §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts):
make a UI program an atomic immutable client/server-plan release with exact authority identities and no
per-app frontend image, half-published plan, mixed-plan execution, or stale-plan execution path.

### Deliverables

- Deterministic paired client/server plan objects, UI release manifests, and exact source-key equality from
  `BoundUiProgram`.
- Compatibility checking and fail-closed `ReloadRequired` admission before handler lookup.
- One generic-runtime image identity shared by the two gate releases.
- Phase-0 manifests, plan-pair/stale-digest matrices, fresh-action oracle, and three named mutants.
- A Register-3 ledger recording authenticated challenge and external evidence digests.

### Validation

1. Run `cabal test ui-program-release-live-gate` on linux-cpu through Keycloak and Envoy.
2. Publish both program revisions and compare both immutable plan objects, release hashes, source keys, and
   atomic pointer history with the independent fixtures.
3. Send matching, stale-authority, stale-content, missing-half, A-client/B-server, and B-client/A-server
   requests; require the two matching canary actions and zero invalid-pair actions.
4. Assert one unchanged generic client image and no per-program image or committed generated plan.
5. Re-run each named mutant and require the same command to fail on its owned assertion.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the tested stale-plan rejection and
  one-generic-runtime-image boundary.
- `documents/engineering/generated_artifacts_doctrine.md` — record plans, codecs, dispatch tables, and app
  manifests as generated, content-addressed, and absent from the committed tree.
- `documents/engineering/release_lifecycle_doctrine.md` — record the immutable UI objects and two-release
  pointer history under the release hash.
- `documents/engineering/testing_doctrine.md` — record the fresh action, external evidence, independent
  manifests, and killed stale-digest/image-rebuild mutants.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/overview.md` — link the phase and flip status only after
  its linux-cpu Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register the release modules and generic-runtime ownership.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 38 — UI projection runtime](phase_38_ui_projection_runtime.md)
- [Phase 39 — release lifecycle](phase_39_release_lifecycle.md)
- [Low-Code UI Runtime](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md)
- [Release Lifecycle Doctrine](../documents/engineering/release_lifecycle_doctrine.md)
