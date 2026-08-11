{-# LANGUAGE OverloadedStrings #-}

module CapacityTopologyMutants
  ( runCapacityMutant
  ) where

import Amoebius.Capacity.Types
  ( Assignment (..)
  , CpuOvercommitPolicy (..)
  , HostEnvironment (..)
  , MaterializedNode (..)
  , Node (..)
  , NodeCapacity (..)
  , Placement (..)
  , PlacementKind (..)
  , VolumeAttachment (..)
  , Workload (..)
  )
import Amoebius.Dsl.Topology (ComputeEngine (Rke2Engine), NodeSupply (FixedSupply), mkTopology)
import CapacityTopologyFixtures (FixtureCase (..), baseWorkload, fixtureCases, resources)
import CapacityTopologyProps (ValidatorMutation (..), validatePlacement)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)

runCapacityMutant :: Text -> IO Bool
runCapacityMutant mutant = pure $ case mutant of
  "fits-drop-memory" -> twinSurvives "illegal_overcommit_vm"
  "carve-skip-subtraction" -> twinSurvives "illegal_overcommit_host"
  "fixed-place-admit-overcommit" -> twinSurvives "illegal_overcommit_cluster"
  "elastic-place-unconditional-right" -> twinSurvives "illegal_elastic_pod_exceeds_largest_candidate"
  "compatibility-admit-all" -> twinSurvives "illegal_engine_substrate_mismatch"
  "rke2-allow-duplicate-host" -> twinSurvives "illegal_rke2_reused_host"
  "pod-drop-ephemeral" -> twinSurvives "illegal_pod_ephemeral_overcommit"
  "cpu-policy-ignore" -> twinSurvives "illegal_cpu_limit_over_policy"
  "elastic-ignore-class-max" -> twinSurvives "illegal_elastic_class_max_exhausted"
  "elastic-drop-per-node" -> twinSurvives "illegal_elastic_per_node_overhead_unplaceable"
  "taint-ignore" -> twinSurvives "illegal_untolerated_taint"
  "memory-backed-drop" -> twinSurvives "illegal_memory_backed_underreserved"
  "tmpfs-persistence-drop" -> twinSurvives "illegal_tmpfs_init_persistence_underreserved"
  "headroom-pad-drop" -> twinSurvives "illegal_padded_reservation_overcommit"
  "validator-drop-cpu" -> validatorSurvives DropCpuValidation CpuInvalid
  "validator-drop-memory" -> validatorSurvives DropMemoryValidation MemoryInvalid
  "validator-drop-ephemeral" -> validatorSurvives DropEphemeralValidation EphemeralInvalid
  "validator-drop-slots" -> validatorSurvives DropSlotValidation SlotsInvalid
  "validator-drop-csi-dedup" -> validatorSurvives DropCsiValidation CsiInvalid
  _ -> True

twinSurvives :: Text -> Bool
twinSurvives name = case findFixture name fixtureCases of
  Nothing -> True
  Just fixture -> fixturePositive fixture == fixtureNegative fixture

findFixture :: Text -> [FixtureCase] -> Maybe FixtureCase
findFixture name fixtures = case fixtures of
  [] -> Nothing
  fixture : remaining
    | fixtureName fixture == name -> Just fixture
    | otherwise -> findFixture name remaining

data InvalidAxis = CpuInvalid | MemoryInvalid | EphemeralInvalid | SlotsInvalid | CsiInvalid

validatorSurvives :: ValidatorMutation -> InvalidAxis -> Bool
validatorSurvives mutation invalidAxis = case mkTopology Rke2Engine (FixedSupply (node :| [])) of
  Left _ -> True
  Right topology -> validatePlacement mutation topology [workload] witness /= Right ()
 where
  (allocatable, requests) = case invalidAxis of
    CpuInvalid -> (resources 4 8 8 1, resources 5 1 1 1)
    MemoryInvalid -> (resources 8 4 8 1, resources 1 5 1 1)
    EphemeralInvalid -> (resources 8 8 4 1, resources 1 1 5 1)
    SlotsInvalid -> (resources 8 8 8 0, resources 1 1 1 1)
    CsiInvalid -> (resources 8 8 8 1, resources 1 1 1 1)
  base = baseWorkload "invalid" requests requests (resources 0 0 0 0)
  workload = case invalidAxis of
    CsiInvalid -> base {workloadAttachments = [VolumeAttachment "csi" "claim-a", VolumeAttachment "csi" "claim-b"]}
    _ -> base
  node = Node "invalid-node" "invalid-host" NativeLinux (NodeCapacity allocatable NoCpuOvercommit (Map.singleton "csi" 1)) Set.empty
  witness =
    Placement
      { placementKind = FixedPlacement
      , placementNodes = [MaterializedNode node Nothing]
      , placementAssignments = [Assignment "invalid" "invalid-node"]
      , placementInstances = 1
      , placementVcpu = 8
      }
