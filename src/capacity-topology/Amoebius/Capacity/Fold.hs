{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Capacity.Fold
  ( PodFitWitness (..)
  , fits
  , podFits
  , carve
  , place
  , effectiveReserved
  , storageReservation
  ) where

import Amoebius.Capacity.Types
  ( Assignment (..)
  , AvailableCapacity (..)
  , Axis (..)
  , CandidateNodeClass (..)
  , CpuOvercommitPolicy (..)
  , Demand (..)
  , GrowthQuota (..)
  , Headroom (..)
  , MaterializedNode (..)
  , Node (..)
  , NodeCapacity (..)
  , Overcommit (..)
  , Placement (..)
  , PlacementError (..)
  , PlacementKind (..)
  , ResourceEnvelope
  , ResourceVector (..)
  , StorageDemand (..)
  , VolumeAttachment (..)
  , Workload (..)
  , addResources
  , envelopeHeadroom
  , envelopeLimits
  , envelopeRequests
  )
import Amoebius.Dsl.Topology (NodeSupply (..), Topology, topologySupply)
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Ord (Down (..))
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data PodFitWitness = PodFitWitness
  { fitWorkload :: Text
  , fitNode :: Text
  , fitReserved :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NodeLedger = NodeLedger
  { ledgerMaterialized :: MaterializedNode
  , ledgerReserved :: AvailableCapacity
  , ledgerCpuLimitRemaining :: Natural
  , ledgerMemoryLimitRemaining :: Natural
  , ledgerEphemeralLimitRemaining :: Natural
  , ledgerClaims :: Map Text (Set Text)
  , ledgerAntiAffinity :: Set Text
  , ledgerAssignments :: [Assignment]
  }

fits :: Demand -> ResourceVector -> Either Overcommit Headroom
fits (Demand required) capacity = Headroom <$> subtractResources required capacity

carve :: AvailableCapacity -> Demand -> Either Overcommit AvailableCapacity
carve (AvailableCapacity capacity) (Demand required) =
#if defined(CAPACITY_CARVE_SKIP_SUBTRACTION_MUTANT)
  AvailableCapacity capacity <$ subtractResources required capacity
#else
  AvailableCapacity <$> subtractResources required capacity
#endif

podFits :: Workload -> Node -> Either PlacementError PodFitWitness
podFits workload node = do
  _ <- debitWorkload workload (initialLedger (MaterializedNode node Nothing))
  pure (PodFitWitness (workloadId workload) (nodeId node) (effectiveReserved (workloadEnvelope workload)))

place :: Topology -> [Workload] -> Either PlacementError Placement
place topology workloads = case topologySupply topology of
  FixedSupply nodes -> placeFixed (NonEmpty.toList nodes) workloads
  ElasticSupply floorNodes candidates quota -> placeElastic floorNodes (NonEmpty.toList candidates) quota workloads

effectiveReserved :: ResourceEnvelope -> ResourceVector
effectiveReserved envelope = addResources (envelopeRequests envelope) (envelopeHeadroom envelope)

storageReservation :: StorageDemand -> (Natural, Natural)
storageReservation storage =
  ( storageDiskBackedBytes storage + storagePrivateEphemeralBytes storage
#if defined(CAPACITY_MEMORY_BACKED_DROP_MUTANT)
  , max (storageTmpfsInitBytes storage) (storageTmpfsAppBytes storage)
#elif defined(CAPACITY_TMPFS_PERSISTENCE_DROP_MUTANT)
  , storageTmpfsAppBytes storage
#else
  , if storageTmpfsPersistsIntoApp storage
      then storageTmpfsInitBytes storage + storageTmpfsAppBytes storage
      else max (storageTmpfsInitBytes storage) (storageTmpfsAppBytes storage)
#endif
  )

placeFixed :: [Node] -> [Workload] -> Either PlacementError Placement
#if defined(CAPACITY_FIXED_ADMIT_OVERCOMMIT_MUTANT)
placeFixed nodes _ =
  Right
    Placement
      { placementKind = FixedPlacement
      , placementNodes = fmap (\node -> MaterializedNode node Nothing) nodes
      , placementAssignments = []
      , placementInstances = fromIntegral (length nodes)
      , placementVcpu = sum [resourceCpu (nodeAllocatable (nodeCapacity node)) | node <- nodes]
      }
#else
placeFixed nodes workloads = do
  final <- placeOnExisting (fmap (initialLedger . (`MaterializedNode` Nothing)) nodes) (decreasing workloads)
  pure
    Placement
      { placementKind = FixedPlacement
      , placementNodes = fmap ledgerMaterialized final
      , placementAssignments = concatMap (reverse . ledgerAssignments) final
      , placementInstances = fromIntegral (length final)
      , placementVcpu = sum [resourceCpu (nodeAllocatable (nodeCapacity node)) | node <- nodes]
      }
#endif

placeElastic :: [Node] -> [CandidateNodeClass] -> GrowthQuota -> [Workload] -> Either PlacementError Placement
#if defined(CAPACITY_ELASTIC_UNCONDITIONAL_RIGHT_MUTANT)
placeElastic floorNodes _ _ _ =
  Right
    Placement
      { placementKind = ElasticPlacement
      , placementNodes = fmap (\node -> MaterializedNode node Nothing) floorNodes
      , placementAssignments = []
      , placementInstances = fromIntegral (length floorNodes)
      , placementVcpu = sum [resourceCpu (nodeAllocatable (nodeCapacity node)) | node <- floorNodes]
      }
#else
placeElastic floorNodes candidates quota workloads = do
  let initial = fmap (initialLedger . (`MaterializedNode` Nothing)) floorNodes
      baseInstances = sum (fmap candidateBaseCount candidates)
      baseVcpu = sum [candidateBaseCount candidate * candidateQuotaVcpu candidate | candidate <- candidates]
  (final, instances, vcpu) <- placeElasticWorkloads candidates quota initial baseInstances baseVcpu (decreasing workloads)
  pure
    Placement
      { placementKind = ElasticPlacement
      , placementNodes = fmap ledgerMaterialized final
      , placementAssignments = concatMap (reverse . ledgerAssignments) final
      , placementInstances = instances
      , placementVcpu = vcpu
      }
#endif

placeOnExisting :: [NodeLedger] -> [Workload] -> Either PlacementError [NodeLedger]
placeOnExisting ledgers workloads = case workloads of
  [] -> Right ledgers
  workload : remaining -> do
    updated <- debitFirst workload ledgers
    placeOnExisting updated remaining

placeElasticWorkloads
  :: [CandidateNodeClass]
  -> GrowthQuota
  -> [NodeLedger]
  -> Natural
  -> Natural
  -> [Workload]
  -> Either PlacementError ([NodeLedger], Natural, Natural)
placeElasticWorkloads candidates quota ledgers instances vcpu workloads = case workloads of
  [] -> Right (ledgers, instances, vcpu)
  workload : remaining ->
    case debitFirst workload ledgers of
      Right updated -> placeElasticWorkloads candidates quota updated instances vcpu remaining
      Left _ -> do
        (candidate, newLedger) <- selectCandidate candidates ledgers workload
        let nextInstances = instances + 1
            nextVcpu = vcpu + candidateQuotaVcpu candidate
        if nextInstances > growthMaxInstances quota
          then Left (GrowthQuotaExceeded InstanceCountAxis nextInstances (growthMaxInstances quota))
          else
            if nextVcpu > growthMaxVcpu quota
              then Left (GrowthQuotaExceeded VcpuQuotaAxis nextVcpu (growthMaxVcpu quota))
              else
                placeElasticWorkloads
                  candidates
                  quota
                  (ledgers <> [newLedger])
                  nextInstances
                  nextVcpu
                  remaining

selectCandidate :: [CandidateNodeClass] -> [NodeLedger] -> Workload -> Either PlacementError (CandidateNodeClass, NodeLedger)
selectCandidate candidates existing workload =
  case (fitting, available) of
    ([], _) -> Left (Unschedulable (workloadId workload <> ":no-effective-candidate"))
    (candidate : _, []) ->
      Left
        ( CandidateClassMaximumExceeded
            (candidateName candidate)
            (classCount (candidateName candidate) existing + 1)
            (candidateMaxCount candidate)
        )
    (_, (candidate, ledger) : _) -> Right (candidate, ledger)
 where
  fitting = [candidate | candidate <- candidates, candidateWouldFit candidate workload]
  available =
    [ (candidate, placed)
    | candidate <- fitting
#if !defined(CAPACITY_ELASTIC_IGNORE_CLASS_MAX_MUTANT)
    , classCount (candidateName candidate) existing < candidateMaxCount candidate
#endif
    , Right placed <- [debitWorkload workload (candidateLedger candidate (classCount (candidateName candidate) existing + 1))]
    ]

candidateWouldFit :: CandidateNodeClass -> Workload -> Bool
candidateWouldFit candidate workload =
  case debitWorkload workload (candidateLedger candidate 1) of
    Right _ -> True
    Left _ -> False

candidateLedger :: CandidateNodeClass -> Natural -> NodeLedger
candidateLedger candidate ordinal =
  initialLedger
    ( MaterializedNode
        Node
          { nodeId = candidateName candidate <> "-" <> Text.pack (show ordinal)
          , nodeHostId = candidateName candidate <> "-host-" <> Text.pack (show ordinal)
          , nodeEnvironment = candidateEnvironment candidate
          , nodeCapacity = effectiveCandidateCapacity candidate
          , nodeTaints = candidateTaints candidate
          }
        (Just (candidateName candidate))
    )

effectiveCandidateCapacity :: CandidateNodeClass -> NodeCapacity
effectiveCandidateCapacity candidate =
  let capacity = candidateCapacity candidate
#if defined(CAPACITY_ELASTIC_DROP_PER_NODE_MUTANT)
      residual = nodeAllocatable capacity
#else
      residual = case subtractResources (candidatePerNodeDemand candidate) (nodeAllocatable capacity) of
        Left _ -> ResourceVector 0 0 0 0
        Right available -> available
#endif
   in capacity {nodeAllocatable = residual}

classCount :: Text -> [NodeLedger] -> Natural
classCount name ledgers =
  fromIntegral
    ( length
        [ ()
        | ledger <- ledgers
        , materializedClass (ledgerMaterialized ledger) == Just name
        ]
    )

debitFirst :: Workload -> [NodeLedger] -> Either PlacementError [NodeLedger]
debitFirst workload ledgers = go [] [] ledgers
 where
  go rejected prefix remaining = case remaining of
    [] -> Left (chooseFailure rejected)
    ledger : rest -> case debitWorkload workload ledger of
      Right updated -> Right (reverse prefix <> (updated : rest))
      Left problem -> go (problem : rejected) (ledger : prefix) rest
  chooseFailure failures
    | not (null nonEligibility) = case nonEligibility of
        problem : _ -> problem
        [] -> Unschedulable (workloadId workload <> ":no-node")
    | otherwise = Unschedulable (workloadId workload <> ":eligibility")
   where
    nonEligibility = [problem | problem <- reverse failures, not (isEligibility problem)]

debitWorkload :: Workload -> NodeLedger -> Either PlacementError NodeLedger
debitWorkload workload ledger = do
  validateStorage workload
  validateEligibility workload node
  validateAntiAffinity workload ledger
  reserved <- firstPlacement (carve (ledgerReserved ledger) (Demand (normalizedReserved workload)))
  cpuLimit <- debitScalar CpuAxis (resourceCpu limits) (ledgerCpuLimitRemaining ledger)
  memoryLimit <- debitScalar MemoryAxis (resourceMemory limits) (ledgerMemoryLimitRemaining ledger)
#if defined(CAPACITY_POD_DROP_EPHEMERAL_MUTANT) || defined(CAPACITY_VALIDATOR_DROP_EPHEMERAL_MUTANT)
  let ephemeralLimit = ledgerEphemeralLimitRemaining ledger
#else
  ephemeralLimit <- debitScalar EphemeralStorageAxis (resourceEphemeralStorage limits) (ledgerEphemeralLimitRemaining ledger)
#endif
  claims <- debitClaims (workloadAttachments workload) capacity (ledgerClaims ledger)
  pure
    ledger
      { ledgerReserved = reserved
      , ledgerCpuLimitRemaining = cpuLimit
      , ledgerMemoryLimitRemaining = memoryLimit
      , ledgerEphemeralLimitRemaining = ephemeralLimit
      , ledgerClaims = claims
      , ledgerAntiAffinity =
          maybe
            (ledgerAntiAffinity ledger)
            (\group -> Set.insert group (ledgerAntiAffinity ledger))
            (workloadAntiAffinity workload)
      , ledgerAssignments = Assignment (workloadId workload) (nodeId node) : ledgerAssignments ledger
      }
 where
  node = materializedNode (ledgerMaterialized ledger)
  capacity = nodeCapacity node
  limits = envelopeLimits (workloadEnvelope workload)

initialLedger :: MaterializedNode -> NodeLedger
initialLedger materialized =
  NodeLedger
    { ledgerMaterialized = materialized
    , ledgerReserved = AvailableCapacity allocatable
    , ledgerCpuLimitRemaining = cpuLimitBudget (nodeCpuOvercommit capacity) (resourceCpu allocatable)
    , ledgerMemoryLimitRemaining = resourceMemory allocatable
    , ledgerEphemeralLimitRemaining = resourceEphemeralStorage allocatable
    , ledgerClaims = Map.empty
    , ledgerAntiAffinity = Set.empty
    , ledgerAssignments = []
    }
 where
  capacity = nodeCapacity (materializedNode materialized)
  allocatable = nodeAllocatable capacity

normalizedReserved :: Workload -> ResourceVector
normalizedReserved workload =
#if defined(CAPACITY_HEADROOM_PAD_DROP_MUTANT)
  let reserved = envelopeRequests (workloadEnvelope workload)
#else
  let reserved = effectiveReserved (workloadEnvelope workload)
#endif
#if defined(CAPACITY_POD_DROP_EPHEMERAL_MUTANT)
   in reserved {resourceEphemeralStorage = 0, resourcePodSlots = 1}
#else
   in reserved {resourcePodSlots = 1}
#endif

validateStorage :: Workload -> Either PlacementError ()
validateStorage workload =
  let requests = envelopeRequests (workloadEnvelope workload)
      (ephemeralRequired, memoryRequired) = storageReservation (workloadStorage workload)
   in if ephemeralRequired > resourceEphemeralStorage requests
        then Left (PodStorageUnderreserved (workloadId workload) EphemeralStorageAxis ephemeralRequired (resourceEphemeralStorage requests))
        else
          if memoryRequired > resourceMemory requests
            then Left (PodStorageUnderreserved (workloadId workload) MemoryAxis memoryRequired (resourceMemory requests))
            else Right ()

validateEligibility :: Workload -> Node -> Either PlacementError ()
#if defined(CAPACITY_TAINT_IGNORE_MUTANT)
validateEligibility _ _ = Right ()
#else
validateEligibility workload node
  | nodeTaints node `Set.isSubsetOf` workloadTolerations workload = Right ()
  | otherwise = Left (IneligibleNode (workloadId workload) (nodeId node))
#endif

validateAntiAffinity :: Workload -> NodeLedger -> Either PlacementError ()
validateAntiAffinity workload ledger = case workloadAntiAffinity workload of
  Nothing -> Right ()
  Just group
    | group `Set.member` ledgerAntiAffinity ledger -> Left (IneligibleNode (workloadId workload) (materializedId ledger))
    | otherwise -> Right ()

debitClaims :: [VolumeAttachment] -> NodeCapacity -> Map Text (Set Text) -> Either PlacementError (Map Text (Set Text))
debitClaims attachments capacity used = go grouped used
 where
  grouped = Map.fromListWith Set.union [(attachmentDriver attachment, Set.singleton (attachmentClaim attachment)) | attachment <- attachments]
  go outstanding current = case Map.minViewWithKey outstanding of
    Nothing -> Right current
    Just ((driver, claims), remaining) ->
      let already = Map.findWithDefault Set.empty driver current
          combined = already `Set.union` claims
          required =
#if defined(CAPACITY_VALIDATOR_DROP_CSI_MUTANT)
            0
#else
            fromIntegral (Set.size combined)
#endif
          available = Map.findWithDefault 0 driver (nodeCsiAttachCapacity capacity)
       in if required > available
            then Left (CapacityOvercommit (Overcommit (CsiAttachmentsAxis driver) required available))
            else go remaining (Map.insert driver combined current)

debitScalar :: Axis -> Natural -> Natural -> Either PlacementError Natural
debitScalar axis required available
  | required <= available = Right (available - required)
  | axis == CpuAxis = Left (CpuLimitPolicyExceeded "node" required available)
  | otherwise = Left (CapacityOvercommit (Overcommit axis required available))

firstPlacement :: Either Overcommit value -> Either PlacementError value
firstPlacement value = case value of
  Left problem -> Left (CapacityOvercommit problem)
  Right result -> Right result

subtractResources :: ResourceVector -> ResourceVector -> Either Overcommit ResourceVector
subtractResources required available
#if !defined(CAPACITY_VALIDATOR_DROP_CPU_MUTANT)
  | resourceCpu required > resourceCpu available =
      Left (Overcommit CpuAxis (resourceCpu required) (resourceCpu available))
#endif
#if !defined(CAPACITY_FITS_DROP_MEMORY_MUTANT) && !defined(CAPACITY_VALIDATOR_DROP_MEMORY_MUTANT)
  | resourceMemory required > resourceMemory available =
      Left (Overcommit MemoryAxis (resourceMemory required) (resourceMemory available))
#endif
#if !defined(CAPACITY_VALIDATOR_DROP_EPHEMERAL_MUTANT)
  | resourceEphemeralStorage required > resourceEphemeralStorage available =
      Left (Overcommit EphemeralStorageAxis (resourceEphemeralStorage required) (resourceEphemeralStorage available))
#endif
#if !defined(CAPACITY_VALIDATOR_DROP_SLOTS_MUTANT)
  | resourcePodSlots required > resourcePodSlots available =
      Left (Overcommit PodSlotsAxis (resourcePodSlots required) (resourcePodSlots available))
#endif
  | otherwise =
      Right
        ResourceVector
          { resourceCpu = naturalDifference (resourceCpu available) (resourceCpu required)
          , resourceMemory = naturalDifference (resourceMemory available) (resourceMemory required)
          , resourceEphemeralStorage = naturalDifference (resourceEphemeralStorage available) (resourceEphemeralStorage required)
          , resourcePodSlots = naturalDifference (resourcePodSlots available) (resourcePodSlots required)
          }

naturalDifference :: Natural -> Natural -> Natural
naturalDifference available required
  | available >= required = available - required
  | otherwise = 0

cpuLimitBudget :: CpuOvercommitPolicy -> Natural -> Natural
cpuLimitBudget policy allocatable = case policy of
#if defined(CAPACITY_CPU_POLICY_IGNORE_MUTANT)
  NoCpuOvercommit -> allocatable * 1024
#else
  NoCpuOvercommit -> allocatable
#endif
  BoundedCpuOvercommit ratio -> allocatable * max 1 ratio

decreasing :: [Workload] -> [Workload]
decreasing = sortOn (Down . weight)
 where
  weight workload =
    let resources = effectiveReserved (workloadEnvelope workload)
     in resourceCpu resources + resourceMemory resources + resourceEphemeralStorage resources

materializedId :: NodeLedger -> Text
materializedId = nodeId . materializedNode . ledgerMaterialized

isEligibility :: PlacementError -> Bool
isEligibility problem = case problem of
  IneligibleNode {} -> True
  _ -> False
