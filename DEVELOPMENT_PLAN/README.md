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
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, DEVELOPMENT_PLAN/phase_23_extension_security_laws.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/diagram_conventions.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/low_code_ui_workflow_lifting.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_ebs_credential_model.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_schema.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/substrate_node_inventory.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/tla_modelling_assumptions.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_capability_messaging.md, documents/illegal_state/illegal_state_capacity.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_tenancy.md, documents/illegal_state/illegal_state_topology.md, documents/reading_order.md
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

amoebius is one Haskell runtime with command, host-daemon, control-plane daemon, scheduler, and worker responsibilities.
The bounded Python `pb` pre-binary handoff exists only to make the minimum platform-adapter distinction,
establish the contained Haskell toolchain, build the source-bound binary, and exec it with argv unchanged. It
does not own a public command, product decision, or validation verdict and is distinct from the Haskell
`BootstrapCoordinator` role.
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
5. A hardware gate names exactly one substrate and one lane. `apple`, `linux-cuda`, and `windows` are
   substrate members; `metal` and `cuda` are specialized capability lanes, while `provider` is a managed
   target lane. The `linux-cpu` baseline cannot substitute for a specialized claim, and one architecture
   cannot substitute for the other.
6. Register 1 is pure/semantic-oracle, Register 2 is boundary-with-fakes, and Register 3 is live. Register 2.5 is a
   deterministic-simulation activity, never a phase-gate register.
7. Missing prerequisites fail; they never skip to green. Unreached applicable layers remain UNVERIFIED.
8. Phase 49 is the complete no-hardware DSL promotion barrier and requires every `LTD-SRC-*` query,
   including the Phase-0-owned `LTD-SRC-008` boundary, to be zero. Phase 50 owns no migration and validates
   only the runtime behavior of that already-bounded handoff; Phase 51 remains a hardware-free Haskell
   host-ensure kernel. Phase 52 is the first hardware-bearing gate. No host, image, registry, cluster,
   accelerator, or cloud validation work may begin before the Phase-49 approval and the intervening numerical
   predecessor approvals exist.
9. A gate, CI job, agent, evidence reader, digest, or attestation may produce a Validation candidate only. The
   human validation authority alone may sign approval and personally change a phase or sprint to Done.

## Repository and evidence discipline

Version-controlled behavioral source is Haskell (`*.hs`) only. Python beneath `pb/**` is the sole source-code
exception and is limited to the bootstrap handoff described above. Documentation, licences, Cabal/project
metadata, ignore rules, and narrowly bounded packaging metadata are tracked inputs, not alternative product
languages. Dhall, PureScript, JavaScript, Python outside `pb/**`, shell, Proto, Pulumi, Dockerfiles,
configuration projections, fixtures, checking tools, oracle serializations, mutants, ledgers, receipts, logs,
reports, screenshots, and other executable or behavioral artifacts are generated lazily from Haskell into
`.build/**` and remain untracked.

All amoebius-owned state stays under the physical checkout. `.build/**` owns reproducible, transient, and
evidentiary output; `.data/**` owns production runtime and durable state; `.test_data/**` owns exclusively
harness-created test state. Raw candidate evidence lives in `.build/runs/**`; a content-addressed receipt may
be installed beneath `.build/evidence-store/**`. Neither has status authority. The complete
repository tree, output inventory, lifecycle rules, and normative `.gitignore`/`.dockerignore` patterns
are owned by
[repository_layout_doctrine.md](../documents/engineering/repository_layout_doctrine.md).

## Toolchain

Compilers, package tools, libraries, code generators, browsers, and transitive dependencies resolve
dynamically from authored compatibility requirements. Every clean run records the selected versions,
source identities, dependency graph, executable paths, and observed integrity data under `.build/toolchain/`
and `.build/locks/`, then binds them into repository-local evidence. No generated resolution is copied into Git.

Only the irreducible host floor is supplied by the operator; everything with a supported install path is
ensured beneath `.build/**`. The floor is checked before any requirement resolves, so an unsupported host is
named with its remedy rather than discovered as a later symptom. Every authored platform key is the canonical
`<os>-<arch>` token, and a publisher that offers no asset for the host's architecture is a refusal, never a
substitution.

## Document index

