{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The placement witness. 'place' packs a workload set onto a topology and returns a
-- 'Placed': the assignment of every workload to a node, constructible nowhere else, so a
-- manifest that names a node can only have been given one by the fold.
module Amoebius.Placement.Witness
  ( Placed
  , Epoch
  , epochNamed
  , epochName
  , placedPlacement
  , placedAssignments
  , placedNode
  , place
  , PodFitWitness (..)
  , podFits
  ) where

import Amoebius.Capacity.Fits (effectiveReserved)
import Amoebius.Capacity.Types
  ( Assignment (..)
  , MaterializedNode (..)
  , Node (..)
  , NodeCapacity (..)
  , Placement (..)
  , PlacementError (..)
  , PlacementKind (..)
  , Workload (..)
  )
import Amoebius.Capacity.Vector (ResourceVector (..))
import Amoebius.Dsl.Topology (NodeSupply (..), Topology, topologySupply)
import Amoebius.Placement.Elastic (placeElastic)
import Amoebius.Placement.Ledger (NodeLedger (..), debitFirst, debitWorkload, decreasing, initialLedger)
import Amoebius.Placement.Taints (tolerates)
import Amoebius.Vocabulary (quantityValue)
import Control.DeepSeq (NFData)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import GHC.Generics (Generic)

-- | The execution epoch a manifest is rendered for. It is named by the provision stage and
-- stamped on every object the render emits.
newtype Epoch = Epoch Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

epochNamed :: Text -> Epoch
epochNamed = Epoch

epochName :: Epoch -> Text
epochName (Epoch name) = name

-- | A placement the fold produced. The constructor is private.
newtype Placed = Placed Placement
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

placedPlacement :: Placed -> Placement
placedPlacement (Placed placement) = placement

placedAssignments :: Placed -> [Assignment]
placedAssignments = placementAssignments . placedPlacement

-- | The node a workload was assigned to.
placedNode :: Placed -> Text -> Maybe Text
placedNode placed workload =
  case [assignmentNode assignment | assignment <- placedAssignments placed, assignmentWorkload assignment == workload] of
    node : _ -> Just node
    [] -> Nothing

data PodFitWitness = PodFitWitness
  { fitWorkload :: Text
  , fitNode :: Text
  , fitReserved :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

podFits :: Workload -> Node -> Either PlacementError PodFitWitness
podFits workload node = do
  _ <- debitWorkload workload (initialLedger (MaterializedNode node Nothing))
  pure (PodFitWitness (workloadId workload) (nodeId node) (effectiveReserved (workloadEnvelope workload)))

-- | The cluster-level feasibility result: a concrete assignment for a fixed node set, or
-- a growth that stays inside the quota for an elastic one.
place :: Topology -> [Workload] -> Either PlacementError Placed
place topology workloads = Placed <$> case topologySupply topology of
  FixedSupply nodes -> placeFixed (NonEmpty.toList nodes) workloads
  ElasticSupply floorNodes candidates quota -> placeElastic floorNodes (NonEmpty.toList candidates) quota workloads

placeFixed :: [Node] -> [Workload] -> Either PlacementError Placement
placeFixed nodes workloads = do
  case [workloadId workload | workload <- workloads, not (any (\node -> tolerates (nodeTaints node) (workloadTolerations workload)) nodes)] of
    first : _ | not (null nodes) -> Left (TaintedOnlyHost first)
    _ -> Right ()
  final <- placeOnExisting (fmap (initialLedger . (`MaterializedNode` Nothing)) nodes) (decreasing workloads)
  pure
    Placement
      { placementKind = FixedPlacement
      , placementNodes = fmap ledgerMaterialized final
      , placementAssignments = concatMap (reverse . ledgerAssignments) final
      , placementInstances = fromIntegral (length final)
      , placementVcpu = sum [quantityValue (resourceCpu (nodeAllocatable (nodeCapacity node))) | node <- nodes]
      }

placeOnExisting :: [NodeLedger] -> [Workload] -> Either PlacementError [NodeLedger]
placeOnExisting ledgers workloads = case workloads of
  [] -> Right ledgers
  workload : remaining -> do
    updated <- debitFirst workload ledgers
    placeOnExisting updated remaining
