{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Placement witnesses retain the named slots and recovery alternatives.
-- Byte presentation and allocation happen after these usable-byte maxima.
module Amoebius.Capacity.Placement
  ( SlotWitness (..), MinioPlacement, BookKeeperPlacement, LedgerSegment (..)
  , provisionMinioPlacement, minioSlots, minioPlacementGeometry, minioObjectPlacement
  , provisionBookKeeperPlacement, bookKeeperSlots, bookKeeperRecoveryCases
  ) where

import Amoebius.Capacity.Storage (StorageError (..))
import Amoebius.Capacity.StorageGeometry
import Control.Monad (unless)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Numeric.Natural (Natural)

data SlotWitness = SlotWitness
  { slotId :: Natural, slotSteadyBytes :: Natural, slotRecoveryBytes :: Natural
  , slotPeakBytes :: Natural, slotComponents :: Map Text Natural }
  deriving stock (Eq, Show)

data MinioPlacement = MinioPlacement (Map Natural SlotWitness) GeometryWitness
  (Map Natural [(Text, Natural, Natural)])
  deriving stock (Eq, Show)

-- | Each tuple is (physical identity, extent, multiplicity). A set index is
-- explicit even for empty sets. Identities cannot migrate between sets here.
provisionMinioPlacement :: MinioPolicy -> Map Natural [(Text, Natural, Natural)]
  -> Either StorageError MinioPlacement
provisionMinioPlacement policy objects = do
  _ <- minioPhysicalDemand policy 0
  unless (Map.keysSet objects == Set.fromList [0 .. minioErasureSets policy - 1])
    (Left (InvalidStorageGeometry "MinIO placement must enumerate every set"))
  let entries = concat (Map.elems objects)
      identities = [identity | (identity, _, _) <- entries]
  unless (length identities == Set.size (Set.fromList identities)
    && all (\(identity, bytes, count) -> identity /= "" && bytes > 0 && count > 0) entries)
    (Left (InvalidStorageGeometry "MinIO physical identities, extents and multiplicities must be unique and positive"))
  let shards = minioDataShards policy + minioParityShards policy
#ifdef PLATFORM_BACKBONE_LOGICAL_AS_PHYSICAL_MUTANT
      shard bytes = ceilDiv bytes shards
#else
      shard bytes = ceilDiv bytes (minioDataShards policy * minioShardBlockBytes policy) * minioShardBlockBytes policy
#endif
      write = (minioConcurrentWriteSets policy + minioFailedWriteSets policy) * shard (minioMaximumWriteSetBytes policy)
      slots = Map.fromList
        [ let payload = sum [count * shard bytes | (_, bytes, count) <- population]
              metadata = minioMetadataBytesPerDrive policy * (1 + sum [count | (_, _, count) <- population])
              recovery = minioFaultBoundPerSet policy * (payload + minioHealingWorkspaceBytesPerDrive policy)
              parts = Map.fromList [("stripe-data-parity", payload), ("metadata", metadata),
                ("healing", recovery), ("concurrent-orphan", write)]
              ordinal = set * shards + drive
          in (ordinal, SlotWitness ordinal (payload + metadata + write) recovery (sum (Map.elems parts)) parts)
        | (set, population) <- Map.toList objects, drive <- [0 .. shards - 1] ]
#ifdef PLATFORM_BACKBONE_DROP_FAULT_SCENARIO_MUTANT
      scenarios = [[]]
#else
      scenarios = fmap concat (sequence [subsets (minioFaultBoundPerSet policy)
          [set * shards .. (set + 1) * shards - 1] | set <- [0 .. minioErasureSets policy - 1]])
#endif
      geometry = GeometryWitness (sum [bytes * count | (_, bytes, count) <- entries])
        (sum (fmap slotPeakBytes (Map.elems slots))) scenarios
        (Map.unionsWith (+) (fmap slotComponents (Map.elems slots)))
  pure (MinioPlacement slots geometry objects)

minioSlots :: MinioPlacement -> Map Natural SlotWitness
minioSlots (MinioPlacement slots _ _) = slots

minioPlacementGeometry :: MinioPlacement -> GeometryWitness
minioPlacementGeometry (MinioPlacement _ geometry _) = geometry

minioObjectPlacement :: MinioPlacement -> Map Natural [(Text, Natural, Natural)]
minioObjectPlacement (MinioPlacement _ _ placement) = placement

data LedgerSegment = LedgerSegment
  { segmentIdentity :: Text, segmentBytes :: Natural, segmentReplicas :: [Natural] }
  deriving stock (Eq, Show)

data BookKeeperPlacement = BookKeeperPlacement (Map Natural SlotWitness)
  [([Natural], Map Text [Natural])]
  deriving stock (Eq, Show)

provisionBookKeeperPlacement :: BookKeeperPolicy -> [LedgerSegment]
  -> Either StorageError BookKeeperPlacement
provisionBookKeeperPlacement policy segments = do
  _ <- bookKeeperPhysicalDemand policy (sum (fmap segmentBytes segments))
  let bookies = [0 .. bookKeeperEnsembleSize policy - 1]
      identities = fmap segmentIdentity segments
      quorum = bookKeeperWriteQuorum policy
  unless (length identities == Set.size (Set.fromList identities)
    && all (\segment -> segmentIdentity segment /= "" && segmentBytes segment > 0
      && fromIntegral (length (segmentReplicas segment)) == quorum
      && length (segmentReplicas segment) == Set.size (Set.fromList (segmentReplicas segment))
      && all (`elem` bookies) (segmentReplicas segment)) segments)
    (Left (InvalidStorageGeometry "BookKeeper segments require exact unique replica identities"))
  cases <- fmap concat $ traverse (recover bookies) (subsets (bookKeeperFaultBound policy) bookies)
  let reserve = bookKeeperJournalAndIndexBytesPerBookie policy
      steady bookie = reserve + sum [segmentBytes segment | segment <- segments, bookie `elem` segmentReplicas segment]
      incoming bookie additions = sum [segmentBytes segment | segment <- segments,
          bookie `elem` Map.findWithDefault [] (segmentIdentity segment) additions]
      slots = Map.fromList
        [ let recovery = maximum (0 : [incoming bookie additions | (_, additions) <- cases])
          in (bookie, SlotWitness bookie (steady bookie) recovery (steady bookie + recovery)
            (Map.fromList [("original-ledgers-and-reserve", steady bookie), ("incoming-replicas", recovery)]))
        | bookie <- bookies ]
  pure (BookKeeperPlacement slots cases)
 where
  recover bookies failed = do
    alternatives <- traverse (\segment -> do
      let lost = fromIntegral (length (filter (`elem` failed) (segmentReplicas segment)))
          candidates = filter (\bookie -> bookie `notElem` failed && bookie `notElem` segmentReplicas segment) bookies
          replacements = choose lost candidates
      unless (not (null replacements)) (Left (InvalidStorageGeometry "BookKeeper replacement pool cannot restore write quorum"))
      pure [(segmentIdentity segment, replacement) | replacement <- replacements]) segments
    pure [(failed, Map.fromList additions) | additions <- sequence alternatives]

bookKeeperSlots :: BookKeeperPlacement -> Map Natural SlotWitness
bookKeeperSlots (BookKeeperPlacement slots _) = slots

bookKeeperRecoveryCases :: BookKeeperPlacement -> [([Natural], Map Text [Natural])]
bookKeeperRecoveryCases (BookKeeperPlacement _ cases) = cases

subsets :: Natural -> [value] -> [[value]]
subsets count values = concatMap (`choose` values) [0 .. count]

choose :: Natural -> [value] -> [[value]]
choose 0 _ = [[]]
choose _ [] = []
choose count (first : rest) = fmap (first :) (choose (count - 1) rest) <> choose count rest

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator = (numerator + denominator - 1) `div` denominator