| Document | Role |
|---|---|
| [development_plan_standards.md](development_plan_standards.md) | The plan rulebook's hub: every section heading and anchor, and the document-form rules |
| [development_plan_phase_model.md](development_plan_phase_model.md) | Rulebook slice: status vocabulary, the phase model, honesty, substrate discipline, reopening and re-baselining |
| [development_plan_gate_integrity.md](development_plan_gate_integrity.md) | Rulebook slice: gate integrity, universal artifact hygiene, reconciliation, and the final repository layout |
| [overview.md](overview.md) | Target architecture and cross-cutting invariants |
| [system_components.md](system_components.md) | Target-only Haskell component-to-doctrine/phase map; never a present-tree or status ledger |
| [substrates.md](substrates.md) | Hardware/substrate registry and pristine-host routing |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | Current-tree and history divergences, owners, and closure conditions |
| [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) | Complete authored/generated tree, dynamic resolution, and ignore/context contract |
| [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) | Validation registers and boundary discipline |
| [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) | Register-2.5 scheduling and replay discipline |
| [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) | Sibling-source migration and convergence rules |
| `phase_00_*.md` … `phase_95_*.md` | One human-authored capability and validation contract per phase |
| [later_phases.md](later_phases.md) | In-scope phases not yet assigned an integer document |

## Status vocabulary

The validation reset uses only two current phase states: **🔄 Active — NOT VALIDATED** for Phase 0 and
**⏸️ Blocked — NOT VALIDATED** for Phases 1–95. `Validated` and `Done` are reserved for a future human
promotion after the redesigned, independently qualified acceptance contract is satisfied; neither is a
current status. Historical status words and symbols cannot reactivate themselves.

## Implementation-progress vocabulary

Until revalidation, the only permitted implementation classifications are **Observed footprint** and
**Known partial**. They report that files or prior run material exist; they do not establish correctness,
source-policy conformance, gate integrity, or phase completion. No digest, seal, receipt, attestation, or
previous command result promotes either classification.

## Definition of Done

A phase is Done only after all of the following occur in order:

1. Its fixed eighteen-row Gate-integrity contract has no `UNRESOLVED`, `MISSING`, skipped, implicit, or empty
   required field and has received independent oracle/reviewer acceptance.
2. Phase 0 satisfies the explicit genesis-predecessor contract declared in its phase document; every later
   phase has a valid external human approval for its exact immediate-predecessor contract.
3. The semantic source scan accounts for every tracked path and admits behavioural source only as `.hs`, with
   the bounded `pb/**` minimal-platform-discrimination, contained-toolchain-establishment,
   source-bound-build, and opaque-exec exception.
4. A fresh cleanroom run starts without generated/state roots or condemned legacy copies and lazily derives
   every required non-Haskell product beneath `.build/**`.
5. The exact Haskell harness build first rejects every qualification sabotage, then runs the clean candidate.
6. Discovery is non-empty and joins in both directions; positive controls, paired specific-reason negatives,
   applied changed-subject mutants, freshness, external observers, authority/bypass probes, and cleanup all
   produce their explicit expected observations.
7. Every legacy ID owned by the phase returns zero findings and its reintroduction negative turns red.
8. The candidate bundle contains raw per-row observations and explicit `UNVERIFIED` residue. Its digest binds
   provenance only and cannot authorize status.
9. A human validation authority reviews the source diff, contract, oracle custody, harness qualification, raw
   observations, residue, predecessor, and legacy closure; signs the external approval; and personally changes
   the tracker and phase/sprint status to Done.

Markdown never embeds or manufactures generated evidence, an approval, a hash, a transcript, or dependency
resolution. Automation and LLMs may report a Validation candidate but may not apply or claim the human
decision. A prior seal or pre-reset result can never satisfy Done. Commit timing is not a gate input
([development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate)).

## Reopened numeric sequence

**Validation reset — 2026-08-22.** Every prior phase and sprint validation claim is invalidated. Phase 0 is
**🔄 Active — NOT VALIDATED** solely for the documentation, validation, and tracked-source-boundary
redesign. Phases 1–95 are **⏸️ Blocked — NOT VALIDATED** and may advance only after their immediate
numerical predecessor has been independently validated and promoted by the human maintainer.

