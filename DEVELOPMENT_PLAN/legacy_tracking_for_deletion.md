# Legacy Tracking for Deletion

> **Purpose**: Record every repository artifact, generated-output practice, obsolete term, and sibling-project
> surface that the amoebius convergence must delete, relocate, or replace, with an owning phase and closure
> condition.
> **Read this if**: an artifact of the earlier planning approach turns up and its status has to be settled.

This document lists material retained only until its replacement lands, so that a reader meeting it elsewhere
can tell it is migration input rather than current doctrine. It owns deletion and relocation bookkeeping, not
design or phase status. Current status belongs to [README.md](README.md); artifact placement belongs to
[`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md), and doctrine
routing belongs to the [documentation index](../documents/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, README.md, documents/documentation_standards.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Ledger Status](#ledger-status)
- [Generative re-baseline — 2026-08-19](#generative-re-baseline--2026-08-19)
- [Host-band re-baseline — 2026-08-18](#host-band-re-baseline--2026-08-18)
- [Phase re-baseline — 2026-08-17](#phase-re-baseline--2026-08-17)
- [Pre-implementation Phase Re-baseline — 2026-08-01](#pre-implementation-phase-re-baseline--2026-08-01)
- [Superseded records, moved to the archive slice](#superseded-records-moved-to-the-archive-slice)
- [Pending Removal](#pending-removal)
- [Notes](#notes)
- [Related Documents](#related-documents)

---

## Ledger Status

🔄 **Active through Phase 33.** The repository contains implementation and generated migration material. The
2026-08-15 containment amendment reopened phases 0–63, and the 2026-08-16 natural-architecture
amendment reopened every phase again and renumbered old 26–64 to 27–65. No row closes merely because a file is absent locally;
the owning phase must enforce the replacement against its source snapshot and verify repository-local evidence.

**Phase 2 closed the positional class on 2026-08-17**, which is the largest single reduction this ledger has
recorded: the deferral total falls from 876 to 314, and every `r13` and `r15` row is deleted rather than
re-owned. What remains is the *deletion* class — generated output still written beneath an authored root, host
state still escaping the checkout, and expectation tables whose provenance their owning phase must establish —
plus the behavioural halves the rows below now name explicitly.

Where a row leans on the sibling prodbox/infernix/jitML system as justification, that is **evidence from a sibling system, not proof in amoebius** (the honesty rule, [development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

```mermaid
flowchart LR
  %% register: orientation
  div["an observed divergence"]
  row["a row here, with an owner and a closure condition"]
  defer["a deferral the audit reports and attributes"]
  close["the owning phase clears it, in numeric order"]
  stale["a row matching nothing fails the audit"]
  div -->|"is recorded as"| row
  row -->|"justifies"| defer
  defer -->|"is reported at every run until"| close
  close -->|"retires the row, because"| stale
```
*Orientation. The deferral list can only shrink, so the target tree is reached exactly when it empties; [development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate) clause 5 owns the deferral mechanism.*

---

## Generative re-baseline — 2026-08-19

The plan sequenced a closed DSL that lifted its sibling projects. The doctrine no longer says that: amoebius is
an **open core** whose lawful instances are domains and hardware substrates, it depends on no seed project, and
every artifact that is not Haskell source is generated from Haskell types. Twenty-one phases are inserted for
the capabilities that had no owner — the five calculi, the two indices, the proof stack amoebius owns, the
extension contract, and the generative classes — one phase splits into a pure half and a live half, and the
sequence is re-ordered so that **the algebra precedes every instance of it**. The count goes from 75 to 96.

**Order of operations.** The tree does not move. The rename, the reference sweep, the tracker, the three
phase-to-ordinal joins, and this map land together, because check `u3` derives its slug-to-ordinal map from the
filenames on disk: no rename can precede the sweep and no sweep can precede the rename. References were
resolved **through the slug**, which [§J](development_plan_standards.md#j-cross-reference-path-rules) makes
the injective key — mapping an ordinal through an ordinal reproduces whatever staleness the input carried,
which is how the two previous re-baselines left stale ordinals behind. The map below is exhaustive over
`0..95`, so a missing row is visible by counting.

**Every phase is reopened.** The re-baseline changes what the gates cover — the Dhall schema becomes generated,
byte goldens become semantic oracles, teardown becomes a type obligation, and the proof stack changes — so no
prior seal survives it. Sealed capability evidence stands as history and stops presenting completion evidence,
per [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase). Phases 3 and 4 of the old sequence
were green on 2026-08-19 and are reopened with the rest: their host capability is unaffected, but a host gate
under the lift calculus is not the gate they passed.

### The audit map

| new id | new path | old id | old path | why it moved |
|--------|----------|--------|----------|--------------|
| 0 | `phase_00_documentation_suite.md` | 0 | `phase_00_documentation_suite.md` | unmoved — band 0 opens the sequence and nothing below the algebra shifts |
| 1 | `phase_01_toolchain_spike.md` | 1 | `phase_01_toolchain_spike.md` | unmoved — band 0 opens the sequence and nothing below the algebra shifts |
| 2 | `phase_02_repository_layout_conformance.md` | 2 | `phase_02_repository_layout_conformance.md` | unmoved — band 0 opens the sequence and nothing below the algebra shifts |
| 3 | `phase_03_artifact_calculus.md` | — | — | **new.** A calculus of the core algebra that no phase owned; the algebra is pure, so it precedes every instance of it |
| 4 | `phase_04_budget_calculus.md` | — | — | **new.** A calculus of the core algebra that no phase owned; the algebra is pure, so it precedes every instance of it |
| 5 | `phase_05_lift_calculus.md` | — | — | **new.** A calculus of the core algebra that no phase owned; the algebra is pure, so it precedes every instance of it |
| 6 | `phase_06_workflow_calculus.md` | — | — | **new.** A calculus of the core algebra that no phase owned; the algebra is pure, so it precedes every instance of it |
| 7 | `phase_07_evidence_calculus.md` | — | — | **new.** A calculus of the core algebra that no phase owned; the algebra is pure, so it precedes every instance of it |
| 8 | `phase_08_scope_index.md` | 26 | `phase_26_scoped_identity_kernel.md` | reshaped and moved into the algebra. `scoped_identity_kernel` becomes the **scope index**: the tenant is skolemised rather than named, so it is a type-level construct the UI schema is indexed by. Its edge to the UI program schema reverses |
| 9 | `phase_09_resource_index.md` | 14 | `phase_14_capacity_core_folds.md` | reshaped and moved into the algebra. `capacity_core_folds` becomes the **resource index**. It is pure Haskell, and the Dhall schema and decoder are generated from it, so its edges to both reverse |
| 10 | `phase_10_calculus_composition.md` | — | — | **new.** A calculus of the core algebra that no phase owned; the algebra is pure, so it precedes every instance of it |
| 11 | `phase_11_formal_model_kernel.md` | 9 | `phase_09_formal_model_kernel.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 12 | `phase_12_explicit_state_checker.md` | — | — | **new.** An amoebius-owned explicit-state checker, so a recorded proof cannot be invalidated by another project's release |
| 13 | `phase_13_symbolic_checker.md` | — | — | **new.** The symbolic checker: the same `Model`, discharged to a solver rather than enumerated |
| 14 | `phase_14_refinement_checker.md` | — | — | **new.** The refinement checker, putting the obligations on the functions rather than on the abstraction |
| 15 | `phase_15_compile_fail_harness.md` | — | — | **new.** The compile-fail harness every unrepresentability claim needs |
| 16 | `phase_16_deterministic_sim_substrate.md` | 22 | `phase_22_deterministic_sim_substrate.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 17 | `phase_17_gateway_migration_model.md` | 10 | `phase_10_gateway_migration_model.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 18 | `phase_18_dsl_formal_model.md` | 23 | `phase_23_dsl_formal_model.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 19 | `phase_19_reconcile_core_simulation.md` | 24 | `phase_24_reconcile_core_simulation.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 20 | `phase_20_extension_declaration.md` | — | — | **new.** The extension declaration: one component per calculus, inspectable before anything runs |
| 21 | `phase_21_extension_laws_per_extension.md` | — | — | **new.** L1–L5 discharged mechanically |
| 22 | `phase_22_extension_laws_compositional.md` | — | — | **new.** C1–C7 and the link-time union closure argument |
| 23 | `phase_23_extension_security_laws.md` | — | — | **new.** S1–S6, the laws under which an insecure state stops being representable |
| 24 | `phase_24_conformance_gate_generator.md` | — | — | **new.** The generated gate and the verdict seal that admits an extension to a link set |
| 25 | `phase_25_dhall_schema_generation.md` | 11 | `phase_11_dhall_typecheck_schema.md` | renamed and inverted. The schema is no longer authored: it is reflected from the Haskell checked-IR types, so schema and decoder cannot disagree |
| 26 | `phase_26_gadt_decode_ir.md` | 12 | `phase_12_gadt_decode_ir.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 27 | `phase_27_illegal_state_covering.md` | 13 | `phase_13_illegal_state_corpus.md` | renamed. The corpus becomes a **covering** over a declared taxonomy, with the grid generated and the entries authored |
| 28 | `phase_28_storage_geometry_folds.md` | 15 | `phase_15_storage_geometry_folds.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 29 | `phase_29_execution_accelerator_folds.md` | 16 | `phase_16_execution_accelerator_folds.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 30 | `phase_30_capability_bind.md` | 17 | `phase_17_capability_bind.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 31 | `phase_31_provision_seal.md` | 18 | `phase_18_provision_seal.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 32 | `phase_32_inference_accelerator_provision.md` | 19 | `phase_19_inference_accelerator_provision.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 33 | `phase_33_render_manifest_oracles.md` | 20 | `phase_20_render_manifest_goldens.md` | renamed. Byte goldens of generated output are replaced by **semantic oracles**, because the artifact address already detects a byte change |
| 34 | `phase_34_chain_kernel_boundary.md` | 21 | `phase_21_chain_kernel_boundary.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 35 | `phase_35_image_recipe_generation.md` | 5 | `phase_05_amoebius_image_recipe.md` | moved into the generative surface and renamed. The recipe is a total function of the bake catalog and needs no host, so its edge to the host-ensure kernel dissolves |
| 36 | `phase_36_transaction_vocabulary.md` | — | — | **new.** P1–P6: the relational data plane as a closed transaction vocabulary |
| 37 | `phase_37_ui_program_schema.md` | 25 | `phase_25_ui_program_schema.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 38 | `phase_38_ui_authorization_kernel.md` | 27 | `phase_27_ui_authorization_kernel.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 39 | `phase_39_ui_effect_binding.md` | 28 | `phase_28_ui_effect_binding.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 40 | `phase_40_ui_plan_compiler.md` | 29 | `phase_29_ui_plan_compiler.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 41 | `phase_41_offline_language_plan.md` | 30 | `phase_30_offline_language_plan.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 42 | `phase_42_ui_browser_interpreter.md` | 31 | `phase_31_ui_browser_interpreter.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 43 | `phase_43_ui_server_boundary.md` | 32 | `phase_32_ui_server_boundary.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 44 | `phase_44_ui_local_composition.md` | 33 | `phase_33_ui_local_composition.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 45 | `phase_45_encrypted_browser_runtime.md` | 34 | `phase_34_encrypted_browser_runtime.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 46 | `phase_46_ui_contract_generation.md` | — | — | **new.** Browser contracts, codecs and the one bundle become recipes |
| 47 | `phase_47_tool_and_mutant_generation.md` | — | — | **new.** The checking tools and the mutant corpus emitted from the declarations they check |
| 48 | `phase_48_test_workflow_algebra.md` | 62 | `phase_62_test_topology_dsl.md` | **split A.** The topology as pure workflow values, Register 1. Its live half is Phase 90 |
| 49 | `phase_49_self_referential_gates.md` | — | — | **new.** amoebius's own gates expressed as workflow values |
| 50 | `phase_50_host_assert_cli.md` | 3 | `phase_03_host_assert_cli.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 51 | `phase_51_host_ensure_kernel.md` | 4 | `phase_04_host_ensure_kernel.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 52 | `phase_52_linux_engine_bringup.md` | 6 | `phase_06_linux_engine_bringup.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 53 | `phase_53_apple_engine_bringup.md` | 7 | `phase_07_apple_engine_bringup.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 54 | `phase_54_windows_engine_bringup.md` | 8 | `phase_08_windows_engine_bringup.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 55 | `phase_55_bootstrap_coordinator_kind.md` | 35 | `phase_35_bootstrap_coordinator_kind.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 56 | `phase_56_base_image_registry.md` | 36 | `phase_36_base_image_registry.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 57 | `phase_57_complementary_arch_child.md` | 73 | `phase_73_complementary_arch_child.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 58 | `phase_58_object_reconciler.md` | 37 | `phase_37_object_reconciler.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 59 | `phase_59_capacity_scheduler.md` | 38 | `phase_38_capacity_scheduler.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 60 | `phase_60_retained_storage.md` | 39 | `phase_39_retained_storage.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 61 | `phase_61_vault_pki.md` | 40 | `phase_40_vault_pki.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 62 | `phase_62_platform_backbone.md` | 41 | `phase_41_platform_backbone.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 63 | `phase_63_platform_services_2.md` | 42 | `phase_42_platform_services_2.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 64 | `phase_64_keycloak_ingress.md` | 43 | `phase_43_keycloak_ingress.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 65 | `phase_65_live_dsl_deploy.md` | 44 | `phase_44_live_dsl_deploy.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 66 | `phase_66_app_tenancy.md` | 45 | `phase_45_app_tenancy.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 67 | `phase_67_pulsar_client.md` | 46 | `phase_46_pulsar_client.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 68 | `phase_68_user_tenant_isolation_live.md` | 47 | `phase_47_user_tenant_isolation_live.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 69 | `phase_69_content_store_workflow.md` | 48 | `phase_48_content_store_workflow.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 70 | `phase_70_ui_projection_runtime.md` | 49 | `phase_49_ui_projection_runtime.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 71 | `phase_71_release_lifecycle.md` | 50 | `phase_50_release_lifecycle.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 72 | `phase_72_ui_program_release.md` | 51 | `phase_51_ui_program_release.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 73 | `phase_73_network_fabric_wireguard.md` | 52 | `phase_52_network_fabric_wireguard.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 74 | `phase_74_multicluster_spawn_georepl.md` | 53 | `phase_53_multicluster_spawn_georepl.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 75 | `phase_75_gateway_migration_drills.md` | 54 | `phase_54_gateway_migration_drills.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 76 | `phase_76_provider_deploy_checkpoint.md` | 55 | `phase_55_provider_deploy_checkpoint.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 77 | `phase_77_provider_child_bringup.md` | 56 | `phase_56_provider_child_bringup.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 78 | `phase_78_provider_ebs_credential.md` | 57 | `phase_57_provider_ebs_credential.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 79 | `phase_79_provider_dynamic_nodes.md` | 58 | `phase_58_provider_dynamic_nodes.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 80 | `phase_80_determinism_jitcache.md` | 59 | `phase_59_determinism_jitcache.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 81 | `phase_81_ui_single_tenant_live.md` | 63 | `phase_63_ui_single_tenant_live.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 82 | `phase_82_ui_multi_tenant_live.md` | 64 | `phase_64_ui_multi_tenant_live.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 83 | `phase_83_ui_rollout_reconnect.md` | 65 | `phase_65_ui_rollout_reconnect.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 84 | `phase_84_ui_ha_multizone.md` | 66 | `phase_66_ui_ha_multizone.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 85 | `phase_85_offline_replay_receipts.md` | 67 | `phase_67_offline_replay_receipts.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 86 | `phase_86_offline_blobs_isolation.md` | 68 | `phase_68_offline_blobs_isolation.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 87 | `phase_87_offline_release_evolution.md` | 69 | `phase_69_offline_release_evolution.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 88 | `phase_88_offline_multizone_continuity.md` | 70 | `phase_70_offline_multizone_continuity.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 89 | `phase_89_apple_metal_host_daemon.md` | 74 | `phase_74_apple_metal_host_daemon.md` | shift only — displaced by the algebra, the proof stack and the extension contract taking the head of the sequence |
| 90 | `phase_90_test_topology_live.md` | — | — | **new — split B of old 62.** The elevated harness and the live self-tearing-down topology, Register 3. It cannot precede the platform it exercises |
| 91 | `phase_91_infernix_rederivation.md` | 60 | `phase_60_infernix_lift.md` | renamed. A lift becomes a **re-derivation**: amoebius depends on no seed and re-derives the structure under its own obligations |
| 92 | `phase_92_infernix_ui_rederivation.md` | 61 | `phase_61_infernix_ui_lift.md` | renamed, for the reason Phase 91 records |
| 93 | `phase_93_jitml_rederivation.md` | 71 | `phase_71_jitml_lift_cuda.md` | renamed, for the reason Phase 91 records |
| 94 | `phase_94_jitml_ui_rederivation.md` | 72 | `phase_72_jitml_ui_lift.md` | renamed, for the reason Phase 91 records |
| 95 | `phase_95_webapp_rederivation.md` | — | — | **new.** The web seed re-derived as a conforming extension; the insecure states its survey found representable are foreclosed by S1–S6 |

### Three dependency edges reverse

[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)-3 requires that every artifact a gate
names is delivered at or below its own number. Three edges reverse under the generative turn, and each is
recorded here rather than silently edited:

| edge | was | is | why |
|------|-----|----|-----|
| resource index → Dhall schema and decoder | old 14 depended on old 11 and 12 | new 25 and 26 depend on new 9 | the index is pure Haskell and the schema is reflected **from** it |
| scope index → UI program schema | old 26 depended on old 25 | new 37 depends on new 8 | the scope index is the type-level construct the UI schema is indexed **by** |
| image recipe → host-ensure kernel | old 5 depended on old 4 | no edge | under the artifact calculus the recipe is a total function of the bake catalog and needs no host |

### Rejected, with reason

| # | proposal | not adopted, because |
|---|----------|----------------------|
| G1 | keeping the ordinals frozen and treating bands as a reading aid | it buys a smaller change and loses the property the re-baseline exists for: [§E](development_plan_phase_model.md#e-one-canonical-phase-model)'s contiguous `0..N` is the plan's only ordering statement, so a band order that contradicts it makes numeric order meaningless |
| G2 | inserting the new band at 9 and leaving 0–8 untouched | it preserves two seals and inverts the thesis: the host band would precede the algebra that specifies it, which is [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)-2 — a later phase requiring an earlier deliverable to be shaped differently |
| G3 | per-candidate provisional ordinals in `later_phases.md` | the tail now opens at 96 and ten candidates would run past 99, which no ordinal check in the suite can express; the candidates are unscheduled, so they name the tail rather than a number |
| G4 | rewriting the 102 band-range expressions mechanically | an old contiguous range maps to a non-contiguous new set — old `Phases 11–20` splits because old 14 becomes 9 — so every range is re-derived by hand or recorded below as owed |

### Still open after this change

| item | owner | closure condition |
|------|-------|-------------------|
| 58 band-range expressions still carrying pre-re-baseline ordinals — 31 inside phase contracts, 27 in `documents/` doctrine prose | each owning phase, and Phase 0 for the doctrine prose | each range re-derived from the new sequence, or restated as a band name that carries no ordinal. Every normative surface is now done and checked: [§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)'s bands, diagram and register cut, [§L](development_plan_phase_model.md#l-one-substrate-discipline)'s four named forms, `substrates.md`'s preamble and per-phase table, and the README's phase overview and implementation audit, each re-derived from the phase documents and held there by `d8` |
| the [§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed) band diagram and [§L](development_plan_phase_model.md#l-one-substrate-discipline)'s four named ordinal forms | Phase 0 | **done.** Re-derived against the nine bands and the 51/52 register cut, and now read by `phase_contract_lint`'s `d8`, which recomputes every band, register and substrate claim the plan states about itself from the contracts |
| 96 phase contracts still carrying their pre-re-baseline sprint bodies | each phase | sprint bodies rewritten with an amended gate, as that phase opens. The [§D](development_plan_standards.md#d-the-per-phase-document-skeleton) surface is already re-authored and checked: every contract carries a Phase scope that says something its Purpose does not (`d5`), a [§M](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause-13 discharge or an explicit not-applicable (`d6`), no surviving completion marker (`d7`), and a dependency edge naming what it actually consumes |
| 27 gates whose acceptance still rests on a byte golden of generated output — phases 11, 16, 17, 19, 30, 32, 34, 35, 37, 48, 55, 58, 59, 60, 61, 62, 63, 64, 67, 69, 72, 73, 78, 80, 91, 92, 94 | each phase | the golden is replaced by a semantic oracle asserting the property it stood in for; the address already detects a byte change, so the comparison is redundant as well as weak |
| 20 gates still taking committed Dhall as an authored input — phases 25, 27, 30, 31, 32, 48, 65, 72, 73, 75, 76, 77, 78, 79, 80, 89, 91, 92, 93, 94 | each phase | the schema, prelude and positive corpus are reflected from the Haskell types; only the expectation stays authored |
| the 21 inserted phases have one sprint each | each phase | sprint seams drawn when the phase opens |
| a library sharing `hs-source-dirs: src` with a sibling it also depends on does not build: GHC resolves the import to the home source file and recompiles the sibling's modules without the sibling's dependencies | each owning phase | the shared source root is split, or the depended-on module moves to a root only its own library names. Observed 2026-08-20 on `release-lifecycle`, which fails at `Amoebius.Store.ContentAddress` against an unmodified tree; the pattern also holds for `workflow-runtime`, `infernix`, `infernix-ui`, `jitml`, `jitml-ui` and `offline-runtime`. Nothing reported it because Phase 1 builds only the representative set, deliberately, and a `--dry-run` resolves without compiling |
| two renderings of a content address — [`Amoebius.Calculus.Artifact.Address`](../src/Amoebius/Calculus/Artifact/Address.hs) and `Amoebius.Store.ContentAddress` | the store's phase | the store's rendering is re-derived from the calculus's. Phase 3 could not simply reuse it: the calculus is the bottom of the stack and the store sits above it, so the dependency would invert the layers, and the row above blocks the reuse mechanically as well |
| 11 catalogue cells are *unknown* rather than empty, and the entry tags that would settle them | Phase 0 | **done, 2026-08-20.** Every entry now pairs each foreclosure to the locus that catches it on an authored `Cells:` line, so `tools/covering_grid.py` measures occupancy instead of crediting the product of the tags a prose paragraph mentions: 143 credited cells resolve to the 64 the entries assert, the eleven unknowns resolve into occupied, inadmissible and justified, and the over-crediting note retires. The layer-to-locus admissibility relation is authored in the catalog router beside the axes, the layer becomes a column of `locus_registry.tsv` so the Phase-27 fixture ledger cannot claim a cell the catalog does not, and `c1`–`c4` with six seeded defects decide the whole of it |

### What this change does not perform

It renames no source file and moves no directory. It edits `tools/` in three respects — each gate's `CONTRACT`
constant, each gate's `PhaseGate(phase=...)` run-partition key, and the `owner_phase` bound of the
locus-registry lint — because [§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3
makes the phase document's filename the one sanctioned place an ordinal appears and names that single constant
as the only place a generated path may learn a phase. Both were re-derived from each gate's own contract path,
which incidentally corrected several that already disagreed with their contract before this change.

Three gates were re-run to confirm they still execute against their moved contracts, and all three reach their
prior result. Those runs wrote attestations into the evidence store, as any gate run does. **No phase's status
changes because of them**: the re-baseline reopened every phase, the tracker carries no ✅, and a passing run
against a superseded contract is an observed footprint rather than completion evidence
([§C](development_plan_standards.md#c-status-vocabulary)).

### The condemned corpus

The generative turn condemns every tracked artifact that is a rendering of something amoebius already holds.
Each row's owner is the phase whose gate must clear it, never a later one.

| condemned | owner | closure condition |
|-----------|-------|-------------------|
| the tracked `dhall/**` corpus — schemas, prelude, examples, catalogs | Phase 25 | the schema is reflected from the Haskell checked-IR types and rendered to `.build/dhall/`; nothing under `dhall/` is tracked |
| `tools/**` checking tools | Phase 47 | each tool is emitted from the declaration it checks; an independently authored oracle moves to `test/oracle/**` |
| `tools/phase_contract_lint.py`, authored 2026-08-20 to check what a contract promises | Phase 47 | emitted from the section-D skeleton and the registries it joins; it exists because no tool read the contract half, and it retires into a recipe with the rest of `tools/**` |
| the tracked mutant corpus | Phase 47 | mutants are rendered from positive seeds and declared operators into `.build/test-corpora/**` |
| the committed byte golden of the rendered container recipe | Phase 35 | replaced by a semantic oracle over the rendered content; the address already detects a byte change |
| `proto/**` | Phase 26 | the wire schema is rendered from the message types to `.build/proto/` |
| `ui/**` emitted contracts, codecs and bundle | Phase 46 | rendered to `.build/ui/`; the generic interpreter's own source moves under `src/**` |
| `pulumi/**` | Phase 58 | rendered from the typed provider declarations to `.build/pulumi/` |
| `src/Infernix/**` squatting an upstream namespace | Phase 91 | re-derived under `Amoebius.*`; amoebius links no seed module |
| the seed `source-repository-package` entries in `cabal.project` | Phase 91 | removed; amoebius depends on no seed project |
| `Role.dhall`, named in the target tree and absent from it | Phase 25 | the role vocabulary is a Haskell type and its Dhall projection is generated |

---

## Host-band re-baseline — 2026-08-18

Six phases are inserted at 3 and the rest shift by six; phases 0–2 do not move. The band they form is the
plan's one deliberate departure from validating the DSL before implementing host logic, and it has a closure
condition rather than a precedent: the rule is not executable until the thing that executes it exists, and
nothing outside the critical path from a bare host to a built image belongs to these six.

**Order of operations.** The tree does not move in this change. No path outside the plan suite names a phase,
so this is the documentation act and it lands as one commit: check `u3` derives its slug-to-ordinal map from
the filenames on disk, so no rename can precede the reference sweep and no sweep can precede the rename.
Until phases 3–8 run, every statement in a later phase describing a host as already prepared is a divergence
this table owns rather than a defect in that phase.

### The audit map

| new id | new path | old id | old path | why it moved |
|--------|----------|--------|----------|--------------|
| 0 | `phase_00_documentation_suite.md` | 0 | `phase_00_documentation_suite.md` | unmoved — the inserted band opens at 3, below which nothing shifts |
| 1 | `phase_01_toolchain_spike.md` | 1 | `phase_01_toolchain_spike.md` | unmoved — the inserted band opens at 3, below which nothing shifts |
| 2 | `phase_02_repository_layout_conformance.md` | 2 | `phase_02_repository_layout_conformance.md` | unmoved — the inserted band opens at 3, below which nothing shifts |
| 3 | `phase_03_host_assert_cli.md` | — | — | **new.** The pre-binary host assertions had no owner: [`substrate_doctrine.md` §6](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) stated the coordinator contract and the first phase to gate any part of it sat 26 phases after the first host is touched |
| 4 | `phase_04_host_ensure_kernel.md` | — | — | **new.** The post-handoff ensure surface was specified per substrate inside unrelated phases; one closed substrate-indexed algebra makes the cross-substrate branch unrepresentable |
| 5 | `phase_05_amoebius_image_recipe.md` | — | — | **new.** "The recipe does not change as the remaining Haskell lands" is a claim only a sealed golden can hold, and it had no owning gate |
| 6 | `phase_06_linux_engine_bringup.md` | — | — | **new.** The bootstrap phase assumed a guest with a container runtime already present; nothing gated the step that installs it |
| 7 | `phase_07_apple_engine_bringup.md` | — | — | **new.** `apple` was gated only at phases the 2026-08-17 re-baseline moved to the tail, leaving the Apple host floor itself ungated |
| 8 | `phase_08_windows_engine_bringup.md` | — | — | **new.** `windows` was a declared catalog member no phase gated; [§L](development_plan_phase_model.md#l-one-substrate-discipline)'s own sentence saying so is retracted by this change |
| 9 | `phase_09_formal_model_kernel.md` | 3 | `phase_03_formal_model_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 10 | `phase_10_gateway_migration_model.md` | 4 | `phase_04_gateway_migration_model.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 11 | `phase_11_dhall_typecheck_schema.md` | 5 | `phase_05_dhall_typecheck_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 12 | `phase_12_gadt_decode_ir.md` | 6 | `phase_06_gadt_decode_ir.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 13 | `phase_13_illegal_state_corpus.md` | 7 | `phase_07_illegal_state_corpus.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 14 | `phase_14_capacity_core_folds.md` | 8 | `phase_08_capacity_core_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 15 | `phase_15_storage_geometry_folds.md` | 9 | `phase_09_storage_geometry_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 16 | `phase_16_execution_accelerator_folds.md` | 10 | `phase_10_execution_accelerator_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 17 | `phase_17_capability_bind.md` | 11 | `phase_11_capability_bind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 18 | `phase_18_provision_seal.md` | 12 | `phase_12_provision_seal.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 19 | `phase_19_inference_accelerator_provision.md` | 13 | `phase_13_inference_accelerator_provision.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 20 | `phase_20_render_manifest_goldens.md` | 14 | `phase_14_render_manifest_goldens.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 21 | `phase_21_chain_kernel_boundary.md` | 15 | `phase_15_chain_kernel_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 22 | `phase_22_deterministic_sim_substrate.md` | 16 | `phase_16_deterministic_sim_substrate.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 23 | `phase_23_dsl_formal_model.md` | 17 | `phase_17_dsl_formal_model.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 24 | `phase_24_reconcile_core_simulation.md` | 18 | `phase_18_reconcile_core_simulation.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 25 | `phase_25_ui_program_schema.md` | 19 | `phase_19_ui_program_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 26 | `phase_26_scoped_identity_kernel.md` | 20 | `phase_20_scoped_identity_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 27 | `phase_27_ui_authorization_kernel.md` | 21 | `phase_21_ui_authorization_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 28 | `phase_28_ui_effect_binding.md` | 22 | `phase_22_ui_effect_binding.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 29 | `phase_29_ui_plan_compiler.md` | 23 | `phase_23_ui_plan_compiler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 30 | `phase_30_offline_language_plan.md` | 24 | `phase_24_offline_language_plan.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 31 | `phase_31_ui_browser_interpreter.md` | 25 | `phase_25_ui_browser_interpreter.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 32 | `phase_32_ui_server_boundary.md` | 26 | `phase_26_ui_server_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 33 | `phase_33_ui_local_composition.md` | 27 | `phase_27_ui_local_composition.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 34 | `phase_34_encrypted_browser_runtime.md` | 28 | `phase_28_encrypted_browser_runtime.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 35 | `phase_35_bootstrap_coordinator_kind.md` | 29 | `phase_29_bootstrap_coordinator_kind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 36 | `phase_36_base_image_registry.md` | 30 | `phase_30_base_image_registry.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 37 | `phase_37_object_reconciler.md` | 31 | `phase_31_object_reconciler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 38 | `phase_38_capacity_scheduler.md` | 32 | `phase_32_capacity_scheduler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 39 | `phase_39_retained_storage.md` | 33 | `phase_33_retained_storage.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 40 | `phase_40_vault_pki.md` | 34 | `phase_34_vault_pki.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 41 | `phase_41_platform_backbone.md` | 35 | `phase_35_platform_backbone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 42 | `phase_42_platform_services_2.md` | 36 | `phase_36_platform_services_2.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 43 | `phase_43_keycloak_ingress.md` | 37 | `phase_37_keycloak_ingress.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 44 | `phase_44_live_dsl_deploy.md` | 38 | `phase_38_live_dsl_deploy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 45 | `phase_45_app_tenancy.md` | 39 | `phase_39_app_tenancy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 46 | `phase_46_pulsar_client.md` | 40 | `phase_40_pulsar_client.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 47 | `phase_47_user_tenant_isolation_live.md` | 41 | `phase_41_user_tenant_isolation_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 48 | `phase_48_content_store_workflow.md` | 42 | `phase_42_content_store_workflow.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 49 | `phase_49_ui_projection_runtime.md` | 43 | `phase_43_ui_projection_runtime.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 50 | `phase_50_release_lifecycle.md` | 44 | `phase_44_release_lifecycle.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 51 | `phase_51_ui_program_release.md` | 45 | `phase_45_ui_program_release.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 52 | `phase_52_network_fabric_wireguard.md` | 46 | `phase_46_network_fabric_wireguard.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 53 | `phase_53_multicluster_spawn_georepl.md` | 47 | `phase_47_multicluster_spawn_georepl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 54 | `phase_54_gateway_migration_drills.md` | 48 | `phase_48_gateway_migration_drills.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 55 | `phase_55_provider_deploy_checkpoint.md` | 49 | `phase_49_provider_deploy_checkpoint.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 56 | `phase_56_provider_child_bringup.md` | 50 | `phase_50_provider_child_bringup.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 57 | `phase_57_provider_ebs_credential.md` | 51 | `phase_51_provider_ebs_credential.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 58 | `phase_58_provider_dynamic_nodes.md` | 52 | `phase_52_provider_dynamic_nodes.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 59 | `phase_59_determinism_jitcache.md` | 53 | `phase_53_determinism_jitcache.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 60 | `phase_60_infernix_lift.md` | 54 | `phase_54_infernix_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 61 | `phase_61_infernix_ui_lift.md` | 55 | `phase_55_infernix_ui_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 62 | `phase_62_test_topology_dsl.md` | 56 | `phase_56_test_topology_dsl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 63 | `phase_63_ui_single_tenant_live.md` | 57 | `phase_57_ui_single_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 64 | `phase_64_ui_multi_tenant_live.md` | 58 | `phase_58_ui_multi_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 65 | `phase_65_ui_rollout_reconnect.md` | 59 | `phase_59_ui_rollout_reconnect.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 66 | `phase_66_ui_ha_multizone.md` | 60 | `phase_60_ui_ha_multizone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 67 | `phase_67_offline_replay_receipts.md` | 61 | `phase_61_offline_replay_receipts.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 68 | `phase_68_offline_blobs_isolation.md` | 62 | `phase_62_offline_blobs_isolation.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 69 | `phase_69_offline_release_evolution.md` | 63 | `phase_63_offline_release_evolution.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 70 | `phase_70_offline_multizone_continuity.md` | 64 | `phase_64_offline_multizone_continuity.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 71 | `phase_71_jitml_lift_cuda.md` | 65 | `phase_65_jitml_lift_cuda.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 72 | `phase_72_jitml_ui_lift.md` | 66 | `phase_66_jitml_ui_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 73 | `phase_73_complementary_arch_child.md` | 67 | `phase_67_second_arch_attested_index.md` | shift, **reopened, and renamed**: the attested multi-architecture index is retracted with the manifest list, so the slug's `attested_index` had become a false claim; the phase keeps the complementary architecture's native image and loses the join |
| 74 | `phase_74_apple_metal_host_daemon.md` | 68 | `phase_68_apple_metal_host_daemon.md` | shift only — displaced by an inserted phase or by a moved neighbour |

### Rejected, with reason

| # | proposal | not adopted, because |
|---|----------|----------------------|
| R1 | a fractional id (`Phase 2.5`) for the inserted band | [§E](development_plan_phase_model.md#e-one-canonical-phase-model) admits `0..N` contiguous with no fractional id; the fully mapped re-baseline is the only admitted mechanism |
| R2 | inserting the band at 1 or 2 | the CLI reads the authored toolchain requirements that Phase 1 delivers, so a phase below it inverts [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)-3; and `tools/layout_relocation_map.tsv` names Phase 2 in its own header, so inserting at 2 edits the one artifact that must be authored before the move it records |
| R3 | tail placement for `apple` and `windows` | [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)-1 is the stronger constraint: splitting "amoebius prepares its host" across one early phase and two tail phases makes the host-portability claim a design plus two exceptions, and that claim is the one the project makes on its first page. The cost is recorded rather than hidden — the head band is a three-machine floor, and the contiguity a single-machine developer had is re-scoped to phases 9 through 70 |
| R4 | one merged host-bring-up phase | [§O](development_plan_standards.md#o-sprint-sized-seams-and-bounded-phase-gates) admits one acceptance command in one register on at most one substrate; a merged phase names three substrates and two registers |
| R5 | merging phases 3 and 4 | two languages, two test stacks, and two independently useful claims — that the pre-binary assertions are idempotent, and that the post-handoff assertions are substrate-indexed and branchless |
| R6 | keeping `buildx` for the base image while banning it elsewhere | two build mechanisms is the opposite of one lifted path, and [§6](../documents/engineering/image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1)'s question would then have two answers |
| R7 | preserving the OCI index as a publish-time join without `buildx` | the join produces an artifact no single host attested, which is the defect the natural-architecture rebaseline exists to remove |
| R8 | shifting the phase column of `test/oracle/preimplementation_artifacts.tsv` | twelve or more gates select their rows by literal ordinal prefix and assert a custody count against them; shifting the column zeroes those silently |
| R9 | bulk-shifting the phase ordinals inside `src/`, `test/`, `tools/`, and `dhall/` string content | shifting a stale name mints a fresh stale name; those are de-phased, not translated |

This change also retired twenty-one rows whose observation was struck and whose closure was recorded without
a residual half. A register row earns its place by naming work still owed; a row that records only that
something was finished is answered by the phase document that finished it, and keeping it here costs the
budget a live row needs.

### Still open after this change

- The gate modules for phases 3–8 do not exist; each new phase names a `**Gate:**` command the tree does not
  yet carry. Owner: phases 3–8. Closure: each gate runs to a verdict and emits its ledger.
- `questions.txt` is tracked at the repository root and rule `r13` reports it as outside the target tree.
  Owner: Phase 2. Closure: the file is placed or removed.
- 886 acronym first uses across the corpus are unexpanded against [`documentation_standards.md` §12.1](../documents/documentation_standards.md), whose registry is normative and whose adoption is zero. No check
  measures it. Owner: Phase 0. Closure: a check exists and the corpus passes it.
- The `p3` sentence-cap backlog stands at 69, and `SENTENCE_CAP` is parked at 90 against the stated 45.
  Owner: Phase 0. Closure: the cap reaches its stated value with the corpus under it.
- Five sprint sub-numbers cited across documents do not exist in either the old or the new numbering —
  `Sprint 20.8`, `Sprint 32.4`, `Sprint 32.5`, `Sprint 10.19`, and `Sprint 49.3`. The 2026-08-18 ordinal
  pass corrected each reference's *phase* component and left the sub-number, which was already dangling.
  Owner: the citing phase of each. Closure: each names a sprint that exists.

### What this change does not perform

This is the documentation act. Every row below is code the change deliberately did not touch.

| observation | required end state | owner and closure |
|-------------|--------------------|-------------------|
| `dhall/amoebius/Image.dhall` declares `Base : { name : Text }` and a three-arm `BakeStep`, while doctrine states an architecture-carrying `Base` and the four-rung ladder | the Dhall unions match [`image_build_doctrine.md` §5](../documents/engineering/image_build_doctrine.md#5-what-the-image-identity-is-given-that-the-tag-is-an-address) and [§6](../documents/engineering/image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1) | Phase 42. Closure: the tags and the rungs are representable and no fourth `BakeStep` shape exists |
| `dhall/amoebius/BakeCatalog.dhall` carries `baseDigest` and the rendered golden pins `ubuntu:24.04@sha256:…` | no authored digest in any recipe or catalog; the parent is a channel resolved per run | Phase 5. Closure: no authored digest remains under `dhall/` or the recipe golden |
| `src/Amoebius/Image/{BuildRuntime,Artifact,Publish,Ref,NodeLoad}.hs` and eight Python tools model a multi-architecture index | one image per architecture under its own tag, with no join | Phase 42. Closure: no module constructs or validates a manifest list |
| ~~`src/Amoebius/Host/Ensure.hs` carries `installMechanism :: String`, `installAndVerify` has no caller, and `HostTool` has five constructors and no `Docker` arm~~ | the ensure algebra is typed data with a probe-first driver | **Closed by Phase 4 on 2026-08-19.** A step is a `Performer` plus an `[Argument]` in which a version is a `RequirementVersion` rather than a literal; `HostTool` carries `Docker`; and the driver is exercised by the absent → present → present replay against a committed fake tool directory, which is what makes the re-resolve observable rather than argued |
| ~~`src/Amoebius/Cluster/Bootstrap.hs` refuses `apple` and `windows` outright~~ | every catalog member reaches a frame | **Closed by Phase 4 on 2026-08-19.** The wildcard arm is replaced by an exhaustive match over `Frame`, so each substrate enters the frame its row names; materializing the Lima and WSL2 frames belongs to Phases 7 and 8 |
| `test/fixture/bootstrap_coordinator/install_plans.tsv` describes the retired four-column step shape, which the typed `InstallStep` renders as five | the Phase-35 fixture describes the step shape that exists | Phase 35. Closure: `tools/bootstrap_coordinator_gate.py` reaches a verdict against the rendered plan |
| `dsl-core` compiled `Amoebius.Pulumi.Engine` as a home module its stanza never declared, so `-Werror=missing-home-modules` refused the build | every home module a component compiles is declared by that component | **Closed by Phase 4 on 2026-08-19**: the module is declared, and the gate builds under `-Werror` |
| ~~`pb/` is an `argparse` CLI under a setuptools `pyproject.toml` with no configured type checker, formatter, linter, or test runner~~ | a Poetry distribution installed with `pipx`, checked under `mypy --strict` with no explicit `Any` | **Closed by Phase 3 on 2026-08-19.** The distribution is Poetry-built with a Click topology; `ruff`, `black` and `mypy --strict` with `disallow_any_explicit` run as a gate precondition, a token-aware scan refuses `Any`, `cast` and `type: ignore` outright, and 217 tests cover it at 100% branch coverage |
| `test/spec/host/test_bootstrap_coordinator.py` imports `pb.bootstrap_coordinator`, which Phase 3 split into `pb/pb/{process,prereqs,bootstrap}.py` | the Phase-35 spec drives the modules that exist, through the one choke point | Phase 35. Closure: the spec imports resolve and `tools/bootstrap_coordinator_gate.py` reaches a verdict |
| `test/spec/host/test_live_dsl_deploy_admin_client.py` imports `pb.cli.parser`, which the Click topology replaced | the Phase-44 spec reads the command surface through the parser that exists | Phase 44. Closure: the spec imports resolve and the admin surface is exercised against the daemon |
| `pb/pb/admin.py` is the second (admin-REST) mode and has no live validation; Phase 3's gate exercises it only against a fake opener | the mode is validated against a running control-plane daemon | Phase 44. Closure: Sprint 44.4 drives Vault init/unseal, Dhall update and KV CRUD live |
| ~160 `tools/*_live.py` modules drive kind, Vault, Pulsar, MinIO and Kubernetes in Python, duplicating the typed, absolute-path host layer `src/Amoebius/Host/**` exists to own, and none is covered by any linter, type checker or suite | cluster drivers are Haskell behind the typed host boundary; Python keeps only the policy-over-text gate kernel, held to the standard Phase 3 set for `pb/` | the owning phase of each live gate. Closure: each `*_live.py` is retired as its phase reopens, or is brought under the `pb` quality standard |
| `tools/toolchain.py` resolves into `.build/toolchain/{bin,runtime,downloads,cache}` with no platform segment | the resolved-toolchain tree is partitioned by `<os>-<arch>` | Phase 4. Closure: two hosts of different architecture resolve into disjoint subtrees |
| thirty-one gate modules pass `PhaseGate(phase=N)` with `N` offset from their own contract's ordinal | the run-artifact tag and the contract ordinal agree, or the divergence is authored | the owning phase of each gate. Closure: the integer is derived from the contract path |
| `tools/base_image_registry_gate.py` maps its mutants to sprint ids from a superseded numbering | the sprint prefix is derived from the contract | Phase 42. Closure: no sprint id names a phase the document does not carry |
| `tools/live_dsl_deploy_gate.py` discovers a test module under a name the file no longer has, so the step runs no tests and passes | the discovery pattern names the file that exists | Phase 44. Closure: the step reports a non-zero test count |
| eight UI gate modules construct `PhaseGate` without a lane, which the constructor refuses | each names its lane | the owning phase of each gate. Closure: every gate constructs |
| two gate modules write run evidence into `DEVELOPMENT_PLAN/evidence/`, an authored root, and neither uses the shared harness that would refuse it | evidence lands beneath `.build/runs/**` | the owning phase of each gate. Closure: no gate writes into an authored root |
| `tools/containment.py` resolves `docker` at a hard-coded path that does not exist on `apple`, so the containment observer silently degrades there | the executable is resolved through the ensure kernel | Phase 4. Closure: the observer reports on every substrate |
| `tools/migration_allowlist.tsv` carries owner cells in a superseded numbering. `dhall/examples/locus_registry.tsv` and `tools/generator_registry.tsv` were shifted — the registry together with the `**Delivery-owner:**` tags it joins against and the literal ceiling in `tools/locus_registry_lint.py`, which is still written rather than derived | each owner cell names the current ordinal, and the ceiling is derived rather than written | the owning phase of each row. Closure: the owner column joins to the tracker |
| roughly three thousand phase ordinals sit in comments and string literals across `src/`, `test/`, `tools/`, and `dhall/`, most already stale | no authored non-plan content names a phase ordinal | the owning phase of each. Closure: the de-phasing that Phase 2 applied to paths is applied to content |
| `documents/engineering/substrate_doctrine.md` retains its ensure-contract, virtualized-substrate, and coordinator sections in a hub carrying one slice | the family carries a slice per aspect | Phase 0. Closure: each remaining aspect is its own slice |
| `documents/engineering/testing_doctrine.md` states no policy for the browser image, its three engines, or host-driven end-to-end runs | the end-to-end policy is authored in testing doctrine | Phase 0. Closure: the policy has an owning section |
| the gate ordinal families named `dhall-typecheck` and `gadt-decode` remain in filenames, oracle keys, and prose | each names the mechanism that rejects rather than an ordinal | Phase 0. Closure: no authored name carries a gate ordinal |

---

## Phase re-baseline — 2026-08-17

[§E](development_plan_phase_model.md#e-one-canonical-phase-model) admits a re-baseline only when the same
change records **every** old phase as `old id/path -> new id/path(s)`, updates every inbound link, and leaves
no stale old-number reference. The 2026-08-16 map recorded only the *changed ranges*, and seven ordinals
survived it; this one is exhaustive, and the `f5` check now fails on the class of defect that produced them.

Three phases are inserted and four move bands. The rest shift. What the re-baseline answers:

- **The artifact layer was inverted.** Every one of 876 deferred findings was owned by a phase 32 or later,
  because the allowlist attributed each shared-surface finding to the *last* phase that needed it. That is
  right for a deletion and wrong for a relocation, and it left nine pre-cluster phases specified against paths
  the target tree forbids. New Phase 2 owns the relocations; the deletions stay with their last consumer.
- **A re-baseline was unaffordable.** [§U](development_plan_gate_integrity.md#u-the-final-repository-layout)
  clause 3 makes one cheap on the premise that no path outside this plan suite names an ordinal — and rule
  `r15` deferred exactly that violation across 34 rows, one per phase 32 through 65. The de-phasing that makes
  a re-baseline safe was owned by the phases being re-baselined. New Phase 2 breaks that cycle.
- **The DSL was not fully validated before live.** TLA+ proved a throwaway model and `IOSim` a toy reconcile
  loop; neither instrument was ever pointed at the DSL. New Phases 11 and 12 do that, and the reconcile
  algorithm's only proof claim — sibling evidence from prodbox — becomes an amoebius result.
- **Two pure phases sat behind 36 live ones**, and specialized-hardware islands gated the linux-cpu chain at
  two points. Both are corrected below. A developer with one `linux-cpu/amd64` machine and a cloud account now
  runs 0 through 64 contiguously; before, the chain halted at old 25.

**Order of operations.** The tree does not move in this change. This is the documentation act; Phase 2's gate
is the tree act, and it follows — because a re-baseline is documentation-only once no path names a phase.
Until Phase 2 runs, every phase document naming an ordinal-bearing authored path is a divergence this table
owns, not a defect in that phase.

| new id | new path | old id | old path | why it moved |
|---|---|---|---|---|
| 0 | `phase_00_documentation_suite.md` | 0 | `phase_00_documentation_suite.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 1 | `phase_01_toolchain_spike.md` | 1 | `phase_01_toolchain_spike.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 2 | [`phase_02`](phase_02_repository_layout_conformance.md) | — (new) | — | **new.** A whole-tree closure predicate had no satisfiable owner: four register rows quantify over the entire tree and name a distributed owner, which [§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 5 forbids |
| 3 | `phase_09_formal_model_kernel.md` | 2 | `phase_09_formal_model_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 4 | `phase_10_gateway_migration_model.md` | 3 | `phase_10_gateway_migration_model.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 5 | `phase_11_dhall_typecheck_schema.md` | 4 | `phase_11_dhall_typecheck_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 6 | `phase_12_gadt_decode_ir.md` | 5 | `phase_12_gadt_decode_ir.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 7 | `phase_13_illegal_state_corpus.md` | 6 | `phase_13_illegal_state_corpus.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 8 | `phase_14_capacity_core_folds.md` | 7 | `phase_14_capacity_core_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 9 | `phase_15_storage_geometry_folds.md` | 8 | `phase_15_storage_geometry_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 10 | `phase_16_execution_accelerator_folds.md` | 9 | `phase_16_execution_accelerator_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 11 | `phase_17_capability_bind.md` | 10 | `phase_17_capability_bind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 12 | `phase_18_provision_seal.md` | 11 | `phase_18_provision_seal.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 13 | `phase_19_inference_accelerator_provision.md` | 12 | `phase_19_inference_accelerator_provision.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 14 | `phase_20_render_manifest_goldens.md` | 13 | `phase_20_render_manifest_goldens.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 15 | `phase_21_chain_kernel_boundary.md` | 14 | `phase_21_chain_kernel_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 16 | `phase_22_deterministic_sim_substrate.md` | 15 | `phase_22_deterministic_sim_substrate.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 17 | [`phase_18`](phase_18_dsl_formal_model.md) | — (new) | — | **new.** The model kernel and the one cross-cluster obligation left the DSL itself model-checked by nothing |
| 18 | [`phase_19`](phase_19_reconcile_core_simulation.md) | — (new) | — | **new.** The simulation substrate had no amoebius-owned subject before the live band; the reconciler was first simulated inside the same phase as its live gate |
| 19 | `phase_25_ui_program_schema.md` | 16 | `phase_25_ui_program_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 20 | `phase_26_scoped_identity_kernel.md` | 17 | `phase_26_scoped_identity_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 21 | `phase_27_ui_authorization_kernel.md` | 18 | `phase_27_ui_authorization_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 22 | `phase_28_ui_effect_binding.md` | 19 | `phase_28_ui_effect_binding.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 23 | `phase_29_ui_plan_compiler.md` | 20 | `phase_29_ui_plan_compiler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 24 | `phase_30_offline_language_plan.md` | 60 | `phase_30_offline_language_plan.md` | Register 1, substrate `none` — pure UI offline language work stranded behind 36 Register-3 phases |
| 25 | `phase_31_ui_browser_interpreter.md` | 21 | `phase_31_ui_browser_interpreter.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 26 | `phase_32_ui_server_boundary.md` | 22 | `phase_32_ui_server_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 27 | `phase_33_ui_local_composition.md` | 23 | `phase_33_ui_local_composition.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 28 | `phase_34_encrypted_browser_runtime.md` | 61 | `phase_34_encrypted_browser_runtime.md` | Register 2, substrate `none` — browser runtime work stranded behind the live band |
| 29 | `phase_35_bootstrap_coordinator_kind.md` | 24 | `phase_35_bootstrap_coordinator_kind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 30 | `phase_36_base_image_registry.md` | 25 | `phase_36_base_image_registry.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 31 | `phase_37_object_reconciler.md` | 27 | `phase_37_object_reconciler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 32 | `phase_38_capacity_scheduler.md` | 28 | `phase_38_capacity_scheduler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 33 | `phase_39_retained_storage.md` | 29 | `phase_39_retained_storage.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 34 | `phase_40_vault_pki.md` | 30 | `phase_40_vault_pki.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 35 | `phase_41_platform_backbone.md` | 31 | `phase_41_platform_backbone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 36 | `phase_42_platform_services_2.md` | 32 | `phase_42_platform_services_2.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 37 | `phase_43_keycloak_ingress.md` | 33 | `phase_43_keycloak_ingress.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 38 | `phase_44_live_dsl_deploy.md` | 34 | `phase_44_live_dsl_deploy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 39 | `phase_45_app_tenancy.md` | 35 | `phase_45_app_tenancy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 40 | `phase_46_pulsar_client.md` | 36 | `phase_46_pulsar_client.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 41 | `phase_47_user_tenant_isolation_live.md` | 37 | `phase_47_user_tenant_isolation_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 42 | `phase_48_content_store_workflow.md` | 38 | `phase_48_content_store_workflow.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 43 | `phase_49_ui_projection_runtime.md` | 39 | `phase_49_ui_projection_runtime.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 44 | `phase_50_release_lifecycle.md` | 40 | `phase_50_release_lifecycle.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 45 | `phase_51_ui_program_release.md` | 41 | `phase_51_ui_program_release.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 46 | `phase_52_network_fabric_wireguard.md` | 42 | `phase_52_network_fabric_wireguard.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 47 | `phase_53_multicluster_spawn_georepl.md` | 43 | `phase_53_multicluster_spawn_georepl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 48 | `phase_54_gateway_migration_drills.md` | 44 | `phase_54_gateway_migration_drills.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 49 | `phase_55_provider_deploy_checkpoint.md` | 45 | `phase_55_provider_deploy_checkpoint.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 50 | `phase_56_provider_child_bringup.md` | 46 | `phase_56_provider_child_bringup.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 51 | `phase_57_provider_ebs_credential.md` | 47 | `phase_57_provider_ebs_credential.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 52 | `phase_58_provider_dynamic_nodes.md` | 48 | `phase_58_provider_dynamic_nodes.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 53 | `phase_59_determinism_jitcache.md` | 49 | `phase_59_determinism_jitcache.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 54 | `phase_60_infernix_lift.md` | 50 | `phase_60_infernix_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 55 | `phase_61_infernix_ui_lift.md` | 51 | `phase_61_infernix_ui_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 56 | `phase_62_test_topology_dsl.md` | 55 | `phase_62_test_topology_dsl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 57 | `phase_63_ui_single_tenant_live.md` | 56 | `phase_63_ui_single_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 58 | `phase_64_ui_multi_tenant_live.md` | 57 | `phase_64_ui_multi_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 59 | `phase_65_ui_rollout_reconnect.md` | 58 | `phase_65_ui_rollout_reconnect.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 60 | `phase_66_ui_ha_multizone.md` | 59 | `phase_66_ui_ha_multizone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 61 | `phase_67_offline_replay_receipts.md` | 62 | `phase_67_offline_replay_receipts.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 62 | `phase_68_offline_blobs_isolation.md` | 63 | `phase_68_offline_blobs_isolation.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 63 | `phase_69_offline_release_evolution.md` | 64 | `phase_69_offline_release_evolution.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 64 | `phase_70_offline_multizone_continuity.md` | 65 | `phase_70_offline_multizone_continuity.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 65 | `phase_71_jitml_lift_cuda.md` | 52 | `phase_71_jitml_lift_cuda.md` | `linux-cuda` island interrupting the linux-cpu chain; moved to the specialized tail, grouped by machine |
| 66 | `phase_72_jitml_ui_lift.md` | 53 | `phase_72_jitml_ui_lift.md` | `linux-cuda` island interrupting the linux-cpu chain; moved to the specialized tail, grouped by machine |
| 67 | `phase_73_complementary_arch_child.md` | 26 | `phase_73_complementary_arch_child.md` | `apple` island at old 26 blocking 39 downstream linux-cpu phases; moved to the specialized tail |
| 68 | `phase_74_apple_metal_host_daemon.md` | 54 | `phase_74_apple_metal_host_daemon.md` | `apple`/`metal` island interrupting the linux-cpu chain; moved to the specialized tail |

**Rejected, with reason** ([§T](development_plan_gate_integrity.md#t-plan-to-implementation-reconciliation)
clause 5). The proposal recorded elsewhere in this register to move the third-party bake into the pre-cluster
band is **not adopted**. A BuildKit bake needs a container engine and a detected natural architecture, so it
is neither substrate `none` nor Register 1/2 and cannot enter the DSL-validation band without breaking the
register cut that band exists to hold. The bake stays with the native base image in the live sequence. That
row's *second* sentence — that a re-baseline follows the de-phasing — is adopted verbatim as this one's order
of operations.

**Still open after this change.** Phase 73's gate command names `tools/complementary_arch_gate.py`, which does
not exist; it is the only phase in the suite naming a gate tool the tree does not have. The 2026-08-18 doctrine
pass renamed it from `tools/attested_index_gate.py` when the attested-index join was retracted with the
manifest list, so the missing tool now at least names what the phase does. Owner: Phase 73. Closure: the gate
runs to a verdict.

---

## Pre-implementation Phase Re-baseline — 2026-08-01

This table is the audit map for the approved low-code UI-runtime insertion. The left column is deliberately
historical text, not a live link; the right column records every current destination. Rows 17–42 are mechanical
renames, while the former broad UI phases 19 and 48 are explicit one-to-many splits and the `N/A` rows are new
seams. The renumbering used old-id placeholders before emitting any new id, so overlapping ids could not
cascade (for example, old Phase 20 could not become 31 by being rewritten first to 24 and then rewritten
again). Ubuntu-24.04 was explicitly protected as a non-phase literal.

| Historical id and path | Current id and path |
|------------------------|---------------------|
| 16 — phase_16_spa_composition_representational.md | 19 — phase_25_ui_program_schema.md; 20 — phase_26_scoped_identity_kernel.md; 21 — phase_27_ui_authorization_kernel.md; 22 — phase_28_ui_effect_binding.md; 23 — phase_29_ui_plan_compiler.md; 25 — phase_31_ui_browser_interpreter.md; 26 — phase_32_ui_server_boundary.md; 27 — phase_33_ui_local_composition.md |
| 17 — historical Phase-17 bootstrap-kind document | 29 — phase_35_bootstrap_coordinator_kind.md |
| 18 — phase_36_base_image_registry.md | 30 — phase_36_base_image_registry.md |
| 19 — phase_37_object_reconciler.md | 31 — phase_37_object_reconciler.md |
| 20 — phase_38_capacity_scheduler.md | 32 — phase_38_capacity_scheduler.md |
| 21 — phase_39_retained_storage.md | 33 — phase_39_retained_storage.md |
| 22 — phase_40_vault_pki.md | 34 — phase_40_vault_pki.md |
| 23 — phase_41_platform_backbone.md | 35 — phase_41_platform_backbone.md |
| 24 — phase_42_platform_services_2.md | 36 — phase_42_platform_services_2.md |
| 25 — phase_43_keycloak_ingress.md | 37 — phase_43_keycloak_ingress.md |
| 26 — phase_44_live_dsl_deploy.md | 38 — phase_44_live_dsl_deploy.md |
| 27 — phase_45_app_tenancy.md | 39 — phase_45_app_tenancy.md |
| 28 — phase_46_pulsar_client.md | 40 — phase_46_pulsar_client.md |
| N/A — newly isolated live-enforcement seam | 41 — phase_47_user_tenant_isolation_live.md |
| 29 — phase_48_content_store_workflow.md | 42 — phase_48_content_store_workflow.md |
| N/A — newly isolated owner-projection seam | 43 — phase_49_ui_projection_runtime.md |
| 30 — phase_50_release_lifecycle.md | 44 — phase_50_release_lifecycle.md |
| N/A — newly isolated UI-release seam | 45 — phase_51_ui_program_release.md |
| 31 — phase_52_network_fabric_wireguard.md | 46 — phase_52_network_fabric_wireguard.md |
| 32 — phase_53_multicluster_spawn_georepl.md | 47 — phase_53_multicluster_spawn_georepl.md |
| 33 — phase_54_gateway_migration_drills.md | 48 — phase_54_gateway_migration_drills.md |
| 34 — phase_55_provider_deploy_checkpoint.md | 49 — phase_55_provider_deploy_checkpoint.md |
| 35 — phase_56_provider_child_bringup.md | 50 — phase_56_provider_child_bringup.md |
| 36 — phase_57_provider_ebs_credential.md | 51 — phase_57_provider_ebs_credential.md |
| 37 — phase_58_provider_dynamic_nodes.md | 52 — phase_58_provider_dynamic_nodes.md |
| 38 — phase_59_determinism_jitcache.md | 53 — phase_59_determinism_jitcache.md |
| 39 — phase_60_infernix_lift.md | 54 — phase_60_infernix_lift.md |
| N/A — newly isolated infernix-to-UI seam | 55 — phase_61_infernix_ui_lift.md |
| 40 — phase_71_jitml_lift_cuda.md | 65 — phase_71_jitml_lift_cuda.md |
| N/A — newly isolated jitML-to-UI seam | 66 — phase_72_jitml_ui_lift.md |
| 41 — phase_74_apple_metal_host_daemon.md | 68 — phase_74_apple_metal_host_daemon.md |
| 42 — phase_62_test_topology_dsl.md | 56 — phase_62_test_topology_dsl.md |
| 43 — phase_43_spa_live_deploy.md | 57 — phase_63_ui_single_tenant_live.md; 58 — phase_64_ui_multi_tenant_live.md; 59 — phase_65_ui_rollout_reconnect.md; 60 — phase_66_ui_ha_multizone.md |

Destination phases **43, 45, 47, 57, and 59** are the explicitly mapped new live isolation, projection,
UI-release, infernix-UI, and jitML-UI seams inserted between the mechanically renamed phases. The old Phase 19
and Phase 48 milestone documents were retired only after every split destination was enumerated above. The resulting plan is one
contiguous `0..58` sequence at that date; two later re-baselines have since extended it.

---

## Superseded records, moved to the archive slice

Nine dated sections carried no audit-map row and recorded findings that are closed or superseded. They moved
to [`legacy_tracking_for_deletion_archive.md`](legacy_tracking_for_deletion_archive.md) so this hub stays
under the document cap of [§10](../documents/documentation_standards.md#10-document-shape) while every audit
map stays here, where check `u3`'s historical exemption is keyed to this filename:

- [Host-ensure amendment — 2026-08-17](legacy_tracking_for_deletion_archive.md#host-ensure-amendment--2026-08-17) — moved to the archive slice; its findings are closed or superseded.
- [One binary, many roles — 2026-08-17](legacy_tracking_for_deletion_archive.md#one-binary-many-roles--2026-08-17) — moved to the archive slice; its findings are closed or superseded.
- [Natural-architecture rebaseline — 2026-08-16](legacy_tracking_for_deletion_archive.md#natural-architecture-rebaseline--2026-08-16) — moved to the archive slice; its findings are closed or superseded.
- [Repository-containment rebaseline — 2026-08-15](legacy_tracking_for_deletion_archive.md#repository-containment-rebaseline--2026-08-15) — moved to the archive slice; its findings are closed or superseded.
- [Existing-code divergence snapshot — 2026-08-11](legacy_tracking_for_deletion_archive.md#existing-code-divergence-snapshot--2026-08-11) — moved to the archive slice; its findings are closed or superseded.
- [Phase-0 closure disposition — 2026-08-12](legacy_tracking_for_deletion_archive.md#phase-0-closure-disposition--2026-08-12) — moved to the archive slice; its findings are closed or superseded.
- [Layout and naming divergence snapshot — 2026-08-14](legacy_tracking_for_deletion_archive.md#layout-and-naming-divergence-snapshot--2026-08-14) — moved to the archive slice; its findings are closed or superseded.
- [What the layout conformance uncovered — 2026-08-17](legacy_tracking_for_deletion_archive.md#what-the-layout-conformance-uncovered--2026-08-17) — moved to the archive slice; its findings are closed or superseded.
- [Generated-artifact and terminology migration — 2026-08-11](legacy_tracking_for_deletion_archive.md#generated-artifact-and-terminology-migration--2026-08-11) — moved to the archive slice; its findings are closed or superseded.

---

## Pending Removal

"Location" names the **sibling-project artifact** being supplanted; the target
amoebius module that absorbs or replaces it is owned by [system_components.md](system_components.md). "Why
slated" cites the governing doctrine section by name. "Owning phase" is the amoebius phase whose adoption
work performs the removal. The final column preserves the invalidated pre-amendment observation that explains
what code or gap was seen; it is not current status. Every row is currently reopened with its owning phase,
and only [README.md](README.md) supplies that status.

| Item | Location (sibling artifact) | Why slated | Owning phase | Pre-amendment observation (invalidated) |
|------|-----------------------------|------------|--------------|--------|
| **prodbox** as a standalone product / CLI | sibling `prodbox/` — `app/prodbox/Main.hs`, `src/Prodbox/` | prodbox is absorbed as the **root single-node control-plane behaviour** — a library + the in-cluster control-plane daemon (a Deployment `replicas=1`, single-instance from k8s/etcd, no election) under the one amoebius binary, not a separate product; see [`daemon_topology_doctrine.md` §3 — the control-plane daemon](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon) and the convergence framing in [README.md](README.md) | [Phase 55](phase_55_bootstrap_coordinator_kind.md) – [Phase 65](phase_65_live_dsl_deploy.md) | 📋 Planned |
| **The shell `bootstrap.sh` igniter** | sibling hostbootstrap `bootstrap.sh` (the substrate shell script) | Retired for the **Python `pb` bootstrap coordinator CLI** — one Python CLI, two modes (bootstrap coordinator bring-up + admin-REST client); amoebius owns no bootstrap shell script; see [`substrate_doctrine.md` §6 — the bootstrap coordinator contract](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) | [Phase 55](phase_55_bootstrap_coordinator_kind.md) | ✅ Replacement built; complete pristine-Incus Phase-29 gate passed |
| **infernix** as a standalone product / image | sibling `infernix/` — `Infernix.Runtime.*` | infernix becomes an **ML extension library** linked into the amoebius binary (and a shared library at the app surface), never a separate product; see [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library, the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule) | [Phase 91](phase_91_infernix_rederivation.md) | 🟡 Scoped gate passed 2026-08-11: one untouched sibling compacted-topic module and the new facade are linked; full sibling inference-engine linkage remains UNVERIFIED |
| **infernix handwritten SPA** as an authority-bearing frontend | sibling infernix PureScript demo client | Replaced by the bounded Dhall module and linked Haskell adapter interpreted through the generic UI runtime; the sibling screen remains UX evidence, never a second executable frontend or authority source. | [Phase 92](phase_92_infernix_ui_rederivation.md) | 🟡 Scoped gate passed 2026-08-11; ledger `external-run-reference`. The test uses loopback UI origins and a reference worker, so full edge/Kubernetes replica/production cutover remains UNVERIFIED. |
| **jitML** as a standalone product | sibling `jitML/` — `JitML.*` | jitML becomes a linked **ML extension library** behind one scope-bound CUDA-training → pointer-committed-artifact facade; Phase 42 continues to own delegated Pulsar-Failover/CAS coordination and Phase 66 alone owns UI interaction | [Phase 93](phase_93_jitml_rederivation.md) | 🟡 Scoped gate passed 2026-08-11; ledger `external-run-reference`. One sibling CUDA generator is linked, but the full trainer/checkpoint graph and Kubernetes owner remain UNVERIFIED. |
| **Baked / Poetry-venv ML engine payloads** | sibling infernix per-engine Poetry venvs + curl-tar-at-image-build (`docker/Dockerfile`, `model_cache.py`) | Retired for the shared **jit-build resolver + `CacheBudget`-bounded content-addressed cache**: each engine is a named catalog identity resolved on first miss, never baked or URL-fetched; see [`content_addressing_determinism.md` §4.5 — the ML-asset lifecycle](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) and [`image_build_doctrine.md` §7](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 80](phase_80_determinism_jitcache.md) | 🟡 Scoped replacement validated with a pinned engine fixture; production engine payloads remain UNVERIFIED |
| **All third-party Helm charts + the Helm binary** | sibling prodbox chart platform (`Prodbox.Lib.ChartPlatform`, vendored charts); `helm` baked in the hostbootstrap base image | No-Helm: platform and app manifests are **pure typed Haskell rendered and applied by the typed reconciler** (server-side apply, ApplySet prune, wait), so neither charts nor the `helm` dependency survive; see [`manifest_generation_doctrine.md` §1 — why this doctrine exists: types render manifests, Helm does not](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) | [Phase 62](phase_62_platform_backbone.md) (platform) → [Phase 65](phase_65_live_dsl_deploy.md) (app DSL) | 📋 Planned |
| The **five upstream operator charts** — Harbor, MetalLB, Envoy Gateway, cert-manager, Percona — *as charts* | vendored Helm charts in sibling prodbox | Operators are **generated as typed CRs**, and their binaries **baked into the base container**, not installed via operator charts: no-third-party-charts ≠ no-third-party-software; see [`manifest_generation_doctrine.md` §4 — no third-party charts ≠ no third-party software: operators are generated](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated) and [`image_build_doctrine.md` §7 — what amoebius bakes vs builds](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 62](phase_62_platform_backbone.md) | 📋 Planned |
| **The per-app container image** | the `app/workload image` class every app shipped as its second artifact | Retired: an app is bounded `UiSource` plus immutable client/server plans interpreted by the generic runtime — no per-app browser or server image, hand-written Dockerfile, or registry publication. Only a reviewed trusted Haskell adapter changes a `Runtime.linkedAdapters` variant; an ordinary UI change mints a `ProgramDigest`/`Release` and reuses the image digest. See [`app_vs_deployment_doctrine.md` §2 — the application-logic surface](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is) and [`image_build_doctrine.md` §5 — the closed `ImageIdentity`](../documents/engineering/image_build_doctrine.md#5-what-the-image-identity-is-given-that-the-tag-is-an-address) | [Phases 25–33](phase_37_ui_program_schema.md) (language/runtime) → [Phase 72](phase_72_ui_program_release.md) (immutable program release) | 📋 Planned |
| **The hand-authored `docker/base/Dockerfile`** | the committed `ARG`/`RUN … install` template driving the base-image bake | Retired for a **generated** Dockerfile emitted from the typed `BakeCatalog`, on the same ground [`manifest_generation_doctrine.md` §1](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) retires Helm charts: interpolated text that nothing inspects until it runs. See [`generated_artifacts_doctrine.md` §2 — what is generated](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what) | [Phase 56](phase_56_base_image_registry.md) | ✅ Done — resealed 2026-08-16 |
| **Harbor** itself (the registry) | sibling prodbox in-cluster Harbor + mirror-into-registry pipeline | Replaced by the single-binary **`distribution` (`registry:2`)** registry — itself a baked binary, no relational DB, no public-registry pulls; see [`image_build_doctrine.md` §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster) and [`platform_services_doctrine.md` §3 — the registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source) | [Phase 56](phase_56_base_image_registry.md) | ✅ Done — resealed 2026-08-16 |
| **jitML Node.js-subprocess WebSocket** Pulsar transport | sibling jitML — the Node subprocess owning the WebSocket client (`JitML.*`) | Retired for the **native `amoebius-pulsar`** TCP binary-protocol client: one client, one wire, **no WebSockets**, no Node runtime; see [`pulsar_client_doctrine.md` §1 — one client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets) and [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 67](phase_67_pulsar_client.md) (native client) → [Phase 93](phase_93_jitml_rederivation.md) (jitML cutover) | 📋 Planned: Phase 65's scoped host-CUDA slice does not exercise native CBOR/Pulsar, so transport cutover remains UNVERIFIED. The portable `linux-cpu` lane and Incus/Lima/WSL2 clean-host routing remain available. |
| **infernix in-process WebSocket gateway** Pulsar transport | sibling `Infernix.Runtime.Pulsar` (WebSocket gateway, one-producer-per-publish, base64-in-JSON) | Same native-client replacement; infernix stops shipping its own transport and consumes `amoebius-pulsar`; see [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 67](phase_67_pulsar_client.md) (native client) → [Phase 91](phase_91_infernix_rederivation.md) (infernix cutover) | 🟡 Scoped gate passed 2026-08-11: native-CBOR driver and dedup path observed; full command-to-worker cutover remains UNVERIFIED |
| **infernix single-arch (amd64-only)** image publication | sibling infernix image-build pipeline | Replaced by **multi-arch (`amd64` + `arm64`) baked binaries** under one manifest list; see [`image_build_doctrine.md` §3 — buildx multi-arch, amd64 and arm64, one manifest list](../documents/engineering/image_build_doctrine.md#3-multi-architecture-images--one-natively-built-child-per-architecture) | [Phase 56](phase_56_base_image_registry.md) | ✅ Done — resealed 2026-08-16 |
| **Per-substrate chart / image re-pins** | sibling prodbox substrate-aware version/image-ref pinning | Forbidden by **substrate equivalence**: one release/image-ref value across every substrate, with a build-time check that no code path re-pins conditionally on the active substrate; see [`platform_services_doctrine.md` §12 — substrate equivalence as a structural invariant](../documents/engineering/platform_services_doctrine.md#12-substrate-equivalence-as-a-structural-invariant). This bars per-substrate divergence of chart **versions** and **image refs** only; per-cluster **shape** divergence (single-node vs distributed) is permitted by [`service_capability_doctrine.md`](../documents/engineering/service_capability_doctrine.md) | [Phase 62](phase_62_platform_backbone.md) | 📋 Planned |

---

## Notes

- **"Removed" rarely means "deleted code."** For the three standalone products, the convergence retires their
  *product / packaging / transport identity*, not their domain logic. prodbox's control-plane behaviour and
  infernix's/jitML's ML logic are **preserved as libraries** linked into the one amoebius binary. Their demo
  clients remain migration evidence while the flows become bounded UI modules; what disappears is the separate
  CLI, image, release, and browser trust seam. This is why these rows are tracked here rather than as plain
  feature work.

- **Charts vs software (the Helm rows).** Dropping the five operator charts does **not** drop the five
  operators. Harbor is the one operator/service that is genuinely *replaced* (by `distribution`); MetalLB,
  Envoy Gateway, cert-manager, and Percona survive as **baked binaries with generated CRs**. Only the Helm
  *delivery mechanism* — the charts and the `helm` dependency — is removed. The distinction — charts and the
  `helm` dependency are removed, the operators are not — is the subject of [`manifest_generation_doctrine.md` §4 — no third-party charts ≠ no third-party software](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated).

- **Why two phases on the transport rows.** The native `amoebius-pulsar` client lands in
  [Phase 67](phase_67_pulsar_client.md), but the sibling transports are only *deleted* when
  each library is migrated onto it — infernix's WebSocket gateway at [Phase 91](phase_91_infernix_rederivation.md)
  and jitML's Node-subprocess client at [Phase 93](phase_93_jitml_rederivation.md), one subsystem at a time
  behind reversible adapter seams. The "client-lands → library-cutover" pair is captured so neither half is
  marked Done prematurely.

- **The substrate-equivalence row is a standing prohibition, not a one-time deletion.** "Per-substrate
  re-pins" is removed in the structural sense that no amoebius code path is allowed to express one; the
  enforcing build-time check is itself a [Phase 62](phase_62_platform_backbone.md) deliverable,
  and the substrate catalog it ranges over is owned by [substrates.md](substrates.md). It belongs on this
  ledger because it forecloses a prodbox-era pattern (substrate-conditional image refs) by construction.

- **Sibling evidence, not amoebius proof.** Every justification above that points at prodbox / infernix /
  jitML behaviour begins as evidence from a sibling system. Passed/scoped text in the final column is an
  invalidated historical observation and may be used only for diagnosis at its stated boundary; it is not a
  current amoebius result. All "Why slated" text remains design intent (the honesty rule,
  [development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

- **No fractional phases, no forward dependencies.** Owning-phase assignments above respect the one-phase
  model and strict numeric order ([development_plan_standards.md §E](development_plan_standards.md#e-one-canonical-phase-model)): every
  removal is pinned to an existing, contiguously-numbered phase, never to a fractional or later-than-its-cause
  id.

---

## Related Documents
- [README.md](README.md) — the live tracker: phase order, status, and gates that drive every owning-phase column
- [development_plan_standards.md](development_plan_standards.md) — the rulebook (status vocabulary [§C](development_plan_standards.md#c-status-vocabulary), one-phase model [§E](development_plan_standards.md#e-one-canonical-phase-model), doctrine-citation [§H](development_plan_standards.md#h-the-doctrine-citation-rule-cite-by-name), honesty [§K](development_plan_standards.md#k-honesty-proven--tested--assumed)) this ledger obeys
- [system_components.md](system_components.md) — the target amoebius modules that absorb or replace each slated artifact
- [substrates.md](substrates.md) — the substrate registry the substrate-equivalence row ranges over
- [phase_62_platform_backbone.md](phase_62_platform_backbone.md) — owns the no-Helm platform render, the baked operators, and the substrate-equivalence check (`distribution` and multi-arch are [phase_56_base_image_registry.md](phase_56_base_image_registry.md)'s)
- [phase_67_pulsar_client.md](phase_67_pulsar_client.md) — owns the native `amoebius-pulsar` client that retires the WebSocket transports
- [`manifest_generation_doctrine.md`](../documents/engineering/manifest_generation_doctrine.md) — no-Helm rendering + generated operators
- [`image_build_doctrine.md`](../documents/engineering/image_build_doctrine.md) — baked binaries, `distribution`, multi-arch
- [`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md) — the registry and substrate-equivalence invariants
- [`pulsar_client_doctrine.md`](../documents/engineering/pulsar_client_doctrine.md) — the native client and what it replaces
- [`app_vs_deployment_doctrine.md`](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-low-code-workflow-ui-as-application-logic-only) — infernix/jitML-as-library and their interactions expressed through the bounded UI runtime
- [`daemon_topology_doctrine.md`](../documents/engineering/daemon_topology_doctrine.md) — prodbox absorbed as the control-plane daemon
