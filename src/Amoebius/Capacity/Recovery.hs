{-# LANGUAGE OverloadedStrings #-}

-- | Named replacement slots stay separate from retained source allocations.
-- These witnesses describe placement and demand, not observed process exit or
-- permission to start a replacement executor.
module Amoebius.Capacity.Recovery
  ( RecoveryCase (..), RetainedSegment (..), RecoveryPlan
  , provisionMinioRecovery, provisionBookKeeperRecovery, bookKeeperHistoryEnvelope
  , recoveryCases, recoverySlotPeaks, recoveryActiveIds, recoverySpareIds
  ) where

import Amoebius.Capacity.Placement
import Amoebius.Capacity.Storage (StorageError (..))
import Amoebius.Capacity.StorageGeometry
import Control.Monad (unless)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Numeric.Natural (Natural)

data RecoveryCase = RecoveryCase
  { failedMembers :: [Natural], replacementMembers :: Map Natural Natural
  , incomingBytes :: Map Natural Natural, recoverySegments :: [RetainedSegment] }
  deriving stock (Eq, Show)

data RetainedSegment = RetainedSegment
  { retainedSegmentId :: Text, retainedSegmentBytes :: Natural
  , retainedEnsemble :: [Natural], retainedWriteSet :: [Natural] }
  deriving stock (Eq, Show)

data RecoveryPlan = RecoveryPlan [Natural] [Natural] [RecoveryCase] (Map Natural Natural)
  deriving stock (Eq, Show)

-- | A shared spare can serve mutually exclusive faults. Simultaneously failed
-- drives need distinct targets, including faults in different erasure sets.
provisionMinioRecovery :: MinioPlacement -> Map Natural Natural -> Either StorageError RecoveryPlan
provisionMinioRecovery placement spares = do
  let slots = minioSlots placement
      active = Map.keys slots
      supply = Map.keys spares
  unless (not (null supply) && all (`notElem` active) supply)
    (invalid "MinIO replacement identities must be distinct from active drives")
  cases <- fmap concat $ traverse (\failed -> do
    let mappings = assignments failed supply
        fitting mapping = all (\(source, target) -> maybe False (>= slotPeakBytes (slots Map.! source)) (Map.lookup target spares)) (Map.toList mapping)
        eligible = filter fitting mappings
    unless (not (null eligible)) (invalid "MinIO replacement pool cannot cover the complete fault case")
    pure [RecoveryCase failed mapping (Map.fromList [(target, slotPeakBytes (slots Map.! source)) | (source, target) <- Map.toList mapping]) [] | mapping <- eligible])
    (geometryFailureScenarios (minioPlacementGeometry placement))
  let peaks = Map.unionsWith max (fmap incomingBytes cases)
  pure (RecoveryPlan active supply cases peaks)

-- | BK4.17.2 replacement excludes every current ensemble member, including
-- survivors outside this segment's write set. Ack quorum is not a byte factor.
provisionBookKeeperRecovery :: BookKeeperPolicy -> [Natural] -> [Natural] -> [RetainedSegment]
  -> Either StorageError RecoveryPlan
provisionBookKeeperRecovery policy active spares segments = do
  _ <- bookKeeperPhysicalDemand policy (sum (fmap retainedSegmentBytes segments))
  unless (not (null active) && unique active && unique spares && all (`notElem` active) spares)
    (invalid "BookKeeper active and spare identities must be distinct")
  unless (unique (fmap retainedSegmentId segments) && all validSegment segments)
    (invalid "BookKeeper recovery requires exact segment ensembles and write sets")
  cases <- fmap concat $ traverse (\failed -> do
    unless (all (any (`notElem` failed) . retainedWriteSet) segments)
      (invalid "BookKeeper failed replicas have no surviving source")
    let affected = filter (\member -> any (elem member . retainedEnsemble) segments) failed
        candidates = filter (`notElem` failed) (active <> spares)
        eligible mapping = all (\(source, target) -> all
          (\segment -> source `notElem` retainedEnsemble segment || target `notElem` retainedEnsemble segment) segments) (Map.toList mapping)
        mappings = filter eligible (assignments affected candidates)
    unless (not (null mappings)) (invalid "BookKeeper has no eligible replacement outside the current ensemble")
    pure [RecoveryCase failed mapping (Map.fromListWith (+)
      [(target, retainedSegmentBytes segment) | segment <- segments, (source, target) <- Map.toList mapping,
        source `elem` retainedWriteSet segment]) segments | mapping <- mappings]) (subsets (bookKeeperFaultBound policy) active)
  let reserve = bookKeeperJournalAndIndexBytesPerBookie policy
      steady = Map.fromList [(member, reserve + sum [retainedSegmentBytes segment | segment <- segments,
            member `elem` retainedWriteSet segment]) | member <- active <> spares]
      incoming = Map.unionsWith max (fmap incomingBytes cases)
      peaks = Map.unionWith (+) steady incoming
  pure (RecoveryPlan active spares cases peaks)
 where
  validSegment segment = retainedSegmentId segment /= "" && retainedSegmentBytes segment > 0
    && unique (retainedEnsemble segment) && unique (retainedWriteSet segment)
    && fromIntegral (length (retainedEnsemble segment)) == bookKeeperEnsembleSize policy
    && fromIntegral (length (retainedWriteSet segment)) == bookKeeperWriteQuorum policy
    && all (`elem` active) (retainedEnsemble segment)
    && all (`elem` retainedEnsemble segment) (retainedWriteSet segment)

-- | Unknown finite history can be distributed among the legal write sets.
-- For each slot the linear byte maximum occurs at a corner assigning the
-- entire bound to one write set. Keep those alternatives, not a cluster mean.
bookKeeperHistoryEnvelope :: BookKeeperPolicy -> [Natural] -> [Natural] -> Natural
  -> Either StorageError RecoveryPlan
bookKeeperHistoryEnvelope policy active spares history = do
  unless (history > 0) (invalid "BookKeeper serialized history must be positive")
  let ensembles = choose (bookKeeperEnsembleSize policy) active
      layouts = [(ensemble, writes) | ensemble <- ensembles, writes <- choose (bookKeeperWriteQuorum policy) ensemble]
  unless (not (null layouts)) (invalid "BookKeeper has no legal ensemble layout")
  plans <- traverse (\(ensemble, writes) -> provisionBookKeeperRecovery policy active spares
    [RetainedSegment "bounded-serialized-history" history ensemble writes]) layouts
  pure (RecoveryPlan active spares (concatMap recoveryCases plans) (Map.unionsWith max (fmap recoverySlotPeaks plans)))

recoveryCases :: RecoveryPlan -> [RecoveryCase]
recoveryCases (RecoveryPlan _ _ cases _) = cases

recoverySlotPeaks :: RecoveryPlan -> Map Natural Natural
recoverySlotPeaks (RecoveryPlan _ _ _ peaks) = peaks

recoveryActiveIds :: RecoveryPlan -> [Natural]
recoveryActiveIds (RecoveryPlan active _ _ _) = active

recoverySpareIds :: RecoveryPlan -> [Natural]
recoverySpareIds (RecoveryPlan _ spares _ _) = spares

assignments :: Ord value => [value] -> [value] -> [Map value value]
assignments [] _ = [Map.empty]
assignments (source : rest) candidates =
  [Map.insert source target mapping | target <- candidates, mapping <- assignments rest (filter (/= target) candidates)]

subsets :: Natural -> [value] -> [[value]]
subsets maximumCount values = concatMap (`choose` values) [0 .. maximumCount]

choose :: Natural -> [value] -> [[value]]
choose 0 _ = [[]]
choose _ [] = []
choose count (first : rest) = fmap (first :) (choose (count - 1) rest) <> choose count rest

unique :: Ord value => [value] -> Bool
unique values = length values == Set.size (Set.fromList values)

invalid :: Text -> Either StorageError value
invalid = Left . InvalidStorageGeometry