Existing source and historical results are retained only as **Observed footprint / Known partial** migration
input. They cannot satisfy an acceptance condition, and historical prose cannot become current through a
status change. Phase 0 now has a Haskell dispatcher whose explicit readiness findings force refusal; later
phase-specific gate commands remain planned contracts pending the comprehensive anti-spoof review. This reset
makes no claim that any gate has run or passed.

Hardware validation is frozen. No phase at or above Phase 52 may run for promotion until the hardware-free
DSL promotion barrier and every preceding redesigned phase have been independently satisfied and
human-approved.

## Current implementation audit

The current audit makes no validation attribution.

| Phase(s) | Current classification | Meaning |
|---|---|---|
| 0 | **Observed footprint / Known partial — NOT VALIDATED** | Haskell validation-kernel modules and component oracles exist. Current `pb/**` remains broadened legacy debt, and no conforming opaque public handoff is implemented. Supporting library-build and component-test diagnostics passed, but qualification, independent human review and key custody, clean-room observation, evidence integration, contract resolution, legacy closure, and human promotion remain absent. |
| 1–95 | **Observed footprint / Known partial — NOT VALIDATED** | Existing files and historical run material are migration input only; each phase is blocked behind numerical predecessor validation and human promotion. |

The 2026-08-22 inspection observed successful supporting diagnostics for
`cabal build lib:validation-kernel` and `cabal test validation-kernel-component`. These are compilation and
component observations only, never validation. The current dirty worktree is ineligible for clean snapshot
acquisition, and the dispatcher also carries explicit fail-closed findings for unexecuted qualification,
missing independent human review/key custody, missing external clean-room observation, and missing evidence
integration. The evidence schema also lacks closed typed command, toolchain, substrate, run, and cleanup
fields, and no reviewed binding connects Git object-format identity to its required SHA-256 provenance. In
addition, 93 phase contracts contain 1,290 `UNRESOLVED` gate cells and 92 `MISSING`
predecessor cells, for 1,382 fail-closed cells in total. The Phase-0
gate must refuse while any of these conditions remains.

Capability-by-capability target ownership remains in the linked phase contracts and the target-only
[system_components.md](system_components.md). Current divergences live only in the single
[legacy register](legacy_tracking_for_deletion.md). No historical digest, receipt, attestation, pass statement,
supporting diagnostic, or component result is a current validation result.

## Phase overview

The table is an order-and-status index. It is read with the dated progress audit above, not as an assertion
that a blocked phase has no code. The linked phase document owns the phase-specific gate; every gate also
inherits the universal postcondition above.

