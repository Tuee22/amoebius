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
**Referenced by**: DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_core_folds.md, DEVELOPMENT_PLAN/phase_08_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_10_capability_bind.md, DEVELOPMENT_PLAN/phase_11_provision_seal.md, DEVELOPMENT_PLAN/phase_12_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_13_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_15_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_16_ui_program_schema.md, DEVELOPMENT_PLAN/phase_17_scoped_identity_kernel.md, DEVELOPMENT_PLAN/phase_18_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_19_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_20_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_21_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_22_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_23_ui_local_composition.md, DEVELOPMENT_PLAN/phase_24_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/phase_26_object_reconciler.md, DEVELOPMENT_PLAN/phase_27_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_28_retained_storage.md, DEVELOPMENT_PLAN/phase_29_vault_pki.md, DEVELOPMENT_PLAN/phase_30_platform_backbone.md, DEVELOPMENT_PLAN/phase_31_platform_services_2.md, DEVELOPMENT_PLAN/phase_32_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_33_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_34_app_tenancy.md, DEVELOPMENT_PLAN/phase_35_pulsar_client.md, DEVELOPMENT_PLAN/phase_36_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_37_content_store_workflow.md, DEVELOPMENT_PLAN/phase_38_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_39_release_lifecycle.md, DEVELOPMENT_PLAN/phase_40_ui_program_release.md, DEVELOPMENT_PLAN/phase_41_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_42_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_43_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_44_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_45_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_46_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_47_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_48_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_49_infernix_lift.md, DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_51_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_52_jitml_ui_lift.md, DEVELOPMENT_PLAN/phase_53_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_54_test_topology_dsl.md, DEVELOPMENT_PLAN/phase_55_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_56_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_57_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_58_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_59_offline_language_plan.md, DEVELOPMENT_PLAN/phase_60_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_61_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_62_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_63_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_64_offline_multizone_continuity.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/diagram_conventions.md, documents/engineering/dsl_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_schema.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/glossary.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_techniques.md, documents/reading_order.md, documents/engineering/repository_layout_doctrine.md
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
4. Every hardware substrate can run the `linux-cpu` baseline. Pristine Linux uses Incus on Linux or
   Linux-CUDA, Lima on Apple, and WSL2 on Windows.
5. A gate may additionally require at most one specialized lane, Apple or Linux-CUDA. The baseline cannot
   substitute for a specialized claim.
6. Register 1 is pure/golden, Register 2 is boundary-with-fakes, and Register 3 is live. Register 2.5 is a
   deterministic-simulation activity, never a phase-gate register.
7. Missing prerequisites fail; they never skip to green. Unreached applicable layers remain UNVERIFIED.

## Repository and evidence discipline

Only human-authored inputs and reviewed external source are version-controlled. Generated projections,
compiled output, lock/freeze files, package checksum databases, hard-coded library or package SHA values,
resolved paths, test enumeration, ledgers, receipts, logs, reports, screenshots, and generated
documentation remain untracked.

Generated local output belongs under `gen/`. Immutable run attestations belong in the external evidence
store. The complete repository tree, output inventory, and normative `.gitignore`/`.dockerignore` patterns
are owned by
[repository_layout_doctrine.md](../documents/engineering/repository_layout_doctrine.md).

## Toolchain

Compilers, package tools, libraries, code generators, browsers, and transitive dependencies resolve
dynamically from authored compatibility requirements. Every clean run records the selected versions,
source identities, dependency graph, executable paths, and observed integrity data under `gen/toolchain/`
and `gen/locks/`, then binds them into external evidence. No generated resolution is copied into Git.

## Document index

| Document | Role |
|---|---|
| [development_plan_standards.md](development_plan_standards.md) | Plan structure, status, reopening, gate integrity, and universal artifact hygiene |
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
verified external attestation can establish Policy-conformant progress or support ✅ Done.

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
8. An immutable external attestation verifies against that source-snapshot digest and the phase contract.
9. The source snapshot contains every referenced authored input and passes the same documented gate with no
   ignored worktree file as an input.
10. Semantic provenance checks reject reproducible tracked copies, including generated fixtures placed beneath
    otherwise authored roots.

