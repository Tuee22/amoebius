{-# LANGUAGE OverloadedStrings #-}

module CapacityTopologyFixtures
  ( FixtureCase (..)
  , fixtureCases
  , positiveCases
  , baseNode
  , baseCandidate
  , baseWorkload
  , resources
  , tagPlacement
  , tagTopology
  ) where

import Amoebius.Capacity.Fold (carve, fits, place)
import Amoebius.Capacity.Types
  ( AvailableCapacity (..)
  , Axis (..)
  , CandidateNodeClass (..)
  , CpuOvercommitPolicy (..)
  , Demand (..)
  , GrowthQuota (..)
  , HostEnvironment (..)
  , Node (..)
  , NodeCapacity (..)
  , Overcommit (..)
  , Placement
  , PlacementError (..)
  , ResourceVector (..)
  , StorageDemand (..)
  , Workload (..)
  , emptyStorageDemand
  , mkResourceEnvelope
  , zeroResources
  )
import Amoebius.Dsl.Topology
  ( ComputeEngine (..)
  , NodeSupply (..)
  , ServerQuorum (..)
  , Topology
  , TopologyError (..)
  , mkRke2Topology
  , mkTopology
  )
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Numeric.Natural (Natural)

data FixtureCase = FixtureCase
  { fixtureName :: Text
  , fixtureTwin :: Text
  , fixtureNegative :: Either Text ()
  , fixturePositive :: Either Text ()
  }

fixtureCases :: [FixtureCase]
fixtureCases =
  [ FixtureCase
      "illegal_engine_substrate_mismatch"
      "legal_engine_substrate_pair"
      (topologyOutcome (mkTopology ManagedEksEngine (FixedSupply (baseNode "native" "host-native" :| []))))
      (topologyOutcome (mkTopology ManagedEksEngine (FixedSupply (managedNode "managed" :| []))))
  , FixtureCase
      "illegal_rke2_reused_host"
      "legal_rke2_distinct_hosts"
      (topologyOutcome (mkRke2Topology SingleServer [baseNode "server" "host-a"] [baseNode "agent" "host-a"]))
      (topologyOutcome (mkRke2Topology SingleServer [baseNode "server" "host-a"] [baseNode "agent" "host-b"]))
  , FixtureCase
      "illegal_overcommit_host"
      "legal_host_exact_fit"
      (overcommitOutcome (fits (Demand (resources 5 2 2 1)) (resources 4 2 2 1)))
      (overcommitOutcome (fits (Demand (resources 4 2 2 1)) (resources 4 2 2 1)))
  , FixtureCase
      "illegal_overcommit_vm"
      "legal_vm_exact_fit"
      (overcommitOutcome (carve (AvailableCapacity (resources 4 8 4 2)) (Demand (resources 4 9 4 2))))
      (overcommitOutcome (carve (AvailableCapacity (resources 4 8 4 2)) (Demand (resources 4 8 4 2))))
  , FixtureCase
      "illegal_overcommit_cluster"
      "legal_cluster_pod_slots"
      (fixedResult (nodeWith (resources 8 8 8 1) NoCpuOvercommit Set.empty) [smallWorkload "slot-a", smallWorkload "slot-b"])
      (fixedResult (nodeWith (resources 8 8 8 2) NoCpuOvercommit Set.empty) [smallWorkload "slot-a", smallWorkload "slot-b"])
  , FixtureCase
      "illegal_cpu_limit_over_policy"
      "legal_cpu_limit_policy"
      (fixedResult (nodeWith (resources 4 8 8 2) NoCpuOvercommit Set.empty) [cpuLimitWorkload "cpu-a", cpuLimitWorkload "cpu-b"])
      (fixedResult (nodeWith (resources 4 8 8 2) (BoundedCpuOvercommit 2) Set.empty) [cpuLimitWorkload "cpu-a", cpuLimitWorkload "cpu-b"])
  , FixtureCase
      "illegal_pod_ephemeral_overcommit"
      "legal_pod_ephemeral_fit"
      (fixedResult (nodeWith (resources 8 8 4 1) NoCpuOvercommit Set.empty) [ephemeralWorkload])
      (fixedResult (nodeWith (resources 8 8 5 1) NoCpuOvercommit Set.empty) [ephemeralWorkload])
  , FixtureCase
      "illegal_padded_reservation_overcommit"
      "legal_padded_reservation_fit"
      (fixedResult (nodeWith (resources 4 8 8 1) (BoundedCpuOvercommit 2) Set.empty) [paddedWorkload])
      (fixedResult (nodeWith (resources 5 8 8 1) (BoundedCpuOvercommit 2) Set.empty) [paddedWorkload])
  , FixtureCase
      "illegal_elastic_pod_exceeds_largest_candidate"
      "legal_elastic_largest_candidate"
      (elasticResult (baseCandidate {candidateCapacity = capacity (resources 4 8 8 2)}) (GrowthQuota 2 8) [largeWorkload])
      (elasticResult (baseCandidate {candidateCapacity = capacity (resources 5 8 8 2)}) (GrowthQuota 2 10) [largeWorkload])
  , FixtureCase
      "illegal_elastic_class_max_exhausted"
      "legal_elastic_class_max"
      (elasticResult (baseCandidate {candidateMaxCount = 1}) (GrowthQuota 3 12) [threeCpu "class-a", threeCpu "class-b"])
      (elasticResult (baseCandidate {candidateMaxCount = 2}) (GrowthQuota 3 12) [threeCpu "class-a", threeCpu "class-b"])
  , FixtureCase
      "illegal_elastic_per_node_overhead_unplaceable"
      "legal_elastic_per_node_overhead"
      (elasticResult (baseCandidate {candidatePerNodeDemand = resources 1 0 0 0}) (GrowthQuota 2 8) [fourCpu])
      (elasticResult (baseCandidate {candidatePerNodeDemand = zeroResources}) (GrowthQuota 2 8) [fourCpu])
  , FixtureCase
      "illegal_elastic_worst_case_instances_over_quota"
      "legal_elastic_instance_quota"
      (elasticResult (baseCandidate {candidateMaxCount = 2}) (GrowthQuota 1 8) [antiWorkload "quota-a", antiWorkload "quota-b"])
      (elasticResult (baseCandidate {candidateMaxCount = 2}) (GrowthQuota 2 8) [antiWorkload "quota-a", antiWorkload "quota-b"])
  , FixtureCase
      "illegal_untolerated_taint"
      "legal_tolerated_taint"
      (fixedResult (nodeWith (resources 4 8 8 1) NoCpuOvercommit (Set.singleton "dedicated")) [smallWorkload "tainted"])
      (fixedResult (nodeWith (resources 4 8 8 1) NoCpuOvercommit (Set.singleton "dedicated")) [(smallWorkload "tainted") {workloadTolerations = Set.singleton "dedicated"}])
  , FixtureCase
      "illegal_memory_backed_underreserved"
      "legal_memory_backed_reserved"
      (fixedResult baseFitNode [storageWorkload "memory-backed" 2 2 1 True])
      (fixedResult baseFitNode [storageWorkload "memory-backed" 3 2 1 True])
  , FixtureCase
      "illegal_tmpfs_init_persistence_underreserved"
      "legal_tmpfs_init_persistence_reserved"
      (fixedResult baseFitNode [storageWorkload "tmpfs-persistence" 3 2 2 True])
      (fixedResult baseFitNode [storageWorkload "tmpfs-persistence" 3 2 2 False])
  ]

positiveCases :: [(Text, Either Text (Topology, [Workload], Placement))]
positiveCases =
  [ ("legal_multisubstrate_cluster", positiveFixed)
  , ("legal_managed_eks", positiveElastic)
  ]

positiveFixed :: Either Text (Topology, [Workload], Placement)
positiveFixed = do
  topology <- firstTopology (mkTopology Rke2Engine (FixedSupply (baseNode "linux" "host-linux" :| [virtualNode "lima" "host-lima"])))
  let workloads = [smallWorkload "fixed-a", smallWorkload "fixed-b"]
  placement <- firstPlacement (place topology workloads)
  pure (topology, workloads, placement)

positiveElastic :: Either Text (Topology, [Workload], Placement)
positiveElastic = do
  topology <- firstTopology (mkTopology ManagedEksEngine (ElasticSupply [] (baseCandidate {candidateMaxCount = 2} :| []) (GrowthQuota 2 8)))
  let workloads = [antiWorkload "elastic-a", antiWorkload "elastic-b"]
  placement <- firstPlacement (place topology workloads)
  pure (topology, workloads, placement)

baseNode :: Text -> Text -> Node
baseNode name host = Node name host NativeLinux (capacity (resources 8 16 16 8)) Set.empty

virtualNode :: Text -> Text -> Node
virtualNode name host = Node name host VirtualizedLinux (capacity (resources 8 16 16 8)) Set.empty

managedNode :: Text -> Node
managedNode name = Node name name ManagedAws (capacity (resources 8 16 16 8)) Set.empty

nodeWith :: ResourceVector -> CpuOvercommitPolicy -> Set.Set Text -> Node
nodeWith allocatable policy taints = Node "node" "host" NativeLinux (capacityWithPolicy allocatable policy) taints

baseFitNode :: Node
baseFitNode = nodeWith (resources 8 8 8 2) NoCpuOvercommit Set.empty

capacity :: ResourceVector -> NodeCapacity
capacity value = capacityWithPolicy value NoCpuOvercommit

capacityWithPolicy :: ResourceVector -> CpuOvercommitPolicy -> NodeCapacity
capacityWithPolicy value policy = NodeCapacity value policy (Map.fromList [("csi", 4)])

baseCandidate :: CandidateNodeClass
baseCandidate =
  CandidateNodeClass
    { candidateName = "standard"
    , candidateEnvironment = ManagedAws
    , candidateCapacity = capacityWithPolicy (resources 4 8 8 4) (BoundedCpuOvercommit 2)
    , candidatePerNodeDemand = zeroResources
    , candidateTaints = Set.empty
    , candidateBaseCount = 0
    , candidateMaxCount = 2
    , candidateQuotaVcpu = 4
    }

resources :: Natural -> Natural -> Natural -> Natural -> ResourceVector
resources = ResourceVector

baseWorkload :: Text -> ResourceVector -> ResourceVector -> ResourceVector -> Workload
baseWorkload name requests limits padding =
  case mkResourceEnvelope requests limits padding of
    Left _ -> fallback
    Right envelope ->
      Workload name envelope emptyStorageDemand [] Set.empty Nothing
 where
  fallback =
    case mkResourceEnvelope zeroResources zeroResources zeroResources of
      Left _ -> baseWorkload name zeroResources zeroResources zeroResources
      Right envelope -> Workload name envelope emptyStorageDemand [] Set.empty Nothing

smallWorkload :: Text -> Workload
smallWorkload name = baseWorkload name (resources 1 1 1 1) (resources 1 1 1 1) zeroResources

cpuLimitWorkload :: Text -> Workload
cpuLimitWorkload name = baseWorkload name (resources 1 1 1 1) (resources 3 1 1 1) zeroResources

ephemeralWorkload :: Workload
ephemeralWorkload = baseWorkload "ephemeral" (resources 1 1 5 1) (resources 1 1 5 1) zeroResources

paddedWorkload :: Workload
paddedWorkload = baseWorkload "padded" (resources 3 1 1 1) (resources 5 1 1 1) (resources 2 0 0 0)

largeWorkload :: Workload
largeWorkload = baseWorkload "large" (resources 5 1 1 1) (resources 5 1 1 1) zeroResources

threeCpu :: Text -> Workload
threeCpu name = baseWorkload name (resources 3 1 1 1) (resources 3 1 1 1) zeroResources

fourCpu :: Workload
fourCpu = baseWorkload "four-cpu" (resources 4 1 1 1) (resources 4 1 1 1) zeroResources

antiWorkload :: Text -> Workload
antiWorkload name = (threeCpu name) {workloadAntiAffinity = Just "spread"}

storageWorkload :: Text -> Natural -> Natural -> Natural -> Bool -> Workload
storageWorkload name requestedMemory initBytes appBytes persists =
  (baseWorkload name (resources 1 requestedMemory 1 1) (resources 1 requestedMemory 1 1) zeroResources)
    { workloadStorage = StorageDemand 0 0 initBytes appBytes persists
    }

fixedResult :: Node -> [Workload] -> Either Text ()
fixedResult node workloads = do
  topology <- firstTopology (mkTopology Rke2Engine (FixedSupply (node :| [])))
  placementOutcome (place topology workloads)

elasticResult :: CandidateNodeClass -> GrowthQuota -> [Workload] -> Either Text ()
elasticResult candidate quota workloads = do
  topology <- firstTopology (mkTopology ManagedEksEngine (ElasticSupply [] (candidate :| []) quota))
  placementOutcome (place topology workloads)

topologyOutcome :: Either TopologyError Topology -> Either Text ()
topologyOutcome result = case result of
  Left problem -> Left (tagTopology problem)
  Right _ -> Right ()

overcommitOutcome :: Either Overcommit value -> Either Text ()
overcommitOutcome result = case result of
  Left problem -> Left ("Overcommit:" <> axisTag (overcommitAxis problem))
  Right _ -> Right ()

placementOutcome :: Either PlacementError value -> Either Text ()
placementOutcome result = case result of
  Left problem -> Left (tagPlacement problem)
  Right _ -> Right ()

firstTopology :: Either TopologyError value -> Either Text value
firstTopology result = case result of
  Left problem -> Left (tagTopology problem)
  Right value -> Right value

firstPlacement :: Either PlacementError value -> Either Text value
firstPlacement result = case result of
  Left problem -> Left (tagPlacement problem)
  Right value -> Right value

tagTopology :: TopologyError -> Text
tagTopology problem = case problem of
  EngineSubstrateMismatch _ -> "EngineSubstrateMismatch"
  DuplicateHostId _ -> "DuplicateHostId"
  EmptyRke2Topology -> "EmptyRke2Topology"

tagPlacement :: PlacementError -> Text
tagPlacement problem = case problem of
  CapacityOvercommit overcommit -> "Overcommit:" <> axisTag (overcommitAxis overcommit)
  Unschedulable _ -> "Unschedulable"
  CpuLimitPolicyExceeded {} -> "CpuLimitPolicyExceeded"
  InvalidResourceEnvelope overcommit -> "InvalidResourceEnvelope:" <> axisTag (overcommitAxis overcommit)
  PodStorageUnderreserved _ axis _ _ -> "PodStorageUnderreserved:" <> axisTag axis
  GrowthQuotaExceeded axis _ _ -> "GrowthQuotaExceeded:" <> axisTag axis
  CandidateClassMaximumExceeded {} -> "CandidateClassMaximumExceeded"
  IneligibleNode {} -> "IneligibleNode"

axisTag :: Axis -> Text
axisTag axis = case axis of
  CpuAxis -> "CpuAxis"
  MemoryAxis -> "MemoryAxis"
  EphemeralStorageAxis -> "EphemeralStorageAxis"
  PodSlotsAxis -> "PodSlotsAxis"
  CsiAttachmentsAxis _ -> "CsiAttachmentsAxis"
  InstanceCountAxis -> "InstanceCountAxis"
  VcpuQuotaAxis -> "VcpuQuotaAxis"
  ClassMaximumAxis _ -> "ClassMaximumAxis"