| Phase | Name | Substrate | Lane | Register | Status | Validation contract |
|---|---|---|---|---|---|---|
| 0 | Documentation, source policy, and validation trust root | none | `none` | — | 🔄 Active — NOT VALIDATED; documentation, validation, and source-boundary redesign only | [phase_0](phase_00_documentation_suite.md) |
| 1 | Haskell toolchain and probe-source closure | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 0 requires independent validation and human promotion first | [phase_1](phase_01_toolchain_spike.md) |
| 2 | Repository layout conformance and de-phased naming | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 1 requires independent validation and human promotion first | [phase_2](phase_02_repository_layout_conformance.md) |
| 3 | The artifact calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 2 requires independent validation and human promotion first | [phase_3](phase_03_artifact_calculus.md) |
| 4 | The budget calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 3 requires independent validation and human promotion first | [phase_4](phase_04_budget_calculus.md) |
| 5 | The lift calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 4 requires independent validation and human promotion first | [phase_5](phase_05_lift_calculus.md) |
| 6 | The workflow calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 5 requires independent validation and human promotion first | [phase_6](phase_06_workflow_calculus.md) |
| 7 | The evidence calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 6 requires independent validation and human promotion first | [phase_7](phase_07_evidence_calculus.md) |
| 8 | Scoped identity kernel | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 7 requires independent validation and human promotion first | [phase_8](phase_08_scope_index.md) |
| 9 | Capacity core fold + topology relation | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 8 requires independent validation and human promotion first | [phase_9](phase_09_resource_index.md) |
| 10 | Composition across the five calculi | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 9 requires independent validation and human promotion first | [phase_10](phase_10_calculus_composition.md) |
| 11 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 10 requires independent validation and human promotion first | [phase_11](phase_11_formal_model_kernel.md) |
| 12 | The amoebius explicit-state checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 11 requires independent validation and human promotion first | [phase_12](phase_12_explicit_state_checker.md) |
| 13 | The amoebius symbolic checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 12 requires independent validation and human promotion first | [phase_13](phase_13_symbolic_checker.md) |
| 14 | The amoebius refinement checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 13 requires independent validation and human promotion first | [phase_14](phase_14_refinement_checker.md) |
| 15 | The compile-fail fixture harness | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 14 requires independent validation and human promotion first | [phase_15](phase_15_compile_fail_harness.md) |
| 16 | Deterministic-simulation substrate | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 15 requires independent validation and human promotion first | [phase_16](phase_16_deterministic_sim_substrate.md) |
| 17 | Gateway-migration model (both branches) | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 16 requires independent validation and human promotion first | [phase_17](phase_17_gateway_migration_model.md) |
| 18 | DSL formal model | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 17 requires independent validation and human promotion first | [phase_18](phase_18_dsl_formal_model.md) |
| 19 | Reconcile decision core under deterministic simulation | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 18 requires independent validation and human promotion first | [phase_19](phase_19_reconcile_core_simulation.md) |
| 20 | The extension declaration | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 19 requires independent validation and human promotion first | [phase_20](phase_20_extension_declaration.md) |
| 21 | The per-extension laws L1-L5 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 20 requires independent validation and human promotion first | [phase_21](phase_21_extension_laws_per_extension.md) |
| 22 | The compositional laws C1-C7 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 21 requires independent validation and human promotion first | [phase_22](phase_22_extension_laws_compositional.md) |
| 23 | The security laws S1-S6 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 22 requires independent validation and human promotion first | [phase_23](phase_23_extension_security_laws.md) |
| 24 | The generated conformance gate | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 23 requires independent validation and human promotion first | [phase_24](phase_24_conformance_gate_generator.md) |
| 25 | Haskell-derived Dhall projection and smart-constructor prelude | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 24 requires independent validation and human promotion first | [phase_25](phase_25_dhall_schema_generation.md) |
| 26 | Haskell protocol declarations, GADT-indexed IR, and total decoder | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 25 requires independent validation and human promotion first | [phase_26](phase_26_gadt_decode_ir.md) |
| 27 | Illegal-state corpus + validation-locus ledger | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 26 requires independent validation and human promotion first | [phase_27](phase_27_illegal_state_covering.md) |
| 28 | Logical→physical storage geometry folds | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 27 requires independent validation and human promotion first | [phase_28](phase_28_storage_geometry_folds.md) |
| 29 | Execution-epoch + scheduler + accelerator + provider-root folds | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 28 requires independent validation and human promotion first | [phase_29](phase_29_execution_accelerator_folds.md) |
| 30 | Capability union + representational bind | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 29 requires independent validation and human promotion first | [phase_30](phase_30_capability_bind.md) |
| 31 | Whole-deployment provision seal + expansion | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 30 requires independent validation and human promotion first | [phase_31](phase_31_provision_seal.md) |
| 32 | InferenceEngine capability + accelerator provision | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 31 requires independent validation and human promotion first | [phase_32](phase_32_inference_accelerator_provision.md) |
| 33 | Pure `renderAll` + rendered-artifact oracles | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 32 requires independent validation and human promotion first | [phase_33](phase_33_render_manifest_oracles.md) |
| 34 | chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 33 requires independent validation and human promotion first | [phase_34](phase_34_chain_kernel_boundary.md) |
| 35 | The amoebius image recipe | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 34 requires independent validation and human promotion first | [phase_35](phase_35_image_recipe_generation.md) |
| 36 | The closed transaction vocabulary | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 35 requires independent validation and human promotion first | [phase_36](phase_36_transaction_vocabulary.md) |
| 37 | Bounded UI-program schema | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 36 requires independent validation and human promotion first | [phase_37](phase_37_ui_program_schema.md) |
| 38 | UI authorization kernel | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 37 requires independent validation and human promotion first | [phase_38](phase_38_ui_authorization_kernel.md) |
| 39 | UI effect binding | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 38 requires independent validation and human promotion first | [phase_39](phase_39_ui_effect_binding.md) |
| 40 | UI plan compiler | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 39 requires independent validation and human promotion first | [phase_40](phase_40_ui_plan_compiler.md) |
| 41 | Offline language and paired plans | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 40 requires independent validation and human promotion first | [phase_41](phase_41_offline_language_plan.md) |
| 42 | Haskell browser-interpreter semantics and projection | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 41 requires independent validation and human promotion first | [phase_42](phase_42_ui_browser_interpreter.md) |
| 43 | Haskell UI-server boundary | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 42 requires independent validation and human promotion first | [phase_43](phase_43_ui_server_boundary.md) |
| 44 | Hardware-free Haskell UI composition | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 43 requires independent validation and human promotion first | [phase_44](phase_44_ui_local_composition.md) |
| 45 | Haskell offline-state semantics and runtime projection | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 44 requires independent validation and human promotion first | [phase_45](phase_45_encrypted_browser_runtime.md) |
| 46 | Haskell-generated browser contracts and bundle | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 45 requires independent validation and human promotion first | [phase_46](phase_46_ui_contract_generation.md) |
| 47 | Foreign-source generator closure, checking tools, and mutants | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 46 requires independent validation and human promotion first | [phase_47](phase_47_tool_and_mutant_generation.md) |
| 48 | The test-workflow algebra | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 47 requires independent validation and human promotion first | [phase_48](phase_48_test_workflow_algebra.md) |
| 49 | No-hardware DSL promotion barrier + self-referential gate suite | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 48 requires independent validation and human promotion first | [phase_49](phase_49_self_referential_gates.md) |
| 50 | Bounded `pb` bootstrap + Haskell handoff | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 49 requires independent validation and human promotion first | [phase_50](phase_50_host_assert_cli.md) |
| 51 | The host-ensure kernel | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 50 requires independent validation and human promotion first | [phase_51](phase_51_host_ensure_kernel.md) |
| 52 | Linux: sudoless Docker and the native image | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 51 requires independent validation and human promotion first | [phase_52](phase_52_linux_engine_bringup.md) |
| 53 | Apple: Homebrew, Colima, and the native image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 52 requires independent validation and human promotion first | [phase_53](phase_53_apple_engine_bringup.md) |
| 54 | Windows: WSL2 and the lifted Linux engine | windows | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 53 requires independent validation and human promotion first | [phase_54](phase_54_windows_engine_bringup.md) |
| 55 | Haskell substrate coordinator + single kind cluster | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 54 requires independent validation and human promotion first | [phase_55](phase_55_bootstrap_coordinator_kind.md) |
| 56 | The base image, the jit-build resolver, and the in-cluster registry | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 55 requires independent validation and human promotion first | [phase_56](phase_56_base_image_registry.md) |
| 57 | The complementary-architecture base image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 56 requires independent validation and human promotion first | [phase_57](phase_57_complementary_arch_child.md) |
| 58 | Typed renderer + object reconciler | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 57 requires independent validation and human promotion first | [phase_58](phase_58_object_reconciler.md) |
| 59 | amoebius-capacity scheduler + bootstrap cutover | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 58 requires independent validation and human promotion first | [phase_59](phase_59_capacity_scheduler.md) |
| 60 | No-provisioner retained storage + lossless rebind | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 59 requires independent validation and human promotion first | [phase_60](phase_60_retained_storage.md) |
| 61 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 60 requires independent validation and human promotion first | [phase_61](phase_61_vault_pki.md) |
| 62 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 61 requires independent validation and human promotion first | [phase_62](phase_62_platform_backbone.md) |
| 63 | Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 62 requires independent validation and human promotion first | [phase_63](phase_63_platform_services_2.md) |
| 64 | Keycloak-owned ingress | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 63 requires independent validation and human promotion first | [phase_64](phase_64_keycloak_ingress.md) |
| 65 | Live DSL deploy via the replicas=1 control-plane daemon | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 64 requires independent validation and human promotion first | [phase_65](phase_65_live_dsl_deploy.md) |
| 66 | Tenant/provider provisioning | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 65 requires independent validation and human promotion first | [phase_66](phase_66_app_tenancy.md) |
| 67 | Native Pulsar client (CBOR) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 66 requires independent validation and human promotion first | [phase_67](phase_67_pulsar_client.md) |
| 68 | Live subject/tenant isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 67 requires independent validation and human promotion first | [phase_68](phase_68_user_tenant_isolation_live.md) |
| 69 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 68 requires independent validation and human promotion first | [phase_69](phase_69_content_store_workflow.md) |
| 70 | Owner-scoped UI projection runtime | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 69 requires independent validation and human promotion first | [phase_70](phase_70_ui_projection_runtime.md) |
| 71 | Release lifecycle | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 70 requires independent validation and human promotion first | [phase_71](phase_71_release_lifecycle.md) |
| 72 | Atomic immutable UI-program release | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 71 requires independent validation and human promotion first | [phase_72](phase_72_ui_program_release.md) |
| 73 | WireGuard network fabric | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 72 requires independent validation and human promotion first | [phase_73](phase_73_network_fabric_wireguard.md) |
| 74 | Multi-cluster spawn + geo-replication | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 73 requires independent validation and human promotion first | [phase_74](phase_74_multicluster_spawn_georepl.md) |
| 75 | Gateway-migration drills + model-correspondence | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 74 requires independent validation and human promotion first | [phase_75](phase_75_gateway_migration_drills.md) |
| 76 | Haskell-derived provider Pulumi program and enveloped checkpoint | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 75 requires independent validation and human promotion first | [phase_76](phase_76_provider_deploy_checkpoint.md) |
| 77 | Hostless provider child + convergence + Lease handoff | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 76 requires independent validation and human promotion first | [phase_77](phase_77_provider_child_bringup.md) |
| 78 | Per-PV EBS decoupling + create-vs-delete credential | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 77 requires independent validation and human promotion first | [phase_78](phase_78_provider_ebs_credential.md) |
| 79 | Dynamic node provisioning by signal + leak-free provider gate | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 78 requires independent validation and human promotion first | [phase_79](phase_79_provider_dynamic_nodes.md) |
| 80 | Determinism kernel + jit-build CacheBudget cache | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 79 requires independent validation and human promotion first | [phase_80](phase_80_determinism_jitcache.md) |
| 81 | Single-tenant low-code UI live path | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 80 requires independent validation and human promotion first | [phase_81](phase_81_ui_single_tenant_live.md) |
| 82 | Multi-tenant low-code UI isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 81 requires independent validation and human promotion first | [phase_82](phase_82_ui_multi_tenant_live.md) |
| 83 | UI rollout, projection catch-up, and reconnect | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 82 requires independent validation and human promotion first | [phase_83](phase_83_ui_rollout_reconnect.md) |
| 84 | Initial online UI multi-zone high availability | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 83 requires independent validation and human promotion first | [phase_84](phase_84_ui_ha_multizone.md) |
| 85 | Offline replay and durable receipts | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 84 requires independent validation and human promotion first | [phase_85](phase_85_offline_replay_receipts.md) |
| 86 | Offline blobs and partition isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 85 requires independent validation and human promotion first | [phase_86](phase_86_offline_blobs_isolation.md) |
| 87 | Offline release and schema evolution | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 86 requires independent validation and human promotion first | [phase_87](phase_87_offline_release_evolution.md) |
| 88 | Offline multi-zone continuity | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 87 requires independent validation and human promotion first | [phase_88](phase_88_offline_multizone_continuity.md) |
| 89 | Apple-Metal host compute daemon | apple | `metal` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 88 requires independent validation and human promotion first | [phase_89](phase_89_apple_metal_host_daemon.md) |
| 90 | The live test topology and elevated harness | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 89 requires independent validation and human promotion first | [phase_90](phase_90_test_topology_live.md) |
| 91 | The infernix inference core, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 90 requires independent validation and human promotion first | [phase_91](phase_91_infernix_rederivation.md) |
| 92 | The infernix workflow and artifact contracts, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 91 requires independent validation and human promotion first | [phase_92](phase_92_infernix_ui_rederivation.md) |
| 93 | The jitML numerical core, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 92 requires independent validation and human promotion first | [phase_93](phase_93_jitml_rederivation.md) |
| 94 | The jitML training and checkpoint contracts, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 93 requires independent validation and human promotion first | [phase_94](phase_94_jitml_ui_rederivation.md) |
| 95 | The multi-tenant web application re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED; redesigned Phase 94 requires independent validation and human promotion first | [phase_95](phase_95_webapp_rederivation.md) |
| 96+ | Later phases | varies | varies | — | 📋 Planned — NOT VALIDATED | [later_phases](later_phases.md) |

## Related Documents

- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md)
