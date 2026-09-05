{-# LANGUAGE OverloadedStrings #-}

-- | The proposed plan revision, held dormant.
--
-- The present order was never topologically sorted: its dependencies live in
-- prose no checker may read, and 'Amoebius.Validation.CapabilityGraph' still
-- reports seven edges that run backwards. Two of those are relocations rather
-- than claim edits, and a relocation cannot be applied without moving phases.
--
-- This module states the intended arrangement as typed values so it can be
-- checked before anything moves: the revised phase table, and the complete
-- old-to-new audit map that @development_plan_phase_model.md@ section E
-- requires of any reordering. It is checked for internal integrity only.
--
-- __Nothing consumes this module.__ The present 96-row identity table remains
-- the one the gate reads. Swapping them is a separate, single, indivisible
-- change; landing the proposal first means that change is a mechanical
-- application of an already-checked map rather than an act of authorship.
--
-- The revision applies the section-O trigger, made computable from fields that
-- are already typed and already joined against the documents: a phase splits
-- when it would otherwise need a second final register, substrate, lane or
-- declared gate, and two phases merge only when they agree on all four of
-- register, substrate, lane and resource-provision requirement. That fourth
-- conjunct matters: it is what rejects merging the two Register-2 UI phases,
-- which agree on register, substrate and lane but not on whether they must
-- declare a resource-provision contract.
--
-- Split seams are chosen for sprint contiguity rather than theme. The sprint
-- @Blocked by@ chains are linear, so a capability holding a discontiguous set
-- of its parent's sprints creates a dependency edge running backwards between
-- the very phases the split produces. Three of the eight splits read more
-- naturally when grouped by subject and were cut at the contiguous seam
-- instead; 'splitSprintAssignment' states the result and the check refuses any
-- assignment that is not a contiguous run.
module Amoebius.Validation.PlanRevision
  ( planRevisionDiagnostic
  ) where

import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.Types (CheckResult (..), Finding, finding, observation)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text

data Band
  = Foundations
  | Algebra
  | ProofStack
  | ExtensionContract
  | GenerativeSurface
  | TestAsWorkflow
  | PreBinaryAndHost
  | LivePlatform
  | DomainInstances
  deriving (Bounded, Enum, Eq, Ord, Show)

data RevisedPhase = RevisedPhase
  { revisedOrdinal :: Int
  , revisedCapability :: Text
  , revisedBand :: Band
  , revisedRegister :: Text
  , revisedSubstrate :: Text
  , revisedLane :: Text
  , revisedResource :: PhaseIdentity.ResourceProvisionRequirement
  }
  deriving (Eq, Show)

-- | One old phase and the capabilities it becomes. A split names several; a
-- merge shares one with its siblings. Section E requires this map to be
-- complete over the old domain and to reach every new capability.
data AuditEntry = AuditEntry
  { auditOldOrdinal :: Int
  , auditOldPath :: FilePath
  , auditNewCapabilities :: [Text]
  }
  deriving (Eq, Show)

revisedPhases :: [RevisedPhase]
revisedPhases =
  [ RevisedPhase 0 "policy_and_legacy_register" Foundations "NoRegister" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 1 "source_and_document_classifiers" Foundations "NoRegister" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 2 "gate_kernel_and_candidate" Foundations "NoRegister" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 3 "toolchain_and_dependency_probes" Foundations "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 4 "dynamic_resolution_and_vendor_closure" Foundations "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 5 "tracked_root_closure" Foundations "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 6 "naming_and_mutant_registry_closure" Foundations "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 7 "compile_fail_harness" Foundations "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 8 "generation_harness" Foundations "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 9 "core_value_calculi" Algebra "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 10 "workflow_evidence_calculi" Algebra "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 11 "scoped_and_capacity_indices" Algebra "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 12 "calculus_composition" Algebra "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 13 "formal_model_kernel" ProofStack "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 14 "explicit_state_checker" ProofStack "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 15 "symbolic_checker" ProofStack "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 16 "refinement_checker" ProofStack "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 17 "compile_fail_corpus" ProofStack "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 18 "deterministic_sim_substrate" ProofStack "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 19 "gateway_migration_model" ProofStack "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 20 "dsl_formal_model" ProofStack "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 21 "reconcile_core_simulation" ProofStack "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 22 "extension_declaration_and_laws" ExtensionContract "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 23 "compositional_security_and_conformance" ExtensionContract "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 24 "dhall_schema_generation" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 25 "decode_schema_seam" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 26 "decode_ir_seam" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 27 "illegal_state_covering" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 28 "storage_geometry_folds" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 29 "execution_accelerator_folds" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 30 "capability_bind" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 31 "provision_seal" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 32 "inference_accelerator_provision" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 33 "render_manifest_oracles" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 34 "chain_kernel_semantics" GenerativeSurface "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 35 "chain_boundary_fakes" GenerativeSurface "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 36 "image_recipe_generation" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 37 "transaction_vocabulary" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 38 "ui_program_schema" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 39 "ui_authorization_kernel" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 40 "ui_effect_binding" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 41 "ui_plan_compiler" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 42 "offline_language_plan" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 43 "ui_browser_interpreter" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 44 "ui_server_boundary" GenerativeSurface "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 45 "ui_local_composition" GenerativeSurface "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 46 "encrypted_browser_runtime" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 47 "ui_contract_and_tool_corpus" GenerativeSurface "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 48 "test_workflow_algebra" TestAsWorkflow "Register1" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionAbsent
  , RevisedPhase 49 "self_referential_gates" TestAsWorkflow "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 50 "host_assert_cli" PreBinaryAndHost "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 51 "host_ensure_kernel" PreBinaryAndHost "Register2" "NoSubstrate" "NoLane" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 52 "linux_engine_bringup" PreBinaryAndHost "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 53 "apple_engine_bringup" PreBinaryAndHost "Register3" "Apple" "LinuxCpuArm64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 54 "windows_engine_bringup" PreBinaryAndHost "Register3" "Windows" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 55 "bootstrap_coordinator_kind" PreBinaryAndHost "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 56 "base_image_registry" PreBinaryAndHost "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 57 "complementary_arch_child" PreBinaryAndHost "Register3" "Apple" "LinuxCpuArm64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 58 "object_reconciler" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 59 "capacity_scheduler" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 60 "retained_storage" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 61 "vault_pki" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 62 "platform_backbone" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 63 "platform_services_2" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 64 "keycloak_ingress" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 65 "live_dsl_deploy" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 66 "app_tenancy" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 67 "pulsar_client" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 68 "user_tenant_isolation_live" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 69 "content_store_workflow" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 70 "ui_projection_runtime" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 71 "release_lifecycle" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 72 "ui_program_release" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 73 "network_fabric_wireguard" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 74 "multicluster_spawn_georepl" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 75 "gateway_migration_drills" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 76 "provider_deploy_checkpoint" LivePlatform "Register3" "LinuxCpu" "Provider" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 77 "provider_child_bringup" LivePlatform "Register3" "LinuxCpu" "Provider" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 78 "provider_ebs_credential" LivePlatform "Register3" "LinuxCpu" "Provider" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 79 "provider_dynamic_nodes" LivePlatform "Register3" "LinuxCpu" "Provider" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 80 "determinism_kernel" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 81 "jit_cache_runtime" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 82 "ui_live_tenancy_and_rollout" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 83 "ui_ha_multizone" LivePlatform "Register3" "LinuxCpu" "Provider" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 84 "offline_replay_blobs_and_release" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 85 "offline_multizone_continuity" LivePlatform "Register3" "LinuxCpu" "Provider" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 86 "apple_metal_host_daemon" LivePlatform "Register3" "Apple" "Metal" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 87 "test_topology_live" LivePlatform "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 88 "infernix_rederivation_and_ui" DomainInstances "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 89 "jitml_rederivation_and_ui" DomainInstances "Register3" "LinuxCuda" "Cuda" PhaseIdentity.ResourceProvisionRequired
  , RevisedPhase 90 "webapp_rederivation" DomainInstances "Register3" "LinuxCpu" "LinuxCpuAmd64" PhaseIdentity.ResourceProvisionRequired
  ]

auditMap :: [AuditEntry]
auditMap =
  [ AuditEntry 0 "DEVELOPMENT_PLAN/phase_00_documentation_suite.md" ["policy_and_legacy_register", "source_and_document_classifiers", "gate_kernel_and_candidate"]
  , AuditEntry 1 "DEVELOPMENT_PLAN/phase_01_toolchain_spike.md" ["toolchain_and_dependency_probes", "dynamic_resolution_and_vendor_closure"]
  , AuditEntry 2 "DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md" ["tracked_root_closure", "naming_and_mutant_registry_closure"]
  , AuditEntry 3 "DEVELOPMENT_PLAN/phase_03_artifact_calculus.md" ["core_value_calculi"]
  , AuditEntry 4 "DEVELOPMENT_PLAN/phase_04_budget_calculus.md" ["core_value_calculi"]
  , AuditEntry 5 "DEVELOPMENT_PLAN/phase_05_lift_calculus.md" ["core_value_calculi"]
  , AuditEntry 6 "DEVELOPMENT_PLAN/phase_06_workflow_calculus.md" ["workflow_evidence_calculi"]
  , AuditEntry 7 "DEVELOPMENT_PLAN/phase_07_evidence_calculus.md" ["workflow_evidence_calculi"]
  , AuditEntry 8 "DEVELOPMENT_PLAN/phase_08_scope_index.md" ["scoped_and_capacity_indices"]
  , AuditEntry 9 "DEVELOPMENT_PLAN/phase_09_resource_index.md" ["scoped_and_capacity_indices"]
  , AuditEntry 10 "DEVELOPMENT_PLAN/phase_10_calculus_composition.md" ["calculus_composition"]
  , AuditEntry 11 "DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md" ["formal_model_kernel"]
  , AuditEntry 12 "DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md" ["explicit_state_checker"]
  , AuditEntry 13 "DEVELOPMENT_PLAN/phase_13_symbolic_checker.md" ["symbolic_checker"]
  , AuditEntry 14 "DEVELOPMENT_PLAN/phase_14_refinement_checker.md" ["refinement_checker"]
  , AuditEntry 15 "DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md" ["compile_fail_harness", "compile_fail_corpus"]
  , AuditEntry 16 "DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md" ["deterministic_sim_substrate"]
  , AuditEntry 17 "DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md" ["gateway_migration_model"]
  , AuditEntry 18 "DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md" ["dsl_formal_model"]
  , AuditEntry 19 "DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md" ["reconcile_core_simulation"]
  , AuditEntry 20 "DEVELOPMENT_PLAN/phase_20_extension_declaration.md" ["extension_declaration_and_laws"]
  , AuditEntry 21 "DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md" ["extension_declaration_and_laws"]
  , AuditEntry 22 "DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md" ["compositional_security_and_conformance"]
  , AuditEntry 23 "DEVELOPMENT_PLAN/phase_23_extension_security_laws.md" ["compositional_security_and_conformance"]
  , AuditEntry 24 "DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md" ["compositional_security_and_conformance"]
  , AuditEntry 25 "DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md" ["dhall_schema_generation"]
  , AuditEntry 26 "DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md" ["decode_schema_seam", "decode_ir_seam"]
  , AuditEntry 27 "DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md" ["illegal_state_covering"]
  , AuditEntry 28 "DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md" ["storage_geometry_folds"]
  , AuditEntry 29 "DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md" ["execution_accelerator_folds"]
  , AuditEntry 30 "DEVELOPMENT_PLAN/phase_30_capability_bind.md" ["capability_bind"]
  , AuditEntry 31 "DEVELOPMENT_PLAN/phase_31_provision_seal.md" ["provision_seal"]
  , AuditEntry 32 "DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md" ["inference_accelerator_provision"]
  , AuditEntry 33 "DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md" ["render_manifest_oracles"]
  , AuditEntry 34 "DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md" ["chain_kernel_semantics", "chain_boundary_fakes"]
  , AuditEntry 35 "DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md" ["image_recipe_generation"]
  , AuditEntry 36 "DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md" ["transaction_vocabulary"]
  , AuditEntry 37 "DEVELOPMENT_PLAN/phase_37_ui_program_schema.md" ["ui_program_schema"]
  , AuditEntry 38 "DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md" ["ui_authorization_kernel"]
  , AuditEntry 39 "DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md" ["ui_effect_binding"]
  , AuditEntry 40 "DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md" ["ui_plan_compiler"]
  , AuditEntry 41 "DEVELOPMENT_PLAN/phase_41_offline_language_plan.md" ["offline_language_plan"]
  , AuditEntry 42 "DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md" ["ui_browser_interpreter"]
  , AuditEntry 43 "DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md" ["ui_server_boundary"]
  , AuditEntry 44 "DEVELOPMENT_PLAN/phase_44_ui_local_composition.md" ["ui_local_composition"]
  , AuditEntry 45 "DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md" ["encrypted_browser_runtime"]
  , AuditEntry 46 "DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md" ["ui_contract_and_tool_corpus"]
  , AuditEntry 47 "DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md" ["generation_harness", "ui_contract_and_tool_corpus"]
  , AuditEntry 48 "DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md" ["test_workflow_algebra"]
  , AuditEntry 49 "DEVELOPMENT_PLAN/phase_49_self_referential_gates.md" ["self_referential_gates"]
  , AuditEntry 50 "DEVELOPMENT_PLAN/phase_50_host_assert_cli.md" ["host_assert_cli"]
  , AuditEntry 51 "DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md" ["host_ensure_kernel"]
  , AuditEntry 52 "DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md" ["linux_engine_bringup"]
  , AuditEntry 53 "DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md" ["apple_engine_bringup"]
  , AuditEntry 54 "DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md" ["windows_engine_bringup"]
  , AuditEntry 55 "DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md" ["bootstrap_coordinator_kind"]
  , AuditEntry 56 "DEVELOPMENT_PLAN/phase_56_base_image_registry.md" ["base_image_registry"]
  , AuditEntry 57 "DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md" ["complementary_arch_child"]
  , AuditEntry 58 "DEVELOPMENT_PLAN/phase_58_object_reconciler.md" ["object_reconciler"]
  , AuditEntry 59 "DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md" ["capacity_scheduler"]
  , AuditEntry 60 "DEVELOPMENT_PLAN/phase_60_retained_storage.md" ["retained_storage"]
  , AuditEntry 61 "DEVELOPMENT_PLAN/phase_61_vault_pki.md" ["vault_pki"]
  , AuditEntry 62 "DEVELOPMENT_PLAN/phase_62_platform_backbone.md" ["platform_backbone"]
  , AuditEntry 63 "DEVELOPMENT_PLAN/phase_63_platform_services_2.md" ["platform_services_2"]
  , AuditEntry 64 "DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md" ["keycloak_ingress"]
  , AuditEntry 65 "DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md" ["live_dsl_deploy"]
  , AuditEntry 66 "DEVELOPMENT_PLAN/phase_66_app_tenancy.md" ["app_tenancy"]
  , AuditEntry 67 "DEVELOPMENT_PLAN/phase_67_pulsar_client.md" ["pulsar_client"]
  , AuditEntry 68 "DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md" ["user_tenant_isolation_live"]
  , AuditEntry 69 "DEVELOPMENT_PLAN/phase_69_content_store_workflow.md" ["content_store_workflow"]
  , AuditEntry 70 "DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md" ["ui_projection_runtime"]
  , AuditEntry 71 "DEVELOPMENT_PLAN/phase_71_release_lifecycle.md" ["release_lifecycle"]
  , AuditEntry 72 "DEVELOPMENT_PLAN/phase_72_ui_program_release.md" ["ui_program_release"]
  , AuditEntry 73 "DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md" ["network_fabric_wireguard"]
  , AuditEntry 74 "DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md" ["multicluster_spawn_georepl"]
  , AuditEntry 75 "DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md" ["gateway_migration_drills"]
  , AuditEntry 76 "DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md" ["provider_deploy_checkpoint"]
  , AuditEntry 77 "DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md" ["provider_child_bringup"]
  , AuditEntry 78 "DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md" ["provider_ebs_credential"]
  , AuditEntry 79 "DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md" ["provider_dynamic_nodes"]
  , AuditEntry 80 "DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md" ["determinism_kernel", "jit_cache_runtime"]
  , AuditEntry 81 "DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md" ["ui_live_tenancy_and_rollout"]
  , AuditEntry 82 "DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md" ["ui_live_tenancy_and_rollout"]
  , AuditEntry 83 "DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md" ["ui_live_tenancy_and_rollout"]
  , AuditEntry 84 "DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md" ["ui_ha_multizone"]
  , AuditEntry 85 "DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md" ["offline_replay_blobs_and_release"]
  , AuditEntry 86 "DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md" ["offline_replay_blobs_and_release"]
  , AuditEntry 87 "DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md" ["offline_replay_blobs_and_release"]
  , AuditEntry 88 "DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md" ["offline_multizone_continuity"]
  , AuditEntry 89 "DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md" ["apple_metal_host_daemon"]
  , AuditEntry 90 "DEVELOPMENT_PLAN/phase_90_test_topology_live.md" ["test_topology_live"]
  , AuditEntry 91 "DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md" ["infernix_rederivation_and_ui"]
  , AuditEntry 92 "DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md" ["infernix_rederivation_and_ui"]
  , AuditEntry 93 "DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md" ["jitml_rederivation_and_ui"]
  , AuditEntry 94 "DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md" ["jitml_rederivation_and_ui"]
  , AuditEntry 95 "DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md" ["webapp_rederivation"]
  ]

-- | The sprint inventory of every old phase that takes part in a split or a
-- merge, authored here rather than read from the contract parser so the
-- sufficiency check below compares two independently stated things.
--
-- Phases that map one to one are omitted: their component is a single parent
-- and a single capability, which any positive budget satisfies.
sprintBudget :: [(Int, Int)]
sprintBudget =
  [ (0, 8)
  , (1, 8)
  , (2, 6)
  , (3, 1)
  , (4, 1)
  , (5, 1)
  , (6, 1)
  , (7, 1)
  , (8, 1)
  , (9, 1)
  , (15, 2)
  , (20, 1)
  , (21, 1)
  , (22, 1)
  , (23, 1)
  , (24, 1)
  , (26, 5)
  , (34, 9)
  , (46, 1)
  , (47, 1)
  , (80, 8)
  , (81, 1)
  , (82, 1)
  , (83, 1)
  , (85, 1)
  , (86, 1)
  , (87, 1)
  , (91, 1)
  , (92, 1)
  , (93, 1)
  , (94, 1)
  ]

-- | Which of a split parent's sprints each new capability takes.
--
-- The sprint @Blocked by@ chains are strictly linear, so projecting a split
-- through the chain yields a phase edge from the owner of each sprint to the
-- owner of the next. The split stays acyclic exactly when every capability's
-- sprints form a contiguous run: a capability holding sprints 1 and 4 while a
-- sibling holds 2 and 3 puts an edge in both directions, which is the very
-- defect this revision exists to remove.
--
-- The tool-and-mutant phase is the one entry whose corpus half takes no sprint
-- of its own. Its single sprint body divides at @Tools.hs@ against
-- @TestCorpus.hs@, and the corpus half folds into the sprint the UI-contract
-- phase already brings to the same merged capability. That division is
-- authorship, not a reassignment, and it is the only such item in the map.
splitSprintAssignment :: [(Int, [(Text, [Int])])]
splitSprintAssignment =
  [ ( 0
    ,
        [ ("policy_and_legacy_register", [1, 2])
        , ("source_and_document_classifiers", [3, 4])
        , ("gate_kernel_and_candidate", [5, 6, 7, 8])
        ]
    )
  , ( 1
    ,
        [ ("toolchain_and_dependency_probes", [1, 2, 3, 4, 5])
        , ("dynamic_resolution_and_vendor_closure", [6, 7, 8])
        ]
    )
  , ( 2
    ,
        [ ("tracked_root_closure", [1, 2, 3])
        , ("naming_and_mutant_registry_closure", [4, 5, 6])
        ]
    )
  , ( 15
    ,
        [ ("compile_fail_harness", [1])
        , ("compile_fail_corpus", [2])
        ]
    )
  , ( 26
    ,
        [ ("decode_ir_seam", [1, 2])
        , ("decode_schema_seam", [3, 4, 5])
        ]
    )
  , ( 34
    ,
        [ ("chain_kernel_semantics", [1, 2, 3, 4])
        , ("chain_boundary_fakes", [5, 6, 7, 8, 9])
        ]
    )
  , ( 47
    ,
        [ ("generation_harness", [1])
        , ("ui_contract_and_tool_corpus", [])
        ]
    )
  , ( 80
    ,
        [ ("determinism_kernel", [1, 2, 3, 4])
        , ("jit_cache_runtime", [5, 6, 7, 8])
        ]
    )
  ]

planRevisionDiagnostic :: CheckResult
planRevisionDiagnostic =
  CheckResult
    { checkName = "plan-revision"
    , checkObservations =
        [ observation "revision.phase-count" (showText (length revisedPhases))
        , observation "revision.old-phase-count" (showText (length auditMap))
        , observation "revision.split-count" (showText (length splits))
        , observation "revision.merge-count" (showText (length merges))
        , observation "revision.role-ordinals" roleOrdinals
        , observation "revision.sprint-deficit-count" (showText (length sprintDeficits))
        , observation "revision.split-discontiguous-count" (showText (length discontiguousSplits))
        ]
          <> [ observation "revision.band" (showText band <> "=" <> showText (bandSize band))
             | band <- [minBound .. maxBound]
             ]
    , checkFindings =
        cardinalityFindings <> auditFindings <> bandFindings <> roleFindings <> sprintFindings <> permanentRefusal
    }
 where
  ordinals = map revisedOrdinal revisedPhases
  capabilities = map revisedCapability revisedPhases
  reached = nub (concatMap auditNewCapabilities auditMap)
  splits = [entry | entry <- auditMap, length (auditNewCapabilities entry) > 1]
  merges =
    [ capability
    | capability <- nub (concatMap auditNewCapabilities auditMap)
    , length [() | entry <- auditMap, capability `elem` auditNewCapabilities entry] > 1
    ]
  bandSize band = length [() | phase <- revisedPhases, revisedBand phase == band]

  -- Parent-and-capability components. A capability formed by a merge draws
  -- sprints from any of its parents, so sufficiency is a property of the whole
  -- component and never of one parent against the capabilities it becomes.
  -- Reading it the narrower way reports a deficit against the tool-and-mutant
  -- phase that the UI-contract phase it merges with already covers.
  parentsOf capability =
    [auditOldOrdinal entry | entry <- auditMap, capability `elem` auditNewCapabilities entry]
  capabilitiesOf ordinal =
    concat [auditNewCapabilities entry | entry <- auditMap, auditOldOrdinal entry == ordinal]
  closure (parents, caps) =
    let parents' = sort (nub (parents <> concatMap parentsOf caps))
        caps' = sort (nub (caps <> concatMap capabilitiesOf parents))
     in if parents' == parents && caps' == caps then (parents, caps) else closure (parents', caps')
  components =
    nub [closure ([auditOldOrdinal entry], sort (auditNewCapabilities entry)) | entry <- auditMap]
  nonTrivialComponents =
    [component | component@(parents, caps) <- components, length parents > 1 || length caps > 1]
  supplyOf parents = sum [budget | parent <- parents, Just budget <- [lookup parent sprintBudget]]

  budgetAbsent =
    [ parent
    | (parents, _) <- nonTrivialComponents
    , parent <- parents
    , lookup parent sprintBudget == Nothing
    ]
  sprintDeficits =
    [component | component@(parents, caps) <- nonTrivialComponents, supplyOf parents < length caps]

  contiguous sprints =
    case sort (nub sprints) of
      [] -> True
      first : rest -> first : rest == [first .. first + length rest]
  discontiguousSplits =
    [ (ordinal, capability, sprints)
    | (ordinal, assignment) <- splitSprintAssignment
    , (capability, sprints) <- assignment
    , not (contiguous sprints)
    ]

  assignedPath ordinal =
    case [auditOldPath entry | entry <- auditMap, auditOldOrdinal entry == ordinal] of
      path : _ -> path
      [] -> "DEVELOPMENT_PLAN/"
  assignmentProblems =
    [ (ordinal, "no sprint assignment is stated for this split")
    | entry <- splits
    , let ordinal = auditOldOrdinal entry
    , lookup ordinal splitSprintAssignment == Nothing
    ]
      <> [ (ordinal, "the sprint assignment names capabilities the audit map does not")
         | (ordinal, assignment) <- splitSprintAssignment
         , entry <- auditMap
         , auditOldOrdinal entry == ordinal
         , sort (map fst assignment) /= sort (auditNewCapabilities entry)
         ]
      <> [ (ordinal, "the assigned sprints overlap or leave a sprint of the parent unassigned")
         | (ordinal, assignment) <- splitSprintAssignment
         , Just budget <- [lookup ordinal sprintBudget]
         , sort (concatMap snd assignment) /= [1 .. budget]
         ]

  sprintFindings =
    [ finding
        "REVISION-SPRINT-BUDGET-ABSENT"
        "DEVELOPMENT_PLAN/"
        ("phase " <> showText parent <> " takes part in a split or merge but states no sprint budget")
    | parent <- nub budgetAbsent
    ]
      <> [ finding
             "REVISION-SPRINT-DEFICIT"
             "DEVELOPMENT_PLAN/"
             ( "the phases "
                 <> Text.intercalate ", " (map showText parents)
                 <> " supply "
                 <> showText (supplyOf parents)
                 <> " sprint(s) to "
                 <> showText (length caps)
                 <> " capabilities, so this component needs new sprint bodies authored rather than reassigned"
             )
         | (parents, caps) <- sprintDeficits
         ]
      <> [ finding
             "REVISION-SPLIT-DISCONTIGUOUS"
             (assignedPath ordinal)
             ( capability
                 <> " takes sprints "
                 <> Text.intercalate ", " (map showText (sort sprints))
                 <> ", which is not a contiguous run of the parent's linear chain, so the split would put a"
                 <> " dependency edge in both directions between the capabilities it creates"
             )
         | (ordinal, capability, sprints) <- discontiguousSplits
         ]
      <> [ finding "REVISION-SPLIT-ASSIGNMENT" (assignedPath ordinal) detail
         | (ordinal, detail) <- assignmentProblems
         ]

  cardinalityFindings =
    [ finding "REVISION-ORDINALS" "DEVELOPMENT_PLAN/" "revised ordinals must be exactly 0..n-1 in order"
    | ordinals /= [0 .. length revisedPhases - 1]
    ]
      <> [ finding "REVISION-CAPABILITY-DUPLICATE" "DEVELOPMENT_PLAN/" "revised capabilities must be unique"
         | length (nub capabilities) /= length capabilities
         ]

  auditFindings =
    [ finding "REVISION-AUDIT-INCOMPLETE" "DEVELOPMENT_PLAN/" "the audit map must cover every old ordinal exactly once"
    | sort (map auditOldOrdinal auditMap) /= [0 .. length auditMap - 1]
    ]
      <> [ finding "REVISION-AUDIT-UNREACHED" (Text.unpack capability) "a revised capability is reached by no old phase"
         | capability <- capabilities
         , capability `notElem` reached
         ]
      <> [ finding "REVISION-AUDIT-UNKNOWN" (Text.unpack capability) "the audit map names a capability the revised table does not contain"
         | capability <- reached
         , capability `notElem` capabilities
         ]

  bandFindings =
    [ finding "REVISION-BAND-DISCONTIGUOUS" (show band) "a band must occupy one contiguous ordinal range"
    | band <- [minBound .. maxBound]
    , let members = [revisedOrdinal phase | phase <- revisedPhases, revisedBand phase == band]
    , not (null members)
    , members /= [minimum members .. maximum members]
    ]

  -- The four semantic cuts must stay consecutive and in role order. Today's
  -- four literals do not state that invariant at all; a revision that broke it
  -- would otherwise pass every other check here.
  roleFindings =
    [ finding "REVISION-ROLE-ORDER" "DEVELOPMENT_PLAN/" ("role-bearing phases must be consecutive and in role order: " <> roleOrdinals)
    | roleSequence /= Just [minimum' .. minimum' + 3]
    ]
   where
    minimum' = case roleSequence of
      Just (first : _) -> first
      _ -> 0

  roleSequence =
    traverse
      capabilityOrdinal
      [ "self_referential_gates"
      , "host_assert_cli"
      , "host_ensure_kernel"
      , "linux_engine_bringup"
      ]
  roleOrdinals =
    Text.intercalate
      ","
      [ capability <> "=" <> maybe "absent" showText (capabilityOrdinal capability)
      | capability <-
          ["self_referential_gates", "host_assert_cli", "host_ensure_kernel", "linux_engine_bringup"]
      ]
  capabilityOrdinal capability =
    case [revisedOrdinal phase | phase <- revisedPhases, revisedCapability phase == capability] of
      [ordinal] -> Just ordinal
      _ -> Nothing

-- | Dormant by construction: the revision is a proposal, and a proposal that
-- could pass a gate would be a second identity table competing with the one the
-- gate reads.
permanentRefusal :: [Finding]
permanentRefusal =
  [ finding
      "REVISION-PROPOSAL-ONLY"
      "DEVELOPMENT_PLAN/"
      "the revised table is a checked proposal; the present identity table remains authoritative until one indivisible change swaps them"
  ]

showText :: Show value => value -> Text
showText = Text.pack . show
