{-# LANGUAGE OverloadedStrings #-}

-- | The elastic arm of the fold: a node set that may grow inside a quota. Growth picks the
-- first candidate class that fits and stays under both ceilings.
module Amoebius.Placement.Elastic
  ( placeElastic
  ) where

import Amoebius.Capacity.Fits (subtractResources)
import Amoebius.Capacity.Types
  ( Axis (..)
  , CandidateNodeClass (..)
  , GrowthQuota (..)
  , HostEnvironment (..)
  , MaterializedNode (..)
  , Node (..)
  , NodeRole (..)
  , NodeCapacity (..)
  , Placement (..)
  , PlacementError (..)
  , PlacementKind (..)
  , Workload (..)
  )
import Amoebius.Capacity.Vector (zeroResources)
import Amoebius.Placement.Ledger (NodeLedger (..), debitFirst, debitWorkload, decreasing, initialLedger)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

placeElastic :: [Node] -> [CandidateNodeClass] -> GrowthQuota -> [Workload] -> Either PlacementError Placement
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
    , classCount (candidateName candidate) existing < candidateMaxCount candidate
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
          , nodeDetected = candidateDetected candidate
          , nodeRole = case candidateEnvironment candidate of
              ManagedAws -> ManagedWorker
              NativeLinux -> Rke2Agent
              VirtualizedLinux -> Rke2Agent
          }
        (Just (candidateName candidate))
    )

effectiveCandidateCapacity :: CandidateNodeClass -> NodeCapacity
effectiveCandidateCapacity candidate =
  let capacity = candidateCapacity candidate
      residual = case subtractResources (candidatePerNodeDemand candidate) (nodeAllocatable capacity) of
        Left _ -> zeroResources
        Right available -> available
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

