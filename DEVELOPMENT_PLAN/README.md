# Amoebius Development Plan

> **Purpose**: Provide the authoritative numeric phase order, current status, remaining work, and routing
> to each phase's independently authored validation contract.
> **Read this if**: the current phase, the next permitted work, or the location of a phase gate must be established.

This tracker owns phase order, status, and dated implementation progress. Each phase document owns its
capability-specific validation contract, while the universal source-snapshot postcondition is owned by
[development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
Architecture remains owned by the doctrine suite under [`../documents/`](../documents/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, DEVELOPMENT_PLAN/phase_23_extension_security_laws.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/diagram_conventions.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/low_code_ui_workflow_lifting.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_ebs_credential_model.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_schema.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/substrate_node_inventory.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/tla_modelling_assumptions.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/validation_frame_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_capability_messaging.md, documents/illegal_state/illegal_state_capacity.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_tenancy.md, documents/illegal_state/illegal_state_topology.md, documents/reading_order.md
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

## Phase discipline

The [phase model](development_plan_phase_model.md#e-one-canonical-phase-model) owns the ordered domain and
hardware barriers. This tracker retains phases 0–95 and their existing capability identities. The compiled
phase-identity table supplies barrier ordinals; this documentation reset does not renumber capabilities.

An agent may continue automatically through implementation-ready sprints and consecutive qualified phases.
Each phase receives its own candidate and exact status-only transition. Later hardware-free preparation
requires its own contract and independent oracle; it produces component diagnostics until its predecessor passes.

Hardware discovery and live effects remain closed until `DSL_BARRIER` and every required predecessor pass.
The roles remain `DSL_BARRIER`, `BOOTSTRAP_HANDOFF`, `HOST_ENSURE`, and `FIRST_HARDWARE`, in that order.
Missing software verification cannot be replaced by hardware success.

## Repository and evidence discipline

The [layout doctrine](../documents/engineering/repository_layout_doctrine.md) owns source classification and
state roots. Haskell owns executable contracts, expectations, coverage, reset generations, and evidence
eligibility. Markdown explains those obligations; its dates, tables, and completion markers supply no verdict.

The [gate-integrity contract](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass) requires
protected acceptance and evidence custody. Copies beneath `.build/**`, matching hashes, and hidden constructors
alone do not establish an authentic pass. Evidence must bind the accepted generation and exact dependency closure.

## Toolchain

The [validation-execution doctrine](../documents/engineering/validation_frame_doctrine.md#2-the-bootstrap-boundary)
owns the finite bootstrap assumption and authenticated acquisition. Phase 0 states its irreducible trust
boundary; Phase 1 qualifies broader toolchain claims. Neither phase depends on implementing the universal DSL gate.

Before the handoff gate passes, validation invokes the exact source-bound Haskell executable directly.
Compiler-bearing development remains serial. Authenticated, network-independent inputs are required by the
phase contract; a locally available compiler supports only the diagnostics that actually used it.

## Document index

| Document | Role |
|---|---|
| [development_plan_standards.md](development_plan_standards.md) | The plan rulebook's hub: every section heading and anchor, and the document-form rules |
| [development_plan_phase_model.md](development_plan_phase_model.md) | Rulebook slice: status vocabulary, the phase model, honesty, substrate discipline, reopening and re-baselining |
| [development_plan_gate_integrity.md](development_plan_gate_integrity.md) | Rulebook slice: gate integrity, universal artifact hygiene, reconciliation, and the final repository layout |
| [overview.md](overview.md) | Target architecture and cross-cutting invariants |
| [system_components.md](system_components.md) | Target-only Haskell component-to-doctrine/phase map; never a present-tree or status ledger |
| [substrates.md](substrates.md) | Hardware/substrate registry and pristine-host routing |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | The sole reader-facing explanation of active typed Haskell divergence bindings; never executable contract |
| [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) | Complete authored/generated tree, dynamic resolution, and ignore/context contract |
| [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) | Validation registers and boundary discipline |
| [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) | Register-2.5 scheduling and replay discipline |
| [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) | Sibling-source migration and convergence rules |
| `phase_00_*.md` … `phase_95_*.md` | One independently authored capability and validation contract per phase |
| [later_phases.md](later_phases.md) | In-scope phases not yet assigned an integer document |

## Status vocabulary

The numbered plan has exactly three states: **Done**, **Active — NOT VALIDATED**, and
**Blocked — NOT VALIDATED**. The [phase model](development_plan_phase_model.md#c-status-vocabulary) defines
their exact tracker, phase, and sprint forms. There is one contiguous validation frontier.

## Implementation-progress vocabulary

**Observed footprint** records attributable source or diagnostics. **Known partial** records a specific missing
behavior, authority, or observation. These descriptions preserve development progress without conferring
certification. They are separate from phase status and cannot authorize gate execution.

## Definition of Done

The [gate-integrity contract](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
owns acceptance. A complete qualified run must demonstrate the accepted capability through actual production
behavior, independent expectations, exact mutation attribution, authentic observation, and current-generation evidence.

An accepted run emits its exact status-only patch. After the verifier exits, an agent may check the bound
preimage, apply that patch, and continue numerically without another routine approval.
Implementation, oracle, policy, or contract changes require the eligibility checks defined by the
[revalidation procedure](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

This documentation refactor is not a qualified gate run. It closes no phase and repairs no Haskell verifier.

## Reopened numeric sequence

**Certification reset — 2026-09-08.** All earlier phase and sprint certification is invalidated for the
replacement validation generation. Phase 0 is Active; phases 1–95 are Blocked. Existing implementation and
diagnostics remain available for inspection and repair.

The August 22 reset and subsequent recorded completions are historical. Commits `f260c29`, `e6ce05c`,
`66690f7`, and `d880196` recorded advancement through phases 0, 46, 49, and 52 respectively.
Those status changes do not establish eligibility under the replacement contract.

A typed generation identity, protected baseline admission, receipt eligibility, and dependency-impact rules
must be implemented and independently qualified in Haskell. This date is a reader reference, not that identity.
Old JSON or a prior Done marker must not admit a candidate in the replacement generation.

The reset retains target capabilities and source paths. An obligation may be refined or transferred only
under the [scope-preservation procedure](development_plan_phase_model.md#n-reopening-and-amending-a-phase).
Restating a narrower test inventory cannot discharge the original capability.

## Current implementation audit

**2026-09-08 — Known partial.** The audit found false-proof and false-qualification paths in current source.
Serial direct-source GHC diagnostics reproduced the cases below. They are defect observations, not phase
evidence, authenticated toolchain acquisition, or complete corpus coverage.

| Owner | Observed footprint or known partial boundary | Required repair |
|---|---|---|
| [Phase 0](phase_00_documentation_suite.md) | Generation eligibility and protected acceptance custody are not established by the existing receipt machinery. | Implement the finite reset/admission boundary and preserve its explicit bootstrap assumptions. |
| [Phases 1–2](phase_01_toolchain_spike.md) | Toolchain and source-graph machinery exists; this checkout lacks transferred authenticated inputs and gate receipts. | Reacquire authentic inputs and qualify source/dependency closure without treating file presence as evidence. |
| [Phases 11–14](phase_11_formal_model_kernel.md) | Malformed guards can disappear; sets and name binding disagree; a commented function can receive a refinement proof. | Reject malformed semantics and establish interpreter, solver, and compiled-source correspondence. |
| [Phases 18–34](phase_18_dsl_formal_model.md) | Capacity differentials and TLC machinery exist; several later projections represent fixture counts. | Preserve bounded results and establish correspondence of actual decoded, provisioned, rendered, and planned values. |
| [Phases 42–46](phase_42_ui_browser_interpreter.md) | A plan with no routes admits a workflow route; generated browser artifacts contain placeholders. | Implement generic checked-plan semantics and executable software projections with independent observations. |
| [Phase 49](phase_49_self_referential_gates.md) | Stage records contain supplied success values; qualification accepts labels and unrelated exceptions. | Execute the real typed pipeline and sabotage the actual accepted harness at exact loci. |
| [Phases 50–52](phase_50_host_assert_cli.md) | Bootstrap and host implementations exist; mutation attribution and effect observation remain incomplete. | Require exact failures, unaffected controls, production-caller coverage, and independently observed effects. |
| [Phase 53](phase_53_apple_engine_bringup.md) | Apple oracle changes distinguish assigned failure sets; native acquisition and predecessor custody remain open. | Preserve those tests and qualify the complete native path only after the reset frontier reaches it. |
| [Phases 54–95](phase_54_windows_engine_bringup.md) | Retained plans and source are implementation inventory. | Implement and validate each preserved capability in numerical order. |

The symbolic diagnostic returned `Inductive` for a model whose explicit checker returned an invariant
counterexample. The refinement diagnostic returned `Proved` while its compiled function returned `-1`
under a nonnegative-result obligation. A mutation selector reported qualification success for an unrelated exception.

These results do not erase useful work. The source includes an independent 6,561-case capacity differential,
Java/TLC state comparisons, and production mutation seams. Their scope and any future qualification are
determined by the owning contracts, not by their existence or earlier PASS output.

**Observed footprint — Apple development.** Before this reset, the macOS `arm64` checkout had no transferred
Phase-52 receipt, original candidate, bootstrap inputs, or authenticated source cache. Its dispatcher also
required Linux-only GenesisTrust, and its qualification runner assumed a different Cabal store location.

The existing Apple oracle changes distinguish exact assigned failures, missing floor members, and one-short
capacity refusals. Serial diagnostics accepted clean production and rejected six mutants, a combined unrelated
failure, and unchanged production linked to a mutant-selected test. No complete Apple gate or live Colima
execution occurred. Those source changes remain preserved.

The [divergence register](legacy_tracking_for_deletion.md) explains existing typed bindings and outstanding
reconciliation. New repair identities and their reintroduction cases must be implemented in Haskell; a row here
cannot manufacture such a binding. Earlier detailed diagnostic narratives remain in Git history.

## Phase overview

The table is an order-and-status index. It is read with the dated progress audit above, not as an assertion
that a blocked phase has no code. The linked phase document owns the phase-specific gate; every gate also
inherits the universal postcondition above.

| Phase | Name | Substrate | Lane | Register | Status | Validation contract |
|---|---|---|---|---|---|---|
| 0 | Documentation, source policy, and validation baseline | none | `none` | — | 🔄 Active — NOT VALIDATED | [Contract](phase_00_documentation_suite.md) |
| 1 | Haskell toolchain and probe-source closure | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_01_toolchain_spike.md) |
| 2 | Repository layout conformance and de-phased naming | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_02_repository_layout_conformance.md) |
| 3 | The artifact calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_03_artifact_calculus.md) |
| 4 | The budget calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_04_budget_calculus.md) |
| 5 | The lift calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_05_lift_calculus.md) |
| 6 | The workflow calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_06_workflow_calculus.md) |
| 7 | The evidence calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_07_evidence_calculus.md) |
| 8 | Scoped identity kernel | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_08_scope_index.md) |
| 9 | Capacity core fold + topology relation | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_09_resource_index.md) |
| 10 | Composition across the five calculi | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_10_calculus_composition.md) |
| 11 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_11_formal_model_kernel.md) |
| 12 | The amoebius explicit-state checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_12_explicit_state_checker.md) |
| 13 | The amoebius symbolic checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_13_symbolic_checker.md) |
| 14 | The amoebius refinement checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_14_refinement_checker.md) |
| 15 | The compile-fail fixture harness | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_15_compile_fail_harness.md) |
| 16 | Deterministic-simulation substrate | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_16_deterministic_sim_substrate.md) |
| 17 | Gateway-migration model (both branches) | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_17_gateway_migration_model.md) |
| 18 | DSL formal model | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_18_dsl_formal_model.md) |
| 19 | Reconcile decision core under deterministic simulation | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_19_reconcile_core_simulation.md) |
| 20 | The extension declaration | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_20_extension_declaration.md) |
| 21 | The per-extension laws L1-L5 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_21_extension_laws_per_extension.md) |
| 22 | The compositional laws C1-C7 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_22_extension_laws_compositional.md) |
| 23 | The security laws S1-S6 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_23_extension_security_laws.md) |
| 24 | The generated conformance gate | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_24_conformance_gate_generator.md) |
| 25 | Haskell-derived Dhall projection and smart-constructor prelude | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_25_dhall_schema_generation.md) |
| 26 | Haskell protocol declarations, GADT-indexed IR, and total decoder | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_26_gadt_decode_ir.md) |
| 27 | Illegal-state corpus + validation-locus ledger | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_27_illegal_state_covering.md) |
| 28 | Logical→physical storage geometry folds | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_28_storage_geometry_folds.md) |
| 29 | Execution-epoch + scheduler + accelerator + provider-root folds | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_29_execution_accelerator_folds.md) |
| 30 | Capability union + representational bind | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_30_capability_bind.md) |
| 31 | Whole-deployment provision seal + expansion | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_31_provision_seal.md) |
| 32 | InferenceEngine capability + accelerator provision | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_32_inference_accelerator_provision.md) |
| 33 | Pure `renderAll` + rendered-artifact oracles | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_33_render_manifest_oracles.md) |
| 34 | chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_34_chain_kernel_boundary.md) |
| 35 | The amoebius image recipe | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_35_image_recipe_generation.md) |
| 36 | The closed transaction vocabulary | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_36_transaction_vocabulary.md) |
| 37 | Bounded UI-program schema | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_37_ui_program_schema.md) |
| 38 | UI authorization kernel | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_38_ui_authorization_kernel.md) |
| 39 | UI effect binding | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_39_ui_effect_binding.md) |
| 40 | UI plan compiler | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_40_ui_plan_compiler.md) |
| 41 | Offline language and paired plans | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_41_offline_language_plan.md) |
| 42 | Haskell browser-interpreter semantics and projection | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_42_ui_browser_interpreter.md) |
| 43 | Haskell UI-server boundary | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_43_ui_server_boundary.md) |
| 44 | Hardware-free Haskell UI composition | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_44_ui_local_composition.md) |
| 45 | Haskell offline-state semantics and runtime projection | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_45_encrypted_browser_runtime.md) |
| 46 | Haskell-generated browser contracts and bundle | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_46_ui_contract_generation.md) |
| 47 | Foreign-source generator closure, checking tools, and mutants | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_47_tool_and_mutant_generation.md) |
| 48 | The test-workflow algebra | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_48_test_workflow_algebra.md) |
| 49 | No-hardware DSL gate barrier + self-referential gate suite | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_49_self_referential_gates.md) |
| 50 | Validate the bounded `pb` → Haskell handoff | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_50_host_assert_cli.md) |
| 51 | The host-ensure kernel | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_51_host_ensure_kernel.md) |
| 52 | Linux: sudoless Docker and the native image | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_52_linux_engine_bringup.md) |
| 53 | Apple: Homebrew, Colima, and the native image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_53_apple_engine_bringup.md) |
| 54 | Windows: WSL2 and the lifted Linux engine | windows | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_54_windows_engine_bringup.md) |
| 55 | Haskell substrate coordinator + single kind cluster | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_55_bootstrap_coordinator_kind.md) |
| 56 | The base image, the jit-build resolver, and the in-cluster registry | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_56_base_image_registry.md) |
| 57 | The complementary-architecture base image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_57_complementary_arch_child.md) |
| 58 | Typed renderer + object reconciler | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_58_object_reconciler.md) |
| 59 | amoebius-capacity scheduler + bootstrap cutover | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_59_capacity_scheduler.md) |
| 60 | No-provisioner retained storage + lossless rebind | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_60_retained_storage.md) |
| 61 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_61_vault_pki.md) |
| 62 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_62_platform_backbone.md) |
| 63 | Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_63_platform_services_2.md) |
| 64 | Keycloak-owned ingress | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_64_keycloak_ingress.md) |
| 65 | Live DSL deploy via the replicas=1 control-plane daemon | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_65_live_dsl_deploy.md) |
| 66 | Tenant/provider provisioning | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_66_app_tenancy.md) |
| 67 | Native Pulsar client (CBOR) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_67_pulsar_client.md) |
| 68 | Live subject/tenant isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_68_user_tenant_isolation_live.md) |
| 69 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_69_content_store_workflow.md) |
| 70 | Owner-scoped UI projection runtime | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_70_ui_projection_runtime.md) |
| 71 | Release lifecycle | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_71_release_lifecycle.md) |
| 72 | Atomic immutable UI-program release | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_72_ui_program_release.md) |
| 73 | WireGuard network fabric | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_73_network_fabric_wireguard.md) |
| 74 | Multi-cluster spawn + geo-replication | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_74_multicluster_spawn_georepl.md) |
| 75 | Gateway-migration drills + model-correspondence | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_75_gateway_migration_drills.md) |
| 76 | Haskell-derived provider Pulumi program and enveloped checkpoint | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_76_provider_deploy_checkpoint.md) |
| 77 | Hostless provider child + convergence + Lease handoff | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_77_provider_child_bringup.md) |
| 78 | Per-PV EBS decoupling + create-vs-delete credential | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_78_provider_ebs_credential.md) |
| 79 | Dynamic node provisioning by signal + leak-free provider gate | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_79_provider_dynamic_nodes.md) |
| 80 | Determinism kernel + jit-build CacheBudget cache | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_80_determinism_jitcache.md) |
| 81 | Single-tenant low-code UI live path | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_81_ui_single_tenant_live.md) |
| 82 | Multi-tenant low-code UI isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_82_ui_multi_tenant_live.md) |
| 83 | UI rollout, projection catch-up, and reconnect | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_83_ui_rollout_reconnect.md) |
| 84 | Initial online UI multi-zone high availability | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_84_ui_ha_multizone.md) |
| 85 | Offline replay and durable receipts | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_85_offline_replay_receipts.md) |
| 86 | Offline blobs and partition isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_86_offline_blobs_isolation.md) |
| 87 | Offline release and schema evolution | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_87_offline_release_evolution.md) |
| 88 | Offline multi-zone continuity | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_88_offline_multizone_continuity.md) |
| 89 | Apple-Metal host compute daemon | apple | `metal` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_89_apple_metal_host_daemon.md) |
| 90 | The live test topology and elevated harness | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_90_test_topology_live.md) |
| 91 | The infernix inference core, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_91_infernix_rederivation.md) |
| 92 | The infernix workflow and artifact contracts, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_92_infernix_ui_rederivation.md) |
| 93 | The jitML numerical core, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_93_jitml_rederivation.md) |
| 94 | The jitML training and checkpoint contracts, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_94_jitml_ui_rederivation.md) |
| 95 | The multi-tenant web application re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_95_webapp_rederivation.md) |

Unnumbered future work remains in [later_phases.md](later_phases.md). It is not a numbered phase, tracker row,
predecessor, or validation state until a standards change assigns it an exact ordinal and contract.

## Related Documents

- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md)
