{-# LANGUAGE OverloadedStrings #-}

-- | The one table that maps a phase capability to the ordinal it currently occupies.
--
-- The plan's domain is @0..9 ∪ 50..95@; ordinals @10..49@ are a reserved gap with no
-- row (decision log DL-0008). Every consumer that once did arithmetic on ordinals —
-- "the predecessor is @n - 1@", "the domain is @0..95@", "the barrier is 49" — asks this
-- table instead, so a re-sequence changes one list and no literal elsewhere.
--
-- This module is data plus total lookups. It carries no gate semantics, evidence,
-- status, or receipt authority.
module Amoebius.Plan.PhaseIdentity
  ( PhaseIdentity
  , PhaseRole (..)
  , ResourceProvisionRequirement (..)
  , allPhaseIdentities
  , allPhaseRoles
  , isPhaseOrdinal
  , lookupCapabilityOrdinal
  , lookupPhaseIdentity
  , phaseDomainLowerOrdinal
  , phaseDomainUpperOrdinal
  , phaseIdentityCapability
  , phaseIdentityIntegrityProblems
  , phaseIdentityOrdinal
  , phaseIdentityPath
  , phaseIdentityResourceProvision
  , phaseOrdinals
  , predecessorOrdinal
  , renderPhaseRole
  , reservedGap
  , roleCapability
  , roleOrdinal
  , successorOrdinal
  ) where

import Data.List (group, sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

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

-- | The ordering roles the plan names, never by ordinal. Each resolves through
-- 'roleOrdinal' to the position its capability currently occupies.
data PhaseRole
  = DslBarrier
  | BootstrapHandoff
  | HostEnsure
  | FirstHardware
  | RegistryBoundary
  deriving (Bounded, Enum, Eq, Ord, Show)

allPhaseRoles :: [PhaseRole]
allPhaseRoles = [minBound .. maxBound]

renderPhaseRole :: PhaseRole -> Text
renderPhaseRole role = case role of
  DslBarrier -> "DSL_BARRIER"
  BootstrapHandoff -> "BOOTSTRAP_HANDOFF"
  HostEnsure -> "HOST_ENSURE"
  FirstHardware -> "FIRST_HARDWARE"
  RegistryBoundary -> "REGISTRY_BOUNDARY"

roleCapability :: PhaseRole -> Text
roleCapability role = case role of
  DslBarrier -> "dsl_barrier"
  BootstrapHandoff -> "host_assert_cli"
  HostEnsure -> "host_ensure_kernel"
  FirstHardware -> "linux_engine_bringup"
  RegistryBoundary -> "base_image_registry"

roleOrdinal :: PhaseRole -> Maybe Int
roleOrdinal = lookupCapabilityOrdinal . roleCapability

-- | The reserved gap: ordinals with no row, occupiable only by a new decision-log
-- entry and a new certification generation.
reservedGap :: (Int, Int)
reservedGap = (10, 49)

allPhaseIdentities :: [PhaseIdentity]
allPhaseIdentities = canonicalPhaseIdentities

phaseOrdinals :: [Int]
phaseOrdinals = map phaseIdentityOrdinal allPhaseIdentities

phaseDomainLowerOrdinal :: Int
phaseDomainLowerOrdinal = minimum phaseOrdinals

phaseDomainUpperOrdinal :: Int
phaseDomainUpperOrdinal = maximum phaseOrdinals

isPhaseOrdinal :: Int -> Bool
isPhaseOrdinal ordinal = Map.member ordinal phaseIdentityByOrdinal

lookupPhaseIdentity :: Int -> Maybe PhaseIdentity
lookupPhaseIdentity ordinal = Map.lookup ordinal phaseIdentityByOrdinal

-- | The reverse projection: a capability to the ordinal it currently occupies.
lookupCapabilityOrdinal :: Text -> Maybe Int
lookupCapabilityOrdinal capability = Map.lookup capability phaseOrdinalByCapability

-- | The previous row of the table, which is the immediate predecessor a gate binds.
-- Phase 50's predecessor is Phase 9; Phase 0 has none.
predecessorOrdinal :: Int -> Maybe Int
predecessorOrdinal ordinal = Map.lookup ordinal predecessorByOrdinal

-- | The next row of the table, which is the phase a pass activates. The last row has none.
successorOrdinal :: Int -> Maybe Int
successorOrdinal ordinal = Map.lookup ordinal successorByOrdinal

predecessorByOrdinal :: Map.Map Int Int
predecessorByOrdinal = Map.fromList (zip (drop 1 phaseOrdinals) phaseOrdinals)

successorByOrdinal :: Map.Map Int Int
successorByOrdinal = Map.fromList (zip phaseOrdinals (drop 1 phaseOrdinals))

phaseOrdinalByCapability :: Map.Map Text Int
phaseOrdinalByCapability =
  Map.fromList
    [ (phaseIdentityCapability identityRow, phaseIdentityOrdinal identityRow)
    | identityRow <- allPhaseIdentities
    ]

phaseIdentityByOrdinal :: Map.Map Int PhaseIdentity
phaseIdentityByOrdinal =
  Map.fromList
    [ (phaseIdentityOrdinal identityRow, identityRow)
    | identityRow <- allPhaseIdentities
    ]

phaseIdentityIntegrityProblems :: [Text]
phaseIdentityIntegrityProblems =
  [ "phase identity cardinality must be exactly " <> showText expectedCardinality
  | length allPhaseIdentities /= expectedCardinality
  ]
    <> [ "phase ordinals must be the reserved-gap domain 0..9 and 50..95 in order"
       | phaseOrdinals /= expectedOrdinals
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
    <> [ "resource provision membership must equal the exact canonical set"
       | actualResourceRequiredOrdinals /= expectedResourceRequiredOrdinals
       ]
    <> [ "phase role capability is not provided by any phase: " <> roleCapability role
       | role <- allPhaseRoles
       , roleOrdinal role == Nothing
       ]
 where
  expectedCardinality = length expectedOrdinals
  expectedOrdinals = [0 .. 9] <> [50 .. 95]
  actualResourceRequiredOrdinals =
    Set.fromList
      [ phaseIdentityOrdinal identityRow
      | identityRow <- allPhaseIdentities
      , phaseIdentityResourceProvision identityRow == ResourceProvisionRequired
      ]
  expectedResourceRequiredOrdinals =
    Set.fromList
      [ ordinal
      | capability <- expectedResourceRequiredCapabilities
      , Just ordinal <- [lookupCapabilityOrdinal capability]
      ]

phasePathMatchesIdentity :: PhaseIdentity -> Bool
phasePathMatchesIdentity identityRow =
  phaseIdentityPath identityRow
    == canonicalPhasePath
      (phaseIdentityOrdinal identityRow)
      (phaseIdentityCapability identityRow)

-- | The phases whose contracts carry a @## Resource provision@ section, named by
-- capability rather than ordinal: the toolchain acquisition and every phase from the
-- bootstrap handoff onward.
expectedResourceRequiredCapabilities :: [Text]
expectedResourceRequiredCapabilities =
  "toolchain_spike"
    : [ phaseIdentityCapability identityRow
      | identityRow <- canonicalPhaseIdentities
      , phaseIdentityOrdinal identityRow >= 50
      ]

canonicalPhaseIdentities :: [PhaseIdentity]
canonicalPhaseIdentities =
  [ identity 0 "documentation_suite" ResourceProvisionAbsent
  , identity 1 "toolchain_spike" ResourceProvisionRequired
  , identity 2 "repository_layout_conformance" ResourceProvisionAbsent
  , identity 3 "typed_spine" ResourceProvisionAbsent
  , identity 4 "witness_manifests_capacity_storage" ResourceProvisionAbsent
  , identity 5 "substrates_lanes_image_recipe" ResourceProvisionAbsent
  , identity 6 "extension_admission_attested_scope" ResourceProvisionAbsent
  , identity 7 "child_clusters_obligation_teardown" ResourceProvisionAbsent
  , identity 8 "ui_program_language_binding" ResourceProvisionAbsent
  , identity 9 "dsl_barrier" ResourceProvisionAbsent
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

showText :: Int -> Text
showText = Text.pack . show

allUnique :: Ord value => [value] -> Bool
allUnique values = all ((== 1) . length) (group (sort values))
