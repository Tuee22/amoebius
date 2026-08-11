# Amoebius Development Plan

> **Purpose**: Provide the authoritative numeric phase order, current status, remaining work, and routing
> to each phase's human-authored validation contract.
> **Read this if**: the current phase, the next permitted work, or the location of a phase gate must be established.

This tracker owns phase order, status, and dated implementation progress. Each phase document owns its
capability-specific validation contract, while the universal clean-tree postcondition is owned by
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
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | Mandatory deletion, relocation, and terminology migrations |
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

1. Its phase-specific acceptance command passes in the declared register and substrate.
2. Its runtime-generated surface enumeration joins completely to independently authored expectations.
3. Applicable mutants, negative controls, external observers, authority pairs, and cleanup checks pass.
4. All deliberate generated files stay under ignored output roots; source-adjacent ignored Python interpreter
   caches are the sole exception, and no other command writes beneath an authored root.
5. The tracked tree remains unchanged and no unignored generated file appears.
6. The Docker context contains no generated output, evidence, cache, dependency tree, secret, or runtime state.
7. The generated run bundle passes its schema and honesty checks.
8. An immutable external attestation verifies against the clean human-committed tree and phase contract.

Markdown never embeds the generated ledger, receipt, hash, transcript, or dependency resolution. A human
status decision may link the external run. Dirty-tree runs and prior seals cannot satisfy Done.

## Reopened numeric sequence

The 2026-08-11 generated-artifact amendment reopens phases 0–64 without renumbering them.

1. **Phase 0 is Active.** It must implement the provenance classifier, generator registry, authored-root
   write guard, generated-path scanner, ignore/context coverage, external-attestation validation, and the
   documentation lints required by the new doctrine. The existing verifier and artifact/ledger linters are
   legacy footprints: they still consume repository-resident ledgers, enumerations, and a manifest-based pin
   model, so the documented Phase-0 command is not yet the redesigned gate.
2. **Phase 1 is next and Blocked.** It must replace lock/freeze files, package/library SHA pins, fixed user
   paths, and retained generated toolchain evidence with dynamic run-local resolution.
3. **Phases 2–64 are Blocked.** In order, each phase must migrate enumeration and evidence to `gen/`,
   establish oracle provenance, adopt the authored-root write guard, rerun its capability gate, and publish
   a clean-tree external attestation.
4. **Later phases remain Planned.** They inherit the redesigned doctrine from their first authored contract.

Prior implementation and run records may guide diagnosis. They do not allow a phase to skip its reopened
gate or numeric predecessor.

## Current implementation audit

