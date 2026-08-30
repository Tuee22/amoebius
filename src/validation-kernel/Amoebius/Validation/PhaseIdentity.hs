{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PhaseIdentity
  ( PhaseIdentity
  , ResourceProvisionRequirement (..)
  , allPhaseIdentities
  , lookupCapabilityOrdinal
  , lookupPhaseIdentity
  , phaseIdentityCapability
  , phaseIdentityIntegrityProblems
  , phaseIdentityOrdinal
  , phaseIdentityPath
  , phaseIdentityResourceProvision
  ) where

import Data.List (group, sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- This is a package-internal identity universe.  It owns only closed,
-- machine-decidable phase identity and resource-section selection; it carries
-- no gate semantics, evidence, review state, or gate-pass result.

data ResourceProvisionRequirement
  = ResourceProvisionAbsent
  | ResourceProvisionRequired
  deriving (Eq, Ord, Show)

data PhaseIdentity = PhaseIdentity
  { phaseIdentityOrdinal :: Int
  , phaseIdentityCapability :: Text
  , phaseIdentityPath :: FilePath
  , phaseIdentityResourceProvision :: ResourceProvisionRequirement
  }
  deriving (Eq, Show)

allPhaseIdentities :: [PhaseIdentity]
allPhaseIdentities = map applyIdentityMutants canonicalPhaseIdentities

lookupPhaseIdentity :: Int -> Maybe PhaseIdentity
lookupPhaseIdentity ordinal = Map.lookup ordinal phaseIdentityByOrdinal

-- | The reverse projection: a phase capability to the ordinal it currently
-- occupies.
--
-- Capability is the stable identity; the ordinal is a coordinate of the plan's
-- present order. A consumer that names a capability keeps naming the right
-- phase after a reorder, which an ordinal literal does not.
lookupCapabilityOrdinal :: Text -> Maybe Int
lookupCapabilityOrdinal capability = Map.lookup capability phaseOrdinalByCapability

phaseOrdinalByCapability :: Map.Map Text Int
phaseOrdinalByCapability =
  Map.fromList
    [ (phaseIdentityCapability identityRow, phaseIdentityOrdinal identityRow)
    | identityRow <- allPhaseIdentities
    ]

phaseIdentityIntegrityProblems :: [Text]
phaseIdentityIntegrityProblems =
  [ "phase identity cardinality must be exactly 96"
  | length allPhaseIdentities /= 96
  ]
    <> [ "resource-required capability is not provided by any phase: " <> capability
       | capability <- unresolvedResourceRequiredCapabilities
       ]
    <> [ "phase identity ordinals must be exactly 0 through 95 in order"
       | map phaseIdentityOrdinal allPhaseIdentities /= [0 .. 95]
       ]
    <> [ "phase capability identifiers must be unique"
       | not (allUnique (map phaseIdentityCapability allPhaseIdentities))
       ]
    <> [ "phase paths must be unique"
       | not (allUnique (map phaseIdentityPath allPhaseIdentities))
       ]
    <> [ "every phase path must be the exact ordinal/capability projection"
       | not (all phasePathMatchesIdentity allPhaseIdentities)
       ]
    <> [ "resource provision requirement literals must contain exactly 55 unique ordinals"
       | length expectedResourceRequiredOrdinalLiterals /= 55
           || Set.size expectedResourceRequiredOrdinals /= 55
       ]
    <> [ "resource provision membership must equal the exact canonical 55-phase set"
       | actualResourceRequiredOrdinals /= expectedResourceRequiredOrdinals
       ]
 where
  actualResourceRequiredOrdinals =
    Set.fromList
      [ phaseIdentityOrdinal identityRow
      | identityRow <- allPhaseIdentities
      , phaseIdentityResourceProvision identityRow == ResourceProvisionRequired
      ]

phaseIdentityByOrdinal :: Map.Map Int PhaseIdentity
phaseIdentityByOrdinal =
  Map.fromList
    [ (phaseIdentityOrdinal identityRow, identityRow)
    | identityRow <- allPhaseIdentities
    ]

applyIdentityMutants :: PhaseIdentity -> PhaseIdentity
applyIdentityMutants = resourceMembershipDrift . pathDrift
 where
#ifdef VALIDATION_PHASE_IDENTITY_PATH_DRIFT_MUTANT
  pathDrift identityRow
    | phaseIdentityOrdinal identityRow == 43 =
        identityRow {phaseIdentityPath = "DEVELOPMENT_PLAN/phase_43_resource-path-drift.md"}
    | otherwise = identityRow
#else
  pathDrift = id
#endif
#ifdef VALIDATION_PHASE_IDENTITY_RESOURCE_MEMBERSHIP_DRIFT_MUTANT
  resourceMembershipDrift identityRow
    | phaseIdentityOrdinal identityRow == 43 =
        identityRow {phaseIdentityResourceProvision = ResourceProvisionAbsent}
    | phaseIdentityOrdinal identityRow == 48 =
        identityRow {phaseIdentityResourceProvision = ResourceProvisionRequired}
    | otherwise = identityRow
#else
  resourceMembershipDrift = id
#endif

phasePathMatchesIdentity :: PhaseIdentity -> Bool
phasePathMatchesIdentity identityRow =
  phaseIdentityPath identityRow
    == canonicalPhasePath
      (phaseIdentityOrdinal identityRow)
      (phaseIdentityCapability identityRow)

expectedResourceRequiredOrdinals :: Set.Set Int
expectedResourceRequiredOrdinals =
  Set.fromList expectedResourceRequiredOrdinalLiterals

-- | The phases that must declare a resource-provision contract, named by
-- capability rather than by ordinal.
--
-- Membership is a property of what a phase does, not of where it sits, so a
-- reorder must not silently move the requirement onto a different phase. The
-- ordinal set below is derived; an unknown capability is reported by
-- 'phaseIdentityIntegrityProblems' rather than dropped.
expectedResourceRequiredCapabilities :: [Text]
expectedResourceRequiredCapabilities =
  [ "toolchain_spike",
    "symbolic_checker",
    "refinement_checker",
    "compile_fail_harness",
    "dhall_schema_generation",
    "illegal_state_covering",
    "chain_kernel_boundary",
    "ui_server_boundary",
    "self_referential_gates",
    "host_assert_cli",
    "host_ensure_kernel",
    "linux_engine_bringup",
    "apple_engine_bringup",
    "windows_engine_bringup",
    "bootstrap_coordinator_kind",
    "base_image_registry",
    "complementary_arch_child",
    "object_reconciler",
    "capacity_scheduler",
    "retained_storage",
    "vault_pki",
    "platform_backbone",
    "platform_services_2",
    "keycloak_ingress",
    "live_dsl_deploy",
    "app_tenancy",
    "pulsar_client",
    "user_tenant_isolation_live",
    "content_store_workflow",
    "ui_projection_runtime",
    "release_lifecycle",
    "ui_program_release",
    "network_fabric_wireguard",
    "multicluster_spawn_georepl",
    "gateway_migration_drills",
    "provider_deploy_checkpoint",
    "provider_child_bringup",
    "provider_ebs_credential",
    "provider_dynamic_nodes",
    "determinism_jitcache",
    "ui_single_tenant_live",
    "ui_multi_tenant_live",
    "ui_rollout_reconnect",
    "ui_ha_multizone",
    "offline_replay_receipts",
    "offline_blobs_isolation",
    "offline_release_evolution",
    "offline_multizone_continuity",
    "apple_metal_host_daemon",
    "test_topology_live",
    "infernix_rederivation",
    "infernix_ui_rederivation",
    "jitml_rederivation",
    "jitml_ui_rederivation",
    "webapp_rederivation"
  ]

expectedResourceRequiredOrdinalLiterals :: [Int]
expectedResourceRequiredOrdinalLiterals =
  [ ordinal
  | capability <- expectedResourceRequiredCapabilities
  , Just ordinal <- [lookupCapabilityOrdinal capability]
  ]

unresolvedResourceRequiredCapabilities :: [Text]
unresolvedResourceRequiredCapabilities =
  [ capability
  | capability <- expectedResourceRequiredCapabilities
  , lookupCapabilityOrdinal capability == Nothing
  ]

canonicalPhaseIdentities :: [PhaseIdentity]
canonicalPhaseIdentities =
  [ identity 0 "documentation_suite" ResourceProvisionAbsent
  , identity 1 "toolchain_spike" ResourceProvisionRequired
  , identity 2 "repository_layout_conformance" ResourceProvisionAbsent
  , identity 3 "artifact_calculus" ResourceProvisionAbsent
  , identity 4 "budget_calculus" ResourceProvisionAbsent
  , identity 5 "lift_calculus" ResourceProvisionAbsent
  , identity 6 "workflow_calculus" ResourceProvisionAbsent
  , identity 7 "evidence_calculus" ResourceProvisionAbsent
  , identity 8 "scope_index" ResourceProvisionAbsent
  , identity 9 "resource_index" ResourceProvisionAbsent
  , identity 10 "calculus_composition" ResourceProvisionAbsent
  , identity 11 "formal_model_kernel" ResourceProvisionAbsent
  , identity 12 "explicit_state_checker" ResourceProvisionAbsent
  , identity 13 "symbolic_checker" ResourceProvisionRequired
  , identity 14 "refinement_checker" ResourceProvisionRequired
  , identity 15 "compile_fail_harness" ResourceProvisionRequired
  , identity 16 "deterministic_sim_substrate" ResourceProvisionAbsent
  , identity 17 "gateway_migration_model" ResourceProvisionAbsent
  , identity 18 "dsl_formal_model" ResourceProvisionAbsent
  , identity 19 "reconcile_core_simulation" ResourceProvisionAbsent
  , identity 20 "extension_declaration" ResourceProvisionAbsent
  , identity 21 "extension_laws_per_extension" ResourceProvisionAbsent
  , identity 22 "extension_laws_compositional" ResourceProvisionAbsent
  , identity 23 "extension_security_laws" ResourceProvisionAbsent
  , identity 24 "conformance_gate_generator" ResourceProvisionAbsent
  , identity 25 "dhall_schema_generation" ResourceProvisionRequired
  , identity 26 "gadt_decode_ir" ResourceProvisionAbsent
  , identity 27 "illegal_state_covering" ResourceProvisionRequired
  , identity 28 "storage_geometry_folds" ResourceProvisionAbsent
  , identity 29 "execution_accelerator_folds" ResourceProvisionAbsent
  , identity 30 "capability_bind" ResourceProvisionAbsent
  , identity 31 "provision_seal" ResourceProvisionAbsent
  , identity 32 "inference_accelerator_provision" ResourceProvisionAbsent
  , identity 33 "render_manifest_oracles" ResourceProvisionAbsent
  , identity 34 "chain_kernel_boundary" ResourceProvisionRequired
  , identity 35 "image_recipe_generation" ResourceProvisionAbsent
  , identity 36 "transaction_vocabulary" ResourceProvisionAbsent
  , identity 37 "ui_program_schema" ResourceProvisionAbsent
  , identity 38 "ui_authorization_kernel" ResourceProvisionAbsent
  , identity 39 "ui_effect_binding" ResourceProvisionAbsent
  , identity 40 "ui_plan_compiler" ResourceProvisionAbsent
  , identity 41 "offline_language_plan" ResourceProvisionAbsent
  , identity 42 "ui_browser_interpreter" ResourceProvisionAbsent
  , identity 43 "ui_server_boundary" ResourceProvisionRequired
  , identity 44 "ui_local_composition" ResourceProvisionAbsent
  , identity 45 "encrypted_browser_runtime" ResourceProvisionAbsent
  , identity 46 "ui_contract_generation" ResourceProvisionAbsent
  , identity 47 "tool_and_mutant_generation" ResourceProvisionAbsent
  , identity 48 "test_workflow_algebra" ResourceProvisionAbsent
  , identity 49 "self_referential_gates" ResourceProvisionRequired
  , identity 50 "host_assert_cli" ResourceProvisionRequired
  , identity 51 "host_ensure_kernel" ResourceProvisionRequired
  , identity 52 "linux_engine_bringup" ResourceProvisionRequired
  , identity 53 "apple_engine_bringup" ResourceProvisionRequired
  , identity 54 "windows_engine_bringup" ResourceProvisionRequired
  , identity 55 "bootstrap_coordinator_kind" ResourceProvisionRequired
  , identity 56 "base_image_registry" ResourceProvisionRequired
  , identity 57 "complementary_arch_child" ResourceProvisionRequired
  , identity 58 "object_reconciler" ResourceProvisionRequired
  , identity 59 "capacity_scheduler" ResourceProvisionRequired
  , identity 60 "retained_storage" ResourceProvisionRequired
  , identity 61 "vault_pki" ResourceProvisionRequired
  , identity 62 "platform_backbone" ResourceProvisionRequired
  , identity 63 "platform_services_2" ResourceProvisionRequired
  , identity 64 "keycloak_ingress" ResourceProvisionRequired
  , identity 65 "live_dsl_deploy" ResourceProvisionRequired
  , identity 66 "app_tenancy" ResourceProvisionRequired
  , identity 67 "pulsar_client" ResourceProvisionRequired
  , identity 68 "user_tenant_isolation_live" ResourceProvisionRequired
  , identity 69 "content_store_workflow" ResourceProvisionRequired
  , identity 70 "ui_projection_runtime" ResourceProvisionRequired
  , identity 71 "release_lifecycle" ResourceProvisionRequired
  , identity 72 "ui_program_release" ResourceProvisionRequired
  , identity 73 "network_fabric_wireguard" ResourceProvisionRequired
  , identity 74 "multicluster_spawn_georepl" ResourceProvisionRequired
  , identity 75 "gateway_migration_drills" ResourceProvisionRequired
  , identity 76 "provider_deploy_checkpoint" ResourceProvisionRequired
  , identity 77 "provider_child_bringup" ResourceProvisionRequired
  , identity 78 "provider_ebs_credential" ResourceProvisionRequired
  , identity 79 "provider_dynamic_nodes" ResourceProvisionRequired
  , identity 80 "determinism_jitcache" ResourceProvisionRequired
  , identity 81 "ui_single_tenant_live" ResourceProvisionRequired
  , identity 82 "ui_multi_tenant_live" ResourceProvisionRequired
  , identity 83 "ui_rollout_reconnect" ResourceProvisionRequired
  , identity 84 "ui_ha_multizone" ResourceProvisionRequired
  , identity 85 "offline_replay_receipts" ResourceProvisionRequired
  , identity 86 "offline_blobs_isolation" ResourceProvisionRequired
  , identity 87 "offline_release_evolution" ResourceProvisionRequired
  , identity 88 "offline_multizone_continuity" ResourceProvisionRequired
  , identity 89 "apple_metal_host_daemon" ResourceProvisionRequired
  , identity 90 "test_topology_live" ResourceProvisionRequired
  , identity 91 "infernix_rederivation" ResourceProvisionRequired
  , identity 92 "infernix_ui_rederivation" ResourceProvisionRequired
  , identity 93 "jitml_rederivation" ResourceProvisionRequired
  , identity 94 "jitml_ui_rederivation" ResourceProvisionRequired
  , identity 95 "webapp_rederivation" ResourceProvisionRequired
  ]

identity :: Int -> Text -> ResourceProvisionRequirement -> PhaseIdentity
identity ordinal capability resourceRequirement =
  PhaseIdentity
    { phaseIdentityOrdinal = ordinal
    , phaseIdentityCapability = capability
    , phaseIdentityPath = canonicalPhasePath ordinal capability
    , phaseIdentityResourceProvision = resourceRequirement
    }

canonicalPhasePath :: Int -> Text -> FilePath
canonicalPhasePath ordinal capability =
  "DEVELOPMENT_PLAN/phase_"
    <> Text.unpack (renderOrdinal ordinal)
    <> "_"
    <> Text.unpack capability
    <> ".md"

renderOrdinal :: Int -> Text
renderOrdinal ordinal = Text.justifyRight 2 '0' (Text.pack (show ordinal))

allUnique :: Ord value => [value] -> Bool
allUnique values = all ((== 1) . length) (group (sort values))
