# Phase 72: Atomic immutable UI-program release

> **Purpose**: Atomically release an immutable bound UI program as a content-addressed `ClientPlan` /
> `UiServerPlan` pair plus public-contract artifacts, without rebuilding the amoebius runtime image,
> and reject stale, missing, or mixed plan identities before any action executes.
> **Read this if**: phase 72 is next in the queue, or a later phase depends on what its gate establishes.

Phase 72 delivers the atomic UI program release; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md), [release_lifecycle_doctrine.md](../documents/engineering/release_lifecycle_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cpu` substrate.
Validated 2026-08-11 with `python3 tools/ui_program_release_gate.py --reuse-fresh-live`;
ledger `external-run-reference`.
Every hardware substrate always supplies this `linux-cpu` lane.

> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 72.1: Release immutable UI plans without rebuilding the runtime ⏸️](#sprint-721-release-immutable-ui-plans-without-rebuilding-the-runtime-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-71 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

Done (invalidated). Two fresh live releases over the unchanged Phase-56 private runtime image published atomic
`ClientPlan`/`UiServerPlan` pairs and accepted exactly their two matching actions. Eight stale, missing,
mixed, and hand-authored admission cases returned `ReloadRequired` before dispatch; the external action journal
recorded zero rejected effects. MinIO pointer history, Kubernetes/containerd image observations, Envoy/Keycloak
counters, exact cleanup, the independent fixtures, and all three committed mutants pass the sealed gate.

This gate does not verify arbitrary future UI-release compatibility witnesses or live rolling-overlap and
reconnect behavior; those claims remain explicitly UNVERIFIED until their owning later phases run.

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

**Session scope:** In one uninterrupted engineering session, implement the UI-to-release artifact projection
and stale-digest admission boundary, accepted only by `cabal test ui-program-release-live-gate`. Split if the work requires a new rollout engine, durable
schema migration, amoebius runtime image build, or second acceptance command.
**Phase scope:** one cohesive claim — *a UI program is released atomically by content address, without rebuilding the runtime image*. A stale or mixed plan identity is refused before any action executes.

**Substrate:** linux-cpu
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Gate:** `cabal test ui-program-release-live-gate` publishes two atomic paired-plan UI releases over one
unchanged amoebius runtime image and admits only an exact-matching plan pair — stale, missing, or mixed
client/server identities return `ReloadRequired` with zero action effect. Apparatus:
[Gate integrity](#gate-integrity).

**Depends on:** [Phase 71](phase_71_release_lifecycle.md) — release lifecycle, which this phase consumes rather than rebuilds.

## Gate integrity

- **Phase-0 representative set.** Phase 0 commits
  `test/fixture/dhall/phase_62/ui_program_release.dhall`,
  `test/fixture/network_fabric_wireguard/release_content_manifest.golden`,
  `test/fixture/network_fabric_wireguard/plan_pair_matrix.tsv`,
  `test/fixture/network_fabric_wireguard/source_key_set.txt`, and
  `test/fixture/network_fabric_wireguard/stale_digest_matrix.tsv` before implementation. The two source revisions differ in
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
- **Observer outside the SUT.** An elevated observer provisioned in this phase — not the shared
  `src/Amoebius/Test/{Harness,Sweep}.hs` that [Phase 48](phase_48_test_workflow_algebra.md) later consolidates —
  reads Envoy access records, the Phase-71 release-ledger
  pointer history, both MinIO plan-object identities and bytes for each release, the action service's
  append-only journal, and the containerd image digest. UI-server self-report is not evidence; any missing or
  challenge-mismatched source fails the gate.
- **Single generic image.** The independent containerd/registry observer must see one unchanged **amoebius
  runtime image** digest across both releases and no app-specific UI image — the image
  [Phase 56](phase_56_base_image_registry.md) bakes and publishes, carrying the compiled PureScript client
  bundle as a baked asset; a UI release is release *data*, never an image build. Per-app plans/contracts
  are immutable release/content objects.
- **Committed mutants.** Phase 0 commits
  `test/mutant/ui_program_release/mut-40-accept-stale-authority-digest.patch` (guard weakening) and
  `test/mutant/ui_program_release/mut-40-publish-mixed-plan-pair.patch` (effect swap), plus
  `test/mutant/ui_program_release/mut-40-rebuild-runtime-per-program.patch` (effect swap). Each must turn its
  corresponding assertion red.
- **Independent oracle.** The source-key set, release manifest, expected two-release pointer history, stale
  response matrix, exact client/server pair matrix, and expected one-image set are hand-authored and never
  emitted by the release projector.
- **Teardown and honesty.** The test namespace and gate-only release/content objects are swept after evidence
  capture. The gate tests this release shape; it does not prove all future release compatibility.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`jit_artifact_doctrine.md`](../documents/engineering/jit_artifact_doctrine.md) — every artifact atomic immutable UI-program release emits is a recipe over a content address, never an authored file.
- [Low-Code UI Runtime §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts):
  bind exact identities, immutable plans, compatibility witnesses, and pre-dispatch stale rejection.
- [Generated Artifacts Doctrine §2 — What is generated and from what](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  keep plans, contract manifests, dispatch tables, and the generic bundle generated and uncommitted.
- [Release Lifecycle Doctrine §2 — Release and the immutable ledger](../documents/engineering/release_lifecycle_doctrine.md#2-release-and-the-immutable-release-ledger-releasehash):
  carry UI content under the existing immutable release identity.
- [Testing spoof resistance §12](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect):
  observe the fresh authorized action outside the UI server.
- [UI Realtime Coordination §7 — replicas, drain, rollout, and gateway migration](../documents/engineering/ui_realtime_coordination_doctrine.md#7-replicas-drain-rollout-and-gateway-migration): pin the WebSocket/routing/cursor ABI needed during rolling overlap.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 72.1: Release immutable UI plans without rebuilding the runtime ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**:
`src/Amoebius/Ui/Release/{Projection,PlanPair,Compatibility,ArtifactManifest}.hs` and
`test/spec/live/UiProgramRelease.hs` (built and validated)
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the live gate compares both plan objects, release-ledger,
action-journal, and containerd observations with Phase-0 hand-authored manifests; all three committed
mutants must fail the unchanged command.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`,
`documents/engineering/release_lifecycle_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`, and
`documents/engineering/testing_doctrine.md`.

### Objective

Adopt [Low-Code UI Runtime §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts):
make a UI program an atomic immutable client/server-plan release with exact authority identities and no
per-app frontend image, half-published plan, mixed-plan execution, or stale-plan execution path.

### Deliverables

- Deterministic paired client/server plan objects, UI release manifests, and exact source-key equality from
  `BoundUiProgram`.
- Compatibility checking and fail-closed `ReloadRequired` admission before handler lookup.
- One amoebius runtime image identity shared by the two gate releases.
- Phase-0 manifests, plan-pair/stale-digest matrices, fresh-action oracle, and three named mutants.
- A Register-3 ledger recording authenticated challenge and repository-local evidence digests.

### Validation

1. Run `cabal test ui-program-release-live-gate` on linux-cpu through Keycloak and Envoy.
2. Publish both program revisions and compare both immutable plan objects, release hashes, source keys, and
   atomic pointer history with the independent fixtures.
3. Send matching, stale-authority, stale-content, missing-half, A-client/B-server, and B-client/A-server
   requests; require the two matching canary actions and zero invalid-pair actions.
4. Assert one unchanged generic client image and no per-program image or committed generated plan.
5. Re-run each named mutant and require the same command to fail on its owned assertion.

### Remaining Work

None for this sprint. Future compatibility-witness coverage and rolling overlap/reconnect remain owned by
their later phases and are not claimed by this gate.

## Documentation Requirements

**Engineering docs updated by the validated gate:**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the tested stale-plan rejection and
  one-generic-runtime-image boundary.
- `documents/engineering/generated_artifacts_doctrine.md` — record plans, codecs, dispatch tables, and app
  manifests as generated, content-addressed, and absent from the committed tree.
- `documents/engineering/release_lifecycle_doctrine.md` — record the immutable UI objects and two-release
  pointer history under the release hash.
- `documents/engineering/testing_doctrine.md` — record the fresh action, repository-local evidence, independent
  manifests, and killed stale-digest/image-rebuild mutants.

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