This is a static audit of the dirty working tree observed on **2026-08-11**, including committed,
uncommitted, untracked, and generated paths. It is not a clean committed baseline and does not claim semantic
completeness. Exact artifact counts and actionable mismatches live in
[legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md#existing-code-divergence-snapshot--2026-08-11).

| Phase(s) | Progress | Observed state | Required next boundary |
|---|---|---|---|
| 0 | **Known partial** | The authored redesign and complete documented Git/Docker ignore-pattern contract are present, and the artifact lint rejects missing patterns and Python cache suppression. The legacy documentation checker still passes only its old contract, while the provenance registry, authored-root guard, effective tracked-path/context audit, dynamic-resolution audit, and external-attestation path are not implemented as one current gate | Complete Sprint 0.7 and make the redesigned Phase-0 command fail every named negative before reopening Phase 1 |
| 1 | **Known partial** | Source, tests, gate, and generated evidence exist; lock/freeze files, generated bindings/evidence, a patch beneath evidence, and user-specific resolution remain | Replace fixed/retained resolution with run-local generation and pass the redesigned Phase-1 gate |
| 2–43 | **Observed footprint** | Every phase has a primary gate, tests or auxiliary tooling, generated evidence, enumeration, and ledger material; prior broad results are invalidated and semantic completeness was not re-established by this static audit | Migrate artifacts, verify oracle provenance, then rerun each current gate in numeric order |
| 44–47 | **Known partial** | Provider/AWS gate footprints exist, while the phase contracts explicitly record missing authenticated provider materialization, EBS/IAM behavior, node provisioning, audit, and leak-freedom | Complete the provider seams after predecessors close and run the live provider gates |
| 48 | **Observed footprint** | Pure and live/cache footprints exist; the prior `linux-cpu` result is invalidated by the artifact-policy amendment | Migrate and rerun the current Phase-48 gate |
| 49–58 | **Known partial** | Gate and test footprints exist; the phase records retain scoped gaps in full sibling lift, native transport, production UI/identity/provider topology, specialized hardware, cleanup, or multi-zone behavior | Close each named gap and rerun in numeric order on the required lane |
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
| 0 | Documentation suite (whole DSL) | none | — | 🔄 Active — doctrine migration | [phase_00](phase_00_documentation_suite.md) |
| 1 | Toolchain spike | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_01](phase_01_toolchain_spike.md) |
| 2 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_02](phase_02_formal_model_kernel.md) |
| 3 | Gateway-migration model (both branches) | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_03](phase_03_gateway_migration_model.md) |
| 4 | Dhall Gate-1 schema + smart-constructor prelude | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_04](phase_04_dhall_gate1_schema.md) |
| 5 | GADT-indexed IR + total decoder (Gate 2) | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_05](phase_05_gadt_decoder_gate2.md) |
| 6 | Illegal-state corpus + validation-locus ledger | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_06](phase_06_illegal_state_corpus.md) |
| 7 | Capacity core fold + topology relation | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_07](phase_07_capacity_core_folds.md) |
| 8 | Logical→physical storage geometry folds | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_08](phase_08_storage_geometry_folds.md) |
| 9 | Execution-epoch + scheduler + accelerator + provider-root folds | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_09](phase_09_execution_accelerator_folds.md) |
| 10 | Capability union + representational bind | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_10](phase_10_capability_bind.md) |
| 11 | Whole-deployment provision seal + expansion | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_11](phase_11_provision_seal.md) |
| 12 | InferenceEngine capability + accelerator provision | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_12](phase_12_inference_accelerator_provision.md) |
| 13 | Pure `renderAll` + rendered-output goldens | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_13](phase_13_render_manifest_goldens.md) |
| 14 | chain/Step kernel + `--dry-run` + boundary fake-tool harness + Gate-3 AST checker | none | 1/2 | ⏸️ Blocked by reopened numeric sequence | [phase_14](phase_14_chain_kernel_boundary.md) |
| 15 | Deterministic-simulation substrate | none | 2 | ⏸️ Blocked by reopened numeric sequence | [phase_15](phase_15_deterministic_sim_substrate.md) |
| 16 | Bounded UI-program schema | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_16](phase_16_ui_program_schema.md) |
| 17 | Scoped identity kernel | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_17](phase_17_scoped_identity_kernel.md) |
| 18 | UI authorization kernel | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_18](phase_18_ui_authorization_kernel.md) |
| 19 | UI effect binding | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_19](phase_19_ui_effect_binding.md) |
| 20 | UI plan compiler | none | 1 | ⏸️ Blocked by reopened numeric sequence | [phase_20](phase_20_ui_plan_compiler.md) |
| 21 | Generic browser interpreter | none | 2 | ⏸️ Blocked by reopened numeric sequence | [phase_21](phase_21_ui_browser_interpreter.md) |
| 22 | UI-server boundary | none | 2 | ⏸️ Blocked by reopened numeric sequence | [phase_22](phase_22_ui_server_boundary.md) |
| 23 | Local UI composition | none | 2 | ⏸️ Blocked by reopened numeric sequence | [phase_23](phase_23_ui_local_composition.md) |
| 24 | Python bootstrap coordinator + substrate detect + single kind cluster | linux-cpu | 3 | ⏸️ Blocked by reopened numeric sequence | [phase_24](phase_24_bootstrap_coordinator_kind.md) |
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
