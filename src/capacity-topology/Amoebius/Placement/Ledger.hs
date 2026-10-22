{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The ledger the placement folds debit: what each node still holds, and the first-fit
-- debit of a workload against the ledgers of a node set. The fold's decisions about which
-- workload goes first and which node it lands on are the witness's; the arithmetic of one
-- debit is here.
module Amoebius.Placement.Ledger
  ( NodeLedger (..)
  , initialLedger
  , debitFirst
  , debitWorkload
  , decreasing
  , materializedId
  ) where

import Amoebius.Capacity.Fits (carve, effectiveReserved)
import Amoebius.Capacity.Types
  ( Assignment (..)
  , AvailableCapacity (..)
  , Axis (..)
  , CpuOvercommitPolicy (..)
  , Demand (..)
  , MaterializedNode (..)
  , Node (..)
  , NodeCapacity (..)
  , Overcommit (..)
  , PlacementError (..)
  , VolumeAttachment (..)
  , Workload (..)
  , envelopeLimits
  , envelopeRequests
  , scaleQuantity
  , storageReservation
  )
import Amoebius.Capacity.Vector (ResourceVector (..))
import Amoebius.Placement.Taints (tolerates)
import Amoebius.Vocabulary (Quantity, Unit (..), quantityValue)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Ord (Down (..))
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

data NodeLedger = NodeLedger
  { ledgerMaterialized :: MaterializedNode
  , ledgerReserved :: AvailableCapacity
  , ledgerCpuLimitRemaining :: Quantity 'CpuUnit
  , ledgerMemoryLimitRemaining :: Quantity 'MemoryUnit
  , ledgerEphemeralLimitRemaining :: Quantity 'EphemeralUnit
  , ledgerClaims :: Map Text (Set Text)
  , ledgerAntiAffinity :: Set Text
  , ledgerAssignments :: [Assignment]
  }

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
  ephemeralLimit <- debitScalar EphemeralStorageAxis (resourceEphemeralStorage limits) (ledgerEphemeralLimitRemaining ledger)
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
  let reserved = effectiveReserved (workloadEnvelope workload)
   in reserved {resourcePodSlots = 1}

validateStorage :: Workload -> Either PlacementError ()
validateStorage workload =
  let requests = envelopeRequests (workloadEnvelope workload)
      (ephemeralRequired, memoryRequired) = storageReservation (workloadStorage workload)
   in if ephemeralRequired > resourceEphemeralStorage requests
        then Left (PodStorageUnderreserved (workloadId workload) EphemeralStorageAxis (quantityValue ephemeralRequired) (quantityValue (resourceEphemeralStorage requests)))
        else
          if memoryRequired > resourceMemory requests
            then Left (PodStorageUnderreserved (workloadId workload) MemoryAxis (quantityValue memoryRequired) (quantityValue (resourceMemory requests)))
            else Right ()

validateEligibility :: Workload -> Node -> Either PlacementError ()
validateEligibility workload node
  | tolerates (nodeTaints node) (workloadTolerations workload) = Right ()
  | otherwise = Left (IneligibleNode (workloadId workload) (nodeId node))

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
            fromIntegral (Set.size combined)
          available = Map.findWithDefault 0 driver (nodeCsiAttachCapacity capacity)
       in if required > available
            then Left (CapacityOvercommit (Overcommit (CsiAttachmentsAxis driver) required available))
            else go remaining (Map.insert driver combined current)

-- | Debit one limit against what remains of it. A cpu limit that exceeds the remaining
-- budget is the bounded-overcommit policy's refusal; any other axis is an overcommit.
debitScalar :: Axis -> Quantity unit -> Quantity unit -> Either PlacementError (Quantity unit)
debitScalar axis required available
  | required <= available = Right (available - required)
  | axis == CpuAxis = Left (CpuLimitPolicyExceeded "node" (quantityValue required) (quantityValue available))
  | otherwise = Left (CapacityOvercommit (Overcommit axis (quantityValue required) (quantityValue available)))

firstPlacement :: Either Overcommit value -> Either PlacementError value
firstPlacement value = case value of
  Left problem -> Left (CapacityOvercommit problem)
  Right result -> Right result

cpuLimitBudget :: CpuOvercommitPolicy -> Quantity 'CpuUnit -> Quantity 'CpuUnit
cpuLimitBudget policy allocatable = case policy of
  NoCpuOvercommit -> allocatable
  BoundedCpuOvercommit ratio -> scaleQuantity (max 1 ratio) allocatable

-- | The order a workload set is packed in: the heaviest first. The weight is a sort key,
-- so the three units are erased to bare magnitudes before they are added.
decreasing :: [Workload] -> [Workload]
decreasing = sortOn (Down . weight)
 where
  weight workload =
    let resources = effectiveReserved (workloadEnvelope workload)
     in quantityValue (resourceCpu resources) + quantityValue (resourceMemory resources) + quantityValue (resourceEphemeralStorage resources)

materializedId :: NodeLedger -> Text
materializedId = nodeId . materializedNode . ledgerMaterialized

isEligibility :: PlacementError -> Bool
isEligibility problem = case problem of
  IneligibleNode {} -> True
  _ -> False
