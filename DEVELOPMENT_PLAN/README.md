# Amoebius Development Plan

> **Purpose**: Provide the authoritative numeric phase order, current status, remaining work, and routing
> to each phase's human-authored validation contract.
> **Read this if**: the current phase, the next permitted work, or the location of a phase gate must be established.

This tracker owns phase order, status, and dated implementation progress. Each phase document owns its
capability-specific validation contract, while the universal source-snapshot postcondition is owned by
[development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
Architecture remains owned by the doctrine suite under [`../documents/`](../documents/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_core_folds.md, DEVELOPMENT_PLAN/phase_08_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_10_capability_bind.md, DEVELOPMENT_PLAN/phase_11_provision_seal.md, DEVELOPMENT_PLAN/phase_12_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_13_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_15_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_16_ui_program_schema.md, DEVELOPMENT_PLAN/phase_17_scoped_identity_kernel.md, DEVELOPMENT_PLAN/phase_18_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_19_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_20_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_21_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_22_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_23_ui_local_composition.md, DEVELOPMENT_PLAN/phase_24_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/phase_26_second_arch_attested_index.md, DEVELOPMENT_PLAN/phase_27_object_reconciler.md, DEVELOPMENT_PLAN/phase_28_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_29_retained_storage.md, DEVELOPMENT_PLAN/phase_30_vault_pki.md, DEVELOPMENT_PLAN/phase_31_platform_backbone.md, DEVELOPMENT_PLAN/phase_32_platform_services_2.md, DEVELOPMENT_PLAN/phase_33_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_34_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_35_app_tenancy.md, DEVELOPMENT_PLAN/phase_36_pulsar_client.md, DEVELOPMENT_PLAN/phase_37_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_38_content_store_workflow.md, DEVELOPMENT_PLAN/phase_39_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_40_release_lifecycle.md, DEVELOPMENT_PLAN/phase_41_ui_program_release.md, DEVELOPMENT_PLAN/phase_42_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_43_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_44_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_45_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_46_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_47_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_48_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_49_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_50_infernix_lift.md, DEVELOPMENT_PLAN/phase_51_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_52_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_53_jitml_ui_lift.md, DEVELOPMENT_PLAN/phase_54_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_55_test_topology_dsl.md, DEVELOPMENT_PLAN/phase_56_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_57_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_58_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_59_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_60_offline_language_plan.md, DEVELOPMENT_PLAN/phase_61_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_62_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_63_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_64_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_65_offline_multizone_continuity.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/diagram_conventions.md, documents/engineering/dsl_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_schema.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/glossary.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_techniques.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents
- [Phase discipline](#phase-discipline)
- [Repository and evidence discipline](#repository-and-evidence-discipline)
- [Toolchain](#toolchain)
- [Document index](#document-index)
- [Status vocabulary](#status-vocabulary)
- [Implementation-progress vocabulary](#implementation-progress-vocabulary)
- [Definition of Done](#definition-of-done)
- [Reopened numeric sequence](#reopened-numeric-sequence)
- [Current implementation audit](#current-implementation-audit)
- [Phase overview](#phase-overview)
- [Related Documents](#related-documents)

---

amoebius is one Haskell runtime with command, host-daemon, singleton, scheduler, and worker responsibilities.
The Python `pb` bootstrap coordinator exists only before binary handoff and as the later admin-REST client.
The constituent prodbox, infernix, jitML, and hostbootstrap capabilities converge as libraries and
behaviours rather than separate products.

## Phase discipline

1. Phases close strictly in numeric order. Phase N+1 cannot close or begin new implementation work before
   Phase N satisfies its redesigned gate.
2. Each phase document owns one cohesive capability claim and one acceptance command.
3. Every gate inherits the artifact-hygiene postcondition in
   [development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
4. Every hardware substrate can run the `linux-cpu` baseline **at its own natural architecture and no
   other**. Pristine Linux uses Incus on Linux or Linux-CUDA, Lima on Apple at `arm64`, and WSL2 on Windows at
   `amd64`. A gate names its lane with that architecture; nothing is emulated or cross-built
   ([substrate_doctrine.md §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule)).
5. A gate may additionally require at most one specialized lane, Apple or Linux-CUDA. The baseline cannot
   substitute for a specialized claim, and one architecture cannot substitute for the other.
6. Register 1 is pure/golden, Register 2 is boundary-with-fakes, and Register 3 is live. Register 2.5 is a
   deterministic-simulation activity, never a phase-gate register.
7. Missing prerequisites fail; they never skip to green. Unreached applicable layers remain UNVERIFIED.

## Repository and evidence discipline

Only human-authored inputs and reviewed external source are version-controlled. Generated projections,
compiled output, lock/freeze files, package checksum databases, hard-coded library or package SHA values,
resolved paths, test enumeration, ledgers, receipts, logs, reports, screenshots, and generated
documentation remain untracked.

All amoebius-owned state stays under the physical checkout. `.build/**` owns reproducible, transient, and
evidentiary output; `.data/**` owns production runtime and durable state; `.test_data/**` owns exclusively
harness-created test state. Immutable run attestations live in `.build/evidence-store/**`. The complete
repository tree, output inventory, lifecycle rules, and normative `.gitignore`/`.dockerignore` patterns
are owned by
[repository_layout_doctrine.md](../documents/engineering/repository_layout_doctrine.md).

## Toolchain

Compilers, package tools, libraries, code generators, browsers, and transitive dependencies resolve
dynamically from authored compatibility requirements. Every clean run records the selected versions,
source identities, dependency graph, executable paths, and observed integrity data under `.build/toolchain/`
and `.build/locks/`, then binds them into repository-local evidence. No generated resolution is copied into Git.

## Document index

| Document | Role |
|---|---|
| [development_plan_standards.md](development_plan_standards.md) | The plan rulebook's hub: every section heading and anchor, and the document-form rules |
| [development_plan_phase_model.md](development_plan_phase_model.md) | Rulebook slice: status vocabulary, the phase model, honesty, substrate discipline, reopening and re-baselining |
| [development_plan_gate_integrity.md](development_plan_gate_integrity.md) | Rulebook slice: gate integrity, universal artifact hygiene, reconciliation, and the final repository layout |
| [overview.md](overview.md) | Target architecture and cross-cutting invariants |
| [system_components.md](system_components.md) | Implemented, substituted, missing, generated, and planned component inventory |
| [substrates.md](substrates.md) | Hardware/substrate registry and pristine-host routing |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | Current-tree and history divergences, owners, and closure conditions |
| [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) | Complete authored/generated tree, dynamic resolution, and ignore/context contract |
| [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) | Validation registers and boundary discipline |
| [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) | Register-2.5 scheduling and replay discipline |
| [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) | Sibling-source migration and convergence rules |
| `phase_00_*.md` … `phase_64_*.md` | One human-authored capability and validation contract per phase |
| [later_phases.md](later_phases.md) | In-scope phases not yet assigned an integer document |

## Status vocabulary

✅ Done · 🔄 Active · 📋 Planned · ⏸️ Blocked · 🧪 Live-proof pending. Definitions live in
[development_plan_standards.md §C](development_plan_standards.md#c-status-vocabulary). The former
non-standard `🟡 Scoped` marker is retired. A scoped historical result is diagnostic, not a current status.

## Implementation-progress vocabulary

Status is a gate decision; progress is a dated repository observation. **No footprint observed**, **Observed
footprint**, **Known partial**, and **Policy-conformant** have the exact meanings in
[development_plan_standards.md §C](development_plan_standards.md#c-status-vocabulary). Source, tests, a gate
script, or an old run can establish only an observed footprint. Only the redesigned current gate plus its
verified repository-local attestation can establish Policy-conformant progress or support ✅ Done.

## Definition of Done

A phase is Done only when all of the following are true:

1. Its phase-specific acceptance command passes in the declared register and substrate, against a recorded
   source snapshot of every non-ignored file.
2. Its runtime-generated surface enumeration joins completely to independently authored expectations.
3. Applicable mutants, negative controls, external observers, authority pairs, and cleanup checks pass.
4. All deliberate generated files stay under ignored output roots; source-adjacent ignored Python interpreter
   caches are the sole exception, and no other command writes beneath an authored root.
5. Nothing the gate ran altered a tracked file, and it left no unignored path behind.
6. The Docker context contains no generated output, evidence, cache, dependency tree, secret, or runtime state.
7. The generated run bundle passes its schema and honesty checks.
8. An immutable repository-local attestation verifies against that source-snapshot digest and the phase contract.
9. The source snapshot contains every referenced authored input and passes the same documented gate with no
   ignored worktree file as an input.
10. Semantic provenance checks reject reproducible tracked copies, including generated fixtures placed beneath
    otherwise authored roots.
11. A before/after host inventory proves that the gate created no amoebius-owned state outside the checkout.
12. Production state uses only `.data/**`; normal teardown preserves durable descendants.
13. Tests use only one marker-owned `.test_data/runs/<run-id>/**` root, fail fast on production state, and
    delete only that exact root after verifying ownership.
14. `test-secrets.dhall` is the sole cleartext secret-at-rest, is read only by the elevated test harness, is
    never copied or emitted, and is rejected by all production entry points.

Markdown never embeds the generated ledger, receipt, hash, transcript, or dependency resolution. A human
status decision may link the content-addressed run reference. A prior seal cannot satisfy Done, and neither can a run whose
source snapshot no longer matches the tree. **When the operator commits is their own affair and never a gate
condition** ([development_plan_standards.md §S](development_plan_standards.md#s-commit-timing)).

## Reopened numeric sequence

The **2026-08-16 natural-architecture amendment** reopens every phase, and re-baselines the sequence. Its
predicate is [development_plan_gate_integrity.md §S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate)
clause 15: a run records the natural architecture it proved, and executes no artifact of another. No seal
recorded before 2026-08-16 names an architecture, and the one that named two reached the second under an
emulator, so no prior seal satisfies the amended gate. Phase 0 adopted the clause and resealed on 2026-08-17;
Phase 1 is Active and Phases 2–65 are Blocked, each returning to work only in numerical order after its
predecessor validates.

The re-baseline is the amendment's second half. No host can build an architecture it cannot execute, so the
old Phase 25 — one gate claiming a two-architecture image — became two: Phase 25 builds, proves, and publishes
its own architecture's child, and a new **Phase 26** does the same on the complementary substrate and joins
both into one attested index. Old phases 26–64 shift to 27–65; the audit map is recorded in
[legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md#natural-architecture-rebaseline--2026-08-16),
as [§E](development_plan_standards.md#e-one-canonical-phase-model) requires.

**Consequence for order of work.** Every phase reopens, so work restarts at Phase 0 and proceeds in numeric
order; a phase's rerun differs from its last one only by recording the architecture it ran on, except in the
image band where the contract itself changed. Phases 0–23 are substrate `none` and pure, so re-recording their
lane is a short run rather than a campaign. From Phase 26 onward the plan needs **two physical machines** — one
per architecture — which is a cost the amendment accepts rather than hides: a two-architecture image proven by
one machine was proven for one of them.

Each phase reruns its own gate and records the architecture that gate ran on; the containment criteria every
phase already inherited are unchanged and carry forward.

```mermaid
flowchart LR
  %% register: orientation
  p0["Phase 0: clause 15 + the amended lint"] -->|"reseal"| p1["Phase 1: rerun, recording its lane and architecture"]
  p1 -->|"then, in numeric order"| live["Phases 2-25: rerun on one architecture"]
  live -->|"then the pair"| pair["Phases 26-65: the complementary host joins, then the chain continues"]
```
*Orientation. [Phase 0](phase_00_documentation_suite.md) adopts the architecture postcondition; each later phase reruns its own gate in numeric order, and the image band needs both machines.*

**Historical amendment record (superseded as status, retained as rationale):**

The **2026-08-15 repository-containment amendment** reopened every previously sealed phase without
renumbering, because the older contract admitted `.build/`'s predecessor, system temporary roots, user-home
state, and host-global container-engine data. Phase 0 validated the closed root set, both ignore contracts,
production rejection of `test-secrets.dhall`, test/production root separation, and a host-inventory negative
that detects any escaped path or global engine resource; each later phase then migrated its own paths, cleared
its rows in the legacy register, and reran its capability gate. Those containment criteria remain in force —
this amendment adds to them rather than replacing them.

The 2026-08-11 generated-artifact amendment reopened phases 0–65 without renumbering them.

1. **Phase 0 adopted and sealed the repository-containment boundary on 2026-08-15.** Its ten-sided gate is
   green with 17 independently seeded policy rules, project-contained run evidence and attestation, and an
   unchanged outside-host inventory. The whole-tree containment scanner attributes 158 legacy callers to
   their numerical owner phases; none is a Phase-0 deferral.

2. **Phase 0 was reopened again on 2026-08-14 by the final-layout amendment, and resealed the same day.**
   [development_plan_standards.md §U](development_plan_standards.md#u-the-final-repository-layout) makes the
   target repository tree normative and gives it to Phase 0. The tree in
   [`repository_layout_doctrine.md` §2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure)
   had enumerated thirty-one roots and called itself exhaustive, but nothing compared it to the worktree, so
   its rule that a new root needs an amendment first had never decided anything. [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) is now the target final
   layout at fourteen roots; Phase 0 owns the check that the tree matches, the no-phase-ordinal rule of [§U](development_plan_standards.md#u-the-final-repository-layout)
   clause 3, and the ignore contracts that are now exhaustive in both directions. Every divergence is recorded
   in
   [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md#layout-and-naming-divergence-snapshot--2026-08-14)
   with an owner and a closure condition, deferred on the shrink-only terms
   [§S clause 5](development_plan_standards.md#s-universal-artifact-hygiene-gate) already sets. The three
   checks and the write-guard repair landed as Sprint 0.9; 1,327 findings are deferred with owners, none of
   them Phase 0's, and the phase resealed with all nine sides passing.
   A **re-baseline follows**, not precedes, that work: the third-party monocontainer bake moves to immediately
   after the toolchain phase, because its dependency floor is the toolchain and not the DSL, and the runtime
   image and registry publication stay in the live sequence. It is sequenced after the de-phasing because a
   re-baseline is documentation-only once no path names a phase, and it lands with the audit map
   [§E](development_plan_standards.md#e-one-canonical-phase-model) requires. Both obligations are recorded in
   [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md#layout-and-naming-divergence-snapshot--2026-08-14).
3. **Phase 0 was reopened and resealed on 2026-08-13.** Its deliverables — the provenance classifier,
   generator registry, authored-root write guard, semantic generated-file scan, source-snapshot verification,
   ignore/context coverage, reachable-history audit, external-attestation validation, and the documentation
   lints — were sealed on 2026-08-12. Once commit `0526152` first tracked this phase's own machinery, the
   audit began scanning its own seeded negative corpora and the `policy` side went red. The finding belonged
   to Phase 0, which cannot defer what it owns; it closed by declaring the corpora as one authored set and
   is sealed again.
4. **Phases 1–3 were previously Done.** Phase 1 replaced its pin manifest with authored compatibility requirements and a
   run-local resolver; Phases 2 and 3 migrated the formal-model and gateway-migration gates onto resolved
   toolchains, run-bundle ledgers, and run-time surface enumeration. Each was sealed on 2026-08-12 with a
   verified pre-containment external attestation, recorded in the historical phase record table below.
5. **The lowest phase not yet sealed is Active; every phase above it is Blocked.** In order, each must migrate
   enumeration and evidence to `.build/`, establish oracle provenance, adopt the authored-root write guard, rerun
   its capability gate, and publish a snapshot-bound repository-local attestation. The phase-overview table is the
   authority on which phase that currently is.
6. **Later phases remain Planned.** They inherit the redesigned doctrine from their first authored contract.

Prior implementation and run records may guide diagnosis. They do not allow a phase to skip its reopened
gate or numeric predecessor.

### The 2026-08-13 secrets amendment reopens Phases 4 and 5

Secrets reach a workload only from Vault, and a production config cannot express a secret value. That second
half is a statement about **Gate 1 and Gate 2**, so it belongs to the phases that own them: Phase 4 gains the
shared `SecretRef` union and Phase 5 gains its decode-and-reject. Both were sealed on 2026-08-12; both are
reopened under [§N](development_plan_standards.md#n-reopening-and-amending-a-phase) with the reason dated in
their status blocks.

Locating the type anywhere later would be the forward dependency
[§E](development_plan_standards.md#e-one-canonical-phase-model) forbids: Phases 4 and 5 would keep claiming a
complete admission boundary while a higher-numbered phase quietly completed it.

**Consequence for order of work.** While 4 and 5 are Active, no phase above them begins new implementation
work ([phase discipline](#phase-discipline) rule 1). Both are pure Register-1 gates, so reclosing them is a
short run rather than a campaign, and phases 6–24 keep the seals they already hold — each is bound to the
snapshot it actually ran against, and this amendment does not touch what those gates cover.

**Vault before providers is now structural, not procedural.** Because a spec cannot be admitted until every
`SecretRef` it names resolves in Vault
([vault_pki_doctrine.md §3.4](../documents/engineering/vault_pki_doctrine.md#34-admission-proves-the-named-secret-exists-before-any-effect)),
no live provider phase can run before Phase 30 exists. The check ranges over the references a spec *names*,
so a spec naming none needs no Vault — which is what keeps Phases 25–29 free of any dependency on 29.

## Current implementation audit

**Current conclusion — 2026-08-17:** **Phase 0 is Policy-conformant; no other phase is.**
[§C](development_plan_standards.md#c-status-vocabulary) reserves that term for a pass of the *current* gate,
and the current gate is [§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15.
Phase 0's 2026-08-17 run is the first to satisfy it: it records the substrate, lane, and natural architecture
it executed on, and refuses a translated one. Every other row below stays at
**Observed footprint** or **Known partial**, which is a change of label, not a claim that the work is gone —
each phase's capability evidence stands as history and is what makes its rerun short.
The existing later-phase implementation still
uses legacy repository roots, system temp and data directories, user-home state, and host-global Docker
resources. The detailed pre-containment rows below are retained as historical capability observations; every
`Policy-conformant` label in them is invalidated for current status by the containment and
natural-architecture amendments alike.

The governed documentation lint and full Phase-0 verifier are sealed. The gate reports every remaining
containment migration as a shrink-only, owner-attributed deferral and writes all of its own state beneath
`.build/**`.

This is a static audit of clean commit `c8870a2` observed on **2026-08-11**. At inspection time it matched
`origin/master`; ignored paths, the effective source-closure boundary, reachable revision history, and
unreachable local objects were inspected separately. A clean or pushed commit is not automatically
policy-conformant. Exact counts, paths, historical findings, and actionable mismatches live in
[legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md#existing-code-divergence-snapshot--2026-08-11).

| Phase(s) | Progress | Observed state | Required next boundary |
|---|---|---|---|
| 0 | **Policy-conformant** | 2026-08-17: the eleven-sided gate passes with 17 clean, mutation-proven artifact rules, 43 seeded documentation negatives red at their own checks, and 35 surfaces joined to 74 implemented checks. All Phase-0 state and attestation are beneath `.build/**`, the outside-host inventory is unchanged, every remaining migration finding has a nonzero owner phase, and the run records substrate `none`, lane `none`, and the `arm64` host it executed on untranslated | None. The next boundary belongs to Phase 1 |
| 1 | **Observed footprint** | Historical, refreshed 2026-08-15: Dynamic tools, npm dependencies, Cabal metadata/store/build roots, temp/cache homes, run evidence, and attestation are project-contained; the 225-package graph resolves twice and from the snapshot; probes and mutants pass; the host inventory is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture. The 2026-08-17 rerun adopted clause 15 and passed its architecture side on `arm64`, then stopped at the declared `host-toolchain` precondition: the host carries no `dhall` and no `chromium` | Supply the two host binaries, then rerun the amended gate to completion |
| 2 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete nine-sided gate passes: 31 authored metrics match, all model and renderer mutants are caught, 608 emitted `.tla`/`.cfg` files stay beneath `.build/**` and outside the source snapshot, 14 surfaces join to 39 run-time items, and the outside-host inventory is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 3 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete nine-sided gate passes: all 12 authored results match, every per-invariant, mechanical, fairness, cutoff, and shared-resource mutant reddens, 34 emitted `.tla`/`.cfg` files remain beneath `.build/**`, 15 surfaces join to 17 run-time items, and the outside-host inventory is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 4 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete nine-sided gate passes after canonical Dhall normalization: all 18 authored metrics match, every field-deletion, type-substitution, special-resource, and custom-arm mutant reddens, 18 surfaces join to 21 run-time items, generated results remain beneath `.build/**`, and the outside-host inventory is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 5 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: all 20 authored metrics match, the decoder/negative/compile-pair/mutant/partiality/absolute-tool checks are green, 23 surfaces join to 26 run-time items, all generated output remains beneath `.build/**`, and the outside-host inventory is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 6 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: all 19 metrics match, 88 catalog entries and 104 subcases reconcile, all mutant families redden, the corpus and honesty-bannered ledger pass, 24 surfaces join to 27 run-time items, and host state is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 7 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete ten-sided gate passes: every fold, twin, compile pair, compatibility row, property, and all 19 mutants pass; 25 surfaces join exactly; the normalized test role tree and all output are contained; host state is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 8 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete ten-sided gate passes: all 27 storage variants and twins, both Gate-1 barriers, six properties, all 31 mutants, the honesty ledger, and all 13 authored metrics pass; 39 surfaces join to 44 run-time items; host state is unchanged. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 9 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete ten-sided gate passes: 32 variants and twins across eighteen families, one Gate-1 barrier, seven properties, all 45 mutants, all 13 metrics, and the honesty ledger pass; 56 surfaces join to 94 run-time items; generated output, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 10 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete ten-sided gate passes: nine capability arms in both shapes, eighteen exact goldens, three Gate-1 and four Gate-2 negatives, the covered property, all four mutants, all twelve metrics, and the honesty ledger pass; 29 surfaces join to 36 enumerated items; generated output, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 11 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete ten-sided gate passes: 26 activation, planner, provision, and mutant items, all ten mutants, all twelve metrics, and the honesty ledger pass; 34 surfaces join to 42 enumerated items; generated output, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 12 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete ten-sided gate passes: 23 coexistence, family/lane, offering, provision, and mutant items, all five mutants, all twelve metrics, and the honesty ledger pass; 28 surfaces join to 39 enumerated items; generated output, normalized capability tests, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 13 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete ten-sided gate passes: 30 deployment and mutant items, all twelve mutants, all ten metrics, and the honesty ledger pass; 31 surfaces join to 46 enumerated items; generated output, normalized manifest tests, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 14 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete twelve-sided gate passes: the chain, boundary, AST, compile-fail, and network-isolation suites, all seven mutants, and all eleven metrics pass; 40 surfaces join to 40 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 15 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: both interpreters, six fake contracts, four schedules, trace determinism/sensitivity, IOSimPOR, the seeded mutant, all nine metrics, and the exact simulation source checks pass; 26 surfaces join to 36 enumerated items; modeled-environment fidelity remains ASSUMED and Runtime UNVERIFIED. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 16 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete twelve-sided gate passes: three positives, ten exact negatives, graph/wire oracles, eight coverage classes, the compile seal, network isolation, all six mutants, and all ten metrics pass; 29 surfaces join to 46 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 17 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete twelve-sided gate passes: all owner joins/swaps, the independent flow matrix, three compile loci, six coverage classes, the owner-equality mutant, all ten metrics, and nine constructor-privacy checks pass; 40 surfaces join to 47 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 18 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: registry, access, parity, epoch, independent-reference, closed-union, constructor-privacy, network-isolation, both mutants, and all eleven metrics pass; 40 surfaces join to 57 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 19 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: seven ports, two trusted links, eight exact errors, thirteen coverage classes, all seven mutants, and all twelve metrics pass; four closed sums and the independent handler/capability key sets are checked directly; 55 surfaces join to 85 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 20 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: four independent projections, four byte-exact canonical artifacts, four independently derived digests, six finite demand cells, two fresh-process determinism checks, all six mutants, and all thirteen metrics pass; 55 surfaces join to 66 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 21 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes in resolved Chrome: two plans, five event arms, four independently derived traces, two DOM snapshots, three accessibility rows, five focus rows, four transport rows, CSP and WebSocket checks, all nine mutants, and all sixteen metrics pass; 66 surfaces join to 84 enumerated items; Node, Spago, PureScript, browser, Cabal, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 22 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete thirteen-sided gate passes: seven HTTP rows, five access rows, five sanitized audit rows, five handler-effect rows, five startup rows, five public assets, five private probes, seven WebSocket rows, loopback-only OS observation, all nine mutants, and all nineteen metrics pass; 77 surfaces join to 94 run-time items; build/test scratch and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 23 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete thirteen-sided gate passes in resolved Chrome: two Dhall applications, five interactions, four exact visible states, four ordered effects, three access rows, five zero-leak denials, loopback-only OS observation, all five mutants, and all seventeen metrics pass; 58 surfaces join to 71 run-time items; the legacy `tests/` root is gone and all generated, build, browser, and host state remains contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 24 | **Observed footprint** | Historical, refreshed 2026-08-15: `python3 tools/bootstrap_coordinator_gate.py --execute` passes all eleven sides against a newly materialized pristine Incus guest. All six mutants are independently red, all sixteen metrics match, and 28 surfaces join to 30 run-time items. Tool acquisition, Cabal state, guest transport, build/evidence, production state, and marker-owned test state are repository-contained; the outside-host inventory is unchanged and the guest is destroyed. Attestation `sha256:cf31b7eb39b7419bc51375e18cc24e56aac1b697150029f52257be751dce4b66`, source `sha256:7503a6e8d86c0f95…`. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 25 | **Known partial** | The catalog, acquisition ladder, pure/static checks, OCI file oracle, and registry standup have been observed. The bake that was observed is the pre-amendment dual-architecture one, whose non-native half was built and probed under emulation; the single-architecture bake this contract now specifies has never run | Rerun the narrowed gate on one host, natively, after Phase 24 reseals |
| 26 | **No footprint observed** | Authored 2026-08-16 by the natural-architecture amendment. No complementary-architecture bake, attestation, or index join exists | Author the oracles and mutants, then run the gate on an `arm64` host after Phase 25 seals |
| 27 | **Observed footprint** | The prior capability remains historical, but its exact Phase-25 handoff is superseded by the open image amendment. | Revalidate against the amended Phase-25 seal |
| 28 | **Observed footprint** | The prior capability remains historical pending the amended Phase-27 predecessor chain. | Revalidate after Phase 27 |
| 29 | **Observed footprint** | The prior capability remains historical pending the amended Phase-28 predecessor chain. | Revalidate after Phase 28 |
| 30 | **Observed footprint** | The prior capability remains historical pending the amended Phase-29 predecessor and Phase-25 handoff. | Revalidate after Phase 29 |
| 31–44 | **Known partial** | Phase 31's live run found the Phase-25 offloader defect; its registry correction and containment changes remain implemented. Phases 31–44 are blocked behind the open predecessor chain, and no current policy-conformant result exists for the range. | Resume Phase 31 only after Phases 25–30 reseal, then validate each later phase in numeric order |
| 45–48 | **Known partial** | Provider/AWS gate footprints exist, while the phase contracts explicitly record missing authenticated provider materialization, EBS/IAM behavior, node provisioning, audit, and leak-freedom | Complete the provider seams after predecessors close and run the live provider gates |
| 49 | **Observed footprint** | Pure and live/cache footprints exist; the prior `linux-cpu` result is invalidated by the artifact-policy amendment | Migrate and rerun the current Phase-49 gate |
| 50–59 | **Known partial** | Gate and test footprints exist. Phase 50 retains frozen sibling-source hashes and Phase 54 commits reference-program output; the range also retains scoped capability gaps in sibling lift, native transport, production topology, hardware, cleanup, or multi-zone behavior | Remove derived/hash expectations in their owning phases, close each capability gap, and rerun in numeric order on the required lane |
| 60 | **Observed footprint** | The offline-language source/test/gate footprint exists; its prior pre-cluster result is invalidated | Migrate and rerun the current Phase-60 gate |
| 61–65 | **Known partial** | Browser/offline gate footprints exist; the contracts retain production compiler, broker, identity, object-store, Kubernetes/CNI, rollout, or provider multi-zone gaps | Close the named Register-2/3 gaps and rerun in numeric order |
| 66+ | **No footprint observed** | This audit did not attribute an implementation footprint to an unnumbered later phase | Author a phase contract in numeric order before implementation |

The absence of a separately listed phase within a range does not hide its state: every integer in that range
inherits the row. Any later code or plan change that affects these observations must refresh this audit and
the legacy register in the same documentation change.

## Phase overview

The table is an order-and-status index. It is read with the dated progress audit above, not as an assertion
that a blocked phase has no code. The linked phase document owns the phase-specific gate; every gate also
inherits the universal postcondition above.

| Phase | Name | Substrate | Lane | Register | Status | Validation contract |
|---|---|---|---|---|---|---|
| 0 | Documentation suite + the final repository layout | none | `none` | — | ✅ Done — resealed 2026-08-17 with [§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 adopted; attestation `sha256:d6fdeca9e2dc4aa8b7cb6f6ecd9204658d1d56bce7acdbbe404620bdc7a5732c` | [phase_00](phase_00_documentation_suite.md) |
| 1 | Toolchain spike | none | `none` | 1 | 🔄 Active — rerunning its gate to record the lane and architecture | [phase_01](phase_01_toolchain_spike.md) |
| 2 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | `none` | 1 | ⏸️ Blocked pending Phase-1 revalidation | [phase_02](phase_02_formal_model_kernel.md) |
| 3 | Gateway-migration model (both branches) | none | `none` | 1 | ⏸️ Blocked pending Phase-2 revalidation | [phase_03](phase_03_gateway_migration_model.md) |
| 4 | Dhall Gate-1 schema + smart-constructor prelude | none | `none` | 1 | ⏸️ Blocked pending Phase-3 revalidation | [phase_04](phase_04_dhall_gate1_schema.md) |
| 5 | GADT-indexed IR + total decoder (Gate 2) | none | `none` | 1 | ⏸️ Blocked pending Phase-4 revalidation | [phase_05](phase_05_gadt_decoder_gate2.md) |
| 6 | Illegal-state corpus + validation-locus ledger | none | `none` | 1 | ⏸️ Blocked pending Phase-5 revalidation | [phase_06](phase_06_illegal_state_corpus.md) |
| 7 | Capacity core fold + topology relation | none | `none` | 1 | ⏸️ Blocked pending Phase-6 revalidation | [phase_07](phase_07_capacity_core_folds.md) |
| 8 | Logical→physical storage geometry folds | none | `none` | 1 | ⏸️ Blocked pending Phase-7 revalidation | [phase_08](phase_08_storage_geometry_folds.md) |
| 9 | Execution-epoch + scheduler + accelerator + provider-root folds | none | `none` | 1 | ⏸️ Blocked pending Phase-8 revalidation | [phase_09](phase_09_execution_accelerator_folds.md) |
| 10 | Capability union + representational bind | none | `none` | 1 | ⏸️ Blocked pending Phase-9 revalidation | [phase_10](phase_10_capability_bind.md) |
| 11 | Whole-deployment provision seal + expansion | none | `none` | 1 | ⏸️ Blocked pending Phase-10 revalidation | [phase_11](phase_11_provision_seal.md) |
| 12 | InferenceEngine capability + accelerator provision | none | `none` | 1 | ⏸️ Blocked pending Phase-11 revalidation | [phase_12](phase_12_inference_accelerator_provision.md) |
| 13 | Pure `renderAll` + rendered-output goldens | none | `none` | 1 | ⏸️ Blocked pending Phase-12 revalidation | [phase_13](phase_13_render_manifest_goldens.md) |
| 14 | chain/Step kernel + `--dry-run` + boundary fake-tool harness + Gate-3 AST checker | none | `none` | 1/2 | ⏸️ Blocked pending Phase-13 revalidation | [phase_14](phase_14_chain_kernel_boundary.md) |
| 15 | Deterministic-simulation substrate | none | `none` | 2 | ⏸️ Blocked pending Phase-14 revalidation | [phase_15](phase_15_deterministic_sim_substrate.md) |
| 16 | Bounded UI-program schema | none | `none` | 1 | ⏸️ Blocked pending Phase-15 revalidation | [phase_16](phase_16_ui_program_schema.md) |
| 17 | Scoped identity kernel | none | `none` | 1 | ⏸️ Blocked pending Phase-16 revalidation | [phase_17](phase_17_scoped_identity_kernel.md) |
| 18 | UI authorization kernel | none | `none` | 1 | ⏸️ Blocked pending Phase-17 revalidation | [phase_18](phase_18_ui_authorization_kernel.md) |
| 19 | UI effect binding | none | `none` | 1 | ⏸️ Blocked pending Phase-18 revalidation | [phase_19](phase_19_ui_effect_binding.md) |
| 20 | UI plan compiler | none | `none` | 1 | ⏸️ Blocked pending Phase-19 revalidation | [phase_20](phase_20_ui_plan_compiler.md) |
| 21 | Generic browser interpreter | none | `none` | 2 | ⏸️ Blocked pending Phase-20 revalidation | [phase_21](phase_21_ui_browser_interpreter.md) |
| 22 | UI-server boundary | none | `none` | 2 | ⏸️ Blocked pending Phase-21 revalidation | [phase_22](phase_22_ui_server_boundary.md) |
| 23 | Local UI composition | none | `none` | 2 | ⏸️ Blocked pending Phase-22 revalidation | [phase_23](phase_23_ui_local_composition.md) |
| 24 | Python bootstrap coordinator + substrate detect + single kind cluster | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-23 revalidation | [phase_24](phase_24_bootstrap_coordinator_kind.md) |
| 25 | Typed bake catalog + native-architecture base image + jit-build resolver + distribution registry | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-24 revalidation | [phase_25](phase_25_base_image_registry.md) |
| 26 | Complementary-architecture child + the attested multi-architecture index | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked pending Phase-25 revalidation | [phase_26](phase_26_second_arch_attested_index.md) |
| 27 | Typed renderer + object reconciler | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-26 revalidation | [phase_27](phase_27_object_reconciler.md) |
| 28 | amoebius-capacity scheduler + bootstrap cutover | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-27 revalidation | [phase_28](phase_28_capacity_scheduler.md) |
| 29 | No-provisioner retained storage + lossless rebind | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-28 revalidation | [phase_29](phase_29_retained_storage.md) |
| 30 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-29 revalidation | [phase_30](phase_30_vault_pki.md) |
| 31 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-30 revalidation | [phase_31](phase_31_platform_backbone.md) |
| 32 | Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-31 revalidation | [phase_32](phase_32_platform_services_2.md) |
| 33 | Keycloak-owned ingress | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-32 revalidation | [phase_33](phase_33_keycloak_ingress.md) |
| 34 | Live DSL deploy via the replicas=1 singleton | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-33 revalidation | [phase_34](phase_34_live_dsl_singleton.md) |
| 35 | Tenant/provider provisioning | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-34 revalidation | [phase_35](phase_35_app_tenancy.md) |
| 36 | Native Pulsar client (CBOR) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-35 revalidation | [phase_36](phase_36_pulsar_client.md) |
| 37 | Live subject/tenant isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-36 revalidation | [phase_37](phase_37_user_tenant_isolation_live.md) |
| 38 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-37 revalidation | [phase_38](phase_38_content_store_workflow.md) |
| 39 | Owner-scoped UI projection runtime | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-38 revalidation | [phase_39](phase_39_ui_projection_runtime.md) |
| 40 | Release lifecycle | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-39 revalidation | [phase_40](phase_40_release_lifecycle.md) |
| 41 | Atomic immutable UI-program release | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-40 revalidation | [phase_41](phase_41_ui_program_release.md) |
| 42 | WireGuard network fabric | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-41 revalidation | [phase_42](phase_42_network_fabric_wireguard.md) |
| 43 | Multi-cluster spawn + geo-replication | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-42 revalidation | [phase_43](phase_43_multicluster_spawn_georepl.md) |
| 44 | Gateway-migration drills + model-correspondence | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-43 revalidation | [phase_44](phase_44_gateway_migration_drills.md) |
| 45 | Provider Pulumi deploy-from-inside + enveloped checkpoint | linux-cpu → provider | `linux-cpu/amd64` → provider | 3 | ⏸️ Blocked pending Phase-44 revalidation | [phase_45](phase_45_provider_deploy_checkpoint.md) |
| 46 | Hostless provider child + convergence + Lease handoff | linux-cpu → provider | `linux-cpu/amd64` → provider | 3 | ⏸️ Blocked pending Phase-45 revalidation | [phase_46](phase_46_provider_child_bringup.md) |
| 47 | Per-PV EBS decoupling + create-vs-delete credential | linux-cpu → provider | `linux-cpu/amd64` → provider | 3 | ⏸️ Blocked pending Phase-46 revalidation | [phase_47](phase_47_provider_ebs_credential.md) |
| 48 | Dynamic node provisioning by signal + leak-free provider gate | linux-cpu → provider | `linux-cpu/amd64` → provider | 3 | ⏸️ Blocked pending Phase-47 revalidation | [phase_48](phase_48_provider_dynamic_nodes.md) |
| 49 | Determinism kernel + jit-build CacheBudget cache | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-48 revalidation | [phase_49](phase_49_determinism_jitcache.md) |
| 50 | infernix core artifact lift | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-49 revalidation | [phase_50](phase_50_infernix_lift.md) |
| 51 | infernix UI lift | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-50 revalidation | [phase_51](phase_51_infernix_ui_lift.md) |
| 52 | Core jitML CUDA artifact lift | linux-cuda | `cuda` | 3 | ⏸️ Blocked pending Phase-51 revalidation | [phase_52](phase_52_jitml_lift_cuda.md) |
| 53 | jitML UI lift | linux-cuda | `cuda` | 3 | ⏸️ Blocked pending Phase-52 revalidation | [phase_53](phase_53_jitml_ui_lift.md) |
| 54 | Apple-Metal host compute daemon | apple | `metal` | 3 | ⏸️ Blocked pending Phase-53 revalidation | [phase_54](phase_54_apple_metal_host_daemon.md) |
| 55 | Test-topology DSL + suggest-test + elevated harness | per generated test | `per generated test` | 3 | ⏸️ Blocked pending Phase-54 revalidation | [phase_55](phase_55_test_topology_dsl.md) |
| 56 | Single-tenant low-code UI live path | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-55 revalidation | [phase_56](phase_56_ui_single_tenant_live.md) |
| 57 | Multi-tenant low-code UI isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-56 revalidation | [phase_57](phase_57_ui_multi_tenant_live.md) |
| 58 | UI rollout, projection catch-up, and reconnect | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-57 revalidation | [phase_58](phase_58_ui_rollout_reconnect.md) |
| 59 | Initial online UI multi-zone high availability | linux-cpu → provider | `linux-cpu/amd64` → provider | 3 | ⏸️ Blocked pending Phase-58 revalidation | [phase_59](phase_59_ui_ha_multizone.md) |
| 60 | Offline language and paired plans | none | `none` | 1 | ⏸️ Blocked pending Phase-59 revalidation | [phase_60](phase_60_offline_language_plan.md) |
| 61 | Encrypted browser offline runtime | none | `none` | 2 | ⏸️ Blocked pending Phase-60 revalidation | [phase_61](phase_61_encrypted_browser_runtime.md) |
| 62 | Offline replay and durable receipts | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-61 revalidation | [phase_62](phase_62_offline_replay_receipts.md) |
| 63 | Offline blobs and partition isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-62 revalidation | [phase_63](phase_63_offline_blobs_isolation.md) |
| 64 | Offline release and schema evolution | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-63 revalidation | [phase_64](phase_64_offline_release_evolution.md) |
| 65 | Offline multi-zone continuity | linux-cpu → provider | `linux-cpu/amd64` → provider | 3 | ⏸️ Blocked pending Phase-64 revalidation | [phase_65](phase_65_offline_multizone_continuity.md) |
| 66+ | Later phases | varies | varies | — | 📋 Planned | [later_phases](later_phases.md) |

## Related Documents

- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md)
