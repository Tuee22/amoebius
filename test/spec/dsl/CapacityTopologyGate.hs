{-# LANGUAGE OverloadedStrings #-}

module CapacityTopologyGate
  ( runCapacityTopologyGate
  ) where

import Amoebius.Capacity.Fold (podFits)
import Amoebius.Capacity.Types
  ( HostEnvironment (..)
  , Node (..)
  , NodeCapacity (..)
  , CpuOvercommitPolicy (..)
  , VolumeAttachment (..)
  , Workload (..)
  )
import Amoebius.Dsl.Topology (ComputeEngine (..), engineAcceptsEnvironment)
import CapacityTopologyFixtures
  ( FixtureCase (..)
  , baseWorkload
  , fixtureCases
  , positiveCases
  , resources
  , tagPlacement
  )
import CapacityTopologyProps (ValidatorMutation (ValidateAll), referenceCompatibility, runCapacityTopologyProps, validatePlacement)
import Control.Monad (forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

data OracleRow = OracleRow
  { oracleCase :: Text
  , oracleExpected :: Text
  , oracleTwin :: Text
  }

data LocusExpectation = Current Text | Deferred Text
  deriving stock (Eq, Show)

runCapacityTopologyGate :: IO ()
runCapacityTopologyGate = do
  let rows = foldOracle
      fixturesByName = Map.fromList [(fixtureName fixture, fixture) | fixture <- fixtureCases]
  assert (length rows == 15) "capacity/topology fold oracle must contain fifteen rows"
  assert (Map.keysSet fixturesByName == Set.fromList (fmap oracleCase rows)) "fixture/oracle case sets diverged"
  forM_ rows $ \row -> case Map.lookup (oracleCase row) fixturesByName of
    Nothing -> fail ("missing fixture: " <> Text.unpack (oracleCase row))
    Just fixture -> do
      assert (fixtureTwin fixture == oracleTwin row) (Text.unpack (oracleCase row) <> " twin drifted")
      assert (fixtureNegative fixture == Left (oracleExpected row)) (Text.unpack (oracleCase row) <> " returned " <> show (fixtureNegative fixture))
      assert (fixturePositive fixture == Right ()) (Text.unpack (oracleCase row) <> " legal twin rejected: " <> show (fixturePositive fixture))
  forM_ positiveCases $ \(name, result) ->
    case result of
      Left problem -> fail (Text.unpack name <> " failed placement: " <> Text.unpack problem)
      Right (topology, workloads, witness) ->
        assert (validatePlacement ValidateAll topology workloads witness == Right ()) (Text.unpack name <> " witness failed independent validation")
  checkCompatibilityOracle
  checkCsiDeduplication
  checkLocusInventory
  runCapacityTopologyProps
  putStrLn "capacity-topology-spec: PASS (15 fold negatives, 15 twins, 2 positives, 9 compatibility pairs, 8 current/3 deferred loci, 4 properties)"

foldOracle :: [OracleRow]
foldOracle =
  [ row "illegal_engine_substrate_mismatch" "EngineSubstrateMismatch" "legal_engine_substrate_pair"
  , row "illegal_rke2_reused_host" "DuplicateHostId" "legal_rke2_distinct_hosts"
  , row "illegal_overcommit_host" "Overcommit:CpuAxis" "legal_host_exact_fit"
  , row "illegal_overcommit_vm" "Overcommit:MemoryAxis" "legal_vm_exact_fit"
  , row "illegal_overcommit_cluster" "Overcommit:PodSlotsAxis" "legal_cluster_pod_slots"
  , row "illegal_cpu_limit_over_policy" "CpuLimitPolicyExceeded" "legal_cpu_limit_policy"
  , row "illegal_pod_ephemeral_overcommit" "Overcommit:EphemeralStorageAxis" "legal_pod_ephemeral_fit"
  , row "illegal_padded_reservation_overcommit" "Overcommit:CpuAxis" "legal_padded_reservation_fit"
  , row "illegal_elastic_pod_exceeds_largest_candidate" "Unschedulable" "legal_elastic_largest_candidate"
  , row "illegal_elastic_class_max_exhausted" "CandidateClassMaximumExceeded" "legal_elastic_class_max"
  , row "illegal_elastic_per_node_overhead_unplaceable" "Unschedulable" "legal_elastic_per_node_overhead"
  , row "illegal_elastic_worst_case_instances_over_quota" "GrowthQuotaExceeded:InstanceCountAxis" "legal_elastic_instance_quota"
  , row "illegal_untolerated_taint" "Unschedulable" "legal_tolerated_taint"
  , row "illegal_memory_backed_underreserved" "PodStorageUnderreserved:MemoryAxis" "legal_memory_backed_reserved"
  , row "illegal_tmpfs_init_persistence_underreserved" "PodStorageUnderreserved:MemoryAxis" "legal_tmpfs_init_persistence_reserved"
  ]
 where
  row = OracleRow

compatibilityOracle :: [(ComputeEngine, HostEnvironment, Bool)]
compatibilityOracle =
  [ (KindEngine, NativeLinux, True)
  , (KindEngine, VirtualizedLinux, True)
  , (KindEngine, ManagedAws, False)
  , (Rke2Engine, NativeLinux, True)
  , (Rke2Engine, VirtualizedLinux, True)
  , (Rke2Engine, ManagedAws, False)
  , (ManagedEksEngine, NativeLinux, False)
  , (ManagedEksEngine, VirtualizedLinux, False)
  , (ManagedEksEngine, ManagedAws, True)
  ]

checkCompatibilityOracle :: IO ()
checkCompatibilityOracle = do
  assert (length compatibilityOracle == 9) "compatibility oracle must enumerate nine pairs"
  forM_ compatibilityOracle $ \(engine, environment, expected) -> do
    assert (referenceCompatibility engine environment == expected) "reference compatibility predicate diverged from authored expectation"
    assert (engineAcceptsEnvironment engine environment == expected) "implementation compatibility predicate diverged from authored expectation"

checkCsiDeduplication :: IO ()
checkCsiDeduplication =
  case podFits workload node of
    Left problem -> assert (tagPlacement problem == "Overcommit:CsiAttachmentsAxis") "CSI challenge returned the wrong axis"
    Right _ -> fail "two distinct CSI claims were admitted against a one-claim node budget"
 where
  node = Node "csi-node" "csi-host" NativeLinux (NodeCapacity (resources 8 8 8 1) NoCpuOvercommit (Map.singleton "csi" 1)) Set.empty
  workload =
    (baseWorkload "csi-workload" (resources 1 1 1 1) (resources 1 1 1 1) (resources 0 0 0 0))
      { workloadAttachments = [VolumeAttachment "csi" "claim-a", VolumeAttachment "csi" "claim-b"] }

checkLocusInventory :: IO ()
checkLocusInventory = do
  let current = [name | Current name <- locusExpectations]
      deferred = [name | Deferred name <- locusExpectations]
  assert (length current == 8 && length deferred == 3) "validation-locus inventory must remain exactly eight current and three deferred"
  assert (Set.size (Set.fromList (current <> deferred)) == 11) "validation-locus inventory contains a duplicate"

locusExpectations :: [LocusExpectation]
locusExpectations =
  [ Current "resource-vector-fit"
  , Current "zero-capable-carve"
  , Current "fixed-placement-witness"
  , Current "elastic-growth-envelope"
  , Current "engine-environment-compatibility"
  , Current "rke2-distinct-hosts"
  , Current "storage-reservation"
  , Current "csi-attachment-deduplication"
  , Deferred "binding-feasibility"
  , Deferred "render-fidelity"
  , Deferred "runtime-fidelity"
  ]

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
