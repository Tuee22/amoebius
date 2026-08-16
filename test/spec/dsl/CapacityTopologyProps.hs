{-# LANGUAGE OverloadedStrings #-}

module CapacityTopologyProps
  ( ValidatorMutation (..)
  , runCapacityTopologyProps
  , validatePlacement
  , referenceCompatibility
  ) where

import Amoebius.Capacity.Fold (carve, fits, place)
import Amoebius.Capacity.Types
  ( Assignment (..)
  , AvailableCapacity (..)
  , CandidateNodeClass (..)
  , CpuOvercommitPolicy (..)
  , Demand (..)
  , GrowthQuota (..)
  , HostEnvironment (..)
  , MaterializedNode (..)
  , Node (..)
  , NodeCapacity (..)
  , Placement (..)
  , ResourceVector (..)
  , StorageDemand (..)
  , VolumeAttachment (..)
  , Workload (..)
  , addResources
  , envelopeHeadroom
  , envelopeLimits
  , envelopeRequests
  , headroomResources
  , availableResources
  )
import Amoebius.Dsl.Topology
  ( ComputeEngine (..)
  , NodeSupply (..)
  , Topology
  , engineAcceptsEnvironment
  , mkTopology
  , topologySupply
  )
import CapacityTopologyFixtures
  ( baseWorkload
  , resources
  )
import Control.Monad (unless)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Numeric.Natural (Natural)
import Test.QuickCheck
  ( Arbitrary (arbitrary)
  , Args (chatty, maxSuccess)
  , Property
  , Gen
  , Result
  , Testable
  , checkCoverage
  , chooseInt
  , counterexample
  , cover
  , elements
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )

data ValidatorMutation
  = ValidateAll
  | DropCpuValidation
  | DropMemoryValidation
  | DropEphemeralValidation
  | DropSlotValidation
  | DropCsiValidation
  deriving stock (Eq, Show)

data ScalarCase = ScalarCase Natural Natural
  deriving stock (Show)

instance Arbitrary ScalarCase where
  arbitrary = ScalarCase <$> natural 0 20 <*> natural 0 20

data PlacementCase = PlacementCase Natural Natural
  deriving stock (Show)

instance Arbitrary PlacementCase where
  arbitrary = PlacementCase <$> natural 1 20 <*> natural 1 20

data CompatibilityCase = CompatibilityCase ComputeEngine HostEnvironment
  deriving stock (Show)

instance Arbitrary CompatibilityCase where
  arbitrary =
    CompatibilityCase
      <$> elements [KindEngine, Rke2Engine, ManagedEksEngine]
      <*> elements [NativeLinux, VirtualizedLinux, ManagedAws]

runCapacityTopologyProps :: IO ()
runCapacityTopologyProps = do
  results <- sequence
    [ runProperty "prop_fitsEquivalence" propFitsEquivalence
    , runProperty "prop_carveSubtracts" propCarveSubtracts
    , runProperty "prop_placeSound" propPlaceSound
    , runProperty "prop_compatibilityEquivalence" propCompatibilityEquivalence
    ]
  let failed = [name | (name, result) <- results, not (isSuccess result)]
  unless (null failed) (fail ("capacity/topology properties failed: " <> show failed))
  putStrLn "capacity-properties: TESTED sampled (4) with >=30% accept/reject coverage"

propFitsEquivalence :: ScalarCase -> Property
propFitsEquivalence (ScalarCase required available) = checkCoverage
  $ cover 30 (required <= available) "in-envelope"
  $ cover 30 (required > available) "out-of-envelope"
  $ case fits (Demand (resources required 0 0 0)) (resources available 0 0 0) of
      Left _ -> property (required > available)
      Right headroom -> property (resourceCpu (headroomResources headroom) == available - required)

propCarveSubtracts :: ScalarCase -> Property
propCarveSubtracts (ScalarCase required available) = checkCoverage
  $ cover 30 (required <= available) "in-envelope"
  $ cover 30 (required > available) "out-of-envelope"
  $ case carve (AvailableCapacity (resources 0 available 0 0)) (Demand (resources 0 required 0 0)) of
      Left _ -> property (required > available)
      Right residual -> property (resourceMemory (availableResources residual) == available - required)

propPlaceSound :: PlacementCase -> Property
propPlaceSound (PlacementCase required available) = checkCoverage
  $ cover 30 (required <= available) "place-accept"
  $ cover 30 (required > available) "place-reject"
  $ case mkTopology Rke2Engine (FixedSupply (node :| [])) of
      Left problem -> counterexample (show problem) False
      Right topology -> case place topology [workload] of
        Left _ -> property (required > available)
        Right witness ->
          counterexample (show witness) (property (required <= available && validatePlacement ValidateAll topology [workload] witness == Right ()))
 where
  workload = baseWorkload "property" (resources required 1 1 1) (resources required 1 1 1) (resources 0 0 0 0)
  node =
    Node
      "property-node"
      "property-host"
      NativeLinux
      (NodeCapacity (resources available 4 4 1) NoCpuOvercommit Map.empty)
      Set.empty

propCompatibilityEquivalence :: CompatibilityCase -> Property
propCompatibilityEquivalence (CompatibilityCase engine environment) = checkCoverage
  $ cover 30 expected "compatible"
  $ cover 30 (not expected) "incompatible"
  $ property (engineAcceptsEnvironment engine environment == expected)
 where
  expected = referenceCompatibility engine environment

referenceCompatibility :: ComputeEngine -> HostEnvironment -> Bool
referenceCompatibility engine environment = case (engine, environment) of
  (KindEngine, NativeLinux) -> True
  (KindEngine, VirtualizedLinux) -> True
  (Rke2Engine, NativeLinux) -> True
  (Rke2Engine, VirtualizedLinux) -> True
  (ManagedEksEngine, ManagedAws) -> True
  _ -> False

validatePlacement :: ValidatorMutation -> Topology -> [Workload] -> Placement -> Either Text ()
validatePlacement mutation topology workloads witness = do
  ensure (assignmentWorkloads == expectedWorkloads) "assignment set differs from workload set"
  mapM_ validateNode (placementNodes witness)
  validateElastic
 where
  assignments = placementAssignments witness
  assignmentWorkloads = Set.fromList (fmap assignmentWorkload assignments)
  expectedWorkloads = Set.fromList (fmap workloadId workloads)
  workloadMap = Map.fromList [(workloadId workload, workload) | workload <- workloads]

  validateNode materialized = do
    let node = materializedNode materialized
        assignedIds = [assignmentWorkload assignment | assignment <- assignments, assignmentNode assignment == nodeId node]
        assigned = [workload | workloadIdValue <- assignedIds, Just workload <- [Map.lookup workloadIdValue workloadMap]]
        reserved = sumResources (fmap independentReserved assigned)
        limits = sumResources (fmap (envelopeLimits . workloadEnvelope) assigned)
        allocatable = nodeAllocatable (nodeCapacity node)
        cpuBudget = independentCpuBudget (nodeCpuOvercommit (nodeCapacity node)) (resourceCpu allocatable)
    ensureAxis DropCpuValidation (resourceCpu reserved <= resourceCpu allocatable) "reserved CPU overcommit"
    ensureAxis DropMemoryValidation (resourceMemory reserved <= resourceMemory allocatable) "reserved memory overcommit"
    ensureAxis DropEphemeralValidation (resourceEphemeralStorage reserved <= resourceEphemeralStorage allocatable) "reserved ephemeral overcommit"
    ensureAxis DropSlotValidation (fromIntegral (length assigned) <= resourcePodSlots allocatable) "pod-slot overcommit"
    ensureAxis DropCpuValidation (resourceCpu limits <= cpuBudget) "CPU-limit policy exceeded"
    ensureAxis DropMemoryValidation (resourceMemory limits <= resourceMemory allocatable) "memory-limit overcommit"
    ensureAxis DropEphemeralValidation (resourceEphemeralStorage limits <= resourceEphemeralStorage allocatable) "ephemeral-limit overcommit"
    mapM_ (validateStorageIndependent mutation) assigned
    mapM_ (\workload -> ensure (nodeTaints node `Set.isSubsetOf` workloadTolerations workload) "taint mismatch") assigned
    validateCsi mutation (nodeCsiAttachCapacity (nodeCapacity node)) assigned
    validateAntiAffinity assigned

  validateElastic = case topologySupply topology of
    FixedSupply _ -> Right ()
    ElasticSupply _ candidates quota -> do
      ensure (placementInstances witness <= growthMaxInstances quota) "elastic instance quota exceeded"
      ensure (placementVcpu witness <= growthMaxVcpu quota) "elastic vCPU quota exceeded"
      mapM_ validateCandidateMaximum (NonEmpty.toList candidates)

  validateCandidateMaximum candidate =
    let count =
          length
            [ ()
            | materialized <- placementNodes witness
            , materializedClass materialized == Just (candidateName candidate)
            ]
     in ensure (fromIntegral count <= candidateMaxCount candidate) "elastic class maximum exceeded"

  ensureAxis dropped condition message
    | mutation == dropped = Right ()
    | otherwise = ensure condition message

independentReserved :: Workload -> ResourceVector
independentReserved workload =
  let envelope = workloadEnvelope workload
      value = addResources (envelopeRequests envelope) (envelopeHeadroom envelope)
   in value {resourcePodSlots = 1}

validateStorageIndependent :: ValidatorMutation -> Workload -> Either Text ()
validateStorageIndependent mutation workload = do
  let storage = workloadStorage workload
      requests = envelopeRequests (workloadEnvelope workload)
      ephemeral = storageDiskBackedBytes storage + storagePrivateEphemeralBytes storage
      memory =
        if storageTmpfsPersistsIntoApp storage
          then storageTmpfsInitBytes storage + storageTmpfsAppBytes storage
          else max (storageTmpfsInitBytes storage) (storageTmpfsAppBytes storage)
  if mutation == DropEphemeralValidation
    then Right ()
    else ensure (ephemeral <= resourceEphemeralStorage requests) "pod ephemeral reservation underflow"
  if mutation == DropMemoryValidation
    then Right ()
    else ensure (memory <= resourceMemory requests) "pod tmpfs reservation underflow"

validateCsi :: ValidatorMutation -> Map Text Natural -> [Workload] -> Either Text ()
validateCsi mutation capacity workloads
  | mutation == DropCsiValidation = Right ()
  | otherwise = mapM_ validateDriver (Map.toList claims)
 where
  claims =
    Map.fromListWith Set.union
      [ (attachmentDriver attachment, Set.singleton (attachmentClaim attachment))
      | workload <- workloads
      , attachment <- workloadAttachments workload
      ]
  validateDriver (driver, driverClaims) =
    ensure
      (fromIntegral (Set.size driverClaims) <= Map.findWithDefault 0 driver capacity)
      "CSI attachment capacity exceeded"

validateAntiAffinity :: [Workload] -> Either Text ()
validateAntiAffinity workloads =
  ensure (length groups == Set.size (Set.fromList groups)) "anti-affinity group co-located"
 where
  groups = [group | workload <- workloads, Just group <- [workloadAntiAffinity workload]]

sumResources :: [ResourceVector] -> ResourceVector
sumResources = foldr addResources (ResourceVector 0 0 0 0)

independentCpuBudget :: CpuOvercommitPolicy -> Natural -> Natural
independentCpuBudget policy allocatable = case policy of
  NoCpuOvercommit -> allocatable
  BoundedCpuOvercommit ratio -> allocatable * max 1 ratio

ensure :: Bool -> Text -> Either Text ()
ensure condition message = if condition then Right () else Left message

runProperty :: Testable property => String -> property -> IO (String, Result)
runProperty name prop = do
  result <- quickCheckWithResult stdArgs {maxSuccess = 300, chatty = False} prop
  pure (name, result)

natural :: Int -> Int -> Gen Natural
natural lower upper = fromIntegral <$> chooseInt (lower, upper)