Markdown never embeds the generated ledger, receipt, hash, transcript, or dependency resolution. A human
status decision may link the external run. A prior seal cannot satisfy Done, and neither can a run whose
source snapshot no longer matches the tree. **When the operator commits is their own affair and never a gate
condition** ([development_plan_standards.md §S](development_plan_standards.md#s-commit-timing)).

## Reopened numeric sequence

The 2026-08-11 generated-artifact amendment reopens phases 0–64 without renumbering them.

1. **Phase 0 is Done.** Its deliverables — the provenance classifier, generator registry, authored-root
   write guard, semantic generated-file scan, source-snapshot verification, ignore/context coverage,
   reachable-history audit, external-attestation validation, and the documentation lints — were implemented
   and sealed on 2026-08-12. The gate runs two-sided against a snapshot containing no ignored worktree file
   and publishes a verified external attestation.
2. **Phases 1–3 are Done.** Phase 1 replaced its pin manifest with authored compatibility requirements and a
   run-local resolver; Phases 2 and 3 migrated the formal-model and gateway-migration gates onto resolved
   toolchains, run-bundle ledgers, and run-time surface enumeration. Each was sealed on 2026-08-12 with a
   verified external attestation, recorded in the phase-overview table below.
3. **The lowest phase not yet sealed is Active; every phase above it is Blocked.** In order, each must migrate
   enumeration and evidence to `gen/`, establish oracle provenance, adopt the authored-root write guard, rerun
   its capability gate, and publish a snapshot-bound external attestation. The phase-overview table is the
   authority on which phase that currently is.
4. **Later phases remain Planned.** They inherit the redesigned doctrine from their first authored contract.

Prior implementation and run records may guide diagnosis. They do not allow a phase to skip its reopened
gate or numeric predecessor.

## Current implementation audit

This is a static audit of clean commit `c8870a2` observed on **2026-08-11**. At inspection time it matched
`origin/master`; ignored paths, the effective source-closure boundary, reachable revision history, and
unreachable local objects were inspected separately. A clean or pushed commit is not automatically
policy-conformant. Exact counts, paths, historical findings, and actionable mismatches live in
[legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md#existing-code-divergence-snapshot--2026-08-11).

| Phase(s) | Progress | Observed state | Required next boundary |
|---|---|---|---|
| 0 | **Policy-conformant** | Refreshed 2026-08-12. Sprints 0.5–0.7 are complete and the nine-sided gate is green, its snapshot side linting the corpus from non-ignored source alone: negatives materialize under `gen/test-corpora/`, surfaces enumerate into `gen/test-surfaces/`, the ledger lands in the run bundle, eleven artifact-policy rules each turn red on a seeded negative, no authored document links into a generated root, and the run publishes a verified external attestation | None. Phase 0 is sealed; its deferral list in `tools/migration_allowlist.tsv` is worked off by the phases that own each row |
| 1 | **Policy-conformant** | Refreshed 2026-08-12. `toolchain/pins.json` is deleted and split into authored `toolchain/requirements.json` and run-local `gen/toolchain/resolved.json`; the reviewed patch sits under `patches/**` and the superseded one is gone; `cabal.project` names a release channel, not a revision, and carries no developer path or frozen index snapshot. The nine-sided gate is green: two resolutions admit the same 225-package graph, the same graph resolves from non-ignored source alone, the representative set builds from an empty store, both seeded mutants redden, five seeded provenance negatives each turn exactly one check red, and the run publishes a verified external attestation | None. Phase 1 is sealed; its five deferral rows are removed from `tools/migration_allowlist.tsv` |
| 2 | **Policy-conformant** | Refreshed 2026-08-12. The JVM and `tla2tools` resolve from authored requirements instead of pinned URLs and archive checksums; the 31 recorded metrics are checked against the authored expectation and the ledger is derived from them into the run bundle; 14 surfaces join to 39 run-time enumerated items; and a new artifact side proves all 608 emitted `.tla`/`.cfg` files stay outside the source snapshot | None. Phase 2 is sealed |
| 3 | **Policy-conformant** | Refreshed 2026-08-12. The JVM and `tla2tools` resolve from authored requirements; twelve recorded metrics are checked against the authored expectation and the ledger is derived from them into the run bundle; 15 surfaces join to 17 run-time enumerated items; the emitted specification stays outside the source snapshot. Two previously unevidenced ledger rows now name the mutant families that decide them, and the open decomposition lemma stays UNVERIFIED | None. Phase 3 is sealed |
| 4 | **Policy-conformant** | Refreshed 2026-08-12. `dhall` resolves from authored requirements; the run bundle replaces both the plan-tree evidence directory and the generated `ledgers/phase_04_gate1.md`; 17 surfaces join to 20 run-time enumerated items. Two schema modules were normalized to satisfy the lint this phase has always required, and the `schema-modules` count oracle was amended from 14 to 17 and paired with a reviewed module inventory so later schema growth cannot drift past it | None. Phase 4 is sealed; its three deferral rows are removed from `tools/migration_allowlist.tsv` |
| 5 | **Policy-conformant** | Refreshed 2026-08-12. The results table is measured rather than asserted, the suite's tool paths are resolved rather than hard-coded, and the `serve-ui` entry point moved from `lib:dsl-core` to the executable that calls it — removing the code-level forward dependency that made every core-linking phase depend on the unimplemented Phase-22 boundary. 23 surfaces join to 26 run-time enumerated items | None. Phase 5 is sealed; its deferral row is removed from `tools/migration_allowlist.tsv` |
| 6 | **Policy-conformant** | Refreshed 2026-08-12. The results table is measured rather than asserted, `CorpusSpec` resolves its Dhall executable per run, and the previously undeclared `gen/dsl/**` output class is now in the canonical inventory — retiring eighteen deferrals across phases 6–23 that were really one missing registry row. 24 surfaces join to 27 run-time enumerated items | None. Phase 6 is sealed |
| 7 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle, 25 surfaces join to 25 run-time enumerated items, the Haskell gate resolves its Dhall executable per run, and every cabal invocation now carries the resolved compiler instead of inheriting whichever GHC the host's PATH offers | None. Phase 7 is sealed |
| 8 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle and 39 surfaces join to the run's own enumeration — 27 of them one-to-one against the storage-case oracle rather than sharing a single acceptance token. Three surface-to-case associations are provisional and recorded in the legacy register for the phase owner | None. Phase 8 is sealed |
| 9 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle; 56 surfaces join to the run's own enumeration, with 77 oracle cases and mutants partitioned one-to-one across 37 claim surfaces. Five contract surfaces have no recorded observation of their own and are now honestly UNVERIFIED rather than asserted tested; the gap is recorded against Phase 9 | None. Phase 9 is sealed |
| 10 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle; 29 surfaces join to the run's own enumeration, with 20 arm slugs, case names, and mutant names partitioned one-to-one. Five contract surfaces have no recorded observation and are now honestly UNVERIFIED; the gap is recorded against Phase 10 | None. Phase 10 is sealed |
| 11 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle; 34 surfaces join to the run's own enumeration, with 26 activation witnesses, planner cases, provision cases, and mutant names partitioned one-to-one. Six contract surfaces have no recorded observation and are now honestly UNVERIFIED; the gap is recorded against Phase 11 | None. Phase 11 is sealed |
| 12 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle; 28 surfaces join to the run's own enumeration with 23 items partitioned one-to-one. Two contract surfaces have no recorded observation and are now honestly UNVERIFIED | None. Phase 12 is sealed |
| 13 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle; 31 surfaces join to the run's own enumeration with 30 items partitioned one-to-one. Two surfaces now join to the source checks that always decided them; seven have no recorded observation and are honestly UNVERIFIED | None. Phase 13 is sealed |
| 14 | **Policy-conformant** | Refreshed 2026-08-12. Evidence and ledger move to the run bundle; 40 surfaces join to the run's own enumeration with 20 locus entries and mutants partitioned one-to-one. Six surfaces now join to source checks that always decided them, thirteen have no recorded observation and are honestly UNVERIFIED, and the whole-tree subprocess-site inventory is amended for three Phase-25 image modules with the check kept exact | None. Phase 14 is sealed |
| 15 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; all 26 surfaces join to the run's own enumeration with 22 items partitioned one-to-one and no surface left unevidenced. Two surfaces now join to source checks that always decided them; modeled-environment fidelity remains ASSUMED and the runtime layer UNVERIFIED, which is what Register 2 can honestly claim | None. Phase 15 is sealed |
| 16 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; 29 surfaces join to the run's own enumeration with 30 items partitioned one-to-one and all ten metrics claimed. Each foreclosure surface joins both its negative fixture and the mutant that attacks the same foreclosure; only the runtime-noninterference surface is unevidenced, which is correct for a pure register | None. Phase 16 is sealed |
| 17 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; 40 surfaces join to the run's own enumeration with 47 items partitioned one-to-one. Constructor opacity became nine independent checks instead of one, and every cabal call now carries the resolved compiler — without it the compile-fail battery failed to resolve `base` and reported a drifted locus. Three flow diagnostics no committed row exercises are honestly UNVERIFIED; the gap is recorded against Phase 17 | None. Phase 17 is sealed; its three deferral rows are removed from `tools/migration_allowlist.tsv` |
| 18 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; 40 surfaces join to the run's own enumeration with 57 items partitioned one-to-one and no surface unevidenced. `ActionEffect` and `Permission` are now checked as closed enumerable sums rather than implied by the rows that exercise them, and each mutant keeps its own surface beside the pinned row it attacks | None. Phase 18 is sealed; its three deferral rows are removed from `tools/migration_allowlist.tsv` |
| 19 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; 55 surfaces join to the run's own enumeration with 85 items partitioned one-to-one and no surface unevidenced. Four closed sums are now checked as sums, and the separately authored handler and capability tables are cross-checked both ways — a handler present in one and absent from the other used to bind to nothing without any row count noticing | None. Phase 19 is sealed; its three deferral rows are removed from `tools/migration_allowlist.tsv` |
| 20 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; 55 surfaces join to the run's own enumeration with 66 items partitioned one-to-one and no surface unevidenced. `test/fixtures/ui_plan_compiler/expected_digests.tsv` is deleted — four SHA-256 values over bytes the goldens already pin was a second copy nobody could author — and the suite derives that side at run time from the goldens, with a check that refuses to let a digest table return. The four plan goldens stay same-commit regression fixtures | Independent human review of the four plan goldens; the Phase-20 gate cannot supply the chronology Git does not record |
| 21 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; 66 surfaces join to the run's own enumeration with 84 items partitioned one-to-one. `test/fixtures/ui_browser/reference_traces.tsv` is deleted — it duplicated what the independent Haskell semantics returns — and `authoredRouteRows`, which ignored its argument and agreed with any corpus, now derives from the same semantics. The browser driver resolves from `toolchain/requirements.json` instead of a literal typed into the gate twice | None. Phase 21 is sealed; its four deferral rows are removed from `tools/migration_allowlist.tsv` |
| 22 | **Policy-conformant** | Refreshed 2026-08-13. The first run of this gate that could ever have passed: the boundary ABI the entry point imports was defined nowhere, so `exe:amoebius` did not build. `Amoebius.Ui.Server.Dispatch` implements it, the seeded mutants became inputs rather than CPP flags so all nine run against the observed binary, and the executable stopped listing `src` in `hs-source-dirs` — a search path, not a module filter, which had it recompiling the shared core into the executable against a shorter `build-depends`. 77 surfaces join to 94 items; `unreferenced-handler-unreachable` is honestly UNVERIFIED | None. Phase 22 is sealed; its five deferral rows are removed from `tools/migration_allowlist.tsv` |
| 23 | **Policy-conformant** | Refreshed 2026-08-13. Evidence and ledger move to the run bundle; 58 surfaces join to the run's own enumeration with 71 items partitioned one-to-one. The composition only became runnable once Phase 22's action table gained its `use-artifact` row, and the `M-drop-handle-tenant` detector — which tested for status 200 while the boundary answers 202 for a mutation — was reading a landed attack as a miss. The suite no longer names an absolute developer path for cabal or dhall | None. Phase 23 is sealed; its five deferral rows are removed from `tools/migration_allowlist.tsv` |
| 24 | **Known partial** | Refreshed 2026-08-13. The live capability is established: the migrated gate passes on all ten sides against a pristine Incus guest, replacing a retired form that verified a `live-*` evidence battery no tool in the tree writes and that had neither a surface enumeration nor a ledger. Zero bare-name PATH lookups across 88,654 execve calls; both divergent starts repaired without recreating the node; mutant M3 moved from `planned:requires-live-cluster` to observed-red inside the guest. The phase is not sealed: `pb/bootstrap_execution_envelope.json` still pins package integrity digests, an `r6` finding this phase owns and therefore cannot defer past its own closure | Resolve the bootstrap envelope's versions, URLs, and integrity per run; add SplitRuntime backing so M6 and the etcd/audit high-water surfaces have an observation; then reseal |
| 25–43 | **Observed footprint** | Each phase has implementation or gate material. Generated evidence/enumeration, unresolved TSV and oracle provenance, digest/checksum fixtures, and same-commit regression fixtures prevent a current policy-conformant result | Classify and migrate artifacts, independently review or replace regression fixtures, and rerun each current gate in numeric order |
| 44–47 | **Known partial** | Provider/AWS gate footprints exist, while the phase contracts explicitly record missing authenticated provider materialization, EBS/IAM behavior, node provisioning, audit, and leak-freedom | Complete the provider seams after predecessors close and run the live provider gates |
| 48 | **Observed footprint** | Pure and live/cache footprints exist; the prior `linux-cpu` result is invalidated by the artifact-policy amendment | Migrate and rerun the current Phase-48 gate |
| 49–58 | **Known partial** | Gate and test footprints exist. Phase 49 retains frozen sibling-source hashes and Phase 53 commits reference-program output; the range also retains scoped capability gaps in sibling lift, native transport, production topology, hardware, cleanup, or multi-zone behavior | Remove derived/hash expectations in their owning phases, close each capability gap, and rerun in numeric order on the required lane |
| 59 | **Observed footprint** | The offline-language source/test/gate footprint exists; its prior pre-cluster result is invalidated | Migrate and rerun the current Phase-59 gate |
| 60–64 | **Known partial** | Browser/offline gate footprints exist; the contracts retain production compiler, broker, identity, object-store, Kubernetes/CNI, rollout, or provider multi-zone gaps | Close the named Register-2/3 gaps and rerun in numeric order |
| 65+ | **No footprint observed** | This audit did not attribute an implementation footprint to an unnumbered later phase | Author a phase contract in numeric order before implementation |

The absence of a separately listed phase within a range does not hide its state: every integer in that range
inherits the row. Any later code or plan change that affects these observations must refresh this audit and
the legacy register in the same documentation change.

## Phase overview

The table is an order-and-status index. It is read with the dated progress audit above, not as an assertion
that a blocked phase has no code. The linked phase document owns the phase-specific gate; every gate also
inherits the universal postcondition above.

| Phase | Name | Substrate | Register | Status | Validation contract |
|---|---|---|---|---|---|
| 0 | Documentation suite (whole DSL) | none | — | ✅ Done — sealed 2026-08-12, attestation `sha256:e6016cf4e59bd229bf1af69a778fff878dee516bbf3535ba12120a3ecc127170` | [phase_00](phase_00_documentation_suite.md) |
| 1 | Toolchain spike | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:353cafb9d60d6e4205d84fef33dd92ea4c0f198c5dfcdf16455c5a217e95bb24` | [phase_01](phase_01_toolchain_spike.md) |
| 2 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:a6c345e051ff96ff3c66c98a4ea2832f56ada1d50c0d91524a0ce9763b19710e` | [phase_02](phase_02_formal_model_kernel.md) |
| 3 | Gateway-migration model (both branches) | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:f640ce89ff0bd972746f1b155446e7b54266c946cf4b6b8f3f925073fd74f189` | [phase_03](phase_03_gateway_migration_model.md) |
| 4 | Dhall Gate-1 schema + smart-constructor prelude | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:00bfda42ed8e2ddc333713e05262a92f41d9bc76b2dad1219202e12099a9c019` | [phase_04](phase_04_dhall_gate1_schema.md) |
| 5 | GADT-indexed IR + total decoder (Gate 2) | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:3dfdee987647704b9e62dd70e6c31c4fe96b58df533b216a7b59f73f38ad1a1f` | [phase_05](phase_05_gadt_decoder_gate2.md) |
| 6 | Illegal-state corpus + validation-locus ledger | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:2a18c8372d20736e226b93994c8fcd7e133af9e55bc799889551a653269a8b05` | [phase_06](phase_06_illegal_state_corpus.md) |
| 7 | Capacity core fold + topology relation | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:61ba75bf3bb6b53846b17ac13903918ec00a1dd14604fbf92c8bb747fc2dd445` | [phase_07](phase_07_capacity_core_folds.md) |
| 8 | Logical→physical storage geometry folds | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:2236282920d39585e287806cab364d279156460312aec61e480abdc812d9435c` | [phase_08](phase_08_storage_geometry_folds.md) |
| 9 | Execution-epoch + scheduler + accelerator + provider-root folds | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:305cadfdf77170e64269d4842fdc9e8a7fea370b991056a7f465db7009c4bd0b` | [phase_09](phase_09_execution_accelerator_folds.md) |
| 10 | Capability union + representational bind | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:af29f3726a6b4464436530958b476925360aec3a82a7005ade12fda31a0ad6b6` | [phase_10](phase_10_capability_bind.md) |
| 11 | Whole-deployment provision seal + expansion | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:46f666a4abf03ac312c5f90f695e87670dbe1855f8d068e1152f3e5b991d1cb8` | [phase_11](phase_11_provision_seal.md) |
| 12 | InferenceEngine capability + accelerator provision | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:eba86a80c57d10c9629d25cd74199104d3df181cb1adbb2f223492d1d3b3a89f` | [phase_12](phase_12_inference_accelerator_provision.md) |
| 13 | Pure `renderAll` + rendered-output goldens | none | 1 | ✅ Done — sealed 2026-08-12, attestation `sha256:105d193d15c907176c594bb81305890191d2f818081bf11c081bb499cd046794` | [phase_13](phase_13_render_manifest_goldens.md) |
| 14 | chain/Step kernel + `--dry-run` + boundary fake-tool harness + Gate-3 AST checker | none | 1/2 | ✅ Done — sealed 2026-08-12, attestation `sha256:95a34d33ad9a72a75072bfd1e905a7f9c811a6871a0ecbbde0b67b9613064eb5` | [phase_14](phase_14_chain_kernel_boundary.md) |
| 15 | Deterministic-simulation substrate | none | 2 | ✅ Done — sealed 2026-08-13, attestation `sha256:8a27796e30cb0da4b538fd20e3d758bdf4dff3417669cbf1766c7bc247eaa0b3` | [phase_15](phase_15_deterministic_sim_substrate.md) |
| 16 | Bounded UI-program schema | none | 1 | ✅ Done — sealed 2026-08-13, attestation `sha256:4580dcd430b5608434256528d6500153f7aac31b5bfe27bcf1b484e53ab44c9c` | [phase_16](phase_16_ui_program_schema.md) |
| 17 | Scoped identity kernel | none | 1 | ✅ Done — sealed 2026-08-13, attestation `sha256:45ba0ed3a546b6dd436f611f2d12e80378bc64c5d349d8f9fdf44f32c727b18a` | [phase_17](phase_17_scoped_identity_kernel.md) |
| 18 | UI authorization kernel | none | 1 | ✅ Done — sealed 2026-08-13, attestation `sha256:409c13f0c41aec877a4f3f72c3509fd1c17322523920e1deff0abac0b1cca88a` | [phase_18](phase_18_ui_authorization_kernel.md) |
| 19 | UI effect binding | none | 1 | ✅ Done — sealed 2026-08-13, attestation `sha256:470c58ccbca52b5e580058c7e086a5b22d5af0bc506ee58d14e397529903587d` | [phase_19](phase_19_ui_effect_binding.md) |
| 20 | UI plan compiler | none | 1 | ✅ Done — sealed 2026-08-13, attestation `sha256:6e567d5b9a009a424ba1974e7d62957e579bd56f928e9bc1076365584aaaa8be` | [phase_20](phase_20_ui_plan_compiler.md) |
| 21 | Generic browser interpreter | none | 2 | ✅ Done — sealed 2026-08-13, attestation `sha256:9494bf7e55160959786c7028baa5d9e0dad2ecb7227e541a03164cd08e6ed3e8` | [phase_21](phase_21_ui_browser_interpreter.md) |
| 22 | UI-server boundary | none | 2 | ✅ Done — sealed 2026-08-13, attestation `sha256:eec403a9845ec9acf5201e49bf916cd7d3c8e69cdd66c5daef743efb90aac59e` | [phase_22](phase_22_ui_server_boundary.md) |
| 23 | Local UI composition | none | 2 | ✅ Done — sealed 2026-08-13, attestation `sha256:363ae0c7c14e334f0455a1ffb67c9ce14eae0f33c736ca555187b076f596bc1a` | [phase_23](phase_23_ui_local_composition.md) |
| 24 | Python bootstrap coordinator + substrate detect + single kind cluster | linux-cpu | 3 | 🔄 Active — artifact migration | [phase_24](phase_24_bootstrap_coordinator_kind.md) |
| 25 | Typed bake catalog + multi-arch base image + jit-build resolver + distribution registry | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_25](phase_25_base_image_registry.md) |
| 26 | Typed renderer + object reconciler | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_26](phase_26_object_reconciler.md) |
| 27 | amoebius-capacity scheduler + bootstrap cutover | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_27](phase_27_capacity_scheduler.md) |
| 28 | No-provisioner retained storage + lossless rebind | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_28](phase_28_retained_storage.md) |
| 29 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_29](phase_29_vault_pki.md) |
| 30 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_30](phase_30_platform_backbone.md) |
| 31 | Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_31](phase_31_platform_services_2.md) |
| 32 | Keycloak-owned ingress | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_32](phase_32_keycloak_ingress.md) |
| 33 | Live DSL deploy via the replicas=1 singleton | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_33](phase_33_live_dsl_singleton.md) |
| 34 | Tenant/provider provisioning | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_34](phase_34_app_tenancy.md) |
| 35 | Native Pulsar client (CBOR) | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_35](phase_35_pulsar_client.md) |
| 36 | Live subject/tenant isolation | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_36](phase_36_user_tenant_isolation_live.md) |
| 37 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_37](phase_37_content_store_workflow.md) |
| 38 | Owner-scoped UI projection runtime | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_38](phase_38_ui_projection_runtime.md) |
| 39 | Release lifecycle | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_39](phase_39_release_lifecycle.md) |
| 40 | Atomic immutable UI-program release | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_40](phase_40_ui_program_release.md) |
| 41 | WireGuard network fabric | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_41](phase_41_network_fabric_wireguard.md) |
| 42 | Multi-cluster spawn + geo-replication | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_42](phase_42_multicluster_spawn_georepl.md) |
| 43 | Gateway-migration drills + model-correspondence | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_43](phase_43_gateway_migration_drills.md) |
| 44 | Provider Pulumi deploy-from-inside + enveloped checkpoint | linux-cpu → provider | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_44](phase_44_provider_deploy_checkpoint.md) |
| 45 | Hostless provider child + convergence + Lease handoff | linux-cpu → provider | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_45](phase_45_provider_child_bringup.md) |
| 46 | Per-PV EBS decoupling + create-vs-delete credential | linux-cpu → provider | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_46](phase_46_provider_ebs_credential.md) |
| 47 | Dynamic node provisioning by signal + leak-free provider gate | linux-cpu → provider | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_47](phase_47_provider_dynamic_nodes.md) |
| 48 | Determinism kernel + jit-build CacheBudget cache | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_48](phase_48_determinism_jitcache.md) |
| 49 | infernix core artifact lift | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_49](phase_49_infernix_lift.md) |
| 50 | infernix UI lift | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_50](phase_50_infernix_ui_lift.md) |
| 51 | Core jitML CUDA artifact lift | linux-cuda | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_51](phase_51_jitml_lift_cuda.md) |
| 52 | jitML UI lift | linux-cuda | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_52](phase_52_jitml_ui_lift.md) |
| 53 | Apple-Metal host compute daemon | apple | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_53](phase_53_apple_metal_host_daemon.md) |
| 54 | Test-topology DSL + suggest-test + elevated harness | per generated test | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_54](phase_54_test_topology_dsl.md) |
| 55 | Single-tenant low-code UI live path | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_55](phase_55_ui_single_tenant_live.md) |
| 56 | Multi-tenant low-code UI isolation | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_56](phase_56_ui_multi_tenant_live.md) |
| 57 | UI rollout, projection catch-up, and reconnect | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_57](phase_57_ui_rollout_reconnect.md) |
| 58 | Initial online UI multi-zone high availability | linux-cpu → provider | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_58](phase_58_ui_ha_multizone.md) |
| 59 | Offline language and paired plans | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_59](phase_59_offline_language_plan.md) |
| 60 | Encrypted browser offline runtime | none | 2 | ⏸️ Blocked by reopened numeric sequence | [phase_60](phase_60_encrypted_browser_runtime.md) |
| 61 | Offline replay and durable receipts | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_61](phase_61_offline_replay_receipts.md) |
| 62 | Offline blobs and partition isolation | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_62](phase_62_offline_blobs_isolation.md) |
| 63 | Offline release and schema evolution | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_63](phase_63_offline_release_evolution.md) |
| 64 | Offline multi-zone continuity | linux-cpu → provider | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_64](phase_64_offline_multizone_continuity.md) |
| 65+ | Later phases | varies | — | 📋 Planned | [later_phases](later_phases.md) |

## Related Documents

- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md)
