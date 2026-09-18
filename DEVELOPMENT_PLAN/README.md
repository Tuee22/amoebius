# Amoebius Development Plan

> **Purpose**: Provide the authoritative phase order, current status, and routing to each phase's
> independently authored validation contract.
> **Read this if**: the current phase, the next permitted work, or the location of a phase gate must be established.

This tracker owns phase order and status. Each phase document owns its capability-specific validation
contract, while the universal source-snapshot postcondition is owned by
[development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
Architecture remains owned by the doctrine suite under [`../documents/`](../documents/README.md), and the
reasons the plan has its present shape are recorded in the [decision log](../documents/decision_log.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_07_child_clusters_obligation_teardown.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_09_dsl_barrier.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/decision_log.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/diagram_conventions.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/low_code_ui_workflow_lifting.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_ebs_credential_model.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_schema.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/substrate_node_inventory.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/validation_frame_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_capability_messaging.md, documents/illegal_state/illegal_state_capacity.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_tenancy.md, documents/illegal_state/illegal_state_topology.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents

- [Phase discipline](#phase-discipline)
- [Repository and evidence discipline](#repository-and-evidence-discipline)
- [Toolchain](#toolchain)
- [Document index](#document-index)
- [Status vocabulary](#status-vocabulary)
- [Definition of Done](#definition-of-done)
- [Transition procedure](#transition-procedure)
- [Generation-2 reset](#generation-2-reset)
- [Phase overview](#phase-overview)
- [Related Documents](#related-documents)

## Phase discipline

The [phase model](development_plan_phase_model.md#e-one-canonical-phase-model) owns the ordered domain and
hardware barriers. The domain is `0..9 ∪ 50..95`; ordinals 10 through 49 are a reserved gap with no row,
occupiable only by a new decision-log entry and a new certification generation
([DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)). Phases are
considered in table order: Phase 50's predecessor is Phase 9.

The four ordering barriers are named by role: `DSL_BARRIER` (Phase 9), `BOOTSTRAP_HANDOFF` (Phase 50),
`HOST_ENSURE` (Phase 51), and `FIRST_HARDWARE` (Phase 52), in that order. The compiled phase-identity table
resolves each role to its ordinal; this tracker projects that table. Hardware discovery and live effects
remain closed until the barrier's receipt exists, and every hardware gate binds that receipt and runs a
corpus example through its own subject. Missing software verification cannot be replaced by hardware success.

An agent implements sprint seams and runs `amoebius-validate preview phase NN`, which mints nothing. Later
hardware-free preparation requires its own contract and independent oracle; it produces component diagnostics
until its predecessor is accepted.

## Repository and evidence discipline

The [layout doctrine](../documents/engineering/repository_layout_doctrine.md) owns source classification and
state roots. Haskell owns executable contracts, expectations, coverage, generations, and evidence eligibility.
Markdown explains those obligations; its dates, tables, and completion markers supply no verdict.

The [gate-integrity contract](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass) requires
protected acceptance and evidence custody. Copies beneath `.build/**`, matching hashes, and hidden constructors
alone do not establish an authentic pass. Evidence must bind the accepted generation, the verifier digest, the
governance digest, and the predecessor's product closure.

## Toolchain

The [validation-execution doctrine](../documents/engineering/validation_frame_doctrine.md#2-the-bootstrap-boundary)
owns the finite bootstrap assumption and authenticated acquisition. Phase 0 states its irreducible trust
boundary; Phase 1 qualifies broader toolchain claims. Neither phase depends on implementing the DSL barrier.

Before the handoff gate passes, validation invokes the exact source-bound verifier `amoebius-validate`
directly, which spawns the product binary `amoebius` as a child for every product command. Compiler-bearing
development remains serial. Authenticated, network-independent inputs are required by the phase contract; a
locally available compiler supports only the diagnostics that actually used it.

## Document index

| Document | Role |
|---|---|
| [development_plan_standards.md](development_plan_standards.md) | The plan rulebook's hub: every section heading and anchor, and the document-form rules |
| [development_plan_phase_model.md](development_plan_phase_model.md) | Rulebook slice: status vocabulary, the phase model, honesty, substrate discipline, reopening and re-baselining |
| [development_plan_gate_integrity.md](development_plan_gate_integrity.md) | Rulebook slice: gate integrity, universal artifact hygiene, reconciliation, and the final repository layout |
| [overview.md](overview.md) | Target architecture and cross-cutting invariants |
| [system_components.md](system_components.md) | Target-only Haskell component-to-doctrine/phase map; never a present-tree or status ledger |
| [substrates.md](substrates.md) | Hardware/substrate registry and pristine-host routing |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | The sole reader-facing explanation of active typed Haskell divergence bindings and the audit map of every re-sequence; never executable contract |
| [Decision log](../documents/decision_log.md) | The append-only register of decisions that changed frozen doctrine or this plan |
| [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) | Complete authored/generated tree, dynamic resolution, and ignore/context contract |
| [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md) | The one generic runner, its gate-specification vocabulary, refusals, and the agent-run commands |
| [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) | Register-2.5 scheduling and replay discipline |
| `phase_00_*.md` … `phase_09_*.md`, `phase_50_*.md` … `phase_95_*.md` | One independently authored capability and validation contract per phase |
| [later_phases.md](later_phases.md) | In-scope work not yet assigned an integer document, including the proof-assistant track |

## Status vocabulary

The numbered plan has exactly three states: **Done**, **Active — NOT VALIDATED**, and
**Blocked — NOT VALIDATED**. The [phase model](development_plan_phase_model.md#c-status-vocabulary) defines
their exact tracker, phase, and sprint forms. There is one contiguous validation frontier in table order.

## Definition of Done

The [gate-integrity contract](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
owns acceptance. A complete qualified run must demonstrate the accepted capability through the shipped
product binary, independent expectations, runner-generated mutants, authentic observation, and
generation-2 evidence.

An accepted run emits its exact status-only patch. Only the verifier's `accept` applies that patch, one phase
per accept, and the receipt it records must reproduce under `replay`
([DL-0013](../documents/decision_log.md#dl-0013--validation-authority-is-mechanical-and-receipts-are-reproducible))).
Implementation, oracle, policy, or contract changes require the eligibility checks defined by the
[revalidation procedure](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

This documentation change is not a qualified gate run. It closes no phase and repairs no Haskell verifier.

## Transition procedure

1. The agent runs one gate serially (`--jobs=1`) with `amoebius-validate preview phase NN`, which runs the
   complete gate, prints the would-be receipt, and mints nothing.
2. The agent stops at the phase boundary and reports the preview.
3. The agent runs `amoebius-validate accept --phase NN`, which runs the gate again, records the receipt, writes
   its reproducible digest beside the Done status, and applies exactly one phase's status patch; the agent
   reports the printed Claim, specification digest, kill table, spine outcome, and corpus delta.
4. The human reads `git diff` (status lines and the receipt line only) and commits.
5. The next gate's preflight compares HEAD's status surface with the receipt's postimage and requires every
   predecessor receipt to reproduce; it refuses `StatusSurfaceDirty`, `PredecessorNotCommitted`, or
   `PredecessorNotReproduced` on any difference. A wiped store is re-established by
   `amoebius-validate replay`.

## Generation-2 reset

Certification generation 2 replaces the generation-1 validator with the custody core plus one generic runner
([DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel)).
The plan is re-sequenced into a vertical slice, Phases 3 through 9 over one growing corpus, with 10 through 49
reserved ([DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice)). The
reset started the frontier at Phase 0 with every other phase Blocked; the table below records the current frontier. Generation-1 stores are archived as historical observations
and supply no authority. The typed reset cause is
`ResetCause { validatorGap = "gates measured the harness", productGap = LTD-DSL-001 }`.

Until the reopened Phase 0 reconciles the checker, the existing documentation checker reports the reserved
gap as missing phases, the tracker and identity table as the wrong cardinality, and Phase 50's predecessor
edge as non-adjacent. Those findings are the reconciliation target of Phase 0's second sprint. The reasons
behind this reset are recorded in the decision log
([DL-0006](../documents/decision_log.md#dl-0006--the-honesty-backlog-is-struck-or-re-mooded)) and the active
divergence in the [legacy register](legacy_tracking_for_deletion.md); this tracker carries no audit narrative.

## Phase overview

The table is an order-and-status index. The linked phase document owns the phase-specific gate; every gate
also inherits the universal postcondition above.

| Phase | Name | Substrate | Lane | Register | Status | Validation contract |
|---|---|---|---|---|---|---|
| 0 | Documentation, governance, and the validation seed | none | `none` | — | ✅ Done | [Contract](phase_00_documentation_suite.md) |
| 1 | Haskell toolchain and probe-source closure | none | `none` | 2 | 🔄 Active — NOT VALIDATED | [Contract](phase_01_toolchain_spike.md) |
| 2 | Repository layout conformance and source closure | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_02_repository_layout_conformance.md) |
| 3 | The typed spine from one spec to fake-applied bytes | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_03_typed_spine.md) |
| 4 | Witness-driven manifests, capacity, and storage | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_04_witness_manifests_capacity_storage.md) |
| 5 | Substrates, lanes, rke2 quorum, and the image recipe | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_05_substrates_lanes_image_recipe.md) |
| 6 | Extension admission and attested scope | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_06_extension_admission_attested_scope.md) |
| 7 | Child clusters and obligation-indexed teardown | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_07_child_clusters_obligation_teardown.md) |
| 8 | UI program language, binding, and plans | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_08_ui_program_language_binding.md) |
| 9 | The DSL barrier through the shipped binary | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_09_dsl_barrier.md) |
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

Unnumbered future work, including the proof-assistant track that owns the parked formal checkers, remains in
[later_phases.md](later_phases.md). It is not a numbered phase, tracker row, predecessor, or validation state
until a decision-log entry assigns it an exact ordinal and contract.

## Related Documents

- [Documentation Standards](../documents/documentation_standards.md)
- [Decision Log](../documents/decision_log.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md)
